from PyQt5.QtWidgets import QDialog

from app.data.resources.resources import RESOURCES

from app.extensions.custom_gui import ResourceListView
from app.editor.data_editor import SingleResourceEditor
from app.editor.base_database_gui import DatabaseTab

from app.editor.portrait_editor import portrait_model, portrait_properties

from app.editor import timer

class PortraitDatabase(DatabaseTab):
    @classmethod
    def create(cls, parent=None):
        data = RESOURCES.portraits
        title = "Unit Portrait"
        right_frame = portrait_properties.PortraitProperties
        collection_model = portrait_model.PortraitModel
        deletion_criteria = None

        dialog = cls(data, title, right_frame, deletion_criteria,
                     collection_model, parent, button_text="Add New %s...",
                     view_type=ResourceListView)
        return dialog

    @classmethod
    def edit(cls, parent=None):
        window = SingleResourceEditor(PortraitDatabase, ['portraits'], parent)
        window.exec_()

def get():
    timer.get_timer().start_for_editor()
    window = SingleResourceEditor(PortraitDatabase, ['portraits'])
    result = window.exec_()
    timer.get_timer().stop_for_editor()
    if result == QDialog.Accepted:
        selected_portrait = window.tab.right_frame.current
        return selected_portrait, True
    else:
        return None, False

# Testing
# Run "python -m app.editor.portrait_editor.portrait_tab" from main directory
if __name__ == '__main__':
    import sys
    from PyQt5.QtWidgets import QApplication
    app = QApplication(sys.argv)
    RESOURCES.load('default.ltproj')
    window = SingleResourceEditor(PortraitDatabase, ['portraits'])
    window.show()
    app.exec_()
