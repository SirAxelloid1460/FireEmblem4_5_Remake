from typing import Tuple
from app.constants import WINHEIGHT, WINWIDTH
from app.engine.graphics.ui_framework.ui_framework_layout import convert_align, HAlignment, VAlignment

from app.utilities.enums import Alignments

def calc_align(box_size: Tuple[int, int], alignment: Alignments,
               disp_width: int = WINWIDTH, disp_height: int = WINHEIGHT,
               margins_lr_tb: Tuple[int, int, int, int] = (4, 4, 2, 2)) -> Tuple[int, int]:
    """takes an alignment and a window (as a size)s and aligns a box within that window

    Args:
        box_size (Tuple[int, int]): size of box to position
        alignment (Alignments): alignment to position to
        disp_width (int, optional): width of display to align to. Defaults to WINWIDTH.
        disp_height (int, optional): height of display to align to. Defaults to WINHEIGHT.
        margins_lr_tb (Tuple[int, int, int, int], optional): pixel margins to leave along the edges
            goes (left, right, top, bottom). Defaults to (4, 4, 2, 2).

    Returns:
        Tuple[int, int]: pixel coordinate of box's top left that would align it correctly
    """
    width, height = box_size
    ml, mr, mt, mb = margins_lr_tb
    halign, valign = convert_align(alignment)
    if halign is HAlignment.LEFT:
        left = ml
    elif halign is HAlignment.CENTER:
        left = disp_width // 2 - width // 2
    else: # RIGHT
        left = disp_width - (mr + width)

    if valign is VAlignment.TOP:
        top = mt
    elif valign is VAlignment.CENTER:
        top = disp_height // 2 - height // 2
    else: # BOTTOMT
        top = disp_height - (mb + height)
    return left, top