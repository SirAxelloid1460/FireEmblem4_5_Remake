from app.utilities.utils import clamp
import math

def lerp(a: float, b: float, t: float) -> float:
    """Linear interpolation

    Args:
        a, b (float): values to lerp between
        t (float): time or proportion to lerp for, must be in range [0, 1]

    Returns:
        [float]: lerped value
    """
    t = clamp(t, 0, 1)
    return (b - a) * t + a

def tlerp(a: tuple, b: tuple, t: float) -> tuple:
    """Linear between two tuples

    Args:
        a, b (tuple): tuples to lerp betweeen
        t (float): time or proportion to lerp for, must be in range [0, 1]

    Returns:
        tuple: lerpd tuple
    """
    lerp_func = lambda t1, t2: lerp(t1, t2, t)
    return tuple(map(lerp_func, a, b))

def log_interp(a: float, b: float, t: float, skew: float = 10) -> float:
    """Exponential interpolation between two values

    Args:
        a, b (float): values to interpolate between
        t (float): time or progress to interpolate at, must be in range [0, 1]
        skew (float, optional): "skewness" of the interpolation. MUST be a positive float.
            1 is roughly a linear curve; higher numbers create faster starts and slower finishes,
            while lower numbers have slow starts and fast finishes. Defaults to 10.

    Returns:
        float: interpolated value
    """
    # can't be 0 because divide by 0
    t = clamp(t, 0.0001, 1)
    skew = max(0.0001, skew)
    ratio = 1 + 1 / skew
    return (b - a) * math.pow(ratio, -1/t + 1) + a

def tlog_interp(a: tuple, b: tuple, t: float, skew: float = 10) -> float:
    """exponential interpolation between two tuples

    Args:
        a, b (tuple): tuples to interpolate between
        t (float): time or progress to interpolate at, must be in range [0, 1]
        skew (float, optional): "skewness" of the interpolation. MUST be a positive float.
            1 is roughly a linear curve; higher numbers create faster starts and slower finishes,
            while lower numbers have slow starts and fast finishes. Defaults to 10.

    Returns:
        tuple: interpolated value
    """
    interp_func = lambda t1, t2: log_interp(t1, t2, t, skew)
    return tuple(map(interp_func, a, b))

def cubic_easing(a: float, b: float, t: float) -> float:
    ratio = 4 * t * t * t if t < 0.5 else (1 - math.pow(-2 * t + 2, 3) / 2)
    return (b - a) * ratio + a

def tcubic_easing(a: tuple, b: tuple, t: float) -> tuple:
    ease_func = lambda t1, t2: cubic_easing(t1, t2, t)
    return tuple(map(ease_func, a, b))
