from app.data.database.item_components import ItemComponent, ItemTags
from app.data.database.components import ComponentType

from app.utilities import utils
from app.engine import target_system, skill_system
from app.engine.game_state import game

class BlastAOE(ItemComponent):
    nid = 'blast_aoe'
    desc = "Blast extends outwards the specified number of tiles."
    tag = ItemTags.AOE

    expose = ComponentType.Int  # Radius
    value = 1

    def _get_power(self, unit) -> int:
        empowered_splash = skill_system.empower_splash(unit)
        return self.value + 1 + empowered_splash

    def splash(self, unit, item, position) -> tuple:
        ranges = set(range(self._get_power(unit)))
        splash = target_system.find_manhattan_spheres(ranges, position[0], position[1])
        splash = {pos for pos in splash if game.tilemap.check_bounds(pos)}
        from app.engine import item_system
        if item_system.is_spell(unit, item):
            # spell blast
            splash = [game.board.get_unit(s) for s in splash]
            splash = [s.position for s in splash if s]
            return None, splash
        else:
            # regular blast
            splash = [game.board.get_unit(s) for s in splash if s != position]
            splash = [s.position for s in splash if s]
            return position if game.board.get_unit(position) else None, splash

    def splash_positions(self, unit, item, position) -> set:
        ranges = set(range(self._get_power(unit)))
        splash = target_system.find_manhattan_spheres(ranges, position[0], position[1])
        splash = {pos for pos in splash if game.tilemap.check_bounds(pos)}
        return splash

class EnemyBlastAOE(BlastAOE, ItemComponent):
    nid = 'enemy_blast_aoe'
    desc = "Gives Blast AOE that only hits enemies"
    tag = ItemTags.AOE

    def splash(self, unit, item, position) -> tuple:
        ranges = set(range(self._get_power(unit)))
        splash = target_system.find_manhattan_spheres(ranges, position[0], position[1])
        splash = {pos for pos in splash if game.board.check_bounds(pos)}
        from app.engine import item_system, skill_system
        if item_system.is_spell(unit, item):
            # spell blast
            splash = [game.board.get_unit(s) for s in splash]
            splash = [s.position for s in splash if s and skill_system.check_enemy(unit, s)]
            return None, splash
        else:
            # regular blast
            splash = [game.board.get_unit(s) for s in splash if s != position]
            splash = [s.position for s in splash if s and skill_system.check_enemy(unit, s)]
            return position if game.board.get_unit(position) else None, splash

    def splash_positions(self, unit, item, position) -> set:
        from app.engine import skill_system
        ranges = set(range(self._get_power(unit)))
        splash = target_system.find_manhattan_spheres(ranges, position[0], position[1])
        splash = {pos for pos in splash if game.tilemap.check_bounds(pos)}
        # Doesn't highlight allies positions
        splash = {pos for pos in splash if not game.board.get_unit(pos) or skill_system.check_enemy(unit, game.board.get_unit(pos))}
        return splash

class AllyBlastAOE(BlastAOE, ItemComponent):
    nid = 'ally_blast_aoe'
    desc = "Gives Blast AOE that only hits allies"
    tag = ItemTags.AOE

    def splash(self, unit, item, position) -> tuple:
        ranges = set(range(self._get_power(unit)))
        splash = target_system.find_manhattan_spheres(ranges, position[0], position[1])
        splash = {pos for pos in splash if game.tilemap.check_bounds(pos)}
        from app.engine import skill_system
        splash = [game.board.get_unit(s) for s in splash]
        splash = [s.position for s in splash if s and skill_system.check_ally(unit, s)]
        return None, splash

class SmartBlastAOE(BlastAOE, ItemComponent):
    nid = 'smart_blast_aoe'
    desc = "Gives Enemy Blast AOE for items that target enemies, and Ally Blast AOE for items that target allies"
    tag = ItemTags.AOE

    def splash(self, unit, item, position) -> tuple:
        if 'target_ally' in item.components.keys():
            return AllyBlastAOE.splash(self, unit, item, position)
        elif 'target_enemy' in item.components.keys():
            return EnemyBlastAOE.splash(self, unit, item, position)
        else:
            return BlastAOE.splash(self, unit, item, position)

    def splash_positions(self, unit, item, position) -> set:
        if 'target_ally' in item.components.keys():
            return AllyBlastAOE.splash_positions(self, unit, item, position)
        elif 'target_enemy' in item.components.keys():
            return EnemyBlastAOE.splash_positions(self, unit, item, position)
        else:
            return BlastAOE.splash_positions(self, unit, item, position)

class EquationBlastAOE(BlastAOE, ItemComponent):
    nid = 'equation_blast_aoe'
    desc = "Gives Equation-Sized Blast AOE"
    tag = ItemTags.AOE

    expose = ComponentType.Equation  # Radius
    value = None

    def _get_power(self, unit) -> int:
        from app.engine import equations
        value = equations.parser.get(self.value, unit)
        empowered_splash = skill_system.empower_splash(unit)
        return value + 1 + empowered_splash

class AllyEquationBlastAOE(AllyBlastAOE, EquationBlastAOE, ItemComponent):
    nid = 'ally_equation_blast_aoe'
    desc = "Gives Equation-Sized Blast AOE that only hits allies"
    tag = ItemTags.AOE

    expose = ComponentType.Equation  # Radius
    value = None

