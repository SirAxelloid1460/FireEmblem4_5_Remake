import os

from PyQt5.QtWidgets import QFileDialog

from app.data.database.database import DB

from app.editor.data_editor import SingleDatabaseEditor
from app.editor.base_database_gui import DatabaseTab
from app.editor.settings import MainSettingsController
from app.editor.terrain_editor import terrain_properties, terrain_model, terrain_import

class TerrainDatabase(DatabaseTab):
    allow_import_from_lt = True

    @classmethod
    def create(cls, parent=None):
        data = DB.terrain
        title = _("Terrain")
        right_frame = terrain_properties.TerrainProperties

        def deletion_func(model, index):
            return model._data[index.row()].nid != "0"

        collection_model = terrain_model.TerrainModel
        dialog = cls(data, title, right_frame, (deletion_func, None, None), collection_model, parent)
        return dialog

    def import_data(self):
        settings = MainSettingsController()
        starting_path = settings.get_last_open_path()
        fn, ok = QFileDialog.getOpenFileName(self, _("Import terrain from terrain.xml"), starting_path, "Terrain XML (terrain.xml);;All Files(*)")
        if ok and fn.endswith('terrain.xml'):
            parent_dir = os.path.split(fn)[0]
            settings.set_last_open_path(parent_dir)
            new_terrain = terrain_import.get_from_xml(parent_dir, fn)
            for terrain in new_terrain:
                self._data.append(terrain)
            self.update_list()

def get_editor():
    return SingleDatabaseEditor(TerrainDatabase)

# Testing
# Run "python -m app.editor.terrain_editor.terrain_tab" from main directory
if __name__ == '__main__':
    import sys
    from PyQt5.QtWidgets import QApplication
    app = QApplication(sys.argv)
    from app.data.resources.resources import RESOURCES
    RESOURCES.load('default.ltproj')
    DB.load('default.ltproj')
    window = SingleDatabaseEditor(TerrainDatabase)
    window.show()
    app.exec_()
