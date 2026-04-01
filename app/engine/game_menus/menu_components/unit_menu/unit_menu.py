from __future__ import annotations

from enum import Enum
from typing import Callable, List, Tuple

import app.engine.graphics.ui_framework as uif
from app.engine import engine, image_mods
from app.engine.base_surf import create_base_surf
from app.engine.fonts import FONT
from app.engine.game_menus.menu_components.unit_menu.unit_table import \
    UnitInformationTable
from app.engine.objects.unit import UnitObject
from app.engine.sprites import SPRITES
from app.utilities.direction import Direction


class SORT_TYPE(Enum):
    ASCENDING = 0
    DESCENDING = 1

class UnitMenuUI():
    SORT_ARROW_WIGGLE = [6, 7, 6, 5]

    def __init__(self, data: List[UnitObject]):
        self.page_num = 1
        self.sort_by: str = 'Name'
        self.sort_direction = SORT_TYPE.DESCENDING
        self.sort_arrow_wiggle_index = 0

        self.data = data

        # initialize components
        self.unit_info_box: uif.UIComponent = uif.UIComponent(name="page type box")
        self.unit_info_box.props.bg = SPRITES.get('world_map_location_box')
        self.unit_info_box.size = self.unit_info_box.props.bg.get_size()
        self.unit_info_box.props.v_alignment = uif.VAlignment.TOP
        self.unit_info_box.props.h_alignment = uif.HAlignment.LEFT
        self.unit_info_box.margin = (0, 0, 0, 0)

        self.page_title_component = uif.plain_text_component.PlainTextLine("page type text", self.unit_info_box, "")
        self.page_title_component.props.h_alignment = uif.HAlignment.CENTER
        self.page_title_component.props.v_alignment = uif.VAlignment.CENTER
        self.page_title_component.props.font = FONT['chapter-grey']
        self.page_title_component.set_text("Character")
        self.unit_info_box.add_child(self.page_title_component)

        self.sort_box: uif.UIComponent = uif.UIComponent(name='sort box')
        self.sort_box.props.bg = image_mods.make_translucent(create_base_surf(72, 24, 'menu_bg_base'), 0.15)
        self.sort_box.size = self.sort_box.props.bg.get_size()
        self.sort_box.props.v_alignment = uif.VAlignment.TOP
        self.sort_box.props.h_alignment = uif.HAlignment.RIGHT
        self.sort_box.margin = (0, 4, 5, 0)

        self.sort_by_text = uif.plain_text_component.PlainTextLine("sort by", self.sort_box, "")
        self.sort_by_text.props.h_alignment = uif.HAlignment.LEFT
        self.sort_by_text.props.v_alignment = uif.VAlignment.CENTER
        self.sort_by_text.props.font = FONT['text']
        self.sort_by_text.margin = (3, 0, 0, 0)
        self.sort_by_text.padding = (0, 0, 0, 2)
        self.sort_by_text.set_text("Sort: ")
        self.sort_box.add_child(self.sort_by_text)

        asc_sort_arrow = SPRITES.get('sort_arrow')
        self.asc_sort_arrow = uif.UIComponent.from_existing_surf(asc_sort_arrow)
        self.asc_sort_arrow.props.h_alignment = uif.HAlignment.RIGHT
        self.asc_sort_arrow.margin = (0, 2, 5, 0)
        self.sort_box.add_child(self.asc_sort_arrow)
        self.asc_sort_arrow.disable()

        desc_sort_arrow = engine.flip_vert(asc_sort_arrow)
        self.desc_sort_arrow = uif.UIComponent.from_existing_surf(desc_sort_arrow)
        self.desc_sort_arrow.props.h_alignment = uif.HAlignment.RIGHT
        self.desc_sort_arrow.margin = (0, 2, 5, 0)
        self.sort_box.add_child(self.desc_sort_arrow)

        self.page_number_text = uif.plain_text_component.PlainTextLine('page_num', None, '%d / %d' % (0, 0))
        self.page_number_text.props.font = FONT['text-blue']
        self.page_number_text.props.h_alignment = uif.HAlignment.RIGHT
        bottom_of_sort_box = self.sort_box.margin[2] + self.sort_box.size[1]
        self.page_number_text.margin = (0, 5, bottom_of_sort_box - 5, 0)

        self.unit_info_table = UnitInformationTable(
            name='unit_box', data=self.data)

        self.base_component = uif.UIComponent.create_base_component()
        self.base_component.name = "base"
        self.base_component.add_child(self.unit_info_box)
        self.base_component.add_child(self.sort_box)
        self.base_component.add_child(self.unit_info_table)
        self.base_component.add_child(self.page_number_text)

    def get_page_title(self) -> str:
        return self.unit_info_table.get_page_title()

    def _update_title_box(self):
        page_title = self.get_page_title()
        if self.page_title_component.text is not page_title:
            self.page_title_component.set_text(page_title)

    def _update_sort_box(self):
        sort_text = 'Sort: ' + self.sort_by
        if self.sort_by_text.text != sort_text:
            self.sort_by_text.set_text(sort_text)
        # orient sort arrow
        if self.sort_direction == SORT_TYPE.ASCENDING:
            self.desc_sort_arrow.disable()
            self.asc_sort_arrow.enable()
            curr_sort_arrow = self.asc_sort_arrow
        else:
            self.asc_sort_arrow.disable()
            self.desc_sort_arrow.enable()
            curr_sort_arrow = self.desc_sort_arrow
        # perturb it
        curr_sort_arrow.margin = (0, 2, self.SORT_ARROW_WIGGLE[(self.sort_arrow_wiggle_index // 8) % len(self.SORT_ARROW_WIGGLE)], 0)
        self.sort_arrow_wiggle_index += 1

    def get_page_num(self) -> int:
        return self.unit_info_table.get_page_num()

    def get_num_pages(self) -> int:
        return self.unit_info_table.get_num_pages()

    def _update_page_num(self):
        page_num_text = '%d / %d' % (self.get_page_num() + 1, self.get_num_pages())
        if self.page_number_text.text != page_num_text:
            self.page_number_text.set_text(page_num_text)

    def cursor_hover(self) -> UnitObject | str | None:
        return self.unit_info_table.cursor_hover()

    def move_cursor(self, direction: Direction) -> bool:
        return self.unit_info_table.move_cursor(direction)

    def sort_data(self, sort_by: Tuple[str, Callable[[UnitObject], int | str]]):
        if self.sort_by == sort_by[0]:
            if self.sort_direction == SORT_TYPE.ASCENDING:
                self.sort_direction = SORT_TYPE.DESCENDING
            else:
                self.sort_direction = SORT_TYPE.ASCENDING
        reverse = self.sort_direction != SORT_TYPE.DESCENDING
        self.sort_by = sort_by[0]
        self.data = sorted(self.data, key=sort_by[1], reverse=reverse)
        self.unit_info_table.sort_data(self.data)

    def draw(self, surf: engine.Surface) -> engine.Surface:
        self._update_sort_box()
        self._update_title_box()
        self._update_page_num()
        ui_surf = self.base_component.to_surf()
        surf.blit(ui_surf, (0, 0))
        return surf
