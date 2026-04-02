from __future__ import annotations
from app.engine.graphics.ui_framework.ui_framework_styling import UIMetric

from typing import TYPE_CHECKING, Tuple, Union

from app.utilities.algorithms.interpolation import (cubic_easing, lerp, log_interp, tcubic_easing, tlerp,
                                                    tlog_interp)
from app.utilities.utils import clamp

if TYPE_CHECKING:
    from ..ui_framework import UIComponent

from ..ui_framework_animation import InterpolationType, UIAnimation

"""
This file contains functions that will generate commonly used animations on demand.
"""

def translate_anim(start_offset: Tuple[int, int], end_offset: Tuple[int, int],
                   duration: int=125, disable_after=False,
                   interp_mode: InterpolationType = InterpolationType.LINEAR,
                   skew: float = 10) -> UIAnimation:
    """A shorthand way of creating a translation animation.

    Args:
        start_offset (Tuple[int, int]): Starting offset
        end_offset (Tuple[int, int]): Ending offset
        duration (int, optional): measured in milliseconds. How long the animation takes. Defaults to 125 (1/8 of a second)
        disable_after (bool, optional): whether or not to disable the component after the animation halts.
            Useful for transition outs.
        interp_mode (InterpolationType, optional): which interpolation strategy to use. Defaults to linear.
        skew (float, optional): if using InterpolationType.LOGARITHMIC, what skew to use for the interpolation

    Returns:
        UIAnimation: A UIAnimation that translates the UIComponent from one point to another.
    """
    if interp_mode == InterpolationType.LINEAR:
        lerp_func = tlerp
    elif interp_mode == InterpolationType.LOGARITHMIC:
        lerp_func = lambda a, b, t: tlog_interp(a, b, t, skew)
    else:
        lerp_func = lambda a, b, t: tcubic_easing(a, b, t)

    def before_translation(c: UIComponent, *args):
        c.offset = start_offset
    def translate(c: UIComponent, anim_time, *args):
        c.offset = lerp_func(start_offset, end_offset, anim_time / duration)
    def after_translation(c: UIComponent, *args):
        c.offset = end_offset
    def should_stop(c: UIComponent, anim_time, *args) -> bool:
        return anim_time >= duration

    def disable(c: UIComponent, *args):
        c.disable()

    if disable_after:
        return UIAnimation(halt_condition=should_stop, before_anim=before_translation, do_anim=translate, after_anim=[after_translation, disable])
    else:
        return UIAnimation(halt_condition=should_stop, before_anim=before_translation, do_anim=translate, after_anim=after_translation)

def toggle_anim(enabled: bool=None, force: bool=False) -> UIAnimation:
    """A shorthand way of creating an "animation" that does nothing but disable/enable the component

    Why is this useful? Because Animations are queued; if you want to run a transition and then disable afterwards,
    this is insanely useful since it will wait until the animation adjourns to disable,
    preventing graphical bugs such as components instantly vanishing on the first frame of an animation.

    Args:
        force: Whether or not to wait for all children to stop animating. By default, this is true.

    Returns:
        UIAnimation: A UIAnimation that disables, enables, or toggles the component.
            Best used as a way to cap off a chain of queued transition animations.
    """
    if not force:
        def children_done_animating(c: UIComponent, *args):
            return not c.any_children_animating()
        halt_func = children_done_animating
    else:
        halt_func = lambda: True

    if enabled == None:
        def toggle(c: UIComponent, *args):
            if c.enabled:
                c.disable()
            else:
                c.enable()
        return UIAnimation(after_anim=toggle, halt_condition = halt_func)
    elif enabled == False:
        def disable(c: UIComponent, *args):
            c.disable()
        return UIAnimation(after_anim=disable, halt_condition = halt_func)
    else:
        def enable(c: UIComponent, *args):
            c.enable()
        return UIAnimation(after_anim=enable)

