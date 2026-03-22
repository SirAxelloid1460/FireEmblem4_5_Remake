from PyQt5.QtWidgets import QWidget, QVBoxLayout, QPushButton, \
    QDialog, QAbstractItemView, QHBoxLayout
from PyQt5.QtCore import Qt

from app.data.resources.resources import RESOURCES
from app.extensions.custom_gui import ResourceTableView, MultiselectTableView
from app.editor.data_editor import SingleResourceEditor, MultiResourceEditor
from app.editor.sound_editor.sound_model import SFXModel, MusicModel
from app.editor import table_model

class SoundTab(QWidget):
    def __init__(self, data, title, model, view, parent=None):
        super().__init__(parent)
        self.window = parent
        self._data = data
        self.title = title

        self.setWindowTitle(self.title)
        self.setStyleSheet("font: 10pt;")

        self.layout = QVBoxLayout(self)
        self.setLayout(self.layout)
        self.setMinimumWidth(360)

        self.model = model(data, self)
        self.proxy_model = table_model.ProxyModel()
        self.proxy_model.setSourceModel(self.model)
        self.view = view(None, self)
        self.view.setAlternatingRowColors(True)
        self.view.setSelectionBehavior(QAbstractItemView.SelectRows)
        self.view.setSelectionMode(QAbstractItemView.SingleSelection)
        self.view.setModel(self.proxy_model)
        self.view.setSortingEnabled(True)
        # Remove edit on double click
        self.view.setEditTriggers(QAbstractItemView.NoEditTriggers)
        self.view.sortByColumn(0, Qt.AscendingOrder)
        self.display = self.view

        self.layout.addWidget(self.view)

        hbox = QHBoxLayout()

        self.button = QPushButton("Add New %s..." % self.title)
        self.button.clicked.connect(self.append)
        hbox.addWidget(self.button)

        self.modify_button = QPushButton("Modify Current %s..." % self.title)
        self.modify_button.clicked.connect(self.modify)
        hbox.addWidget(self.modify_button)

        self.layout.addLayout(hbox)

    def append(self):
        last_index = self.model.append()
        if last_index:
            self.view.setCurrentIndex(last_index)

    def reset(self):
        pass

    def update_list(self):
        pass

    def get_selected(self):
        select = self.display.selectionModel()
        indices = select.selectedRows()
        return [self._data[self.proxy_model.mapToSource(index).row()] for index in indices]

    def modify(self, index):
        proxy_indices = self.display.selectionModel().selectedRows()
        if proxy_indices:
            real_indices = [self.proxy_model.mapToSource(index) for index in proxy_indices]
            self.model.modify(real_indices)

class SFXDatabase(SoundTab):
    @classmethod
    def create(cls, parent=None):
        data = RESOURCES.sfx
        title = "SFX"

        dialog = cls(data, title, SFXModel, MultiselectTableView, parent)
        return dialog

class MusicDatabase(SoundTab):
    @classmethod
    def create(cls, parent=None):
        data = RESOURCES.music
        title = "Music"

        dialog = cls(data, title, MusicModel, ResourceTableView, parent)
        return dialog

def get_sfx():
    window = SingleResourceEditor(SFXDatabase, ['sfx'])
    result = window.exec_()
    if result == QDialog.Accepted:
        selected_sfx = window.tab.get_selected()
        return selected_sfx, True
    else:
        return None, False

def get_music():
    window = SingleResourceEditor(MusicDatabase, ['music'])
    result = window.exec_()
    if result == QDialog.Accepted:
        selected_music = window.tab.get_selected()
        return selected_music, True
    else:
        return None, False

def get_full_editor():
    return MultiResourceEditor((MusicDatabase, SFXDatabase),
                               ("music", "sfx"))

# Testing
# Run "python -m app.editor.sound_editor.sound_tab"
if __name__ == '__main__':
    import sys
    from PyQt5.QtWidgets import QApplication
    app = QApplication(sys.argv)
    RESOURCES.load('default.ltproj')
    # DB.load('default.ltproj')
    window = MultiResourceEditor((MusicDatabase, SFXDatabase),
                                 ("music", "sfx"))
    # window = SingleResourceEditor(SFXDatabase, ['sfx'])
    window.show()
    app.exec_()
