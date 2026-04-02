from typing import List, Optional

from app.events import event_commands
from app.utilities.data import Data, Prefab
from app.utilities.typing import NID

class EventPrefab(Prefab):
    def __init__(self, name):
        self.name = name
        self.trigger = None
        self.level_nid = None
        self.condition: str = "True"
        self.commands: List[event_commands.EventCommand] = []
        self.only_once = False
        self.priority: int = 20

    @property
    def nid(self):
        if not self.name:
            return None
        if self.level_nid:
            return self.level_nid + " " + self.name
        else:
            return "Global " + self.name

    def save_attr(self, name, value):
        if name == 'commands':
            value = [c.save() for c in value if c]
        else:
            value = super().save_attr(name, value)
        return value

    def restore_attr(self, name, value):
        if name == 'priority':
            if value is None:
                value = 20
            else:
                value = super().restore_attr(name, value)
        elif name == 'commands':
            value = [event_commands.restore_command(c) for c in value]
            value = [v for v in value if v]
        else:
            value = super().restore_attr(name, value)
        return value

    @classmethod
    def default(cls):
        return cls('None')

class EventCatalog(Data[EventPrefab]):
    datatype = EventPrefab

    def get(self, trigger_nid, level_nid):
        return [event for event in self._list if event.trigger == trigger_nid and
                (not event.level_nid or event.level_nid == level_nid)]

    def get_by_level(self, level_nid: Optional[NID]) -> List[EventPrefab]:
        return [event for event in self._list if (not event.level_nid or not level_nid or event.level_nid == level_nid)]

    def get_by_nid_or_name(self, name_or_nid: str, level_nid: None) -> List[EventPrefab]:
        level_events = self.get_by_level(level_nid)
        return [event for event in level_events if
                ((event.nid == name_or_nid) or (event.name == name_or_nid))]

    def get_from_nid(self, key, fallback=None):
        return self._dict.get(key, fallback)
