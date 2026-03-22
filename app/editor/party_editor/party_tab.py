from app.data.database.database import DB

from app.editor.base_database_gui import DatabaseTab
from app.editor.data_editor import SingleDatabaseEditor

from app.editor.party_editor import party_model, party_properties

class PartyDatabase(DatabaseTab):
    @classmethod
    def create(cls, parent=None):
        data = DB.parties
        title: str = _("Party")
        right_frame = party_properties.PartyProperties

        def deletion_func(model, index):
            return model.rowCount() > 1

        collection_model = party_model.PartyModel
        return cls(data, title, right_frame, (deletion_func, None, None), collection_model, parent)

# Run "python -m app.editor.party_editor.party_tab" from main directory
if __name__ == '__main__':
    import sys
    from PyQt5.QtWidgets import QApplication
    app = QApplication(sys.argv)
    from app.data.resources.resources import RESOURCES
    RESOURCES.load('default.ltproj')
    DB.load('default.ltproj')
    window = SingleDatabaseEditor(PartyDatabase)
    window.show()
    app.exec_()
