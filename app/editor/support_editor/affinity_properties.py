from PyQt5.QtWidgets import QWidget, QLineEdit, QTextEdit, \
    QMessageBox, QDoubleSpinBox, QStyledItemDelegate, QVBoxLayout, QHBoxLayout, \
    QSpacerItem, QSizePolicy
from PyQt5.QtGui import QFontMetrics

from app.utilities import str_utils
from app.data.database.database import DB
from app.data.database.supports import SupportRankBonusList

from app.extensions.custom_gui import ComboBox, PropertyBox
from app.extensions.list_widgets import AppendMultiListWidget
from app.editor.lib.components.validated_line_edit import NidLineEdit

from app.editor.icons import ItemIcon16

class AffinityProperties(QWidget):
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

        self.nid_box = PropertyBox("Unique ID", NidLineEdit, self)
        self.nid_box.edit.textChanged.connect(self.nid_changed)
        self.nid_box.edit.editingFinished.connect(self.nid_done_editing)
        name_section.addWidget(self.nid_box)

        self.name_box = PropertyBox("Display Name", QLineEdit, self)

        self.name_box.edit.textChanged.connect(self.name_changed)
        name_section.addWidget(self.name_box)

        top_section.addLayout(name_section)

        self.desc_box = PropertyBox("Description", QTextEdit, self)
        font_height = QFontMetrics(self.desc_box.edit.font())
        self.desc_box.edit.setFixedHeight(font_height.lineSpacing() * 2 + 20)
        self.desc_box.edit.textChanged.connect(self.desc_changed)

        attrs = ('support_rank', 'damage', 'resist', 'accuracy', 'avoid', 'crit', 'dodge', 'attack_speed', 'defense_speed')
        self.rank_bonus = AppendMultiListWidget(SupportRankBonusList(), "Rank Bonus", attrs, SupportRankBonusDelegate, self)

        total_section = QVBoxLayout()
        self.setLayout(total_section)
        total_section.addLayout(top_section)
        total_section.addWidget(self.desc_box)
        total_section.addWidget(self.rank_bonus)

    def nid_changed(self, text):
        # Can't change None
        if self.current.nid == 'None': 
            self.nid_box.edit.setText('None')
            return
        # Also change name if they are identical
        if self.current.name == self.current.nid.replace('_', ' '):
            self.name_box.edit.setText(text.replace('_', ' '))
        self.current.nid = text
        self.window.update_list()

    def nid_done_editing(self):
        # Check validity of nid!
        other_nids = [d.nid for d in self._data.values() if d is not self.current]
        if self.current.nid in other_nids:
            QMessageBox.warning(self.window, 'Warning', 'Affinity ID %s already in use' % self.current.nid)
            self.current.nid = str_utils.get_next_name(self.current.nid, other_nids)
        old_nid = self._data.find_key(self.current)
        self.window.left_frame.model.on_nid_changed(old_nid, self.current.nid)
        self._data.update_nid(self.current, self.current.nid)
        self.window.update_list()

    def name_changed(self, text):
        self.current.name = text
        self.window.update_list()

    def desc_changed(self, text=None):
        self.current.desc = self.desc_box.edit.toPlainText()

    def set_current(self, current):
        self.current = current
        self.nid_box.edit.setText(current.nid)
        self.name_box.edit.setText(current.name)
        self.desc_box.edit.setText(current.desc)
        self.rank_bonus.set_current(current.bonus)
        self.icon_edit.set_current(current.icon_nid, current.icon_index)
        if current.nid == 'None':
            self.nid_box.setEnabled(False)
        else:
            self.nid_box.setEnabled(True)


class SupportRankBonusDelegate(QStyledItemDelegate):
    rank_column = 0
    float_columns = (1, 2, 3, 4, 5, 6, 7, 8)

    def createEditor(self, parent, option, index):
        if index.column() in self.float_columns:
            editor = QDoubleSpinBox(parent)
            editor.setRange(-255, 255)
            return editor
        elif index.column() == self.rank_column:
            editor = ComboBox(parent)
            for rank in DB.support_ranks:
                editor.addItem(rank.nid)
            return editor
        else:
            return super().createEditor(parent, option, index)
