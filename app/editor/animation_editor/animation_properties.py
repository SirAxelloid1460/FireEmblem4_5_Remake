import time

from PyQt5.QtWidgets import QWidget, QHBoxLayout, QVBoxLayout, \
    QSizePolicy, QFrame, QSplitter, QRadioButton, QLineEdit, QLabel, QSpinBox, \
    QStyle, QToolButton
from PyQt5.QtCore import Qt
from PyQt5.QtGui import QPixmap, QPainter, QImage, QColor, QPen

from app.extensions.custom_gui import PropertyBox
from app.extensions.spinbox_xy import SpinBoxXY

from app.utilities import utils, str_utils
from app.editor import timer
from app.editor.icon_editor.icon_view import IconView

class SpeedSpecification(QWidget):
    def __init__(self, parent):
        super().__init__()
        self.window = parent.window

        self.layout = QVBoxLayout()

        self.int_speed = QRadioButton("Constant (ms)", self)
        self.int_speed.toggled.connect(self.int_speed_toggled)
        self.list_speed = QRadioButton("Variable (#frames)", self)

        self.int_speed_box = QSpinBox(self)
        self.int_speed_box.setRange(1, 1024)
        self.int_speed_box.valueChanged.connect(self.change_spinbox)

        self.list_speed_box = QLineEdit(self)
        self.list_speed_box.setPlaceholderText("Enter integers separated by commas")
        self.list_speed_box.textChanged.connect(self.change_text)
        self.list_speed_box.editingFinished.connect(self.check_text)
        self.list_speed_box.setEnabled(False)
        self.list_speed_label = QLabel(self)

        top_layout = QHBoxLayout()
        top_layout.addWidget(self.int_speed)
        top_layout.addWidget(self.int_speed_box)

        bottom_layout = QHBoxLayout()
        bottom_layout.addWidget(self.list_speed)
        bottom_layout.addWidget(self.list_speed_box)
        bottom_layout.addWidget(self.list_speed_label)

        self.layout.addLayout(top_layout)
        self.layout.addLayout(bottom_layout)

        self.setLayout(self.layout)

    def set_current(self, speed):
        if str_utils.is_int(speed):
            self.int_speed_box.setValue(speed)
            self.int_speed.setChecked(True)
            self.int_speed_toggled(True)
        else:
            self.list_speed_box.setText(self.set_speed(speed))
            self.int_speed.setChecked(False)
            self.int_speed_toggled(False)

    def int_speed_toggled(self, checked):
        if checked:
            self.int_speed_box.setEnabled(True)
            self.list_speed_box.setEnabled(False)
            self.list_speed_label.setPixmap(QPixmap())
            if self.window.current:
                self.window.current.speed = int(self.int_speed_box.value())
        else:
            self.int_speed_box.setEnabled(False)
            self.list_speed_box.setEnabled(True)
            self.check_text()

    def change_spinbox(self, val):
        if self.window.current:
            self.window.current.speed = int(val)

    def change_text(self, text):
        self.check_text()

    def check_text(self):
        text = self.list_speed_box.text()
        if text:
            good = self.text_valid(text)
            if good:
                icon = self.style().standardIcon(QStyle.SP_DialogApplyButton)
                self.list_speed_label.setPixmap(icon.pixmap(32, 32))
                if self.window.current:
                    self.window.current.speed = self.get_speed(text)
            else:
                icon = self.style().standardIcon(QStyle.SP_DialogCancelButton)
                self.list_speed_label.setPixmap(icon.pixmap(32, 32))
                if self.window.current:
                    self.window.current.speed = int(self.int_speed_box.value())
        else:
            self.list_speed_label.setPixmap(QPixmap())
            if self.window.current:
                self.window.current.speed = int(self.int_speed_box.value())

    def get_speed(self, text):
        frame_numbers = text.replace(' ', '').split(',')
        # Split '*' symbol
        new_frame_numbers = []
        for num in frame_numbers:
            if '*' in num:
                a, b = num.split('*')
                new_frame_numbers += [a] * int(b)
            else:
                new_frame_numbers.append(num)
        frame_numbers = [int(_) for _ in new_frame_numbers]
        return frame_numbers

    def set_speed(self, speed_list):
        a = []
        current_speed_int = speed_list[0]
        total = 1
        for speed_int in speed_list[1:]:
            if speed_int == current_speed_int:
                total += 1
            elif total > 1:
                a.append(str(current_speed_int) + '*' + str(total))
                total = 1
            else:
                a.append(str(current_speed_int))
                total = 1
            current_speed_int = speed_int

        if total > 1:
            a.append(str(current_speed_int) + '*' + str(total))
        else:
            a.append(str(current_speed_int))

        return ','.join(a)

    def text_valid(self, text):
        try:
            frame_numbers = self.get_speed(text)
            return all(i > 0 for i in frame_numbers) and len(frame_numbers) == self.window.current.num_frames
        except:
            return False

