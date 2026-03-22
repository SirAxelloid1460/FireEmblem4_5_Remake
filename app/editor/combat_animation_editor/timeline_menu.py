import functools

from PyQt5.QtWidgets import QVBoxLayout, QWidget, QAction, QWidgetAction, \
    QListWidgetItem, QLineEdit, QToolButton, QApplication, QMenu, QToolBar, \
    QAbstractItemView
from PyQt5.QtCore import Qt
from PyQt5.QtGui import QIcon

from app.editor.settings import MainSettingsController

from app.data.resources import combat_commands

from app.editor import combat_command_widgets
from app.extensions.widget_list import WidgetList

class TimelineList(WidgetList):
    def __init__(self, parent):
        super().__init__(parent)

        self.setContextMenuPolicy(Qt.CustomContextMenu)
        self.customContextMenuRequested.connect(self.customMenuRequested)

    def customMenuRequested(self, pos):
        index = self.indexAt(pos)
        menu = QMenu(self)

        if index.isValid():
            duplicate_action = QAction("Duplicate", self, triggered=lambda: self.duplicate(index))
            menu.addAction(duplicate_action)
            delete_action = QAction("Delete", self, triggered=lambda: self.delete(index))
            menu.addAction(delete_action)
            if len(self.index_list) <= 1:
                delete_action.setEnabled(False)

            menu.popup(self.viewport().mapToGlobal(pos))

    def duplicate(self, index):
        idx = index.row()
        command = self.index_list[idx]
        new_command = command.__class__.copy(command)
        self.window.insert_command(idx + 1, new_command)

    def delete(self, index):
        idx = index.row()
        command = self.index_list[idx]
        self.remove_command(command)

    def add_command_widget(self, command_widget):
        item = QListWidgetItem()
        item.setSizeHint(command_widget.sizeHint())
        self.addItem(item)
        self.setItemWidget(item, command_widget)
        self.index_list.append(command_widget._data)
        return item

    def insert_command_widget(self, idx, command_widget):
        item = QListWidgetItem()
        item.setSizeHint(command_widget.sizeHint())
        self.insertItem(idx, item)
        self.setItemWidget(item, command_widget)
        self.index_list.insert(idx, command_widget._data)
        return item

    def remove_command(self, command):
        if command in self.index_list:
            idx = self.index_list.index(command)
            self.index_list.remove(command)
            self.window.current_pose.timeline.remove(command)
            return self.takeItem(idx)
        return None

    def remove_command_widget(self, command_widget):
        command = command_widget._data
        if command in self.index_list:
            idx = self.index_list.index(command)
            self.index_list.remove(command)
            self.window.current_pose.timeline.remove(command)
            return self.takeItem(idx)
        return None

class TimelineMenu(QWidget):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.window = parent

        self.current_pose = None
        self.current_frames = None

        self.current_idx = 0
        self._finished = False

        self.view = TimelineList(self)
        self.view.setStyleSheet("QListWidget::item:selected {background-color: palette(highlight);}")
        self.view.order_swapped.connect(self.command_moved)
        self.view.currentChanged = self.on_new_selection

        self.create_actions()
        self.create_toolbar()

        self.create_input()

        layout = QVBoxLayout()
        layout.addWidget(self.toolbar)
        layout.addWidget(self.view)
        layout.addWidget(self.entry)
        self.setLayout(layout)

    def set_current_frames(self, frames):
        self.current_frames = frames

    def set_current_pose(self, pose):
        self.current_pose = pose
        self.current_idx = 0
        self._finished = False

        self.view.clear()
        if self.current_pose:
            for idx, command in enumerate(self.current_pose.timeline):
                self.add_command_widget(command)

        self.select(self.current_idx)

    def clear(self):
        self.current_frames = None
        self.clear_pose()

    def clear_pose(self):
        self.current_pose = None
        self.current_idx = 0
        self._finished = False
        self.view.clear()

    def select(self, idx):
        self.view.setCurrentRow(idx)
        item = self.view.item(idx)
        self.view.scrollToItem(item, QAbstractItemView.EnsureVisible)

    def on_new_selection(self, curr, prev):
        self.current_idx = curr.row()

    def reset(self):
        self.current_idx = 0
        self._finished = False
        self.select(self.current_idx)

    def remove_command(self, command):
        self.view.remove_command(command)

    def remove_command_widget(self, command):
        self.view.remove_command_widget(command)

    def add_command(self, command):
        new_command = command.__class__.copy(command)
        self.current_pose.timeline.append(new_command)
        self.add_command_widget(new_command)

    def insert_command(self, idx, command):
        self.current_pose.timeline.insert(idx, command)
        command_widget = \
            combat_command_widgets.get_command_widget(command, self)
        self.view.insert_command_widget(idx, command_widget)

    def add_command_widget(self, command):
        command_widget = \
            combat_command_widgets.get_command_widget(command, self)
        self.view.add_command_widget(command_widget)

    def command_moved(self, start, end):
        # self.current_pose.timeline.move_index(start, end)
        if start == end:
            return
        obj = self.current_pose.timeline.pop(start)
        if start > end:
            self.current_pose.timeline.insert(end, obj)
        else:
            self.current_pose.timeline.insert(end - 1, obj)

    def add_text(self):
        try:
            text = self.entry.text()
            command = combat_commands.parse_text(text)
            self.add_command(command)
            self.entry.clear()
        except Exception:
            # play error sound
            print("You got an error, boi!", flush=True)
            QApplication.beep()

    def create_actions(self):
        self.actions = {}
        for command in combat_commands.anim_commands:
            new_func = functools.partial(self.add_command, command)
            new_action = QAction(QIcon(), command.name, self, triggered=new_func)
            self.actions[command.nid] = new_action

    def create_toolbar(self):
        self.toolbar = QToolBar(self)
        self.menus = {}

        self.settings = MainSettingsController()
        theme = self.settings.get_theme(0)
        if theme == 0:
            icon_folder = 'icons/icons'
        else:
            icon_folder = 'icons/dark_icons'

        for command in combat_commands.anim_commands:
            if command.tag not in self.menus:
                new_menu = QMenu(self)
                self.menus[command.tag] = new_menu
                toolbutton = QToolButton(self)
                toolbutton.setIcon(QIcon(f"{icon_folder}/command_%s.png" % command.tag))
                toolbutton.setMenu(new_menu)
                toolbutton.setPopupMode(QToolButton.InstantPopup)
                toolbutton_action = QWidgetAction(self)
                toolbutton_action.setDefaultWidget(toolbutton)
                self.toolbar.addAction(toolbutton_action)
            menu = self.menus[command.tag]
            menu.addAction(self.actions.get(command.nid))

    def create_input(self):
        self.entry = QLineEdit(self)
        self.entry.setPlaceholderText("Enter command here")

    def keyPressEvent(self, event):
        key = event.key()
        if key == Qt.Key_Return or key == Qt.Key_Enter:
            self.add_text()
        else:
            super().keyPressEvent(event)

    def get_current_command(self):
        if self.current_pose and self.current_pose.timeline and \
                self.current_idx < len(self.current_pose.timeline):
            return self.current_pose.timeline[max(0, self.current_idx)]
        return None

    def inc_current_idx(self):
        self.current_idx += 1
        if self.current_idx >= len(self.current_pose.timeline):
            self.current_idx = len(self.current_pose.timeline)
            self._finished = True
            self.select(self.current_idx - 1)
        else:
            self.select(self.current_idx - 1)

    def finished(self) -> bool:
        return self._finished
