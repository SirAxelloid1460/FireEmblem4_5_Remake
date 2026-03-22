from PyQt5.QtWidgets import QWidget, QGridLayout, QListView, QPushButton
from PyQt5.QtCore import QSize, Qt
from PyQt5.QtGui import QPixmap

from app.editor import timer
from app.data.resources.resources import RESOURCES

from app.editor.data_editor import SingleResourceEditor
from app.editor.panorama_editor import panorama_model
from app.extensions.delete_list_view import DeleteListView

class PanoramaTab(QWidget):
    def __init__(self, data, title, model, parent=None):
        super().__init__(parent)
        self.window = parent
        self._data = data
        self.title = title

        self.setWindowTitle(self.title + "s")
        self.setStyleSheet("font: 10pt;")

        self.layout = QGridLayout(self)
        self.setLayout(self.layout)

        for panorama in self._data:
            if not panorama.pixmaps:
                for path in panorama.get_all_paths():
                    panorama.pixmaps.append(QPixmap(path))

        self.view = DeleteListView()
        self.view.setMinimumSize(240*3 + 22, 180*3)
        self.view.setUniformItemSizes(True)
        self.view.setIconSize(QSize(240, 160))
        self.model = model(self._data, self)
        self.view.setModel(self.model)
        self.view.setViewMode(QListView.IconMode)
        self.view.setResizeMode(QListView.Adjust)
        self.view.setMovement(QListView.Static)
        self.view.setGridSize(QSize(240, 180))

        self.layout.addWidget(self.view, 0, 0, 1, 2)

        self.button = QPushButton("Add New Background...")
        self.button.clicked.connect(self.model.append)
        self.layout.addWidget(self.button, 1, 0, 1, 1)

        self.movie_button = QPushButton("Add New Multi-Image Background...")
        self.movie_button.clicked.connect(self.model.append_multi)
        self.layout.addWidget(self.movie_button, 1, 1, 1, 1)

        self.display = None

        timer.get_timer().tick_elapsed.connect(self.tick)

    def update_list(self):
        # self.model.dataChanged.emit(self.model.index(0), self.model.index(self.model.rowCount()))
        self.model.layoutChanged.emit()

    def tick(self):
        pass
        # for idx, panorama in enumerate(self._data):
        #     if len(panorama.pixmaps) > 1:
        #         index = self.model.index(idx)
        #         self.model.dataChanged.emit(index, index, [Qt.DecorationRole])

    def reset(self):
        pass

    @property
    def current(self):
        indices = self.view.selectionModel().selectedIndexes()
        if indices:
            index = indices[0]
            panorama = self.model._data[index.row()]
            return panorama
        return None

class PanoramaDatabase(PanoramaTab):
    @classmethod
    def create(cls, parent=None):
        data = RESOURCES.panoramas
        title = "Background"
        collection_model = panorama_model.PanoramaModel
        deletion_criteria = None

        dialog = cls(data, title, collection_model, parent)
        return dialog

    @classmethod
    def edit(cls, parent=None):
        window = SingleResourceEditor(PanoramaDatabase, ['panoramas'], parent)
        window.exec_()

# Run "python -m app.editor.panorama_editor.panorama_tab" from main directory
if __name__ == '__main__':
    import sys
    from PyQt5.QtWidgets import QApplication
    app = QApplication(sys.argv)
    RESOURCES.load('default.ltproj')
    # DB.load('default.ltproj')
    window = SingleResourceEditor(PanoramaDatabase, ['panoramas'])
    window.show()
    app.exec_()
