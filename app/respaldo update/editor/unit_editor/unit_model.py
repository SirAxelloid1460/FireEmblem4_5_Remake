from PyQt5.QtGui import QPixmap, QIcon
from PyQt5.QtCore import Qt

from app.data.resources.resources import RESOURCES
from app.utilities.data import Data
from app.data.database.database import DB
from app.data.database import units
from app.data.database.level_units import UniqueUnit

from app.extensions.custom_gui import DeletionDialog

from app.editor.base_database_gui import DragDropCollectionModel
import app.editor.utilities as editor_utilities
from app.utilities import str_utils

from app.constants import EDITION

def get_chibi(unit):
    res = RESOURCES.portraits.get(unit.portrait_nid)
    if not res:
        return None
    if not res.pixmap:
        res.pixmap = QPixmap(res.full_path)
    if EDITION == 'Axelloid1460':
        pixmap = res.pixmap.copy(res.pixmap.width() - 40, 18, 32, 32)
    else:
        pixmap = res.pixmap.copy(res.pixmap.width() - 32, 16, 32, 32)
    pixmap = QPixmap.fromImage(editor_utilities.convert_colorkey(pixmap.toImage()))
    return pixmap

class UnitModel(DragDropCollectionModel):
    def data(self, index, role):
        if not index.isValid():
            return None
        if role == Qt.DisplayRole:
            unit = self._data[index.row()]
            if not unit:
                return "None"
            text = unit.nid
            return text
        elif role == Qt.DecorationRole:
            unit = self._data[index.row()]
            if not unit:
                return None
            # Get chibi image
            pixmap = get_chibi(unit)
            if pixmap:
                return QIcon(pixmap)
            else:
                return None
        return None

    def delete(self, idx):
        # check to make sure nothing else is using me!!!
        unit = self._data[idx]
        nid = unit.nid
        affected = None
        affected_ais = [ai for ai in DB.ai if ai.has_unit_spec("ID", nid)]
        affected_levels = [level for level in DB.levels if any(isinstance(unit, UniqueUnit) and unit.nid == nid for unit in level.units)]
        if affected_ais:
            affected = Data(affected_ais)
            from app.editor.ai_editor.ai_model import AIModel
            model = AIModel
        elif affected_levels:
            affected = Data(affected_levels)
            from app.editor.global_editor.level_menu import LevelModel
            model = LevelModel
        if affected:
            msg = "Deleting Unit <b>%s</b> would affect these objects" % nid
            ok = DeletionDialog.inform(affected, model, msg, self.window)
            if ok:
                self.on_delete(nid)
            else:
                return
        super().delete(idx)

    def on_delete(self, old_nid):
        new_nid = None
        for unit in DB.units:
            if unit.nid != old_nid:
                new_nid = unit.nid
                break
        for ai in DB.ai:
            ai.change_unit_spec("ID", old_nid, new_nid)
        for level in DB.levels:
            if old_nid in level.units.keys():
                level.units.remove_key(old_nid)
            for unit_group in level.unit_groups:
                unit_group.remove(old_nid)
            for unit in level.units:
                if unit.starting_traveler == old_nid:
                    unit.starting_traveler = None
        for party in DB.parties:
            if party.leader == old_nid:
                party.leader == new_nid

    def on_nid_changed(self, old_nid, new_nid):
        for ai in DB.ai:
            ai.change_unit_spec("ID", old_nid, new_nid)
        for level in DB.levels:
            for unit in level.units:
                if isinstance(unit, UniqueUnit) and unit.nid == old_nid:
                    level.units.update_nid(unit, new_nid)
            for unit_group in level.unit_groups:
                unit_group.swap(old_nid, new_nid)
            for unit in level.units:
                if old_nid and unit.starting_traveler == old_nid:
                    unit.starting_traveler = new_nid
        for party in DB.parties:
            if party.leader == old_nid:
                party.leader = new_nid

    def create_new(self):
        nids = [d.nid for d in self._data]
        nid = name = str_utils.get_next_name("New Unit", nids)
        bases = {k: 0 for k in DB.stats.keys()}
        growths = {k: 0 for k in DB.stats.keys()}
        wexp_gain = {weapon_nid: DB.weapons.default() for weapon_nid in DB.weapons.keys()}
        new_unit = units.UnitPrefab(nid, name, '', None, 1, DB.classes[0].nid, [],
                                    bases, growths, [], [], [], wexp_gain)
        new_unit.fields = []
        DB.units.append(new_unit)
        return new_unit
