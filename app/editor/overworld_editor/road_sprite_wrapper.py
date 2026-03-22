from __future__ import annotations

from app.utilities.typing import Point
from PyQt5.QtGui import QImage, QPainter, QPixmap, QTransform
from app.engine.overworld.overworld_road_sprite_wrapper import OverworldRoadSpriteWrapper

class RoadSpriteWrapper(OverworldRoadSpriteWrapper):
    def get_image(self, road_sprite):
        if not road_sprite.pixmap:
            road_sprite.pixmap = QPixmap(road_sprite.full_path)

    def get_subimage(self, road_sprite, x):
        return road_sprite.pixmap.toImage().copy(x, 0, 8, 8)

    def rotate(self, sprite: QImage, angle: float) -> QImage:
        return sprite.transformed(QTransform().rotate(angle))

    def draw(self, pos: Point, sprite: QImage, draw_engine: QPainter):
        painter: QPainter = draw_engine
        sprite: QImage = sprite
        painter.drawImage(*pos, sprite)
