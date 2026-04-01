from app.engine.base_surf import create_base_surf
from app.engine.sprites import SPRITES
from app.engine import image_mods
import os
import time

import pygame
import pygame.draw
import pygame.event
from pygame import Surface

from ..premade_components import PlainTextComponent
from ..premade_components.header_list import *
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

class SORT_TYPE(Enum):
    ASCENDING = 0
    DESCENDING = 1

NUM_PAGES = 3

class DemoUnitInfo():
    def __init__(self, name, klass, lvl, exp, hp, maxhp, pow, skill, spd, luck, dfns, res, affin, equip, atk, hit, avoid):
        self.name = name
        self.klass = klass
        self.lvl = lvl
        self.exp = exp
        self.hp = hp
        self.maxhp = maxhp
        self.pow = pow
        self.skill = skill
        self.spd = spd
        self.luck = luck
        self.dfns = dfns
        self.res = res
        self.affin = affin
        self.equip = equip
        self.atk = atk
        self.hit = hit
        self.avoid = avoid

DEMO_UNIT_DATA: List[DemoUnitInfo] = [
    DemoUnitInfo('Gilliam', 'Knight', 4, 0, 25, 25, 9, 6, 3, 3, 9, 3, 'lightning',  'Iron Lance', 16, 93, 9),
    DemoUnitInfo('Franz', 'Cavalier', 1, 65, 8, 20, 7, 5, 7, 2, 6, 1, 'light',      'Iron Sword', 12, 101, 16),
    DemoUnitInfo('Seth', 'Paladin', 2, 13, 27, 31, 14,14,12,13,12, 8, 'anima',      'Silver Lance', 28, 119, 37),
    DemoUnitInfo('Seth', 'Paladin', 2, 13, 27, 31, 14,14,12,13,12, 8, 'anima',      'Silver Lance', 28, 119, 37),
    DemoUnitInfo('Seth', 'Paladin', 2, 13, 27, 31, 14,14,12,13,12, 8, 'anima',      'Silver Lance', 28, 119, 37),
    DemoUnitInfo('Seth', 'Paladin', 2, 13, 27, 31, 14,14,12,13,12, 8, 'anima',      'Silver Lance', 28, 119, 37),
    DemoUnitInfo('Seth', 'Paladin', 2, 13, 27, 31, 14,14,12,13,12, 8, 'anima',      'Silver Lance', 28, 119, 37),
    DemoUnitInfo('Seth', 'Paladin', 2, 13, 27, 31, 14,14,12,13,12, 8, 'anima',      'Silver Lance', 28, 119, 37),
    DemoUnitInfo('Seth', 'Paladin', 2, 13, 27, 31, 14,14,12,13,12, 8, 'anima',      'Silver Lance', 28, 119, 37),
    DemoUnitInfo('Seth', 'Paladin', 2, 13, 27, 31, 14,14,12,13,12, 8, 'anima',      'Silver Lance', 28, 119, 37),
    DemoUnitInfo('Seth', 'Paladin', 2, 13, 27, 31, 14,14,12,13,12, 8, 'anima',      'Silver Lance', 28, 119, 37),
    DemoUnitInfo('Seth', 'Paladin', 2, 13, 27, 31, 14,14,12,13,12, 8, 'anima',      'Silver Lance', 28, 119, 37),
    DemoUnitInfo('Seth', 'Paladin', 2, 13, 27, 31, 14,14,12,13,12, 8, 'anima',      'Silver Lance', 28, 119, 37),
    DemoUnitInfo('Seth', 'Paladin', 2, 13, 27, 31, 14,14,12,13,12, 8, 'anima',      'Silver Lance', 28, 119, 37),
    DemoUnitInfo('Seth', 'Paladin', 2, 13, 27, 31, 14,14,12,13,12, 8, 'anima',      'Silver Lance', 28, 119, 37),
    DemoUnitInfo('Seth', 'Paladin', 2, 13, 27, 31, 14,14,12,13,12, 8, 'anima',      'Silver Lance', 28, 119, 37),
    DemoUnitInfo('Seth', 'Paladin', 2, 13, 27, 31, 14,14,12,13,12, 8, 'anima',      'Silver Lance', 28, 119, 37),
    DemoUnitInfo('Seth', 'Paladin', 2, 13, 27, 31, 14,14,12,13,12, 8, 'anima',      'Silver Lance', 28, 119, 37),
    DemoUnitInfo('Seth', 'Paladin', 2, 13, 27, 31, 14,14,12,13,12, 8, 'anima',      'Silver Lance', 28, 119, 37),
    DemoUnitInfo('Seth', 'Paladin', 2, 13, 27, 31, 14,14,12,13,12, 8, 'anima',      'Silver Lance', 28, 119, 37),
    DemoUnitInfo('Eirika', 'Lord', 1, 0, 16, 16,    4, 8, 9, 5, 3, 1, 'light',      'Rapier', 11, 113, 23)
]

