from __future__ import annotations
from app.data.database.items import ItemPrefab
from app.data.database.levels import LevelPrefab
from app.data.database.skills import SkillPrefab

import re
from typing import TYPE_CHECKING, Dict, List, Optional, Tuple, Type

from app.data.database.database import Database
from app.editor.event_editor.event_inspector import EventInspectorEngine
from app.engine.fonts import FONT
from app.engine.graphics.ui_framework.ui_framework_layout import (HAlignment,
                                                                  VAlignment)
from app.events import event_commands
from app.events.screen_positions import horizontal_screen_positions, vertical_screen_positions
from app.data.resources.resources import Resources
from app.sprites import SPRITES
from app.utilities import str_utils
from app.utilities.enums import Alignments
from app.utilities.typing import NID, Point
from app.events.regions import RegionType as RegionTypeEnum

class Validator():
    desc = ""

    def __init__(self, db: Optional[Database]=None, resources: Optional[Resources]=None):
        self._db = db or Database()
        self._resources = resources or Resources()

    def validate(self, text, level):
        return text

    def valid_entries(self, level: Optional[NID] = None, text: Optional[str] = None) -> List[Tuple[Optional[str], NID]]:
        """Return a list of all known valid options for this validator
        in tuple (name, nid) format.

        Returns:
            List[Tuple[Optional[str], NID]]: A list of (name, nid) tuples that are valid for this type.
        """
        return []

    def convert(self, text: str):
        return text

class OptionValidator(Validator):
    valid: List[str] = []

    @property
    def desc(self) -> str:
        return "must be one of (`%s`)" % '`, `'.join(self.valid)

    def validate(self, text, level):
        if text.lower() in self.valid:
            return text
        return None

    def valid_entries(self, level: Optional[NID] = None, text: Optional[str] = None) -> List[Tuple[Optional[str], NID]]:
        return [(None, option) for option in self.valid]

class EvalValidator(Validator):
    """exists as a special subclass of validators"""

    tags = ['eval']

    def process_arg_text(self, text: str):
        eval_begin = text.find(':')
        eval_text = text[eval_begin+1:]
        # remove internal evals from consideration
        eval_text = re.sub(r'\{[^)]*\}', '', eval_text)
        return eval_text

class RawDataValidator(EvalValidator):
    desc = "must be a correct reference to raw data"
    tags = ['d', 'data']

    def validate(self, text, level):
        return text

    def valid_entries(self, level: Optional[NID] = None, text: Optional[str] = None) -> List[Tuple[Optional[str], NID]]:
        if not text:
            return []
        text = self.process_arg_text(text)
        nlevel = text.count('.')
        if nlevel == 0:
            return [(None, key) for key in self._db.raw_data.keys()]
        elif nlevel == 1:
            # we already have a raw data NID
            args = text.split('.')
            data_nid = args[0]
            raw_data_prefab = self._db.raw_data.get_prefab(data_nid)
            if not raw_data_prefab:
                return []
            # are we searching, or quering a specific row?
            if args[1].startswith('[') and raw_data_prefab.dtype == 'list': # searching across column space
                if args[1].endswith(']'): # finished searching
                    return []
                search_term = args[1].split(',')[-1].replace('[', '')
                if '=' in search_term: # we're matching in column space
                    search_col = search_term.split('=')[0]
                    if search_col not in raw_data_prefab.oattrs:
                        return []
                    return [(None, getattr(row, search_col)) for row in raw_data_prefab.value.values()]
                return [(None, oattr) for oattr in raw_data_prefab.oattrs]
            elif raw_data_prefab and raw_data_prefab.dtype in ['list', 'kv']: # searching for specific row nid
                return [(None, key) for key in raw_data_prefab.value.keys()]
        elif nlevel == 2:
            # this is a list type
            data_nid = text.split('.')[0]
            raw_data_prefab = self._db.raw_data.get_prefab(data_nid)
            if not raw_data_prefab:
                return []
            if raw_data_prefab and raw_data_prefab.dtype == 'list': # get its columns
                return [(None, oattr) for oattr in raw_data_prefab.oattrs]
        return []

class UnitFieldValidator(EvalValidator):
    desc = "must be a correct reference to fields on units"
    tags = ['f', 'field']

    def validate(self, text, level):
        return text

    def valid_entries(self, level: Optional[NID] = None, text: Optional[str] = None) -> List[Tuple[Optional[str], NID]]:
        text = self.process_arg_text(text)
        nlevel = text.count('.')
        if nlevel == 0: # we want to select a specific unit
            all_keys = set()
            all_keys.update(set(self._db.units.keys()))
            all_keys.update(set(self._db.classes.keys()))
            return [(None, key) for key in all_keys] + [(None, '_unit'), (None, '_unit2')]
        elif nlevel == 1:
            # we already have unit nid
            unit_nid = text.split('.')[0]
            if unit_nid in ['_unit', '_unit2']:
                # generic unit, get all keys
                all_keys = set()
                for unit in self._db.units:
                    all_keys.update(set([key for (key, _) in unit.fields]))
                for klass in self._db.classes:
                    all_keys.update(set([key for (key, _) in klass.fields]))
                return [(None, key) for key in all_keys]
            else:
                unit_prefab = self._db.units.get(unit_nid)
                if unit_prefab: # get its predefined field keys
                    return [(None, key) for (key, _) in unit_prefab.fields]
                else: # maybe try klass?
                    klass_prefab = self._db.classes.get(unit_nid)
                    if klass_prefab:
                        return [(None, key) for (key, _) in klass_prefab.fields]
        return []

class VarValidator(EvalValidator):
    desc = "must be a correct reference to an existing game_var or level_var"
    tags = ['v', 'var']

    def validate(self, text, level):
        return text

    def valid_entries(self, level: Optional[NID] = None, text: Optional[str] = None) -> List[Tuple[Optional[str], NID]]:
        vars_in_level = set(self._db.game_var_slots.keys())
        vars_in_level = vars_in_level | EventInspectorEngine(self._db.events).find_all_variables_in_level(level)
        return [(None, var_name) for var_name in vars_in_level]

