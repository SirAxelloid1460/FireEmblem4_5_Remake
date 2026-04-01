from __future__ import annotations
from math import inf
from app.utilities.algorithms.interpolation import tlerp, tlog_interp
from enum import Enum

from typing import List, Optional, TYPE_CHECKING, Callable, Dict, Tuple


from app.utilities.utils import (dot_product, magnitude, normalize, tclamp, tmult, tuple_add,
                                 tuple_sub)

if TYPE_CHECKING:
    from .ui_framework import UIComponent

class InterpolationType(Enum):
    LINEAR = 0
    LOGARITHMIC = 1
    CUBIC = 2

def animated(name: str):
    """Decorator that binds an animation to a function call. For example,
    you can associate a "transition_in" animation with the "enable" function of a UIComponent.

    Args:
        name (str): name of animation to be bound
    """
    def animated_inner(func: Callable):
        def wrapper(self: UIComponent, *args, **kwargs):
            if name in self.saved_animations:
                anims = self.saved_animations[name]
                self.queue_animation(anims)
            func(self, *args, **kwargs)
        return wrapper
    return animated_inner

class UIAnimation():
    """An Animation class for the UI.

    Usage of this is straightforward. An animation consists of the following:

        component [UIComponent]: A UI Component on which to perform the animation.

        halt_condition [Callable[[UIComponent, Optional[int]], bool]]:
            A function (or list of such functions)
            that takes in a UI component and time passed and informs us if the
            animation is finished. Defaults to None, which means that it will run before_anim
            function once, and end immediately.

        before_anim, do_anim, after_anim [Callable[[UIComponent, Optional[int]]]]:
            A series of arbitrary functions (or list of such functions)
            that take in a UI Component and time passed and
            alter its properties in some way. Namely, these three functions will be called
            on the provided UI Component above.

            before_anim is called once, when the animation is begun (via animation.begin())
            do_anim is continuously called.
            after_anim is called once, when the animation ends (via the halt_condition())

            Generally, it is advised that after_anim contains the expected end state of a
            component, as animations can be skipped, and do_anim is not guaranteed to be
            called until halt_condition is satisfied.

        skippable [bool]:
            Whether or not this animation is skippable. Some animations, such as passive hovering animations,
            are not skippable, and skipping them would result in a program lock.
    """
    def __init__(self, halt_condition: Callable[[UIComponent, int], bool] = None,
                 before_anim:   List[Callable[[UIComponent, int, int]]] | Callable[[UIComponent, int, int]] = None,
                 do_anim:       List[Callable[[UIComponent, int, int]]] | Callable[[UIComponent, int, int]] = None,
                 after_anim:    List[Callable[[UIComponent, int, int]]] | Callable[[UIComponent, int, int]] = None,
                 skippable: bool = True):
        self.component: UIComponent = None
        self.skippable = skippable

        if isinstance(before_anim, list):
            self.before_anim = before_anim
        else:
            self.before_anim = [before_anim]
        if isinstance(do_anim, list):
            self.do_anim = do_anim
        else:
            self.do_anim = [do_anim]
        if isinstance(after_anim, list):
            self.after_anim = after_anim
        else:
            self.after_anim = [after_anim]
        self.should_halt = halt_condition

        self.start_time: int = 0
        self.current_time: int = 0
        self.begun = False

    def _exec_before_anims(self, component: UIComponent, start_time: int, delta_time: int):
        for before_anim in self.before_anim:
            if before_anim:
                before_anim(component, start_time, 0)

    def _exec_do_anims(self, component: UIComponent, anim_time: int, delta_time: int):
        for do_anim in self.do_anim:
            if do_anim:
                do_anim(component, anim_time, delta_time)

    def _exec_after_anims(self, component: UIComponent, anim_time: int, delta_time: int):
        for after_anim in self.after_anim:
            if after_anim:
                after_anim(component, anim_time, delta_time)

    def begin(self):
        """begins the animation

        Args:
            start_time (int, optional): the time at which the animation was begun. Defaults to 0.
                necessary to calculate animation progress and lerping
        """
        if not self.component:
            return
        self.begun = True
        self.start_time = 0
        self.current_time = 0
        self._exec_before_anims(self.component, 0, 0)

    def update(self, delta_time: int = 0) -> bool:
        """Plays the animation.
        If the animation hasn't started, start it.
        If the animation is started, iterate the animation one stage.
        If the animation should stop, finish it and return true.

        Args:
            delta_time (int, optional): the time since an animation was last updated. Defaults to 0.
                necessary to calculate animation progress and lerping

        Returns:
            bool: Whether the animation has halted.
        """
        if not self.component:
            return False
        if not self.begun:
            self.begin()
            return False
        # update internal timer
        self.current_time = self.current_time + delta_time
        anim_time = self.current_time
        # update animation
        if self.should_halt is None or self.should_halt(self.component, anim_time, delta_time):
            self._exec_after_anims(self.component, anim_time, delta_time)
            # we finished, so we want to reset the animation
            # in case we call it again
            self.reset()
            return True
        else:
            self._exec_do_anims(self.component, anim_time, delta_time)
            return False

    def reset(self):
        self.begun = False

    # override some magic methods
    def __add__(self, other: UIAnimation):
        return UIAnimation(self.should_halt,
                           self.before_anim + other.before_anim,
                           self.do_anim + other.do_anim,
                           self.after_anim + other.after_anim)

def hybridize_animation(anims: Dict[str, UIAnimation], keyfunction: Callable[[UIComponent], str]) -> UIAnimation:
    """Helper function for creating a switchable animation.

    For example: suppose you want to to combine transition-out-right and a transition-out-left animation into
    a single animation, "transition_out", for ease of calling. Obviously, transition-out-right will play
    if the component is right-aligned/on the right side of the screen, and vice versa. This function will
    composite those two animations based on a choosing function. You would pass in a dict mapping the string
    "right" to the transition-out-right animation, and "left" to the transition-out-left animation,
    and pass in a function keyfunction that returns "right' if the component is right, and "left" if the component is left.

    Args:
        anims (Dict[str, UIAnimation]): a list of animations with arbitrary keys
        keyfunction (Callable[[UIComponent, int], str]): a function for determining which key to select at any given time.
        MUST return only keys that are present in the anims Dict.

    Returns:
        UIAnimation: a hybridized UIAnimation.
    """
    def composite_before(c: UIComponent, *args):
        which_anim = keyfunction(c, *args)
        if which_anim in anims and anims[which_anim].before_anim:
            anims[which_anim]._exec_before_anims(c, *args)
    def composite_do(c: UIComponent, *args):
        which_anim = keyfunction(c, *args)
        if which_anim in anims and anims[which_anim].do_anim:
            anims[which_anim]._exec_do_anims(c, *args)
    def composite_after(c: UIComponent, *args):
        which_anim = keyfunction(c, *args)
        if which_anim in anims and anims[which_anim].after_anim:
            anims[which_anim]._exec_after_anims(c, *args)
    def composite_halt(c: UIComponent, *args) -> bool:
        which_anim = keyfunction(c, *args)
        if which_anim in anims:
            if anims[which_anim].should_halt:
                return anims[which_anim].should_halt(c, *args)
        return True

    composite_anim = UIAnimation(halt_condition=composite_halt, before_anim=composite_before, do_anim=composite_do, after_anim=composite_after)
    return composite_anim
