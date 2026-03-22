import os
import time
from enum import Enum

import pygame
import pygame.draw
import pygame.event

from .demo_code.demo_cursor import Cursor, Scene
from .demo_code.demo_ui import DemoUI
from .demo_code.demo_narration import NarrationUI
from .demo_code.demo_scroll import ScrollUI
from .demo_code.demo_unit_menu import DemoUnitMenu
from .demo_code.demo_table import DemoTable
from .ui_framework import *
from .ui_framework_animation import *
from .ui_framework_layout import *
from .ui_framework_styling import *
from .premade_components import *
from .premade_animations import *

TILEWIDTH, TILEHEIGHT = 16, 16
TILEX, TILEY = 15, 10
WINWIDTH, WINHEIGHT = TILEX * TILEWIDTH, TILEY * TILEHEIGHT
DIR_PATH = os.path.dirname(os.path.realpath(__file__))

def current_milli_time():
    return round(time.time() * 1000)

class Mode(Enum):
    OverworldUIMode = 0
    NarrationMode = 1

def LoadDialogLogDemo(screen, tmp_surf, clock):
    ui_overlay = ScrollUI()
    while True:
        tmp_surf.fill((255, 255, 255, 255))
        events = pygame.event.get()
        for e in events:
            if e.type == pygame.KEYDOWN:
                if e.key == pygame.K_ESCAPE:
                    return
                elif e.key == pygame.K_SPACE:
                    ui_overlay.scroll_all()
                if e.key == pygame.K_DOWN:
                    ui_overlay.scroll_down()
                elif e.key == pygame.K_UP:
                    ui_overlay.scroll_up()
        ui_overlay.draw(tmp_surf)
        frame = pygame.transform.scale(tmp_surf, (WINWIDTH * 2, WINHEIGHT * 2))
        screen.blit(frame, (0, 0))
        pygame.display.flip()
        clock.tick(60)

def LoadNarrationDialogDemo(screen, tmp_surf, clock):
    ui_overlay = NarrationUI()
    narration_open = False
    while True:
        tmp_surf.fill((255, 255, 255, 255))
        events = pygame.event.get()
        for e in events:
            if e.type == pygame.KEYDOWN:
                if e.key == pygame.K_ESCAPE:
                    return
                elif e.key == pygame.K_SPACE:
                    if not narration_open:
                        narration_open = True
                        ui_overlay.narration.enter()
                    else:
                        ui_overlay.narration.start_scrolling()
                elif e.key == pygame.K_BACKSPACE:
                    if narration_open:
                        ui_overlay.narration.exit()
                        narration_open = False
                elif e.key == pygame.K_TAB:
                    if narration_open:
                        ui_overlay.narration.write_a_line()
                if e.key == pygame.K_DOWN:
                    ui_overlay.scroll_down()
                elif e.key == pygame.K_UP:
                    ui_overlay.scroll_up()
        ui_overlay.draw(tmp_surf)
        frame = pygame.transform.scale(tmp_surf, (WINWIDTH * 2, WINHEIGHT * 2))
        screen.blit(frame, (0, 0))
        pygame.display.flip()
        clock.tick(60)

def LoadWorldMapDemo(screen, tmp_surf, clock):
    cursor = Cursor()
    world_map = pygame.image.load(os.path.join(DIR_PATH, 'demo_code', 'magvel_demo.png'))
    nodes = Scene()
    ui_overlay = DemoUI(cursor)
    cursor.scene = nodes
    while True:
        tmp_surf.fill((255, 255, 255, 255))
        events = pygame.event.get()
        for e in events:
            if e.type == pygame.KEYDOWN:
                if e.key == pygame.K_ESCAPE:
                    return
            cursor.take_input(events)
        tmp_surf.blit(world_map, (0, 0))
        nodes.draw(tmp_surf)
        cursor.draw(tmp_surf)
        ui_overlay.draw(tmp_surf)
        frame = pygame.transform.scale(tmp_surf, (WINWIDTH * 2, WINHEIGHT * 2))
        screen.blit(frame, (0, 0))
        pygame.display.flip()
        clock.tick(60)

