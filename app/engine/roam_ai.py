import logging
import math

from app.data.database.database import DB
from app.engine import (action, ai_controller, ai_state, engine, equations,
                        evaluate, skill_system, target_system)
from app.engine.game_state import game
from app.events import triggers
from app.events.regions import RegionType
from app.utilities import utils


class FreeRoamAIHandler():
    """Handles and selects all valid units with AI in free roam
    Will:
        Maintain a list of valid units to check on
        Reload that list only when asked
        Iterate through that list to fulfill objective of each unit

    self.targets = Set[Units]
    """

    def __init__(self):
        pass

    def update(self):
        for unit in self.targets:
            unit.ai.update()

class FreeRoamUnit():
    """A simple class focused on containing info
    for AI units in Free Roam"""
    def __init__(self, unit, ai):
        self.unit = unit
        self.ai = ai

class FreeRoamAIController(ai_controller.AIController):
    def __init__(self, unit):
        # Controls whether we should be skipping through the AI's turns
        self.do_skip: bool = False
        self.max_pause = 1000
        self.reset()
        self.unit = unit
        self.movement_manager = RoamMovementHandler(self.unit)
        self.ai = DB.ai.get(self.unit.get_roam_ai())

    def skip(self):
        self.do_skip = True

    def end_skip(self):
        self.do_skip = False

    def reset(self):
        self.unit = None
        self.state = None # Now an AIState subclass

        self.behaviour_idx = 0
        self.behaviour = None
        self.desired_proximity = 0

        self.did_something = False
        self.pause = self.max_pause

        self.path = None

    def stop_unit(self):
        """Halts the unit and tells the move manager to stop"""
        self.state = None
        self.path = None
        self.behaviour_idx = 0
        self.behaviour = None
        self.movement_manager.stop_unit()

    def clean_up(self):
        self.goal_item = None
        self.goal_target = None

    def set_next_behaviour(self):
        behaviours = self.ai.behaviours
        if not behaviours:
            return
        if self.behaviour_idx < len(behaviours):
            self.behaviour = behaviours[self.behaviour_idx]
            self.behaviour_idx += 1
        else:
            self.behaviour_idx = 0
            self.behaviour = behaviours[self.behaviour_idx]

    def load_unit(self, unit):
        self.reset()
        self.unit = unit

    def update(self):
        if self.state == None:
            self.think()
        else:
            self.act()

    def get_move_path(self, pos):
        """Finds the path from the unit's position to the target
        Ideally called rarely"""
        return target_system.get_path(self.unit, pos, free_movement=True)[:-1]

    def move(self):
        """Called every update. Calls the movement manager to actually implement the move
        Checks if the path should be recalculated"""
        if not self.state.target:
            return
        if utils.calculate_distance(game.board.rationalize_pos(self.unit.position), self.state.target) <= self.desired_proximity:
            self.path = None
            self.state = None
            self.movement_manager.stop_unit()
            return
        if self.goal_target and game.board.rationalize_pos(self.get_goal_position(self.goal_target)) != self.state.target:
            self.set_path()
        if self.behaviour.action == "Move_away_from":
            self.smart_retreat()
        if self.path:
            self.movement_manager.move()

    def get_targets(self):
        all_units = []
        all_positions = []
        if self.behaviour.target == 'Unit':
            all_units = [u for u in game.units if u.position]
        elif self.behaviour.target == 'Enemy':
            all_units = [u for u in game.units if u.position and skill_system.check_enemy(self.unit, u)]
        elif self.behaviour.target == 'Ally':
            all_units = [u for u in game.units if u.position and skill_system.check_ally(self.unit, u)]
        elif self.behaviour.target == 'Event':
            target_spec = self.behaviour.target_spec
            for region in game.level.regions:
                try:
                    if region.region_type == RegionType.EVENT and region.sub_nid == target_spec and (not region.condition or evaluate.evaluate(region.condition, self.unit, local_args={'region': region})):
                        all_positions += region.get_all_positions()
                except:
                    logging.warning("Region Condition: Could not parse %s" % region.condition)
            all_positions = list(set(all_positions))  # Remove duplicates
        elif self.behaviour.target == 'Position':
            if self.behaviour.target_spec == "Starting":
                if self.unit.starting_position:
                    all_positions = [self.unit.starting_position]
            else:
                all_positions = [tuple(self.behaviour.target_spec)]

        if self.behaviour.target in ('Unit', 'Enemy', 'Ally'):
            all_units = self.handle_roam_unit_spec(all_units, self.behaviour)
            if DB.constants.value('ai_fog_of_war'):
                all_targets = [unit.position for unit in all_units if game.board.in_vision(game.board.rationalize_pos(unit.position), self.unit.team)]
            else:
                all_targets = [unit.position for unit in all_units]
        else:
            all_targets = all_positions
        
        return all_targets

    def handle_roam_unit_spec(self, all_targets, behaviour):
        """A modified version of an AIController function
        Uses the unit instead of the unit's position
        This way we don't have to find the unit (which can't be done)"""
        target_spec = behaviour.target_spec
        if not target_spec:
            return all_targets
        invert = bool(behaviour.invert_targeting)
        # Uses ^ (which is XOR) to handle inverting the targeting
        if target_spec[0] == "Tag":
            all_targets = [unit for unit in all_targets if bool(target_spec[1] in unit.tags) ^ invert]
        elif target_spec[0] == "Class":
            all_targets = [unit for unit in all_targets if bool(unit.klass == target_spec[1]) ^ invert]
        elif target_spec[0] == "Name":
            all_targets = [unit for unit in all_targets if bool(unit.name == target_spec[1]) ^ invert]
        elif target_spec[0] == 'Faction':
            all_targets = [unit for unit in all_targets if bool(unit.faction == target_spec[1]) ^ invert]
        elif target_spec[0] == 'Party':
            all_targets = [unit for unit in all_targets if bool(unit.party == target_spec[1]) ^ invert]
        elif target_spec[0] == 'ID':
            all_targets = [unit for unit in all_targets if bool(unit.nid == target_spec[1]) ^ invert]
        elif target_spec[0] == 'Team':
            all_targets = [unit for unit in all_targets if bool(unit.team == target_spec[1]) ^ invert]
        return all_targets

    def prepare_move(self):
        """Happens when we first decide we'd like to move"""
        targets = self.get_targets()
        if targets:
            self.goal_target = targets[0]
            self.set_path()
            return self.get_target()
        else:
            self.state = None
            return None

    def get_target(self):
        return target_system.get_nearest_open_tile(self.unit, game.board.rationalize_pos(self.get_goal_position(self.goal_target)))

    def set_path(self):
        """Sets our goal and updates movement manager information"""
        target = self.get_target()
        if target:
            self.path = self.get_move_path(target)
            self.movement_manager.update_path(self.path)
            self.movement_manager.update_goal_pos(target)

    def get_goal_position(self, target):
        """Since we don't just have tuples as goals, this
        returns the position of the target"""
        if hasattr(target, 'position'):
            return target.position
        return target

    def wait(self):
        if engine.get_time() > self.state.time:
            self.state = None

    def interact(self):
        # Get region
        region = None
        rat_pos = game.board.rationalize_pos(self.state.unit.position)
        for r in game.level.regions:
            if r.contains(rat_pos) and r.region_type == RegionType.EVENT and r.sub_nid == self.behaviour.target_spec:
                try:
                    if not r.condition or evaluate.evaluate(r.condition, self.state.unit, position=rat_pos, local_args={'region': r}):
                        region = r
                        break
                except:
                    logging.warning("Could not evaluate region conditional %s" % r.condition)
        if region:
            did_trigger = game.events.trigger(triggers.RegionTrigger(region.sub_nid, self.state.unit, rat_pos, region))
            if not did_trigger:  # Just in case we need the generic one
                did_trigger = game.events.trigger(triggers.OnRegionInteract(self.state.unit, rat_pos, region))
            if did_trigger and region.only_once:
                action.do(action.RemoveRegion(region))
            if did_trigger:
                action.do(action.HasAttacked(self.unit))
        self.state = None

    def smart_retreat(self) -> bool:
        valid_positions = self.get_true_valid_moves()

        target_positions = self.get_targets()

        zero_move = max(target_system.find_potential_range(self.unit, True, True), default=0)
        single_move = zero_move + equations.parser.movement(self.unit)
        double_move = single_move + equations.parser.movement(self.unit)

        target_positions = {(self.get_goal_position(pos), utils.calculate_distance(self.unit.position, self.get_goal_position(pos))) for pos in target_positions}

        if self.behaviour.view_range == -4:
            pass
        elif self.behaviour.view_range == -3:
            target_positions = {(pos, mag) for pos, mag in target_positions if mag < double_move}
        elif self.behaviour.view_range == -2:
            target_positions = {(pos, mag) for pos, mag in target_positions if mag < single_move}
        elif self.behaviour.view_range == -1:
            target_positions = {(pos, mag) for pos, mag in target_positions if mag < zero_move}
        else:
            target_positions = {(pos, mag) for pos, mag in target_positions if mag < self.view_range}

        if target_positions and len(valid_positions) > 1:
            self.goal_target = utils.smart_farthest_away_pos(self.unit.position, valid_positions, target_positions)
            self.set_path()
            return self.get_target()
        return None

    def set_roam_info(self, behaviour):
        self.desired_proximity = behaviour.desired_proximity
        self.movement_manager.update_speed(behaviour.roam_speed)

    def act(self):
        if self.state.mtype == ai_state.AIAction.MOVE:
            self.move()
        elif self.state.mtype == ai_state.AIAction.WAIT:
            self.wait()
        elif self.state.mtype == ai_state.AIAction.INTERACT:
            self.interact()

    def think(self):
        time = engine.get_time()
        self.did_something = False

        logging.info("*** AI Thinking... ***")

        while True:
            # Can spend up to half a frame thinking
            over_time = engine.get_true_time() - time >= 8
            logging.info("Current State: %s", self.state)

            self.start_time = engine.get_time()
            logging.info("Starting AI with nid: %s, position: %s, class: %s, AI: %s", self.unit.nid, self.unit.position, self.unit.klass, self.unit.get_roam_ai())
            self.clean_up()
            # Get next behaviour
            self.set_next_behaviour()
            if self.behaviour:
                logging.info(self.behaviour.action)

                self.set_roam_info(self.behaviour)

                if self.behaviour.action == "None":
                    pass  # Try again
                elif self.behaviour.action == "Wait":
                    #self.goal_target = self.start_time + self.behaviour.target_spec
                    self.state = ai_state.WaitStruct(self.unit, self.start_time + self.behaviour.target_spec)
                elif self.behaviour.action == 'Move_to':
                    target = self.prepare_move()
                    if target:
                        self.state = ai_state.MoveToStruct(self.unit, target)
                    else:
                        return

                elif self.behaviour.action == 'Interact':
                    self.state = ai_state.InteractStruct(self.unit)
                elif self.behaviour.action == "Move_away_from":
                    target = self.smart_retreat()
                    if target:
                        self.state = ai_state.MoveToStruct(self.unit, target)
                    else:
                        return

            else:
                return

            if over_time:
                return

