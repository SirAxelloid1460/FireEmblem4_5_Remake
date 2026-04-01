from PyQt5 import QtGui
from PyQt5 import QtWidgets
from PyQt5.QtWidgets import QMainWindow, QAction, QDockWidget, QLabel, QFrame
from PyQt5.QtGui import QIcon
from PyQt5.QtCore import Qt


from app.data.database.database import DB

from app.editor.map_view import GlobalModeLevelMapView
from app.editor.settings import MainSettingsController

from app.editor import timer

from app.editor.lib.state_editor.state_enums import MainEditorScreenStates

from .level_menu import LevelDatabase
from .overworld_menu import OverworldDatabase


class GlobalEditor(QMainWindow):
    def __init__(self, app_state_manager):
        super().__init__()
        self.rendered = False
        self.app_state_manager = app_state_manager
        self.settings = MainSettingsController()
        self.app_state_manager.subscribe_to_key(
            GlobalEditor.__name__, 'selected_level', self.set_current_level)
        self.app_state_manager.subscribe_to_key(
            GlobalEditor.__name__, 'selected_overworld', self.set_current_overworld)

        self._render()

        # create actions
        self.create_actions()
        self.set_icons()

        timer.get_timer().tick_elapsed.connect(self.map_view.update_view)
        QtWidgets.qApp.focusChanged.connect(self.update_overworld_widget)

    def update_overworld_widget(self):
        should_be_visible = DB.constants.value('overworld')
        if should_be_visible:
            self.overworld_dock.show()
        else:
            self.overworld_dock.hide()

    def create_left_dock(self):
        self.create_level_dock()
        self.create_overworld_dock()
        self.addDockWidget(Qt.LeftDockWidgetArea, self.level_dock)
        self.addDockWidget(Qt.LeftDockWidgetArea, self.overworld_dock)
        self.tabifyDockWidget(self.level_dock, self.overworld_dock)
        self.level_dock.raise_()

    def create_overworld_dock(self):
        print("Create Overworld Dock")
        self.overworld_dock = QDockWidget("Overworlds", self)
        self.overworld_menu = OverworldDatabase(self.app_state_manager)
        self.overworld_dock.setAllowedAreas(Qt.LeftDockWidgetArea)
        self.overworld_dock.setWidget(self.overworld_menu)
        self.overworld_dock.setFeatures(QDockWidget.NoDockWidgetFeatures)

    def create_level_dock(self):
        print("Create Level Dock")
        self.level_dock = QDockWidget("Levels", self)
        self.level_menu = LevelDatabase(self.app_state_manager)
        self.level_dock.setAllowedAreas(Qt.LeftDockWidgetArea)
        self.level_dock.setWidget(self.level_menu)
        self.level_dock.setFeatures(QDockWidget.NoDockWidgetFeatures)

    def create_statusbar(self):
        self.status_bar = self.statusBar()
        self.position_bar = QLabel("", self)
        self.position_bar.setFrameStyle(QFrame.Panel | QFrame.Sunken)
        self.position_bar.setMinimumWidth(100)
        self.status_bar.addPermanentWidget(self.position_bar)

    def set_position_bar(self, pos):
        if pos:
            self.position_bar.setText("Position (%d, %d)" % (pos[0], pos[1]))
        else:
            self.position_bar.setText("")

    def set_message(self, msg):
        if msg:
            self.status_bar.showMessage(msg)
        else:
            self.status_bar.clearMessage()

    def set_current_level(self, level_nid):
        level = DB.levels.get(level_nid)
        self.current_level = level
        self.map_view.set_current_level(level)

    def set_current_overworld(self, overworld_nid):
        overworld = DB.overworlds.get(overworld_nid)
        self.current_level = overworld
        self.map_view.set_current_level(overworld, overworld=True)

    def create_actions(self):
        # menu actions
        self.zoom_in_act = QAction(
            "Zoom in", self, shortcut="Ctrl++", triggered=self.map_view.zoom_in)
        self.zoom_out_act = QAction(
            "Zoom out", self, shortcut="Ctrl+-", triggered=self.map_view.zoom_out)

        # toolbar actions
        self.modify_level_act = QAction(
            "Edit Level", self, triggered=self.edit_level)

    def set_icons(self, force_theme=None):
        if force_theme is None:
            theme = self.settings.get_theme(0)
        else:
            theme = force_theme
        if theme == 0:
            icon_folder = 'icons/icons'
        else:
            icon_folder = 'icons/dark_icons'
        self.zoom_in_act.setIcon(QIcon(f'{icon_folder}/zoom_in.png'))
        self.zoom_out_act.setIcon(QIcon(f'{icon_folder}/zoom_out.png'))
        self.modify_level_act.setIcon(QIcon(f'{icon_folder}/map.png'))

    def overworld_mode(self) -> bool:
        return not self.overworld_dock.visibleRegion().isEmpty()

    def create_toolbar(self, toolbar):
        toolbar.addAction(self.modify_level_act, 0)

    def create_menus(self, app_menu_bar):
        edit_menu = app_menu_bar.getMenu(_('Edit'))
        edit_menu.addSeparator()
        edit_menu.addAction(self.zoom_in_act)
        edit_menu.addAction(self.zoom_out_act)

    def edit_level(self):
        if self.overworld_mode():
            self.app_state_manager.change_and_broadcast('main_editor_mode', MainEditorScreenStates.OVERWORLD_EDITOR)
        else:
            self.app_state_manager.change_and_broadcast('main_editor_mode', MainEditorScreenStates.LEVEL_EDITOR)

    def _render(self):
        self.map_view = GlobalModeLevelMapView(self)
        self.setCentralWidget(self.map_view)

        self.create_left_dock()
        self.create_statusbar()


# Testing
# run "python -m app.editor.global_editor.global_editor" from main directory
if __name__ == '__main__':
    import sys
    from PyQt5.QtWidgets import QApplication
    from app.data.resources.resources import RESOURCES
    from app.editor.lib.state_editor.editor_state_manager import EditorStateManager
    app = QApplication(sys.argv)
    RESOURCES.load('default.ltproj')
    DB.load('default.ltproj')
    window = GlobalEditor(EditorStateManager())
    window.show()
    app.exec_()
