from dataclasses import dataclass

from app.utilities.data import Data, Prefab

@dataclass
class Lore(Prefab):
    nid: str = None
    name: str = None
    title: str = None
    category: str = "Character"
    text: str = ""

class LoreCatalog(Data[Lore]):
    datatype = Lore