class AnimationProperties(QWidget):
    def __init__(self, parent, current=None):
        QWidget.__init__(self, parent)
        self.window = parent
        self._data = self.window._data
        self.setMaximumHeight(720)

        # Populate resources
        for resource in self._data:
            resource.pixmap = QPixmap(resource.full_path)

        self.current = current
        self.playing = False
        self.loop = False
        self.last_update = 0
        self.counter = 0
        self.frames_passed = 0

        left_section = QVBoxLayout()

        self.frame_view = IconView(self)
        self.frame_view.scene.setBackgroundBrush(QColor(200, 200, 200))
        left_section.addWidget(self.frame_view)

        button_section = QHBoxLayout()
        button_section.setAlignment(Qt.AlignTop)

        self.play_button = QToolButton(self)
        self.play_button.setIcon(self.style().standardIcon(QStyle.SP_MediaPlay))
        self.play_button.clicked.connect(self.play_clicked)

        self.loop_button = QToolButton(self)
        self.loop_button.setIcon(self.style().standardIcon(QStyle.SP_BrowserReload))
        self.loop_button.clicked.connect(self.loop_clicked)
        self.loop_button.setCheckable(True)

        button_section.addWidget(self.play_button)
        button_section.addWidget(self.loop_button)
        left_section.addLayout(button_section)

        right_section = QVBoxLayout()

        self.frame_box = PropertyBox("Frames", SpinBoxXY, self)
        self.frame_box.edit.coordsChanged.connect(self.frames_changed)
        self.frame_box.edit.setMinimum(1)
        right_section.addWidget(self.frame_box)

        self.total_num_box = PropertyBox("Total Frames", QSpinBox, self)
        self.total_num_box.edit.valueChanged.connect(self.num_frames_changed)
        right_section.addWidget(self.total_num_box)

        self.speed_box = PropertyBox("Speed", SpeedSpecification, self)
        right_section.addWidget(self.speed_box)

        left_frame = QFrame(self)
        left_frame.setLayout(left_section)
        right_frame = QFrame(self)
        right_frame.setLayout(right_section)

        top_splitter = QSplitter(self)
        top_splitter.setChildrenCollapsible(False)
        top_splitter.addWidget(left_frame)
        top_splitter.addWidget(right_frame)

        self.raw_view = PropertyBox("Raw Sprite", IconView, self)
        self.raw_view.edit.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Expanding)

        final_splitter = QSplitter(self)
        final_splitter.setOrientation(Qt.Vertical)
        final_splitter.setChildrenCollapsible(False)
        final_splitter.addWidget(top_splitter)
        final_splitter.addWidget(self.raw_view)

        final_section = QHBoxLayout()
        self.setLayout(final_section)
        final_section.addWidget(final_splitter)

        timer.get_timer().tick_elapsed.connect(self.tick)

    def tick(self):
        if self.current:
            self.draw_raw()
            self.draw_frame()

    def set_current(self, current):
        self.current = current
        old_num_frames = self.current.num_frames
        self.frame_box.edit.set_current(current.frame_x, current.frame_y)
        self.total_num_box.edit.setValue(old_num_frames)
        self.speed_box.edit.set_current(current.speed)
        self.draw_raw()
        self.draw_frame()

    def draw_raw(self):
        pixmap = self.current.pixmap
        base_image = QImage(pixmap.width(), pixmap.height(), QImage.Format_ARGB32)
        base_image.fill(QColor(0, 0, 0, 0))
        painter = QPainter()
        painter.begin(base_image)
        painter.drawImage(0, 0, self.current.pixmap.toImage())
        # Draw grid lines
        painter.setPen(QPen(Qt.black, 1, Qt.DashLine))
        width = self.current.pixmap.width() // self.current.frame_x
        height = self.current.pixmap.height() // self.current.frame_y
        for x in range(self.current.frame_x + 1):
            painter.drawLine(x * width, 0, x * width, self.current.pixmap.height())
        for y in range(self.current.frame_y + 1):
            painter.drawLine(0, y * height, self.current.pixmap.width(), y * height)

        painter.end()

        self.raw_view.edit.set_image(QPixmap.fromImage(base_image))
        self.raw_view.edit.show_image()

    def draw_frame(self):
        if self.playing:
            if str_utils.is_int(self.current.speed):
                num = int(time.time() * 1000 - self.last_update) // self.current.speed
                if num >= self.current.num_frames and not self.loop:
                    num = 0
                    self.stop()
                else:
                    num %= self.current.num_frames
            else:
                self.frames_passed += 1
                if self.frames_passed > self.current.speed[self.counter]:
                    self.counter += 1
                    self.frames_passed = 0
                if self.counter >= len(self.current.speed):
                    if not self.loop:
                        self.stop()
                    self.counter = 0
                num = self.counter
        else:
            num = 0

        width = self.current.pixmap.width() // self.current.frame_x
        height = self.current.pixmap.height() // self.current.frame_y
        left = (num % self.current.frame_x) * width
        top = (num // self.current.frame_x) * height
        base_image = self.current.pixmap.copy(left, top, width, height)

        self.frame_view.set_image(base_image)
        self.frame_view.show_image()

    def stop(self):
        self.playing = False
        self.play_button.setIcon(self.style().standardIcon(QStyle.SP_MediaPlay))

    def play_clicked(self):
        if self.playing:
            self.stop()
        else:
            self.playing = True
            self.last_update = time.time() * 1000
            self.counter = 0
            self.frames_passed = 0
            self.play_button.setIcon(self.style().standardIcon(QStyle.SP_MediaStop))

    def loop_clicked(self, val):
        if val:
            self.loop = True
        else:
            self.loop = False

    def frames_changed(self, x, y):
        if self.current:
            self.current.frame_x = x
            self.current.frame_y = y
            minim = x * y - x + 1
            self.total_num_box.edit.setRange(minim, x * y)
            self.total_num_box.edit.setValue(utils.clamp(self.current.num_frames, minim, x * y))

    def num_frames_changed(self, val):
        self.current.num_frames = val
