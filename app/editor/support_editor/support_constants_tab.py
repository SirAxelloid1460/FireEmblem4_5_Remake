from PyQt5.QtWidgets import QSpinBox, QCheckBox, \
    QVBoxLayout, QGroupBox, QWidget
from PyQt5.QtCore import Qt
from app.data.database.constants import ConstantType

from app.data.database.database import DB

from app.extensions.custom_gui import PropertyBox, ComboBox, PropertyCheckBox

from app.editor.base_database_gui import DatabaseTab
from app.editor.data_editor import SingleDatabaseEditor

import logging

class SupportConstantDatabase(DatabaseTab):
    @classmethod
    def create(cls, parent=None):
        data = DB.support_constants
        title = "Support Constants"

        dialog = cls(data, title, parent)
        return dialog

    def update_list(self):
        pass

    def reset(self):
        pass

    # Now we get to the new stuff
    def __init__(self, data, title, parent=None):
        QWidget.__init__(self, parent)
        self.window = parent
        self._data = data
        self.title = title

        self.setWindowTitle('%s Editor' % self.title)
        self.setStyleSheet("font: 10pt")

        self.layout = QVBoxLayout(self)
        self.setLayout(self.layout)

        # main_constants = ('combat_convos', 'base_convos', 'battle_buddy_system', 'bonus_method')
        main_constants = ('combat_convos', 'base_convos', 'break_supports_on_death', 'bonus_method')
        main_section = self.create_section(main_constants)
        main_section.setTitle("Main Constants")
        points_constants = ('bonus_range', 'growth_range', 'chapter_points', 'end_turn_points', 'combat_points', 'interact_points', 'pairup_points')
        points_section = self.create_section(points_constants)
        points_section.setTitle("Range and Points")
        limit_constants = ('bonus_ally_limit', 'rank_limit', 'highest_rank_limit', 'ally_limit', 'point_limit_per_chapter', 'rank_limit_per_chapter')
        limit_section = self.create_section(limit_constants)
        limit_section.setTitle("Limits")

        self.layout.addWidget(main_section)
        self.layout.addWidget(points_section)
        self.layout.addWidget(limit_section)

        self.splitter = None

    def create_section(self, constants):
        section = QGroupBox(self)
        layout = QVBoxLayout()
        section.setLayout(layout)

        for constant_nid in constants:
            constant = self._data.get(constant_nid)
            if not constant:
                logging.error("Couldn't find constant %s" % constant_nid)
                continue
            if constant.attr == ConstantType.INT:
                box = PropertyBox(constant.name, QSpinBox, self, horiz_layout=True)
                box.edit.setRange(0, 99)
                box.edit.setValue(constant.value)
                box.edit.setAlignment(Qt.AlignRight)
                box.edit.setMaximumWidth(50)
                box.edit.valueChanged.connect(constant.set_value)
            elif constant.attr == ConstantType.BOOL:
                box = PropertyCheckBox(constant.name, QCheckBox, self)
                box.edit.setChecked(constant.value)
                box.edit.stateChanged.connect(constant.set_value)
            else: # Choice tuple
                box = PropertyBox(constant.name, ComboBox, self)
                box.edit.addItems(constant.attr)
                box.edit.setValue(constant.value)
                box.edit.currentTextChanged.connect(constant.set_value)
            layout.addWidget(box)
        return section

# Testing
# Run "python -m app.editor.constant_tab" from main directory
if __name__ == '__main__':
    import sys
    from PyQt5.QtWidgets import QApplication
    app = QApplication(sys.argv)
    DB.load('default.ltproj')
    window = SingleDatabaseEditor(SupportConstantDatabase)
    window.show()
    app.exec_()