class DemoUnitGrid(UIComponent):
    COLUMN_ATTR = [
        'klass',
        'lvl',
        'exp',
        'hp',
        'maxhp',
        'pow',
        'skill',
        'spd',
        'luck',
        'dfns',
        'res',
        'affin',
        'equip',
        'atk',
        'hit',
        'avoid'
    ]
    COLUMN_WIDTHS = [
        '40%', #klass
        '15%', #lvl
        '15%', #exp
        '15%', #hp
        '15%', #maxhp

        '14%', # pow
        '14%', # skill
        '14%', # spd
        '14%', # luck
        '14%', # dfns
        '14%', # res
        '16%', # affin

        '40%', # equip
        '20%', # atk
        '20%', # hit
        '20%', # avoid
    ]
    COLUMN_NAMES = [
        'Class',
        'Lv',
        'Exp',
        'HP',
        'Max',
        'S/M',
        'Skill',
        'Spd',
        'Luck',
        'Def',
        'Res',
        'Affin',
        'Equip',
        'Atk',
        'Hit',
        'Avoid'
    ]
    MAX_PAGES = 3

    def __init__(self, name: str = None, parent: UIComponent = None, data: List[DemoUnitInfo]=None):
        super().__init__(name=name, parent=parent)
        self.size = ('75%', '100%')
        self.max_width = '75%'
        self.props.bg_color = (0, 0, 128, 128)
        self.data = data
        self.page = 0

        # children layout
        self.props.layout = UILayoutType.LIST
        self.props.list_style = ListLayoutStyle.ROW

        self.lists: List[HeaderList] = []

        # first page
        for i in range(len(self.COLUMN_ATTR)):
            self.lists.append(HeaderList(
                name=self.COLUMN_ATTR[i],
                parent=self,
                header_row=IconRow(text=self.COLUMN_NAMES[i], text_align=HAlignment.CENTER),
                data_rows=self.generate_rows(self.COLUMN_ATTR[i]),
                height=self.height - 8,
                width=self.round_column_width(self.COLUMN_WIDTHS[i]),
                should_freeze=True
            ))
        total_width = 0
        for hlist in self.lists:
            hlist.margin = (0, 0, 3, 0)
            self.add_child(hlist)
            total_width += hlist.width
        self.width = total_width

    def round_column_width(self, ui_metric_str: str) -> str:
        return ui_metric_str

    def generate_rows(self, attribute_name, icon = None):
        rows = []
        for unit in self.data:
            if attribute_name == 'maxhp':
                rows.append(IconRow(unit.name, text=('/' + str(unit.__getattribute__(attribute_name))), icon=icon))
            elif attribute_name == 'affin':
                rows.append(IconRow(unit.name, icon=pygame.image.load(os.path.join(DIR_PATH, 'affinity_lightning.png'))))
            else:
                val = unit.__getattribute__(attribute_name)
                if isinstance(val, int):
                    rows.append(IconRow(unit.name, text=str(val), icon=icon, text_align=HAlignment.RIGHT))
                else:
                    rows.append(IconRow(unit.name, text=str(val), icon=icon, text_align=HAlignment.LEFT))

        return rows

    def scroll_right(self):
        if self.page < self.MAX_PAGES - 1:
            scroll_right_anim = component_scroll_anim(self.scroll, (min(self.scroll[0] + self.width, self.twidth - self.width), self.scroll[1]))
            self.queue_animation(animations=[scroll_right_anim])
            self.page += 1

    def scroll_left(self):
        if self.page > 0:
            scroll_left_anim = component_scroll_anim(self.scroll, (self.scroll[0] - self.width, self.scroll[1]))
            self.queue_animation(animations=[scroll_left_anim])
            self.page -= 1

    def scroll_down(self):
        for header_list in self.lists:
            header_list.scroll_down()

    def scroll_up(self):
        for header_list in self.lists:
            header_list.scroll_up()

