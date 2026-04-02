from app.data.database.database import DB

from app.editor.base_database_gui import DatabaseTab
from app.editor.data_editor import SingleDatabaseEditor

from app.editor.difficulty_mode_editor import difficulty_mode_model, difficulty_mode_properties

class DifficultyModeDatabase(DatabaseTab):
    @classmethod
    def create(cls, parent=None):
        data = DB.difficulty_modes
        title: str = "Difficulty Mode"
        right_frame = difficulty_mode_properties.DifficultyModeProperties

        def deletion_func(model, index):
            return model.rowCount() > 1

        collection_model = difficulty_mode_model.DifficultyModeModel
        return cls(data, title, right_frame, (deletion_func, None, None), collection_model, parent)

# Run "python -m app.editor.difficulty_mode_editor.difficulty_mode_tab" from main directory
if __name__ == '__main__':
    import sys
    from PyQt5.QtWidgets import QApplication
    app = QApplication(sys.argv)
    from app.data.resources.resources import RESOURCES
    RESOURCES.load('default.ltproj')
    DB.load('default.ltproj')
    window = SingleDatabaseEditor(DifficultyModeDatabase)
    window.show()
    app.exec_()
