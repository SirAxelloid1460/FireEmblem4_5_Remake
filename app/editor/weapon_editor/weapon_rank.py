from PyQt5.QtWidgets import QItemDelegate
from PyQt5.QtCore import Qt

from app.utilities import str_utils
from app.utilities.data import Data
from app.data.database.database import DB

from app.extensions.custom_gui import ComboBox, PropertyBox, DeletionDialog
from app.extensions.list_dialogs import MultiAttrListDialog
from app.extensions.list_models import MultiAttrListModel, DefaultMultiAttrListModel

from app.data.database.weapons import WeaponRank
from app.data.database import item_components

class WeaponRankMultiModel(MultiAttrListModel):
    def delete(self, idx):
        # Check to make sure nothing else is using this rank
        element = DB.weapon_ranks[idx]
        affected_weapons = [weapon for weapon in DB.weapons if
                            any(adv.weapon_rank == element.rank for adv in weapon.rank_bonus) or
                            any(adv.weapon_rank == element.rank for adv in weapon.advantage) or
                            any(adv.weapon_rank == element.rank for adv in weapon.disadvantage)]
        affected_items = item_components.get_items_using(item_components.ComponentType.WeaponRank, element.rank, DB)
        if affected_weapons or affected_items:
            if affected_weapons:
                affected = Data(affected_weapons)
                from app.editor.weapon_editor.weapon_model import WeaponModel
                model = WeaponModel
            elif affected_items:
                affected = Data(affected_items)
                from app.editor.item_editor.item_model import ItemModel
                model = ItemModel
            msg = "Deleting WeaponRank <b>%s</b> would affect these objects." % element.rank
            combo_box = PropertyBox("Rank", ComboBox, self.window)
            objs = [rank for rank in DB.weapon_ranks if rank.rank != element.rank]
            combo_box.edit.addItems([rank.rank for rank in objs])
            obj_idx, ok = DeletionDialog.get_simple_swap(affected, model, msg, combo_box)
            if ok:
                swap = objs[obj_idx]
                item_components.swap_values(affected_items, item_components.ComponentType.WeaponRank, element.rank, swap.rank)
                for weapon in affected_weapons:
                    weapon.rank_bonus.swap_rank(element.rank, swap.rank)
                    weapon.advantage.swap_rank(element.rank, swap.rank)
                    weapon.disadvantage.swap_rank(element.rank, swap.rank)
            else:
                return
        super().delete(idx)

    def create_new(self):
        nids = DB.weapon_ranks.keys()
        nid = str_utils.get_next_name("Rank", nids)
        new_weapon_rank = WeaponRank(nid, 1)
        DB.weapon_ranks.append(new_weapon_rank)
        return new_weapon_rank

    def on_attr_changed(self, data, attr, old_value, new_value):
        if attr == 'rank':
            self._data.update_nid(data, new_value)
            for weapon in DB.weapons:
                weapon.rank_bonus.swap_rank(old_value, new_value)
                weapon.advantage.swap_rank(old_value, new_value)
                weapon.disadvantage.swap_rank(old_value, new_value)
            affected_items = item_components.get_items_using(item_components.ComponentType.WeaponRank, old_value, DB)
            item_components.swap_values(affected_items, item_components.ComponentType.WeaponRank, old_value, new_value)

class RankDialog(MultiAttrListDialog):
    @classmethod
    def create(cls):
        def deletion_func(model, index):
            return model.rowCount() > 1

        return cls(DB.weapon_ranks, "Weapon Rank",
                   ("rank", "requirement"),
                   WeaponRankMultiModel, (deletion_func, None, None))

class WexpGainDelegate(QItemDelegate):
    bool_column = 0
    weapon_type_column = 1
    int_column = 2

    def createEditor(self, parent, option, index):
        if index.column() == self.int_column:
            editor = ComboBox(parent)
            editor.setEditable(True)
            editor.addItem('0')
            for rank in DB.weapon_ranks:
                editor.addItem(rank.rank)
            return editor
        else:
            return None

class WexpGainMultiAttrModel(DefaultMultiAttrListModel):
    def rowCount(self, parent=None):
        return len(DB.weapons)

    def data(self, index, role):
        if not index.isValid():
            return None
        if index.column() in self.checked_columns:
            if role == Qt.CheckStateRole:
                weapon_key = DB.weapons.keys()[index.row()]
                data = self._data.get(weapon_key, DB.weapons.default())
                attr = self._headers[index.column()]
                val = getattr(data, attr)
                return Qt.Checked if bool(val) else Qt.Unchecked
            else:
                return None
        elif role == Qt.DisplayRole or role == Qt.EditRole:
            weapon_key = DB.weapons.keys()[index.row()]
            data = self._data.get(weapon_key, DB.weapons.default())
            attr = self._headers[index.column()]
            if attr == 'nid':
                return weapon_key
            else:
                return getattr(data, attr)
        return None

    def setData(self, index, value, role):
        if not index.isValid():
            return False
        weapon_key = DB.weapons.keys()[index.row()]
        data = self._data.get(weapon_key)
        if not data:
            self._data[weapon_key] = DB.weapons.default()
            data = self._data[weapon_key]
        attr = self._headers[index.column()]

        current_value = getattr(data, attr)
        if attr == 'wexp_gain':
            if value in DB.weapon_ranks.keys():
                value = DB.weapon_ranks.get(value).requirement
            elif str_utils.is_int(value):
                value = int(value)
            else:
                value = 0
            setattr(data, 'wexp_gain', value)
            usable = getattr(data, 'usable')
            if value > 0 and not usable:
                self.on_attr_changed(data, 'usable', usable, True)
                setattr(data, 'usable', True)
            self.on_attr_changed(data, attr, current_value, value)
            setattr(data, attr, value)
        elif attr == 'usable':
            self.on_attr_changed(data, 'usable', current_value, value)
            if value == Qt.Checked:
                setattr(data, 'usable', True)
            else:
                setattr(data, 'usable', False)
        self.dataChanged.emit(index, index)
        return True
