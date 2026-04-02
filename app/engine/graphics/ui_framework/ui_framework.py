from __future__ import annotations

import logging
from enum import Enum
from typing import Any, Callable, Dict, List, Optional, Tuple, Union

from app.constants import WINHEIGHT, WINWIDTH
from app.engine import engine, image_mods
from app.utilities.typing import Color4
from app.utilities.utils import tclamp, tmult, tuple_add, tuple_sub

from .premade_animations.animation_templates import toggle_anim
from .ui_framework_animation import UIAnimation, animated
from .ui_framework_layout import (HAlignment, ListLayoutStyle, UILayoutHandler,
                                  UILayoutType, VAlignment)
from .ui_framework_styling import UIMetric

CACHED_ATTRIBUTES = ['size', 'height', 'width', 'margin', 'padding', 'offset', 'scroll', 'tsize', 'twidth', 'theight', 'max_width', 'max_height', 'overflow']
UNSETTABLE_ATTRIBUTES = ['tsize', 'twidth', 'theight', 'isize', 'iwidth', 'iheight']
class ResizeMode(Enum):
    MANUAL = 0
    AUTO = 1

class ComponentProperties():
    def __init__(self, parent: UIComponent):
        # don't worry about these
        self._done_init = False
        self._parent_pointer: UIComponent = parent

        # used by the parent to position
        self.h_alignment: HAlignment = HAlignment.LEFT  # Horizontal Alignment of Component
        self.v_alignment: VAlignment = VAlignment.TOP   # Vertical Alignment of Component

        self.grid_occupancy: Tuple[int, int] = (1, 1)    # width/height that the component takes up in a grid
        self.grid_coordinate: Tuple[int, int] = (0, 0)   # which grid coordinate the component occupies

        # used by the component to configure itself
        self.bg: engine.Surface = None                         # bg image for the component
        self.bg_color: Color4 = (0, 0, 0, 0)            # (if no bg) - bg fill color for the component

        self.bg_align: Tuple[HAlignment, VAlignment] = (HAlignment.CENTER,
                                                        VAlignment.CENTER)

        self.layout: UILayoutType = UILayoutType.NONE   # layout type for the component (see ui_framework_layout.py)
        self.list_style: ListLayoutStyle = (            # list layout style for the component, if using UILayoutType.LIST
            ListLayoutStyle.ROW )

        self.resize_mode: ResizeMode = (                # resize mode; AUTO components will dynamically resize themselves,
            ResizeMode.AUTO )                           # whereas MANUAL components will NEVER resize themselves.
                                                        # Probably always use AUTO, since it'll use special logic.

        # space on both sides horizontally and vertically that this component
        # can use to draw additional overflowing pixels
        self.overflow: List[UIMetric, UIMetric] = [UIMetric.pixels(0),
                                                   UIMetric.pixels(0),
                                                   UIMetric.pixels(0),
                                                   UIMetric.pixels(0)]

        self.size: List[UIMetric] = [UIMetric.percent(100),
                                      UIMetric.percent(100)]

        self.margin: List[UIMetric] = [UIMetric.pixels(0),
                                        UIMetric.pixels(0),
                                        UIMetric.pixels(0),
                                        UIMetric.pixels(0)]

        self.padding: List[UIMetric] = [UIMetric.pixels(0),
                                         UIMetric.pixels(0),
                                         UIMetric.pixels(0),
                                         UIMetric.pixels(0)]

        # temporary offset (horizontal, vertical) - used for animations
        self.offset: List[UIMetric] = [UIMetric.pixels(0),
                                        UIMetric.pixels(0)]

        # scroll offset
        self.scroll: List[UIMetric] = [UIMetric.pixels(0),
                                        UIMetric.pixels(0)]

        # maximum width for the component
        # Useful for dynamic components such as dialog.
        self.max_width: UIMetric = UIMetric.percent(100)
        # maximum height for the component.
        self.max_height: UIMetric = UIMetric.percent(100)

        self.opacity: float = 1                         # layer opacity for the element.


        # ignore
        self._done_init = True

    def __setattr__(self, name: str, value: Any) -> None:
        # is it actually updating something?
        try:
            if self.__getattribute__(name) == value:
                return
        except:
            pass

        _should_redraw = True

        if name == '_parent_pointer' or name == '_done_init' or not self._done_init:
            super(ComponentProperties, self).__setattr__(name, value)
            return
        if name in ['max_width', 'max_height']:
            value = UIMetric.parse(value)
            if self.__getattribute__(name) == value:
                return
            super(ComponentProperties, self).__setattr__(name, value)
            self._parent_pointer._recalculate_cached_size_from_props()
        elif name in ['size', 'offset', 'scroll', 'margin', 'padding', 'overflow']:
            value = tuple([UIMetric.parse(i) for i in value])
            if self.__getattribute__(name) == value:
                return
            super(ComponentProperties, self).__setattr__(name, value)
            if name == 'size' or name == 'padding':
                self._parent_pointer._recalculate_cached_size_from_props()
            elif name == 'offset':
                _should_redraw = False
                self._parent_pointer._recalculate_cached_offset_from_props()
                if self._parent_pointer.parent:
                    self._parent_pointer.parent._should_redraw = True
            elif name == 'scroll':
                _should_redraw = False
                self._parent_pointer._recalculate_cached_scroll_from_props()
                if self._parent_pointer.parent:
                    self._parent_pointer.parent._should_redraw = True
            elif name == 'margin':
                _should_redraw = False
                self._parent_pointer._recalculate_cached_margin_from_props()
                if self._parent_pointer.parent:
                    self._parent_pointer.parent._should_redraw = True
            elif name == 'overflow':
                self._parent_pointer._recalculate_cached_overflow_from_props()
        elif name == 'height':
            value = UIMetric.parse(value)
            if self.size[1] == value:
                return
            super(ComponentProperties, self).__setattr__('size', (self.size[0], value))
            self._parent_pointer._recalculate_cached_size_from_props()
        elif name == 'width':
            value = UIMetric.parse(value)
            if self.size[0] == value:
                return
            super(ComponentProperties, self).__setattr__('size', (value, self.size[1]))
            self._parent_pointer._recalculate_cached_size_from_props()
        elif name in ['h_alignment', 'v_alignment']:
            super(ComponentProperties, self).__setattr__(name, value)
            _should_redraw = False
        else:
            super(ComponentProperties, self).__setattr__(name, value)
            self._parent_pointer._recalculate_cached_dimensions_from_props()

        try:
            if _should_redraw:
                self._parent_pointer._should_redraw = True
        except: # probably hasn't been initialized yet
            pass

