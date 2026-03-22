from PyQt5.QtCore import Qt
from PyQt5.QtGui import QIcon, QPixmap

from app.utilities.data import Data
from app.data.resources.resources import RESOURCES
from app.data.database.database import DB
from app.data.database import items

from app.extensions.custom_gui import DeletionDialog
from app.editor.base_database_gui import DragDropCollectionModel
from app.editor.custom_widgets import ItemBox

from app.utilities import str_utils
import app.editor.utilities as editor_utilities

def get_pixmap(item):
    x, y = item.icon_index
    res = RESOURCES.icons16.get(item.icon_nid)
    if not res:
        return None
    if not res.pixmap:
        res.pixmap = QPixmap(res.full_path)
    pixmap = res.pixmap.copy(x*16, y*16, 16, 16)
    pixmap = QPixmap.fromImage(editor_utilities.convert_colorkey(pixmap.toImage()))
    return pixmap

class ItemModel(DragDropCollectionModel):
    def data(self, index, role):
        if not index.isValid():
            return None
        if role == Qt.DisplayRole:
            item = self._data[index.row()]
            text = item.nid
            return text
        elif role == Qt.DecorationRole:
            item = self._data[index.row()]
            pix = get_pixmap(item)
            if pix:
                pix = pix.scaled(32, 32)
                return QIcon(pix)
        return None

    def delete(self, idx):
        # Check to make sure nothing else is using me!!!
        item = self._data[idx]
        if len(self._data) > 1:  # So we have something to swap to
            nid = item.nid
            affected_units = [unit for unit in DB.units if nid in unit.get_items()]
            affected_levels = [level for level in DB.levels if any(nid in unit.get_items() for unit in level.units)]
            if affected_units or affected_levels:
                if affected_units:
                    affected = Data(affected_units)
                    from app.editor.unit_editor.unit_model import UnitModel
                    model = UnitModel
                elif affected_levels:
                    affected = Data(affected_levels)
                    from app.editor.global_editor.level_menu import LevelModel
                    model = LevelModel
                msg = "Deleting Item <b>%s</b> would affect these objects." % nid
                swap, ok = DeletionDialog.get_swap(affected, model, msg, ItemBox(self.window, exclude=item), self.window)
                if ok:
                    self.on_nid_changed(nid, swap.nid)
                else:
                    return
        # Delete watchers
        super().delete(idx)

    def on_nid_changed(self, old_nid, new_nid):
        for unit in DB.units:
            unit.replace_item_nid(old_nid, new_nid)
        for level in DB.levels:
            for unit in level.units:
                unit.replace_item_nid(old_nid, new_nid)

    def create_new(self):
        nids = [d.nid for d in self._data]
        nid = name = str_utils.get_next_name("New Item", nids)
        new_item = items.ItemPrefab(nid, name, '')
        DB.items.append(new_item)
        return new_item
