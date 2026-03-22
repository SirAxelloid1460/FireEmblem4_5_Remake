from app.data.resources.resources import RESOURCES
from app.data.database.database import DB

from app.editor.base_database_gui import DatabaseTab
from app.editor.data_editor import SingleDatabaseEditor

from app.editor.weapon_editor import weapon_properties, weapon_model, weapon_rank

class WeaponDatabase(DatabaseTab):
    # Repurposes import button to be used as edit weapon ranks button
    allow_import_from_lt = True

    @classmethod
    def create(cls, parent=None):
        data = DB.weapons
        title = "Weapon Type"
        right_frame = weapon_properties.WeaponProperties

        def deletion_func(model, index):
            return model._data[index.row()].nid != "Default"

        collection_model = weapon_model.WeaponModel
        dialog = cls(data, title, right_frame, (deletion_func, None, deletion_func), collection_model, parent)
        dialog.left_frame.import_button.setText("Edit Weapon Ranks...")
        return dialog

    def import_data(self):
        dlg = weapon_rank.RankDialog.create()
        result = dlg.exec_()

# Testing
# Run "python -m app.editor.weapon_editor.weapon_tab" from main directory
if __name__ == '__main__':
    import sys
    from PyQt5.QtWidgets import QApplication
    app = QApplication(sys.argv)
    from app.data.resources.resources import RESOURCES
    RESOURCES.load('default.ltproj')
    DB.load('default.ltproj')
    window = SingleDatabaseEditor(WeaponDatabase)
    window.show()
    app.exec_()
