from app.data.database.item_components import ItemComponent, ItemTags
from app.data.database.components import ComponentType

class AlternateDamageFormula(ItemComponent):
    nid = 'alternate_damage_formula'
    desc = 'Item uses a different damage formula'
    tag = ItemTags.FORMULA

    expose = ComponentType.Equation
    value = 'DAMAGE'

    def damage_formula(self, unit, item):
        return self.value

class AlternateResistFormula(ItemComponent):
    nid = 'alternate_resist_formula'
    desc = 'Item uses a different resist formula. Resist applies to both defense and resistance.'
    tag = ItemTags.FORMULA

    expose = ComponentType.Equation
    value = 'DEFENSE'

    def resist_formula(self, unit, item):
        return self.value

class AlternateAccuracyFormula(ItemComponent):
    nid = 'alternate_accuracy_formula'
    desc = 'Item uses a different accuracy formula'
    tag = ItemTags.FORMULA

    expose = ComponentType.Equation
    value = 'HIT'

    def accuracy_formula(self, unit, item):
        return self.value

class AlternateAvoidFormula(ItemComponent):
    nid = 'alternate_avoid_formula'
    desc = 'Item uses a different avoid formula'
    tag = ItemTags.FORMULA

    expose = ComponentType.Equation
    value = 'AVOID'

    def avoid_formula(self, unit, item):
        return self.value

class AlternateCritAccuracyFormula(ItemComponent):
    nid = 'alternate_crit_accuracy_formula'
    desc = 'Item uses a different critical accuracy formula'
    tag = ItemTags.FORMULA

    expose = ComponentType.Equation
    value = 'CRIT_HIT'

    def crit_accuracy_formula(self, unit, item):
        return self.value

class AlternateCritAvoidFormula(ItemComponent):
    nid = 'alternate_crit_avoid_formula'
    desc = 'Item uses a different critical avoid formula'
    tag = ItemTags.FORMULA

    expose = ComponentType.Equation
    value = 'CRIT_AVOID'

    def crit_avoid_formula(self, unit, item):
        return self.value

class AlternateAttackSpeedFormula(ItemComponent):
    nid = 'alternate_attack_speed_formula'
    desc = 'Item uses a different attack speed formula. Attack speed is used when initiating a combat.'
    tag = ItemTags.FORMULA

    expose = ComponentType.Equation
    value = 'HIT'

    def attack_speed_formula(self, unit, item):
        return self.value

class AlternateDefenseSpeedFormula(ItemComponent):
    nid = 'alternate_defense_speed_formula'
    desc = 'Item uses a different defense speed formula. Defense speed is used when being attacked.'
    tag = ItemTags.FORMULA

    expose = ComponentType.Equation
    value = 'HIT'

    def defense_speed_formula(self, unit, item):
        return self.value