class DemoUnitBox(UIComponent):
    def __init__(self, name: str = None, parent: UIComponent = None, on_page_scroll: Callable[[int], None] = None, data: List[DemoUnitInfo] = None):
        super().__init__(name=name, parent=parent)
        self.page_num = 1
        self.on_page_scroll = on_page_scroll
        self.data = data
        self.size = (232, 120)
        self.margin = (0, 0, 0, 3)
        self.props.v_alignment = VAlignment.BOTTOM
        self.props.h_alignment = HAlignment.CENTER

        # background hackery
        background_surf = engine.create_surface((232, 120), True)
        top_thickness = 20
        background_header = engine.subsurface(image_mods.make_translucent(create_base_surf(232, 28, 'menu_bg_white'), 0.1), (0, 0, 232, top_thickness))
        header_shadow: Surface = image_mods.make_translucent(engine.image_load(SPRITES['header_shadow'].full_path, convert_alpha=True), 0.7)
        background_header.blit(header_shadow, (0, 10))
        background_base = engine.subsurface(image_mods.make_translucent(create_base_surf(232, 120, 'menu_bg_base'), 0.1), (0, top_thickness, 232, 120 - top_thickness))
        background_surf.blit(background_header, (0, 0))
        background_surf.blit(background_base, (0, top_thickness))
        self.props.bg = background_surf

        # children layout
        self.props.layout = UILayoutType.LIST
        self.props.list_style = ListLayoutStyle.ROW

        name_rows = None
        self.header_row = None
        name_rows: List[IconRow] = self.generate_name_rows()
        self.header_row = IconRow(text='Name', icon=engine.create_surface((16, 16), True))

        self.left_unit_name_list = HeaderList(name='name list',
                                              parent=self,
                                              header_row=self.header_row,
                                              data_rows=name_rows,
                                              height=self.height-8,
                                              width='25%')
        self.left_unit_name_list.margin = (3, 0, 3, 0)
        self.right_unit_data_grid = DemoUnitGrid('data grid', self, data=self.data)

        # self.left_unit_name_list = DemoUnitList('name list', self, data)
        # self.right_unit_data_grid = DemoUnitGrid('data grid', self, data=self.data)

        self.add_child(self.left_unit_name_list)
        self.add_child(self.right_unit_data_grid)

    def generate_name_rows(self):
        rows = []
        for unit in self.data:
            iconbg = pygame.image.load(os.path.join(DIR_PATH, 'fort.png'))
            iconbg = pygame.transform.scale(iconbg, (20, 20))
            icon = UIComponent()
            icon.size = (16, 16)
            icon.overflow = (2, 0, 2, 0)
            icon.props.bg = iconbg
            row = IconRow(unit.name, text=unit.name, icon=icon)
            row.overflow = (16, 0, 16, 0)
            rows.append(row)
        return rows

    def scroll_down(self):
        self.left_unit_name_list.scroll_down()
        self.right_unit_data_grid.scroll_down()

    def scroll_up(self):
        self.left_unit_name_list.scroll_up()
        self.right_unit_data_grid.scroll_up()

    def scroll_right(self):
        self.right_unit_data_grid.scroll_right()

    def scroll_left(self):
        self.right_unit_data_grid.scroll_left()