class EnemyCleaveAOE(ItemComponent):
    nid = 'enemy_cleave_aoe'
    desc = "All enemies within one tile (or diagonal from the user) are affected by this attack's AOE."
    tag = ItemTags.AOE

    def splash(self, unit, item, position) -> tuple:
        from app.engine import skill_system
        pos = unit.position
        all_positions = {(pos[0] - 1, pos[1] - 1),
                         (pos[0], pos[1] - 1),
                         (pos[0] + 1, pos[1] - 1),
                         (pos[0] - 1, pos[1]),
                         (pos[0] + 1, pos[1]),
                         (pos[0] - 1, pos[1] + 1),
                         (pos[0], pos[1] + 1),
                         (pos[0] + 1, pos[1] + 1)}

        all_positions = {pos for pos in all_positions if game.tilemap.check_bounds(pos)}
        all_positions.discard(position)
        splash = all_positions
        splash = [game.board.get_unit(pos) for pos in splash]
        splash = [s.position for s in splash if s and skill_system.check_enemy(unit, s)]
        main_target = position if game.board.get_unit(position) else None
        return main_target, splash

    def splash_positions(self, unit, item, position) -> set:
        from app.engine import skill_system
        pos = unit.position
        all_positions = {(pos[0] - 1, pos[1] - 1),
                         (pos[0], pos[1] - 1),
                         (pos[0] + 1, pos[1] - 1),
                         (pos[0] - 1, pos[1]),
                         (pos[0] + 1, pos[1]),
                         (pos[0] - 1, pos[1] + 1),
                         (pos[0], pos[1] + 1),
                         (pos[0] + 1, pos[1] + 1)}

        all_positions = {pos for pos in all_positions if game.tilemap.check_bounds(pos)}
        all_positions.discard(position)
        splash = all_positions
        # Doesn't highlight allies positions
        splash = {pos for pos in splash if not game.board.get_unit(pos) or skill_system.check_enemy(unit, game.board.get_unit(pos))}
        return splash

class AllAlliesAOE(ItemComponent):
    nid = 'all_allies_aoe'
    desc = "Item affects all allies on the map including user"
    tag = ItemTags.AOE

    def splash(self, unit, item, position) -> tuple:
        from app.engine import skill_system
        splash = [u.position for u in game.units if u.position and skill_system.check_ally(unit, u)]
        return None, splash

    def splash_positions(self, unit, item, position) -> set:
        # All positions
        splash = {(x, y) for x in range(game.tilemap.width) for y in range(game.tilemap.height)}
        return splash

class AllAlliesExceptSelfAOE(ItemComponent):
    nid = 'all_allies_except_self_aoe'
    desc = "Item affects all allies on the map except user"
    tag = ItemTags.AOE

    def splash(self, unit, item, position) -> tuple:
        from app.engine import skill_system
        splash = [u.position for u in game.units if u.position and skill_system.check_ally(unit, u) and u is not unit]
        return None, splash

    def splash_positions(self, unit, item, position) -> set:
        # All positions
        splash = {(x, y) for x in range(game.tilemap.width) for y in range(game.tilemap.height)}
        return splash

class AllEnemiesAOE(ItemComponent):
    nid = 'all_enemies_aoe'
    desc = "Item affects all enemies on the map"
    tag = ItemTags.AOE

    def splash(self, unit, item, position) -> tuple:
        from app.engine import skill_system
        splash = [u.position for u in game.units if u.position and skill_system.check_enemy(unit, u)]
        return None, splash

    def splash_positions(self, unit, item, position) -> set:
        from app.engine import skill_system
        # All positions
        splash = {(x, y) for x in range(game.tilemap.width) for y in range(game.tilemap.height)}
        # Doesn't highlight allies positions
        splash = {pos for pos in splash if not game.board.get_unit(pos) or skill_system.check_enemy(unit, game.board.get_unit(pos))}
        return splash

class LineAOE(ItemComponent):
    nid = 'line_aoe'
    desc = "A line is drawn from the user to the target, affecting each unit within it. Never extends past the target."
    tag = ItemTags.AOE

    def splash(self, unit, item, position) -> tuple:
        splash = set(utils.raytrace(unit.position, position))
        splash.discard(unit.position)
        splash = [game.board.get_unit(s) for s in splash]
        splash = [s.position for s in splash if s]
        return None, splash

    def splash_positions(self, unit, item, position) -> set:
        splash = set(utils.raytrace(unit.position, position))
        splash.discard(unit.position)
        return splash

class EnemyLineAOE(ItemComponent):
    nid = 'enemy_line_aoe'
    desc = "A line is drawn from the user to the target, affecting each enemy within it. Never extends past the target."
    tag = ItemTags.AOE

    def splash(self, unit, item, position) -> tuple:
        splash = set(utils.raytrace(unit.position, position))
        splash.discard(unit.position)
        splash = [game.board.get_unit(s) for s in splash]
        splash = [s.position for s in splash if s and skill_system.check_enemy(unit, s)]
        return None, splash

    def splash_positions(self, unit, item, position) -> set:
        splash = set(utils.raytrace(unit.position, position))
        splash.discard(unit.position)
        # Doesn't highlight allies positions
        splash = {pos for pos in splash if not game.board.get_unit(pos) or skill_system.check_enemy(unit, game.board.get_unit(pos))}
        return splash
