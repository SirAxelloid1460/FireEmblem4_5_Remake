from app.data.database.skill_components import SkillComponent, SkillTags
from app.data.database.components import ComponentType

class AlternateDamageFormula(SkillComponent):
    nid = 'alternate_damage_formula'
    desc = 'Unit uses a different damage formula'
    tag = SkillTags.FORMULA

    expose = ComponentType.Equation
    value = 'DAMAGE'

    def damage_formula(self, unit):
        return self.value

class AlternateResistFormula(SkillComponent):
    nid = 'alternate_resist_formula'
    desc = 'Unit uses a different resist formula'
    tag = SkillTags.FORMULA

    expose = ComponentType.Equation
    value = 'DEFENSE'

    def resist_formula(self, unit):
        return self.value

class AlternateAccuracyFormula(SkillComponent):
    nid = 'alternate_accuracy_formula'
    desc = 'Unit uses a different accuracy formula'
    tag = SkillTags.FORMULA

    expose = ComponentType.Equation
    value = 'HIT'

    def accuracy_formula(self, unit):
        return self.value

class AlternateAvoidFormula(SkillComponent):
    nid = 'alternate_avoid_formula'
    desc = 'Unit uses a different avoid formula'
    tag = SkillTags.FORMULA

    expose = ComponentType.Equation
    value = 'AVOID'

    def avoid_formula(self, unit):
        return self.value

class AlternateCritAccuracyFormula(SkillComponent):
    nid = 'alternate_crit_accuracy_formula'
    desc = 'Unit uses a different critical accuracy formula'
    tag = SkillTags.FORMULA

    expose = ComponentType.Equation
    value = 'CRIT_HIT'

    def crit_accuracy_formula(self, unit):
        return self.value

class AlternateCritAvoidFormula(SkillComponent):
    nid = 'alternate_crit_avoid_formula'
    desc = 'Unit uses a different critical avoid formula'
    tag = SkillTags.FORMULA

    expose = ComponentType.Equation
    value = 'CRIT_AVOID'

    def crit_avoid_formula(self, unit):
        return self.value

class AlternateAttackSpeedFormula(SkillComponent):
    nid = 'alternate_attack_speed_formula'
    desc = 'Unit uses a different attack speed formula'
    tag = SkillTags.FORMULA

    expose = ComponentType.Equation
    value = 'HIT'

    def attack_speed_formula(self, unit):
        return self.value

class AlternateDefenseSpeedFormula(SkillComponent):
    nid = 'alternate_defense_speed_formula'
    desc = 'Unit uses a different defense speed formula'
    tag = SkillTags.FORMULA

    expose = ComponentType.Equation
    value = 'HIT'

    def defense_speed_formula(self, unit):
        return self.value

class AlternateCriticalMultiplierFormula(SkillComponent):
    nid = 'alternate_critical_multiplier_formula'
    desc = 'Change how much damage a critical does in comparison to base damage'
    tag = SkillTags.FORMULA

    expose = ComponentType.Equation
    value = 'CRIT_MULT'

    def critical_multiplier_formula(self, unit):
        return self.value

class AlternateCriticalAdditionFormula(SkillComponent):
    nid = 'alternate_critical_addition_formula'
    desc = 'Change how much damage a critical does in comparison to base damage'
    tag = SkillTags.FORMULA

    expose = ComponentType.Equation
    value = 'CRIT_ADD'

    def critical_addition_formula(self, unit):
        return self.value

class AlternateThraciaCriticalMultiplierFormula(SkillComponent):
    nid = 'alternate_thracia_critical_addition_formula'
    desc = 'Change how much damage a critical does in comparison to base damage'
    tag = SkillTags.FORMULA

    expose = ComponentType.Equation
    value = 'THRACIA_CRIT'

    def thracia_critical_multiplier_formula(self, unit):
        return self.value

