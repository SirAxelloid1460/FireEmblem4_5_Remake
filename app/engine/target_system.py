from __future__ import annotations
from typing import FrozenSet, TYPE_CHECKING, List, Tuple
from functools import lru_cache

from app.data.database.database import DB
from app.engine import (combat_calcs, equations, item_funcs, item_system,
                        line_of_sight, skill_system)
from app.engine.pathfinding import pathfinding
from app.engine.game_state import game
from app.utilities import utils

if TYPE_CHECKING:
    from app.engine.objects.unit import UnitObject
    from app.engine.objects.item import ItemObject


# Consider making these sections faster
def get_shell(valid_moves: set, potential_range: set, bounds: Tuple[int, int, int, int], manhattan_restriction: set = None) -> set:
    valid_attacks = set()
    if manhattan_restriction:
        for valid_move in valid_moves:
            valid_attacks |= restricted_manhattan_spheres(potential_range, valid_move[0], valid_move[1], manhattan_restriction)
    else:
        for valid_move in valid_moves:
            valid_attacks |= find_manhattan_spheres(potential_range, valid_move[0], valid_move[1])
    return {pos for pos in valid_attacks if bounds[0] <= pos[0] <= bounds[2] and bounds[1] <= pos[1] <= bounds[3]}

def restricted_manhattan_spheres(rng: set, x: int, y: int, manhattan_restriction: set) -> set:
    sphere = cached_base_manhattan_spheres(frozenset(rng))
    sphere = {(a + x, b + y) for (a, b) in sphere if (a, b) in manhattan_restriction}
    return sphere

# Consider making these sections faster -- use memory?
def find_manhattan_spheres(rng: set, x: int, y: int) -> set:
    sphere = cached_base_manhattan_spheres(frozenset(rng))
    sphere = {(a + x, b + y) for (a, b) in sphere}
    return sphere

@lru_cache(1024)
def cached_base_manhattan_spheres(rng: FrozenSet[int]) -> set:
    _range = range
    _abs = abs
    sphere = set()
    for r in rng:
        for i in _range(-r, r+1):
            magn = _abs(i)
            dx = i
            dy = r - magn
            sphere.add((dx, dy))
            sphere.add((dx, -dy))
    return sphere


def get_nearest_open_tile(unit, position):
    r = 0
    _abs = abs
    while r < 10:
        for x in range(-r, r + 1):
            magn = _abs(x)
            n1 = position[0] + x, position[1] + r - magn
            n2 = position[0] + x, position[1] - r + magn
            if game.movement.check_weakly_traversable(unit, n1) and not game.board.get_unit(n1) and not game.movement.check_if_occupied_in_future(n1):
                return n1
            elif game.movement.check_weakly_traversable(unit, n2) and not game.board.get_unit(n2) and not game.movement.check_if_occupied_in_future(n2):
                return n2
        r += 1
    return None

def get_nearest_open_tile_rationalization(unit, position, taken_positions):
    r = 0
    _abs = abs
    while r < 10:
        for x in range(-r, r + 1):
            magn = _abs(x)
            n1 = position[0] + x, position[1] + r - magn
            n2 = position[0] + x, position[1] - r + magn
            if game.movement.check_weakly_traversable(unit, n1) and not game.board.get_unit(n1) and not n1 in taken_positions:
                return n1
            elif game.movement.check_weakly_traversable(unit, n2) and not game.board.get_unit(n2) and not n2 in taken_positions:
                return n2
        r += 1
    return None

def distance_to_closest_enemy(unit, pos=None):
    if pos is None:
        pos = unit.position
    enemy_list = [u for u in game.units if u.position and skill_system.check_enemy(u, unit)]
    if not enemy_list:
        return 100  # No enemies
    dist_list = [utils.calculate_distance(enemy.position, pos) for enemy in enemy_list]
    return min(dist_list)

def get_adjacent_positions(pos):
    x, y = pos
    adjs = ((x, y - 1), (x - 1, y), (x + 1, y), (x, y + 1))
    return [a for a in adjs if game.board.check_bounds(a)]

def get_adj_units(unit) -> list:
    adj_positions = get_adjacent_positions(unit.position)
    adj_units = [game.board.get_unit(pos) for pos in adj_positions]
    adj_units = [u for u in adj_units if u]
    return adj_units