class DemoUnitMenu():
    PAGE_TITLES = {
        1: 'Character',
        2: 'Fighting Skill',
        3: 'Equipment',
        4: 'Personal Data',
        5: 'Weapon Level',
        6: 'Support Chance'
    }

    SORT_ARROW_WIGGLE = [6, 7, 6, 5]

    def __init__(self):
        self.page_num = 1
        self.sort_by: str = 'Name'
        self.sort_direction = SORT_TYPE.DESCENDING
        self.sort_arrow_wiggle_index = 0

        self.data = DEMO_UNIT_DATA

        # initialize components
        self.unit_info_box: UIComponent = UIComponent(name="page type box")
        self.unit_info_box.props.bg = engine.image_load(SPRITES['world_map_location_box'].full_path, convert_alpha=True)
        self.unit_info_box.size = self.unit_info_box.props.bg.get_size()
        self.unit_info_box.props.v_alignment = VAlignment.TOP
        self.unit_info_box.props.h_alignment = HAlignment.LEFT
        self.unit_info_box.margin = (0, 0, 0, 0)

        self.page_title_component = PlainTextLine("page type text", self.unit_info_box, "")
        self.page_title_component.props.h_alignment = HAlignment.CENTER
        self.page_title_component.props.v_alignment = VAlignment.CENTER
        self.page_title_component.props.resize_mode = ResizeMode.AUTO
        self.page_title_component.set_font_name('chapter-grey')
        self.page_title_component.set_text("Character")
        self.unit_info_box.add_child(self.page_title_component)

        self.sort_box: UIComponent = UIComponent(name='sort box')
        self.sort_box.props.bg = image_mods.make_translucent(create_base_surf(72, 24, 'menu_bg_base'), 0.15)
        self.sort_box.size = self.sort_box.props.bg.get_size()
        self.sort_box.props.v_alignment = VAlignment.TOP
        self.sort_box.props.h_alignment = HAlignment.RIGHT
        self.sort_box.margin = (0, 4, 5, 0)

        self.sort_by_text = PlainTextComponent("sort by", self.sort_box, "")
        self.sort_by_text.props.h_alignment = HAlignment.LEFT
        self.sort_by_text.props.v_alignment = VAlignment.CENTER
        self.sort_by_text.props.resize_mode = ResizeMode.AUTO
        self.sort_by_text.set_font_name('text')
        self.sort_by_text.margin = (3, 0, 0, 0)
        self.sort_by_text.padding = (0, 0, 0, 2)
        self.sort_by_text.set_text("Sort: ")
        self.sort_box.add_child(self.sort_by_text)

        asc_sort_arrow = engine.image_load(SPRITES['sort_arrow'].full_path, convert_alpha=True)
        self.asc_sort_arrow = UIComponent.from_existing_surf(asc_sort_arrow)
        self.asc_sort_arrow.props.h_alignment = HAlignment.RIGHT
        self.asc_sort_arrow.margin = (0, 2, 5, 0)
        self.sort_box.add_child(self.asc_sort_arrow)
        self.asc_sort_arrow.disable()

        desc_sort_arrow = engine.transform_rotate(asc_sort_arrow, 180)
        self.desc_sort_arrow = UIComponent.from_existing_surf(desc_sort_arrow)
        self.desc_sort_arrow.props.h_alignment = HAlignment.RIGHT
        self.desc_sort_arrow.margin = (0, 2, 5, 0)
        self.sort_box.add_child(self.desc_sort_arrow)

        self.page_number_text = PlainTextLine('page_num', text='%d / %d' % (self.page_num, NUM_PAGES))
        self.page_number_text.set_font_name('text-blue')
        self.page_number_text.props.h_alignment = HAlignment.RIGHT
        bottom_of_sort_box = self.sort_box.margin[2] + self.sort_box.size[1]
        self.page_number_text.margin = (0, 5, bottom_of_sort_box - 5, 0)

        self.unit_scroll_box = DemoUnitBox(name='unit box',
                                           on_page_scroll=self._on_unit_page_scroll,
                                           data=self.data)

        self.base_component = UIComponent.create_base_component(WINWIDTH, WINHEIGHT)
        self.base_component.name = "base"
        self.base_component.add_child(self.unit_info_box)
        self.base_component.add_child(self.sort_box)
        self.base_component.add_child(self.unit_scroll_box)
        self.base_component.add_child(self.page_number_text)
        self.base_component.set_chronometer(current_milli_time)

    def _on_unit_page_scroll(self, page):
        self.page_num = page

    def _update_title_box(self):
        page_title = self.PAGE_TITLES[self.page_num]
        if self.page_title_component.text is not page_title:
            self.page_title_component.set_text(page_title)

    def _update_sort_box(self):
        sort_text = 'Sort: ' + self.sort_by
        if self.sort_by_text.text != sort_text:
            self.sort_by_text.set_text(sort_text)
        # orient sort arrow
        if self.sort_direction == SORT_TYPE.ASCENDING:
            self.desc_sort_arrow.disable()
            self.asc_sort_arrow.enable()
            curr_sort_arrow = self.asc_sort_arrow
        else:
            self.asc_sort_arrow.disable()
            self.desc_sort_arrow.enable()
            curr_sort_arrow = self.desc_sort_arrow
        # perturb it
        curr_sort_arrow.margin = (0, 2, self.SORT_ARROW_WIGGLE[(self.sort_arrow_wiggle_index // 8) % len(self.SORT_ARROW_WIGGLE)], 0)
        self.sort_arrow_wiggle_index += 1

    def _update_page_num(self):
        page_num_text = '%d / %d' % (self.page_num, NUM_PAGES)
        if self.page_number_text.text != page_num_text:
            self.page_number_text.set_text(page_num_text)

    def draw(self, surf: Surface) -> Surface:
        self._update_sort_box()
        self._update_title_box()
        ui_surf = self.base_component.to_surf()
        surf.blit(ui_surf, (0, 0))
        return surf