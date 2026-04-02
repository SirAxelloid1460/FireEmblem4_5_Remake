from __future__ import annotations

from typing import List

from app.utilities import tclamp
from app.constants import WINWIDTH, WINHEIGHT

from app.engine.graphics.ui_framework.ui_framework import UIComponent
from app.engine.graphics.ui_framework.ui_framework_layout import UILayoutType, ListLayoutStyle
from app.engine.graphics.ui_framework.premade_components import PlainTextComponent

class DialogEntryComponent(UIComponent):
    def __init__(self, name, speaker, text, parent=None):
        super().__init__(name=name, parent=parent)

        self.props.layout = UILayoutType.LIST

        self.props.list_style = ListLayoutStyle.COLUMN
        self.speaker = PlainTextComponent("speaker", self, text=speaker)
        self.speaker.padding = (5, 0, 0, 0)
        self.speaker.set_font_name('text-yellow')

        self.text = PlainTextComponent("dialog text", self, text=text)
        self.text.padding = (5, 5, 0, 10)
        self.size = self.calculate_size()

        self.add_child(self.speaker)
        self.add_child(self.text)

    def calculate_size(self):
        width = self.parent.width
        height = self.text.height + self.speaker.height
        return (width, height)

class DialogLogContainer(UIComponent):
    def __init__(self, name, parent=None):
        super().__init__(name=name, parent=parent)
        self.props.layout = UILayoutType.LIST
        self.props.bg_color = (33, 33, 33, 225)
        self.props.list_style = ListLayoutStyle.COLUMN
        self.text_objects: List[PlainTextComponent] = []
        self.scroll_height = self.parent.height

    def scroll_up_down(self, dist):
        self.scroll = tclamp((self.scroll[0], self.scroll[1] + dist), (0, 0), (0, self.theight - self.max_height))

    def scroll_all(self):
        self.scroll = (self.scroll[0], self.scroll_height - self.height)

    def update_scroll_height(self):
        scroll_height = 0
        for text in self.text_objects:
            scroll_height += text.height

        self.scroll_height = max(scroll_height, self.parent.height)
        self.height = self.scroll_height

    def add_entry(self, dialog_entry: DialogEntryComponent):
        self.add_child(dialog_entry)
        self.text_objects.append(dialog_entry)
        self.update_scroll_height()

    def remove_entry(self, entry_ui):
        self.remove_child(entry_ui.name)
        self.text_objects.remove(entry_ui)
        self.update_scroll_height()

    def get_last_entry(self):
        if self.text_objects:
            return self.text_objects[-1]
        else:
            return None

class DialogLogUI:
    entry_count = 0

    def __init__(self):
        self.base_component = UIComponent.create_base_component(WINWIDTH, WINHEIGHT)
        self.base_component.name = "base"

        self.log_container = DialogLogContainer('container', parent=self.base_component) # Component contains all the dialog log entries.
        self.base_component.add_child(self.log_container)

    def add_entry(self, speaker: str, text: str):
        # Create and add new entry to ui.
        entry = DialogEntryComponent(f"entry no. {self.entry_count}", speaker, text, parent=self.log_container)
        self.log_container.add_entry(entry)
        self.entry_count += 1
        return entry # Return ui component

    def remove_entry(self, entry: DialogEntryComponent):
        self.log_container.remove_entry(entry)
        self.entry_count -= 1

    def scroll_up(self):
        self.log_container.scroll_up_down(-20)

    def scroll_down(self):
        self.log_container.scroll_up_down(20)

    def scroll_all(self):
        self.log_container.scroll_all()

    def get_last_entry(self):
        return self.log_container.get_last_entry()

    def draw(self, surf):
        ui_surf = self.base_component.to_surf()
        surf.blit(ui_surf, (0, 0))
        return surf