class SkillAttrValidator(EvalValidator):
    desc = "expression to evaluate skill field"
    tags = ['s', 'skill']

    def validate(self, text, level):
        text = self.process_arg_text(text)
        if not '.' in text:
            return None
        skill_nid, attribute = text.split('.', 1)
        if not skill_nid in self._db.skills:
            return None
        skill = self._db.skills.get(skill_nid)
        if not attribute in dir(skill):
            return None
        return text

    def valid_entries(self, level: NID, text: str) -> List[Tuple[Optional[str], NID]]:
        text = self.process_arg_text(text)
        level = text.count('.')
        if level == 0: # we want to select a specific skill
            return [(None, key) for key in self._db.skills.keys()]
        elif level == 1:
            # we already have skill nid
            skill_nid = text.split('.')[0]
            skill_prefab = self._db.skills.get(skill_nid)
            if skill_prefab: # get all attrs of skill
                return [(None, key) for key in vars(skill_prefab)]
            else: # return common attrs from empty obj
                return [(None, key) for key in vars(SkillPrefab(None, None, None))]
        return []

class ItemAttrValidator(EvalValidator):
    desc = "expression to evaluate item field"
    tags = ['i', 'item']

    def validate(self, text, level):
        text = self.process_arg_text(text)
        if not '.' in text:
            return None
        item_nid, attribute = text.split('.', 1)
        if not item_nid in self._db.items:
            return None
        item = self._db.items.get(item_nid)
        if not attribute in dir(item):
            return None
        return text

    def valid_entries(self, level: NID, text: str) -> List[Tuple[Optional[str], NID]]:
        text = self.process_arg_text(text)
        nlevel = text.count('.')
        if nlevel == 0: # we want to select a specific item
            return [(None, key) for key in self._db.items.keys()]
        elif nlevel == 1:
            # we already have item nid
            item_nid = text.split('.')[0]
            item_prefab = self._db.items.get(item_nid)
            if item_prefab: # get all attrs of item
                return [(None, key) for key in vars(item_prefab)]
            else: # return common attrs from empty obj
                return [(None, key) for key in vars(ItemPrefab(None, None, None))]
        return []


class UnitField(Validator):
    desc = "can be nid of any unit field, including new ones"

    def validate(self, text, level):
        return text

    def valid_entries(self, level: NID, text: str) -> List[Tuple[Optional[str], NID]]:
        all_keys = set()
        for unit in self._db.units:
            all_keys.update(set([key for (key, _) in unit.fields]))
        return [(None, key) for key in all_keys]

class Achievement(Validator):
    desc = "can be any nid of an achievement"

    def validate(self, text, level):
        return text

    def valid_entries(self, level: Optional[NID] = None, text: Optional[str] = None) -> List[Tuple[Optional[str], NID]]:
        achs = EventInspectorEngine(self._db.events).find_all_calls_of_command(event_commands.CreateAchievement())
        slots = [(None, command.parameters['Nid']) for command in achs.values()]
        return slots

class GeneralVar(Validator):
    desc = "can be any nid"

    def validate(self, text, level):
        return text

    def valid_entries(self, level: Optional[NID] = None, text: Optional[str] = None) -> List[Tuple[Optional[str], NID]]:
        vars_in_level = set(self._db.game_var_slots.keys())
        vars_in_level = vars_in_level | EventInspectorEngine(self._db.events).find_all_variables_in_level(level)
        return [(None, var_name) for var_name in vars_in_level]

class EventFunction(Validator):
    desc = "must be a valid event function"

    def validate(self, text, level):
        command_nids = [command.nid for command in event_commands.get_commands()]
        if text in command_nids:
            return text
        return None

    def valid_entries(self, level: Optional[NID] = None, text: Optional[str] = None) -> List[Tuple[Optional[str], NID]]:
        valids = [(None, command.nid) for command in event_commands.get_commands()]
        return valids

class Expression(Validator):
    desc = "must be a valid Python expression to evaluate."

class Nid(Validator):
    """
    Any nid will do, because we cannot know what
    objects will have been created
    """
    pass

class Integer(Validator):
    def validate(self, text, level):
        if str_utils.is_int(text):
            return int(text)
        return None

class Float(Validator):
    desc = "Any number with a decimal"

    def validate(self, text, level):
        if str_utils.is_float(text):
            return text
        return None

    def convert(self, text: str):
        return float(text)

class PositiveInteger(Validator):
    desc = "must be a positive whole number"

    def validate(self, text, level):
        if str_utils.is_int(text) and int(text) > 0:
            return int(text)
        return None

class IntegerList(Validator):
    desc = "must be a comma-delimited list of integers (ie, `5,7,12`)"

    def validate(self, text, level):
        text = text.split(',')
        for t in text:
            if not str_utils.is_int(t):
                return None
        return text

class WholeNumber(Validator):
    desc = "must be a whole number"

    def validate(self, text, level):
        if str_utils.is_int(text) and int(text) >= 0:
            return int(text)
        return None

class String(Validator):
    """
    Any string will do
    """
    pass

class Time(Validator):
    def validate(self, text, level):
        if str_utils.is_int(text):
            return int(text)
        return None

    def convert(self, text: str) -> int:
        return int(text)

class Music(Validator):
    def validate(self, text, level):
        if text in self._resources.music.keys():
            return text
        elif text == 'None':
            return text
        return None

    def valid_entries(self, level: Optional[NID] = None, text: Optional[str] = None) -> List[Tuple[Optional[str], NID]]:
        valids = [(None, music.nid) for music in self._resources.music.values()]
        return valids

class Sound(Validator):
    def validate(self, text, level):
        if text in self._resources.sfx.keys():
            return text
        return None

    def valid_entries(self, level: Optional[NID] = None, text: Optional[str] = None) -> List[Tuple[Optional[str], NID]]:
        valids = [(None, sfx.nid) for sfx in self._resources.sfx.values()]
        return valids

