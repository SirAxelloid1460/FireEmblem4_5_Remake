from PyQt5.QtWidgets import QWidget, QHBoxLayout, QVBoxLayout, \
    QLabel, QSizePolicy, QSpinBox
from PyQt5.QtCore import pyqtSignal
from PyQt5.QtGui import QColor

from app.extensions.color_slider import RGBSlider, HSVSlider

class ChannelBox(QWidget):
    colorChanged = pyqtSignal(QColor)

    def __init__(self, parent):
        super().__init__(parent)

        self.color: QColor = QColor(0, 0, 0)

        self.hue_slider = HSVSlider('hue', self)
        self.hue_slider.setSizePolicy(QSizePolicy.MinimumExpanding, QSizePolicy.Fixed)
        self.hue_slider.setMinimumSize(200, 20)
        self.saturation_slider = HSVSlider('saturation', self)
        self.saturation_slider.setSizePolicy(QSizePolicy.MinimumExpanding, QSizePolicy.Fixed)
        self.saturation_slider.setMinimumSize(200, 20)
        self.value_slider = HSVSlider('value', self)
        self.value_slider.setSizePolicy(QSizePolicy.MinimumExpanding, QSizePolicy.Fixed)
        self.value_slider.setMinimumSize(200, 20)

        self.hue_label = QLabel('H')
        self.saturation_label = QLabel('S')
        self.value_label = QLabel('V')

        self.hue_spin = QSpinBox()
        self.hue_spin.setRange(0, 360)
        self.saturation_spin = QSpinBox()
        self.saturation_spin.setRange(0, 255)
        self.value_spin = QSpinBox()
        self.value_spin.setRange(0, 255)

        self.red_slider = RGBSlider('red', self)
        self.red_slider.setSizePolicy(QSizePolicy.MinimumExpanding, QSizePolicy.Fixed)
        self.red_slider.setMinimumSize(200, 20)
        self.green_slider = RGBSlider('green', self)
        self.green_slider.setSizePolicy(QSizePolicy.MinimumExpanding, QSizePolicy.Fixed)
        self.green_slider.setMinimumSize(200, 20)
        self.blue_slider = RGBSlider('blue', self)
        self.blue_slider.setSizePolicy(QSizePolicy.MinimumExpanding, QSizePolicy.Fixed)
        self.blue_slider.setMinimumSize(200, 20)

        self.red_label = QLabel('R')
        self.green_label = QLabel('G')
        self.blue_label = QLabel('B')

        self.red_spin = QSpinBox()
        self.red_spin.setRange(0, 255)
        self.green_spin = QSpinBox()
        self.green_spin.setRange(0, 255)
        self.blue_spin = QSpinBox()
        self.blue_spin.setRange(0, 255)

        self.manual_edit: bool = False  # Guard so that we don't get infinite change

        self.hue_slider.hueChanged.connect(self.change_hue)
        self.saturation_slider.saturationChanged.connect(self.change_saturation)
        self.value_slider.valueChanged.connect(self.change_value)

        self.hue_spin.valueChanged.connect(self.change_hue_i)
        self.saturation_spin.valueChanged.connect(self.change_saturation_i)
        self.value_spin.valueChanged.connect(self.change_value_i)

        self.red_slider.redChanged.connect(self.change_red)
        self.green_slider.greenChanged.connect(self.change_green)
        self.blue_slider.blueChanged.connect(self.change_blue)

        self.red_spin.valueChanged.connect(self.change_red_i)
        self.green_spin.valueChanged.connect(self.change_green_i)
        self.blue_spin.valueChanged.connect(self.change_blue_i)

        main_layout = QVBoxLayout()
        hue_layout = QHBoxLayout()
        saturation_layout = QHBoxLayout()
        value_layout = QHBoxLayout()
        hue_layout.addWidget(self.hue_label)
        hue_layout.addWidget(self.hue_spin)
        hue_layout.addWidget(self.hue_slider)
        saturation_layout.addWidget(self.saturation_label)
        saturation_layout.addWidget(self.saturation_spin)
        saturation_layout.addWidget(self.saturation_slider)
        value_layout.addWidget(self.value_label)
        value_layout.addWidget(self.value_spin)
        value_layout.addWidget(self.value_slider)
        main_layout.addLayout(hue_layout)
        main_layout.addLayout(saturation_layout)
        main_layout.addLayout(value_layout)

        red_layout = QHBoxLayout()
        green_layout = QHBoxLayout()
        blue_layout = QHBoxLayout()
        red_layout.addWidget(self.red_label)
        red_layout.addWidget(self.red_spin)
        red_layout.addWidget(self.red_slider)
        green_layout.addWidget(self.green_label)
        green_layout.addWidget(self.green_spin)
        green_layout.addWidget(self.green_slider)
        blue_layout.addWidget(self.blue_label)
        blue_layout.addWidget(self.blue_spin)
        blue_layout.addWidget(self.blue_slider)
        main_layout.addLayout(red_layout)
        main_layout.addLayout(green_layout)
        main_layout.addLayout(blue_layout)

        self.setLayout(main_layout)

    def change_color(self, color: QColor):
        if self.color != color:
            self.color = color
            self.change_hue(color)
            self.change_saturation(color)
            self.change_value(color)
            self.change_red(color)
            self.change_green(color)
            self.change_blue(color)

    def change_hue(self, color: QColor):
        self.manual_edit = False
        self.hue_slider.set_hue(color)
        self.hue_spin.setValue(color.hue())

        self.saturation_slider.change_hue(color)
        self.value_slider.change_hue(color)

        self.color = self.hue_slider.color
        self.colorChanged.emit(self.color)

        self.update_rgb_sliders(self.color)

    def change_hue_i(self, i: int):
        if self.manual_edit:
            new_color = QColor.fromHsv(i, 0, 0)
            self.change_hue(new_color)
        self.manual_edit = True

    def change_saturation(self, color: QColor):
        self.manual_edit = False
        self.saturation_slider.set_saturation(color)
        self.saturation_spin.setValue(color.saturation())

        self.hue_slider.change_saturation(color)
        self.value_slider.change_saturation(color)

        self.color = self.saturation_slider.color
        self.colorChanged.emit(self.color)

        self.update_rgb_sliders(self.color)

    def change_saturation_i(self, i: int):
        if self.manual_edit:
            new_color = QColor.fromHsv(0, i, 0)
            self.change_saturation(new_color)
        self.manual_edit = True

    def change_value(self, color: QColor):
        self.manual_edit = False
        self.value_slider.set_value(color)
        self.value_spin.setValue(color.value())

        self.hue_slider.change_value(color)
        self.saturation_slider.change_value(color)

        self.color = self.value_slider.color
        self.colorChanged.emit(self.color)

        self.update_rgb_sliders(self.color)

    def change_value_i(self, i: int):
        if self.manual_edit:
            new_color = QColor.fromHsv(0, 0, i)
            self.change_value(new_color)
        self.manual_edit = True

    def update_hsv_sliders(self, color: QColor):
        self.hue_slider.change_hue(color)
        self.hue_slider.change_saturation(color)
        self.hue_slider.change_value(color)
        self.saturation_slider.change_hue(color)
        self.saturation_slider.change_saturation(color)
        self.saturation_slider.change_value(color)
        self.value_slider.change_hue(color)
        self.value_slider.change_saturation(color)
        self.value_slider.change_value(color)

        self.hue_spin.setValue(color.hue())
        self.saturation_spin.setValue(color.saturation())
        self.value_spin.setValue(color.value())

    def change_red(self, color: QColor):
        self.manual_edit = False
        self.red_slider.set_red(color)
        self.red_spin.setValue(color.red())

        self.green_slider.change_red(color)
        self.blue_slider.change_red(color)

        self.color = self.red_slider.color
        self.colorChanged.emit(self.color)

        self.update_hsv_sliders(self.color)

    def change_red_i(self, i: int):
        if self.manual_edit:
            new_color = QColor.fromRgb(i, 0, 0)
            self.change_red(new_color)
        self.manual_edit = True

    def change_green(self, color: QColor):
        self.manual_edit = False
        self.green_slider.set_green(color)
        self.green_spin.setValue(color.green())

        self.red_slider.change_green(color)
        self.blue_slider.change_green(color)

        self.color = self.green_slider.color
        self.colorChanged.emit(self.color)

        self.update_hsv_sliders(self.color)

    def change_green_i(self, i: int):
        if self.manual_edit:
            new_color = QColor.fromRgb(0, i, 0)
            self.change_green(new_color)
        self.manual_edit = True

    def change_blue(self, color: QColor):
        self.manual_edit = False
        self.blue_slider.set_blue(color)
        self.blue_spin.setValue(color.blue())

        self.red_slider.change_blue(color)
        self.green_slider.change_blue(color)

        self.color = self.blue_slider.color
        self.colorChanged.emit(self.color)

        self.update_hsv_sliders(self.color)

    def change_blue_i(self, i: int):
        if self.manual_edit:
            new_color = QColor.fromRgb(0, 0, i)
            self.change_blue(new_color)
        self.manual_edit = True

    def update_rgb_sliders(self, color: QColor):
        self.red_slider.change_red(color)
        self.red_slider.change_green(color)
        self.red_slider.change_blue(color)
        self.green_slider.change_red(color)
        self.green_slider.change_green(color)
        self.green_slider.change_blue(color)
        self.blue_slider.change_red(color)
        self.blue_slider.change_green(color)
        self.blue_slider.change_blue(color)

        self.red_spin.setValue(color.red())
        self.green_spin.setValue(color.green())
        self.blue_spin.setValue(color.blue())