class RoamMovementHandler():
    def __init__(self, unit):
        # Controls the actual movement for roam units
        self.ai_speed = 20
        self.unit = unit
        self.last_move = 0
        self.path = []
        self.goal_position = None

        self.speed_divisor = 100

        self.speed = 0.0
        self.vspeed = 0.0
        self.hspeed = 0.0
        self.direction = [0, 0]

        self.sprite_dir_time = self.ai_speed * 4 # Used to reduce unit sprite flickering
        self.cur_sprite_time = self.sprite_dir_time

    def update_speed(self, speed: int):
        self.ai_speed = speed
        self.sprite_dir_time = self.ai_speed * 4

    def update_path(self, path):
        """Setter for self.path"""
        self.path = path

    def update_goal_pos(self, pos):
        """Setter for self.goal_position"""
        self.goal_position = pos

    def move(self):
        """Times to see if we should move. Changes sprite if we've reached goal"""
        if self.goal_position != game.board.rationalize_pos(self.unit.position):
            current_time = engine.get_time()
            pause_time = 20
            if current_time - self.last_move > pause_time:
                self.last_move = current_time
                if len(self.path) > 0:
                    self.handle_direction(self.unit.position, self.path[-1])
        else:
            self.stop_unit()

    def rationalization(self):
        """We want to end up in the exact correct position"""
        if self.goal_position != self.unit.position:
            current_time = engine.get_time()
            pause_time = 20
            if current_time - self.last_move > pause_time:
                self.last_move = current_time
                if len(self.path) > 0:
                    self.handle_direction(self.unit.position, self.path[-1], rationalizing=True)
        else:
            self.stop_unit()

    def stop_unit(self):
        """Halts the unit and all move-related activities"""
        self.path = []
        self.goal_position = None

        self.speed = 0.0
        self.vspeed = 0.0
        self.hspeed = 0.0
        self.direction = [0, 0]
        self.unit.sprite.change_state('normal')
        self.unit.sound.stop()

    def handle_direction(self, pos, next_pos, rationalizing=False):
        """Sets speed values and calls the move if they reach a threshold"""
        base_speed = 0.008
        base_accel = 0.008
        running_accel = 0.01
        max_speed = 0.15

        if next_pos[0] > pos[0]: # Going right
            self.hspeed = self.speed
        elif next_pos[0] < pos[0]: # Going left
            self.hspeed = -self.speed
        else:
            self.hspeed = 0

        if next_pos[1] > pos[1]: # Going up
            self.vspeed = self.speed
        elif next_pos[1] < pos[1]: # Going down
            self.vspeed = -self.speed
        else:
            self.vspeed = 0

        if self.speed < max_speed:
            self.speed += (base_accel * (self.ai_speed / self.speed_divisor))
        elif self.speed > max_speed:
            self.speed -= running_accel

        self.dir_collides(next_pos)

        rounded_pos = game.board.rationalize_pos(self.unit.position)

        # Actually move the unit
        if abs(self.hspeed) > base_speed or abs(self.vspeed) > base_speed or rationalizing:
            self.handle_move()

        if not rationalizing and self.path[-1] == rounded_pos:
            self.path.pop()

    def handle_move(self):
        """Changes the unit position and sprite"""
        self.make_move(self.hspeed, self.vspeed)
        self.cur_sprite_time -= self.ai_speed
        if self.cur_sprite_time <= 0 or self.unit.sprite.state == "normal":
            self.cur_sprite_time = self.sprite_dir_time
            self.unit.sprite.change_state('moving')
            self.unit.sprite.handle_net_position((self.hspeed, self.vspeed))

    def dir_collides(self, target_pos):
        """Prevents unit spasms when their positions are < self.speed away from an integer"""
        pos = self.unit.position
        rat_pos = (int(pos[0]), int(pos[1]))

        if abs(rat_pos[0] - target_pos[0]) < abs(rat_pos[1] - target_pos[1]):
            h = int(pos[0] + 1)
            if self.hspeed > 0 and pos[0] + 1 + self.hspeed > h + 1:
                self.hspeed = h + 1 - (pos[0] + 1)
            elif self.hspeed > 0 and pos[0] + 1 + self.hspeed > h + 1:
                self.hspeed = h + 1 - (pos[0] + 1)
            elif self.hspeed < 0 and pos[0] + self.hspeed < rat_pos[0]:
                self.hspeed = rat_pos[0] - pos[0]

        if abs(rat_pos[0] - target_pos[0]) > abs(rat_pos[1] - target_pos[1]):
            v = int(pos[1] + 1)
            if self.vspeed > 0 and pos[1] + 1 + self.vspeed > v + 1:
                self.vspeed = v + 1 - (pos[1] + 1)
            elif self.vspeed > 0 and pos[1] + 1 + self.vspeed > v + 1:
                self.vspeed = v + 1 - (pos[1] + 1)
            elif self.vspeed < 0 and pos[1] + self.vspeed < rat_pos[1]:
                self.vspeed = rat_pos[1] - pos[1]

    def make_move(self, dx, dy):
        """Changes the unit position"""
        x, y = self.unit.position
        self.unit.position = x + dx, y + dy

        rounded_pos = game.board.rationalize_pos(self.unit.position)
        if self.check_close(self.unit.position, rounded_pos):
            self.unit.position = rounded_pos

        self.unit.sound.play()

    def check_close(self, pos1, pos2):
        dis = 0.1
        if math.isclose(pos1[0], pos2[0], abs_tol=dis) and math.isclose(pos1[1], pos2[1], abs_tol=dis):
            return True
        return False