class PhaseMusic(OptionValidator):
    valid = ['player_phase', 'enemy_phase', 'other_phase', 'enemy2_phase',
             'player_battle', 'enemy_battle', 'other_battle', 'enemy2_battle']

class Volume(Validator):
    desc = "A number between greater than 0 (0 is muted, 1 is current volume)"

    def validate(self, text, level):
        if str_utils.is_float(text) and float(text) >= 0:
            return float(text)
        return None

    def convert(self, text: str) -> float:
        return float(text)

class PortraitNid(Validator):
    def validate(self, text, level):
        if text in self._resources.portraits.keys():
            return text
        return None

    def valid_entries(self, level: Optional[NID] = None, text: Optional[str] = None) -> List[Tuple[Optional[str], NID]]:
        valids = [(None, portrait.nid) for portrait in self._resources.portraits.values()]
        return valids

class Portrait(Validator):
    desc = "can be a unit's nid, a portrait's nid, or one of (`{unit}`, `{unit1}`, `{unit2}`)."

    def validate(self, text, level):
        if text in self._db.units.keys():
            return text
        elif text in self._resources.portraits.keys():
            return text
        elif text in ('{unit}', '{unit1}', '{unit2}'):
            return text
        return None

    def valid_entries(self, level: Optional[NID] = None, text: Optional[str] = None) -> List[Tuple[Optional[str], NID]]:
        valids = [(None, portrait.nid) for portrait in self._resources.portraits.values()]
        other_valids = [(unit.name, unit.nid) for unit in self._db.units.values()]
        valids.append((None, "{unit}"))
        valids.append((None, "{unit1}"))
        valids.append((None, "{unit2}"))
        return valids + other_valids

class AI(Validator):
    def validate(self, text, level):
        if text in self._db.ai.keys():
            return text
        return None

class Team(Validator):
    def validate(self, text, level):
        if text in self._db.teams:
            return text
        return None

    def valid_entries(self, level: Optional[NID] = None, text: Optional[str] = None) -> List[Tuple[Optional[str], NID]]:
        valids = [(None, team_nid) for team_nid in self._db.teams]
        return valids

class Tag(Validator):
    def validate(self, text, level):
        if text in self._db.tags.keys():
            return text
        return None

    def valid_entries(self, level: Optional[NID] = None, text: Optional[str] = None) -> List[Tuple[Optional[str], NID]]:
        valids = [(None, tag.nid) for tag in self._db.tags.values()]
        return valids

class TagList(Validator):
    desc = "must be a comma-delimited list of tags (ie, `Armor,Dragon,Boss`)"

    def validate(self, text, level):
        tex = text.split(',')
        for t in tex:
            if t not in self._db.tags.keys():
                return None
        return text

    def valid_entries(self, level: Optional[NID] = None, text: Optional[str] = None) -> List[Tuple[Optional[str], NID]]:
        valids = [(None, tag.nid) for tag in self._db.tags.values()]
        return valids

class TextPosition(Validator):
    valid_positions = ['center']

    desc = """
Determines position to place text. Supports either pixels (`x,y`) or the `center` position.
"""

    def validate(self, text, level):
        if text in self.valid_positions:
            return text
        elif text and ',' in text and len(text.split(',')) == 2 and all(str_utils.is_int(t) for t in text.split(',')):
            return text
        return None

    def valid_entries(self, level: Optional[NID] = None, text: Optional[str] = None) -> List[Tuple[Optional[str], NID]]:
        valids = [(None, option) for option in self.valid_positions]
        return valids


class ScreenPosition(Validator):
    desc = """
Determines where to add the portrait to the screen.
Available options are (`OffscreenLeft`,
`FarLeft`, `Left`, `MidLeft`, `MidRight`, `Right`, `FarRight`, `OffscreenRight`) for horizontal positions.
Available options are (`Top`, `Middle`, `Bottom`) for vertical positions.
Alternately, specify a position in pixels (`x,y`)
for the topleft of the portrait.
Can combine horizontal and vertical positions like so: `Left,Bottom`.
If the portrait is placed on the left side of the screen to start,
it will be facing right, and vice versa.
"""

    def validate(self, text: str, level: Optional[NID]):
        if text in horizontal_screen_positions:
            return text
        elif text in vertical_screen_positions:
            return text
        elif str_utils.is_int(text):
            return text
        elif ',' in text and len(text.split(',')) == 2:
            horiz_comp = False
            vert_comp = False
            splittext = text.split(',')
            horiz_comp = splittext[0] in horizontal_screen_positions or str_utils.is_int(splittext[0])
            vert_comp = splittext[0] in vertical_screen_positions
            if horiz_comp and splittext[1] in horizontal_screen_positions:
                return None
            if vert_comp and splittext[1] in vertical_screen_positions:
                return None
            return text
        return None

    def valid_entries(self, level: Optional[NID] = None, text: Optional[str] = None) -> List[Tuple[Optional[str], NID]]:
        valids = [(None, option) for option in horizontal_screen_positions]
        valids += [(None, option) for option in vertical_screen_positions]
        return valids

class Slide(OptionValidator):
    valid = ["normal", "left", "right"]

class Font(OptionValidator):
    valid = list(FONT.keys())

class Direction(OptionValidator):
    valid = ["open", "close"]

class Orientation(OptionValidator):
    valid = ["h", "horiz", "horizontal", "v", "vert", "vertical"]

class ExpressionList(Validator):
    valid_expressions = ["NoSmile", "Smile", "NormalBlink", "CloseEyes", "HalfCloseEyes", "OpenEyes", "OpenMouth"]
    desc = "expects a comma-delimited list of expressions. Valid expressions are: (`NoSmile`, `Smile`, `NormalBlink`, `CloseEyes`, `HalfCloseEyes`, `OpenEyes`, `OpenMouth`). Example: `Smile,CloseEyes`"

    def validate(self, text, level):
        text = text.split(',')
        for t in text:
            if t not in self.valid_expressions:
                return None
        return text

    def valid_entries(self, level: Optional[NID] = None, text: Optional[str] = None) -> List[Tuple[Optional[str], NID]]:
        valids = [(None, option) for option in self.valid_expressions]
        return valids

