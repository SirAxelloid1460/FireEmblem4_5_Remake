from PyQt5.QtGui import QPixmap, QIcon
from PyQt5.QtCore import Qt

from app.utilities.data import Data
from app.data.resources.resources import RESOURCES
from app.data.database.database import DB
from app.data.database import weapons, components, item_components

from app.editor.custom_widgets import WeaponTypeBox
from app.extensions.custom_gui import DeletionDialog
from app.editor.base_database_gui import DragDropCollectionModel

from app.utilities import str_utils
import app.editor.utilities as editor_utilities

def get_pixmap(weapon):
    x, y = weapon.icon_index
    res = RESOURCES.icons16.get(weapon.icon_nid)
    if not res:
        return None
    if not res.pixmap:
        res.pixmap = QPixmap(res.full_path)
    pixmap = res.pixmap.copy(x*16, y*16, 16, 16)
    pixmap = QPixmap.fromImage(editor_utilities.convert_colorkey(pixmap.toImage()))
    return pixmap

class WeaponModel(DragDropCollectionModel):
    def data(self, index, role):
        if not index.isValid():
            return None
        if role == Qt.DisplayRole:
            weapon = self._data[index.row()]
            text = weapon.nid + " : " + weapon.name
            return text
        elif role == Qt.DecorationRole:
            weapon = self._data[index.row()]
            pixmap = get_pixmap(weapon)
            if pixmap:
                return QIcon(pixmap)
        return None

    def delete(self, idx):
        # Check to make sure nothing else is using me!!!
        weapon_type = self._data[idx]
        nid = weapon_type.nid
        affected_klasses = [klass for klass in DB.classes if klass.wexp_gain.get(nid) and klass.wexp_gain.get(nid).wexp_gain > 0]
        affected_units = [unit for unit in DB.units if unit.wexp_gain.get(nid) and unit.wexp_gain.get(nid).wexp_gain > 0]
        affected_items = item_components.get_items_using(components.ComponentType.WeaponType, nid, DB)
        affected_weapons = [weapon for weapon in DB.weapons if weapon.advantage.contains(nid) or weapon.disadvantage.contains(nid)]
        if affected_klasses or affected_units or affected_items or affected_weapons:
            if affected_items:
                affected = Data(affected_items)
                from app.editor.item_editor.item_model import ItemModel
                model = ItemModel
            elif affected_klasses:
                affected = Data(affected_klasses)
                from app.editor.class_editor.class_model import ClassModel
                model = ClassModel
            elif affected_units:
                affected = Data(affected_units)
                from app.editor.unit_editor.unit_model import UnitModel
                model = UnitModel
            elif affected_weapons:
                affected = Data(affected_weapons)
                model = WeaponModel
            msg = "Deleting WeaponType <b>%s</b> would affect these objects." % nid
            swap, ok = DeletionDialog.get_swap(affected, model, msg, WeaponTypeBox(self.window, exclude=weapon_type), self.window)
            if ok:
                self.on_nid_changed(nid, swap.nid)
            else:
                return  # User cancelled swap
        # Delete watchers
        # None needed
        super().delete(idx)

    def on_nid_changed(self, old_value, new_value):
        old_nid, new_nid = old_value, new_value
        for klass in DB.classes:
            if old_nid in klass.wexp_gain:
                if klass.wexp_gain.get(new_nid):
                    klass.wexp_gain[new_nid].wexp_gain += klass.wexp_gain[old_nid].wexp_gain
                    klass.wexp_gain[new_nid].usable = bool(klass.wexp_gain[new_nid].usable) or bool(klass.wexp_gain[old_nid].usable)
                else:
                    klass.wexp_gain[new_nid] = klass.wexp_gain[old_nid]
        for unit in DB.units:
            if old_nid in unit.wexp_gain:
                if unit.wexp_gain.get(new_nid):
                    unit.wexp_gain[new_nid].wexp_gain += unit.wexp_gain[old_nid].wexp_gain
                else:
                    unit.wexp_gain[new_nid] = unit.wexp_gain[old_nid]
        for weapon in DB.weapons:
            weapon.rank_bonus.swap_type(old_nid, new_nid)
            weapon.advantage.swap_type(old_nid, new_nid)
            weapon.disadvantage.swap_type(old_nid, new_nid)
        affected_items = item_components.get_items_using(components.ComponentType.WeaponType, old_nid, DB)
        item_components.swap_values(affected_items, components.ComponentType.WeaponType, old_nid, new_nid)

    def create_new(self):
        nids = [d.nid for d in self._data]
        nid = name = str_utils.get_next_name("New Weapon Type", nids)
        new_weapon = weapons.WeaponType(
            nid, name, False, weapons.CombatBonusList(),
            weapons.CombatBonusList(), weapons.CombatBonusList())
        DB.weapons.append(new_weapon)
        return new_weapon
