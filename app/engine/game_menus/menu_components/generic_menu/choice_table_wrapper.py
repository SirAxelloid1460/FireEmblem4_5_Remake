from __future__ import annotations
from app.engine.game_menus.menu_components.generic_menu.simple_menu_wrapper import SimpleMenuUI

from typing import Callable, List, Tuple

from app.engine.game_menus.menu_components.generic_menu.simple_menu import \
    ChoiceTable
from app.engine.game_state import game
from app.engine.graphics.ui_framework.ui_framework import UIComponent
from app.engine.graphics.ui_framework.ui_framework_layout import HAlignment, convert_align
from app.engine.icons import get_icon, get_icon_by_nid
from app.engine.objects.unit import UnitObject
from app.utilities.enums import Alignments, Orientation
from app.utilities.typing import NID


class ChoiceMenuUI(SimpleMenuUI):
    def __init__(self, data: List[str] | Callable[[], List] = None, data_type: str = 'str',
                 title: str = None, rows: int = 0, cols: int = 1, row_width: int = -1,
                 alignment: Alignments = Alignments.CENTER, bg: str = 'menu_bg_base',
                 orientation: Orientation = Orientation.VERTICAL, text_align: HAlignment = HAlignment.LEFT):
        # set in super constructor
        self.table: ChoiceTable = None
        super().__init__(data=data, data_type=data_type,
                         title=title, rows=rows, cols=cols,
                         row_width=row_width, alignment=alignment,
                         bg=bg, orientation=orientation, text_align=text_align)

    def create_table(self, base_component, rows, cols, title, row_width, bg, orientation, text_align) -> ChoiceTable:
        return ChoiceTable('table', base_component, num_rows=rows,
                           num_columns=cols, title=title, row_width=row_width,
                           background=bg, orientation=orientation,
                           option_text_align=text_align)

    def get_selected(self):
        return self.table.get_selected()

    def move_up(self, first_push: bool = False):
        self.table.move_up(first_push)

    def move_down(self, first_push: bool = False):
        self.table.move_down(first_push)

    def move_right(self, first_push: bool = False):
        self.table.move_right(first_push)

    def move_left(self, first_push: bool = False):
        self.table.move_left(first_push)

    def set_scrollbar(self, active: bool):
        if active:
            self.table.set_scrollbar_mode(1)
        else:
            self.table.set_scrollbar_mode(0)

    def set_arrows(self, active: bool):
        if active:
            self.table.set_arrow_mode(1)
        else:
            self.table.set_arrow_mode(0)

    def draw(self, surf, focus=1): # focus allows us to stop updating the animated bits if we're not in focus
        self.base_component._should_redraw = True
        self.table.set_cursor_mode(focus)
        ui_surf = self.base_component.to_surf()
        surf.blit(ui_surf, (0, 0))
        return surf
