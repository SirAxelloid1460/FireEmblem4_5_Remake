from PyQt5.QtWidgets import QWidget, QLineEdit, QMessageBox, QVBoxLayout
from PyQt5.QtCore import Qt

from app.data.database.database import DB

from app.extensions.custom_gui import PropertyBox
from app.editor.lib.components.validated_line_edit import NidLineEdit
from app.editor.custom_widgets import UnitBox
from app.utilities import str_utils

class PartyProperties(QWidget):
    def __init__(self, parent, current=None):
        super().__init__(parent)
        self.window = parent
        self._data = self.window._data

        self.current = current

        name_section = QVBoxLayout()

        self.nid_box = PropertyBox(_("Unique ID"), NidLineEdit, self)
        self.nid_box.edit.textChanged.connect(self.nid_changed)
        self.nid_box.edit.editingFinished.connect(self.nid_done_editing)
        name_section.addWidget(self.nid_box)

        self.name_box = PropertyBox(_("Display Name"), QLineEdit, self)

        self.name_box.edit.textChanged.connect(self.name_changed)
        name_section.addWidget(self.name_box)

        self.leader_box = UnitBox(self, title=_("Leader Unit"))
        self.leader_box.edit.activated.connect(self.leader_changed)
        name_section.addWidget(self.leader_box)

        self.setLayout(name_section)
        name_section.setAlignment(Qt.AlignTop)

    def nid_changed(self, text):
        if self.current.name == self.current.nid.replace('_', ' '):
            self.name_box.edit.setText(text.replace('_', ' '))
        self.current.nid = text
        self.window.update_list()

    def nid_done_editing(self):
        other_nids = [d.nid for d in self._data.values() if d is not self.current]
        if self.current.nid in other_nids:
            QMessageBox.warning(self.window, 'Warning', 'Party ID %s already in use' % self.current.nid)
        self.current.nid = str_utils.get_next_name(self.current.nid, other_nids)
        old_nid = self._data.find_key(self.current)
        self.window.left_frame.model.on_nid_changed(old_nid, self.current.nid)
        self._data.update_nid(self.current, self.current.nid)
        self.window.update_list()

    def name_changed(self, text):
        self.current.name = text
        self.window.update_list()

    def leader_changed(self):
        idx = self.leader_box.edit.currentIndex()
        self.current.leader = DB.units[idx].nid
        self.window.update_list()

    def set_current(self, current):
        self.current = current
        self.nid_box.edit.setText(current.nid)
        self.name_box.edit.setText(current.name)
        self.leader_box.edit.setValue(current.leader)
