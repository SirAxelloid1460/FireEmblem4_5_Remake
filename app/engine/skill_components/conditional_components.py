from app.data.database.skill_components import SkillComponent, SkillTags
from app.data.database.components import ComponentType

class CombatCondition(SkillComponent):
    nid = 'combat_condition'
    desc = "Status is conditional based on combat properties"
    tag = SkillTags.ADVANCED

    expose = ComponentType.String
    value = 'False'

    ignore_conditional = True
    _condition = False

    def pre_combat(self, playback, unit, item, target, mode):
        from app.engine import evaluate
        try:
            x = bool(evaluate.evaluate(self.value, unit, target, unit.position, {'item': item, 'mode': mode}))
            self._condition = x
            return x
        except Exception as e:
            print("%s: Could not evaluate combat condition %s" % (e, self.value))

    def post_combat(self, playback, unit, item, target, mode):
        self._condition = False

    def condition(self, unit, item):
        return self._condition

    def test_on(self, playback, unit, item, target, mode):
        self.pre_combat(playback, unit, item, target, mode)

    def test_off(self, playback, unit, item, target, mode):
        self._condition = False

class Condition(SkillComponent):
    nid = 'condition'
    desc = "Status is conditional"
    tag = SkillTags.ADVANCED

    expose = ComponentType.String
    value = 'False'

    ignore_conditional = True

    def condition(self, unit, item):
        from app.engine import evaluate
        try:
            return bool(evaluate.evaluate(self.value, unit, position=unit.position, local_args={'item': item}))
        except Exception as e:
            print("%s: Could not evaluate condition %s" % (e, self.value))