class IllegalCharacterList(Validator):
    valid_sets = ["uppercase", "lowercase", "uppercase_UTF8", "lowercase_UTF8", "numbers_and_punctuation"]
    desc = "expects a comma-delimited list of character sets to ban. Valid options are: ('uppercase', 'lowercase', 'uppercase_UTF8', 'lowercase_UTF8', 'numbers_and_punctuation'). Example: `uppercase,lowercase`"

    def validate(self, text, level):
        text = text.split(',')
        for t in text:
            if t not in self.valid_sets:
                return None
        return text

    def valid_entries(self, level: Optional[NID] = None, text: Optional[str] = None) -> List[Tuple[Optional[str], NID]]:
        valids = [(None, option) for option in self.valid_sets]
        return valids

class DialogVariant(Validator):
    built_in = ["thought_bubble", "noir", "hint", "narration", "narration_top", "cinematic", "clear"]

    def validate(self, text, level):
        slots = self.built_in.copy()
        predefined_variants = EventInspectorEngine(self._db.events).find_all_calls_of_command(event_commands.SpeakStyle())
        slots += list(set([variant.parameters['Style'] for variant in predefined_variants.values()]))
        if text in slots:
            return text
        return None

    def valid_entries(self, level: Optional[NID] = None, text: Optional[str] = None) -> List[Tuple[Optional[str], NID]]:
        slots = [(None, style) for style in self.built_in]
        text = text.split(',')
        predefined_variants = EventInspectorEngine(self._db.events).find_all_calls_of_command(event_commands.SpeakStyle())
        slots += [(None, style) for style in list(set([variant.parameters['Style'] for variant in predefined_variants.values()]))]
        return slots

class StringList(Validator):
    desc = "must be delimited by commas. For example: `Water,Earth,Fire,Air`"

    def validate(self, text, level):
        text = text.split(',')
        return text

class DashList(Validator):
    desc = "similar to a StringList, but delimited by dashes. For example: `Water-Earth-Fire-Air`"

    def validate(self, text, level):
        try:
            self.convert(text)
            return text
        except:
            pass
        return None

    def convert(self, text: str) -> List:
        return text.split('-')

class PointList(Validator):
    desc = "A list of points separated by dashes. E.g. (1, 1)-(3.5, 3)-(24,-6)"
    decimal_converter = re.compile(r'[^\d.]+')

    def validate(self, value, level):
        if isinstance(value, list):
            if all([isinstance(p, tuple) for p in value]):
                return value
        return None

    def convert(self, text: str) -> List[Point]:
        try:
            text.replace(' ', '')
            tlist = text.split(')-(')
            parsed_list = []
            for pstring in tlist:
                coords = pstring.split(',')
                x = float(self.decimal_converter.sub('', coords[0]))
                y = float(self.decimal_converter.sub('', coords[1]))
                parsed_list.append((x, y))
            return parsed_list
        except:
            return text

class Speaker(Validator):
    pass  # Any text will do

class Panorama(Validator):
    def validate(self, text, level):
        if text in self._resources.panoramas.keys():
            return text
        return None

    def valid_entries(self, level: Optional[NID] = None, text: Optional[str] = None) -> List[Tuple[Optional[str], NID]]:
        valids = [(None, pan.nid) for pan in self._resources.panoramas.values()]
        return valids

class Width(Validator):
    desc = "is measured in pixels"

    def validate(self, text, level):
        if str_utils.is_int(text):
            return 8 * round(int(text) / 8)
        return None

class Speed(Validator):
    desc = "is measured in milliseconds"

    def validate(self, text, level):
        if str_utils.is_int(text) and int(text) > 0:
            return text
        return None

class Color3(Validator):
    desc = "uses 0-255 for color channels. Example: `128,160,136`"

    def validate(self, text, level):
        if ',' not in text:
            return None
        text = text.split(',')
        if len(text) != 3:
            return None
        if all(str_utils.is_int(t) and 0 <= int(t) <= 255 for t in text):
            return text
        return None

class Bool(OptionValidator):
    valid = ['t', 'true', '1', 'y', 'yes', 'f', 'false', '0', 'n', 'no']

class ShopFlavor(Validator):
    # Any string will do
    desc = "defaults to `armory`"

    def valid_entries(self, level: Optional[NID] = None, text: Optional[str] = None) -> List[Tuple[Optional[str], NID]]:
        valids = []
        valids.append((None, "vendor"))
        valids.append((None, "armory"))
        return valids

class TableEntryType(OptionValidator):
    valid = ['type_skill', 'type_base_item', 'type_game_item', 'type_unit', 'type_class', 'type_icon', 'type_portrait', 'type_chibi']

class Chapter(Validator):
    desc = "accepts a chapter's nid."

    def validate(self, text, level):
        if text in self._db.levels.keys():
            return text
        return None

    def valid_entries(self, level: Optional[NID] = None, text: Optional[str] = None) -> List[Tuple[Optional[str], NID]]:
        valids = [(None, n) for n in self._db.levels.keys()]
        return valids

class FogOfWarType(OptionValidator):
    valid = ['gba', 'thracia']

class ShakeType(OptionValidator):
    valid = ['default', 'combat', 'kill', 'random', 'celeste']

