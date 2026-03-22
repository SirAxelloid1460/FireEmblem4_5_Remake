from __future__ import annotations
from app.utilities.enums import Alignments
from app.utilities.typing import Point
from functools import lru_cache
import logging

from typing import TYPE_CHECKING, Callable, Dict, List, Tuple, Union

if TYPE_CHECKING:
    from .ui_framework import UIComponent

from enum import Enum

def convert_align(align: Alignments) -> Tuple[HAlignment, VAlignment]:
    if align == Alignments.TOP_LEFT:
        return (HAlignment.LEFT, VAlignment.TOP)
    if align == Alignments.TOP:
        return (HAlignment.CENTER, VAlignment.TOP)
    if align == Alignments.TOP_RIGHT:
        return (HAlignment.RIGHT, VAlignment.TOP)
    if align == Alignments.LEFT:
        return (HAlignment.LEFT, VAlignment.CENTER)
    if align == Alignments.CENTER:
        return (HAlignment.CENTER, VAlignment.CENTER)
    if align == Alignments.RIGHT:
        return (HAlignment.RIGHT, VAlignment.CENTER)
    if align == Alignments.BOT_LEFT:
        return (HAlignment.LEFT, VAlignment.BOTTOM)
    if align == Alignments.BOT:
        return (HAlignment.CENTER, VAlignment.BOTTOM)
    if align == Alignments.BOT_RIGHT:
        return (HAlignment.RIGHT, VAlignment.BOTTOM)

class HAlignment(Enum):
    LEFT = 'left'
    CENTER = 'center'
    RIGHT = 'right'
    NONE = 'none'

class VAlignment(Enum):
    TOP = 'top'
    CENTER = 'center'
    BOTTOM = 'bottom'
    NONE = 'none'

class UILayoutType(Enum):
    """Enum for distinguishing the types of layouts for a component.
    The layout types are as follows:

        - NONE: Simplest layout. Draws all children naively, i.e. according to their alignment and margins.
                This WILL draw children on top of one another if they occupy the same space.
                This layout is best used for very simple UIs that you exert direct control over,
                such as the game UI that includes unit info and terrain info (whose alignment we control).

        - LIST: Will draw children in order, and align them accordingly in a list. Uses ComponentProperties.list_style to
                determine whether to draw children top to bottom, left to right, or vice versa. Make sure you proportion
                the children correctly, otherwise they will be cut off or drawn off screen.

        - GRID: The 2D version of the above. Uses ComponentProperties.grid_dimensions to determine the (rows, columns) of the grid.
                Will draw children in order. If you want children to take up more than one slot, use the child's
                ComponentProperties.grid_occupancy property to determine how many (row_space, column_space) it takes up.
                As with the list, ensure that you proportion the children correctly.

        - MANUAL_GRID: If you wanted more fine control of what goes where, the manual grid will not automatically draw children in order;
                rather, it will draw them according to the child's ComponentProperties.grid_coordinates property. This means that
                if you do not set the ComponentProperties.grid_coordinates property for some child, it will NOT DRAW PROPERLY (i.e.
                overwrite the first square and muck things up)
    """
    NONE = 0
    LIST = 1
    GRID = 2
    MANUAL_GRID = 3

class ListLayoutStyle(Enum):
    ROW = 0
    COLUMN = 1
    ROW_REVERSE = 2 # right to left
    COLUMN_REVERSE = 3 # bottom to top

