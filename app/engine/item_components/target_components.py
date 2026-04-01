from __future__ import annotations

import logging
from functools import lru_cache

from app.data.database.components import ComponentType
from app.data.database.item_components import ItemComponent, ItemTags
from app.engine import item_funcs, skill_system, target_system
from app.engine.game_state import game
from app.utilities import utils


class TargetsAnything(ItemComponent):
    nid = 'target_tile'
    desc = "Item targets any tile"
    tag = ItemTags.TARGET

    def ai_targets(self, unit, item) -> set:
        return {(x, y) for x in range(game.tilemap.width) for y in range(game.tilemap.height)}

    def valid_targets(self, unit, item) -> set:
        rng = item_funcs.get_range(unit, item)
        positions = target_system.find_manhattan_spheres(rng, *unit.position)
        return {pos for pos in positions if game.board.check_bounds(pos)}

class TargetsUnits(ItemComponent):
    nid = 'target_unit'
    desc = "Item targets any unit"
    tag = ItemTags.TARGET

    def ai_targets(self, unit, item):
        return {other.position for other in game.units if other.position}

    def valid_targets(self, unit, item) -> set:
        targets = {other.position for other in game.units if other.position}
        return {t for t in targets if utils.calculate_distance(unit.position, t) in item_funcs.get_range(unit, item)}

class TargetsEnemies(ItemComponent):
    nid = 'target_enemy'
    desc = "Item targets any enemy"
    tag = ItemTags.TARGET

    def ai_targets(self, unit, item):
        return {other.position for other in game.units if other.position and
                skill_system.check_enemy(unit, other)}

    def valid_targets(self, unit, item) -> set:
        targets = {other.position for other in game.units if other.position and
                   skill_system.check_enemy(unit, other)}
        return {t for t in targets if utils.calculate_distance(unit.position, t) in item_funcs.get_range(unit, item)}

class TargetsAllies(ItemComponent):
    nid = 'target_ally'
    desc = "Item targets any ally"
    tag = ItemTags.TARGET

    def ai_targets(self, unit, item):
        return {other.position for other in game.units if other.position and
                skill_system.check_ally(unit, other)}

    def valid_targets(self, unit, item) -> set:
        targets = {other.position for other in game.units if other.position and
                   skill_system.check_ally(unit, other)}
        return {t for t in targets if utils.calculate_distance(unit.position, t) in item_funcs.get_range(unit, item)}

class TargetsSpecificTiles(ItemComponent):
    nid = 'target_specific_tile'
    desc = "Item targets tiles specified by the condition. Condition must return a list of positions, or a list of lists of positions. Positions must be within the item's range."
    tag = ItemTags.TARGET

    expose = ComponentType.String
    value = ''

    def ai_targets(self, unit, item) -> set:
        return set(self.resolve_targets(unit, item))

    def valid_targets(self, unit, item) -> set:
        rng = item_funcs.get_range(unit, item)
        range_restrictions = target_system.find_manhattan_spheres(rng, *unit.position)
        targetable_positions = self.resolve_targets(unit, item)
        return {pos for pos in targetable_positions if pos in range_restrictions}

    def resolve_targets(self, unit, item):
        from app.engine import evaluate
        try:
            value_list = evaluate.evaluate(self.value, unit, position=unit.position, local_args={'item': item})
        except Exception as e:
            logging.error("target_specific_tile component failed to evaluate expression %s with error %s", self.value, e)
            value_list = []
        return utils.flatten_list(value_list)

class EvalSpecialRange(ItemComponent):
    nid = 'eval_special_range'
    desc = "Use this to restrict range to specific tiles around the unit"
    tag = ItemTags.TARGET

    expose = ComponentType.String
    value = ''

    # if the range is large, the calculation will be large; let's not repeat this more than necessary.
    # luckily, the calculation is trivial.
    @staticmethod
    @lru_cache(maxsize=None)
    def calculate_range_restrict(condition, max_rng) -> set:
        valid_range_squares = set()
        try:
            # neat performance trick
            cond_as_func = eval('lambda x, y:' + condition)
            for x in range(-max_rng, max_rng+1):
                for y in range(-max_rng, max_rng+1):
                    if cond_as_func(x, y):
                        valid_range_squares.add((x, y))
        except Exception as e:
            logging.error("eval_special_range failed for condition %s with error %s", condition, str(e))
        return valid_range_squares

    def range_restrict(self, unit, item) -> set:
        rng = item_funcs.get_range(unit, item)
        if not rng:
            return set()
        max_rng = max(rng)
        return EvalSpecialRange.calculate_range_restrict(self.value, max_rng)

    def target_restrict(self, unit, item, def_pos, splash) -> bool:
        if def_pos:
            net_pos = (def_pos[0] - unit.position[0], def_pos[1] - unit.position[1])
            range_restriction = self.range_restrict(unit, item)
            if net_pos in range_restriction:
                return True
            return False
        else:
            for pos in splash:
                net_pos = (pos[0] - unit.position[0], pos[1] - unit.position[1])
                range_restriction = self.range_restrict(unit, item)
                if net_pos not in range_restriction:
                    return False
        return True

