from PyQt5.QtWidgets import QWidget, QSpacerItem, QDialog, \
    QLineEdit, QHBoxLayout, QVBoxLayout, \
    QMessageBox, QSizePolicy, QCheckBox
from PyQt5.QtGui import QImage, QIcon, QPixmap, QColor
from PyQt5.QtCore import Qt, QSize

from app.sprites import SPRITES
from app.data.resources.resources import RESOURCES
from app.data.database.database import DB

from app.extensions.custom_gui import ComboBox, PropertyBox
from app.editor.custom_widgets import MovementCostBox
from app.editor.mcost_dialog import McostDialog
from app.editor.skill_editor import skill_model
from app.extensions.color_icon import ColorIcon
from app.editor.lib.components.validated_line_edit import NidLineEdit
from app.utilities import str_utils

class TerrainProperties(QWidget):
    def __init__(self, parent, current=None):
        super().__init__(parent)
        self.window = parent
        self._data = self.window._data

        self.current = current

        top_section = QHBoxLayout()

        self.icon_edit = ColorIcon(QColor(0, 0, 0), self)
        self.icon_edit.colorChanged.connect(self.on_color_change)
        top_section.addWidget(self.icon_edit)

        horiz_spacer = QSpacerItem(40, 10, QSizePolicy.Fixed, QSizePolicy.Fixed)
        top_section.addSpacerItem(horiz_spacer)

        name_section = QVBoxLayout()

        self.nid_box = PropertyBox(_("Unique ID"), NidLineEdit, self)
        self.nid_box.edit.textChanged.connect(self.nid_changed)
        self.nid_box.edit.editingFinished.connect(self.nid_done_editing)
        name_section.addWidget(self.nid_box)

        self.name_box = PropertyBox(_("Display Name"), QLineEdit, self)

        self.name_box.edit.textChanged.connect(self.name_changed)
        name_section.addWidget(self.name_box)

        top_section.addLayout(name_section)

        main_section = QVBoxLayout()

        self.minimap_box = PropertyBox(_("Minimap Type"), ComboBox, self)
        minimap_tiles = QImage(SPRITES['Minimap_Tiles'].full_path)
        sf = 4
        for text, sprite_coord in DB.minimap.get_minimap_types():
            im = minimap_tiles.copy(sprite_coord[0]*sf, sprite_coord[1]*sf, sf, sf)
            icon = QIcon(QPixmap.fromImage(im).scaled(QSize(16, 16), Qt.KeepAspectRatio))
            self.minimap_box.edit.addItem(icon, text)
        self.minimap_box.edit.currentIndexChanged.connect(self.minimap_changed)

        self.platform_box = PropertyBox(_("Combat Platform Type"), ComboBox, self)
        for text, sprite_name in RESOURCES.get_platform_types():
            icon = QIcon(RESOURCES.platforms[sprite_name])
            self.platform_box.edit.addItem(icon, text)
        self.platform_box.edit.setIconSize(QSize(87, 40))
        self.platform_box.edit.currentIndexChanged.connect(self.platform_changed)

        self.background_box = PropertyBox(_("Combat Background"), ComboBox, self)
        self.background_box.edit.addItem(QIcon(), 'None')
        for panorama in RESOURCES.panoramas:
            icon = QIcon(panorama.get_all_paths()[0])
            self.background_box.edit.addItem(icon, panorama.nid)
        self.background_box.edit.setIconSize(QSize(240, 160))
        self.background_box.edit.currentIndexChanged.connect(self.background_changed)

        movement_section = QHBoxLayout()
        self.movement_box = MovementCostBox(self, button=True)
        self.movement_box.edit.currentIndexChanged.connect(self.movement_changed)
        self.movement_box.button.clicked.connect(self.access_movement_grid)
        movement_section.addWidget(self.movement_box)

        self.opaque_box = PropertyBox("Blocks line of sight?", QCheckBox, self)
        self.opaque_box.edit.stateChanged.connect(self.opacity_changed)

        self.status_box = PropertyBox(_("Status"), ComboBox, self)
        self.status_box.edit.addItem(_("None"))
        for skill in DB.skills:
            pixmap = skill_model.get_pixmap(skill)
            if pixmap:
                self.status_box.edit.addItem(QIcon(pixmap), skill.nid)
            else:
                self.status_box.edit.addItem(skill.nid)
        self.status_box.edit.setIconSize(QSize(16, 16))
        self.status_box.edit.currentIndexChanged.connect(self.status_changed)

        main_section.addWidget(self.minimap_box)
        main_section.addWidget(self.platform_box)
        main_section.addLayout(movement_section)
        main_section.addWidget(self.opaque_box)
        main_section.addWidget(self.status_box)
        main_section.addWidget(self.background_box)

        total_section = QVBoxLayout()
        self.setLayout(total_section)
        total_section.addLayout(top_section)
        total_section.addLayout(main_section)
        total_section.setAlignment(Qt.AlignTop)

    def nid_changed(self, text):
        self.current.nid = text
        self.window.update_list()

    def nid_done_editing(self):
        # Check validity of nid!
        other_nids = [terrain.nid for terrain in DB.terrain.values() if terrain is not self.current]
        if self.current.nid in other_nids:
            QMessageBox.warning(self.window, 'Warning', 'Terrain ID %s already in use' % self.current.nid)
            self.current.nid = str_utils.get_next_int(self.current.nid, other_nids)
        DB.terrain.update_nid(self.current, self.current.nid)
        self.window.update_list()

    def name_changed(self, text):
        self.current.name = text
        self.window.update_list()

    def minimap_changed(self, index):
        self.current.minimap = self.minimap_box.edit.currentText()

    def platform_changed(self, index):
        self.current.platform = self.platform_box.edit.currentText()

    def background_changed(self, index):
        self.current.background = self.background_box.edit.currentText()

    def movement_changed(self, index):
        self.current.mtype = self.movement_box.edit.currentText()

    def opacity_changed(self, state):
        self.current.opaque = bool(state)

    def status_changed(self, index):
        status = self.status_box.edit.currentText()
        if status == _('None'):
            self.current.status = None
        else:
            self.current.status = status

    def access_movement_grid(self):
        dlg = McostDialog()
        result = dlg.exec_()
        if result == QDialog.Accepted:
            self.movement_box.edit.setValue(self.current.mtype)
        else:
            pass

    def on_color_change(self, color):
        self.current.color = tuple(color.getRgb()[:3])
        self.window.update_list()

    def set_current(self, current):
        self.current = current
        self.nid_box.edit.setText(current.nid)
        self.name_box.edit.setText(current.name)
        self.minimap_box.edit.setValue(current.minimap)
        self.platform_box.edit.setValue(current.platform)
        if current.background:
            self.background_box.edit.setValue(current.background)
        else:
            self.background_box.edit.setValue('None')
        self.movement_box.edit.setValue(current.mtype)
        self.opaque_box.edit.setChecked(bool(current.opaque))
        if current.status:
            self.status_box.edit.setValue(current.status)
        else:
            self.status_box.edit.setValue("None")

        # Icon
        color = current.color
        self.icon_edit.change_color(QColor(color[0], color[1], color[2]))
