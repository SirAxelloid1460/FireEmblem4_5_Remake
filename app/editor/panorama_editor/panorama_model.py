from PyQt5.QtWidgets import QFileDialog, QMessageBox
from PyQt5.QtCore import Qt
from PyQt5.QtGui import QPixmap, QIcon

import os, glob, time

from app.constants import WINWIDTH, WINHEIGHT
from app.utilities import str_utils

from app.data.resources.panoramas import Panorama
from app.data.resources.resources import RESOURCES

from app.editor.settings import MainSettingsController
from app.editor.base_database_gui import ResourceCollectionModel

class PanoramaModel(ResourceCollectionModel):
    def data(self, index, role):
        if not index.isValid():
            return None
        if role == Qt.DisplayRole or role == Qt.EditRole:
            panorama = self._data[index.row()]
            text = panorama.nid
            return text
        elif role == Qt.DecorationRole:
            panorama = self._data[index.row()]
            if not panorama.pixmaps:
                for path in panorama.get_all_paths():
                    panorama.pixmaps.append(QPixmap(path))
            if not panorama.pixmaps:
                return None
            counter = int(time.time() * 1000 // 125) % len(panorama.pixmaps)
            pixmap = panorama.pixmaps[counter]
            if pixmap:
                # pixmap = pixmap.scaled(240, 160)
                return QIcon(pixmap)
        return None

    def create_new(self):
        settings = MainSettingsController()
        starting_path = settings.get_last_open_path()
        fns, ok = QFileDialog.getOpenFileNames(self.window, "Add Background", starting_path, "PNG Files (*.png);;All Files(*)")
        new_panorama = None
        if ok:
            for fn in fns:
                if fn.endswith('.png'):
                    nid = os.path.split(fn)[-1][:-4]
                    nid = str_utils.get_next_name(nid, [d.nid for d in RESOURCES.panoramas])
                    pixmap = QPixmap(fn)
                    full_path = fn
                    if pixmap.width() >= WINWIDTH and pixmap.height() >= WINHEIGHT:
                        new_panorama = Panorama(nid, full_path, 1)
                        RESOURCES.panoramas.append(new_panorama)
                    else:
                        QMessageBox.critical(self.window, "Error", "Image must be at least %dx%d pixels in size" % (WINWIDTH, WINHEIGHT))
                else:
                    QMessageBox.critical(self.window, "File Type Error!", "Background must be PNG format!")
            parent_dir = os.path.split(fns[-1])[0]
            settings.set_last_open_path(parent_dir)
        return new_panorama

    def create_new_movie(self):
        settings = MainSettingsController()
        starting_path = settings.get_last_open_path()
        fns, ok = QFileDialog.getOpenFileNames(self.window, "Add Movie (Select First Image)", starting_path, "PNG Files (*.png);;All Files(*)")
        new_panorama = None
        zero_error = False
        if ok:
            for fn in fns:
                if fn.endswith('.png'):
                    nid = os.path.split(fn)[-1][:-4]
                    last_number = str_utils.find_last_number(nid)
                    if last_number == 0:
                        movie_prefix = str_utils.get_prefix(fn)
                        ims = glob.glob(movie_prefix + '*' + '.png')
                        ims = sorted(ims, key=lambda x: str_utils.find_last_number(x[:-4]))
                        full_path = movie_prefix + '.png'
                    elif not zero_error:
                        QMessageBox.critical(self.window, "Warning!", "Select first image of movie only (image0.png)!")
                        zero_error = True
                        continue
                    pixs = [QPixmap(im) for im in ims]
                    movie_prefix = str_utils.get_next_name(movie_prefix, [d.nid for d in RESOURCES.panoramas])
                    if all(pix.width() >= WINWIDTH and pix.height() >= WINHEIGHT for pix in pixs):
                        new_panorama = Panorama(movie_prefix, full_path, len(pixs))
                        RESOURCES.panoramas.append(new_panorama)
                    else:
                        QMessageBox.critical(self.window, "Error", "Images must be at least %dx%d pixels in size" % (WINWIDTH, WINHEIGHT))
                else:
                    QMessageBox.critical(self.window, "File Type Error!", "Background must be PNG format!")
            parent_dir = os.path.split(fns[-1])[0]
            settings.set_last_open_path(parent_dir)
        return new_panorama

    def _append(self, new_item):
        view = self.window.view
        self.dataChanged.emit(self.index(0), self.index(self.rowCount()))
        self.layoutChanged.emit()
        last_index = self.index(self.rowCount() - 1)
        view.setCurrentIndex(last_index)
        return last_index

    def append(self):
        new_item = self.create_new()
        if not new_item:
            return
        self._append(new_item)

    def append_multi(self):
        new_item = self.create_new_movie()
        if not new_item:
            return
        self._append(new_item)

    def delete(self, idx):
        # Check to see what is using me?
        # TODO Nothing for now -- later Dialogue
        res = self._data[idx]
        nid = res.nid
        super().delete(idx)

    def on_nid_changed(self, old_nid, new_nid):
        # What uses panoramas
        # TODO Nothing for now -- later Dialogue
        pass