class EvalTargetRestrict2(ItemComponent):
    nid = 'eval_target_restrict_2'
    desc = \
"""
Restricts which units or spaces can be targeted. These properties are accessible in the eval body:

- `unit`: the unit using the item
- `target`: the target of the item
- `item`: the item itself
- `position`: the position of the unit
- `target_pos`: the position of the target
"""
    tag = ItemTags.TARGET

    expose = ComponentType.String
    value = 'True'

    def target_restrict(self, unit, item, def_pos, splash) -> bool:
        from app.engine import evaluate
        try:
            target = game.board.get_unit(def_pos)
            unit_pos = unit.position
            target_pos = def_pos
            if evaluate.evaluate(self.value, unit, target, unit_pos, local_args={'target_pos': target_pos, 'item': item}):
                return True
            for s_pos in splash:
                target = game.board.get_unit(s_pos)
                if evaluate.evaluate(self.value, unit, target, unit_pos, local_args={'target_pos': s_pos, 'item': item}):
                    return True
        except Exception as e:
            print("Could not evaluate %s (%s)" % (self.value, e))
            return True
        return False

    def simple_target_restrict(self, unit, item):
        from app.engine import evaluate
        try:
            if evaluate.evaluate(self.value, unit, local_args={'item': item}):
                return True
        except Exception as e:
            print("Could not evaluate %s (%s)" % (self.value, e))
            return True
        return False

class EmptyTileTargetRestrict(ItemComponent):
    nid = 'empty_tile_target_restrict'
    desc = "Item will only target tiles without units on them"
    tag = ItemTags.TARGET

    def target_restrict(self, unit, item, def_pos, splash) -> bool:
        if not game.board.get_unit(def_pos):
            return True
        return False

class TraversableTargetRestrict(ItemComponent):
    nid = 'traversable_tile_target_restrict'
    desc = 'Item targets tiles that are traversable by the unit. Useful for movement (warp) and summon skills, for example'
    tag = ItemTags.TARGET

    def target_restrict(self, unit, item, def_pos, splash) -> bool:
        if unit and def_pos:
            if game.movement.check_traversable(unit, def_pos):
                return True
        return False
        
class IgnoreLineOfSight(ItemComponent):
    nid = 'ignore_line_of_sight'
    desc = 'Item ignores line of sight rules even when line of sight constant is enabled.'
    tag = ItemTags.TARGET
    
    def ignore_line_of_sight(self, unit, item) -> bool:
        return True

class MinimumRange(ItemComponent):
    nid = 'min_range'
    desc = "Set the minimum_range of the item to an integer"
    tag = ItemTags.TARGET

    expose = ComponentType.Int
    value = 0

    def minimum_range(self, unit, item) -> int:
        return self.value

class MaximumRange(ItemComponent):
    nid = 'max_range'
    desc = "Set the maximum_range of the item to an integer"
    tag = ItemTags.TARGET

    expose = ComponentType.Int
    value = 0

    def maximum_range(self, unit, item) -> int:
        return self.value

class MaximumEquationRange(ItemComponent):
    nid = 'max_equation_range'
    desc = "Set the maximum_range of the item to an equation"
    tag = ItemTags.TARGET

    expose = ComponentType.Equation

    def maximum_range(self, unit, item) -> int:
        from app.engine import equations
        if unit:
            value = equations.parser.get(self.value, unit)
            return int(value)
        else:
            return -1

class GlobalRange(ItemComponent):
    nid = 'global_range'
    desc = "Item has no maximum range"
    tag = ItemTags.TARGET

    def maximum_range(self, unit, item) -> int:
        return 99
