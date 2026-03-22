from __future__ import annotations

from app.constants import COLORKEY
from app.engine.objects.item import ItemObject

from typing import Callable, List, Tuple

from app.data.database.database import DB
from app.data.database.items import ItemPrefab
from app.data.database.klass import Klass
from app.data.database.skills import SkillPrefab
from app.engine import engine
from app.engine.game_menus.menu_components.generic_menu.simple_menu import \
    SimpleIconTable
from app.engine.game_state import game
from app.engine.graphics.ui_framework.ui_framework import UIComponent
from app.engine.graphics.ui_framework.ui_framework_layout import HAlignment, convert_align
from app.engine.icons import draw_chibi, get_icon, get_icon_by_nid
from app.engine.objects.unit import UnitObject
from app.data.resources.resources import RESOURCES
from app.sprites import SPRITES
from app.utilities.enums import Alignments, Orientation
from app.utilities.typing import NID

class SimpleMenuUI():
    def __init__(self, data: List[str] | Callable[[], List] = None, data_type: str = 'str',
                 title: str = None, rows: int = 0, cols: int = 1, row_width: int = -1,
                 alignment: Alignments = Alignments.TOP_LEFT, bg: str = 'menu_bg_base',
                 orientation: Orientation = Orientation.VERTICAL, text_align: HAlignment = HAlignment.LEFT):
        self._data_type = data_type
        self._data: List = None
        self._get_data: Callable[[], List] = None

        # UI stuff
        self.base_component = UIComponent.create_base_component()
        self.table: SimpleIconTable = self.create_table(self.base_component, rows, cols, title, row_width, bg, orientation, text_align)
        halign, valign = convert_align(alignment)
        self.table.props.h_alignment = halign
        self.table.props.v_alignment = valign
        self.table.margin = (10, 10, 10, 10)
        self.base_component.add_child(self.table)

        if callable(data):
            self._get_data = data
            self.set_data(self._get_data())
        else:
            self.set_data(data)

    def create_table(self, base_component, rows, cols, title, row_width, bg, orientation, text_align) -> SimpleIconTable:
        return SimpleIconTable('table', base_component, num_rows=rows,
                               num_columns=cols, title=title, row_width=row_width,
                               background=bg, orientation=orientation,
                               option_text_align=text_align)

    def set_data(self, raw_data):
        if self._data == raw_data and not self._data_type == 'type_unit': # units need to be refreshed
            return
        self._data = raw_data
        parsed_data = self.parse_data(raw_data)
        self.table.set_data(parsed_data)

    def parse_data(self, data: List[str]) -> List[str] | List[Tuple[engine.Surface, str, NID]]:
        """Takes input of form:
        ['nid1', 'nid2', 'nid3', 'nid4']
        or of form:
        ['nid1|text1', 'nid2|text2', 'nid3|text3']
        """
        split_data = []
        for datum in data:
            datum = str(datum)
            processed = datum.split('|')
            nid = processed[0]
            name = None
            if len(processed) > 1:
                name = processed[1]
            split_data.append((nid, name))
        if self._data_type == 'type_base_item':
            return [self.parse_item(DB.items.get(item_nid), choice_text, item_nid) for item_nid, choice_text in split_data]
        if self._data_type == 'type_game_item':
            return [self.parse_item(game.item_registry.get(int(item_uid)), choice_text, item_uid) for item_uid, choice_text in split_data]
        elif self._data_type == 'type_skill':
            return [self.parse_skill(DB.skills.get(skill_nid), choice_text) for skill_nid, choice_text in split_data]
        elif self._data_type == 'type_unit':
            return [self.parse_unit(game.unit_registry.get(unit_nid), choice_text) for unit_nid, choice_text in split_data]
        elif self._data_type == 'type_class':
            return [self.parse_klass(DB.classes.get(klass_nid), choice_text) for klass_nid, choice_text in split_data]
        elif self._data_type == 'type_portrait':
            return [self.parse_portrait(portrait_nid) for portrait_nid, _ in split_data]
        elif self._data_type == 'type_chibi':
            return [self.parse_chibi(chibi_nid) for chibi_nid, _ in split_data]
        elif self._data_type == 'type_icon':
            parsed_data = [(datum.split('-'), choice_text) for datum, choice_text in split_data]
            return [self.parse_custom_icon_data(tup, choice_text) for tup, choice_text in parsed_data]
        else:
            return [(None, choice_text if choice_text else choice_nid, choice_nid) for choice_nid, choice_text in split_data]

    def parse_klass(self, klass: Klass, choice_name: str)-> Tuple[engine.Surface, str, str]:
        # @TODO: figure out why klasses don't know their own sprite and fix that
        return klass

    def parse_custom_icon_data(self, tup: Tuple[NID, str, str, str], choice_name: str) -> Tuple[engine.Surface, str, str]:
        icon_sheet_nid = tup[0]
        icon_x = int(tup[1])
        icon_y = int(tup[2])
        choice_nid = tup[3]
        icon = get_icon_by_nid(icon_sheet_nid, icon_x, icon_y)
        if choice_name:
            return (icon, choice_name, choice_nid)
        return (icon, choice_nid)

    def parse_skill(self, skill: SkillPrefab, choice_name: str) -> Tuple[engine.Surface, str, str]:
        if skill:
            return (get_icon(skill), skill.name if not choice_name else choice_name, skill.nid)
        else:
            return (get_icon(skill), "ERR", "ERR")

    def parse_item(self, item: ItemPrefab | ItemObject, choice_name: str, choice_value: str) -> Tuple[engine.Surface, str, str]:
        if item:
            return (get_icon(item), item.name if not choice_name else choice_name, choice_value)
        else:
            return (get_icon(item), "ERR", "ERR")

    def parse_unit(self, unit: UnitObject, choice_name: str) -> Tuple[engine.Surface, str, str]:
        if unit:
            unit_sprite = unit.sprite.create_image('passive')
            unit_icon = UIComponent()
            unit_icon.size = (16, 16)
            unit_icon.overflow = (12, 0, 12, 0) # the unit sprites are kind of enormous
            unit_icon.add_surf(unit_sprite, (-24, -24))
            return (unit_icon, unit.name if not choice_name else choice_name, unit.nid)
        else:
            return (get_icon(None), "ERR", "ERR")

    def parse_portrait(self, portrait_nid: NID) -> Tuple[engine.Surface, str, str]:
        # mostly copied from EventPortrait
        portrait = RESOURCES.portraits.get(portrait_nid)
        if portrait:
            main_portrait_coords = (0, 0, 96, 80)
            if not portrait.image:
                portrait.image = engine.image_load(portrait.full_path)
            portrait.image = portrait.image.convert()
            engine.set_colorkey(portrait.image, COLORKEY, rleaccel=True)
            main_portrait = engine.subsurface(portrait.image, main_portrait_coords)
        else:
            main_portrait = engine.create_surface((96, 80))
        return (main_portrait, "", "")

    def parse_chibi(self, chibi_nid: NID) -> Tuple[engine.Surface, str, str]:
        chibi_surf = engine.create_surface((32, 32), True)
        chibi = draw_chibi(chibi_surf, chibi_nid, (0, 0))
        return (chibi, "", "")

    def update(self):
        if self._get_data:
            new_data = self._get_data()
            self.set_data(new_data)
        elif self._data_type == 'type_unit': # we need to reset data to update sprites
            # elif because while not mutually exclusive, we only ever need one call of "set_data"
            if self._get_data:
                new_data = self._get_data()
            else:
                new_data = self._data
            self.set_data(new_data)
        return True

    def draw(self, surf):
        ui_surf = self.base_component.to_surf()
        surf.blit(ui_surf, (0, 0))
        return surf
