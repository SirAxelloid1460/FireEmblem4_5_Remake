from PyQt5.QtWidgets import QWidget, QGridLayout, QPushButton
from PyQt5.QtCore import Qt, QSize
from PyQt5.QtGui import QIcon

from app.editor import tilemap_editor
from app.data.resources.resources import RESOURCES
from app.data.database.database import DB
from app.data.database.levels import LevelPrefab

from app.editor.lib.state_editor.state_enums import MainEditorScreenStates

from app.extensions.custom_gui import RightClickListView
from app.editor.base_database_gui import DragDropCollectionModel
from app.editor.tile_editor import tile_model
from app.utilities import str_utils


class LevelDatabase(QWidget):
    def __init__(self, state_manager):
        super().__init__()
        self.state_manager = state_manager

        self.grid = QGridLayout()
        self.setLayout(self.grid)

        def deletion_func(model, index):
            return len(DB.levels) > 1

        self.view = RightClickListView((deletion_func, None, None), self)
        self.view.setMinimumSize(128, 320)
        self.view.setIconSize(QSize(64, 64))
        # self.view.setUniformItemSizes(True)
        self.view.currentChanged = self.on_level_changed
        self.view.doubleClicked.connect(self.on_double_click)

        self.model = LevelModel(DB.levels, self)
        self.view.setModel(self.model)

        self.model.drag_drop_finished.connect(self.catch_drag)

        self.button = QPushButton("Create New Level...")
        self.button.clicked.connect(self.model.append)

        self.grid.addWidget(self.view, 0, 0)
        self.grid.addWidget(self.button, 1, 0)

        if len(DB.levels) == 0:
            self.create_initial_level()

        self.state_manager.subscribe_to_key(
            LevelDatabase.__name__, 'ui_refresh_signal', self.update_view)

    def on_level_changed(self, curr, prev):
        if DB.levels:
            new_level = DB.levels[curr.row()]
            self.state_manager.change_and_broadcast(
                'selected_level', new_level.nid)

    def catch_drag(self):
        if DB.levels:
            index = self.view.currentIndex()
            new_level = DB.levels[index.row()]
            self.state_manager.change_and_broadcast(
                'selected_level', new_level.nid)

    def on_double_click(self, index):
        if DB.levels and self.state_manager.state.main_editor_mode == MainEditorScreenStates.GLOBAL_EDITOR:
            new_level = DB.levels[index.row()]
            self.state_manager.change_and_broadcast(
                'selected_level', new_level.nid)
            self.state_manager.change_and_broadcast(
                'main_editor_mode', MainEditorScreenStates.LEVEL_EDITOR)

    def create_initial_level(self):
        nids = [level.nid for level in DB.levels]
        new_nid = str(str_utils.get_next_int("0", nids))
        DB.levels.append(LevelPrefab(new_nid, 'Prologue'))
        self.model.dataChanged.emit(self.model.index(
            0), self.model.index(self.model.rowCount()))
        first_index = self.model.index(0)
        self.view.setCurrentIndex(first_index)

    def update_view(self, _=None):
        self.model.layoutChanged.emit()
        # self.model.dataChanged.emit(self.model.index(0), self.model.index(self.model.rowCount()))


class LevelModel(DragDropCollectionModel):
    def data(self, index, role):
        if not index.isValid():
            return None
        if role == Qt.DisplayRole:
            level = self._data[index.row()]
            text = level.nid + " : " + level.name
            return text
        elif role == Qt.DecorationRole:
            level = self._data[index.row()]
            res = RESOURCES.tilemaps.get(level.tilemap)
            if res:
                pix = tilemap_editor.get_tilemap_pixmap(res)
                img = QIcon(pix)
                return img
        return None

    def create_new(self):
        nids = [level.nid for level in DB.levels]
        nid = str(str_utils.get_next_int("0", nids))
        name = "Chapter %s" % nid

        # Create new level
        new_level = LevelPrefab(nid, name)
        DB.levels.append(new_level)
        return new_level
