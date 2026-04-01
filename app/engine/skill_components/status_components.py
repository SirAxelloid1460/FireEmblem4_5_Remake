import random

from app.data.database.skill_components import SkillComponent, SkillTags
from app.data.database.components import ComponentType

from app.engine import equations, action, skill_system
from app.engine.game_state import game
from app.engine.combat import playback as pb
from app.utilities import static_random
from app.utilities.enums import Strike

class Aura(SkillComponent):
    nid = 'aura'
    desc = "Skill has an aura that gives off child skill"
    tag = SkillTags.STATUS
    paired_with = ('aura_range', 'aura_target')

    expose = ComponentType.Skill

class AuraRange(SkillComponent):
    nid = 'aura_range'
    desc = "Set range of skill's aura"
    tag = SkillTags.STATUS
    paired_with = ('aura', 'aura_target')

    expose = ComponentType.Int
    value = 3

class AuraTarget(SkillComponent):
    nid = 'aura_target'
    desc = "Set target of skill's aura (set to 'ally', 'enemy', or 'unit')"
    tag = SkillTags.STATUS
    paired_with = ('aura', 'aura_range')

    expose = ComponentType.String
    value = 'unit'

class AuraShow(SkillComponent):
    nid = 'show_aura'
    desc = 'Aura will always show on the map'
    tag = SkillTags.STATUS
    paired_with = ('aura', 'aura_range', 'aura_target')

    expose = ComponentType.Color3
    value = (128, 0, 0)

class PairUpBonus(SkillComponent):
    nid = 'pairup_bonus'
    desc = "Grants a child skill to lead units while in guard stance."
    tag = SkillTags.STATUS

    expose = ComponentType.Skill

    def on_pairup(self, unit, leader):
        action.do(action.AddSkill(leader, self.value))

    def on_separate(self, unit, leader):
        if self.value in [skill.nid for skill in leader.skills]:
            action.do(action.RemoveSkill(leader, self.value))

class Regeneration(SkillComponent):
    nid = 'regeneration'
    desc = "Unit restores %% of HP at beginning of turn"
    tag = SkillTags.STATUS

    expose = ComponentType.Float
    value = 0.2

    def on_upkeep(self, actions, playback, unit):
        max_hp = equations.parser.hitpoints(unit)
        if unit.get_hp() < max_hp:
            hp_change = int(max_hp * self.value)
            actions.append(action.ChangeHP(unit, hp_change))
            # Playback
            playback.append(pb.HitSound('MapHeal'))
            playback.append(pb.DamageNumbers(unit, -hp_change))
            if hp_change >= 30:
                name = 'MapBigHealTrans'
            elif hp_change >= 15:
                name = 'MapMediumHealTrans'
            else:
                name = 'MapSmallHealTrans'
            playback.append(pb.CastAnim(name))

class ManaRegeneration(SkillComponent):
    nid = 'mana_regeneration'
    desc = "Unit restores X mana at beginning of turn"
    tag = SkillTags.STATUS

    expose = ComponentType.Int

    def on_upkeep(self, actions, playback, unit):
        actions.append(action.ChangeMana(unit, self.value))

class UpkeepDamage(SkillComponent):
    nid = 'upkeep_damage'
    desc = "Unit takes damage at upkeep"
    tag = SkillTags.STATUS

    expose = ComponentType.Int
    value = 5

    def _playback_processing(self, playback, unit, hp_change):
        # Playback
        if hp_change < 0:
            playback.append(pb.HitSound('Attack Hit ' + str(random.randint(1, 5))))
            playback.append(pb.UnitTintAdd(unit, (255, 255, 255)))
            playback.append(pb.DamageNumbers(unit, self.value))
        elif hp_change > 0:
            playback.append(pb.HitSound('MapHeal'))
            if hp_change >= 30:
                name = 'MapBigHealTrans'
            elif hp_change >= 15:
                name = 'MapMediumHealTrans'
            else:
                name = 'MapSmallHealTrans'
            playback.append(pb.CastAnim(name))
            playback.append(pb.DamageNumbers(unit, self.value))

    def on_upkeep(self, actions, playback, unit):
        hp_change = -self.value
        actions.append(action.ChangeHP(unit, hp_change))
        actions.append(action.TriggerCharge(unit, self.skill))
        self._playback_processing(playback, unit, hp_change)
        skill_system.after_take_strike(actions, playback, unit, None, None, 'defense', (0, 0), Strike.HIT)

class EndstepDamage(UpkeepDamage, SkillComponent):
    nid = 'endstep_damage'
    desc = "Unit takes damage at endstep"
    tag = SkillTags.STATUS

    expose = ComponentType.Int
    value = 5

    def on_upkeep(self, actions, playback, unit):
        pass

    def on_endstep(self, actions, playback, unit):
        hp_change = -self.value
        actions.append(action.ChangeHP(unit, hp_change))
        actions.append(action.TriggerCharge(unit, self.skill))
        self._playback_processing(playback, unit, hp_change)
        skill_system.after_take_strike(actions, playback, unit, None, None, 'defense', (0, 0), Strike.HIT)

class GBAPoison(SkillComponent):
    nid = 'gba_poison'
    desc = "Unit takes random amount of damage up to num"
    tag = SkillTags.STATUS

    expose = ComponentType.Int
    value = 5

    def on_upkeep(self, actions, playback, unit):
        old_random_state = static_random.get_combat_random_state()
        hp_loss = -static_random.get_randint(1, self.value)
        new_random_state = static_random.get_combat_random_state()
        actions.append(action.RecordRandomState(old_random_state, new_random_state))
        actions.append(action.ChangeHP(unit, hp_loss))

class ResistStatus(SkillComponent):
    nid = 'resist_status'
    desc = "Unit is only affected by statuses for a turn"
    tag = SkillTags.STATUS

    def on_add(self, unit, skill):
        for skill in unit.skills:
            if skill.time:
                action.do(action.SetObjData(skill, 'turns', min(skill.data['turns'], 1)))

    def on_gain_skill(self, unit, other_skill):
        if other_skill.time:
            action.do(action.SetObjData(other_skill, 'turns', min(other_skill.data['turns'], 1)))

class ImmuneStatus(SkillComponent):
    nid = 'immune_status'
    desc = "Unit is not affected by negative statuses"
    tag = SkillTags.STATUS

    def on_add(self, unit, skill):
        for skill in unit.skills:
            if skill.negative:
                action.do(action.RemoveSkill(unit, skill))

    def on_gain_skill(self, unit, other_skill):
        if other_skill.negative:
            action.do(action.RemoveSkill(unit, other_skill))

class ReflectStatus(SkillComponent):
    nid = 'reflect_status'
    desc = "Unit reflects statuses back to initiator"
    tag = SkillTags.STATUS

    def on_gain_skill(self, unit, other_skill):
        if other_skill.initiator_nid:
            other_unit = game.get_unit(other_skill.initiator_nid)
            if other_unit:
                # Create a copy of other skill
                action.do(action.AddSkill(other_unit, other_skill.nid))
