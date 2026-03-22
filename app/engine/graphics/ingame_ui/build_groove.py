from typing import Tuple

from app.sprites import SPRITES
from app.engine import engine

def build_groove(surf, topleft: Tuple[int, int], width: int, fill: float):
    """
    Draws a bar of width `width` onto surf. Bar can be filled some percentage of its width

    Args:
        surf: The surface to draw the bar on
        topleft: The topleft position on the surface to draw the bar to
        width: How long in pixels to make the bar
        fill: A fraction from 0 to 1 indicating how much to fill the bar up
    """
    bg = SPRITES.get('groove_back')
    start = engine.subsurface(bg, (0, 0, 2, 5))
    mid = engine.subsurface(bg, (2, 0, 1, 5))
    end = engine.subsurface(bg, (3, 0, 2, 5))
    fg = SPRITES.get('groove_fill')

    # Build back groove
    surf.blit(start, topleft)
    for idx in range(width - 2):
        mid_pos = (topleft[0] + 2 + idx, topleft[1])
        surf.blit(mid, mid_pos)
    surf.blit(end, (topleft[0] + width, topleft[1]))

    # Build fill groove
    number_needed = int(fill * (width - 1))  # Width of groove minus section for start and end
    for groove in range(number_needed):
        surf.blit(fg, (topleft[0] + 1 + groove, topleft[1] + 1))
