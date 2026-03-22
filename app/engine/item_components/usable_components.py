from typing import Dict
from app.data.database.item_components import ItemComponent, ItemTags
from app.data.database.components import ComponentType

from app.engine import action, item_funcs

class Uses(ItemComponent):
    nid = 'uses'
    desc = "Number of uses of item"
    paired_with = ('uses_options',)
    tag = ItemTags.USES

    expose = ComponentType.Int
    value = 1

    _did_something = False

    def init(self, item):
        item.data['uses'] = self.value
        item.data['starting_uses'] = self.value

    def available(self, unit, item) -> bool:
        return item.data['uses'] > 0

    def is_broken(self, unit, item) -> bool:
        return item.data['uses'] <= 0

    def on_hit(self, actions, playback, unit, item, target, target_pos, mode, attack_info):
        if item.uses_options.one_loss_per_combat():
            self._did_something = True
        else:
            actions.append(action.SetObjData(item, 'uses', item.data['uses'] - 1))
            actions.append(action.UpdateRecords('item_use', (unit.nid, item.nid)))

    def on_miss(self, actions, playback, unit, item, target, target_pos, mode, attack_info):
        if item.uses_options.lose_uses_on_miss():
            if item.uses_options.one_loss_per_combat():
                self._did_something = True
            else:
                actions.append(action.SetObjData(item, 'uses', item.data['uses'] - 1))
                actions.append(action.UpdateRecords('item_use', (unit.nid, item.nid)))

    def on_broken(self, unit, item):
        from app.engine.game_state import game
        if self.is_broken(unit, item):
            if item in unit.items:
                action.do(action.RemoveItem(unit, item))
            elif item in game.party.convoy:
                action.do(action.RemoveItemFromConvoy(item))
            else:
                for other_unit in game.get_units_in_party():
                    if item in other_unit.items:
                        action.do(action.RemoveItem(other_unit, item))
            return True
        return False

    def end_combat(self, playback, unit, item, target, mode):
        if self._did_something:
            action.do(action.SetObjData(item, 'uses', item.data['uses'] - 1))
            action.do(action.UpdateRecords('item_use', (unit.nid, item.nid)))
        self._did_something = False

    def reverse_use(self, unit, item):
        if self.is_broken(unit, item):
            if item_funcs.inventory_full(unit, item):
                action.do(action.PutItemInConvoy(item))
            else:
                action.do(action.GiveItem(unit, item))
        action.do(action.SetObjData(item, 'uses', item.data['uses'] + 1))
        action.do(action.ReverseRecords('item_use', (unit.nid, item.nid)))

    def special_sort(self, unit, item):
        return item.data['uses']

class ChapterUses(ItemComponent):
    nid = 'c_uses'
    desc = "The item’s uses per chapter. The uses recharge to full at chapter end, even if all are used. Do not combine with the uses component."
    paired_with = ('uses_options',)
    tag = ItemTags.USES

    expose = ComponentType.Int
    value = 1

    _did_something = False

    def init(self, item):
        item.data['c_uses'] = self.value
        item.data['starting_c_uses'] = self.value

    def available(self, unit, item) -> bool:
        return item.data['c_uses'] > 0

    def is_broken(self, unit, item) -> bool:
        return item.data['c_uses'] <= 0

    def on_hit(self, actions, playback, unit, item, target, target_pos, mode, attack_info):
        if item.uses_options.one_loss_per_combat():
            self._did_something = True
        else:
            actions.append(action.SetObjData(item, 'c_uses', item.data['c_uses'] - 1))
            actions.append(action.UpdateRecords('item_use', (unit.nid, item.nid)))

    def on_miss(self, actions, playback, unit, item, target, target_pos, mode, attack_info):
        if item.uses_options.lose_uses_on_miss():
            if item.uses_options.one_loss_per_combat():
                self._did_something = True
            else:
                actions.append(action.SetObjData(item, 'c_uses', item.data['c_uses'] - 1))
                actions.append(action.UpdateRecords('item_use', (unit.nid, item.nid)))

    def on_broken(self, unit, item):
        if self.is_broken(unit, item):
            if unit.equipped_weapon is item:
                action.do(action.UnequipItem(unit, item))
            elif unit.equipped_accessory is item:
                action.do(action.UnequipItem(unit, item))
            return True
        return False

    def end_combat(self, playback, unit, item, target, mode):
        if self._did_something:
            action.do(action.SetObjData(item, 'c_uses', item.data['c_uses'] - 1))
            action.do(action.UpdateRecords('item_use', (unit.nid, item.nid)))
        self._did_something = False

    def on_end_chapter(self, unit, item):
        # Don't need to use action here because it will be end of chapter
        item.data['c_uses'] = item.data['starting_c_uses']

    def reverse_use(self, unit, item):
        action.do(action.SetObjData(item, 'c_uses', item.data['c_uses'] + 1))
        action.do(action.ReverseRecords('item_use', (unit.nid, item.nid)))

    def special_sort(self, unit, item):
        return item.data['c_uses']

