from app.data.database.database import DB

from app.editor.base_database_gui import DatabaseTab
from app.editor.data_editor import SingleDatabaseEditor

from app.editor.faction_editor import faction_model, faction_properties

class FactionDatabase(DatabaseTab):
    @classmethod
    def create(cls, parent=None):
        data = DB.factions
        title: str = 'Faction'
        right_frame = faction_properties.FactionProperties

        def deletion_func(model, index):
            return model.rowCount() > 1

        collection_model = faction_model.FactionModel
        dialog = cls(data, title, right_frame, (deletion_func, None, None), collection_model, parent)
        return dialog

# Testing
# Run "python -m app.editor.faction_editor.faction_tab" from main directory
if __name__ == '__main__':
    import sys
    from PyQt5.QtWidgets import QApplication
    app = QApplication(sys.argv)
    from app.data.resources.resources import RESOURCES
    RESOURCES.load('default.ltproj')
    DB.load('default.ltproj')
    window = SingleDatabaseEditor(FactionDatabase)
    window.show()
    app.exec_()
