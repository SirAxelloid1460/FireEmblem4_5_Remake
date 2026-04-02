from PyQt5.QtCore import Qt

from app.data.database.database import DB

from app.extensions.custom_gui import DeletionDialog
from app.editor.custom_widgets import PartyBox
from app.editor.base_database_gui import DragDropCollectionModel

from app.data.database import parties
from app.utilities import str_utils

class PartyModel(DragDropCollectionModel):
    def data(self, index, role):
        if not index.isValid():
            return None
        if role == Qt.DisplayRole:
            party = self._data[index.row()]
            text = party.nid + ": " + party.name
            return text
        return None

    def create_new(self):
        nids = [d.nid for d in self._data]
        nid = name = str_utils.get_next_name("New Party", nids)
        new_party = parties.PartyPrefab(nid, name, DB.units[0].nid)
        DB.parties.append(new_party)
        return new_party

    def delete(self, idx):
        party = self._data[idx]
        nid = party.nid
        affected_levels = [level for level in DB.levels if level.party == nid]
        if affected_levels:
            from app.editor.global_editor.level_menu import LevelModel
            model = LevelModel
            msg = "Deleting Party <b>%s</b> would affect this level" % nid
            swap, ok = DeletionDialog.get_swap(affected_levels, model, msg, PartyBox(self.window, exclude=party), self.window)
            if ok:
                self.on_nid_changed(nid, swap.nid)
            else:
                return
        super().delete(idx)

    def on_nid_changed(self, old_nid, new_nid):
        # Levels can be effected
        for level in DB.levels:
            if level.party == old_nid:
                level.party = new_nid