def fade_anim(start_opacity: float, end_opacity: float,
              duration: int=125, disable_after=False,
              interp_mode: InterpolationType = InterpolationType.LINEAR,
              skew: float = 10) -> UIAnimation:
    """A shorthand way of creating a fade animation.

    Args:
        start_offset (float): Starting offset
        end_offset (float): Ending offset
        duration (int, optional): measured in milliseconds. How long the animation takes. Defaults to 125 (1/8 of a second)
        disable_after (bool, optional): whether or not to disable the component after the animation halts.
            Useful for transition outs.
        interp_mode (InterpolationType, optional): which interpolation strategy to use. Defaults to linear.
        skew (float, optional): if using InterpolationType.LOGARITHMIC, what skew to use for the interpolation

    Returns:
        UIAnimation: A UIAnimation that translates the UIComponent from one point to another.
    """
    if interp_mode == InterpolationType.LINEAR:
        lerp_func = lerp
    elif interp_mode == InterpolationType.LOGARITHMIC:
        lerp_func = lambda a, b, t: log_interp(a, b, t, skew)
    else:
        lerp_func = lambda a, b, t: cubic_easing(a, b, t)

    start_opacity = clamp(start_opacity, 0, 1)
    end_opacity = clamp(end_opacity, 0, 1)
    def before_fade(c: UIComponent, *args):
        c.props.opacity = start_opacity
    def fade(c: UIComponent, anim_time, *args):
        c.props.opacity = lerp_func(start_opacity, end_opacity, anim_time / duration)
    def after_fade(c: UIComponent, *args):
        c.props.opacity = end_opacity
    def should_stop(c: UIComponent, anim_time, *args) -> bool:
        return anim_time >= duration

    def disable(c: UIComponent, *args):
        c.disable()

    if disable_after:
        return UIAnimation(halt_condition=should_stop, before_anim=before_fade, do_anim=fade, after_anim=[after_fade, disable])
    else:
        return UIAnimation(halt_condition=should_stop, before_anim=before_fade, do_anim=fade, after_anim=after_fade)

def component_scroll_anim(start_scroll: Tuple[int | float | str | UIMetric, int | float | str | UIMetric],
                          end_scroll: Tuple[int | float | str | UIMetric, int | float | str | UIMetric],
                          duration: int=125, disable_after=False,
                          interp_mode: InterpolationType = InterpolationType.LINEAR,
                          skew: float = 10) -> UIAnimation:
    """A shorthand way of creating a scroll animation.

    Args:
        start_offset (Tuple[int | float | str | UIMetric, int | float | str | UIMetric]): Starting scroll pos
        end_offset (Tuple[int | float | str | UIMetric, int | float | str | UIMetric]): Ending scroll pos
        duration (int, optional): measured in milliseconds. How long the animation takes. Defaults to 125 (1/8 of a second)
        disable_after (bool, optional): whether or not to disable the component after the animation halts.
            Useful for transition outs.
        interp_mode (InterpolationType, optional): which interpolation strategy to use. Defaults to linear.
        skew (float, optional): if using InterpolationType.LOGARITHMIC, what skew to use for the interpolation

    Returns:
        UIAnimation: A UIAnimation that scrolls the UIComponent from one height to another
    """
    # convert scroll input
    if isinstance(start_scroll[0], str):
        sscroll = (UIMetric.parse(start_scroll[0]), UIMetric.parse(start_scroll[1]))
        escroll = (UIMetric.parse(end_scroll[0]), UIMetric.parse(end_scroll[1]))
    else:
        sscroll = start_scroll
        escroll = end_scroll

    if interp_mode == InterpolationType.LINEAR:
        lerp_func = tlerp
    elif interp_mode == InterpolationType.LOGARITHMIC:
        lerp_func = lambda a, b, t: tlog_interp(a, b, t, skew)
    else:
        lerp_func = lambda a, b, t: tcubic_easing(a, b, t)

    def before_scroll(c: UIComponent, *args):
        c.scroll = sscroll
    def do_scroll(c: UIComponent, anim_time, *args):
        c.scroll = lerp_func(sscroll, escroll, anim_time / duration)
    def after_translation(c: UIComponent, *args):
        c.scroll = escroll
    def should_stop(c: UIComponent, anim_time, *args) -> bool:
        return anim_time >= duration

    def disable(c: UIComponent, *args):
        c.disable()

    if disable_after:
        return UIAnimation(halt_condition=should_stop, before_anim=before_scroll, do_anim=do_scroll, after_anim=[after_translation, disable])
    else:
        return UIAnimation(halt_condition=should_stop, before_anim=before_scroll, do_anim=do_scroll, after_anim=after_translation)
