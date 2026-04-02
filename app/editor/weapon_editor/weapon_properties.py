from PyQt5.QtWidgets import QWidget, QLineEdit, \
    QMessageBox, QSpinBox, QStyledItemDelegate, QVBoxLayout, QHBoxLayout, \
    QSpacerItem, QSizePolicy, QCheckBox
from PyQt5.QtGui import QIcon

from app.utilities import str_utils
from app.data.database.database import DB
from app.data.database.weapons import CombatBonusList

from app.extensions.custom_gui import ComboBox, PropertyBox, PropertyCheckBox
from app.extensions.list_widgets import AppendMultiListWidget
from app.editor.lib.components.validated_line_edit import NidLineEdit

from app.editor.weapon_editor import weapon_model
from app.editor.icons import ItemIcon16

class WeaponProperties(QWidget):
    def __init__(self, parent, current=None):
        super().__init__(parent)
        self.window = parent
        self._data = self.window._data

        self.current = current

        top_section = QHBoxLayout()

        self.icon_edit = ItemIcon16(self)
        top_section.addWidget(self.icon_edit)

        horiz_spacer = QSpacerItem(40, 10, QSizePolicy.Fixed, QSizePolicy.Fixed)
        top_section.addSpacerItem(horiz_spacer)

        name_section = QVBoxLayout()

        self.nid_box = PropertyBox(_("Unique ID"), NidLineEdit, self)
        self.nid_box.edit.textChanged.connect(self.nid_changed)
        self.nid_box.edit.editingFinished.connect(self.nid_done_editing)
        name_section.addWidget(self.nid_box)

        self.name_box = PropertyBox(_("Display Name"), QLineEdit, self)

        self.name_box.edit.textChanged.connect(self.name_changed)
        name_section.addWidget(self.name_box)

        top_section.addLayout(name_section)

        self.force_melee_anim_box = PropertyCheckBox(_("Force Melee Anim"), QCheckBox, self)
        self.force_melee_anim_box.edit.stateChanged.connect(self.force_melee_anim_changed)
        self.force_melee_anim_box.setToolTip(_("Force this weapontype to use the melee animation at melee range, even with a ranged weapon. Ex. Javelins in GBA"))
        name_section.addWidget(self.force_melee_anim_box)

        attrs = ('weapon_rank', 'damage', 'resist', 'accuracy', 'avoid', 'crit', 'dodge', 'attack_speed', 'defense_speed')
        self.rank_bonus = AppendMultiListWidget(CombatBonusList(), _("Rank Bonus"), attrs, RankBonusDelegate, self)
        attrs = ('weapon_type', 'weapon_rank', 'damage', 'resist', 'accuracy', 'avoid', 'crit', 'dodge', 'attack_speed', 'defense_speed')
        self.advantage = AppendMultiListWidget(CombatBonusList(), _("Advantage versus"), attrs, CombatBonusDelegate, self)
        self.disadvantage = AppendMultiListWidget(CombatBonusList(), _("Disadvantage versus"), attrs, CombatBonusDelegate, self)

        total_section = QVBoxLayout()
        self.setLayout(total_section)
        total_section.addLayout(top_section)
        total_section.addWidget(self.rank_bonus)
        total_section.addWidget(self.advantage)
        total_section.addWidget(self.disadvantage)

    def nid_changed(self, text):
        # Also change name if they are identical
        if self.current.name == self.current.nid.replace('_', ' '):
            self.name_box.edit.setText(text.replace('_', ' '))
        self.current.nid = text
        self.window.update_list()

    def nid_done_editing(self):
        # Check validity of nid!
        other_nids = [d.nid for d in self._data.values() if d is not self.current]
        if self.current.nid in other_nids:
            QMessageBox.warning(self.window, 'Warning', 'Weapon Type ID %s already in use' % self.current.nid)
            self.current.nid = str_utils.get_next_name(self.current.nid, other_nids)
        old_nid = self._data.find_key(self.current)
        self.window.left_frame.model.on_nid_changed(old_nid, self.current.nid)
        self._data.update_nid(self.current, self.current.nid)
        self.window.update_list()

    def name_changed(self, text):
        self.current.name = text
        self.window.update_list()

    def force_melee_anim_changed(self, state):
        self.current.force_melee_anim = bool(state)

    def set_current(self, current):
        self.current = current
        self.nid_box.edit.setText(current.nid)
        self.name_box.edit.setText(current.name)
        self.force_melee_anim_box.edit.setChecked(bool(current.force_melee_anim))
        self.rank_bonus.set_current(current.rank_bonus)
        self.advantage.set_current(current.advantage)
        self.disadvantage.set_current(current.disadvantage)
        self.icon_edit.set_current(current.icon_nid, current.icon_index)

class CombatBonusDelegate(QStyledItemDelegate):
    type_column = 0
    rank_column = 1
    int_columns = (2, 3, 4, 5, 6, 7, 8, 9)

    def createEditor(self, parent, option, index):
        if index.column() in self.int_columns:
            editor = QSpinBox(parent)
            editor.setRange(-255, 255)
            return editor
        elif index.column() == self.rank_column:
            editor = ComboBox(parent)
            for rank in DB.weapon_ranks:
                editor.addItem(rank.rank)
            editor.addItem("All")
            return editor
        elif index.column() == self.type_column:
            editor = ComboBox(parent)
            for weapon_type in DB.weapons:
                x, y = weapon_type.icon_index
                pixmap = weapon_model.get_pixmap(weapon_type)
                icon = QIcon(pixmap) if pixmap else None
                editor.addItem(icon, weapon_type.nid)
            return editor
        else:
            return super().createEditor(parent, option, index)

class RankBonusDelegate(CombatBonusDelegate):
    type_column = -2
    rank_column = 0
    int_columns = (1, 2, 3, 4, 5, 6, 7, 8)
