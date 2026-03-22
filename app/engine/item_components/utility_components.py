from app.utilities import utils

from app.data.database.item_components import ItemComponent, ItemTags
from app.data.database.components import ComponentType
from app.events.regions import RegionType
from app.events import triggers

from app.engine import action
from app.engine import item_system, item_funcs, skill_system, equations
from app.engine.game_state import game
from app.engine.combat import playback as pb

class Heal(ItemComponent):
    nid = 'heal'
    desc = "Item heals this amount on hit"
    tag = ItemTags.UTILITY

    expose = ComponentType.Int
    value = 10

    def _get_heal_amount(self, unit, target):
        empower_heal = skill_system.empower_heal(unit, target)
        empower_heal_received = skill_system.empower_heal_received(target, unit)
        return self.value + empower_heal + empower_heal_received

    def target_restrict(self, unit, item, def_pos, splash) -> bool:
        # Restricts target based on whether any unit has < full hp
        defender = game.board.get_unit(def_pos)
        if defender and defender.get_hp() < defender.get_max_hp():
            return True
        for s_pos in splash:
            s = game.board.get_unit(s_pos)
            if s and s.get_hp() < s.get_max_hp():
                return True
        return False

    def on_hit(self, actions, playback, unit, item, target, target_pos, mode, attack_info):
        heal = self._get_heal_amount(unit, target)
        true_heal = min(heal, target.get_max_hp() - target.get_hp())
        actions.append(action.ChangeHP(target, heal))

        # For animation
        if true_heal > 0:
            playback.append(pb.HealHit(unit, item, target, heal, true_heal))
            playback.append(pb.HitSound('MapHeal', map_only=True))
            if heal >= 30:
                name = 'MapBigHealTrans'
            elif heal >= 15:
                name = 'MapMediumHealTrans'
            else:
                name = 'MapSmallHealTrans'
            playback.append(pb.HitAnim(name, target))

    def ai_priority(self, unit, item, target, move):
        if target and skill_system.check_ally(unit, target):
            max_hp = target.get_max_hp()
            missing_health = max_hp - target.get_hp()
            help_term = utils.clamp(missing_health / float(max_hp), 0, 1)
            heal = self._get_heal_amount(unit, target)
            heal_term = utils.clamp(min(heal, missing_health) / float(max_hp), 0, 1)
            return help_term * heal_term
        return 0

class MagicHeal(Heal, ItemComponent):
    nid = 'magic_heal'
    desc = "Heals the target for the specified integer + the HEAL equation defined in the equations editor. Will act oddly if no HEAL equation is defined."

    def _get_heal_amount(self, unit, target):
        empower_heal = skill_system.empower_heal(unit, target)
        empower_heal_received = skill_system.empower_heal_received(target, unit)
        return self.value + equations.parser.heal(unit) + empower_heal + empower_heal_received

class Refresh(ItemComponent):
    nid = 'refresh'
    desc = "Has an effect identical to dancing in normal FE. A dance skill makes use of this component in an attached item."
    tag = ItemTags.UTILITY

    def target_restrict(self, unit, item, def_pos, splash) -> bool:
        # only targets areas where unit could move again
        defender = game.board.get_unit(def_pos)
        if defender and defender.finished:
            return True
        for s_pos in splash:
            s = game.board.get_unit(s_pos)
            if s.finished:
                return True

    def on_hit(self, actions, playback, unit, item, target, target_pos, mode, attack_info):
        actions.append(action.Reset(target))
        playback.append(pb.RefreshHit(unit, item, target))

class Restore(ItemComponent):
    nid = 'restore'
    desc = "Item removes all negative statuses from target on hit"
    tag = ItemTags.UTILITY

    def _can_be_restored(self, status):
        return status.negative

    def target_restrict(self, unit, item, def_pos, splash) -> bool:
        defender = game.board.get_unit(def_pos)
        # only targets units that need to be restored
        if defender and skill_system.check_ally(unit, defender) and any(self._can_be_restored(skill) for skill in defender.skills):
            return True
        for s_pos in splash:
            s = game.board.get_unit(s_pos)
            if skill_system.check_ally(unit, s) and any(self._can_be_restored(skill) for skill in s.skills):
                return True
        return False

    def on_hit(self, actions, playback, unit, item, target, target_pos, mode, attack_info):
        for skill in target.skills:
            if self._can_be_restored(skill):
                actions.append(action.RemoveSkill(target, skill))
                playback.append(pb.RestoreHit(unit, item, target))

class RestoreSpecific(Restore, ItemComponent):
    nid = 'restore_specific'
    desc = "Item removes specific status from target on hit"
    tag = ItemTags.UTILITY

    expose = ComponentType.Skill # Nid

    def _can_be_restored(self, status):
        return status.nid == self.value

