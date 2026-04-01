import logging
import os
import sys
import functools

from PyQt5.QtWidgets import QMainWindow, QAction, QMenu, QMessageBox, \
    QDesktopWidget, \
    QToolButton, QWidgetAction, QStackedWidget
from PyQt5.QtGui import QIcon

from app import autoupdate

from app.editor.settings import MainSettingsController

from app.constants import VERSION
from app.data.database.database import DB

from app.editor import timer

# components
from app.editor.lib.components.menubar import MenuBar
from app.editor.lib.components.toolbar import Toolbar
from app.editor.preferences import PreferencesDialog
from app.editor.save_viewer import SaveViewer

# Application State
from app.editor.lib.state_editor.editor_state_manager import EditorStateManager
from app.editor.lib.state_editor.state_enums import MainEditorScreenStates

# Saving/Loading Project
from app.editor.file_manager.project_file_backend import ProjectFileBackend

# Editors
from app.editor.global_editor.global_editor import GlobalEditor
from app.editor.level_editor.level_editor import LevelEditor
from app.editor.overworld_editor.overworld_editor import OverworldEditor

# Game interface
import app.editor.game_actions.game_actions as GAME_ACTIONS

# Databases
from app.editor.unit_editor.unit_tab import UnitDatabase
from app.editor.faction_editor.faction_tab import FactionDatabase
from app.editor.party_editor.party_tab import PartyDatabase
from app.editor.class_editor.class_tab import ClassDatabase
from app.editor.weapon_editor.weapon_tab import WeaponDatabase
from app.editor.item_editor.new_item_tab import NewItemDatabase
from app.editor.skill_editor.new_skill_tab import NewSkillDatabase
from app.editor.terrain_editor.terrain_tab import TerrainDatabase
from app.editor.stat_editor.stat_tab import StatTypeDatabase
from app.editor.ai_editor.ai_tab import AIDatabase
from app.editor.difficulty_mode_editor.difficulty_mode_tab import DifficultyModeDatabase
from app.editor.constant_tab import ConstantDatabase
from app.editor.tag_widget import TagDialog
from app.editor.game_var_slot_widget import GameVarSlotDialog
from app.editor.mcost_dialog import McostDialog
from app.editor.translation_widget import TranslationDialog
from app.editor.equation_widget import EquationDialog
from app.editor.event_editor.event_tab import EventDatabase
from app.editor.lore_editor.lore_tab import LoreDatabase
from app.editor.raw_editor.raw_data_tab import RawDataDatabase

# Resources
from app.editor.icon_editor import icon_tab
from app.editor.combat_animation_editor import combat_animation_tab
from app.editor.tile_editor import tile_tab
from app.editor.sound_editor import sound_tab
from app.editor.support_editor import support_pair_tab
from app.editor.portrait_editor.portrait_tab import PortraitDatabase
from app.editor.panorama_editor.panorama_tab import PanoramaDatabase
from app.editor.map_sprite_editor.map_sprite_tab import MapSpriteDatabase

__version__ = VERSION

