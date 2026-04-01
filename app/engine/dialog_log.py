from __future__ import annotations

import re

from typing import Tuple, List

from app.engine.state import State
from app.engine.fluid_scroll import FluidScroll
from app.engine.game_state import game

from app.engine.graphics.dialog.dialog_log_ui import DialogLogUI

class DialogLogState(State):
    name = 'dialog_log'
    transparent = True

    def start(self):
        self.fluid = FluidScroll()

    def begin(self):
        game.dialog_log.ui.scroll_all() # Set scroll to bottom.

    def take_input(self, event):
        self.fluid.update()
        directions = self.fluid.get_directions()

        if 'UP' in directions:
            game.dialog_log.ui.scroll_up()
        elif 'DOWN' in directions:
            game.dialog_log.ui.scroll_down()
        elif event == 'INFO' or event == 'BACK':
            game.state.back()

    def draw(self, surf):
        surf = game.dialog_log.ui.draw(surf)
        return surf

class DialogLog():
    def __init__(self):
        self.ui = DialogLogUI()
        self.entries: List[Tuple[str, str]] = []
        self.last_entry = None

    def append(self, dialog_tuple: Tuple[str, str]):
        speaker, text = dialog_tuple[0], dialog_tuple[1]
        text = DialogLog.clean_speak_text(text)
        self.last_entry = self.ui.add_entry(speaker, text)
        self.entries.append((speaker, text))

    def pop(self):
        self.ui.remove_entry(self.last_entry)
        self.last_entry = self.ui.get_last_entry()
        self.entries.pop()

    def clear(self):
        while self.last_entry:
            self.pop()
        self.entries.clear()

    def save(self):
        return self.entries

    def load(self, entries: List[Tuple[str, str]]):
        for entry in entries:
            self.append(entry)

    @staticmethod
    def clean_speak_text(s):
        """Returns a copy of the "speak" command text without any commands

        >>> s = 'This is a test| with{w}{br} commands.'
        >>> clean_text(s)
        >>> 'This is a test with commands.'
        """
        x = re.sub(r'({\w*})|(\|)|(;)/', ' ', s)
        # Get rid of extra spaces
        return re.sub(r' +', ' ', x)

    @classmethod
    def restore(cls, entries: List[Tuple[str, str]]):
        d = cls()
        d.load(entries)
        return d