class UILayoutHandler():
    """The Layout Handler contains most of the code for handling the different
    UILayoutTypes: NONE, LIST, GRID, and MANUAL_GRID.

    This is mostly organizational, reducing the amount of case handling that I
    would otherwise need to write in ui_framework.py.
    """
    def __init__(self, parent_component: UIComponent):
        self.parent_component: UIComponent = parent_component

    def generate_child_positions(self, no_cull = False) -> Dict[int, Point]:
        """Generates a list positions, order corresponding to the list of children provided.

        Returns:
            Dict[int, Point]: Dict mapping child index to child positions.
        """
        layout = self.parent_component.props.layout
        if layout == UILayoutType.LIST:
            return self._list_layout(no_cull)
        elif layout == UILayoutType.GRID:
            pass
        elif layout == UILayoutType.MANUAL_GRID:
            pass
        else: # assume UILayoutType.NONE
            return self._naive_layout(no_cull)

    def _naive_position_children_cached(self, children: Tuple[UIComponent, ...], psize: Tuple[int, int], ppadding: Tuple[int, int, int, int], no_cull=False) -> Dict[int, Point]:
        width, height = psize
        padding = ppadding
        positions = {}
        for idx, child in enumerate(children):
            cwidth, cheight = child.size
            v_alignment = child.props.v_alignment
            h_alignment = child.props.h_alignment
            offset = child.offset

            top = 0
            left = 0
            # handle horizontal and vertical alignments
            if h_alignment is HAlignment.LEFT:
                left = child.margin[0] + padding[0]
            elif h_alignment is HAlignment.CENTER:
                left = width / 2 - cwidth / 2
            elif h_alignment is HAlignment.RIGHT:
                left = width - (child.margin[1] + cwidth + padding[1])

            if v_alignment is VAlignment.TOP:
                top = child.margin[2] + padding[2]
            elif v_alignment is VAlignment.CENTER:
                top = height / 2 - cheight / 2
            elif v_alignment is VAlignment.BOTTOM:
                top = height - (child.margin[3] + cheight + padding[3])
            final_pos = (left + offset[0], top + offset[1])
            if no_cull:
                positions[idx] = final_pos
            elif not self.should_cull(final_pos, child.size, child.overflow, psize, self.parent_component.scroll, self.parent_component.overflow):
                positions[idx] = final_pos
        return positions

    def _naive_layout(self, no_cull=False) -> Dict[int, Point]:
        """Layout Strategy for the naive UILayoutType.NONE layout.

        Returns:
            Dict[int, Point]: positions of children
        """
        psize = self.parent_component.size
        ppadding = self.parent_component.padding
        return self._naive_position_children_cached(tuple(self.parent_component.children), psize, ppadding, no_cull)

    def _list_layout_position_children_cached(self, children: Tuple[UIComponent, ...], psize: Tuple[int, int], ppadding: Tuple[int, int, int, int],
                                    incrementing_index: int, no_cull=False) -> Dict[int, Point]:
        positions = {}

        width, height = psize
        padding = ppadding
        # we build in the padding
        incrementing_position = [self.parent_component.padding[0], self.parent_component.padding[2]]

        for idx, child in enumerate(children):
            csize = (child.width, child.height)
            props = child.props

            position = list(incrementing_position)

            # position the child on the off-axis via their alignment:
            if incrementing_index == 0:
                # row list, so align the children as they wish vertically
                if props.v_alignment is VAlignment.TOP:
                    position[1] = child.margin[2] + padding[2]
                elif props.v_alignment is VAlignment.CENTER:
                    position[1] = height / 2 - csize[1] / 2
                elif props.v_alignment is VAlignment.BOTTOM:
                    position[1] = height - (child.margin[3] + csize[1] + padding[3])
                # increment by left margin
                position[incrementing_index] += child.margin[0]
            else:
                # column list, align the children as they wish horizontally
                if props.h_alignment is HAlignment.LEFT:
                    position[0] = child.margin[0] + padding[0]
                elif props.h_alignment is HAlignment.CENTER:
                    position[0] = width / 2 - csize[0] / 2
                elif props.h_alignment is HAlignment.RIGHT:
                    position[0] = width - (child.margin[1] + csize[0] + padding[1])
                # increment by top margin
                position[incrementing_index] += child.margin[2]
            if no_cull: # add anyway
                positions[idx] = tuple(position)
            elif not self.should_cull(tuple(position), child.size, child.overflow, psize, self.parent_component.scroll, self.parent_component.overflow):
                positions[idx] = tuple(position)
            cmargin_sum = (child.margin[0] + child.margin[1], child.margin[2] + child.margin[3])
            csize = (child.width, child.height)
            # increment the position by the child's relevant properties for the next child
            incrementing_position[incrementing_index] = (incrementing_position[incrementing_index] +
                                                        csize[incrementing_index] +
                                                        cmargin_sum[incrementing_index])
        return positions

    def _list_layout(self, no_cull=False) -> Dict[int, Point]:
        """Layout strategy for the UILayoutType.LIST layout.

        Returns:
            Dict[int, Point]: positions of children
        """
        positions = []
        psize = self.parent_component.size
        padding = self.parent_component.padding
        ordered_children = self.parent_component.children[:]

        # handle different types of lists
        if self.parent_component.props.list_style == ListLayoutStyle.ROW:
            # we increment the x-coordinate
            incrementing_index = 0
        elif self.parent_component.props.list_style == ListLayoutStyle.COLUMN:
            # we increment the y-coordinate
            incrementing_index = 1
        elif self.parent_component.props.list_style == ListLayoutStyle.ROW_REVERSE:
            # we reverse the list so we calculate the last child first (thus simulating a "right to left" list)
            # we increment the x-coordinate
            incrementing_index = 0
            ordered_children = ordered_children[::-1]
        elif self.parent_component.props.list_style == ListLayoutStyle.COLUMN_REVERSE:
            # we reverse the list so we calculate the last child first (thus simulating a "bottom-to-top" list)
            # we increment the y-coordinate
            incrementing_index = 1
            ordered_children = ordered_children[::-1]
        else:
            logging.error('Unrecognized or unset ListLayoutStyle in component %s' % self.parent_component.name)

        positions = self._list_layout_position_children_cached(tuple(ordered_children), psize, padding, incrementing_index, no_cull)

        if (self.parent_component.props.list_style == ListLayoutStyle.ROW_REVERSE
                or self.parent_component.props.list_style == ListLayoutStyle.COLUMN_REVERSE):
            # reverse the positions list so the ordering is accurate
            new_positions = {}
            for idx, position in positions.items():
                new_positions[len(self.parent_component.children) - idx - 1] = position
            positions = new_positions
        return positions

    @lru_cache()
    def should_cull(self, cpos: Tuple[int, int], csize: Tuple[int, int], coverflow: Tuple[int, int, int, int], psize: Tuple[int, int], pscroll: Tuple[int, int], poverflow: Tuple[int, int, int, int]) -> bool:
        cpos = (cpos[0] - pscroll[0], cpos[1] - pscroll[1])
        if cpos[0] + csize[0] + coverflow[1] < -poverflow[0]: # too far left
            return True
        if cpos[0] - coverflow[0] > psize[0] + poverflow[1]: # too far right
            return True
        if cpos[1] + csize[1]  + coverflow[3] < -poverflow[2]: # too far up
            return True
        if cpos[1] - coverflow[2] > psize[1] + poverflow[3]: # too far down
            return True
        return False