def get_adj_allies(unit) -> list:
    adj_units = get_adj_units(unit)
    adj_allies = [u for u in adj_units if skill_system.check_ally(unit, u)]
    return adj_allies

def get_attacks(unit: UnitObject, item: ItemObject = None, force=False) -> set:
    """
    Determines all possible positions the unit could attack
    Does not attempt to determine if an enemy is actually in that place
    """
    if not force and unit.has_attacked:
        return set()
    if not item:
        item = unit.get_weapon()
    if not item:
        return set()
    no_attack_after_move = item_system.no_attack_after_move(unit, item) or skill_system.no_attack_after_move(unit)
    if no_attack_after_move and unit.has_moved_any_distance:
        return set()

    item_range = item_funcs.get_range(unit, item)
    if not item_range:
        return set()

    if max(item_range) >= 99:
        attacks = {(x, y) for x in range(game.tilemap.width) for y in range(game.tilemap.height)}
    else:
        manhattan_restriction = item_system.range_restrict(unit, item)
        attacks = get_shell({unit.position}, item_range, game.board.bounds, manhattan_restriction)

    return attacks
    
def _get_all_attacks(unit, valid_moves, items) -> (set, int):
    attacks = set()
    max_range = 0
    for item in items:
        no_attack_after_move = item_system.no_attack_after_move(unit, item) or skill_system.no_attack_after_move(unit)
        if no_attack_after_move and unit.has_moved_any_distance:
            continue
        item_range = item_funcs.get_range(unit, item)
        if not item_range:  # Possible if you have a weapon with say range 2-3 but your maximum range is limited to 1
            continue
        max_range = max(max_range, max(item_range))
        if max_range >= 99:
            attacks = {(x, y) for x in range(game.tilemap.width) for y in range(game.tilemap.height)}
        else:
            manhattan_restriction = item_system.range_restrict(unit, item)
            if no_attack_after_move:
                attacks |= get_shell({unit.position}, item_range, game.board.bounds, manhattan_restriction)
            else:
                attacks |= get_shell(valid_moves, item_range, game.board.bounds, manhattan_restriction)
    return (attacks, max_range)
    
def _get_possible_attacks(unit, valid_moves, items):
    items_standard, items_ignore_los = [], []
    for item in items:
        (items_standard, items_ignore_los)[item_system.ignore_line_of_sight(unit, item)].append(item)
    # First get all attacks by items that obey line of sight
    attacks, max_range = _get_all_attacks(unit, valid_moves, items_standard)
    # max_range is used only for making line of sight calculation faster
    # Filter away those that aren't in line of sight
    if DB.constants.value('line_of_sight'):
        attacks = set(line_of_sight.line_of_sight(valid_moves, attacks, max_range))
    # Now get all attacks by items that ignore line of sight
    attacks2, _ = _get_all_attacks(unit, valid_moves, items_ignore_los)
    attacks |= attacks2
    return attacks

def get_possible_attacks(unit, valid_moves) -> set:
    return _get_possible_attacks(unit, valid_moves, get_all_weapons(unit))

def get_possible_spell_attacks(unit, valid_moves) -> set:
    return _get_possible_attacks(unit, valid_moves, get_all_spells(unit))

# Uses all weapons the unit has access to to find its potential range
def find_potential_range(unit, weapon=True, spell=False, boundary=False) -> set:
    if weapon and spell:
        items = [item for item in unit.items if item_funcs.available(unit, item) and
                 item_system.is_weapon(unit, item) or item_system.is_spell(unit, item)]
    elif weapon:
        items = get_all_weapons(unit)
    elif spell:
        items = get_all_spells(unit)
    else:
        return set()
    potential_range = set()
    for item in items:
        for rng in item_funcs.get_range(unit, item):
            potential_range.add(rng)
    return potential_range

def get_valid_moves(unit, force=False, witch_warp=True) -> set:
    # Assumes unit is on the map
    if not force and unit.finished:
        return set()
    from app.engine.movement import MovementManager
    mtype = MovementManager.get_movement_group(unit)
    grid = game.board.get_grid(mtype)
    bounds = game.board.bounds
    height = game.board.height
    start_pos = game.board.rationalize_pos(unit.position)
    pathfinder = pathfinding.Djikstra(start_pos, grid, bounds, height, unit.team)
    movement_left = equations.parser.movement(unit) if force else unit.movement_left

    if skill_system.pass_through(unit):
        can_move_through = lambda team, adj: True
    else:
        can_move_through = game.board.can_move_through
    valid_moves = pathfinder.process(can_move_through, movement_left)
    valid_moves.add(unit.position)
    if witch_warp:
        witch_warp = set(skill_system.witch_warp(unit))
        valid_moves |= witch_warp
    return valid_moves

