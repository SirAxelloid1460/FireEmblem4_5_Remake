import os

from PyQt5.QtWidgets import QFileDialog, QDialog

from app.data.database.database import DB
from app.editor.data_editor import SingleDatabaseEditor
from app.editor.base_database_gui import DatabaseTab
from app.editor.settings import MainSettingsController
from app.editor.unit_editor import unit_model, unit_properties, unit_import

class UnitDatabase(DatabaseTab):
    allow_import_from_lt = True
    allow_import_from_csv = True
    allow_copy_and_paste = True

    @classmethod
    def create(cls, parent=None):
        data = DB.units
        title = _("Unit")
        right_frame = unit_properties.UnitProperties
        deletion_criteria = (None, None, None)
        collection_model = unit_model.UnitModel
        dialog = cls(data, title, right_frame, deletion_criteria, collection_model, parent)
        return dialog

    def import_data(self):
        settings = MainSettingsController()
        starting_path = settings.get_last_open_path()
        fn, ok = QFileDialog.getOpenFileName(self, _("Import units from units.xml"), starting_path, "Units XML (units.xml);;All Files(*)")
        if ok and fn:
            parent_dir = os.path.split(fn)[0]
            settings.set_last_open_path(parent_dir)
            new_units = unit_import.get_from_xml(parent_dir, fn)
            for unit in new_units:
                self._data.append(unit)
            self.update_list()

    def import_csv(self):
        settings = MainSettingsController()
        starting_path = settings.get_last_open_path()
        fn, ok = QFileDialog.getOpenFileName(self, _("Import units from csv"), starting_path, "Units csv (*.csv);;All Files(*)")
        if ok and fn:
            parent_dir = os.path.split(fn)[0]
            settings.set_last_open_path(parent_dir)
            unit_import.update_db_from_csv(DB, fn)
            self.update_list()
            self.reset()

    def on_tab_close(self):
        # Checking to see if any levels need to be changed
        for level in DB.levels:
            for unit in level.units.values():
                if unit.generic or unit.nid in DB.units.keys():
                    pass
                else:  # Remove any unit that no longer exist
                    level.units.remove_key(unit.nid)
            # Now remove groups
            for unit_group in level.unit_groups:
                for unit_nid in unit_group.units:
                    if unit_nid not in level.units.keys():
                        unit_group.remove(unit_nid)

def get(unit_nid=None):
    window = SingleDatabaseEditor(UnitDatabase)
    unit = DB.units.get(unit_nid)
    if unit:
        idx = DB.units.index(unit_nid)
        window.tab.left_frame.set_current_row(idx)
    result = window.exec_()
    if result == QDialog.Accepted:
        selected_unit = window.tab.right_frame.current
        return selected_unit, True
    else:
        return None, False

# Testing
# Run "python -m app.editor.unit_editor.unit_tab" from main directory
if __name__ == '__main__':
    import sys
    from PyQt5.QtWidgets import QApplication
    app = QApplication(sys.argv)
    from app import dark_theme
    d = dark_theme.QDarkPalette()
    d.set_app(app)
    from app.data.resources.resources import RESOURCES
    RESOURCES.load('default.ltproj')
    DB.load('default.ltproj')
    window = SingleDatabaseEditor(UnitDatabase)
    window.show()
    app.exec_()
