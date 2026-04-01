from __future__ import annotations
from app.engine.objects.item import ItemObject
from app.engine.text_evaluator import TextEvaluator

import logging
from typing import Any, Callable, Dict, List, Tuple

import app.engine.config as cf
import app.engine.graphics.ui_framework as uif
from app.constants import WINHEIGHT, WINWIDTH
from app.data.database.database import DB
from app.engine import (action, dialog, engine, evaluate,
                        target_system, item_funcs)
from app.engine.game_state import GameState
from app.engine.objects.overworld import OverworldNodeObject
from app.engine.objects.unit import UnitObject
from app.engine.sound import get_sound_thread
from app.events import event_commands, triggers
from app.events.event_portrait import EventPortrait
from app.utilities import str_utils, utils, static_random
from app.utilities.typing import NID

class Event():
    true_vals = ('t', 'true', 'True', '1', 'y', 'yes')

    skippable = {"speak", "wait", "bop_portrait",
                 "sound", "location_card", "credits", "ending"}

    def __init__(self, nid, commands, trigger: triggers.EventTrigger, game: GameState = None):
        self._transition_speed = 250
        self._transition_color = (0, 0, 0)

        self.nid = nid
        self.commands: List[event_commands.EventCommand] = commands.copy()
        self.command_idx = 0

        self.background = None

        event_args = trigger.to_args()
        self.unit = event_args.get('unit1', None)
        self.unit2 = event_args.get('unit2', None)
        self.created_unit = None
        self.position = event_args.get('position', None)
        self.local_args = event_args or {}
        if game:
            self.game = game
        else:
            from app.engine.game_state import game
            self.game = game

        self._generic_setup()

        self.text_evaluator = TextEvaluator(self.logger, self.game, self.unit, self.unit2, self.position, self.local_args)

    def _generic_setup(self):
        self.portraits: Dict[str, EventPortrait] = {}
        self.text_boxes: List[dialog.Dialog] = []
        self.other_boxes: List[Tuple[NID, Any]] = []
        self.overlay_ui = uif.UIComponent.create_base_component()
        self.overlay_ui.name = self.nid

        self.prev_state = None
        self.state = 'processing'

        self.turnwheel_flag = 0  # Whether to enter the turnwheel state after this event is finished
        self.battle_save_flag = 0  # Whether to enter the battle save state after this event is finished

        self.wait_time: int = 0

        # Handles keeping the order that unit sprites should be drawn
        self.priority_counter = 1
        self.do_skip = False
        self.super_skip = False

        self.if_stack = [] # Keeps track of how many ifs we've encountered while searching for the bad ifs 'end'.
        self.parse_stack = [] # Keeps track of whether we've encountered a truth this level or not

        # For transition
        self.transition_state = None
        self.transition_progress = 0
        self.transition_update = 0
        self.transition_speed = self._transition_speed
        self.transition_color = self._transition_color

        # For map animations
        self.animations = []

        # a way of passing key input events down to individual events
        # map between name of listener, and listener function
        self.functions_listening_for_input: Dict[str, Callable[[str]]] = {}

        # a way for any arbitrary event to block state processing until an arbitrary condition is fulfilled
        self.should_remain_blocked: List[Callable[[], bool]] = []

        # a method of queueing unblocked actions that require updating (e.g. movement)
        # update functions should return False once they are finished (so they can be removed from the queue)
        # they should receive an argument that represents whether or not we're in skip mode to facilitate skipping
        # and avoid infinite loops.
        # maps name to function
        self.should_update: Dict[str, Callable[[bool], bool]] = {}

        self.logger = logging.getLogger()

    @property
    def unit1(self):
        return self.unit

    def save(self):
        ser_dict = {}
        ser_dict['nid'] = self.nid
        ser_dict['commands'] = self.commands
        ser_dict['command_idx'] = self.command_idx
        ser_dict['unit1'] = self.unit.nid if self.unit else None
        ser_dict['unit2'] = self.unit2.nid if self.unit2 else None
        ser_dict['position'] = self.position
        ser_dict['local_args'] = {k: action.Action.save_obj(v) for k, v in self.local_args.items()}
        ser_dict['if_stack'] = self.if_stack
        ser_dict['parse_stack'] = self.parse_stack
        return ser_dict

    @classmethod
    def restore(cls, ser_dict, game: GameState):
        unit = game.get_unit(ser_dict['unit1'])
        unit2 = game.get_unit(ser_dict['unit2'])
        position = ser_dict['position']
        local_args = ser_dict.get('local_args', {})
        local_args = {k: action.Action.restore_obj(v) for k, v in local_args.items()}
        commands = ser_dict['commands']
        nid = ser_dict['nid']
        self = cls(nid, commands, triggers.GenericTrigger(unit, unit2, position, local_args), game)
        self.command_idx = ser_dict['command_idx']
        self.if_stack = ser_dict['if_stack']
        self.parse_stack = ser_dict['parse_stack']
        return self

    def update(self):
        # update all internal updates, remove the ones that are finished
        self.should_update = {name: to_update for name, to_update in self.should_update.items() if not to_update(self.do_skip)}

        # Update movement so that no_block works correctly
        if self.game.movement:
            self.game.movement.update()

        self._update_state()
        self._update_transition()

    def _update_state(self, dialog_log=True):
        current_time = engine.get_time()
        # Can move through its own internal state up to 5 times in a frame
        counter = 0
        while counter < 5:
            counter += 1
            if self.state != self.prev_state:
                self.prev_state = self.state
                self.logger.debug("Event State: %s", self.state)

            if self.state == 'waiting':
                if current_time > self.wait_time:
                    self.state = 'processing'
                else:
                    break

            elif self.state == 'processing':
                if self.command_idx >= len(self.commands):
                    self.end()
                else:
                    self.process()
                if self.state == 'paused':
                    break  # Necessary so we don't go right back to processing

            elif self.state == 'dialog':
                if self.text_boxes:
                    if self.text_boxes[-1].is_done():
                        if dialog_log:
                            action.do(action.LogDialog(self.text_boxes[-1]))
                        self.state = 'processing'
                        if self.text_boxes[-1].is_complete():
                            self.text_boxes.pop()
                    elif self.text_boxes[-1].is_paused():
                        self.state = 'processing'
                else:
                    self.state = 'processing'

            elif self.state == 'paused':
                self.state = 'processing'

            elif self.state == 'almost_complete':
                if not self.game.movement or len(self.game.movement) <= 0:
                    self.state = 'complete'

            elif self.state == 'complete':
                break

            elif self.state == 'blocked':
                # state is blocked; try to unblock
                should_still_be_blocked = False
                for check_still_blocked in self.should_remain_blocked:
                    if check_still_blocked(): # we haven't fulfilled unblock conditions
                        should_still_be_blocked = True
                        break
                if should_still_be_blocked:
                    break
                else:
                    # resume execution and clear blockers
                    self.should_remain_blocked.clear()
                    self.state = 'processing'

    def _update_transition(self):
        current_time = engine.get_time()
        # Handle transition
        if self.transition_state:
            perc = (current_time - self.transition_update) / self.transition_speed
            if self.transition_state == 'open':
                perc = 1 - perc
            self.transition_progress = utils.clamp(perc, 0, 1)
            if perc < 0:
                self.transition_state = None

    def take_input(self, event):
        if event == 'START' or event == 'BACK':
            get_sound_thread().play_sfx('Select 4')
            self.skip(event == 'START')

        elif event == 'SELECT' or event == 'RIGHT' or event == 'DOWN':
            if self.state == 'dialog':
                if not cf.SETTINGS['talk_boop']:
                    get_sound_thread().play_sfx('Select 1')
                self.hurry_up()

        for listener in self.functions_listening_for_input.values():
            listener(event)

    def draw(self, surf):
        self.animations = [anim for anim in self.animations if not anim.update()]
        for anim in self.animations:
            anim.draw(surf, offset=(-self.game.camera.get_x(), -self.game.camera.get_y()))

        if self.background:
            self.background.draw(surf)

        delete = [key for key, portrait in self.portraits.items() if portrait.update()]
        for key in delete:
            del self.portraits[key]

        # draw all uiframework elements
        ui_surf = self.overlay_ui.to_surf()
        surf.blit(ui_surf, (0, 0))

        sorted_portraits = sorted(self.portraits.values(), key=lambda x: x.priority)
        for portrait in sorted_portraits:
            if 'Narration' in self.nid:
                portrait.draw_chibi(surf)
            else:
                portrait.draw(surf)

        # Draw other boxes
        self.other_boxes = [(nid, box) for (nid, box) in self.other_boxes if box.update()]
        for _, box in self.other_boxes:
            box.draw(surf)

        # Draw text/dialog boxes
        # if self.state == 'dialog':
        if not self.do_skip:
            to_draw = []
            for dialog_box in reversed(self.text_boxes):
                if not dialog_box.is_complete():
                    to_draw.insert(0, dialog_box)
                if dialog_box.solo_flag:
                    break
            for dialog_box in to_draw:
                dialog_box.update()
                dialog_box.draw(surf)

        # Fade to black
        if self.transition_state:
            s = engine.create_surface((WINWIDTH, WINHEIGHT), transparent=True)
            s.fill((*self.transition_color, int(255 * self.transition_progress)))
            surf.blit(s, (0, 0))

        return surf

    def end(self):
        self.state = 'almost_complete'

    def process(self):
        while self.command_idx < len(self.commands) and self.state == 'processing':
            command = self.commands[self.command_idx]
            self.logger.debug("Run Event Command: %s", command)
            try:
                if self.handle_conditional(command):
                    if self.handle_loop(command):
                        pass  # Just builds the next commands
                    elif self.do_skip and command.nid in self.skippable:
                        pass
                    else:
                        self.run_command(command)
                self.command_idx += 1
            except Exception as e:
                raise Exception("Event execution failed with error in command %s" % command) from e

    def handle_loop(self, command: event_commands.EventCommand) -> bool:
        """
        Returns true if a loop was found
        """
        self.logger.disabled = False
        if command.nid == 'for':
            self.logger.info('%s: %s, %s', command.nid, command.parameters, command.chosen_flags)
            show_warning = True
            if 'no_warn' in command.chosen_flags:
                show_warning = False
            iterator_nid = command.parameters['Nid']
            cond = command.parameters['Expression']
            cond = self._evaluate_all(cond)
            try:
                arg_list = self.text_evaluator.direct_eval(cond)
                arg_list = [self._object_to_str(arg) for arg in arg_list]
            except Exception as e:
                self.logger.error("%s: Could not evaluate {%s} in %s" % (e, command.parameters['Expression'], command.to_plain_text()))
                return True
            if not arg_list:
                if show_warning:
                    self.logger.warning("Arg list is empty for: %s in %s" % (command.parameters['Expression'], command.to_plain_text()))

            # template and paste all commands inside the for loop
            # to find the correct endf, we'll need to make sure that
            # every nested for-loop is accounted for
            internal_fors = 0

            curr_idx = self.command_idx + 1
            curr_command = self.commands[curr_idx]
            looped_commands: List[event_commands.EventCommand] = []
            while curr_command.nid != 'endf' or internal_fors > 0:
                if curr_command.nid == 'for':
                    internal_fors += 1
                if curr_command.nid == 'endf':
                    internal_fors -= 1
                looped_commands.append(curr_command)
                curr_idx += 1
                if curr_idx >= len(self.commands):
                    self.logger.error("%s: could not find endf command for loop %s" % ('handle_conditional', cond))
                    return True
                curr_command = self.commands[curr_idx]

            # remove the initial for-loop, as we've templated out all the child fors
            self.commands = self.commands[:self.command_idx + 1] + self.commands[curr_idx:]
            for arg in reversed(arg_list):
                for command in reversed(looped_commands):
                    new_command = command.__class__.copy(command)
                    if iterator_nid:
                        new_command.parameters = {k: v.replace('{' + iterator_nid + '}', arg) for k, v in new_command.parameters.items()}
                    self.commands.insert(self.command_idx + 1, new_command)
            return True
        # Skip endf command here
        elif command.nid == 'endf':
            return True
        return False

    def _get_truth(self, command: event_commands.EventCommand) -> bool:
        try:
            cond = command.parameters['Expression']
            cond = self._evaluate_all(cond)
            truth = bool(self.text_evaluator.direct_eval(cond))
        except Exception as e:
            self.logger.error("%s: Could not evaluate {%s} in %s" % (e, cond, command.to_plain_text()))
            truth = False
        self.logger.info("Result: %s" % truth)
        return truth

    def handle_conditional(self, command) -> bool:
        """
        Returns true if the processor should be processing this command
        """
        self.logger.disabled = False
        if command.nid == 'if':
            self.logger.info('%s: %s, %s', command.nid, command.parameters, command.chosen_flags)
            if not self.if_stack or self.if_stack[-1]:
                truth = self._get_truth(command)
                self.if_stack.append(truth)
                self.parse_stack.append(truth)
            else:
                self.if_stack.append(False)
                self.parse_stack.append(True)
            return False
        elif command.nid == 'elif':
            self.logger.info('%s: %s, %s', command.nid, command.parameters, command.chosen_flags)
            if not self.if_stack:
                self.logger.error("Syntax Error somewhere in script. 'elif' needs to be after if statement.")
                return False
            # If we haven't encountered a truth yet
            if not self.parse_stack[-1]:
                truth = self._get_truth(command)
                self.if_stack[-1] = truth
                self.parse_stack[-1] = truth
            else:
                self.if_stack[-1] = False
            return False
        elif command.nid == 'else':
            self.logger.info('%s: %s, %s', command.nid, command.parameters, command.chosen_flags)
            if not self.if_stack:
                self.logger.error("Syntax Error somewhere in script. 'else' needs to be after if statement.")
                return False
            # If the most recent is False but the rest below are non-existent or true
            if not self.parse_stack[-1]:
                self.if_stack[-1] = True
                self.parse_stack[-1] = True
            else:
                self.if_stack[-1] = False
            return False
        elif command.nid == 'end':
            self.logger.info('%s: %s, %s', command.nid, command.parameters, command.chosen_flags)
            if self.if_stack:
                self.if_stack.pop()
            if self.parse_stack:
                self.parse_stack.pop()
            return False

        if self.if_stack and not self.if_stack[-1]:
            return False
        return True

    def skip(self, super_skip=False):
        self.do_skip = True
        self.super_skip = super_skip
        if self.state != 'paused':
            self.state = 'processing'
        self.transition_state = None
        self.hurry_up()
        self.text_boxes.clear()
        self.other_boxes.clear()
        self.should_remain_blocked.clear()
        while self.should_update:
            self.should_update = {name: to_update for name, to_update in self.should_update.items() if not to_update(self.do_skip)}

    def hurry_up(self):
        if self.text_boxes:
            self.text_boxes[-1].hurry_up()

    def run_command(self, command: event_commands.EventCommand):
        from app.events.function_catalog import get_catalog

        self.logger.info('%s: %s, %s', command.nid, command.parameters, command.chosen_flags)

        parameters, flags = event_commands.convert_parse(command, self._evaluate_all)

        # Handle the weird cases where we don't want to handle evaluation
        if command.nid == 'choice':
            unevaled_parameters, _ = event_commands.convert_parse(command, None)
            parameters['Choices'] = unevaled_parameters['Choices']
        elif command.nid == 'table':
            unevaled_parameters, _ = event_commands.convert_parse(command, None)
            parameters['TableData'] = unevaled_parameters['TableData']
        elif command.nid == 'textbox':
            unevaled_parameters, _ = event_commands.convert_parse(command, None)
            parameters['Text'] = unevaled_parameters['Text']
        if 'no_warn' in flags:
            self.logger.disabled = True
        else:
            self.logger.disabled = False
        parameters = {str_utils.camel_to_snake(k): v for k, v in parameters.items()}
        self.logger.debug("%s, %s", parameters, flags)
        get_catalog()[command.nid](self, **parameters, flags=flags)

    def _object_to_str(self, obj) -> str:
        if hasattr(obj, 'uid'):
            return str(obj.uid)
        elif hasattr(obj, 'nid'):
            return str(obj.nid)
        else:
            return str(obj)

    def _evaluate_all(self, text: str) -> str:
        return self.text_evaluator._evaluate_all(text)

    def _queue_command(self, event_command_str: str):
        try:
            event_command, _ = event_commands.parse_text_to_command(event_command_str, strict=True)
            if not event_command:
                raise SyntaxError("Unable to parse command", ("event.py", 0, 0, event_command_str))
            self.commands.insert(self.command_idx + 1, event_command)
        except Exception as e:
            logging.error('_queue_command: Unable to parse command "%s". %s', event_command_str, e)

    def _place_unit(self, unit, position, entry_type, entry_direc=None):
        position = tuple(position)
        if self.do_skip:
            action.do(action.ArriveOnMap(unit, position))
        elif entry_type == 'warp':
            action.do(action.WarpIn(unit, position))
        elif entry_type == 'swoosh':
            action.do(action.SwooshIn(unit, position))
        elif entry_type == 'fade':
            action.do(action.FadeIn(unit, position, entry_direc))
        else:  # immediate
            action.do(action.ArriveOnMap(unit, position))

    def _move_unit(self, movement_type, placement, follow, unit, position):
        position = tuple(position)
        position = self._check_placement(unit, position, placement)
        if not position:
            self.logger.warning("Couldn't determine valid position for %s?", unit.nid)
            return
        if movement_type == 'immediate' or self.do_skip:
            action.do(action.Teleport(unit, position))
        elif movement_type == 'warp':
            action.do(action.Warp(unit, position))
        elif movement_type == 'fade':
            action.do(action.FadeMove(unit, position))
        elif movement_type == 'normal':
            if unit.position == position:
                # Don't bother if identical
                return
            path = target_system.get_path(unit, position)
            action.do(action.Move(unit, position, path, event=True, follow=follow))
        return position

    def _add_unit_from_direction(self, unit, position, direction, placement) -> bool:
        offsets = [-1, 1, -2, 2, -3, 3, -4, 4, -5, 5, -6, 6, -7, 7]
        final_pos = None

        if direction == 'west':
            test_pos = (0, position[1])
            for x in offsets:
                if self.game.movement.check_traversable(unit, test_pos):
                    final_pos = test_pos
                    break
                else:
                    test_pos = (0, position[1] + x)
        elif direction == 'east':
            test_pos = (self.game.tilemap.width - 1, position[1])
            for x in offsets:
                if self.game.movement.check_traversable(unit, test_pos):
                    final_pos = test_pos
                    break
                else:
                    test_pos = (self.game.tilemap.width - 1, position[1] + x)
        elif direction == 'north':
            test_pos = (position[0], 0)
            for x in offsets:
                if self.game.movement.check_traversable(unit, test_pos):
                    final_pos = test_pos
                    break
                else:
                    test_pos = (position[0] + x, 0)
        elif direction == 'south':
            test_pos = (position[0], self.game.tilemap.height - 1)
            for x in offsets:
                if self.game.movement.check_traversable(unit, test_pos):
                    final_pos = test_pos
                    break
                else:
                    test_pos = (position[1] + x, self.game.tilemap.height - 1)
        if final_pos:
            final_pos = self._check_placement(unit, final_pos, placement)
        if final_pos:
            action.do(action.ArriveOnMap(unit, final_pos))
            return True
        return False

    def _get_position(self, next_pos, unit, group, unit_nid=None):
        if unit_nid is None:
            unit_nid = unit.nid
        if not next_pos:
            position = group.positions.get(unit_nid)
        elif next_pos.lower() == 'starting':
            position = unit.starting_position
        elif ',' in next_pos:
            position = self._parse_pos(next_pos)
        else:
            other_group = self.game.level.unit_groups.get(next_pos)
            position = other_group.positions.get(unit_nid)
        return position

    def _check_placement(self, unit, position, placement):
        if not self.game.tilemap.check_bounds(position):
            self.logger.error("%s: position out of bounds %s", 'check_placement', position)
            return None
        current_occupant = self.game.board.get_unit(position)
        if not current_occupant:
            current_occupant = self.game.movement.check_if_occupied_in_future(position)
        if current_occupant:
            if placement == 'giveup':
                self.logger.warning("Check placement (giveup): Unit already present on tile %s", position)
                return None
            elif placement == 'stack':
                return position
            elif placement == 'closest':
                position = target_system.get_nearest_open_tile(unit, position)
                if not position:
                    self.logger.warning("Somehow wasn't able to find a nearby open tile")
                    return None
                return position
            elif placement == 'push':
                new_pos = target_system.get_nearest_open_tile(current_occupant, position)
                action.do(action.ForcedMovement(current_occupant, new_pos))
                return position
        else:
            return position

    def _copy_unit(self, unit_nid):
        level_prefab = DB.levels.get(self.game.level.nid)
        level_unit_prefab = level_prefab.units.get(unit_nid)
        if not level_unit_prefab:
            self.logger.warning("Could not find level unit prefab for unit with nid: %s", unit_nid)
            return None
        new_nid = str_utils.get_next_int(level_unit_prefab.nid, self.game.unit_registry.keys())
        new_unit = UnitObject.from_prefab(level_unit_prefab, self.game.current_mode, new_nid)
        new_unit.position = None
        new_unit.dead = False
        new_unit.party = self.game.current_party
        self.game.full_register(new_unit)
        return new_unit

    def _get_item_in_inventory(self, unit_nid: str, item: str, recursive=False) -> tuple[UnitObject, ItemObject]:
        if unit_nid.lower() == 'convoy':
            unit = self.game.get_party()
        else:
            unit = self._get_unit(unit_nid)
            if not unit:
                self.logger.error("Couldn't find unit with nid %s" % unit_nid)
                return None, None
        item_id = item
        if recursive:
            item_list = item_funcs.get_all_items_with_multiitems(unit.items)
        else:
            item_list = unit.items
        inids = [item.nid for item in item_list]
        iuids = [item.uid for item in item_list]
        if (item_id not in inids) and (not str_utils.is_int(item_id) or not int(item_id) in iuids):
            self.logger.error("Couldn't find item with id %s" % item)
            return None, None
        item = [item for item in item_list if (item.nid == item_id or (str_utils.is_int(item_id) and item.uid == int(item_id)))][0]
        return unit, item

    def _apply_stat_changes(self, unit, stat_changes, flags):
        klass = DB.classes.get(unit.klass)
        # clamp stat changes
        stat_changes = {k: utils.clamp(v, -unit.stats[k], klass.max_stats.get(k) - unit.stats[k]) for k, v in stat_changes.items()}

        immediate = 'immediate' in flags

        action.do(action.ApplyStatChanges(unit, stat_changes))
        if not immediate:
            self.game.memory['stat_changes'] = stat_changes
            self.game.exp_instance.append((unit, 0, None, 'stat_booster'))
            self.game.state.change('exp')
            self.state = 'paused'

    def _apply_growth_changes(self, unit, growth_changes):
        action.do(action.ApplyGrowthChanges(unit, growth_changes))

    def _parse_pos(self, text: str, is_float=False):
        position = None
        if ',' in text:
            text = text.replace(')', '').replace('(', '').replace('[', '').replace(']', '')
            if is_float:
                position = tuple(float(_) for _ in text.split(','))
            else:
                position = tuple(int(_) for _ in text.split(','))
        elif text == '{position}':
            position = self.position
        elif not self.game.is_displaying_overworld() and self._get_unit(text):
            position = self._get_unit(text).position
        elif self.game.is_displaying_overworld() and self._get_overworld_location_of_object(text):
            position = self._get_overworld_location_of_object(text).position
        elif text in self.game.level.regions.keys():
            return self.game.level.regions.get(text).position
        else:
            valid_regions = \
                [tuple(region.position) for region in self.game.level.regions
                 if text == region.sub_nid and region.position and
                 not self.game.board.get_unit(region.position)]
            if valid_regions:
                position = static_random.shuffle(valid_regions)[0]
        return position

    def _get_unit(self, text) -> UnitObject:
        if text in ('{unit}', '{unit1}'):
            return self.unit
        elif text == '{unit2}':
            return self.unit2
        elif text == '{created_unit}':
            return self.created_unit
        else:
            return self.game.get_unit(text)

    def _get_overworld_location_of_object(self, text, entity_only=False, node_only=False) -> OverworldNodeObject:
        if self.game.overworld_controller:
            if not node_only and text in self.game.overworld_controller.entities:
                entity_at_nid = self.game.overworld_controller.entities[text]
                if entity_at_nid:
                    return entity_at_nid.node

            if not entity_only and text in self.game.overworld_controller.nodes:
                node_at_nid = self.game.overworld_controller.nodes[text]
                if node_at_nid:
                    return node_at_nid
        return None

    def _saturate_portrait(self, portrait):
        for port in self.portraits.values():
            port.desaturate()
        portrait.saturate()