def get_path(unit, position, ally_block=False, use_limit=False, free_movement=False) -> list:
    from app.engine.movement import MovementManager
    mtype = MovementManager.get_movement_group(unit)
    grid = game.board.get_grid(mtype)
    start_pos = unit.position
    if free_movement:
        start_pos = game.board.rationalize_pos(start_pos)

    bounds = game.board.bounds
    height = game.board.height

    if skill_system.pass_through(unit):
        can_move_through = lambda team, adj: True
    else:
        if ally_block:
            can_move_through = game.board.can_move_through_ally_block
        else:
            can_move_through = game.board.can_move_through

    pathfinder = pathfinding.AStar(start_pos, position, grid, bounds, height, unit.team, free_movement)

    limit = unit.movement_left if use_limit else None
    path = pathfinder.process(can_move_through, limit=limit)
    if path is None:
        return []
    return path

def check_path(unit, path) -> bool:
    movement = unit.movement_left
    prev_pos = None
    for pos in path[:-1]:  # Don't need to count the starting position
        if prev_pos and pos not in get_adjacent_positions(prev_pos):
            return False
        mcost = game.movement.get_mcost(unit, pos)
        movement -= mcost
        if movement < 0:
            return False
        prev_pos = pos
    return True

def travel_algorithm(path, moves, unit, grid):
    """
    Given a long path, travels along that path as far as possible
    """
    if not path:
        return unit.position

    moves_left = moves
    through_path = 0
    for position in path[::-1][1:]:  # Remove start position, travel backwards
        moves_left -= grid[position[0] * game.tilemap.height + position[1]].cost
        if moves_left >= 0:
            through_path += 1
        else:
            break
    # Don't move where a unit already is, and don't make through path < 0
    # Lower the through path by one, cause we can't move that far
    while through_path > 0 and any(other_unit.position == path[-(through_path + 1)] for other_unit in game.units if unit is not other_unit):
        through_path -= 1
    return path[-(through_path + 1)]  # Travel as far as we can

def get_valid_targets(unit, item=None) -> set:
    """
    Determines all the valid targets given use of the item
    item_system.valid_targets takes care of range
    """
    if not item:
        item = unit.get_weapon()
    if not item:
        return set()
    if ((item_system.no_attack_after_move(unit, item) or skill_system.no_attack_after_move(unit))
         and unit.has_moved_any_distance):
        return set()
    # Check sequence item targeting
    if item.sequence_item:
        all_targets = set()
        for subitem in item.subitems:
            valid_targets = get_valid_targets(unit, subitem)
            if not valid_targets:
                return set()
            all_targets |= valid_targets
        if not item_system.allow_same_target(unit, item) and len(all_targets) < sum(1 if item_system.allow_less_than_max_targets(unit, si) else item_system.num_targets(unit, si) for si in item.subitems):
            return set()

    # Handle regular item targeting
    all_targets = item_system.valid_targets(unit, item)
    valid_targets = set()
    for position in all_targets:
        splash = item_system.splash(unit, item, position)
        valid = item_system.target_restrict(unit, item, *splash)
        if valid:
            valid_targets.add(position)
    # Fog of War
    if unit.team == 'player' or DB.constants.value('ai_fog_of_war'):
        valid_targets = {position for position in valid_targets if game.board.in_vision(position, unit.team)}
    # Line of Sight
    if DB.constants.value('line_of_sight') and not item_system.ignore_line_of_sight(unit, item):
        item_range = item_funcs.get_range(unit, item)
        if item_range:
            max_item_range = max(item_range)
            valid_targets = set(line_of_sight.line_of_sight([unit.position], valid_targets, max_item_range))
        else: # I think this is impossible to happen, as it is checked in various places above in this function
            valid_targets = set()
    # Make sure we have enough targets to satisfy the item
    if not item_system.allow_same_target(unit, item) and \
            not item_system.allow_less_than_max_targets(unit, item) and \
            len(valid_targets) < item_system.num_targets(unit, item):
        return set()
    return valid_targets

