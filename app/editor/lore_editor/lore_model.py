from PyQt5.QtCore import Qt

from app.data.database.database import DB
from app.editor.base_database_gui import DragDropCollectionModel
from app.utilities import str_utils

from app.data.database import lore

class LoreModel(DragDropCollectionModel):
    def data(self, index, role):
        if not index.isValid():
            return None
        if role == Qt.DisplayRole:
            lore = self._data[index.row()]
            text = lore.nid + ': ' + lore.category
            return text
        return None

    def create_new(self):
        nids = [d.nid for d in self._data]
        nid = name = str_utils.get_next_name("New Lore", nids)
        new_lore = lore.Lore(nid, name, name)
        DB.lore.append(new_lore)
        return new_lore

    def on_nid_changed(self, old_value, new_value):
        pass
