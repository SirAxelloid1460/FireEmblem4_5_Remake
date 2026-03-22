from __future__ import annotations
from app.sprites import SPRITES

import re
from typing import TYPE_CHECKING, List

from app.engine import text_funcs

from ..ui_framework import UIComponent
from .plain_text_component import PlainTextComponent, PlainTextLine


class DialogTextComponent(PlainTextComponent):
    def __init__(self, name: str, parent: UIComponent = None, text: str = "", font_name: str = "text"):
        super().__init__(name=name, parent=parent, text="", font_name=font_name)
        self.text = text
        self.processed_text = self.text.replace('{w}', '').replace('|', '').replace('{br}', '')
        self.wait_points = self.generate_indexes_of_wait_points(self.text)
        self.num_visible_chars = 0
        self.should_display_waiting_cursor = False

        self.cursor = SPRITES.get('waiting_cursor')
        self.cursor_y_offset = [0]*20 + [1]*2 + [2]*8 + [1]*2
        self.cursor_y_offset_index = 0

        self._reset('init')

    def set_should_draw_cursor(self, b: bool):
        self.should_display_waiting_cursor = b
        self._should_redraw = True
        self.manual_surfaces.clear()

    def add_breaks_to_raw_dialog(self, text: str) -> List[str]:
        # strip all special patterns
        text = text.replace('{w}', '')
        text = text.replace('|', '{br}')
        paragraphs = text.split('{br}')
        line_broken_text = []
        for paragraph in paragraphs:
            line_broken_text += text_funcs.line_wrap(self.props.font_name, paragraph, self.iwidth, True)
        return line_broken_text

    def generate_indexes_of_wait_points(self, unprocessed_text: str) -> List[int]:
        # a little bit of an algorithm. Takes a string such as this: 'an apple{w} a day,{w} the doctor{w} away'
        # and provides the indexes where the {w}s would go in the simplified string, 'an apple a day, the doctor away'
        # in this example, it would return [8, 15, 26], corresponding to the spaces (marked by a '|'):
        # 'an apple|a day,|the doctor|away'
        wait_points = []
        unprocessed_wait_points = [m.start() for m in re.finditer('{w}', unprocessed_text)]
        for u in unprocessed_wait_points:
            substr = unprocessed_text[:u].replace('{w}', '')
            wait_points.append(len(substr))
        return wait_points

    def is_waiting(self):
        return self.num_visible_chars in [wait_point_idx for wait_point_idx in self.wait_points] or self.is_done()

    def is_done(self):
        return self.num_visible_chars >= len(self.processed_text)

    def is_at_end_of_line(self):
        all_split = self.add_breaks_to_raw_dialog(self.text)
        curr_index = self.num_visible_chars
        for line in all_split:
            curr_index -= len(line)
            if curr_index == 0:
                return True
            if curr_index < 0:
                return False
        return False

    def num_lines_visible(self):
        all_split = self.add_breaks_to_raw_dialog(self.text)
        curr_index = self.num_visible_chars
        num_lines_visible = 0
        for line in all_split:
            if curr_index <= 0:
                break
            num_lines_visible += 1
            curr_index -= len(line)
        return num_lines_visible

    def num_lines_onscreen(self):
        return self.num_lines_visible() - (self.scroll[1] / self.font_height)

    def get_max_lines(self):
        if self.props.max_lines == 0:
            return 999999
        else:
            return self.props.max_lines

    def set_text(self, text: str):
        self.text = text
        self.processed_text = self.text.replace('{w}', '').replace('|', '').replace('{br}', '')
        self.wait_points = self.generate_indexes_of_wait_points(self.text)
        self.num_visible_chars = 0

    def wiggle_cursor_height(self):
        self.cursor_y_offset_index = (self.cursor_y_offset_index + 1) % len(self.cursor_y_offset)
        return (self.cursor_y_offset[self.cursor_y_offset_index] + self.font_height / 3 +
                    self.font_height * (self.num_lines_visible() - 1))

    def should_redraw(self) -> bool:
        return super().should_redraw() or self.should_display_waiting_cursor

    def _reset(self, reason: str):
        all_split = self.add_breaks_to_raw_dialog(self.text)
        visible_split = []
        remaining_chars = self.num_visible_chars
        for line in all_split:
            if remaining_chars >= len(line):
                visible_split.append(line)
                remaining_chars -= len(line)
            else:
                visible_split.append(line[:remaining_chars])
                break
        if len(self.children) != len(all_split):
            self.children.clear()
            for i in range(0, len(all_split)):
                newline = PlainTextLine(parent=self, font_name=self.props.font_name)
                self.add_child(newline)
        for idx, line in enumerate(visible_split):
            self.children[idx].set_text(line)
        for text_line in self.children[len(visible_split):]:
            text_line.set_text('')
        self.height = self.font_height * max(len(self.children), 1)
        if self.props.max_lines:
            self.max_height = self.font_height * min(max(len(self.children), 1), self.props.max_lines)
        if self.should_display_waiting_cursor and self.is_waiting():
            self.manual_surfaces.clear()
            width_of_last_visible_line = self.children[len(visible_split) - 1].width
            height = self.wiggle_cursor_height()
            self.add_surf(self.cursor, (width_of_last_visible_line, height))