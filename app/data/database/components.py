from enum import Enum, IntEnum

from app.utilities import str_utils
from app.utilities.data import Data

class ComponentType(IntEnum):
    Bool = 0
    Int = 1
    Float = 2
    String = 3
    WeaponType = 4  # Stored as Nids
    WeaponRank = 5  # Stored as Nids
    Unit = 6  # Stored as Nids
    Class = 7  # Stored as Nids
    Tag = 8
    Color3 = 9
    Color4 = 10
    Item = 12  # Stored as Nids
    Skill = 13  # Stored as Nids
    Stat = 14  # Stored as Nids
    MapAnimation = 15  # Stored as Nids
    Equation = 16  # Stored as Nids
    MovementType = 17  # Stored as Nid
    Sound = 18  # Stored as Nid
    AI = 19  # Stored as Nid
    Music = 20  # Stored as Nid
    CombatAnimation = 21  # Stored as Nid
    EffectAnimation = 22  # Stored as Nid
    Affinity = 23  # Stored as Nid
    Terrain = 24 # stored as nid
    Event = 80
    List = 100
    Dict = 101  # Item followed by integer
    FloatDict = 102  # Item followed by floating
    MultipleChoice = 103 # item is a string value from a number of choices
    MultipleOptions = 104 # item is a dict of string options with types that can be individually configured
    StringDict = 105  # Item followed by string
    NewMultipleOptions = 106 # item is a dict of string options with types that can be individually configured


def convert_type_from_string(tstr: str, ttype: ComponentType):
    if ttype == ComponentType.Int:
        return int(tstr)
    if ttype == ComponentType.Float:
        return float(tstr)
    else:
        return tstr

class Component():
    nid: str
    desc: str
    author: str = 'rainlash'
    expose = None  # Attribute
    paired_with: list = []
    tag: Enum
    value = None

    def __init__(self, value=None):
        if value is not None:
            self.value = value

    @property
    def name(self):
        name = self.__class__.__name__
        return str_utils.ignore_numbers(str_utils.camel_case(name))

    @classmethod
    def class_name(cls):
        name = cls.__name__
        return str_utils.ignore_numbers(str_utils.camel_case(name))

    def defines(self, function_name):
        return hasattr(self, function_name)

    @classmethod
    def copy(cls, other):
        return cls(other.value)

    def save(self):
        if isinstance(self.value, Data):
            return self.nid, self.value.save()
        elif isinstance(self.value, list):
            return self.nid, self.value.copy()
        else:
            return self.nid, self.value
