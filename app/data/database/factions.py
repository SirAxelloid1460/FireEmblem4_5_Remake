from dataclasses import dataclass

from app.utilities.data import Data, Prefab

@dataclass
class Faction(Prefab):
    nid: str = None
    name: str = None
    desc: str = ""

    icon_nid: str = None
    icon_index: tuple = (0, 0)

class FactionCatalog(Data[Faction]):
    datatype = Faction
