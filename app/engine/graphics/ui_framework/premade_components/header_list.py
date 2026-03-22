from __future__ import annotations

from typing import Callable, Generic, List, TypeVar

from app.engine import engine

from ..ui_framework import UIComponent
from ..premade_animations import component_scroll_anim
from ..ui_framework_layout import ListLayoutStyle, UILayoutType

T = TypeVar('T', bound=UIComponent)

class HeaderList(UIComponent, Generic[T]):
    def __init__(self, name: str = None, parent: UIComponent = None, header_row: T = None,
                 data_rows: List[T] = None, height: str = '100%', width: str = '100%', list_overflow: int = 6):
        super().__init__(name=name, parent=parent)
        self.size = (width, height)
        self.max_height = height
        self.props.layout = UILayoutType.LIST
        self.props.list_style = ListLayoutStyle.COLUMN
        self.list_overflow = list_overflow

        self.data_rows = data_rows

        # children references
        self.header_row = header_row
        self.scrollable_list = UIComponent('list', self)
        self.regenerate_list_component()
        self.repopulate_children()

    @property
    def scrolled_index(self):
        if self.scrollable_list and self.row_height:
            return self.scrollable_list.scroll[1] / self.row_height
        else:
            return 0

    @property
    def row_height(self):
        if self.data_rows:
            return self.data_rows[0].height
        else:
            return 0

    @property
    def max_visible_rows(self):
        if self.row_height and self.scrollable_list:
            return self.scrollable_list.height / self.row_height
        else:
            return 0

    @property
    def index_scrolled(self) -> int:
        if self.scrollable_list:
            index = self.scrollable_list.scroll[1] / self.row_height
            return index

    def repopulate_children(self):
        self.children = []
        if self.header_row:
            self.add_child(self.header_row)
        if self.scrollable_list:
            self.add_child(self.scrollable_list)

    def set_header(self, header_row: T):
        self.header_row = header_row
        self.repopulate_children()

    def set_data_rows(self, data_rows: List[T]):
        self.data_rows = data_rows
        self.regenerate_list_component()
        self.repopulate_children()

    def is_scrolling(self) -> bool:
        if self.scrollable_list and self.scrollable_list.is_animating():
            return True
        else:
            return False

    def sort_rows(self, sort_func: Callable[[T], int]):
        if self.scrollable_list:
            self.scrollable_list.children = sorted(self.scrollable_list.children, key=sort_func)
        self._should_redraw = True
        self.scrollable_list._should_redraw = True

    def regenerate_list_component(self) -> UIComponent:
        if not self.data_rows:
            return
        list_comp = UIComponent('list', self)
        list_comp.size = ('100%', self.height - (self.header_row.height if self.header_row else 0))
        list_comp.max_height = self.height
        list_comp.props.layout = UILayoutType.LIST
        list_comp.props.list_style = ListLayoutStyle.COLUMN
        list_comp.overflow = (2, 2, self.list_overflow, 0)

        total_height = 0
        for row in self.data_rows:
            row.max_width = self.width
            list_comp.add_child(row)
            total_height += row.height
        list_comp.height = max(list_comp.max_height, total_height)
        self.scrollable_list = list_comp

    def scroll_down(self):
        if self.scrollable_list:
            if self.index_scrolled == len(self.data_rows) - self.max_visible_rows + 1: #already scrolled to the bottom
                return
            scroll_down_anim = component_scroll_anim(self.scrollable_list.scroll, (self.scrollable_list.scroll[0], self.scrollable_list.scroll[1] + self.row_height))
            self.scrollable_list.queue_animation(animations=[scroll_down_anim])

    def scroll_up(self):
        if self.scrollable_list:
            if self.index_scrolled == 0: # already scrolled to the top
                return
            scroll_down_anim = component_scroll_anim(self.scrollable_list.scroll, (self.scrollable_list.scroll[0], self.scrollable_list.scroll[1] - self.row_height))
            self.scrollable_list.queue_animation(animations=[scroll_down_anim])

    def to_surf(self, no_cull=False) -> engine.Surface:
        # manually cull rows
        if self.scrollable_list:
            self.scrollable_list._should_redraw = True
            for idx, row in enumerate(self.scrollable_list.children):
                if idx < self.scrolled_index - 0.4:
                    row.disable()
                elif idx > self.scrolled_index + self.max_visible_rows:
                    row.disable()
                else:
                    row.enable()
        return super().to_surf(no_cull=no_cull)