def LoadUnitMenuDemo(screen, tmp_surf, clock):
    ui_overlay = DemoUnitMenu()
    world_map = pygame.image.load(os.path.join(DIR_PATH, 'demo_code', 'magvel_demo.png'))
    font = pygame.font.Font(None, 30)
    while True:
        tmp_surf.fill((255, 255, 255, 255))
        events = pygame.event.get()
        for e in events:
            if e.type == pygame.KEYDOWN:
                if e.key == pygame.K_ESCAPE:
                    return
                elif e.key == pygame.K_DOWN:
                    ui_overlay.unit_scroll_box.scroll_down()
                elif e.key == pygame.K_UP:
                    ui_overlay.unit_scroll_box.scroll_up()
                elif e.key == pygame.K_LEFT:
                    ui_overlay.unit_scroll_box.scroll_left()
                elif e.key == pygame.K_RIGHT:
                    ui_overlay.unit_scroll_box.scroll_right()
        tmp_surf.blit(world_map, (0, 0))
        ui_overlay.draw(tmp_surf)
        frame = pygame.transform.scale(tmp_surf, (WINWIDTH * 2, WINHEIGHT * 2))
        screen.blit(frame, (0, 0))
        fps = font.render(str(int(clock.get_fps())), True, pygame.Color('white'))
        screen.blit(fps, (50, 50))
        pygame.display.flip()
        clock.tick(60)

def LoadTableDemo(screen, tmp_surf, clock):
    ui_overlay = DemoTable()
    world_map = pygame.image.load(os.path.join(DIR_PATH, 'demo_code', 'magvel_demo.png'))
    font = pygame.font.Font(None, 30)
    while True:
        tmp_surf.fill((255, 255, 255, 255))
        events = pygame.event.get()
        for e in events:
            if e.type == pygame.KEYDOWN:
                if e.key == pygame.K_ESCAPE:
                    return
                elif e.key == pygame.K_DOWN:
                    ui_overlay.move_down()
                elif e.key == pygame.K_UP:
                    ui_overlay.move_up()
                elif e.key == pygame.K_LEFT:
                    ui_overlay.move_left()
                elif e.key == pygame.K_RIGHT:
                    ui_overlay.move_right()

        tmp_surf.blit(world_map, (0, 0))
        ui_overlay.draw(tmp_surf)
        frame = pygame.transform.scale(tmp_surf, (WINWIDTH * 2, WINHEIGHT * 2))
        screen.blit(frame, (0, 0))
        pygame.display.flip()

def main():
    pygame.init()
    screen = pygame.display.set_mode((WINWIDTH * 2, WINHEIGHT * 2))
    tmp_surf = pygame.Surface((WINWIDTH, WINHEIGHT))
    clock = pygame.time.Clock()

    # choose which demo to view
    # LoadWorldMapDemo(screen, tmp_surf, clock)
    # LoadNarrationDialogDemo(screen, tmp_surf, clock)
    # LoadDialogLogDemo(screen, tmp_surf, clock)
    # LoadUnitMenuDemo(screen, tmp_surf, clock)
    LoadTableDemo(screen, tmp_surf, clock)
    return

def profile():
    # ignore this
    import cProfile
    pr = cProfile.Profile()
    pygame.init()
    screen = pygame.display.set_mode((WINWIDTH * 2, WINHEIGHT * 2))
    tmp_surf = pygame.Surface((WINWIDTH, WINHEIGHT))
    ui_overlay = DemoUnitMenu()
    pr.enable()
    ui_overlay.unit_scroll_box.scroll_right()
    for i in range(60):
        ui_overlay.draw(tmp_surf)
    pr.disable()
    pr.print_stats(sort='time')


"""Usage: python -m app.engine.graphics.ui_framework.demo"""
main()
# profile()