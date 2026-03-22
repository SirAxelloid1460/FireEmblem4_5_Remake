from app.constants import COLORKEY
from app.engine.sprites import SPRITES
import os
import time

import pygame
import pygame.draw
import pygame.event
from pygame import Surface
from pygame import Color

from .demo_cursor import Cursor
from .demo_narration import NarrationDialogue
from ..premade_components.plain_text_component import PlainTextComponent, PlainTextLine
from ...ui_framework import *
from ..ui_framework_animation import *
from ..ui_framework_layout import *
from ..ui_framework_styling import *
from ..premade_components import *
from ..premade_animations import *

TILEWIDTH, TILEHEIGHT = 16, 16
TILEX, TILEY = 15, 10
WINWIDTH, WINHEIGHT = TILEX * TILEWIDTH, TILEY * TILEHEIGHT
DIR_PATH = os.path.dirname(os.path.realpath(__file__))

def current_milli_time():
    return round(time.time() * 1000)

class DemoUI():
    def __init__(self, cursor: Cursor):
        # this is just demo code, in real engine this would have a reference to game already
        self.cursor = cursor

        # initialize components
        self.location_title: UIComponent = UIComponent(name="location title")
        self.location_title.props.bg = pygame.image.load(os.path.join(DIR_PATH, 'world_map_location_box.png'))
        self.location_title.size = self.location_title.props.bg.get_size()
        self.location_title.props.v_alignment = VAlignment.TOP
        self.location_title.margin = (5, 5, 5, 5)
        self._init_location_title_animations()
        self.location_title.disable()

        self.location_title_text = PlainTextLine("location title text", self.location_title, "")
        self.location_title_text.props.h_alignment = HAlignment.CENTER
        self.location_title_text.props.v_alignment = VAlignment.CENTER
        self.location_title.add_child(self.location_title_text)

        self.minimap: UIComponent = UIComponent(name="minimap")
        self.minimap.props.v_alignment = VAlignment.BOTTOM
        self.minimap.props.layout = UILayoutType.LIST
        self.minimap.props.list_style = ListLayoutStyle.COLUMN_REVERSE
        self.minimap.size = ('40%', '40%')
        self.minimap.margin = (5, 5, 5, 5)
        self.minimap.padding = ('2%', '2%', '2%', '2%')
        self.minimap.props.bg_color = Color(0, 255, 0, 255)
        self.minimap.overflow = (50, 0, 50, 0)
        self._init_minimap_animations()

        self.item1:UIComponent = UIComponent(name="row1")
        self.item1.height = '30%'
        self.item1.width = '30%'
        self.item1.props.h_alignment = HAlignment.LEFT
        self.item1.margin = ('1%', '1%', '1%', '1%')
        self.item1.props.bg_color = Color(0, 0, 255, 255)
        self.minimap.add_child(self.item1)

        self.item2:UIComponent = UIComponent(name="row2")
        self.item2.height = '30%'
        self.item2.width = '30%'
        self.item2.props.h_alignment = HAlignment.CENTER
        self.item2.margin = ('1%', '1%', '1%', '1%')
        self.item2.props.bg_color = Color(128, 128, 128, 255)
        self.minimap.add_child(self.item2)

        self.item3:UIComponent = UIComponent(name="row3")
        self.item3.height = '30%'
        self.item3.width = '30%'
        self.item3.props.h_alignment = HAlignment.RIGHT
        self.item3.margin = ('1%', '1%', '1%', '1%')
        self.item3.props.bg_color = Color(128, 0, 128, 255)
        self.minimap.add_child(self.item3)

        self.narration = NarrationDialogue('narration')
        self.narration.disable()

        self.base_component = UIComponent.create_base_component(WINWIDTH, WINHEIGHT)
        self.base_component.name = "base"
        self.base_component.add_child(self.location_title)
        self.base_component.add_child(self.minimap)
        self.base_component.add_child(self.narration)
        self.base_component.set_chronometer(current_milli_time)

    def _init_minimap_animations(self):
        translate_down = translate_anim((0, 0), (0, WINHEIGHT))
        translate_up = translate_anim((0, WINHEIGHT), (0, 0))

        def change_align(c: UIComponent, *args):
            if c.props.h_alignment == HAlignment.LEFT:
                c.props.h_alignment = HAlignment.RIGHT
            else:
                c.props.h_alignment = HAlignment.LEFT
        change_alignment = UIAnimation(before_anim=change_align)

        self.minimap.save_animation(translate_down, 'translate_down')
        self.minimap.save_animation(translate_up, 'translate_up')
        self.minimap.save_animation(change_alignment, 'change_alignment')

    def _init_location_title_animations(self):
        exit_left = translate_anim((0, 0), (-WINWIDTH, 0), disable_after=True)
        exit_right = translate_anim((0, 0), (WINWIDTH, 0), disable_after=True)
        enter_left = translate_anim((-WINWIDTH, 0), (0, 0))
        enter_right = translate_anim((WINWIDTH, 0), (0, 0))

        def which_transition(c: UIComponent, *args) -> str:
            if c.props.h_alignment == HAlignment.LEFT:
                return "left"
            else:
                return "right"
        transition_out_anim = hybridize_animation({"left": exit_left, "right": exit_right}, which_transition)
        transition_in_anim = hybridize_animation({"left": enter_left, "right": enter_right}, which_transition)

        self.location_title.save_animation(transition_out_anim, '!exit')
        self.location_title.save_animation(transition_in_anim, '!enter')

    def _update_location_title_component(self):
        # determine name of location hovered
        node_name = self.cursor.get_hover()
        active = False
        if node_name:
            text = node_name
            self.location_title_text.set_text(text)
            active = True
        # logic for determining which side of the screen the title hangs out on
        # only switch sides if we aren't onscreen
        if not self.location_title.enabled:
            if self.cursor.x < TILEX // 2:
                # if both cursor and box is left, switch sides
                if self.location_title.props.h_alignment == HAlignment.LEFT:
                    self.location_title.props.h_alignment = HAlignment.RIGHT
            else:
                if self.location_title.props.h_alignment == HAlignment.RIGHT:
                    self.location_title.props.h_alignment = HAlignment.LEFT
        # animate out/in, if it's not already animating
        if len(self.location_title.queued_animations) == 0:
            if not active:
                if self.location_title.enabled:
                    # was active, now not, animate out
                    self.location_title.exit()
            else:
                if not self.location_title.enabled:
                    # was inactive, no active, animate in
                    self.location_title.enter()

    def _update_minimap_component(self):
        if not self.minimap.enabled:
            self.minimap.enter()
        if (self.cursor.x > TILEX // 2 and
            self.cursor.y > TILEY // 2 - 2):
            # if cursor is in the bottom right
            if self.minimap.props.h_alignment == HAlignment.RIGHT:
                # if we're also in the right - get out of dodge
                self.minimap.queue_animation(names=['translate_down', 'change_alignment', 'translate_up'])
        elif (self.cursor.x < TILEX // 2 and
              self.cursor.y > TILEY // 2 - 2):
            # cursor is in the bottom left
            if self.minimap.props.h_alignment != HAlignment.RIGHT:
                # then we leave the left
                self.minimap.queue_animation(names=['translate_down', 'change_alignment', 'translate_up'])

    def draw(self, surf: Surface) -> Surface:
        self._update_location_title_component()
        self._update_minimap_component()
        ui_surf = self.base_component.to_surf()
        surf.blit(ui_surf, (0, 0))
        return surf