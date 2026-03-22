from app.data.resources.resources import RESOURCES
from app.data.database.database import DB

from app.editor.base_database_gui import DatabaseTab
from app.editor.data_editor import SingleDatabaseEditor

from app.editor.support_editor import affinity_properties, affinity_model, support_ranks

class AffinityDatabase(DatabaseTab):
    # Repurposes import button to be used as edit support ranks button
    allow_import_from_lt = True

    @classmethod
    def create(cls, parent=None):
        data = DB.affinities
        title = "Affinity"
        right_frame = affinity_properties.AffinityProperties

        def deletion_func(model, index):
            return model._data[index.row()].nid != "None"

        collection_model = affinity_model.AffinityModel
        dialog = cls(data, title, right_frame, (deletion_func, None, deletion_func), collection_model, parent)
        dialog.left_frame.import_button.setText("Edit Support Ranks...")
        return dialog

    def import_data(self):
        dlg = support_ranks.SupportRankDialog.create()
        result = dlg.exec_()

# Testing
# Run "python -m app.editor.support_editor.support_tab" from main directory
if __name__ == '__main__':
    import sys
    from PyQt5.QtWidgets import QApplication
    app = QApplication(sys.argv)
    RESOURCES.load('default.ltproj')
    DB.load('default.ltproj')
    window = SingleDatabaseEditor(AffinityDatabase)
    window.show()
    app.exec_()
