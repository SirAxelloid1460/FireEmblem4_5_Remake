from PyQt5.QtWidgets import QWidget, QHBoxLayout, QVBoxLayout, \
    QLineEdit, QPushButton
from PyQt5.QtCore import pyqtSignal, QObject, QTimer, Qt, QRect, \
    QPoint, QEvent
from PyQt5.QtGui import QColor, QCursor, QMouseEvent, \
    QGuiApplication, QWindow, QScreen

from app.utilities import utils
from app.extensions.custom_gui import PropertyBox
from app.extensions.color_icon import ColorIcon
from app.editor.combat_animation_editor.channel_box import ChannelBox

from typing import Tuple

class ColorEditorWidget(QWidget):
    colorChanged = pyqtSignal(QColor)

    def __init__(self, parent):
        super().__init__(parent)
        self.window = parent

        self.current_color = QColor(0, 0, 0)
        self.old_color = QColor(0, 0, 0)

        self.color_icon = ColorIcon(self.current_color, self)
        self.color_icon.colorChanged.connect(self.on_color_change)

        self.channel_box = ChannelBox(self)
        self.channel_box.colorChanged.connect(self.on_color_change)

        # For color picking
        # Adapted from https://github.com/qt/qtbase/blob/dev/src/widgets/dialogs/qcolordialog.cpp
        self.color_picker_event_filter = QColorPickingEventFilter(self)
        self.pick_screen_color_button = QPushButton("Pick Screen Color", self)
        self.pick_screen_color_button.clicked.connect(self.on_pick_screen_color)
        # Needed for windows hacks
        self.update_timer = QTimer(self)
        self.update_timer.timeout.connect(self.force_mouse_tracking)
        self.dummy_transparent_window = QWindow()
        self.dummy_transparent_window.resize(1, 1)
        self.dummy_transparent_window.setFlags(Qt.Tool | Qt.FramelessWindowHint)

        self.hex_box = PropertyBox('Hex Code', QLineEdit, self)
        hex_code = utils.color_to_hex(self.current_color.getRgb())
        self.hex_box.edit.setText(hex_code)
        self.hex_box.edit.textEdited.connect(self.on_hex_edited)

        main_layout = QHBoxLayout()
        left_layout = QVBoxLayout()
        left_layout.addWidget(self.color_icon)
        left_layout.addWidget(self.pick_screen_color_button)
        left_layout.addWidget(self.hex_box)
        main_layout.addLayout(left_layout)
        main_layout.addWidget(self.channel_box)
        self.setLayout(main_layout)

        self.all_widgets = [self.channel_box, self.pick_screen_color_button, self.hex_box]

    def on_color_change(self, color: QColor):
        self.set_current(color)

    # Screen Color Picking starts here
    def on_pick_screen_color(self):
        """
        When the user presses the "Pick Screen Color" button
        """
        self.installEventFilter(self.color_picker_event_filter)
        self.grabMouse(Qt.CrossCursor)
        
        if utils.is_windows():
            # Windows only hack
            # because Windows mouse tracking doesn't work over other processes's windows
            self.update_timer.start(30)
            # Catch the mouse click, otherwise we will click something else and lose focus
            self.dummy_transparent_window.show()

        self.setMouseTracking(True)
        global_pos = QCursor.pos()
        color = self.grab_screen_color(global_pos)
        self.set_current(color)

    def on_release_screen_color(self):
        """
        When the user clicks after pressing the "Pick Screen Color" button
        """
        self.removeEventFilter(self.color_picker_event_filter)
        self.releaseMouse()

        if utils.is_windows():
            self.update_timer.stop()
            self.dummy_transparent_window.setVisible(False)

        self.setMouseTracking(False)

    def grab_screen_color(self, point: QPoint) -> QColor:
        screen: QScreen = QGuiApplication.screenAt(point)
        if not screen:
            screen = QGuiApplication.primaryScreen()
        screen_rect: QRect = screen.geometry()
        pixmap = screen.grabWindow(0, point.x() - screen_rect.x(), point.y() - screen_rect.y(), 1, 1)
        im = pixmap.toImage()
        return im.pixelColor(0, 0)

    def force_mouse_tracking(self):
        """
        Called every 30 ms because mouse tracking doesn't work over the whole screen
        """
        new_global_pos = QCursor.pos()
        # Inside the dialog mouse tracking still works, so the event filter will work just fine
        if (not self.rect().contains(self.mapFromGlobal(new_global_pos))):
            self.update_color_picking(new_global_pos)
            self.dummy_transparent_window.setPosition(new_global_pos)
        
    def update_color_picking(self, point: QPoint):
        color = self.grab_screen_color(point)
        self.set_current(color)

    def handle_color_picking_mouse_move(self, e: QMouseEvent) -> bool:
        self.update_color_picking(e.globalPos())
        # Note: The above is deprecated but the below doesn't work in PyQt
        # self.update_color_picking(e.globalPosition().toPoint())

        return True

    def handle_color_picking_mouse_release(self, e: QMouseEvent) -> bool:
        self.set_current(self.grab_screen_color(e.globalPos()))
        # Note: The above is deprecated but the below doesn't work in PyQt
        # self.set_current(self.grab_screen_color(e.globalPosition().toPoint()))

        self.on_release_screen_color()
        return True
    # Screen color picking ends here

    def on_hex_edited(self, text: str):
        try:
            color: Tuple[int, int, int] = utils.hex_to_color(text)
        except Exception as e:
            return
        qcolor = QColor(*color)
        self.set_current(qcolor)

    def set_current(self, color: QColor):
        if color != self.current_color:
            self.current_color: QColor = color

            self.color_icon.change_color(color)
            tuple_color = color.getRgb()
            self.hex_box.edit.setText(utils.color_to_hex(tuple_color))
            self.channel_box.change_color(color)

            self.colorChanged.emit(color)

class QColorPickingEventFilter(QObject):
    def __init__(self, color_dialog):
        super().__init__(color_dialog)
        self.color_dialog = color_dialog

    def eventFilter(self, obj, event: QEvent) -> bool:
        if event.type() == QEvent.MouseMove:
            return self.color_dialog.handle_color_picking_mouse_move(event)
        elif event.type() == QEvent.MouseButtonRelease:
            return self.color_dialog.handle_color_picking_mouse_release(event)
        return False
