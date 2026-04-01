import logging

import app.engine.config as cf
from app.data.database.database import DB
from app.engine import action, engine, equations, skill_system
from app.engine.game_state import game
from app.engine.sound import get_sound_thread
from app.utilities import utils


class MovementData():
    def __init__(self, path, event, follow, muted=False, speed=0):
        self.path = path
        self.last_update = 0
        self.event = event
        self.follow = follow
        self.muted = muted
        self.speed = speed or cf.SETTINGS['unit_speed']

class MovementManager():
    def __init__(self):
        self.moving_units = {}
        self.camera_follow = None

        self.surprised = False

    def add(self, unit, path, event=False, follow=True, speed=0):
        self.moving_units[unit.nid] = MovementData(path, event, follow, speed=speed)

    def begin_move(self, unit, path, event=False, follow=True, speed=0):
        logging.info("Unit %s begin move: %s", unit.nid, path)
        self.add(unit, path, event, follow, speed=speed)
        unit.sprite.set_speed(int(speed))
        unit.sprite.change_state('moving')
        game.leave(unit)
        unit.sound.play()

    def __len__(self):
        return len(self.moving_units)

    def get_last_update(self, nid):
        data = self.moving_units.get(nid)
        if data:
            return data.last_update
        else:
            return 0

    def get_next_position(self, nid):
        data = self.moving_units.get(nid)
        if data and data.path:
            return data.path[-1]
        else:
            return None

    def check_if_occupied_in_future(self, pos):
        for unit_nid, movement_data in self.moving_units.items():
            if movement_data.path and movement_data.path[0] == pos:
                return game.get_unit(unit_nid)
        return None

    @classmethod
    def get_movement_group(cls, unit_to_move):
        movement_group = skill_system.movement_type(unit_to_move)
        if not movement_group:
            movement_group = DB.classes.get(unit_to_move.klass).movement_group
        return movement_group

    def get_mcost(self, unit_to_move, pos) -> int:
        if DB.terrain:
            terrain_nid = game.get_terrain_nid(game.tilemap, pos)
            terrain = DB.terrain.get(terrain_nid)
            if not terrain:
                terrain = DB.terrain[0]
            if unit_to_move:
                movement_group = self.get_movement_group(unit_to_move)
            else:
                movement_group = DB.classes[0].movement_group
            mcost = DB.mcost.get_mcost(movement_group, terrain.mtype)
        else:
            mcost = 1
        return mcost

    def check_traversable(self, unit_to_move, pos) -> bool:
        if not game.board.check_bounds(pos):
            return False
        mcost = self.get_mcost(unit_to_move, pos)
        movement = equations.parser.movement(unit_to_move)
        return mcost <= movement

    def check_weakly_traversable(self, unit_to_move, pos) -> bool:
        if not game.board.check_bounds(pos):
            return False
        mcost = self.get_mcost(unit_to_move, pos)
        movement = equations.parser.movement(unit_to_move)
        return mcost <= 5 or mcost <= movement

    def check_simple_traversable(self, pos) -> bool:
        if not game.board.check_bounds(pos):
            return False
        mcost = self.get_mcost(None, pos)
        return mcost <= 5

    def check_position(self, unit, data, new_position) -> bool:
        """
        # Check if we run into an enemy
        # Returns True if position is OK
        """
        interrupted = self.check_region_interrupt(unit)
        if interrupted:
            return False
        if data.event:
            return True
        elif skill_system.pass_through(unit):
            # If this is the final position
            if not data.path and game.board.get_unit(new_position):
                return False
            else:
                return True
        else:
            other_team = game.board.get_team(new_position)
            if not other_team or utils.compare_teams(unit.team, other_team):
                return True # Allies, this is fine
            else:  # Enemies
                return False

    def done_moving(self, unit_nid, data, unit, surprise=False):
        if surprise:
            get_sound_thread().play_sfx('Surprise')
            unit.sprite.change_state('normal')
            unit.sprite.reset()
            action.do(action.HasAttacked(unit))
            if unit.team == 'player':
                self.surprised = True
                self.update_surprise()
            # If unit is an ai unit, their turn is now complete
            if game.ai.unit is unit:
                game.ai.interrupt()

        del self.moving_units[unit_nid]
        game.arrive(unit)
        if unit.sound:
            unit.sound.stop()
        if data.event:
            unit.sprite.change_state('normal')
            action.do(action.Reset(unit))
            action.do(action.UpdateFogOfWar(unit))
        else:
            unit.has_moved = True
        # Handle camera auto-follow
        if self.camera_follow == unit_nid:
            self.camera_follow = None

    def check_region_interrupt(self, unit) -> bool:
        '''Checks if the unit is in a region that interrupts. If so, checks if the trigger conditions for the region are met. If so, runs the even and removes the region if appropriate.
        Returns true if the unit was interrupted, false otherwise.'''
        for region in game.level.regions:
            if region.contains(unit.position) and region.interrupt_move:
                return True
        return False

    def update_surprise(self):
        game.state.clear()
        game.state.change('free')
        game.state.change('wait')

    def update(self):
        current_time = engine.get_time()
        for unit_nid in list(self.moving_units.keys()):
            data = self.moving_units[unit_nid]
            if current_time - data.last_update > int(data.speed):
                data.last_update = current_time
                unit = game.get_unit(unit_nid)
                if not unit:
                    logging.error("Could not find unit with nid %s", unit_nid)
                    del self.moving_units[unit_nid]
                    continue
                elif not unit.position:
                    logging.error("Unit with nid %s is no longer on the map", unit_nid)
                    del self.moving_units[unit_nid]
                    continue

                if data.path:
                    new_position = data.path.pop()
                    if unit.position != new_position:
                        if self.check_position(unit, data, new_position):
                            logging.debug("%s moved to %s", unit, new_position)
                        else:  # Can only happen when not in an event
                            logging.debug("%s done moving", unit)
                            self.done_moving(unit_nid, data, unit, surprise=True)
                            continue

                        mcost = self.get_mcost(unit, new_position)
                        unit.consume_movement(mcost)
                    unit.position = new_position
                    # Handle camera following moving unit
                    # if not data.event:
                    if data.follow and not self.camera_follow:
                        self.camera_follow = unit_nid
                    if self.camera_follow == unit_nid:
                        if game.board and game.board.check_bounds(unit.position):
                            game.cursor.set_pos(unit.position)
                        if data.event:
                            game.camera.set_center(*unit.position)

                else: # Path is empty, so we are done
                    surprise = self.check_region_interrupt(unit)
                    self.done_moving(unit_nid, data, unit, surprise=surprise)
