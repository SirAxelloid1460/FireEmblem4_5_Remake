from dataclasses import dataclass

from app.utilities.data import Data, Prefab

@dataclass
class Terrain(Prefab):
    nid: str = None
    name: str = None

    color: tuple = (0, 0, 0)
    minimap: str = None
    platform: str = None
    background: str = None

    mtype: str = None
    opaque: bool = False

    status: str = None

    def restore_attr(self, name, value):
        if name == 'color':
            value = tuple(value)
        else:
            value = super().restore_attr(name, value)
        return value

class TerrainCatalog(Data[Terrain]):
    datatype = Terrain
