from PyQt5.QtCore import Qt
from PyQt5.QtGui import QIcon, QPixmap

from app.utilities.data import Data
from app.data.resources.resources import RESOURCES
from app.data.database.database import DB
from app.data.database import skills

from app.extensions.custom_gui import DeletionDialog
from app.editor.base_database_gui import DragDropCollectionModel
from app.editor.custom_widgets import SkillBox

from app.utilities import str_utils
import app.editor.utilities as editor_utilities

def get_pixmap(skill):
    x, y = skill.icon_index
    res = RESOURCES.icons16.get(skill.icon_nid)
    if not res:
        return None
    if not res.pixmap:
        res.pixmap = QPixmap(res.full_path)
    pixmap = res.pixmap.copy(x*16, y*16, 16, 16)
    pixmap = QPixmap.fromImage(editor_utilities.convert_colorkey(pixmap.toImage()))
    return pixmap

class SkillModel(DragDropCollectionModel):
    def data(self, index, role):
        if not index.isValid():
            return None
        if role == Qt.DisplayRole:
            skill = self._data[index.row()]
            text = skill.nid
            return text
        elif role == Qt.DecorationRole:
            skill = self._data[index.row()]
            pix = get_pixmap(skill)
            if pix:
                pix = pix.scaled(32, 32)
                return QIcon(pix)
        return None

    def delete(self, idx):
        # Check to make sure nothing else is using me!!!
        skill = self._data[idx]
        if len(self._data) > 1:  # So we have something to swap to
            nid = skill.nid
            affected_units = [unit for unit in DB.units if nid in unit.get_skills()]
            affected_classes = [k for k in DB.classes if nid in k.get_skills()]
            if affected_units or affected_classes:
                if affected_units:
                    affected = Data(affected_units)
                    from app.editor.unit_editor.unit_model import UnitModel
                    model = UnitModel
                elif affected_classes:
                    affected = Data(affected_classes)
                    from app.editor.class_editor.class_model import ClassModel
                    model = ClassModel
                msg = "Deleting Skill <b>%s</b> would affect these objects." % nid
                swap, ok = DeletionDialog.get_swap(affected, model, msg, SkillBox(self.window, exclude=skill), self.window)
                if ok:
                    self.on_nid_changed(swap.nid, nid)
                else:
                    return
        # Delete watchers
        super().delete(idx)

    def on_nid_changed(self, old_nid, new_nid):
        for unit in DB.units:
            unit.replace_skill_nid(old_nid, new_nid)
        for k in DB.classes:
            k.replace_skill_nid(old_nid, new_nid)

    def create_new(self):
        nids = [d.nid for d in self._data]
        nid = name = str_utils.get_next_name("New Skill", nids)
        new_skill = skills.SkillPrefab(nid, name, '')
        DB.skills.append(new_skill)
        return new_skill
