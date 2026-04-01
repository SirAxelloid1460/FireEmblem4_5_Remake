from PyQt5.QtCore import Qt

from app.data.database.database import DB

from app.editor.base_database_gui import DragDropCollectionModel

from app.data.database import difficulty_modes
from app.utilities import str_utils

class DifficultyModeModel(DragDropCollectionModel):
    def data(self, index, role):
        if not index.isValid():
            return None
        if role == Qt.DisplayRole:
            difficulty_mode = self._data[index.row()]
            text = difficulty_mode.nid
            return text
        return None

    def create_new(self):
        nids = [d.nid for d in self._data]
        nid = name = str_utils.get_next_name("New Difficulty Mode", nids)
        new_difficulty_mode = difficulty_modes.DifficultyModePrefab(nid, name, 'green')
        new_difficulty_mode.init_bases(DB)
        new_difficulty_mode.init_growths(DB)
        DB.difficulty_modes.append(new_difficulty_mode)
        return new_difficulty_mode

    def delete(self, idx):
        super().delete(idx)

    def on_nid_changed(self, old_nid, new_nid):
        pass
