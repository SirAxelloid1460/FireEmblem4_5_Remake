from __future__ import annotations
from app.engine.overworld.overworld_manager import OverworldManager
from app.utilities.typing import Point
from app.utilities.utils import tmult, tuple_add, tuple_sub
from app.engine.sound import get_sound_thread
import app.engine.graphics.ui_framework as uif
from app.engine import engine
from app.engine.objects.overworld import OverworldObject
from app.engine.overworld.overworld_cursor import OverworldCursor

from typing import List, TYPE_CHECKING, Tuple
from app.constants import COLORKEY, WINHEIGHT
from app.engine.game_counters import ANIMATION_COUNTERS

if TYPE_CHECKING:
    from engine import Surface

from app.engine.sprites import SPRITES
from app.engine import config as cf

class ShimmeringMinimapMarker():
    def __init__(self) -> None:
        self._sprite: Surface = SPRITES.get('player_minimap_marker')
        self.num_sprites_wide = 16
        self.num_sprites_tall = 1

    @property
    def sprite_width(self):
        return self._sprite.get_width() / self.num_sprites_wide

    @property
    def sprite_height(self):
        return self._sprite.get_height() / self.num_sprites_tall

    @property
    def sprite(self):
        left = (ANIMATION_COUNTERS.fps6_360counter.count % 16) * self.sprite_width
        surf = engine.subsurface(self._sprite, (left, 0, self.sprite_width, self.sprite_height))
        return surf

class OverworldMinimap(uif.UIComponent):
    def __init__(self, name: str, parent: uif.UIComponent = None, overworld: OverworldManager = None, cursor: OverworldCursor = None):
        super().__init__(name=name, parent=parent)

        self.overworld = overworld
        self.cursor = cursor

        overworld_minimap_sprite: Surface = SPRITES.get('MagvelMinimap')
        engine.set_colorkey(overworld_minimap_sprite, COLORKEY)
        self.size = overworld_minimap_sprite.get_size()
        self.set_background(overworld_minimap_sprite)

        self.player_minimap_marker: ShimmeringMinimapMarker = ShimmeringMinimapMarker()
        self.overworld_cursor_marker: Surface = SPRITES.get('cursor_minimap_marker')

        # this is the actual part of the sprite that's the map
        self.TRUE_MAP_SIZE: Tuple[int, int] = (64, 43)
        # this is the top left of the drawable map
        self.TRUE_MAP_TOPLEFT: Tuple[int, int] = (0, 13)
        # Obviously, we don't want to draw off the map, so we limit
        self.MAP_SPRITABLE_TOPLEFTS: Tuple[int, int] = tuple_sub(self.TRUE_MAP_SIZE, self.player_minimap_marker.sprite.get_size())
        self._init_minimap_animations()

    def _init_minimap_animations(self):
        translate_down = uif.translate_anim((0, 0), (0, WINHEIGHT))
        translate_up = uif.translate_anim((0, WINHEIGHT), (0, 0))

        def change_align(c: uif.UIComponent, *args):
            if c.props.h_alignment == uif.HAlignment.LEFT:
                c.props.h_alignment = uif.HAlignment.RIGHT
            else:
                c.props.h_alignment = uif.HAlignment.LEFT
        change_alignment = uif.UIAnimation(before_anim=change_align)

        self.save_animation(translate_down, 'translate_down')
        self.save_animation(translate_up, 'translate_up')
        self.save_animation(change_alignment, 'change_alignment')

        self.save_animation(translate_down, '!exit')
        self.save_animation(translate_up, '!enter')

    def convert_overworld_pos_to_minimap_pos(self, pos: Point):
        if self.overworld:
            map_size = (self.overworld.tilemap.width, self.overworld.tilemap.height)
            pos_frac = (pos[0] / map_size[0], pos[1] / map_size[1])
            pos_offset = (pos_frac[0] * self.MAP_SPRITABLE_TOPLEFTS[0],
                          pos_frac[1] * self.MAP_SPRITABLE_TOPLEFTS[1])
            true_minimap_pos = tuple_add(pos_offset, self.TRUE_MAP_TOPLEFT)
            return (int(true_minimap_pos[0]), int(true_minimap_pos[1]))
        return (0, 0)

    def get_entity_positions(self) -> List[Tuple[bool, Point]]:
        entity_positions = []
        if self.overworld:
            for entity in self.overworld.entities.values():
                if entity.on_node and entity.display_position:
                    if entity.team == 'player':
                        entity_positions.append((True, self.convert_overworld_pos_to_minimap_pos(entity.display_position)))
                    else:
                        entity_positions.append((False, self.convert_overworld_pos_to_minimap_pos(entity.display_position)))
        return entity_positions

    def get_cursor_position(self) -> Point:
        if self.cursor and self.overworld:
            return self.convert_overworld_pos_to_minimap_pos(self.cursor.position)
        return (0, 0)

    def to_surf(self, _=False) -> Surface:
        if not self.enabled:
            return engine.create_surface(self.size, True)
        base_surf = self._create_bg_surf().copy()

        if self.overworld:
            # draw the entity markers
            for entity_type_and_position in self.get_entity_positions():
                if entity_type_and_position[0]: # player?
                    base_surf.blit(self.player_minimap_marker.sprite, entity_type_and_position[1])
                else:  # or enemy?
                    base_surf.blit(self.player_minimap_marker.sprite, entity_type_and_position[1])

            # draw the cursor
            if self.cursor:
                base_surf.blit(self.overworld_cursor_marker, self.get_cursor_position())

        return base_surf