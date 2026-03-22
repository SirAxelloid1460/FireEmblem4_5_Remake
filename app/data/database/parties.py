from dataclasses import dataclass

from app.utilities.data import Data, Prefab

@dataclass
class PartyPrefab(Prefab):
    nid: str = None
    name: str = None
    leader: str = None

class PartyCatalog(Data[PartyPrefab]):
    datatype = PartyPrefab
