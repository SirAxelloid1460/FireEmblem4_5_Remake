from __future__ import annotations
from app.engine.graphics.text.text_renderer import render_text, text_width
from app.engine.graphics.ui_framework.ui_framework_layout import ListLayoutStyle, UILayoutType
from app.constants import WINHEIGHT, WINWIDTH
from app.sprites import SPRITES

from typing import List, NamedTuple, TYPE_CHECKING, Tuple, Union
import re

from app.engine import engine, text_funcs
from app.engine.bmpfont import BmpFont
from app.engine.fonts import FONT
from app.engine.graphics.ui_framework.ui_framework_styling import UIMetric
from app.utilities.utils import clamp, tuple_add

if TYPE_CHECKING:
    from app.engine.engine import Surface

from ..ui_framework import ComponentProperties, ResizeMode, UIComponent

class TextProperties(ComponentProperties):
    """Properties that are particular to text-based components.
    """
    def __init__(self, parent: UIComponent):
        super().__init__(parent)
        # self-explanatory: the font (BmpFont)
        # font_name (str of the font name) is more encouraged to be used, but either works
        self.font: BmpFont = FONT['text']
        self.font_name: str = 'text'
        # maximum number of lines in a multiline component the text over, if max_width is set.
        # if 0, then it will split as many as necessary.
        self.max_lines: int = 0
        self.wrap: bool = True

    def __getattribute__(self, name: str):
        if name == 'font':
            if super().__getattribute__('font_name'):
                return FONT[super().__getattribute__('font_name')]
            else:
                pass
        return super().__getattribute__(name)

class PlainTextLine(UIComponent):
    class _RProps:
        text: str = ""
        font_name: str = ""

    """A component that represents a single line of text. You shouldn't assign size to this component"""
    def __init__(self, name: str = "", parent: UIComponent = None, text: str = "", font_name: str = "text"):
        super().__init__(name=name, parent=parent)
        self.prev_rprops = self._RProps()
        self.props: TextProperties = TextProperties(self)
        self.props.font_name = font_name
        self.text = text
        self._reset('init')

    @property
    def font_height(self) -> int:
        return self.props.font.height

    def set_text(self, text: str):
        self.text = text

    def set_font_name(self, font_name: str):
        self.props.font_name = font_name

    def should_redraw(self) -> bool:
        should_redraw = False
        if self.prev_rprops.text != self.text or self.prev_rprops.font_name != self.props.font_name:
            should_redraw = True
        return should_redraw

    def did_redraw(self):
        self.prev_rprops.text = self.text
        self.prev_rprops.font_name = self.props.font_name

    def _reset(self, reason: str):
        """Pre-draw, basically; take all known props, and recalculate one last time."""
        text_size = (text_width(self.props.font_name, self.text) + 1, self.props.font.height)
        self.size = text_size
        text_surf = engine.create_surface(text_size, True)
        if self.props.bg_color:
            text_surf.fill(self.props.bg_color)
        render_text(text_surf, [self.props.font_name], [self.text], None, (0, 0))
        self.props.bg = text_surf

class PlainTextComponent(UIComponent):
    class _RProps:
        text: str = ""
        num_visible_chars: int = 0
        font_name: str = ""

    def __init__(self, name: str, parent: UIComponent = None, text: str = "", font_name: str = "text"):
        super().__init__(name=name, parent=parent)
        self.prev_rprops = self._RProps()
        self.props: TextProperties = TextProperties(self)
        self.props.layout = UILayoutType.LIST
        self.props.list_style = ListLayoutStyle.COLUMN

        self.props.font_name = font_name
        self.text = str(text)
        self.num_visible_chars: int = len(self.text)

        try:
            self._reset('init')
        except AttributeError: # a child class is calling this
            pass

    @property
    def font_height(self) -> int:
        return self.props.font.height

    @property
    def scrolled_line(self) -> int:
        return self.scroll[1] / self.font_height + 1

    def set_scroll_height(self, scroll_to: Union[int, float, str, UIMetric]):
        """crops the text component to the place you want to scroll to. This supports
        calculating the y-coord of a specific line or space between two lines (int, float),
        or a specific pixel or percentage (str, UIMetric)

        Args:
            scroll_to (Union[int, float, str, UIMetric]): location of scroll.
        """
        if isinstance(scroll_to, (int, float)):
            scroll_to = clamp(scroll_to, 1, len(self.children))
            self.scroll = (0, (scroll_to - 1) * self.font_height)
        elif isinstance(scroll_to, str) or isinstance(scroll_to, UIMetric):
            self.scroll = (0, scroll_to)
        else:
            self.scroll = (0, 0)

    def scroll_to_nearest_line(self):
        line_num = round(self.scroll[1] / self.font_height) + 1
        self.scroll = (0, (line_num - 1) * self.font_height)

    def set_text(self, text: str):
        self.text = text
        self.num_visible_chars = len(text)

    def set_font_name(self, font_name: str):
        self.props.font_name = font_name
        for child in self.children:
            child.set_font_name(font_name)

    def set_number_visible_chars(self, num: int):
        self.num_visible_chars = num

    def _reset(self, reason: str):
        if not self.props.wrap:
            if len(self.children) > 1:
                self.children.clear()
            line1 = PlainTextLine('line1', self, self.text, self.props.font_name)
            self.add_child(line1)
        else:
            all_text = self.text
            all_split = text_funcs.line_wrap(self.props.font_name, all_text, self.iwidth, True)
            visible_text = self.text[:self.num_visible_chars]
            visible_split = text_funcs.line_wrap(self.props.font_name, visible_text, self.iwidth, True)
            if len(self.children) != len(all_split): # our text itself changed, we should full reset
                self.children.clear()
                for i in range(0, len(all_split)):
                    newline = PlainTextLine(parent=self, font_name=self.props.font_name)
                    self.add_child(newline)
            for idx, line in enumerate(visible_split): # set the visible lines
                self.children[idx].set_text(line)
            for text_line in self.children[len(visible_split):]: # clear the invisible lines
                text_line.set_text('')
        self.height = self.font_height * max(len(self.children), 1)
        if self.props.max_lines:
            self.max_height = self.font_height * min(max(len(self.children), 1), self.props.max_lines)

    def should_redraw(self) -> bool:
        should_redraw = False
        if (self.prev_rprops.text != self.text
            or self.prev_rprops.num_visible_chars != self.num_visible_chars
            or self.prev_rprops.font_name != self.props.font_name):
            should_redraw = True
        return super().should_redraw() or should_redraw

    def did_redraw(self):
        self.prev_rprops.text = self.text
        self.prev_rprops.num_visible_chars = self.num_visible_chars
        self.prev_rprops.font_name = self.props.font_name