def get_valid_targets_recursive_with_availability_check(unit, item) -> set:
    if item.multi_item:
        items = [sitem for sitem in item_funcs.get_all_items_from_multi_item(unit, item) if item_funcs.available(unit, sitem)]
    else:
        items = [item] if item_funcs.available(unit, item) else []
    valid_targets = set()
    for sitem in items:
        valid_targets |= get_valid_targets(unit, sitem)
    return valid_targets

def get_weapons(unit: UnitObject) -> List[ItemObject]:
    return [item for item in unit.items if item_funcs.is_weapon_recursive(unit, item) and item_funcs.available(unit, item)]

def get_all_weapons(unit: UnitObject) -> List[ItemObject]:
    return [item for item in item_funcs.get_all_items(unit) if item_system.is_weapon(unit, item) and item_funcs.available(unit, item)]

def get_all_targets_with_items(unit, items: List[ItemObject]) -> set:
    targets = set()
    for item in items:
        targets |= get_valid_targets(unit, item)
    return targets

def get_all_weapon_targets(unit) -> set:
    weapons = get_all_weapons(unit)
    return get_all_targets_with_items(unit, weapons)

def get_spells(unit: UnitObject) -> List[ItemObject]:
    return [item for item in unit.items if item_funcs.is_spell_recursive(unit, item) and item_funcs.available(unit, item)]

def get_all_spells(unit):
    return [item for item in item_funcs.get_all_items(unit) if item_system.is_spell(unit, item) and item_funcs.available(unit, item)]

def get_all_spell_targets(unit) -> set:
    spells = get_all_spells(unit)
    return get_all_targets_with_items(unit, spells)

def find_strike_partners(attacker, defender, item):
    '''Finds and returns a tuple of strike partners for the specified units
    First item in tuple is attacker partner, second is target partner
    Returns a tuple of None if no valid partner'''
    if not DB.constants.value('pairup'):
        return None, None
    if not attacker or not defender:
        return None, None
    if skill_system.check_ally(attacker, defender): # If targeting an ally
        return None, None
    if attacker.traveler or defender.traveler: # Dual guard cancels
        return None, None
    if not item_system.is_weapon(attacker, item): # If you're healing someone else
        return None, None
    if attacker.team == defender.team: # If you are the same team. Catches components who define their own check_ally function
        return None, None

    attacker_partner = None
    defender_partner = None
    attacker_adj_allies = get_adj_allies(attacker)
    attacker_adj_allies = [ally for ally in attacker_adj_allies if ally.get_weapon() and not item_system.cannot_dual_strike(ally, ally.get_weapon())]
    defender_adj_allies = get_adj_allies(defender)
    defender_adj_allies = [ally for ally in defender_adj_allies if ally.get_weapon() and not item_system.cannot_dual_strike(ally, ally.get_weapon())]
    attacker_partner = strike_partner_formula(attacker_adj_allies, attacker, defender, 'attack', (0, 0))
    defender_partner = strike_partner_formula(defender_adj_allies, defender, attacker, 'defense', (0, 0))

    if item_system.cannot_dual_strike(attacker, item):
        attacker_partner = None
    if defender.get_weapon() and item_system.cannot_dual_strike(defender, defender.get_weapon()):
        defender_partner = None
    if DB.constants.value('player_pairup_only'):
        if attacker.team != 'player':
            attacker_partner = None
        if defender.team != 'player':
            defender_partner = None

    if attacker_partner is defender_partner:
        # If both attacker and defender have the same partner something is weird
        return None, None
    return attacker_partner, defender_partner

def strike_partner_formula(allies: list, attacker, defender, mode, attack_info):
    '''
    This is the formula for the best choice to make
    when autoselecting strike partners
    '''
    if not allies:
        return None
    damage = [combat_calcs.compute_assist_damage(ally, defender, ally.get_weapon(), defender.get_weapon(), mode, attack_info) for ally in allies]
    accuracy = [utils.clamp(combat_calcs.compute_hit(ally, defender, ally.get_weapon(), defender.get_weapon(), mode, attack_info)/100., 0, 1) for ally in allies]
    score = [dam * acc for dam, acc in zip(damage, accuracy)]
    max_score = max(score)
    max_index = score.index(max_score)
    return allies[max_index]
