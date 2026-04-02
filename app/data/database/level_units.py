from typing import List, Tuple
from app.utilities.typing import NID
from dataclasses import dataclass, field

from app.utilities.data import Prefab

@dataclass
class GenericUnit(Prefab):
    nid: str = None
    variant: str = None

    level: int = None
    klass: str = None

    faction: str = None

    starting_items: List[Tuple[NID, bool]] = field(default_factory=list)
    starting_skills: List[NID] = field(default_factory=list)

    team: str = None
    ai: str = None
    roam_ai: str = None
    ai_group: str = None

    starting_position: list = None  # 2-tuple
    starting_traveler: NID = None  # unit nid

    generic: bool = True

    @property
    def name(self):
        from app.data.database.database import DB
        return DB.factions.get(self.faction).name

    @property
    def desc(self):
        from app.data.database.database import DB
        return DB.factions.get(self.faction).desc

    def replace_item_nid(self, old_nid, new_nid):
        for item in self.starting_items:
            if item[0] == old_nid:
                item[0] = new_nid

    def restore_attr(self, name, value):
        if name == 'starting_items':
            # Need to convert to item nid + droppable
            value = [i if isinstance(i, list) else [i, False] for i in value]
        else:
            value = super().restore_attr(name, value)
        return value

    def get_items(self):
        return [i[0] for i in self.starting_items]

    @property
    def learned_skills(self):
        return []  # Generic units don't have personal skills

@dataclass
class UniqueUnit(Prefab):
    nid: str = None
    team: str = None
    ai: str = None
    roam_ai: str = None
    ai_group: str = None

    faction: str = None  # Always None

    starting_position: list = None  # 2-tuple
    starting_traveler: NID = None  # Unit nid

    generic: bool = False

    # If the attribute is not found
    def __getattr__(self, attr):
        if attr.startswith('__') and attr.endswith('__'):
            return super().__getattr__(attr)
        elif self.nid:
            from app.data.database.database import DB
            prefab = DB.units.get(self.nid)
            return getattr(prefab, attr)
        return None

    def save(self):
        s_dict = {}
        s_dict['nid'] = self.nid
        s_dict['team'] = self.team
        s_dict['ai'] = self.ai
        s_dict['roam_ai'] = self.roam_ai
        s_dict['ai_group'] = self.ai_group
        s_dict['starting_position'] = self.starting_position
        s_dict['starting_traveler'] = self.starting_traveler
        s_dict['generic'] = self.generic
        return s_dict

@dataclass
class UnitGroup(Prefab):
    nid: str = None
    units: list = None  # list of unit nids
    positions: dict = None  # unit nid : position

    @classmethod
    def restore(cls, value):
        self = cls(value['nid'], value['units'], value['positions'])
        self.units = [u for u in self.units if u]
        return self

    @classmethod
    def from_prefab(cls, prefab):
        self = cls(prefab.nid, prefab.units, prefab.positions)
        self.units = [u for u in self.units if u]
        return self

    def remove(self, unit_nid):
        if unit_nid in self.units:
            self.units.remove(unit_nid)
        if unit_nid in self.positions:
            del self.positions[unit_nid]

    def swap(self, old_nid, new_nid):
        for idx, nid in enumerate(self.units):
            if nid == old_nid:
                self.units[idx] = new_nid
        if old_nid in self.positions:
            self.positions[new_nid] = self.positions.pop(old_nid)
