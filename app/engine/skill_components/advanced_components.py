from __future__ import annotations
from typing import TYPE_CHECKING

from app.data.database.components import ComponentType
from app.data.database.skill_components import SkillComponent, SkillTags
from app.engine import action, equations, item_funcs, skill_system
from app.engine.game_state import game
import app.engine.combat.playback as pb
from app.utilities import static_random

if TYPE_CHECKING:
    from app.engine.objects.item import ItemObject


class Ability(SkillComponent):
    nid = 'ability'
    desc = "Give unit an item as an extra ability"
    tag = SkillTags.ADVANCED

    expose = ComponentType.Item

    def extra_ability(self, unit):
        item_uid = self.skill.data.get('ability_item_uid', None)
        if item_uid and game.item_registry.get(item_uid, None):
            return game.item_registry[item_uid]
        else:
            new_item = item_funcs.create_item(unit, self.value)
            self.skill.data['ability_item_uid'] = new_item.uid
            game.register_item(new_item)
            return new_item

    def end_combat(self, playback, unit, item, target, mode):
        if item and item.nid == self.value:
            action.do(action.TriggerCharge(unit, self.skill))

class CombatArt(SkillComponent):
    nid = 'combat_art'
    desc = "Unit has the ability to apply an extra effect to next attack"
    tag = SkillTags.ADVANCED

    expose = ComponentType.Skill
    _action = None

    def init(self, skill):
        self.skill.data['active'] = False

    def combat_art(self, unit):
        return self.value

    def start_combat(self, playback, unit, item, target, mode):
        if self._action:
            playback.append(pb.AttackPreProc(unit, self._action.skill_obj))

    def on_activation(self, unit):
        # I don't think this needs to use an action
        # because there will be no point in the turnwheel
        # where you could stop it at True
        self.skill.data['active'] = True
        self._action = action.AddSkill(unit, self.value)
        action.do(self._action)

    def on_deactivation(self, unit):
        self.skill.data['active'] = False
        # Remove the added combat art skill
        if self._action and self._action.skill_obj:
            action.do(action.RemoveSkill(unit, self._action.skill_obj))
        self._action = None

    def end_combat(self, playback, unit, item, target, mode):
        if self.skill.data.get('active'):
            action.do(action.TriggerCharge(unit, self.skill))
        self.skill.data['active'] = False

class AutomaticCombatArt(SkillComponent):
    nid = 'automatic_combat_art'
    desc = "Unit will be given skill on upkeep and removed on endstep"
    tag = SkillTags.ADVANCED

    expose = ComponentType.Skill

    def on_upkeep(self, actions, playback, unit):
        actions.append(action.AddSkill(unit, self.value))
        actions.append(action.TriggerCharge(unit, self.skill))

    def on_endstep(self, actions, playback, unit):
        actions.append(action.RemoveSkill(unit, self.value))


class AllowedWeapons(SkillComponent):
    nid = 'allowed_weapons'
    desc = "Defines what weapons are allowed for combat art or proc skill"
    tag = SkillTags.ADVANCED

    expose = ComponentType.String

    def weapon_filter(self, unit, item) -> bool:
        from app.engine import evaluate
        try:
            return bool(evaluate.evaluate(self.value, unit, local_args={'item': item}))
        except Exception as e:
            print("Couldn't evaluate conditional {%s} %s" % (self.value, e))
        return False

def get_proc_rate(unit, skill) -> int:
    for component in skill.components:
        if component.defines('proc_rate'):
            return component.proc_rate(unit)
    return 100  # 100 is default

def get_weapon_filter(skill, unit, item) -> bool:
    for component in skill.components:
        if component.defines('weapon_filter'):
            return component.weapon_filter(unit, item)
    return True

class ProcGainSkillForTurn(SkillComponent):
    nid = 'proc_turn_skill'
    desc = "Unit has a chance to gain the proc skill at the beginning of the turn, and will lose it on endstep"
    tag = SkillTags.ADVANCED

    expose = ComponentType.Skill
    _did_action = False

    def on_upkeep(self, actions, playback, unit):
        proc_rate = get_proc_rate(unit, self.skill)
        if static_random.get_combat() < proc_rate:
            actions.append(action.AddSkill(unit, self.value))
            actions.append(action.TriggerCharge(unit, self.skill))
            self._did_action = True

    def on_endstep(self, actions, playback, unit):
        if self._did_action:
            actions.append(action.RemoveSkill(unit, self.value))

