from PyQt5.QtWidgets import QWidget, QLineEdit, QMessageBox, QHBoxLayout, QVBoxLayout, \
    QSpacerItem, QSizePolicy, QTextEdit
from PyQt5.QtCore import Qt
from PyQt5.QtGui import QFontMetrics

from app.extensions.custom_gui import PropertyBox

from app.editor.icons import ItemIcon32
from app.editor.lib.components.validated_line_edit import NidLineEdit
from app.utilities import str_utils

class FactionProperties(QWidget):
    def __init__(self, parent, current=None):
        super().__init__(parent)
        self.window = parent
        self._data = self.window._data

        self.current = current

        top_section = QHBoxLayout()

        self.icon_edit = ItemIcon32(self)
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
        self.desc_box.edit.setFixedHeight(font_height.lineSpacing() * 3 + 20)
        self.desc_box.edit.textChanged.connect(self.desc_changed)

        total_section = QVBoxLayout()
        self.setLayout(total_section)
        total_section.addLayout(top_section)
        total_section.addWidget(self.desc_box)

        total_section.setAlignment(Qt.AlignTop)

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
            QMessageBox.warning(self.window, 'Warning', 'Faction ID %s already in use' % self.current.nid)
            self.current.nid = str_utils.get_next_name(self.current.nid, other_nids)
        self.window.left_frame.model.on_nid_changed(self._data.find_key(self.current), self.current.nid)
        self._data.update_nid(self.current, self.current.nid)
        self.window.update_list()

    def name_changed(self, text):
        self.current.name = text
        self.window.update_list()

    def desc_changed(self, text=None):
        self.current.desc = self.desc_box.edit.toPlainText()
        # self.current.desc = text

    def set_current(self, current):
        self.current = current
        self.nid_box.edit.setText(current.nid)
        self.name_box.edit.setText(current.name)
        self.desc_box.edit.setText(current.desc)
        self.icon_edit.set_current(current.icon_nid, current.icon_index)
