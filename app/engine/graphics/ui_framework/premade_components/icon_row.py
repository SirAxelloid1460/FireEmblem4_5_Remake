from __future__ import annotations
from typing import Optional
from app.engine.graphics.ui_framework.premade_components.plain_text_component import PlainTextLine

from app.engine import engine

from ..ui_framework import HAlignment, UIComponent
from ..ui_framework_layout import ListLayoutStyle, UILayoutType
from ..ui_framework_styling import UIMetric

class IconRow(UIComponent):
    def __init__(self, name: str = None, parent: UIComponent = None,
                 width: str = '100%', height: str = '0%', text: str = '',
                 icon: engine.Surface | UIComponent = None,
                 text_align: HAlignment = HAlignment.LEFT,
                 font: str = 'text', data=None):
        super().__init__(name=name, parent=parent)
        if text_align == HAlignment.LEFT:
            self.props.layout = UILayoutType.LIST
            self.props.list_style = ListLayoutStyle.ROW

        self.data = data

        self.text = PlainTextLine(text, self, text)
        self.text.props.font_name = font
        self.text.props.h_alignment = text_align

        self.icon: UIComponent = self.process_icon(icon)

        parsed_height = UIMetric.parse(height).to_pixels(self.parent.height)
        self.size = (width, max(parsed_height, self.icon.height))

        self.add_child(self.icon)
        self.add_child(self.text)
        self.update_font()

    def _reset(self, reason: str = None):
        self.update_font()

    def set_text(self, text: str):
        if text != self.text.text:
            self._should_redraw = True
        self.text.set_text(text)

    def set_data(self, data: Optional[str]):
        self.data = data

    def update_font(self):
        total_width = self.icon.width + self.text.twidth
        if total_width > self.max_width:
            self.text.set_font_name('narrow')

    def process_icon(self, icon: UIComponent | engine.Surface | None) -> UIComponent:
        if isinstance(icon, UIComponent):
            return icon
        elif isinstance(icon, engine.Surface):
            return UIComponent.from_existing_surf(icon)
        else:
            return UIComponent.from_existing_surf(engine.create_surface((0, self.text.height), True))

    def get_text_topleft(self):
        return self.layout_handler.generate_child_positions(True)[1]

    def set_icon(self, icon: engine.Surface):
        self.icon = self.process_icon(icon)
        self.children.clear()
        self.add_child(self.icon)
        self.add_child(self.text)
        self._should_redraw = True