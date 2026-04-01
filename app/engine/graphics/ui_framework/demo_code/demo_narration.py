from app.constants import COLORKEY
import os
import time

import pygame
import pygame.draw
import pygame.event

from app.engine import engine

from ..premade_components.dialog_text_component import DialogTextComponent
from ...ui_framework import UIComponent, HAlignment, VAlignment
from ..ui_framework_animation import InterpolationType
from ..premade_animations.animation_templates import fade_anim, translate_anim
from ..premade_animations.text_animations import scroll_anim, scroll_to_next_line_anim, type_line_anim

TILEWIDTH, TILEHEIGHT = 16, 16
TILEX, TILEY = 15, 10
WINWIDTH, WINHEIGHT = TILEX * TILEWIDTH, TILEY * TILEHEIGHT
DIR_PATH = os.path.dirname(os.path.realpath(__file__))

def current_milli_time():
    return round(time.time() * 1000)

class NarrationDialogue(UIComponent):
    def __init__(self, name: str, parent: UIComponent = None, anim_duration: int = 3000):
        super().__init__(name=name, parent=parent)
        self.anim_duration = anim_duration

        self.text_vertical_offset = 35
        self.text_horizontal_area = 180
        self.text_horizontal_margin = 30

        # initialize the animated top bar and bottom text area
        # create the sprites
        narration_window_sprite = pygame.image.load(os.path.join(DIR_PATH, 'narration_window.png'))
        engine.set_colorkey(narration_window_sprite, COLORKEY)
        top_height = narration_window_sprite.get_height() // 2
        bottom_height = narration_window_sprite.get_height() - top_height
        width = narration_window_sprite.get_width()

        top_sprite = engine.subsurface(narration_window_sprite, (0, 0, width, top_height))
        bottom_sprite = engine.subsurface(narration_window_sprite, (0, top_height, width, bottom_height))

        self.top_bar: UIComponent = UIComponent.from_existing_surf(top_sprite)
        self.top_bar.props.v_alignment = VAlignment.TOP
        self.top_bar.name = 'narration_window_top_bar'

        self.bot_text_area: UIComponent = UIComponent.from_existing_surf(bottom_sprite)
        self.bot_text_area.props.v_alignment = VAlignment.BOTTOM
        self.bot_text_area.name = 'narration_window_bot_area'

        self._init_textbox_animations()

        # initialize the text component
        self.text: DialogTextComponent = DialogTextComponent('narration_text', None,
            (
            '"Lorem ipsum dolor sit amet, consectetur adipiscing elit, {w}'
            'sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. {w}'
            'Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris {w}'
            'nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in {w}'
            'reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla{w}'
            'pariatur. Excepteur sint occaecat cupidatat non proident, sunt in {w}'
            'culpa qui officia deserunt mollit anim id est laborum."{w}'
            ))
        self.text.max_width = self.text_horizontal_area
        self.text.margin = (self.text_horizontal_margin, self.text_horizontal_margin, self.text_vertical_offset, 0)
        self.text.num_visible_chars = 0
        self.text.props.max_lines = 2
        self._init_text_animations()

        self.bot_text_area.add_child(self.text)

        self.add_child(self.top_bar)
        self.add_child(self.bot_text_area)

    def _init_textbox_animations(self):
        anim_duration = self.anim_duration
        fade_out = fade_anim(1, 0.2, anim_duration, True, InterpolationType.LOGARITHMIC, skew=0.1)
        fade_in = fade_anim(0.2, 1, anim_duration, False, InterpolationType.LOGARITHMIC, skew=3)

        translate_offscreen_down = translate_anim((0, 0), (0, WINHEIGHT/2), disable_after=True, duration=anim_duration, interp_mode=InterpolationType.LOGARITHMIC, skew=0.1) + fade_out
        translate_onscreen_up = translate_anim((0, WINHEIGHT/2), (0, 0), duration=anim_duration, interp_mode=InterpolationType.LOGARITHMIC, skew=3) + fade_in

        translate_offscreen_up = translate_anim((0, 0), (0, -WINHEIGHT/2), disable_after=True, duration=anim_duration, interp_mode=InterpolationType.LOGARITHMIC, skew=0.1) + fade_out
        translate_onscreen_down = translate_anim((0, -WINHEIGHT/2), (0, 0), duration=anim_duration, interp_mode=InterpolationType.LOGARITHMIC, skew=3) + fade_in

        self.top_bar.save_animation(translate_offscreen_up, '!exit')
        self.top_bar.save_animation(translate_onscreen_down, '!enter')

        self.bot_text_area.save_animation(translate_offscreen_down, '!exit')
        self.bot_text_area.save_animation(translate_onscreen_up, '!enter')

    def _init_text_animations(self):
        scroll_down = scroll_anim('0%', '100%', 2000)
        scroll_next = scroll_to_next_line_anim(duration=750)
        write_line = type_line_anim(time_per_char=10)
        self.text.save_animation(scroll_down, 'scroll')
        self.text.save_animation(scroll_next, 'scroll_next')
        self.text.save_animation(write_line, 'line')

    def set_text(self, text):
        self.text.set_text(text)
        self.text.set_visible(0)

    def start_scrolling(self):
        self.text.num_visible_chars = len(self.text.text)
        self.text.queue_animation(names=['scroll'])

    def scroll_to_next(self):
        self.text.queue_animation(names=['scroll_next'])

    def write_a_line(self):
        self.text.queue_animation(names=['line'])

class NarrationUI():
    def __init__(self):
        self.narration = NarrationDialogue('narration')
        self.narration.disable()

        self.base_component = UIComponent.create_base_component(WINWIDTH, WINHEIGHT)
        self.base_component.name = "base"
        self.base_component.add_child(self.narration)
        self.base_component.set_chronometer(current_milli_time)

    def draw(self, surf: engine.Surface) -> engine.Surface:
        ui_surf = self.base_component.to_surf()
        surf.blit(ui_surf, (0, 0))
        return surf