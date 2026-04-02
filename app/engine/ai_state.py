from dataclasses import dataclass
from typing import Tuple
from enum import Enum, auto
from app.engine.objects.unit import UnitObject

class AIAction(Enum):
    NONE = auto()
    MOVE = auto()
    WAIT = auto()
    INTERACT = auto()

@dataclass
class AIStruct():
  unit: UnitObject

@dataclass
class WaitStruct(AIStruct):
  unit: UnitObject
  time: int
  mtype: AIAction = AIAction.WAIT

@dataclass
class MoveToStruct(AIStruct):
  unit: UnitObject
  target: Tuple[int, int]
  mtype: AIAction = AIAction.MOVE

@dataclass
class InteractStruct(AIStruct):
  unit: UnitObject
  mtype: AIAction = AIAction.INTERACT