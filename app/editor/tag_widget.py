from app.utilities.data import Data
from app.data.database.database import DB

from app.extensions.custom_gui import DeletionDialog, PropertyBox, ComboBox
from app.extensions.list_dialogs import MultiAttrListDialog
from app.extensions.list_models import MultiAttrListModel

class TagMultiModel(MultiAttrListModel):
    def delete(self, idx):
        element = DB.tags[idx]
        affected_units = [unit for unit in DB.units if element.nid in unit.tags]
        affected_classes = [k for k in DB.classes if element.nid in k.tags]
        if affected_units or affected_classes:
            if affected_units:
                affected = Data(affected_units)
                from app.editor.unit_editor.unit_model import UnitModel
                model = UnitModel
            elif affected_classes:
                affected = Data(affected_classes)
                from app.editor.class_editor.class_model import ClassModel
                model = ClassModel
            msg = "Deleting Tag <b>%s</b> would affected these items" % element.nid
            combo_box = PropertyBox("Tag", ComboBox, self.window)
            objs = [tag for tag in DB.tags if tag.nid != element.nid]
            combo_box.edit.addItems([tag.nid for tag in objs])
            obj_idx, ok = DeletionDialog.get_simple_swap(affected, model, msg, combo_box, self.window.window)
            if ok:
                swap = objs[obj_idx]
                for unit in affected_units:
                    unit.tags = [swap.nid if tag == element.nid else tag for tag in unit.tags]
                for klass in affected_classes:
                    klass.tags = [swap.nid if tag == element.nid else tag for tag in klass.tags]
            else:
                return
        super().delete(idx)

    def create_new(self):
        return self._data.add_new_default(DB)

    def on_attr_changed(self, data, attr, old_value, new_value):
        if attr == 'nid':
            DB.tags.update_nid(data, new_value)
            for unit in DB.units:
                unit.tags = [new_value if elem == old_value else elem for elem in unit.tags]
            for klass in DB.classes:
                klass.tags = [new_value if elem == old_value else elem for elem in klass.tags]

class TagDialog(MultiAttrListDialog):
    locked_vars = {'Lord', 'Boss', 'Required', 'Mounted', 'Flying', 'Armor', 'Dragon', 'AutoPromote', 'NoAutoPromote', 'Convoy', 'AdjConvoy', 'Tile', 'Blacklist', 'Protect'}

    @classmethod
    def create(cls, parent=None):
        def deletion_func(model, index):
            return model._data[index.row()].nid not in cls.locked_vars

        dlg = cls(DB.tags, "Tag", ("nid",), TagMultiModel, (deletion_func, None, deletion_func), cls.locked_vars, parent)
        return dlg

# Testing
# Run "python -m app.editor.tag_widget"
if __name__ == '__main__':
    import sys
    from PyQt5.QtWidgets import QApplication
    app = QApplication(sys.argv)
    DB.load('default.ltproj')
    window = TagDialog.create()
    window.show()
    app.exec_()
