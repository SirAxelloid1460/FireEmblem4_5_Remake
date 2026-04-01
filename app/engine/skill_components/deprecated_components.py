from typing import Dict
from app.data.database.skill_components import SkillComponent, SkillTags
from app.data.database.components import ComponentType

from app.engine import action

class LostOnEndCombat(SkillComponent):
    nid = 'lost_on_end_combat'
    desc = "Remove after combat"
    tag = SkillTags.DEPRECATED

    expose = (ComponentType.MultipleOptions)

    value = [
            ["LostOnSelf (T/F)", "T", 'Lost after self combat (e.g. vulnerary)'],
            ["LostOnAlly (T/F)", "T", 'Lost after combat with an ally'],
            ["LostOnEnemy (T/F)", "T", 'Lost after combat with an enemy'],
            ["LostOnSplash (T/F)", "T", 'Lost after combat if using an AOE item']
    ]

    @property
    def values(self) -> Dict[str, str]:
        return {value[0]: value[1] for value in self.value}

    def post_combat(self, playback, unit, item, target, mode):
        from app.engine import skill_system
        remove_skill = False
        if self.values.get('LostOnSelf (T/F)', 'T') == 'T':
            if unit == target:
                remove_skill = True
        if self.values.get('LostOnAlly (T/F)', 'T') == 'T':
            if target:
                if skill_system.check_ally(unit, target):
                    remove_skill = True
        if self.values.get('LostOnEnemy (T/F)', 'T') == 'T':
            if target:
                if skill_system.check_enemy(unit, target):
                    remove_skill = True
        if self.values.get('LostOnSplash (T/F)', 'T') == 'T':
            if not target:
                remove_skill = True

        if remove_skill:
            action.do(action.RemoveSkill(unit, self.skill))

    def on_end_chapter(self, unit, skill):
        action.do(action.RemoveSkill(unit, self.skill))

class CombatArtSetMaxRange(SkillComponent):
    nid = 'combat_art_set_max_range'
    desc = "Defines what unit's max range is for testing combat art. Combine with 'Limit Max Range' component on subskill."
    tag = SkillTags.DEPRECATED
    paired_with = ('combat_art', )

    expose = ComponentType.Int

    def combat_art_set_max_range(self, unit) -> int:
        return max(0, self.value)

class CombatArtModifyMaxRange(SkillComponent):
    nid = 'combat_art_modify_max_range'
    desc = "Modifies unit's max range when testing combat art. Combine with 'Modify Max Range' component on subskill."
    tag = SkillTags.DEPRECATED
    paired_with = ('combat_art', )

    expose = ComponentType.Int

    def combat_art_modify_max_range(self, unit) -> int:
        return self.value
