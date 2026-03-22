from PyQt5.QtGui import QPixmap, QIcon
from PyQt5.QtCore import Qt

from app.utilities.data import Data
from app.data.resources.resources import RESOURCES
from app.data.database.database import DB
from app.data.database import supports

from app.editor.custom_widgets import AffinityBox
from app.extensions.custom_gui import DeletionDialog
from app.editor.base_database_gui import DragDropCollectionModel

from app.utilities import str_utils
import app.editor.utilities as editor_utilities

def get_pixmap(affinity):
    x, y = affinity.icon_index
    res = RESOURCES.icons16.get(affinity.icon_nid)
    if not res:
        return None
    if not res.pixmap:
        res.pixmap = QPixmap(res.full_path)
    pixmap = res.pixmap.copy(x*16, y*16, 16, 16)
    pixmap = QPixmap.fromImage(editor_utilities.convert_colorkey(pixmap.toImage()))
    return pixmap

class AffinityModel(DragDropCollectionModel):
    def data(self, index, role):
        if not index.isValid():
            return None
        if role == Qt.DisplayRole:
            affinity = self._data[index.row()]
            text = affinity.nid
            return text
        elif role == Qt.DecorationRole:
            affinity = self._data[index.row()]
            pixmap = get_pixmap(affinity)
            if pixmap:
                return QIcon(pixmap)
        return None

    def delete(self, idx):
        # Check to make sure nothing else is using me!!!
        affinity = self._data[idx]
        nid = affinity.nid
        affected_units = [unit for unit in DB.units if unit.affinity == nid]
        if affected_units:
            affected = Data(affected_units)
            from app.editor.unit_editor.unit_model import UnitModel
            model = UnitModel
            msg = "Deleting Affinity <b>%s</b> would affect these objects." % nid
            swap, ok = DeletionDialog.get_swap(affected, model, msg, AffinityBox(self.window, exclude=affinity), self.window)
            if ok:
                self.on_nid_changed(nid, swap.nid)
            else:
                return  # User cancelled swap
        # Delete watchers
        # None needed
        super().delete(idx)

    def on_nid_changed(self, old_value, new_value):
        old_nid, new_nid = old_value, new_value
        for unit in DB.units:
            if old_nid == unit.affinity:
                unit.affinity = new_nid

    def create_new(self):
        nids = [d.nid for d in self._data]
        nid = name = str_utils.get_next_name("New Affinity", nids)
        new_affinity = supports.Affinity(
            nid, name, '', supports.SupportRankBonusList())
        DB.affinities.append(new_affinity)
        return new_affinity
