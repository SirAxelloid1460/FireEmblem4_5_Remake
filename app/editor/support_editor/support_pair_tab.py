from PyQt5.QtCore import QSize

from app.data.resources.resources import RESOURCES
from app.data.database.database import DB

from app.editor.base_database_gui import DatabaseTab
from app.editor.data_editor import SingleDatabaseEditor, MultiDatabaseEditor

from app.editor.support_editor import support_pair_properties, support_pair_model, support_ranks
from app.editor.support_editor.affinity_tab import AffinityDatabase
from app.editor.support_editor.support_constants_tab import SupportConstantDatabase

class SupportPairDatabase(DatabaseTab):
    # Repurposes import button to be used as edit support ranks button
    allow_import_from_lt = True

    @classmethod
    def create(cls, parent=None):
        data = DB.support_pairs
        title = "Support Pair"
        right_frame = support_pair_properties.SupportPairProperties

        collection_model = support_pair_model.SupportPairModel
        dialog = cls(data, title, right_frame, (None, None, None), collection_model, parent)
        dialog.left_frame.import_button.setText("Edit Support Ranks...")
        dialog.left_frame.view.setIconSize(QSize(64, 32))
        return dialog

    def import_data(self):
        dlg = support_ranks.SupportRankDialog.create()
        result = dlg.exec_()

def get_full_editor():
    editor = MultiDatabaseEditor((SupportPairDatabase, AffinityDatabase, SupportConstantDatabase))
    editor.setWindowTitle("Support Editor")
    return editor

# Testing
# Run "python -m app.editor.support_editor.support_pair_tab" from main directory
if __name__ == '__main__':
    import sys
    from PyQt5.QtWidgets import QApplication
    app = QApplication(sys.argv)
    RESOURCES.load('default.ltproj')
    DB.load('default.ltproj')
    window = SingleDatabaseEditor(SupportPairDatabase)
    window.show()
    app.exec_()
