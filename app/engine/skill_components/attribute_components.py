from app.data.database.skill_components import SkillComponent, SkillTags
from app.data.database.components import ComponentType

class Hidden(SkillComponent):
    nid = 'hidden'
    desc = "Skill will not show up on screen"
    tag = SkillTags.ATTRIBUTE

class HiddenIfInactive(SkillComponent):
    nid = 'hidden_if_inactive'
    desc = 'Skill will not show up on info menu if condition is not fulfilled'
    tag = SkillTags.ATTRIBUTE

class GreyIfInactive(SkillComponent):
    nid = 'grey_if_inactive'
    desc = 'If skill is not active, it will be drawn grey'
    tag = SkillTags.ATTRIBUTE

class TerrainSkill(SkillComponent):
    nid = 'is_terrain'
    desc = 'Skill is hidden and will not affect fliers'
    tag = SkillTags.ATTRIBUTE

    ignore_conditional = True

    def condition(self, unit, item):
        return not 'Flying' in unit.tags

class ClassSkill(SkillComponent):
    nid = 'class_skill'
    desc = "Skill will show up on first page of info menu"
    tag = SkillTags.ATTRIBUTE

class Stack(SkillComponent):
    nid = 'stack'
    desc = "Skill can be applied to a unit multiple times"
    tag = SkillTags.ATTRIBUTE

    expose = ComponentType.Int

    value = 999

class Feat(SkillComponent):
    nid = 'feat'
    desc = "Skill can be selected as a feat"
    tag = SkillTags.ATTRIBUTE

class Negative(SkillComponent):
    nid = 'negative'
    desc = "Skill is considered detrimental"
    tag = SkillTags.ATTRIBUTE

class Global(SkillComponent):
    nid = 'global'
    desc = "All units will possess this skill"
    tag = SkillTags.ATTRIBUTE

class Negate(SkillComponent):
    nid = 'negate'
    desc = "Skill negates Effective component"
    tag = SkillTags.ATTRIBUTE

class NegateTags(SkillComponent):
    nid = 'negate_tags'
    desc = "Skill negates Effective component on specific Tags"
    tag = SkillTags.ATTRIBUTE

    expose = (ComponentType.List, ComponentType.Tag)

class HasTags(SkillComponent):
    nid = 'has_tags'
    desc = 'Skill grants the following tags to the unit'
    tag = SkillTags.ATTRIBUTE

    expose = (ComponentType.List, ComponentType.Tag)