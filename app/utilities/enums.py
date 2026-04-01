from __future__ import annotations
from enum import Enum

class Alignments(Enum):
    TOP_LEFT = "top_left"
    TOP = "top"
    TOP_RIGHT = "top_right"
    LEFT = "left"
    CENTER = "center"
    RIGHT = "right"
    BOT_LEFT = "bottom_left"
    BOT = "bottom"
    BOT_RIGHT = "bottom_right"

class Orientation(Enum):
    HORIZONTAL = 'horizontal'
    VERTICAL = 'vertical'

class Strike(Enum):
    HIT = 'hit'
    MISS = 'miss'
    CRIT = 'crit'
