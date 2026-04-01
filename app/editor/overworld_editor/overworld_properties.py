from app.editor.lib.components.validated_line_edit import NidLineEdit
from app.data.database.database import DB
from app.editor.sound_editor import sound_tab
from app.editor.tile_editor import tile_tab
from app.extensions.custom_gui import (ComboBox, PropertyBox, PropertyCheckBox,
                                       QHLine, SimpleDialog)
from app.data.resources.resources import RESOURCES
from app.utilities import str_utils
from PyQt5.QtCore import QEvent, Qt
from PyQt5.QtWidgets import (QComboBox, QLabel, QLineEdit, QMessageBox,
                             QPushButton, QVBoxLayout, QWidget)


class OverworldPropertiesMenu(QWidget):
    def __init__(self, state_manager):
        super().__init__()
        self.state_manager = state_manager

        self._initialize_components()

        # widget state
        self.set_current(self.state_manager.state.selected_overworld)

        # subscriptions
        self.state_manager.subscribe_to_key(OverworldPropertiesMenu.__name__, 'selected_overworld', self.set_current)

    def set_current(self, overworld_nid):
        self.current = DB.overworlds.get(overworld_nid)
        current = self.current
        if not self.current:
            return
        self.nid_box.edit.setText(overworld_nid)
        self.title_box.edit.setText(current.name)
        self.music_box.edit.setText(current.music)
        self.border_width_box.edit.setText(str(current.border_tile_width))

    def _initialize_components(self):
        self.setStyleSheet("font: 10pt;")

        form = QVBoxLayout(self)
        form.setAlignment(Qt.AlignTop)

        self.nid_box = PropertyBox("Overworld ID", NidLineEdit, self)
        self.nid_box.edit.textChanged.connect(self.nid_changed)
        self.nid_box.edit.editingFinished.connect(self.nid_done_editing)
        form.addWidget(self.nid_box)

        self.title_box = PropertyBox("World Name", QLineEdit, self)
        self.title_box.edit.textChanged.connect(self.title_changed)
        form.addWidget(self.title_box)

        self.music_box = PropertyBox("Overworld Theme", QLineEdit, self)
        self.music_box.edit.setReadOnly(True)
        self.music_box.add_button(QPushButton('...'))
        self.music_box.button.setMaximumWidth(40)
        self.music_box.button.clicked.connect(self.access_music_resources)
        form.addWidget(self.music_box)

        form.addWidget(QHLine())

        self.map_box = QPushButton("Select Tilemap...")
        self.map_box.clicked.connect(self.select_tilemap)
        form.addWidget(self.map_box)

        self.border_width_box = PropertyBox("Border Width", QLineEdit, self)
        self.border_width_box.edit.textChanged.connect(self.width_changed)
        form.addWidget(self.border_width_box)

    def access_music_resources(self):
        res, ok = sound_tab.get_music()
        if ok and res and len(res) > 0:
            nid = res[0].nid
            self.current.music = nid
            self.music_box.edit.setText(nid)

    def nid_changed(self, text):
        self.current.nid = text
        self.state_manager.change_and_broadcast('ui_refresh_signal', None)

    def nid_done_editing(self):
        other_nids = [
            overworld.nid for overworld in DB.overworlds if overworld is not self.current]
        if self.current.nid in other_nids:
            QMessageBox.warning(
                self, 'Warning', 'Level ID %s already in use' % self.current.nid)
            self.current.nid = str_utils.get_next_int(
                self.current.nid, other_nids)
        DB.overworlds.update_nid(self.current, self.current.nid)
        self.state_manager.change_and_broadcast('ui_refresh_signal', None)

    def title_changed(self, text):
        self.current.name = text
        self.state_manager.change_and_broadcast('ui_refresh_signal', None)

    def width_changed(self, text):
        try:
            converted = int(text)
        except:
            return
        self.current.border_tile_width = converted
        self.state_manager.change_and_broadcast('ui_refresh_signal', None)

    def select_tilemap(self):
        res, ok = tile_tab.get_tilemaps()
        if ok:
            nid = res.nid
            self.current.tilemap = nid
            self.state_manager.change_and_broadcast('ui_refresh_signal', None)
