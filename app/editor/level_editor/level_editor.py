from PyQt5.QtWidgets import QMainWindow, QAction, QMenu, QMessageBox, \
    QDockWidget, QFileDialog, QWidget, QLabel, QFrame, QDesktopWidget, \
    QToolButton, QWidgetAction, QLayout, QHBoxLayout
from PyQt5.QtGui import QIcon
from PyQt5.QtCore import Qt, QDir


from app.data.resources.resources import RESOURCES
from app.data.database.database import DB

from app.editor import timer

from app.editor.settings import MainSettingsController

from .property_menu import PropertiesMenu
from .unit_painter_menu import UnitPainterMenu
from .region_painter_menu import RegionMenu
from .unit_group_painter_menu import UnitGroupMenu

from app.editor.map_view import NewMapView, EditMode

# Application State
from app.editor.lib.state_editor.editor_state_manager import EditorStateManager
from app.editor.lib.state_editor.state_enums import MainEditorScreenStates
from app.editor.lib.components.dock import Dock


class LevelEditor(QMainWindow):
    def __init__(self, state_manager):
        super().__init__()
        self.state_manager = state_manager
        self.state_manager.subscribe_to_key(
            LevelEditor.__name__, 'selected_level', self.set_current_level)
        self.settings = MainSettingsController()
        self.rendered = False
        self._render()

        # create things
        self.create_actions()
        self.set_icons()

        timer.get_timer().tick_elapsed.connect(self.map_view.update_view)

    def on_property_tab_select(self, visible):
        if visible:
            self.map_view.set_mode(EditMode.NONE)

    def on_region_tab_select(self, visible):
        if visible:
            self.map_view.set_mode(EditMode.REGIONS)

    def on_units_tab_select(self, visible):
        if visible:
            self.map_view.set_mode(EditMode.UNITS)

    def on_group_tab_select(self, visible):
        if visible:
            self.map_view.set_mode(EditMode.GROUPS)

    def create_edit_dock(self):
        self.docks = {}

        self.docks['Properties'] = Dock(
            'Properties', self, self.on_property_tab_select)
        self.properties_menu = PropertiesMenu(self.state_manager)
        self.docks['Properties'].setWidget(self.properties_menu)
        self.docks['Regions'] = Dock(
            'Regions', self, self.on_region_tab_select)
        self.region_painter_menu = RegionMenu(
            self.state_manager, self.map_view)
        self.docks['Regions'].setWidget(self.region_painter_menu)
        self.docks['Units'] = Dock('Units', self, self.on_units_tab_select)
        self.unit_painter_menu = UnitPainterMenu(
            self.state_manager, self.map_view)
        self.docks['Units'].setWidget(self.unit_painter_menu)
        self.docks['Groups'] = Dock('Groups', self, self.on_group_tab_select)
        self.group_painter_menu = UnitGroupMenu(self.state_manager)
        self.docks['Groups'].setWidget(self.group_painter_menu)

        for title, dock in self.docks.items():
            dock.setAllowedAreas(Qt.RightDockWidgetArea)
            dock.setFeatures(QDockWidget.NoDockWidgetFeatures)
            self.addDockWidget(Qt.RightDockWidgetArea, dock)

        self.tabifyDockWidget(self.docks['Properties'], self.docks['Regions'])
        self.tabifyDockWidget(self.docks['Regions'], self.docks['Units'])
        self.tabifyDockWidget(self.docks['Units'], self.docks['Groups'])

        for title, dock in self.docks.items():
            dock.show()

        self.docks['Properties'].raise_()
        self.map_view.set_mode(EditMode.NONE)

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
        self.update_view()

    def update_view(self):
        if self.rendered:  # (see _render() below)
            self.map_view.update_view()

    def create_actions(self):
        # menu actions
        self.zoom_in_act = QAction(
            "Zoom in", self, shortcut="Ctrl++", triggered=self.map_view.zoom_in)
        self.zoom_out_act = QAction(
            "Zoom out", self, shortcut="Ctrl+-", triggered=self.map_view.zoom_out)

        # toolbar actions
        self.back_to_main_act = QAction(
            "Back", self, shortcut="E", triggered=self.edit_global)

    def set_icons(self):
        theme = self.settings.get_theme(0)
        if theme == 0:
            icon_folder = 'icons/icons'
        else:
            icon_folder = 'icons/dark_icons'
        self.back_to_main_act.setIcon(QIcon(f'{icon_folder}/left_arrow.png'))

    def create_toolbar(self, toolbar):
        toolbar.addAction(self.back_to_main_act, 0)

    def create_menus(self, app_menu_bar):
        edit_menu = app_menu_bar.getMenu('Edit')
        edit_menu.addSeparator()
        edit_menu.addAction(self.zoom_in_act)
        edit_menu.addAction(self.zoom_out_act)

    def edit_global(self):
        self.state_manager.change_and_broadcast('main_editor_mode', MainEditorScreenStates.GLOBAL_EDITOR)

    def _render(self):
        self.map_view = NewMapView(self)
        self.setCentralWidget(self.map_view)

        self.create_edit_dock()
        self.create_statusbar()

        self.map_view.update_view()
        # needed to prevent some race conditions in initializing different components
        self.rendered = True


# Testing
# run "python -m app.editor.level_editor.level_editor" from main directory
if __name__ == '__main__':
    import sys
    from PyQt5.QtWidgets import QApplication
    app = QApplication(sys.argv)
    RESOURCES.load('default.ltproj')
    DB.load('default.ltproj')
    state_manager = EditorStateManager()
    state_manager.state.selected_level = 0
    window = LevelEditor(state_manager)
    window.state_manager.change_and_broadcast('selected_level', '0')
    window.show()
    app.exec_()
