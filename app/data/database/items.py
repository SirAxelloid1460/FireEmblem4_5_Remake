from dataclasses import field
from typing import TYPE_CHECKING, Dict, List, Optional, Tuple
from app.data.category import Categories, CategorizedCatalog
import app.engine.item_component_access as ICA
from app.utilities.data import Data, Prefab
from app.data.database.components import Component
from app.utilities.typing import NID


class ItemPrefab(Prefab):
    nid: NID
    name: str
    desc: str
    components: Data[Component]
    icon_nid: Optional[NID]
    icon_index: Tuple[int, int]

    def __init__(self, nid, name, desc, icon_nid=None, icon_index=(0, 0), components=None):
        self.nid = nid
        self.name = name
        self.desc = desc

        self.icon_nid = icon_nid
        self.icon_index = icon_index

        self.components = components or Data()
        for component_key, component_value in self.components.items():
            self.__dict__[component_key] = component_value

    # If the attribute is not found
    def __getattr__(self, attr):
        if attr.startswith('__') and attr.endswith('__'):
            return super().__getattr__(attr)
        return None

    def __getitem__(self, key):
        return self.__dict__.get(key)

    def __setitem__(self, key, item):
        self.__dict__[key] = item

    def save(self):
        serial_dict = {'nid': self.nid,
                       'name': self.name,
                       'desc': self.desc,
                       'icon_nid': self.icon_nid,
                       'icon_index': self.icon_index,
                       'components': [c.save() for c in self.components]
                       }
        return serial_dict

    @classmethod
    def restore(cls, dat):
        item_components = Data()
        components = [ICA.restore_component(val) for val in dat['components']]
        components = [c for c in components if c]

        # NOTE: Backwards Compatability. Guarantees that additional paired components
        # added since last version are default initialized.
        all_components = Data()
        for component in components:
            all_components.append(component)
            if component.paired_with:
                for paired_nid in component.paired_with:
                    if not any([paired_nid == component.nid for component in components]):
                        component_class = ICA.get_component(paired_nid)
                        new_paired = ICA.restore_component((paired_nid, component_class.value))
                        all_components.append(new_paired)

        i = cls(dat['nid'], dat['name'], dat['desc'],
                dat['icon_nid'], dat['icon_index'],
                all_components)
        return i

class ItemCatalog(CategorizedCatalog[ItemPrefab]):
    datatype = ItemPrefab