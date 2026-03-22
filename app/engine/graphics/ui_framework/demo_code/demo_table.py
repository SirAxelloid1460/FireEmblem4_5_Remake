from random import choice
from app.constants import COLORKEY
from app.engine.game_menus.menu_components.generic_menu.simple_menu import ChoiceTable, SimpleIconTable
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

class DemoTable():
    def __init__(self):
        axe_icon = pygame.image.load(os.path.join(DIR_PATH, 'axe.png'))
        options = [
            (axe_icon, 'axe1'),
            (axe_icon, 'axe2'),
            (axe_icon, 'axe3'),
            (axe_icon, 'axe4'),
            (axe_icon, 'axe5'),
            (axe_icon, 'axe6'),
            (axe_icon, 'axe7'),
            (axe_icon, 'axe8')
        ]

        self.base_component = UIComponent.create_base_component(WINWIDTH, WINHEIGHT)
        self.base_component.set_chronometer(current_milli_time)

        table1 = SimpleIconTable('table', self.base_component, options, num_columns=2)
        table1.margin = (10, 10, 10, 10)
        self.base_component.add_child(table1)

        options2 = [
            (axe_icon, 'axe1'),
            (axe_icon, 'axe2')
        ]

        table2 = SimpleIconTable('table2', self.base_component, title ='weapons')
        table2.margin = (10, 10, 10, 10)
        table2.props.h_alignment = HAlignment.RIGHT

        self.base_component.add_child(table2)
        table2.set_data(options2)

        options3 = [
            'axe1',
            'axe1',
            'axe1',
            'axe1',
            'axe1',
            'axe1',
            'axe1',
            'axe2'
        ]

        self.choicetable1 = ChoiceTable('table3', self.base_component, options3, num_columns=2, num_rows=2)
        self.choicetable1.margin = (10, 10, 10, 10)
        self.choicetable1.props.v_alignment = VAlignment.BOTTOM

        self.base_component.add_child(self.choicetable1)


    def move_down(self):
        self.choicetable1.move_down()
    def move_up(self):
        self.choicetable1.move_up()
    def move_left(self):
        self.choicetable1.move_left()
    def move_right(self):
        self.choicetable1.move_right()

    def draw(self, surf: Surface) -> Surface:
        ui_surf = self.base_component.to_surf()
        surf.blit(ui_surf, (0, 0))
        return surf