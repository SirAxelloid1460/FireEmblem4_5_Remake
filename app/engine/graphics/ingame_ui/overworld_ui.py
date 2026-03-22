from __future__ import annotations
from app.engine.graphics.ingame_ui.overworld_minimap import OverworldMinimap
from app.engine.overworld.overworld_cursor import OverworldCursor
from app.engine.objects.overworld import OverworldNodeObject, OverworldEntityObject, OverworldObject

import app.engine.graphics.ui_framework as uif

from typing import Tuple
from app.engine.engine import Surface
from app.constants import WINWIDTH, WINHEIGHT, TILEX, TILEY

from app.engine.sprites import SPRITES
from app.engine.game_state import game
from app.engine import base_surf
from app.engine import engine

class OverworldTravelUI():
    legal_states = ('overworld',)

    def __init__(self, overworld: OverworldObject = None, cursor: OverworldCursor = None):
        self.overworld = overworld
        self.base_component = uif.UIComponent.create_base_component()
        # initialize components
        self.location_title: uif.UIComponent = uif.UIComponent(name="location title")
        self.location_title.props.bg = SPRITES.get('world_map_location_box')
        self.location_title.size = self.location_title.props.bg.get_size()
        self.location_title.props.v_alignment = uif.VAlignment.TOP
        self.location_title.margin = (5, 5, 5, 5)
        self._init_location_title_animations()
        self.location_title.disable()

        self.location_title_text = uif.PlainTextLine("location title text", self.location_title, "")
        self.location_title_text.props.h_alignment = uif.HAlignment.CENTER
        self.location_title_text.props.v_alignment = uif.VAlignment.CENTER
        self.location_title_text.props.resize_mode = uif.ResizeMode.AUTO
        self.location_title.add_child(self.location_title_text)

        if SPRITES.get('MagvelMinimap'):
            self.minimap: OverworldMinimap = OverworldMinimap('minimap', None, overworld, cursor)
            self.minimap.props.v_alignment = uif.VAlignment.BOTTOM
            self.minimap.margin = (5, 5, 5, 5)
            self.minimap.disable()
            self.base_component.add_child(self.minimap)
        else:
            self.minimap = None

        self.base_component.add_child(self.location_title)
    
    def _init_location_title_animations(self):
        exit_left = uif.translate_anim((0, 0), (-WINWIDTH, 0), disable_after=True)
        exit_right = uif.translate_anim((0, 0), (WINWIDTH, 0), disable_after=True)
        enter_left = uif.translate_anim((-WINWIDTH, 0), (0, 0))
        enter_right = uif.translate_anim((WINWIDTH, 0), (0, 0))

        def which_transition(c: uif.UIComponent, *args) -> str:
            if c.props.h_alignment == uif.HAlignment.LEFT:
                return "left"
            else:
                return "right"
        transition_out_anim = uif.hybridize_animation({"left": exit_left, "right": exit_right}, which_transition)
        transition_in_anim = uif.hybridize_animation({"left": enter_left, "right": enter_right}, which_transition)

        self.location_title.save_animation(transition_out_anim, '!exit')
        self.location_title.save_animation(transition_in_anim, '!enter')

    def _update_location_title_component(self):
        # determine name of location hovered
        pair: Tuple[OverworldEntityObject, OverworldNodeObject] = game.cursor.get_hover()
        (_, node) = pair
        active = False
        if node:
            text = node.prefab.name
            self.location_title_text.set_text(text)
            active = True

        # logic for determining which side of the screen the title hangs out on
        # Try to keep them on the same side
        switch_sides = False
        if not self.location_title.enabled:
            if game.cursor.position[0] < TILEX // 2 + game.camera.get_x():
                # if both cursor is left but box is right, switch sides
                if self.location_title.props.h_alignment == uif.HAlignment.RIGHT:
                    self.location_title.props.h_alignment = uif.HAlignment.LEFT
            else:
                if self.location_title.props.h_alignment == uif.HAlignment.LEFT:
                    self.location_title.props.h_alignment = uif.HAlignment.RIGHT
        else:
            if game.cursor.position[0] < TILEX // 2 + game.camera.get_x():
                # if both cursor is left but box is right, switch sides
                if self.location_title.props.h_alignment == uif.HAlignment.RIGHT:
                    switch_sides = True
            else:
                if self.location_title.props.h_alignment == uif.HAlignment.LEFT:
                    switch_sides = True
        # animate out/in, if it's not already animating
        if len(self.location_title.queued_animations) == 0:
            if self.location_title.enabled and not active:
                # was active, now not, animate out
                self.location_title.exit()
            elif self.location_title.enabled and switch_sides:
                self.location_title.exit()
            elif not self.location_title.enabled and active:
                # was inactive, now active, animate in
                self.location_title.enter()

    def _update_minimap_component(self):
        if self.minimap:
            if not self.minimap.enabled:
                self.minimap.enter()
            if (game.cursor.position[0] > TILEX // 2 + game.camera.get_x() - 1 and
                    game.cursor.position[1] > TILEY // 2 + game.camera.get_y() - 1):
                # if cursor is in the bottom right
                if self.minimap.props.h_alignment == uif.HAlignment.RIGHT:
                    # if we're also in the right - get out of dodge
                    self.minimap.queue_animation(names=['translate_down', 'change_alignment', 'translate_up'])
            elif (game.cursor.position[0] < TILEX // 2 + game.camera.get_x() and
                    game.cursor.position[1] > TILEY // 2 + game.camera.get_y() - 1):
                # cursor is in the bottom left
                if self.minimap.props.h_alignment != uif.HAlignment.RIGHT:
                    # then we leave the left
                    self.minimap.queue_animation(names=['translate_down', 'change_alignment', 'translate_up'])

    def draw(self, surf: Surface) -> Surface:
        if not game.state.current() in self.legal_states:
            if self.minimap:
                self.minimap.disable()
            self.location_title.disable()
            return surf
        self._update_location_title_component()
        self._update_minimap_component()
        self.base_component._should_redraw = True
        ui_surf = self.base_component.to_surf()
        surf.blit(ui_surf, (0, 0))
        return surf