class Position(Validator):
    desc = "accepts a valid `(x, y)` position. You use a unit's nid to use their position. Alternatively, you can use one of (`{unit}`, `{unit1}`, `{unit2}`, `{position}`)"

    def validate(self, text, level: LevelPrefab):
        text = text.split(',')
        if len(text) == 1:
            text = text[0]
            if level and text in level.units.keys():
                return text
            elif text in ('{unit}', '{unit1}', '{unit2}', '{position}'):
                return text
            elif text in self.valid_overworld_nids().values():
                return text
            if level and level.regions:
                if text in level.regions.keys():
                    return text
            return None
        if len(text) > 2:
            return None
        if not all(str_utils.is_int(t) for t in text):
            return None
        if level and level.tilemap:
            tilemap = self._resources.tilemaps.get(level.tilemap)
            x, y = text
            x = int(x)
            y = int(y)
            if 0 <= x < tilemap.width and 0 <= y < tilemap.height:
                return text
            return None
        else:
            return text

    def valid_entries(self, level: Optional[NID] = None, text: Optional[str] = None) -> List[Tuple[Optional[str], NID]]:
        level_prefab = self._db.levels.get(level)
        if level_prefab:
            valids = [(unit.name, unit.nid) for unit in level_prefab.units.values()]
            valids.append((None, "{unit}"))
            valids.append((None, "{unit1}"))
            valids.append((None, "{unit2}"))
            valids.append((None, "{position}"))
            for pair in self.valid_overworld_nids().items():
                valids.append(pair)
            for region in level_prefab.regions.values():
                valids.append((None, region.nid))
            return valids
        else:
            valids = []
            for pair in self.valid_overworld_nids().items():
                valids.append(pair)
            return valids

    def valid_overworld_nids(self) -> Dict[str, NID]:
        # list of all valid nids in overworld
        nids = {}
        for overworld in self._db.overworlds.values():
            node_nids = {node.name: node.nid for node in overworld.overworld_nodes.values()}
            nids.update(node_nids)
        party_nids = {party.name: party.nid for party in self._db.parties.values()}
        nids.update(party_nids)
        return nids

class FloatPosition(Position, Validator):
    desc = """accepts a valid `(x, y)` position, but also allows fractional positions,
    such as (1.5, 2.6). You use a unit's nid to use their position.
    Alternatively, you can use one of (`{unit}`, `{unit1}`, `{unit2}`, `{position}`)"""

    def validate(self, text, level):
        text = text.split(',')
        if len(text) == 1:
            text = text[0]
            if level and text in level.units.keys():
                return text
            elif text in ('{unit}', '{unit1}', '{unit2}', '{position}'):
                return text
            elif text in self.valid_overworld_nids().values():
                return text
            return None
        if len(text) > 2:
            return None
        if not all(str_utils.is_float(t) for t in text):
            return None
        if level and level.tilemap:
            tilemap = self._resources.tilemaps.get(level.tilemap)
            x, y = text
            x = float(x)
            y = float(y)
            if 0 <= x < tilemap.width and 0 <= y < tilemap.height:
                return text
            return None
        else:
            return text

class PositionOffset(Validator):
    desc = "accepts a valid `(x, y)` position offset."

    def validate(self, text, level):
        text = text.split(',')
        if len(text) != 2:
            return None
        if not all(str_utils.is_int(t) for t in text):
            return None
        return text

class Size(Validator):
    desc = "must be in the format `x,y`. Example: `64,32`"

    def validate(self, text, level):
        text = text.split(',')
        if len(text) > 2:
            return None
        if not all(str_utils.is_int(t) and int(t) > 0 for t in text):
            return None
        return text

class Unit(Validator):
    desc = "accepts a unit's nid. Alternatively, you can use one of (`{unit}`, `{unit1}`, `{unit2}`)."

    def validate(self, text, level):
        if not level:
            return text
        nids = [u.nid for u in level.units]
        if text in nids:
            return text
        elif text in ('{unit}', '{unit1}', '{unit2}'):
            return True
        return None

    def valid_entries(self, level: Optional[NID] = None, text: Optional[str] = None) -> List[Tuple[Optional[str], NID]]:
        level_prefab = self._db.levels.get(level)
        if not level_prefab:
            return []
        valids = [(unit.name, unit.nid) for unit in level_prefab.units]
        valids.append((None, "{unit}"))
        valids.append((None, "{unit1}"))
        valids.append((None, "{unit2}"))
        return valids

class Group(Validator):
    def validate(self, text, level):
        if not level:
            return None
        nids = [g.nid for g in level.unit_groups]
        if text in nids:
            return text
        return None

    def valid_entries(self, level: Optional[NID] = None, text: Optional[str] = None) -> List[Tuple[Optional[str], NID]]:
        level_prefab = self._db.levels.get(level)
        if level_prefab:
            valids = [(None, group.nid) for group in level_prefab.unit_groups.values()]
        else:
            valids = []
        return valids

class StartingGroup(Validator):
    desc = "accepts a unit group's nid. Alternatively, can be `starting` to use the unit's starting positions in the level."

    def validate(self, text, level):
        if not level:
            return None
        if ',' in text and len(text.split(',')) == 2:
            if all(str_utils.is_int(t) for t in text.split(',')):
                return text
            else:
                return None
        if text.lower() == 'starting':
            return text
        nids = [g.nid for g in level.unit_groups]
        if text in nids:
            return text
        return None

    def valid_entries(self, level: Optional[NID] = None, text: Optional[str] = None) -> List[Tuple[Optional[str], NID]]:
        level_prefab = self._db.levels.get(level)
        if level_prefab:
            valids = [(None, group.nid) for group in level_prefab.unit_groups.values()]
            valids.append((None, "starting"))
            return valids
        else:
            return []

class UniqueUnit(Validator):
    def validate(self, text, level):
        if text in self._db.units.keys():
            return text
        return None

    def valid_entries(self, level: Optional[NID] = None, text: Optional[str] = None) -> List[Tuple[Optional[str], NID]]:
        valids = [(unit.name, unit.nid) for unit in self._db.units.values()]
        return valids

class GlobalUnit(Validator):
    desc = "accepts a unit's nid. Alternatively, you can use one of (`{unit}`, `{unit1}`, `{unit2}`) where appropriate."

    def validate(self, text, level):
        if level:
            nids = [u.nid for u in level.units]
            if text in nids:
                return text
        if text in self._db.units.keys():
            return text
        elif text in ('{unit}', '{unit1}', '{unit2}'):
            return True
        return None

    def valid_entries(self, level: Optional[NID] = None, text: Optional[str] = None) -> List[Tuple[Optional[str], NID]]:
        valids = [(unit.name, unit.nid) for unit in self._db.units.values()]
        valids.append((None, "{unit}"))
        valids.append((None, "{unit1}"))
        valids.append((None, "{unit2}"))
        return valids

