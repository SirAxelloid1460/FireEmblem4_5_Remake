from PyQt5.QtWidgets import QWidget, QLineEdit, QCheckBox, QMessageBox, \
    QSpinBox, QStyledItemDelegate, QVBoxLayout, QHBoxLayout, QDoubleSpinBox

from app.data.database.database import DB
from app.data.database.supports import SupportRankRequirementList

from app.extensions.custom_gui import ComboBox, PropertyCheckBox
from app.editor.custom_widgets import UnitBox
from app.extensions.list_widgets import AppendMultiListWidget

class SupportPairProperties(QWidget):
    def __init__(self, parent, current=None):
        super().__init__(parent)
        self.window = parent
        self._data = self.window._data

        self.current = current

        unit_section = QHBoxLayout()
        self.unit1_box = UnitBox(self)
        self.unit1_box.edit.currentIndexChanged.connect(self.unit1_changed)
        unit_section.addWidget(self.unit1_box)
        self.unit2_box = UnitBox(self)
        self.unit2_box.edit.currentIndexChanged.connect(self.unit2_changed)
        unit_section.addWidget(self.unit2_box)

        main_layout = QVBoxLayout()
        main_layout.addLayout(unit_section)

        self.one_way_box = PropertyCheckBox("One way?", QCheckBox, self)
        self.one_way_box.setToolTip("Second unit gives bonuses to first unit")
        self.one_way_box.edit.stateChanged.connect(self.one_way_changed)
        main_layout.addWidget(self.one_way_box)

        attrs = ('support_rank', 'requirement', 'gate', 'damage', 'resist', 'accuracy', 'avoid', 'crit', 'dodge', 'attack_speed', 'defense_speed')
        self.rank_bonus = AppendMultiListWidget(
            SupportRankRequirementList(), "Rank Requirements & Personal Bonuses",
            attrs, SupportRankRequirementDelegate, self)
        main_layout.addWidget(self.rank_bonus)
        self.setLayout(main_layout)

    def unit1_changed(self, index):
        old_unit1 = self.current.unit1
        self.current.unit1 = self.unit1_box.edit.currentText()
        other_nids = [d.nid for d in self._data.values() if d is not self.current]
        if self.current.nid in other_nids:
            QMessageBox.warning(self.window, 'Warning', 'Pair %s already in use. Support Pairs must be unique!' % self.current.nid)
            self.current.unit1 = old_unit1
            self.unit1_box.edit.setValue(self.current.unit1)
        self._data.update_nid(self.current, self.current.nid, set_nid=False)
        self.window.update_list()

    def unit2_changed(self, index):
        old_unit2 = self.current.unit2
        self.current.unit2 = self.unit2_box.edit.currentText()
        other_nids = [d.nid for d in self._data.values() if d is not self.current]
        if self.current.nid in other_nids:
            QMessageBox.warning(self.window, 'Warning', 'Pair %s already in use. Support Pairs must be unique!' % self.current.nid)
            self.current.unit2 = old_unit2
            self.unit2_box.edit.setValue(self.current.unit2)
        self._data.update_nid(self.current, self.current.nid, set_nid=False)
        self.window.update_list()

    def one_way_changed(self, state):
        self.current.one_way = bool(state)

    def set_current(self, current):
        self.current = current
        self.unit1_box.edit.setValue(current.unit1)
        self.unit2_box.edit.setValue(current.unit2)
        self.one_way_box.edit.setChecked(bool(current.one_way))
        self.rank_bonus.set_current(current.requirements)

class SupportRankRequirementDelegate(QStyledItemDelegate):
    rank_column = 0
    requirement_column = 1
    str_column = 2
    float_columns = (3, 4, 5, 6, 7, 8, 9, 10)

    def createEditor(self, parent, option, index):
        if index.column() in self.float_columns:
            editor = QDoubleSpinBox(parent)
            editor.setRange(-65535, 65535)
            return editor
        elif index.column() == self.requirement_column:
            editor = QSpinBox(parent)
            editor.setRange(0, 65535)  # No negative rank unlocks allowed
            return editor
        elif index.column() == self.str_column:
            editor = QLineEdit(parent)
            return editor
        elif index.column() == self.rank_column:
            editor = ComboBox(parent)
            for rank in DB.support_ranks:
                editor.addItem(rank.nid)
            return editor
        else:
            return super().createEditor(parent, option, index)
