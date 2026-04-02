from __future__ import annotations
from functools import lru_cache
import traceback

from enum import Enum
from typing import Union

class MetricType(Enum):
  PIXEL = 0
  PERCENTAGE = 1

class UIMetric():
  """A wrapper that handles the two types of length measurement, pixels and percentages,
  and provides functions that handle, convert, and parse strings into these measurements.

  Effectively a barebones substitution of the way CSS handles length measurements.
  """
  def __init__(self, val: int, mtype: MetricType):
    self.val = int(val)
    self.mtype = mtype

    self.hash = None

  # @lru_cache
  def to_pixels(self, parent_metric: int = 100):
    if self.mtype == MetricType.PIXEL:
      return self.val
    else:
      return int(self.val * parent_metric / 100)

  @classmethod
  def pixels(cls, val):
    return cls(val, MetricType.PIXEL)

  @classmethod
  def percent(cls, val):
    return cls(val, MetricType.PERCENTAGE)

  @classmethod
  def parse(cls, metric_string):
    """Parses a metric mtype from some arbitrary given input.
    Basically, "50%" becomes a 50% UIMetric, while all other
    formatting: 50, "50px", "50.0", become 50 pixel UIMetric.

    Args:
        metric_string Union[str, int]: string or integer input

    Returns:
        UIMetric: a UIMetric corresponding to the parsed value
    """
    if isinstance(metric_string, UIMetric): # this isn't a string, but a metric already?
      return metric_string
    try:
      metric_string = str(metric_string)
      if 'px' in metric_string:
        metric_string = metric_string[:-2]
        return cls(int(metric_string), MetricType.PIXEL)
      elif '%' in metric_string:
        metric_string = metric_string[:-1]
        return cls(int(metric_string), MetricType.PERCENTAGE)
      return cls(round(float(metric_string)), MetricType.PIXEL)
    except Exception:
      # the input string was incorrectly formatted
      return cls(0, MetricType.PIXEL)

  #################################
  # magic methods for metric math #
  #################################
  def __add__(self, other: Union[UIMetric, float, int, str]):
    if isinstance(other, str):
      other = UIMetric.parse(str)
    if isinstance(other, UIMetric):
      if self.mtype == other.mtype:
        return UIMetric(self.val + other.val, self.mtype)
      else:
        raise TypeError('UIMetrics not of same type')
    elif isinstance(other, (float, int)):
      return UIMetric(self.val + other, self.mtype)

  def __radd__(self, other):
    return other + self

  def __sub__(self, other: Union[UIMetric, float, int, str]):
    if isinstance(other, str):
      other = UIMetric.parse(str)
    if isinstance(other, UIMetric):
      if self.mtype == other.mtype:
        return UIMetric(self.val - other.val, self.mtype)
      else:
        raise TypeError('UIMetrics not of same type')
    elif isinstance(other, (float, int)):
      return None

  def __rsub__(self, other):
    if isinstance(other, str):
      other = UIMetric.parse(str)
    if isinstance(other, UIMetric):
      if self.mtype == other.mtype:
        return UIMetric(other.val - self.val, self.mtype)
      else:
        raise TypeError('UIMetrics not of same type')
    elif isinstance(other, (float, int)):
      return UIMetric(other - self.val, self.mtype)

  def __mul__(self, other: Union[float, int]):
    if isinstance(other, (float, int)):
      return UIMetric(self.val * other, self.mtype)

  def __rmul__(self, other: Union[float, int]):
    return self * other

  def __truediv__(self, other: Union[float, int]):
    return self * (1 / other)

  def __hash__(self) -> int:
    if not self.hash:
      self.hash = hash((self.val, self.mtype))
    return self.hash

  def __repr__(self) -> str:
      if self.mtype == MetricType.PIXEL:
        return "{}px".format(self.val)
      else:
        return "{}%".format(self.val)

  def __eq__(self, o: object) -> bool:
      if not isinstance(o, UIMetric):
          return False
      else:
          return o.val == self.val and o.mtype == self.mtype
