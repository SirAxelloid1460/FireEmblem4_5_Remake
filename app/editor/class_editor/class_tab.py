import os

from PyQt5.QtWidgets import QApplication, QFileDialog

from app.data.database.database import DB
from app.editor.data_editor import SingleDatabaseEditor
from app.editor.base_database_gui import DatabaseTab

from app.editor.settings import MainSettingsController
from app.editor.class_editor import class_model, class_properties, class_import

class ClassDatabase(DatabaseTab):
    allow_import_from_lt = True
    allow_copy_and_paste = True

    @classmethod
    def create(cls, parent=None):
        data = DB.classes
        title = _("Class")
        right_frame = class_properties.ClassProperties

        def deletion_func(model, index):
            return model._data[index.row()].nid != "Citizen"

        collection_model = class_model.ClassModel
        dialog = cls(data, title, right_frame, (deletion_func, None, deletion_func), collection_model, parent)
        return dialog

    def tick(self):
        self.update_list()

    def import_data(self):
        settings = MainSettingsController()
        starting_path = settings.get_last_open_path()
        fn, ok = QFileDialog.getOpenFileName(self, _("Import classes from class_info.xml"), starting_path, "Class Info XML (class_info.xml);;All Files(*)")
        if ok and fn:
            parent_dir = os.path.split(fn)[0]
            settings.set_last_open_path(parent_dir)
            new_units = class_import.get_from_xml(parent_dir, fn)
            for unit in new_units:
                self._data.append(unit)
            self.update_list()

    @classmethod
    def edit(cls, parent=None):
        window = SingleDatabaseEditor(cls, parent)
        window.exec_()

# Testing
# Run "python -m app.editor.unit_editor.unit_tab" from main directory
if __name__ == '__main__':
    import sys
    app = QApplication(sys.argv)
    from app import dark_theme
    d = dark_theme.QDarkBGPalette()
    d.set_app(app)
    from app.data.resources.resources import RESOURCES
    RESOURCES.load('default.ltproj')
    DB.load('default.ltproj')
    window = SingleDatabaseEditor(ClassDatabase)
    # MEME
    window.setStyleSheet("QDialog {background-image:url(icons/bg.png)};")
    window.show()
    app.exec_()
