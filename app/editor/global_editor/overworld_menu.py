from PyQt5.QtWidgets import QWidget, QGridLayout, QPushButton
from PyQt5.QtCore import Qt, QSize
from PyQt5.QtGui import QPixmap, QIcon

from app.editor.lib.state_editor.state_enums import MainEditorScreenStates

from app.data.resources.resources import RESOURCES
from app.data.database.database import DB
from app.data.database.overworld import OverworldPrefab

from app.extensions.custom_gui import RightClickListView
from app.editor.base_database_gui import DragDropCollectionModel
import app.editor.tilemap_editor as tilemap_editor
from app.utilities import str_utils


class OverworldDatabase(QWidget):
    def __init__(self, state_manager):
        super().__init__()
        self.state_manager = state_manager

        self.grid = QGridLayout()
        self.setLayout(self.grid)

        def deletion_func(model, index):
            return model.rowCount() > 1

        self.view = RightClickListView((deletion_func, None, None), self)
        self.view.setMinimumSize(128, 320)
        self.view.setIconSize(QSize(64, 64))
        self.view.currentChanged = self.on_map_changed
        self.view.doubleClicked.connect(self.on_double_click)

        self.model = OverworldModel(DB.overworlds, self)
        self.view.setModel(self.model)

        self.model.drag_drop_finished.connect(self.catch_drag)

        self.button = QPushButton("Create New Overworld...")
        self.button.clicked.connect(self.model.append)

        self.grid.addWidget(self.view, 0, 0)
        self.grid.addWidget(self.button, 1, 0)

        self.state_manager.subscribe_to_key(
            OverworldDatabase.__name__, 'ui_refresh_signal', self.update_view)

    def on_map_changed(self, curr, prev):
        if DB.overworlds:
            new_overworld = DB.overworlds[curr.row()]
            self.state_manager.change_and_broadcast(
                'selected_overworld', new_overworld.nid)

    def catch_drag(self):
        if DB.overworlds:
            index = self.view.currentIndex()
            new_overworld = DB.overworlds[index.row()]
            self.state_manager.change_and_broadcast(
                'selected_overworld', new_overworld.nid)

    def on_double_click(self, index):
        if DB.overworlds:
            selected_overworld = DB.overworlds[index.row()]
            self.state_manager.change_and_broadcast(
                'selected_overworld', selected_overworld.nid)
            self.state_manager.change_and_broadcast(
                'main_editor_mode', MainEditorScreenStates.OVERWORLD_EDITOR)

    def create_initial_overworld(self):
        nids = [m.nid for m in DB.overworlds]
        nid = str(str_utils.get_next_int("0", nids))
        DB.overworlds.append(OverworldPrefab(nid, 'Overworld'))
        self.model.dataChanged.emit(self.model.index(
            0), self.model.index(self.model.rowCount()))
        first_index = self.model.index(0)
        self.view.setCurrentIndex(first_index)

    def update_view(self, _=None):
        self.model.layoutChanged.emit()

class OverworldModel(DragDropCollectionModel):
    def data(self, index, role):
        if not index.isValid():
            return None
        if role == Qt.DisplayRole:
            overworld = self._data[index.row()]
            text = overworld.nid + " : " + overworld.name
            return text
        elif role == Qt.DecorationRole:
            overworld = self._data[index.row()]
            res = RESOURCES.tilemaps.get(overworld.tilemap)
            if res:
                image = tilemap_editor.draw_tilemap(res)
                img = QIcon(QPixmap.fromImage(image))
                return img
        return None

    def create_new(self):
        nids = [m.nid for m in DB.overworlds]
        nid = str(str_utils.get_next_int("0", nids))
        name = "Overworld %s" % nid

        # Create new overworld
        new_overworld = OverworldPrefab(nid, name)
        DB.overworlds.append(new_overworld)
        return new_overworld