class GlobalUnitOrConvoy(Validator):
    desc = "accepts a unit's nid. Alternatively, you can use one of (`{unit}`, `{unit1}`, `{unit2}`) or `convoy` where appropriate."

    def validate(self, text, level):
        if level:
            nids = [u.nid for u in level.units]
            if text in nids:
                return text
        if text.lower() == 'convoy':
            return text
        elif text in self._db.units.keys():
            return text
        elif text in ('{unit}', '{unit1}', '{unit2}'):
            return True
        return None

    def valid_entries(self, level: Optional[NID] = None, text: Optional[str] = None) -> List[Tuple[Optional[str], NID]]:
        valids = [(unit.name, unit.nid) for unit in self._db.units.values()]
        valids.append((None, "{unit}"))
        valids.append((None, "{unit1}"))
        valids.append((None, "{unit2}"))
        valids.append((None, "convoy"))
        return valids

class Region(Validator):
    desc = "accepts a region nid."

    def validate(self, text, level):
        return text

    def valid_entries(self, level: Optional[NID] = None, text: Optional[str] = None) -> List[Tuple[Optional[str], NID]]:
        valids = []
        level_obj = self._db.levels.get(level)
        if level_obj:
            valids = [(None, region.nid) for region in level_obj.regions]
        return valids
class AnimationType(OptionValidator):
    valid = ['north', 'east', 'west', 'south', 'fade']
class CardinalDirection(OptionValidator):
    valid = ['north', 'east', 'west', 'south']

class EntryType(OptionValidator):
    valid = ['fade', 'immediate', 'warp', 'swoosh']

class Placement(OptionValidator):
    valid = ['giveup', 'stack', 'closest', 'push']

class MovementType(OptionValidator):
    valid = ['normal', 'fade', 'immediate', 'warp', 'swoosh']

class RemoveType(OptionValidator):
    valid = ['fade', 'immediate', 'warp', 'swoosh']

class RegionType(OptionValidator):
    valid = [r.value for r in RegionTypeEnum]

class Weather(OptionValidator):
    valid = ["rain", "sand", "snow", "fire", "light", "purple", "dark", "smoke", "night", "sunset", "event_tile", "switch_tile"]

class Align(OptionValidator):
    valid = [align.value for align in Alignments]

class AlignOrPosition(OptionValidator):
    valid = [align.value for align in Alignments]

    def validate(self, text, level):
        if text in self.valid:
            return text
        elif text and ',' in text and len(text.split(',')) == 2 and all(str_utils.is_int(t) for t in text.split(',')):
            return text
        return None

class HAlign(OptionValidator):
    valid = [align.value for align in HAlignment]

class VAlign(OptionValidator):
    valid = [align.value for align in VAlignment]

class GrowthMethod(OptionValidator):
    valid = ["random", "fixed", "dynamic"]

class CombatScript(Validator):
    valid_commands = ['hit1', 'hit2', 'crit1', 'crit2', 'miss1', 'miss2', '--', 'end']
    desc = "specifies the order and type of actions in combat. Valid actions: (`hit1`, `hit2`, `crit1`, `crit2`, `miss1`, `miss2`, `--`, `end`)."

    def validate(self, text, level):
        commands = text.split(',')
        if all(command.lower() in self.valid_commands for command in commands):
            return text
        return None

    def valid_entries(self, level: Optional[NID] = None, text: Optional[str] = None) -> List[Tuple[Optional[str], NID]]:
        valids = [(None, option) for option in self.valid_commands]
        return valids

class Ability(Validator):
    def validate(self, text, level):
        if text in self._db.items.keys():
            return text
        elif text in self._db.skills.keys():
            return text
        return None

    def valid_entries(self, level: Optional[NID] = None, text: Optional[str] = None) -> List[Tuple[Optional[str], NID]]:
        valids = [(item.name, item.nid) for item in self._db.items.values()]
        svalids = [(skill.name, skill.nid) for skill in self._db.skills.values()]
        return valids + svalids

class Item(Validator):
    desc = "accepts an item's nid or uid."

    def validate(self, text, level):
        if text in self._db.items.keys():
            return text
        return None

    def valid_entries(self, level: Optional[NID] = None, text: Optional[str] = None) -> List[Tuple[Optional[str], NID]]:
        valids = [(item.name, item.nid) for item in self._db.items.values()]
        return valids

class ItemList(Validator):
    desc = "accepts a comma-delimited list of item nids. Example: `Iron Sword,Iron Lance,Iron Bow`"

    def validate(self, text, level):
        items = text.split(',')
        if all(item in self._db.items.keys() for item in items):
            return text
        return None

    def valid_entries(self, level: Optional[NID] = None, text: Optional[str] = None) -> List[Tuple[Optional[str], NID]]:
        valids = [(None, item.nid) for item in self._db.items.values()]
        return valids

class ItemComponent(Validator):
    desc = "accepts an item component."

    def validate(self, text, level):
        from app.engine import item_component_access as ICA
        if text in ICA.get_item_components().keys():
            return text
        return None

    def valid_entries(self, level: Optional[NID] = None, text: Optional[str] = None) -> List[Tuple[Optional[str], NID]]:
        from app.engine import item_component_access as ICA
        valids = [(None, component.nid) for component in ICA.get_item_components()]
        return valids