class RootComponent():
    """Dummy component to simulate the top-level window
    """
    def __init__(self):
        self.width: int = WINWIDTH
        self.height: int = WINHEIGHT
        self.padding: Tuple[int, int, int, int] = (0, 0, 0, 0)
        self.size = (self.width, self.height)

class UIComponent():
    def __init__(self, name: str = "", parent: UIComponent = None):
        """A generic UI component. Contains convenient functionality for
        organizing a UI, as well as UI animation support.

        NOTE: If using percentages, all of width, height, offset, and margin
        are stored as percentages of the size of the parent, while
        padding is stored as a percentage of the self's size.

        Margin and Padding are stored as Left, Right, Top, and Bottom.

        self.children are UI component children.
        self.manual_surfaces are manually positioned surfaces, to support more primitive
            and direct control over the UI.
        """
        self._done_init = False
        if not parent:
            self.parent = RootComponent()
            self.is_root = True
        else:
            self.parent = parent
            self.is_root = False

        self.layout_handler = UILayoutHandler(self)

        self.name = name

        self.children: List[UIComponent] = []
        self.manual_surfaces: List[Tuple[Tuple[int, int], engine.Surface, int, str]] = []

        self.props: ComponentProperties = ComponentProperties(self)

        # these are cached parameters, they cannot be edited (see setattr)
        self.max_width: int = 0
        self.max_height: int = 0

        self.tsize: Tuple[int, int] = (0, 0)
        self.twidth: int = 0
        self.theight: int = 0

        self.isize: Tuple[int, int] = (0, 0)
        self.iwidth: int = 0
        self.iheight: int = 0

        self.size: Tuple[int, int] = (0, 0)
        self.height: int = 0
        self.width: int = 0

        self.margin: Tuple[int, int, int, int] = (0, 0, 0, 0)
        self.padding: Tuple[int, int, int, int] = (0, 0, 0, 0)

        self.offset: Tuple[int, int] = (0, 0)
        self.scroll: Tuple[int, int] = (0, 0)
        self.overflow: Tuple[int, int, int, int] = (0, 0, 0, 0)
        # end cached parameters

        self.cached_background: engine.Surface = None # contains the rendered background.

        # animation queue
        self.queued_animations: List[UIAnimation] = []
        # saved animations
        self.saved_animations: Dict[str, List[UIAnimation]] = {}
        # animation speed-up
        self.animation_speed: int = 1

        # secret internal timekeeper, basically never touch this
        self._chronometer: Callable[[], int] = engine.get_time
        self._last_update: int = self._chronometer()

        self.enabled: bool = True
        self.on_screen: bool = True


        # freezing stuff (see freeze())
        self._frozen = False
        self._frozen_children: List[UIComponent] = []

        self._should_redraw = True
        self._cached_surf: engine.Surface = None
        # for testing
        self._times_drawn: int = 0
        self._logging: bool = False

        self._done_init = True
        self._recalculate_cached_dimensions_from_props()

    def set_chronometer(self, chronometer: Callable[[], int]):
        self._chronometer = chronometer
        self._last_update = self._chronometer()
        for child in self.children:
            child.set_chronometer(chronometer)

    @classmethod
    def create_base_component(cls, win_width=WINWIDTH, win_height=WINHEIGHT) -> UIComponent:
        """Creates a blank component that spans the entire screen; a base component
        to which other components can be attached. This component should not be used
        for any real rendering; it is an organizational tool, and should not be
        animated.

        Args:
            win_width (int): pixel width of the window. Defaults to the global setting.
            win_height(int): pixel height of the window. Defaults to the global setting.

        Returns:
            UIComponent: a blank base component
        """
        base = cls()
        base.width = win_width
        base.height = win_height
        base.overflow = (0, 0, 0, 0)
        return base

    @classmethod
    def from_existing_surf(cls, surf: engine.Surface) -> UIComponent:
        """Creates a sparse UIComponent from an existing surface.

        Args:
            surf (engine.Surface): Surface around which the UIComponent shall be wrapped

        Returns:
            UIComponent: A simple, unconfigured UIComponent consisting of a single surf
        """
        component = cls()
        component.width = surf.get_width()
        component.height = surf.get_height()
        component.max_width = surf.get_width()
        component.max_height = surf.get_height()
        component.set_background(surf)
        return component

    def set_background(self, bg: Union[engine.Surface, Color4]):
        """Set the background of this component to bg_surf.
        If the size doesn't match, it will be rescaled on draw.

        Args:
            bg_surf (engine.Surface): Any surface.
        """
        if isinstance(bg, engine.Surface):
            self.props.bg = bg
        elif isinstance(bg, Tuple):
            self.props.bg_color = bg
        # set this to none; the next time we render,
        # the component will regenerate the background.
        # See _create_bg_surf() and to_surf()
        self.cached_background = None

    def add_child(self, child: UIComponent):
        """Add a child component to this component.
        NOTE: Order matters, depending on the layout
        set in UIComponent.props.layout.

        Also triggers a component reset, if the component is dynamically sized.

        Args:
            child (UIComponent): a child UIComponent
        """
        if child:
            child.parent = self
            child.is_root = False
            child._recalculate_cached_dimensions_from_props()
            child.set_chronometer(self._chronometer)
            self.children.append(child)
            child._should_redraw = True
            if self.props.resize_mode == ResizeMode.AUTO:
                self._should_redraw = True
        else:
            logging.warning('Attempted to add Nonetype Child to component %s' % self.name)

    def has_child(self, child_name: str) -> bool:
        for child in self.children:
            if child_name == child.name:
                return True
        return False

    def get_child(self, child_name: str) -> Optional[UIComponent]:
        for child in self.children:
            if child_name == child.name:
                return child
        return None

    def remove_child(self, child_name: str) -> bool:
        """remove a child from this component.

        Args:
            child_name (str): name of child component.

        Returns:
            bool: whether or not the child existed in the first place to be removed
        """
        for idx, child in enumerate(self.children):
            if child.name == child_name:
                self.children.pop(idx)
                return True
        return False

    def freeze(self):
        """'Freezing' will turn all UIComponent children into a single image.
        This is useful for performance reasons, so if a component's children don't make
        heavy use of animations (such as sprite animations), this is highly encouraged.

        Reverse using the unfreeze command.
        """
        self._frozen_children = self.children[:]
        for child in self.children:
            child.on_screen = True
        frozen_surf = UIComponent.from_existing_surf(self.to_surf(no_cull=True))
        frozen_surf.overflow = self.overflow
        frozen_surf.props.bg_align = (HAlignment.LEFT, VAlignment.TOP)
        self.children.clear()
        self.children.append(frozen_surf)
        self._frozen = True

    def unfreeze(self, force=False):
        """see freeze() for documentation. Don't use this without calling freeze() first, or else.

        Force will force unfreeze, even if children have been (accidentally) added since the last freeze."""
        if len(self.children) > 1 and not force:
            raise ValueError('attempting to unfreeze component %s, but more than one child was detected!' % self.name)
        if not self._frozen:
            raise ValueError('attempting to unfreeze component %s without having frozen' % self.name)
        if self._frozen_children:
            self.children = self._frozen_children[:]
        self._frozen_children.clear()
        self._frozen = False

    def add_surf(self, surf: engine.Surface, pos: Tuple[int, int] = (0, 0), z_level: int = 0, name: str = None):
        """Add a hard-coded surface to this component.

        Args:
            surf (engine.Surface): A Surface
            pos (Tuple[int, int]): the coordinate position of the top left of surface
        """
        self._should_redraw = True
        self.manual_surfaces.append((pos, surf, z_level, name))

    def remove_surf(self, surf_name: str):
        """remove all surfaces with name from the manual surfaces

        Args:
            surf_name (str): name of the surface passed in add_surf
        """
        self._should_redraw = True
        self.manual_surfaces = [surf_tup for surf_tup in self.manual_surfaces if not surf_tup[3] == surf_name]

    def should_redraw(self) -> bool:
        return self._should_redraw or any([child.should_redraw() for child in self.children if child.enabled])

    def did_redraw(self):
        pass

    def speed_up_animation(self, multiplier: int):
        """scales the animation of the component and its children

        Args:
            multiplier (int): the animation speed to be set
        """
        self.animation_speed = multiplier
        for child in self.children:
            child.speed_up_animation(multiplier)

    def is_animating(self) -> bool:
        """
        Returns:
            bool: Is this component currently in the middle of an animation
        """
        return len(self.queued_animations) != 0

    def any_children_animating(self) -> bool:
        """Returns whether or not any children are currently in the middle of an animation.
        Useful for deciding whether or not to shut this component down.

        Returns:
            bool: Are any children recursively animating?
        """
        for child in self.children:
            if child.any_children_animating():
                return True
            if len(child.queued_animations) > 0:
                return True
        return False

    @animated('!enter')
    def enter(self):
        """the component enters, i.e. allows it to display.

        Because of the @animated tag, will automatically queue
        the animation named "!enter" if it exists in the UIObject's
        saved animations
        """
        for child in self.children:
            child.enter()
        self.enabled = True
        self._should_redraw = True

    @animated('!exit')
    def exit(self, is_top_level=True) -> bool:
        """Makes the component exit, i.e. transitions it out

        Because of the @animated tag, will automatically queue
        the animation named "!exit" if it exists in the UIObject's
        saved animations

        This will also recursively exit any children.

        Args:
            is_top_level (bool): Whether or not this is the top level parent.
            If not, then this will not actually disable. This is because if
            you disable a top-level component, then you will never render its children
            anyway; this will avoid graphical bugs such as children vanishing instantly
            before the parent animates out.

        Returns:
            bool: whether or not this is disabled, or is waiting on children to finish animating.
        """
        self._should_redraw = True
        for child in self.children:
            child.exit(False)
        if not is_top_level:
            return
        if self.any_children_animating() or self.is_animating():
            # there's an animation playing; wait until afterwards to exit it
            self.queue_animation([toggle_anim(False)], force=True)
        else:
            self.enabled = False

    def enable(self):
        """does the same thing as enter(), except forgoes all animations
        """
        self._should_redraw = True
        self.enabled = True
        for child in self.children:
            child.enable()

    def disable(self, force=False):
        """Does the same as exit(), except forgoes all animations

        Args:
            force (bool): Whether or not to clear all animations as well
        """
        self._should_redraw = True
        self.enabled = False
        if force:
            self.skip_all_animations()

    def queue_animation(self, animations: List[UIAnimation] = [], names: List[str] = [], force: bool = False):
        """Queues a series of animations for the component. This method can be called with
        arbitrary animations to play, or it can be called with names corresponding to
        an animation saved in its animation dict, or both, with names taking precedence.
        The animations will automatically trigger in the order in which they were queued.

        NOTE: by default, this does not allow queueing when an animation is already playing.

        Args:
            animation (List[UIAnimation], optional): A list of animations to queue. Defaults to [].
            name (List[str], optional): The names of saved animations. Defaults to [].
            force (bool, optional): Whether or not to queue this animation even if other animations are already playing.
            Defaults to False.
        """
        if not force and self.is_animating():
            return
        for name in names:
            if name in self.saved_animations:
                n_animation = self.saved_animations[name]
                for anim in n_animation:
                    anim.component = self
                    self.queued_animations.append(anim)
        for animation in animations:
            animation.component = self
            self.queued_animations.append(animation)

    def push_animation(self, animations: List[UIAnimation] = [], names: List[str] = []):
        """Pushes an animation onto the animation stack, effectively pausing
        the current animation and starting another one. N.B. this will not call
        the "begin_anim" function of the first animation upon it resuming, so using this may result in
        graphical "glitches". Don't use this unless you know exactly why you're using it.

        Args:
            animation (UIAnimation): The UIAnimation to push and begin *right now*.
        """
        for name in names[::-1]:
            if name in self.saved_animations:
                n_animation = self.saved_animations[name]
                for anim in n_animation[::-1]:
                    self.queued_animations.insert(0, anim)

        for animation in animations[::-1]:
            animation.component = self
            self.queued_animations.insert(0, animation)

    def save_animation(self, animation: UIAnimation, name: str):
        """Adds an animation to the UIComponent's animation dict.
        This is useful for adding animations that may be called many times.

        Args:
            animation (UIAnimation): [description]
            name (str): [description]
        """
        if name in self.saved_animations:
            self.saved_animations[name].append(animation)
        else:
            self.saved_animations[name] = [animation]

    def skip_next_animation(self):
        """Finishes the next animation immediately
        """
        current_num_animations = len(self.queued_animations)
        while len(self.queued_animations) >= current_num_animations and len(self.queued_animations) > 0:
            self.update(100)

    def skip_all_animations(self):
        """clears the animation queue by finishing all of them instantly, except for unskippable animations
        Useful for skip button implementation.
        """
        for child in self.children:
            child.skip_all_animations()

        # remove unskippable animations from queue
        unskippables = [anim for anim in self.queued_animations if not anim.skippable]
        self.queued_animations = list(filter(lambda anim: anim.skippable, self.queued_animations))
        while len(self.queued_animations) > 0:
            self.update(100)
        self.queued_animations = unskippables

    def update(self, manual_delta_time=0):
        """update. used at the moment to advance animations.
        """
        if manual_delta_time > 0:
            delta_time = manual_delta_time
        else:
            delta_time = (self._chronometer() - self._last_update) * self.animation_speed
        for child in self.children:
            child.update(delta_time)
        self._last_update = self._last_update + delta_time
        if len(self.queued_animations) > 0:
            try:
                if self.queued_animations[0].update(delta_time):
                    # the above function call returns True if the animation is finished
                    self.queued_animations.pop(0)
            except Exception as e:
                logging.exception('%s: Animation exception! Aborting animation for component %s. Error message: %s',
                                  'ui_framework.py:update()',
                                  self.name,
                                  repr(e))
                self.queued_animations.pop(0)

    def on_parent_resize(self):
        self._should_redraw = True

    def _reset(self, reason: str = None):
        """Pre-draw: take all known props and state, and recalculate true size one last time.
        Args:
            reason (str): the source of the reset call; usually the name of the function or property
            (e.g. 'size')
        """
        pass

    def _create_bg_surf(self) -> engine.Surface:
        """Generates the background surf for this component of identical dimension
        as the component itself.

        Returns:
            engine.Surface: A surface of size self.width x self.height plus overflows possibly,
            containing a background image.
        """
        overflow_sum = (self.overflow[0] + self.overflow[1],
                        self.overflow[2] + self.overflow[3])

        overflow_size = tuple_add(self.tsize, overflow_sum)
        if self.props.bg is None:
            surf = engine.create_surface(overflow_size, True)
            # fill center only
            center_size = tuple_add(tmult(self.tsize, 0.5), self.overflow[::2])
            bg_size = self.tsize
            bg_offset = tuple_sub(center_size, tmult(bg_size, 0.5))
            surf.fill(self.props.bg_color, (*bg_offset, *self.tsize))
            return surf
        else:
            if not self.cached_background or not self.cached_background.get_size() == overflow_size:
                base = engine.create_surface(overflow_size, True)
                # align it
                bg_size = self.props.bg.get_size()
                center_size = tuple_add(tmult(self.tsize, 0.5), self.overflow[::2])
                bg_offset = tuple_sub(center_size, tmult(bg_size, 0.5))
                if self.props.bg_align[0] == HAlignment.LEFT:
                    bg_offset = (0, bg_offset[1])
                elif self.props.bg_align[0] == HAlignment.RIGHT:
                    bg_offset = (overflow_size[0] - bg_size[0], bg_offset[1])

                if self.props.bg_align[1] == VAlignment.TOP:
                    bg_offset = (bg_offset[0], 0)
                elif self.props.bg_align[1] == VAlignment.BOTTOM:
                    bg_offset = (bg_offset[0], overflow_size[1] - bg_size[1])
                base.blit(self.props.bg, bg_offset)
                self.cached_background = base
            return self.cached_background

    def to_surf(self, no_cull=False, should_not_cull_on_redraw=True) -> engine.Surface:
        if not self.enabled:
            self._should_redraw = False
            return engine.create_surface(self.size, True)
        if self.is_root:
            self.update()
        if not self.should_redraw() and self._cached_surf:
            if self._logging:
                print("returning cached for", self.name)
            base_surf = self._cached_surf
        else:
            if self._logging:
                print("regenerating for", self.name)
            self._reset('to_surf' + self.name if self.name else "")
            # draw the background.
            base_surf = self._create_bg_surf().copy()

            # draw all hard coded surfaces by z-index
            negative_z_children = [surf_tup for surf_tup in self.manual_surfaces if surf_tup[2] < 0]
            sorted_neg_z = sorted(negative_z_children, key=lambda tup: tup[2])
            for child in sorted_neg_z:
                pos = tuple_add(child[0], self.overflow[::2])
                img = child[1]
                base_surf.blit(img, pos)

            # @TODO: add z-index support for children. For now, they're all 0
            # position and then draw all children recursively according to our layout
            child_surfs = []
            for child in self.children: # draw first to allow the child to update itself
                if self._logging:
                    print("Adding child %s" % child.name)
                child_surfs.append(child.to_surf())
            child_positions = self.layout_handler.generate_child_positions(should_not_cull_on_redraw)
            for idx, child in enumerate(self.children):
                if idx in child_positions:
                    base_surf.blit(child_surfs[idx], tuple_add(tuple_sub(child_positions[idx], child.overflow[::2]), self.overflow[::2]))
                    child.on_screen = True
                else:
                    child.on_screen = False

            # draw all hard coded surfaces by z-index
            z_children = [surf_tup for surf_tup in self.manual_surfaces if surf_tup[2] >= 0]
            sorted_z = sorted(z_children, key=lambda tup: tup[2])
            for child in sorted_z:
                pos = tuple_add(child[0], self.overflow[::2])
                img = child[1]
                base_surf.blit(img, pos)
            # handle own opacity
            if self.props.opacity < 1:
                base_surf = image_mods.make_translucent(base_surf, 1 - self.props.opacity)
            self._cached_surf = base_surf

            self._times_drawn += 1
            self._should_redraw = False
            self.did_redraw()

        if not no_cull:
            # scroll the component
            scroll_x, scroll_y = self.scroll
            scroll_width = min(self.twidth - scroll_x, self.width)
            scroll_height = min(self.theight - scroll_y, self.height)
            overflow_sum = (self.overflow[0] + self.overflow[1],
                            self.overflow[2] + self.overflow[3])
            scroll_width, scroll_height = tuple_add((scroll_width, scroll_height), overflow_sum)
            ret_surf = engine.subsurface(base_surf, (scroll_x, scroll_y, scroll_width, scroll_height))
        else:
            ret_surf = base_surf
        return ret_surf.copy()

    #################################
    # hidden methods for performance#
    #################################
    def _recalculate_cached_dimensions_from_props(self):
        if not self.on_screen:
            return
        self._recalculate_cached_size_from_props()
        self._recalculate_cached_margin_from_props()
        self._recalculate_cached_offset_from_props()
        self._recalculate_cached_scroll_from_props()
        self._recalculate_cached_overflow_from_props()
        for child in self.children:
            child._recalculate_cached_dimensions_from_props()

    def _recalculate_cached_size_from_props(self):
        if not self.on_screen:
            return
        pwidth, pheight = tuple_sub(self.parent.size, (self.parent.padding[0] + self.parent.padding[1],
                                                       self.parent.padding[2] + self.parent.padding[3]))
        ctwidth = self.props.size[0].to_pixels(pwidth)
        cmax_width = self.props.max_width.to_pixels(pwidth)
        cwidth = min(cmax_width, ctwidth)

        ctheight = self.props.size[1].to_pixels(pheight)
        cmax_height = self.props.max_height.to_pixels(pheight)
        cheight = min(ctheight, cmax_height)

        ctsize = (ctwidth, ctheight)
        csize = (cwidth, cheight)

        cpadding = (self.props.padding[0].to_pixels(ctsize[0]),
            self.props.padding[1].to_pixels(ctsize[0]),
            self.props.padding[2].to_pixels(ctsize[1]),
            self.props.padding[3].to_pixels(ctsize[1]))

        ciwidth = cwidth - cpadding[0] - cpadding[1]
        ciheight = cheight - cpadding[2] - cpadding[3]
        cisize = (ciwidth, ciheight)
        self.cached_background = None
        super(UIComponent, self).__setattr__('max_width', cmax_width)
        super(UIComponent, self).__setattr__('max_height', cmax_height)

        super(UIComponent, self).__setattr__('tsize', ctsize)
        super(UIComponent, self).__setattr__('twidth', ctwidth)
        super(UIComponent, self).__setattr__('theight', ctheight)

        super(UIComponent, self).__setattr__('isize', cisize)
        super(UIComponent, self).__setattr__('iwidth', ciwidth)
        super(UIComponent, self).__setattr__('iheight', ciheight)

        super(UIComponent, self).__setattr__('size', csize)
        super(UIComponent, self).__setattr__('width', cwidth)
        super(UIComponent, self).__setattr__('height', cheight)
        super(UIComponent, self).__setattr__('padding', cpadding)
        for child in self.children:
            child._recalculate_cached_size_from_props()

    def _recalculate_cached_margin_from_props(self):
        if not self.on_screen:
            return
        pwidth, pheight = tuple_sub(self.parent.size, (self.parent.padding[0] + self.parent.padding[1], self.parent.padding[2] + self.parent.padding[3]))
        cmargin = (self.props.margin[0].to_pixels(pwidth),
                    self.props.margin[1].to_pixels(pwidth),
                    self.props.margin[2].to_pixels(pheight),
                    self.props.margin[3].to_pixels(pheight))
        super(UIComponent, self).__setattr__('margin', cmargin)
        for child in self.children:
            child._recalculate_cached_margin_from_props()

    def _recalculate_cached_offset_from_props(self):
        pwidth, pheight = tuple_sub(self.parent.size, (self.parent.padding[0] + self.parent.padding[1], self.parent.padding[2] + self.parent.padding[3]))
        coffset = (self.props.offset[0].to_pixels(pwidth), self.props.offset[1].to_pixels(pheight))
        super(UIComponent, self).__setattr__('offset', coffset)
        for child in self.children:
            child._recalculate_cached_offset_from_props()

    def _recalculate_cached_scroll_from_props(self):
        if not self.on_screen:
            return
        cscroll = tclamp((self.props.scroll[0].to_pixels(self.twidth - self.width), self.props.scroll[1].to_pixels(self.theight - self.height)), (0, 0), (self.tsize))
        super(UIComponent, self).__setattr__('scroll', cscroll)
        for child in self.children:
            child._recalculate_cached_scroll_from_props()

    def _recalculate_cached_overflow_from_props(self):
        if not self.on_screen:
            return
        pwidth, pheight = tuple_sub(self.parent.size, (self.parent.padding[0] + self.parent.padding[1], self.parent.padding[2] + self.parent.padding[3]))
        coverflow = (self.props.overflow[0].to_pixels(pwidth),
                     self.props.overflow[1].to_pixels(pwidth),
                     self.props.overflow[2].to_pixels(pheight),
                     self.props.overflow[3].to_pixels(pheight))
        super(UIComponent, self).__setattr__('overflow', coverflow)
        for child in self.children:
            child._recalculate_cached_overflow_from_props()

    @property
    def _total_to_surfs(self):
        """This is for debugging purposes. returns
        the total number of to_surf calls
        in the recursive component tree.
        """
        total = self._times_drawn
        for child in self.children:
            total += child._total_to_surfs
        return total

    def __setattr__(self, name: str, value: Any) -> None:
        if name == '_done_init' or not self._done_init or name == '_should_redraw':
            super(UIComponent, self).__setattr__(name, value)
            return

        # is it actually updating something?
        try:
            if self.__getattribute__(name) == value:
                return
        except:
            pass

        if name in CACHED_ATTRIBUTES and name not in UNSETTABLE_ATTRIBUTES:
            self.props.__setattr__(name, value)
        elif name in UNSETTABLE_ATTRIBUTES:
            return
        else:
            super(UIComponent, self).__setattr__(name, value)