class MainEditor(QMainWindow):
    def initialize_state_subscriptions(self):
        self.app_state_manager.subscribe_to_key(
            MainEditor.__name__, 'main_editor_mode', self.render_editor)

    def __init__(self):
        super().__init__()
        self.window_title = _('LT Maker')
        self.setWindowTitle(self.window_title)
        self.settings = MainSettingsController()
        # Will be overwritten by auto-open
        desktop = QDesktopWidget()
        main_screen_size = desktop.availableGeometry(desktop.primaryScreen())

        # Use setFixedSize to make it permanent and unchangeable
        default_size = main_screen_size.width()*0.7, main_screen_size.height()*0.7
        self.resize(*default_size)

        geometry = self.settings.component_controller.get_geometry(
            self.__class__.__name__)
        if geometry:
            self.restoreGeometry(geometry)

        # initialize application state
        self.app_state_manager = EditorStateManager()
        self.app_state_manager.state.selected_level = '0'
        self.initialize_state_subscriptions()

        # initialize save/load handler
        self.project_save_load_handler = ProjectFileBackend(
            self,
            self.app_state_manager)

        # initialize possible editors and put them in the stack
        self.global_editor = GlobalEditor(self.app_state_manager)
        self.level_editor = LevelEditor(self.app_state_manager)
        self.overworld_editor = OverworldEditor(self.app_state_manager)
        # order is *very* important here. The first widget added will be index 0, the second is index 1, etc.
        self.editor_stack = QStackedWidget(self)
        self.editor_stack.addWidget(self.global_editor)
        self.editor_stack.addWidget(self.level_editor)
        self.editor_stack.addWidget(self.overworld_editor)
        # initialize to global editor
        self.setCentralWidget(self.editor_stack)
        self.mode = MainEditorScreenStates.GLOBAL_EDITOR
        self.current_editor = self.global_editor

        # initialize other UI elements
        self.create_actions()
        self.recreate_menus()
        # init toolbar
        self.toolbar = Toolbar(self.addToolBar(_("Edit")))
        self.create_toolbar()
        self.set_icons()
        self.create_statusbar()

        self.render_editor(MainEditorScreenStates.GLOBAL_EDITOR)

        # Actually load data
        # DB.deserialize()
        # DB.init_load()

        self.auto_open()
        # if not result:
        #     DB.load('default.ltproj')
        #     self.set_window_title('default.ltproj')

        if len(DB.levels) == 0:
            self.level_menu.create_initial_level()

        # initialize to first level
        first_level_nid = DB.levels[0].nid
        self.app_state_manager.change_and_broadcast('selected_level', first_level_nid)

    def on_clean_changed(self, clean):
        # Change Title
        if clean:
            pass
        else:
            if not self.window_title.startswith('*'):
                self.window_title = '*' + self.window_title

    def set_window_title(self, title):
        if self.window_title.startswith('*'):
            self.window_title = '*' + title + ' -- LT Maker %s' % (__version__)
        else:
            self.window_title = title + ' -- LT Maker %s' % (__version__)
        self.setWindowTitle(self.window_title)

    def set_icons(self, force_theme=None):
        if force_theme is None:
            theme = self.settings.get_theme(0)
        else:
            theme = force_theme
        if theme == 0:
            icon_folder = 'icons/icons'
        else:
            icon_folder = 'icons/dark_icons'

        self.new_act.setIcon(QIcon(f'{icon_folder}/file-plus.png'))
        self.open_act.setIcon(QIcon(f'{icon_folder}/folder.png'))
        self.save_act.setIcon(QIcon(f'{icon_folder}/save.png'))
        self.save_as_act.setIcon(QIcon(f'{icon_folder}/save.png'))
        self.quit_act.setIcon(QIcon(f'{icon_folder}/x.png'))
        self.test_current_act.setIcon(QIcon(f'{icon_folder}/play.png'))
        self.test_load_act.setIcon(QIcon(f'{icon_folder}/play.png'))
        self.test_full_act.setIcon(QIcon(f'{icon_folder}/play_all.png'))
        self.modify_events_act.setIcon(QIcon(f'{icon_folder}/event.png'))

        self.database_button.setIcon(QIcon(f'{icon_folder}/database.png'))
        self.resource_button.setIcon(QIcon(f'{icon_folder}/resource.png'))
        self.test_button.setIcon(QIcon(f'{icon_folder}/play.png'))

        self.global_editor.set_icons(force_theme)

    # === Create Menu ===
    def create_actions(self):
        self.new_act = QAction(_("&New Project..."), self,
                               shortcut="Ctrl+N", triggered=self.new)
        self.open_act = QAction(_("&Open Project..."), self,
                                shortcut="Ctrl+O", triggered=self.open)
        self.save_act = QAction(_("&Save Project"), self,
                                shortcut="Ctrl+S", triggered=self.save)
        self.save_as_act = QAction(
            _("Save Project As..."), self, shortcut="Ctrl+Shift+S", triggered=self.save_as)
        # self.build_act = QAction(QIcon(), "Build Project...", self, shortcut="Ctrl+B", triggered=self.build_project)
        self.quit_act = QAction(
            _("&Quit"), self, shortcut="Ctrl+Q", triggered=self.close)

        self.dump_csv = QAction(
            "Dump CSV data", self, triggered=lambda: self.project_save_load_handler.dump_csv(DB))
        self.dump_script = QAction(
            "Dump script", self, triggered=lambda: self.project_save_load_handler.dump_script(DB))

        self.preferences_act = QAction(
            _("&Preferences..."), self, triggered=self.edit_preferences)
        self.about_act = QAction(_("&About"), self, triggered=self.about)
        self.remove_unused_resources_act = QAction(
            _("Remove Unused Resources"), self, triggered=self.remove_unused_resources)
        self.check_for_updates_act = QAction(
            _("Check for updates..."), self, triggered=self.check_for_updates)

        # Test actions
        self.test_current_act = QAction(
            "Test Current Chapter...", self, shortcut="F5", triggered=self.test_play_current)
        self.test_current_act.setEnabled(False)
        self.test_load_act = QAction(
            "Test Current Chapter from Preload...", self, shortcut="Ctrl+F5", triggered=self.test_play_load)
        self.test_load_act.setEnabled(False)
        self.test_full_act = QAction(
            "Test Full Game...", self, triggered=self.test_play)
        # self.balance_act = QAction(
        #     "Preload Units...", self, triggered=self.edit_preload_units)

        # Database actions
        database_actions = {_("Units"): UnitDatabase.edit,
                            _("Factions"): FactionDatabase.edit,
                            _("Parties"): PartyDatabase.edit,
                            _("Classes"): ClassDatabase.edit,
                            _("Tags"): self.edit_tags,
                            _("Game Vars"): self.edit_game_vars,
                            _("Weapon Types"): WeaponDatabase.edit,
                            _("Items"): NewItemDatabase.edit,
                            _("Skills"): NewSkillDatabase.edit,
                            "AI": AIDatabase.edit,
                            _("Terrain"): TerrainDatabase.edit,
                            _("Movement Costs"): self.edit_mcost,
                            _("Stats"): StatTypeDatabase.edit,
                            _("Equations"): self.edit_equations,
                            _("Constants"): ConstantDatabase.edit,
                            _("Difficulty Modes"): DifficultyModeDatabase.edit,
                            _("Supports"): self.edit_supports,
                            _("Lore"): LoreDatabase.edit,
                            _("Raw Data"): RawDataDatabase.edit,
                            _("Translations"): self.edit_translations
                            }
        self.database_actions = {}
        for name, func in database_actions.items():
            self.database_actions[name] = QAction(
                "%s..." % name, self, triggered=functools.partial(func, self))

        resource_actions = {"Icons": self.edit_icons,
                            "Portraits": PortraitDatabase.edit,
                            # "Map Animations": AnimationDatabase.edit_resource,
                            "Backgrounds": PanoramaDatabase.edit,
                            "Map Sprites": MapSpriteDatabase.edit,
                            "Combat Animations": self.edit_combat_animations,
                            "Tilemaps": self.edit_tilemaps,
                            "Sounds": self.edit_sounds
                            }
        self.resource_actions = {}
        for name, func in resource_actions.items():
            self.resource_actions[name] = QAction(
                "%s..." % name, self, triggered=functools.partial(func, self))

        self.modify_events_act = QAction(
            "Edit Events", self, triggered=functools.partial(EventDatabase.edit, self))

    def edit_level(self):
        self.app_state_manager.change_and_broadcast(
            'main_editor_mode', MainEditorScreenStates.LEVEL_EDITOR)

    def edit_global(self):
        self.app_state_manager.change_and_broadcast(
            'main_editor_mode', MainEditorScreenStates.GLOBAL_EDITOR)

    def edit_overworld(self):
        self.app_state_manager.change_and_broadcast(
            'main_editor_mode', MainEditorScreenStates.OVERWORLD_EDITOR)

    def recreate_menus(self):
        self.menuBar().clear()
        file_menu = QMenu(_("File"), self)
        file_menu.addAction(self.new_act)
        file_menu.addAction(self.open_act)
        file_menu.addSeparator()
        file_menu.addAction(self.save_act)
        file_menu.addAction(self.save_as_act)
        file_menu.addAction(self.dump_csv)
        file_menu.addAction(self.dump_script)
        file_menu.addSeparator()
        file_menu.addAction(self.quit_act)

        edit_menu = QMenu(_("Edit"), self)
        for action in self.database_actions.values():
            edit_menu.addAction(action)
        edit_menu.addSeparator()
        for action in self.resource_actions.values():
            edit_menu.addAction(action)

        test_menu = QMenu(_("Test"), self)
        test_menu.addAction(self.test_current_act)
        test_menu.addAction(self.test_load_act)
        test_menu.addAction(self.test_full_act)

        help_menu = QMenu(_("Extra"), self)
        help_menu.addAction(self.about_act)
        help_menu.addAction(self.preferences_act)
        help_menu.addAction(self.remove_unused_resources_act)
        help_menu.addAction(self.check_for_updates_act)
        self.menubar = MenuBar(self.menuBar())
        self.menubar.addMenu(file_menu)
        self.menubar.addMenu(edit_menu)
        self.menubar.addMenu(test_menu)
        self.menubar.addMenu(help_menu)

        # allow current editor to further customize
        try:
            self.current_editor.create_menus(self.menubar)
        except AttributeError:
            pass

    def create_toolbar(self):
        self.database_button = QToolButton(self)
        self.database_button.setPopupMode(QToolButton.InstantPopup)
        database_menu = QMenu(_("Database"), self)
        for action in self.database_actions.values():
            database_menu.addAction(action)
        self.database_button.setMenu(database_menu)
        self.database_button_action = QWidgetAction(self)
        self.database_button_action.setDefaultWidget(self.database_button)

        self.resource_button = QToolButton(self)
        self.resource_button.setPopupMode(QToolButton.InstantPopup)
        resource_menu = QMenu(_("Resource"), self)
        for action in self.resource_actions.values():
            resource_menu.addAction(action)
        self.resource_button.setMenu(resource_menu)
        self.resource_button_action = QWidgetAction(self)
        self.resource_button_action.setDefaultWidget(self.resource_button)

        self.test_button = QToolButton(self)
        self.test_button.setPopupMode(QToolButton.InstantPopup)
        test_menu = QMenu(_("Test"), self)
        test_menu.addAction(self.test_current_act)
        test_menu.addAction(self.test_load_act)
        test_menu.addAction(self.test_full_act)
        self.test_button.setMenu(test_menu)
        self.test_button_action = QWidgetAction(self)
        self.test_button_action.setDefaultWidget(self.test_button)

        # self.toolbar.addToolButton(self.test_button)

    def recreate_toolbar(self):
        self.toolbar.clear()
        self.toolbar.addAction(self.database_button_action)
        self.toolbar.addAction(self.resource_button_action)
        self.toolbar.addAction(self.modify_events_act)
        self.toolbar.addAction(self.test_button_action)
        # let current editor to further customize toolbar
        try:
            self.current_editor.create_toolbar(self.toolbar)
        except AttributeError:
            pass

    def create_statusbar(self):
        self.status_bar = self.statusBar()

    def set_message(self, msg):
        if msg:
            self.status_bar.showMessage(msg)
        else:
            self.status_bar.clearMessage()

    def closeEvent(self, event):
        if self.project_save_load_handler.maybe_save():
            logging.info("Setting current project %s" %
                  self.settings.get_current_project())
            self.settings.set_current_project(
                self.settings.get_current_project())
            event.accept()
        else:
            event.ignore()
        self.settings.component_controller.set_geometry(
            self.__class__.__name__, self.saveGeometry())

    def test_play_current(self):
        self.test_current_act.setEnabled(False)
        self.test_load_act.setEnabled(False)
        self.test_full_act.setEnabled(False)
        # Make a save before playing if not on default
        if os.path.basename(self.settings.get_current_project()) != 'default.ltproj':
            self.save()
        timer.get_timer().stop()  # Don't need these while running game
        GAME_ACTIONS.test_play_current(
            self.app_state_manager.state.selected_level)
        timer.get_timer().start()
        self.test_current_act.setEnabled(True)
        self.test_load_act.setEnabled(True)
        self.test_full_act.setEnabled(True)

    def test_play(self):
        self.test_current_act.setEnabled(False)
        self.test_load_act.setEnabled(False)
        self.test_full_act.setEnabled(False)
        # Make a save before playing if not on default
        if os.path.basename(self.settings.get_current_project()) != 'default.ltproj':
            self.save()
        timer.get_timer().stop()  # Don't need these while running game
        GAME_ACTIONS.test_play()
        timer.get_timer().start()
        self.test_current_act.setEnabled(True)
        self.test_load_act.setEnabled(True)
        self.test_full_act.setEnabled(True)

    def test_play_load(self):
        saved_games = GAME_ACTIONS.get_saved_games()
        if saved_games:
            save_loc = SaveViewer.get(saved_games, self)
            if not save_loc:
                return
        else:
            save_loc = None
        self.test_current_act.setEnabled(False)
        self.test_load_act.setEnabled(False)
        self.test_full_act.setEnabled(False)
        # Make a save before playing if not on default
        if os.path.basename(self.settings.get_current_project()) != 'default.ltproj':
            self.save()
        timer.get_timer().stop()  # Don't need these while running game
        GAME_ACTIONS.test_play_load(
            self.app_state_manager.state.selected_level, save_loc)
        timer.get_timer().start()
        self.test_current_act.setEnabled(True)
        self.test_load_act.setEnabled(True)
        self.test_full_act.setEnabled(True)

    def new(self):
        if self.project_save_load_handler.new():
            # if we made a new game:
            self.set_window_title('Untitled')
            title = os.path.split(self.settings.get_current_project())[-1]
            self.set_window_title(title)

            # Return to global
            if not self.mode.GLOBAL_EDITOR:
                self.app_state_manager.change_and_broadcast(
                    'main_editor_mode', MainEditorScreenStates.GLOBAL_EDITOR)
            self.app_state_manager.change_and_broadcast(
                'selected_level', DB.levels[0].nid)  # Needed in order to update map view
            self.app_state_manager.change_and_broadcast(
                'ui_refresh_signal', None)

    def open(self):
        if self.project_save_load_handler.open():
            title = os.path.split(self.settings.get_current_project())[-1]
            self.set_window_title(title)
            logging.info("Loaded project from %s" %
                  self.settings.get_current_project())
            self.status_bar.showMessage(
                "Loaded project from %s" % self.settings.get_current_project())
            # Return to global
            if not self.mode.GLOBAL_EDITOR:
                self.app_state_manager.change_and_broadcast(
                    'main_editor_mode', MainEditorScreenStates.GLOBAL_EDITOR)
            self.app_state_manager.change_and_broadcast(
                'selected_level', DB.levels[0].nid)  # Needed in order to update map view
            self.app_state_manager.change_and_broadcast(
                'ui_refresh_signal', None)

    def auto_open(self):
        self.project_save_load_handler.auto_open()
        title = os.path.split(self.settings.get_current_project())[-1]
        self.set_window_title(title)
        logging.info("Loaded project from %s" %
              self.settings.get_current_project())
        self.status_bar.showMessage(
            "Loaded project from %s" % self.settings.get_current_project())
        # Return to global
        if not self.mode.GLOBAL_EDITOR:
            self.app_state_manager.change_and_broadcast(
                'main_editor_mode', MainEditorScreenStates.GLOBAL_EDITOR)
        self.app_state_manager.change_and_broadcast(
            'selected_level', DB.levels[0].nid)  # Needed in order to update map view
        self.app_state_manager.change_and_broadcast(
            'ui_refresh_signal', None)

    def save(self):
        if self.project_save_load_handler.save():
            current_proj = self.settings.get_current_project()
            title = os.path.split(current_proj)[-1]
            self.set_window_title(title)
            # Remove asterisk on window title
            if self.window_title.startswith('*'):
                self.window_title = self.window_title[1:]
            self.status_bar.showMessage('Saved project to %s' % current_proj)

    def save_as(self):
        if self.project_save_load_handler.save(True):
            current_proj = self.settings.get_current_project()
            title = os.path.split(current_proj)[-1]
            self.set_window_title(title)
            # Remove asterisk on window title
            if self.window_title.startswith('*'):
                self.window_title = self.window_title[1:]
            self.status_bar.showMessage('Saved project to %s' % current_proj)

    def remove_unused_resources(self):
        # Need to save first before cleaning
        if self.project_save_load_handler.save():
            self.project_save_load_handler.clean()
            current_proj = self.settings.get_current_project()
            self.status_bar.showMessage('All unused resources removed from %s' % current_proj)
        else:
            QMessageBox.warning(self, "Save Error", "Must save project before removing unused resources!")

    def edit_tags(self, parent=None):
        dialog = TagDialog.create()
        dialog.exec_()

    def edit_game_vars(self, parent=None):
        dialog = GameVarSlotDialog.create()
        dialog.exec_()

    def edit_supports(self, parent=None):
        dialog = support_pair_tab.get_full_editor()
        dialog.exec_()

    def edit_mcost(self, parent=None):
        dialog = McostDialog(self)
        dialog.exec_()

    def edit_equations(self, parent=None):
        dialog = EquationDialog.create()
        dialog.exec_()

    def edit_translations(self, parent=None):
        dialog = TranslationDialog.create()
        dialog.exec_()

    def edit_icons(self, parent=None):
        dialog = icon_tab.get_full_editor()
        dialog.exec_()

    def edit_combat_animations(self, parent=None):
        dialog = combat_animation_tab.get_full_editor()
        dialog.exec_()

    def edit_tilemaps(self, parent=None):
        dialog = tile_tab.get_full_editor()
        dialog.exec_()

    def edit_sounds(self, parent=None):
        dialog = sound_tab.get_full_editor()
        dialog.exec_()

    def edit_preferences(self):
        dialog = PreferencesDialog(self)
        dialog.exec_()

    def render_editor(self, main_editor_mode):
        self.mode = main_editor_mode
        if self.mode == MainEditorScreenStates.GLOBAL_EDITOR:
            self.current_editor = self.global_editor
            self.editor_stack.setCurrentIndex(0)
            self.test_current_act.setEnabled(True)
            self.test_load_act.setEnabled(True)
            self.recreate_menus()
            self.recreate_toolbar()
        elif self.mode == MainEditorScreenStates.LEVEL_EDITOR:
            self.current_editor = self.level_editor
            self.editor_stack.setCurrentIndex(1)
            self.test_current_act.setEnabled(True)
            self.test_load_act.setEnabled(True)
            self.recreate_menus()
            self.recreate_toolbar()
        elif(self.mode == MainEditorScreenStates.OVERWORLD_EDITOR):
            self.current_editor = self.overworld_editor
            self.editor_stack.setCurrentIndex(2)
            self.test_current_act.setEnabled(False)
            self.test_load_act.setEnabled(False)
            self.recreate_menus()
            self.recreate_toolbar()

    def about(self):
        QMessageBox.about(self, "About Lex Talionis Game Maker",
                          "<p>This is the <b>Lex Talionis</b> Game Maker.</p>"
                          "<p>Check out <a href='https://lt-maker.readthedocs.io/'>https://lt-maker.readthedocs.io/</a> "
                          "for more information and helpful tutorials.</p>"
                          "<p>This program has been freely distributed under the MIT License.</p>"
                          "<p>Copyright 2014-2023 rainlash.</p>")

    def check_for_updates(self):
        # Only check for updates in frozen version
        if hasattr(sys, 'frozen') or True:
            if autoupdate.check_for_update():
                link = r"https://gitlab.com/rainlash/lt-maker/-/releases/permalink/latest/downloads/lex_talionis_maker"
                QMessageBox.information(self, "Update Available", "A new update to LT-maker is available!\n"
                                        "Copy this link to your browser to download it:\n"
                                        f"{link}",
                                        )
            else:
                QMessageBox.information(
                    self, "Update not found", "No updates found.")
        else:
            QMessageBox.warning(self, "Update unavailable", "<p>This is a standard python version of LT-maker.</p>"
                                      "<p>Use <b>git fetch</b> and <b>git pull</b> to download the latest git repo updates instead.</p>")


# Testing
# Run "python -m app.editor.main_editor" from main directory
if __name__ == '__main__':
    import sys
    from PyQt5.QtWidgets import QApplication
    app = QApplication(sys.argv)
    window = MainEditor()
    window.show()
    app.exec_()