class AttackProc(SkillComponent):
    nid = 'attack_proc'
    desc = "Allows skill to proc on a single attacking strike"
    tag = SkillTags.ADVANCED

    expose = ComponentType.Skill
    _did_action = False

    def start_sub_combat(self, actions, playback, unit, item, target, mode, attack_info):
        if mode == 'attack' and target and skill_system.check_enemy(unit, target):
            if not get_weapon_filter(self.skill, unit, item):
                return
            proc_rate = get_proc_rate(unit, self.skill)
            if static_random.get_combat() < proc_rate:
                act = action.AddSkill(unit, self.value)
                action.do(act)
                playback.append(pb.AttackProc(unit, act.skill_obj))
                self._did_action = True

    def end_sub_combat(self, actions, playback, unit, item, target, mode, attack_info):
        if self._did_action:
            action.do(action.RemoveSkill(unit, self.value))
        self._did_action = False

class DefenseProc(SkillComponent):
    nid = 'defense_proc'
    desc = "Allows skill to proc when defending a single strike"
    tag = SkillTags.ADVANCED

    expose = ComponentType.Skill
    _did_action = False

    def start_sub_combat(self, actions, playback, unit, item, target, mode, attack_info):
        if mode == 'defense' and target and skill_system.check_enemy(unit, target):
            if not get_weapon_filter(self.skill, unit, item):
                return
            proc_rate = get_proc_rate(unit, self.skill)
            if static_random.get_combat() < proc_rate:
                act = action.AddSkill(unit, self.value)
                action.do(act)
                playback.append(pb.DefenseProc(unit, act.skill_obj))
                self._did_action = True

    def end_sub_combat(self, actions, playback, unit, item, target, mode, attack_info):
        if self._did_action:
            action.do(action.RemoveSkill(unit, self.value))
        self._did_action = False

class AttackPreProc(SkillComponent):
    nid = 'attack_pre_proc'
    desc = "Allows skill to proc when initiating combat. Lasts entire combat."
    tag = SkillTags.ADVANCED

    expose = ComponentType.Skill
    _did_action = False

    def start_combat(self, playback, unit, item, target, mode):
        if mode == 'attack' and target and skill_system.check_enemy(unit, target):
            if not get_weapon_filter(self.skill, unit, item):
                return
            proc_rate = get_proc_rate(unit, self.skill)
            if static_random.get_combat() < proc_rate:
                act = action.AddSkill(unit, self.value)
                action.do(act)
                playback.append(pb.AttackPreProc(unit, act.skill_obj))
                self._did_action = True

    def end_combat(self, playback, unit, item, target, mode):
        if self._did_action:
            action.do(action.RemoveSkill(unit, self.value))
            self._did_action = False

class DefensePreProc(SkillComponent):
    nid = 'defense_pre_proc'
    desc = "Allows skill to proc when defending in combat. Lasts entire combat."
    tag = SkillTags.ADVANCED

    expose = ComponentType.Skill
    _did_action = False

    def start_combat(self, playback, unit, item, target, mode):
        if mode == 'defense' and target and skill_system.check_enemy(unit, target):
            if not get_weapon_filter(self.skill, unit, item):
                return
            proc_rate = get_proc_rate(unit, self.skill)
            if static_random.get_combat() < proc_rate:
                act = action.AddSkill(unit, self.value)
                action.do(act)
                playback.append(pb.DefensePreProc(unit, act.skill_obj))
                self._did_action = True

    def end_combat(self, playback, unit, item, target, mode):
        if self._did_action:
            action.do(action.RemoveSkill(unit, self.value))
            self._did_action = False

class ProcRate(SkillComponent):
    nid = 'proc_rate'
    desc = "Set the proc rate"
    tag = SkillTags.ADVANCED

    expose = ComponentType.Equation

    def proc_rate(self, unit):
        return equations.parser.get(self.value, unit)

class ItemOverride(SkillComponent):
    nid = 'item_override'
    desc = 'allows overriding of item properties'
    tag = SkillTags.ADVANCED

    expose = ComponentType.Item
    value = ""

    item: ItemObject = None

    def get_components(self, unit):
        if not self.value:
            return []
        if not self.item:
            from app.engine import item_funcs
            self.item = item_funcs.create_item(unit, self.value)
        return self.item.components