class UnlockStaff(ItemComponent):
    nid = 'unlock_staff'
    desc = "Item allows user to unlock locked regions. Doesn't work with other splash/aoe components"
    tag = ItemTags.UTILITY

    _did_hit = False

    def _valid_region(self, region) -> bool:
        return region.region_type == RegionType.EVENT and 'can_unlock' in region.condition

    def ai_targets(self, unit, item) -> set:
        targets = set()
        for region in game.level.regions:
            if self._valid_region(region):
                for position in region.get_all_positions():
                    targets.add(position)
        return targets

    def valid_targets(self, unit, item) -> set:
        targets = self.ai_targets(unit, item)
        return {t for t in targets if utils.calculate_distance(unit.position, t) in item_funcs.get_range(unit, item)}

    def splash(self, unit, item, position):
        return position, []

    def target_restrict(self, unit, item, def_pos, splash) -> bool:
        for pos in [def_pos] + splash:
            for region in game.level.regions:
                if self._valid_region(region) and region.contains(def_pos):
                    return True
        return False

    def on_hit(self, actions, playback, unit, item, target, target_pos, mode, attack_info):
        self._did_hit = True

    def end_combat(self, playback, unit, item, target, mode):
        if self._did_hit:
            pos = game.cursor.position
            region = None
            for reg in game.level.regions:
                if self._valid_region(reg) and reg.contains(pos):
                    region = reg
                    break
            if region:
                did_trigger = game.events.trigger(triggers.RegionTrigger(region.sub_nid, unit, pos, region, item))
                if did_trigger and region.only_once:
                    action.do(action.RemoveRegion(region))
        self._did_hit = False

class CanUnlock(ItemComponent):
    nid = 'can_unlock'
    desc = "Allows the item to unlock specific types of locks. In GBA games, the unlock staff can only unlock doors. This component would allow for that limited functionality. In particular, region.nid.startswith('Door') would limit the staff to unlocking doors."
    tag = ItemTags.UTILITY

    expose = ComponentType.String
    value = 'True'

    def can_unlock(self, unit, item, region) -> bool:
        from app.engine import evaluate
        try:
            return bool(evaluate.evaluate(self.value, unit, local_args={'item': item, 'region': region}))
        except:
            print("Could not evaluate %s" % self.value)
        return False

class Repair(ItemComponent):
    nid = 'repair'
    desc = "Repairs a selected item in the target's inventory. Used in the Hammerne staff."
    tag = ItemTags.UTILITY

    def init(self, item):
        item.data['target_item'] = None

    def _target_restrict(self, defender):
        # Unit has item that can be repaired
        for item in defender.items:
            if item.uses and item.data['uses'] < item.data['starting_uses'] and \
                    not item_system.unrepairable(defender, item):
                return True
        return False

    def target_restrict(self, unit, item, def_pos, splash) -> bool:
        # Unit has item that can be repaired
        defender = game.board.get_unit(def_pos)
        if not defender:
            return False
        return self._target_restrict(defender)

    def simple_target_restrict(self, unit, item):
        return self._target_restrict(unit)

    def targets_items(self, unit, item) -> bool:
        return True

    def item_restrict(self, unit, item, defender, def_item) -> bool:
        if def_item.uses and def_item.data['uses'] < def_item.data['starting_uses'] and \
                not item_system.unrepairable(defender, def_item):
            return True
        return False

    def on_hit(self, actions, playback, unit, item, target, target_pos, mode, attack_info):
        target_item = item.data.get('target_item')
        if target_item:
            actions.append(action.RepairItem(target_item))

    def end_combat(self, playback, unit, item, target, mode):
        item.data['target_item'] = None

class Trade(ItemComponent):
    nid = 'trade'
    desc = "Item allows user to trade with target on hit"
    tag = ItemTags.UTILITY

    _did_hit = False

    def on_hit(self, actions, playback, unit, item, target, target_pos, mode, attack_info):
        self._did_hit = True

    def end_combat(self, playback, unit, item, target, mode):
        if self._did_hit and target:
            game.cursor.cur_unit = unit
            game.cursor.set_pos(target.position)
            game.memory['trade_partner'] = target
            game.state.change('combat_trade')
        self._did_hit = False

class MenuAfterCombat(ItemComponent):
    nid = 'menu_after_combat'
    desc = "Using this item returns the user to the menu state. However, user cannot attack again. Menu activates after any use of the item that involves targeting a unit (including targeting the user)."
    tag = ItemTags.UTILITY

    def menu_after_combat(self, unit, item):
        return True

class AttackAfterCombat(ItemComponent):
    nid = 'attack_after_combat'
    desc = "Can access menu and attack after combat"
    tag = ItemTags.UTILITY

    def menu_after_combat(self, unit, item):
        return True

    def can_attack_after_combat(self, unit, item):
        return True

class NoAttackAfterMove(ItemComponent):
    nid = 'no_attack_after_move'
    desc = "Cannot be used after moving"
    tag = ItemTags.UTILITY

    def no_attack_after_move(self, unit, item):
        return True