class UsesOptions(ItemComponent):
    nid = 'uses_options'
    desc = 'Additional options for uses'
    tag = ItemTags.HIDDEN

    expose = (ComponentType.MultipleOptions)

    value = [
        ['LoseUsesOnMiss (T/F)', 'F', 'Lose uses even on miss'],
        ['OneLossPerCombat (T/F)', 'F', "Doubling doesn't cost extra uses"]
    ]

    @property
    def values(self) -> Dict[str, str]:
        return {value[0]: value[1] for value in self.value}

    def lose_uses_on_miss(self) -> bool:
        if self.values['LoseUsesOnMiss (T/F)'] == 'F':
            return False
        return True

    def one_loss_per_combat(self) -> bool:
        if self.values.get('OneLossPerCombat (T/F)', 'F') == 'T':
            return True
        return False

class HPCost(ItemComponent):
    nid = 'hp_cost'
    desc = "Item subtracts the specified amount of HP upon use. If the subtraction would kill the unit the item becomes unusable."
    tag = ItemTags.USES

    expose = ComponentType.Int
    value = 1

    _did_something = False

    def available(self, unit, item) -> bool:
        return unit.get_hp() > self.value

    def on_hit(self, actions, playback, unit, item, target, target_pos, mode, attack_info):
        self._did_something = True

    def on_miss(self, actions, playback, unit, item, target, target_pos, mode, attack_info):
        self._did_something = True

    def end_combat(self, playback, unit, item, target, mode):
        if self._did_something:
            action.do(action.ChangeHP(unit, -self.value))
        self._did_something = False

    def reverse_use(self, unit, item):
        action.do(action.ChangeHP(unit, self.value))

class ManaCost(ItemComponent):
    nid = 'mana_cost'
    desc = "Item subtracts the specified amount of Mana upon use. MANA must be defined in the equations editor. If unit does not have enough mana the item will not be usable."
    tag = ItemTags.USES

    expose = ComponentType.Int
    value = 1

    _did_something = False

    def available(self, unit, item) -> bool:
        return unit.get_mana() >= self.value

    def is_broken(self, unit, item) -> bool:
        return unit.get_mana() < self.value

    def on_broken(self, unit, item) -> bool:
        if unit.equipped_weapon is item:
            action.do(action.UnequipItem(unit, item))
        elif unit.equipped_accessory is item:
            action.do(action.UnequipItem(unit, item))
        return False

    def on_hit(self, actions, playback, unit, item, target, target_pos, mode, attack_info):
        self._did_something = True

    def on_miss(self, actions, playback, unit, item, target, target_pos, mode, attack_info):
        self._did_something = True

    def end_combat(self, playback, unit, item, target, mode):
        if self._did_something:
            action.do(action.ChangeMana(unit, -self.value))
        self._did_something = False

    def reverse_use(self, unit, item):
        action.do(action.ChangeMana(unit, self.value))

class EvalManaCost(ItemComponent):
    nid = 'eval_mana_cost'
    desc = "Item costs mana to use, the amount is eval'd at runtime"
    tag = ItemTags.USES

    expose = ComponentType.String

    value = ""

    def _check_value(self, unit, item) -> int:
        from app.engine import evaluate
        try:
            return int(evaluate.evaluate(self.value, unit, local_args={'item': item}))
        except:
            print("Couldn't evaluate %s conditional" % self.value)
        return 0

    def available(self, unit, item) -> bool:
        return unit.get_mana() >= self._check_value(unit, item)

    def start_combat(self, playback, unit, item, target, mode):
        value = self._check_value(unit, item)
        action.do(action.ChangeMana(unit, -value))

    def reverse_use(self, unit, item):
        value = self._check_value(unit, item)
        action.do(action.ChangeMana(unit, value))

