import math
from typing import Dict
from app.data.database.skill_components import SkillComponent, SkillTags
from app.data.database.components import ComponentType
from app.data.database.database import DB

from app.engine import action
from app.engine.game_state import game

class Time(SkillComponent):
    nid = 'time'
    desc = "Lasts for some number of turns (checked on upkeep)"
    tag = SkillTags.TIME

    expose = ComponentType.Int
    value = 2

    def init(self, skill):
        self.skill.data['turns'] = self.value
        self.skill.data['starting_turns'] = self.value

    def on_upkeep(self, actions, playback, unit):
        val = self.skill.data['turns'] - 1
        action.do(action.SetObjData(self.skill, 'turns', val))
        if self.skill.data['turns'] <= 0:
            actions.append(action.RemoveSkill(unit, self.skill))

    def text(self) -> str:
        return str(self.skill.data['turns'])

    def on_end_chapter(self, unit, skill):
        action.do(action.RemoveSkill(unit, self.skill))

class EndTime(SkillComponent):
    nid = 'end_time'
    desc = "Lasts for some number of turns (checked on endstep)"
    tag = SkillTags.TIME

    expose = ComponentType.Int
    value = 2

    def init(self, skill):
        self.skill.data['turns'] = self.value
        self.skill.data['starting_turns'] = self.value

    def on_endstep(self, actions, playback, unit):
        val = self.skill.data['turns'] - 1
        action.do(action.SetObjData(self.skill, 'turns', val))
        if self.skill.data['turns'] <= 0:
            actions.append(action.RemoveSkill(unit, self.skill))

    def text(self) -> str:
        return str(self.skill.data['turns'])

    def on_end_chapter(self, unit, skill):
        action.do(action.RemoveSkill(unit, self.skill))

class CombinedTime(SkillComponent):
    nid = 'combined_time'
    desc = "Lasts for twice the number of phases (counts both upkeep and endstep)"
    tag = SkillTags.TIME

    expose = ComponentType.Int
    value = 1

    def init(self, skill):
        self.skill.data['turns'] = self.value * 2
        self.skill.data['starting_turns'] = self.value * 2

    def on_upkeep(self, actions, playback, unit):
        val = self.skill.data['turns'] - 1
        action.do(action.SetObjData(self.skill, 'turns', val))
        if self.skill.data['turns'] <= 0:
            actions.append(action.RemoveSkill(unit, self.skill))

    def on_endstep(self, actions, playback, unit):
        val = self.skill.data['turns'] - 1
        action.do(action.SetObjData(self.skill, 'turns', val))
        if self.skill.data['turns'] <= 0:
            actions.append(action.RemoveSkill(unit, self.skill))

    def text(self) -> str:
        return str(math.ceil(self.skill.data['turns'] / 2))

    def on_end_chapter(self, unit, skill):
        action.do(action.RemoveSkill(unit, self.skill))

class UpkeepStatChange(SkillComponent):
    nid = 'upkeep_stat_change'
    desc = "Gives changing stat bonuses"
    tag = SkillTags.TIME

    expose = (ComponentType.Dict, ComponentType.Stat)
    value = []

    def init(self, skill):
        self.skill.data['counter'] = 0

    def stat_change(self, unit):
        return {stat[0]: stat[1] * self.skill.data['counter'] for stat in self.value}

    def on_upkeep(self, actions, playback, unit):
        val = self.skill.data['counter'] + 1
        action.do(action.SetObjData(self.skill, 'counter', val))

    def on_end_chapter(self, unit, skill):
        action.do(action.RemoveSkill(unit, self.skill))

class LostOnEndstep(SkillComponent):
    nid = 'lost_on_endstep'
    desc = "Remove on next endstep"
    tag = SkillTags.TIME

    def on_endstep(self, actions, playback, unit):
        actions.append(action.RemoveSkill(unit, self.skill))

    def on_end_chapter(self, unit, skill):
        action.do(action.RemoveSkill(unit, self.skill))

class LostOnUpkeep(SkillComponent):
    nid = 'lost_on_upkeep'
    desc = "Remove on next upkeep"
    tag = SkillTags.TIME

    def on_upkeep(self, actions, playback, unit):
        actions.append(action.RemoveSkill(unit, self.skill))

    def on_end_chapter(self, unit, skill):
        action.do(action.RemoveSkill(unit, self.skill))

class LostOnEndCombat2(SkillComponent):
    nid = 'lost_on_end_combat2'
    desc = "Remove after combat"
    tag = SkillTags.TIME

    expose = (ComponentType.NewMultipleOptions)

    options = {
        "lost_on_self": ComponentType.Bool,
        "lost_on_ally": ComponentType.Bool,
        "lost_on_enemy": ComponentType.Bool,
        "lost_on_splash": ComponentType.Bool,
    }

    def __init__(self, value=None):
        self.value = {
            "lost_on_self": True,
            "lost_on_ally": True,
            "lost_on_enemy": True,
            "lost_on_splash": True,
        }
        if value:
            self.value.update(value)

    def post_combat(self, playback, unit, item, target, mode):
        from app.engine import skill_system
        remove_skill = False
        if self.value.get('lost_on_self', True):
            if unit == target:
                remove_skill = True
        if self.value.get('lost_on_ally', True):
            if target:
                if skill_system.check_ally(unit, target):
                    remove_skill = True
        if self.value.get('lost_on_enemy', True):
            if target:
                if skill_system.check_enemy(unit, target):
                    remove_skill = True
        if self.value.get('lost_on_splash', True):
            if not target:
                remove_skill = True

        if remove_skill:
            action.do(action.RemoveSkill(unit, self.skill))

    def on_end_chapter(self, unit, skill):
        action.do(action.RemoveSkill(unit, self.skill))

class LostOnKill(SkillComponent):
    nid = 'lost_on_kill'
    desc = "Remove after getting a kill"
    tag = SkillTags.TIME

    def post_combat(self, playback, unit, item, target, mode):
        if target and target.get_hp() <= 0:
            action.do(action.RemoveSkill(unit, self.skill))

    def on_end_chapter(self, unit, skill):
        action.do(action.RemoveSkill(unit, self.skill))

class LostOnEndChapter(SkillComponent):
    nid = 'lost_on_end_chapter'
    desc = "Remove at end of chapter"
    tag = SkillTags.TIME

    def on_end_chapter(self, unit, skill):
        action.do(action.RemoveSkill(unit, self.skill))

class EventOnRemove(SkillComponent):
    nid = 'event_on_remove'
    desc = "Calls event when removed"
    tag = SkillTags.TIME

    expose = ComponentType.Event

    def on_true_remove(self, unit, skill):
        event_prefab = DB.events.get_from_nid(self.value)
        if event_prefab:
            game.events.trigger_specific_event(event_prefab.nid, unit)