class StatList(Validator):
    desc = "accepts a comma-delimited list of pairs of stat nids and stat changes. For example, `STR,2,SPD,-3`."

    def validate(self, text, level):
        s_l = text.split(',')
        if len(s_l)%2 != 0:  # Must be divisible by 2
            return None
        for idx in range(len(s_l)//2):
            stat_nid = s_l[idx*2]
            stat_value = s_l[idx*2 + 1]
            if stat_nid not in self._db.stats.keys():
                return None
            elif not str_utils.is_int(stat_value):
                return None
        return text

    def valid_entries(self, level: Optional[NID] = None, text: Optional[str] = None) -> List[Tuple[Optional[str], NID]]:
        valids = [(None, stat.nid) for stat in self._db.stats.values()]
        return valids

class KlassList(Validator):
    desc = "accepts a comma-delimited list of klass nids."

    def validate(self, text, level):
        s_l = text.split(',')

        for entry in s_l:
            if entry not in self._db.classes.keys():
                return None
        return text

    def valid_entries(self, level: Optional[NID] = None, text: Optional[str] = None) -> List[Tuple[Optional[str], NID]]:
        valids = [(None, klass.nid) for klass in self._db.classes.values()]
        return valids

class ArgList(Validator):
    desc = "accepts a comma-delimited list of pairs of keywords and values. For example, `Color,Purple,Animal,Dog`."

    def validate(self, text, level):
        s_l = text.split(',')
        if len(s_l)%2 != 0:  # Must be divisible by 2
            return None
        return text

class Skill(Validator):
    def validate(self, text, level):
        if text in self._db.skills.keys():
            return text
        return None

    def valid_entries(self, level: Optional[NID] = None, text: Optional[str] = None) -> List[Tuple[Optional[str], NID]]:
        svalids = [(skill.name, skill.nid) for skill in self._db.skills.values()]
        return svalids

class Icon(Validator):
    def get_all_icons(self):
        all_icons = set()
        for sheet in self._resources.icons16:
            all_icons |= set(sheet._subicon_dict.keys())
        return all_icons

    def validate(self, text, level):
        return text in self.get_all_icons()

    def valid_entries(self, level: Optional[NID] = None, text: Optional[str] = None) -> List[Tuple[Optional[str], NID]]:
        return [(None, alias) for alias in self.get_all_icons()]

class Party(Validator):
    desc = "accepts the nid of an existing Party"

    def validate(self, text, level):
        if text in self._db.parties.keys():
            return text
        return None

    def valid_entries(self, level: Optional[NID] = None, text: Optional[str] = None) -> List[Tuple[Optional[str], NID]]:
        valids = [(party.name, party.nid) for party in self._db.parties.values()]
        return valids

class Faction(Validator):
    def validate(self, text, level):
        if text in self._db.factions.keys():
            return text
        return None

    def valid_entries(self, level: Optional[NID] = None, text: Optional[str] = None) -> List[Tuple[Optional[str], NID]]:
        valids = [(fac.name, fac.nid) for fac in self._db.factions.values()]
        return valids

class Klass(Validator):
    def validate(self, text, level):
        if text in self._db.classes.keys():
            return text
        return None

    def valid_entries(self, level: Optional[NID] = None, text: Optional[str] = None) -> List[Tuple[Optional[str], NID]]:
        valids = [(klass.name, klass.nid) for klass in self._db.classes.values()]
        return valids

class Lore(Validator):
    def validate(self, text, level):
        if text in self._db.lore.keys():
            return text
        return None

    def valid_entries(self, level: Optional[NID] = None, text: Optional[str] = None) -> List[Tuple[Optional[str], NID]]:
        valids = [(lore.name, lore.nid) for lore in self._db.lore.values()]
        return valids

class WeaponType(Validator):
    def validate(self, text, level):
        if text in self._db.weapons.keys():
            return text
        return None

    def valid_entries(self, level: Optional[NID] = None, text: Optional[str] = None) -> List[Tuple[Optional[str], NID]]:
        valids = [(weapon.name, weapon.nid) for weapon in self._db.weapons.values()]
        return valids

class SupportRank(Validator):
    def validate(self, text, level):
        if text in self._db.support_ranks.keys():
            return text
        return None

    def valid_entries(self, level: Optional[NID] = None, text: Optional[str] = None) -> List[Tuple[Optional[str], NID]]:
        valids = [(None, rank.nid) for rank in self._db.support_ranks.values()]
        return valids

class Layer(Validator):
    def validate(self, text, level):
        if level:
            tilemap_prefab = self._resources.tilemaps.get(level.tilemap)
            if text in tilemap_prefab.layers.keys():
                return text
        return None

    def valid_entries(self, level: Optional[NID] = None, text: Optional[str] = None) -> List[Tuple[Optional[str], NID]]:
        level = self._db.levels.get(level)
        if level:
            tilemap_prefab = self._resources.tilemaps.get(level.tilemap)
            valids = [(None, layer_nid) for layer_nid in tilemap_prefab.layers.keys()]
            return valids
        return []

class LayerTransition(OptionValidator):
    valid = ['fade', 'immediate']

class MapAnim(Validator):
    def validate(self, text, level):
        if text in self._resources.animations.keys():
            return text
        return None

    def valid_entries(self, level: Optional[NID] = None, text: Optional[str] = None) -> List[Tuple[Optional[str], NID]]:
        valids = [(None, anim.nid) for anim in self._resources.animations.values()]
        return valids

class Tilemap(Validator):
    def validate(self, text, level):
        if text in self._resources.tilemaps.keys():
            return text
        return None

    def valid_entries(self, level: Optional[NID] = None, text: Optional[str] = None) -> List[Tuple[Optional[str], NID]]:
        valids = [(None, tilemap.nid) for tilemap in self._resources.tilemaps.values()]
        return valids

class Event(Validator):
    desc = "accepts the name or nid of an event. Will run the event appropriate for the level if more than one event with the same name exists."

    def validate(self, text, level):
        lnid = level.nid if level else None
        if self._db.events.get_by_nid_or_name(text, lnid):
            return text
        return None

    def valid_entries(self, level: Optional[NID] = None, text: Optional[str] = None) -> List[Tuple[Optional[str], NID]]:
        valids = [(event.name, event.nid) for event in self._db.events.get_by_level(level)]
        return valids

class OverworldNID(Validator):
    desc = "accepts the nid of a valid overworld"

    def validate(self, text, level):
        if self._db.overworlds.get(text) is not None:
            return text
        return None

    def valid_entries(self, level: Optional[NID] = None, text: Optional[str] = None) -> List[Tuple[Optional[str], NID]]:
        valids = [(overworld.name, overworld.nid) for overworld in self._db.overworlds.values()]
        return valids

class OverworldLocation(Validator):
    desc = "accepts the nid of an overworld location/node, or a display coordinate x, y"
    decimal_converter = re.compile(r'[^\d.-]+')

    def validate(self, text, level):
        try:
            text = self.convert(text)
            if isinstance(text, tuple) and len(text) == 2:
                return text
            for overworld in self._db.overworlds.values():
                for node in overworld.overworld_nodes:
                    if node.nid == text:
                        return text
        except:
            pass
        return None

    def valid_entries(self, level: Optional[NID] = None, text: Optional[str] = None) -> List[Tuple[Optional[str], NID]]:
        valids = []
        for overworld in self._db.overworlds.values():
            valids = valids + [(node.name, node.nid) for node in overworld.overworld_nodes.values()]
        return valids

    def convert(self, text: str) -> NID | Tuple[float, float]:
        if len(text.split(',')) == 2: # is coordinate
            try:
                coords = text.split(',')
                x = float(self.decimal_converter.sub('', coords[0]))
                y = float(self.decimal_converter.sub('', coords[1]))
                return (x, y)
            except:
                raise ValueError("Could not parse coordinates from string %s" % text)
        else: # is nid
            return text

class OverworldNodeNID(Validator):
    desc = "accepts the nid of an overworld node only"

    def validate(self, text, level):
        for overworld in self._db.overworlds.values():
            for node in overworld.overworld_nodes:
                if node.nid == text:
                    return text
        return None

    def valid_entries(self, level: Optional[NID] = None, text: Optional[str] = None) -> List[Tuple[Optional[str], NID]]:
        valids = []
        for overworld in self._db.overworlds.values():
            valids = valids + [(node.name, node.nid) for node in overworld.overworld_nodes.values()]
        return valids

class OverworldNodeMenuOption(Validator):
    desc = "accepts the nid of an overworld node menu option only"

    def validate(self, text, level):
        for overworld in self._db.overworlds.values():
            for node in overworld.overworld_nodes:
                if text in [option.nid for option in node.menu_options]:
                    return text
        return None

    def valid_entries(self, level: Optional[NID] = None, text: Optional[str] = None) -> List[Tuple[Optional[str], NID]]:
        valids = []
        for overworld in self._db.overworlds.values():
            for node in overworld.overworld_nodes:
                valids = valids + [(option.option_name, option.nid) for option in node.menu_options]
        return valids

class OverworldEntity(Validator):
    desc = "accepts the nid of an overworld entity. By default, all parties have associated overworld entities."

    def validate(self, text, level):
        return text

    def valid_entries(self, level: Optional[NID] = None, text: Optional[str] = None) -> List[Tuple[Optional[str], NID]]:
        valids = [(party.name, party.nid) for party in self._db.parties.values()]
        return valids

class Sprite(Validator):
    desc = 'accepts the filename of any sprite resource in the project.'

    def validate(self, text: NID, level: NID):
        if text in SPRITES.keys():
            return text
        return None

    def valid_entries(self, level: Optional[NID] = None, text: Optional[str] = None) -> List[Tuple[Optional[str], NID]]:
        valids = [(sprite_name, sprite_name) for sprite_name in SPRITES.keys()]
        return valids

class MaybeSprite(Validator):
    desc = 'accepts the name of any sprite resource in the project, or None'

    def validate(self, text: NID, level: NID):
        if text in SPRITES.keys():
            return text
        if text == 'None':
            return text
        return None

    def valid_entries(self, level: Optional[NID] = None, text: Optional[str] = None) -> List[Tuple[Optional[str], NID]]:
        valids = [(sprite_name, sprite_name) for sprite_name in SPRITES.keys()]
        valids += [(None, "None")]
        return valids

class DifficultyMode(Validator):
    desc = 'accepts the nid of a difficulty mode.'
    
    def validate(self, text, level):
        if text in self._db.difficulty_modes.keys():
            return text
        return None

    def valid_entries(self, level: Optional[NID] = None, text: Optional[str] = None) -> List[Tuple[Optional[str], NID]]:
        valids = [(difficulty.name, difficulty.nid) for difficulty in self._db.difficulty_modes.values()]
        return valids

validators: Dict[str, Type[Validator]]= {validator.__name__: validator for validator in Validator.__subclasses__()}
option_validators: Dict[str, Type[OptionValidator]] = {validator.__name__: validator for validator in OptionValidator.__subclasses__()}
eval_validators: Dict[str, Type[EvalValidator]] = {}
for validator in EvalValidator.__subclasses__():
    for tag in validator.tags:
        eval_validators[tag] = validator

def validate(var_type, text, level, db: Database = None, resources: Resources = None):
    if text and text[0] == '{' and text[-1] == '}': # eval validator
        validator = eval_validators.get(var_type)
        if validator:
            v = validator(db, resources)
            return v.validate(text, level)
    validator = validators.get(var_type)
    if validator:
        v = validator(db, resources)
        return v.validate(text, level)
    validator = option_validators.get(var_type)
    if validator:
        v = validator(db, resources)
        return v.validate(text, level)
    else:
        return text

def convert(var_type, text):
    if not text:
        return None
    try:
        validator = validators.get(var_type)
        if validator:
            v = validator()
            return v.convert(text)
        validator = option_validators.get(var_type)
        if validator:
            v = validator()
            return v.convert(text)
        else:
            return text
    except:
        return text

def get(keyword) -> Validator:
    if keyword in validators:
        return validators[keyword]
    elif keyword in option_validators:
        return option_validators[keyword]
    elif keyword in eval_validators:
        return eval_validators[keyword]
    return None