class Cooldown(ItemComponent):
    nid = 'cooldown'
    desc = "The item cannot be used for the specified number of turns. Since timers tick down at the start of the turn, setting cooldown to one will allow the unit to use the item on their next turn."
    tag = ItemTags.USES

    expose = ComponentType.Int
    value = 1

    def init(self, item):
        item.data['cooldown'] = 0
        item.data['starting_cooldown'] = self.value
        self._used_in_combat = False

    def available(self, unit, item) -> bool:
        return item.data['cooldown'] == 0

    def is_broken(self, unit, item) -> bool:
        return item.data['cooldown'] != 0

    def on_hit(self, actions, playback, unit, item, target, target_pos, mode, attack_info):
        self._used_in_combat = True

    def on_miss(self, actions, playback, unit, item, target, target_pos, mode, attack_info):
        self._used_in_combat = True

    def end_combat(self, playback, unit, item, target, mode):
        if self._used_in_combat:
            action.do(action.SetObjData(item, 'cooldown', self.value))
            self._used_in_combat = False

    def reverse_use(self, unit, item):
        action.do(action.SetObjData(item, 'cooldown', 0))

    def on_broken(self, unit, item):
        if unit.equipped_weapon is item:
            action.do(action.UnequipItem(unit, item))
        elif unit.equipped_accessory is item:
            action.do(action.UnequipItem(unit, item))
        return False

    def on_upkeep(self, actions, playback, unit, item):
        if item.data['cooldown'] > 0:
            # Doesn't use actions list in order to prevent
            # requiring the status phase to show health bar
            action.do(action.SetObjData(item, 'cooldown', item.data['cooldown'] - 1))

    def on_end_chapter(self, unit, item):
        # Don't need to use action here because it will be end of chapter
        item.data['cooldown'] = 0

class PrfUnit(ItemComponent):
    nid = 'prf_unit'
    desc = 'Item can only be wielded by certain units'
    tag = ItemTags.USES

    expose = (ComponentType.List, ComponentType.Unit)

    def available(self, unit, item) -> bool:
        return unit.nid in self.value

class PrfClass(ItemComponent):
    nid = 'prf_class'
    desc = 'Item can only be wielded by certain classes'
    tag = ItemTags.USES

    expose = (ComponentType.List, ComponentType.Class)

    def available(self, unit, item) -> bool:
        return unit.klass in self.value

class PrfTag(ItemComponent):
    nid = 'prf_tags'
    desc = 'Item can only be wielded by units with certain tags'
    tag = ItemTags.USES

    expose = (ComponentType.List, ComponentType.Tag)

    def available(self, unit, item) -> bool:
        return any(tag in self.value for tag in unit.tags)

class PrfAffinity(ItemComponent):
    nid = 'prf_affinity'
    desc = 'Item can only be wielded by units with certain affinity'
    tag = ItemTags.USES

    expose = (ComponentType.List, ComponentType.Affinity)

    def available(self, unit, item) -> bool:
        return unit.affinity in self.value

class Locked(ItemComponent):
    nid = 'locked'
    desc = 'Item cannot be taken or dropped from a units inventory. However, the trade command can be used to rearrange its position, and event commands can remove the item.'
    tag = ItemTags.USES

    def locked(self, unit, item) -> bool:
        return True

    def unstealable(self, unit, item) -> bool:
        return True

class Unstealable(ItemComponent):
    nid = 'unstealable'
    desc = 'Item cannot be stolen'
    tag = ItemTags.USES

    def unstealable(self, unit, item) -> bool:
        return True

class EvalAvailable(ItemComponent):
    nid = 'eval_available'
    desc = 'Item is only available while condition is true'
    tag = ItemTags.USES

    expose = ComponentType.String

    def available(self, unit, item) -> bool:
        from app.engine import evaluate
        try:
            return int(evaluate.evaluate(self.value, unit, local_args={'item': item}))
        except:
            logging.error("EvalAvailable: Couldn't evaluate %s conditional" % self.value)
        return False
