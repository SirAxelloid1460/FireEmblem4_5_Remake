import os
import shutil

from PyQt5.QtWidgets import QFileDialog, QMessageBox
from PyQt5.QtCore import Qt
from PyQt5.QtGui import QPixmap, QIcon, QImage, QColor

from app.constants import PORTRAIT_WIDTH, ALT_PORTRAIT_WIDTH, PORTRAIT_HEIGHT

from app.data.resources.portraits import Portrait
from app.data.resources.resources import RESOURCES

from app.utilities.data import Data
from app.data.database.database import DB

from app.extensions.custom_gui import DeletionDialog
from app.editor.base_database_gui import ResourceCollectionModel
from app.editor.settings import MainSettingsController
from app.utilities import str_utils
import app.editor.utilities as editor_utilities

def auto_frame_portrait(portrait: Portrait):
    width, height = 32, 16

    def test_similarity(im1: QImage, im2: QImage) -> int:
        diff = 0
        for x in range(width):
            for y in range(height):
                color1 = im1.pixel(x, y)  # Returns QRgb
                color2 = im2.pixel(x, y)
                diff += color1 ^ color2
        return diff

    if not portrait.pixmap:
        portrait.pixmap = QPixmap(portrait.full_path)
    pixmap = portrait.pixmap
    blink_frame1 = QImage(pixmap.copy(96, 48, 32, 16))
    mouth_frame1 = QImage(pixmap.copy(96, 80, 32, 16))
    main_frame = QImage(pixmap.copy(0, 0, 96, 80))
    best_blink_similarity = width * height * 128**3
    best_mouth_similarity = width * height * 128**3
    best_blink_pos = [0, 0]
    best_mouth_pos = [0, 0]
    for x in range(0, main_frame.width() - width, 8):
        for y in range(0, main_frame.height() - height, 8):
            sub_frame = main_frame.copy(x, y, 32, 16)
            blink_similarity = test_similarity(blink_frame1, sub_frame)
            mouth_similarity = test_similarity(mouth_frame1, sub_frame)
            if blink_similarity < best_blink_similarity:
                best_blink_similarity = blink_similarity
                best_blink_pos = [x, y]
            if mouth_similarity < best_mouth_similarity:
                best_mouth_similarity = mouth_similarity
                best_mouth_pos = [x, y]
    portrait.blinking_offset = best_blink_pos
    portrait.smiling_offset = best_mouth_pos

def auto_colorkey(portrait: Portrait):
    if not portrait.pixmap:
        portrait.pixmap = QPixmap(portrait.full_path)
    im = portrait.pixmap.toImage()
    if im.pixel(0, 0) != editor_utilities.qCOLORKEY:
        im = editor_utilities.color_convert(im, {im.pixel(0, 0): editor_utilities.qCOLORKEY})
        # since we're messing with data, let's try to be atomic
        try:
            shutil.copyfile(portrait.full_path, portrait.full_path + '.bak')
        except:
            raise IOError("failed to create backup, aborting auto-colorkey")
        os.remove(portrait.full_path)
        try:
            im.save(portrait.full_path)
            portrait.pixmap = QPixmap(portrait.full_path)
            portrait.image = None # reset this so the engine will know to reload
        except:
            shutil.move(portrait.full_path + '.bak', portrait.full_path)
            raise IOError("some file operation failed, aborting auto-colorkey")
        os.remove(portrait.full_path + '.bak')

class PortraitModel(ResourceCollectionModel):
    def data(self, index, role):
        if not index.isValid():
            return None
        if role == Qt.DisplayRole:
            portrait = self._data[index.row()]
            text = portrait.nid
            return text
        elif role == Qt.DecorationRole:
            portrait = self._data[index.row()]
            if not portrait.pixmap:
                portrait.pixmap = QPixmap(portrait.full_path)
            pixmap = portrait.pixmap
            chibi = pixmap.copy(pixmap.width() - 32, 16, 32, 32)
            chibi = QPixmap.fromImage(editor_utilities.convert_colorkey(chibi.toImage()))
            return QIcon(chibi)
        elif role == Qt.EditRole:
            portrait = self._data[index.row()]
            text = portrait.nid
            return text
        return None

    def create_new(self):
        settings = MainSettingsController()
        starting_path = settings.get_last_open_path()
        fns, ok = QFileDialog.getOpenFileNames(self.window, "Select Portraits", starting_path, "PNG Files (*.png);;All Files(*)")
        new_portrait = None
        if ok:
            for fn in fns:
                if fn.endswith('.png'):
                    nid = os.path.split(fn)[-1][:-4]
                    pix = QPixmap(fn)
                    nid = str_utils.get_next_name(nid, [d.nid for d in RESOURCES.portraits])
                    if (pix.width() == ALT_PORTRAIT_WIDTH or pix.width() == PORTRAIT_WIDTH) and pix.height() == PORTRAIT_HEIGHT:
                        # Swap to use colorkey color if it's not
                        new_portrait = Portrait(nid, fn, pix)
                        auto_colorkey(new_portrait)
                        auto_frame_portrait(new_portrait)
                        RESOURCES.portraits.append(new_portrait)
                    else:
                        QMessageBox.critical(self.window, "Error", "Image is not correct size (128x112 or 144x112 px)")
                else:
                    QMessageBox.critical(self.window, "File Type Error!", "Portrait must be PNG format!")
            parent_dir = os.path.split(fns[-1])[0]
            settings.set_last_open_path(parent_dir)
        return new_portrait

    def delete(self, idx):
        # Check to see what is using me?
        res = self._data[idx]
        nid = res.nid
        affected_units = [unit for unit in DB.units if unit.portrait_nid == nid]
        if affected_units:
            affected = Data(affected_units)
            from app.editor.unit_editor.unit_model import UnitModel
            model = UnitModel
            msg = "Deleting Portrait <b>%s</b> would affect these units." % nid
            ok = DeletionDialog.inform(affected, model, msg, self.window)
            if ok:
                pass
            else:
                return
        super().delete(idx)

    def on_nid_changed(self, old_nid, new_nid):
        # What uses portraits
        # Units (Later Dialogues)
        for unit in DB.units:
            if unit.portrait_nid == old_nid:
                unit.portrait_nid = new_nid
