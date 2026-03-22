from dataclasses import dataclass

from app.utilities.data import Data, Prefab
from app.utilities import str_utils

@dataclass
class StatPrefab(Prefab):
    nid: str = None
    name: str = None
    maximum: int = 30
    desc: str = ""
    position: str = "left"

    def __repr__(self):
        return self.nid

    def restore_attr(self, name, value):
        if name == 'position' and not value:
            return 'left'
        return value

class StatCatalog(Data[StatPrefab]):
    datatype = StatPrefab

    def add_new_default(self, db):
        nid = str_utils.get_next_name("New Stat", self.keys())
        new_stat = StatPrefab(nid, nid)
        self.append(new_stat)
        return new_stat
