from __future__ import annotations
from app.utilities.typing import NID
from collections import OrderedDict
from typing import Optional, Union

from app.data.database.level_units import GenericUnit, UniqueUnit, UnitGroup
from app.events.regions import Region
from app.utilities.data import Data, Prefab

class LevelPrefab(Prefab):
    def __init__(self, nid, name):
        self.nid = nid
        self.name = name
        self.tilemap: Optional[NID] = None  # Tilemap Nid
        self.bg_tilemap: Optional[NID] = None # bg tilemap nid
        self.party: NID = None  # Party Prefab Nid
        self.music = OrderedDict()

        self.objective = {'simple': '',
                          'win': '',
                          'loss': ''}
        self.roam: bool = False
        self.roam_unit: str = None

        self.go_to_overworld: bool = False

        self.units = Data[Union[UniqueUnit, GenericUnit]]()
        self.regions = Data[Region]()
        self.unit_groups = Data()

    def save_attr(self, name, value):
        if name == 'units':
            value = [unit.save() for unit in value]
        elif name == 'unit_groups':
            value = [unit_group.save() for unit_group in value]
        elif name == 'regions':
            value = [region.save() for region in value]
        elif name == 'objective':
            value = value.copy()  # Must make a copy so we don't keep a reference to the same one
        else:
            value = super().save_attr(name, value)
        return value

    def restore_attr(self, name, value):
        if name == 'units':
            value = Data([GenericUnit.restore(unit_data) if unit_data['generic']
                          else UniqueUnit.restore(unit_data) for unit_data in value])
        elif name == 'unit_groups':
            value = Data([UnitGroup.restore(val) for val in value])
        elif name == 'regions':
            value = Data([Region.restore(val) for val in value])
        elif name == 'music':
            value = {k: value.get(k) for k in value.keys()}
        else:
            value = super().restore_attr(name, value)
        return value

    @classmethod
    def default(cls):
        return cls('0', 'Prologue')

class LevelCatalog(Data[LevelPrefab]):
    datatype = LevelPrefab
