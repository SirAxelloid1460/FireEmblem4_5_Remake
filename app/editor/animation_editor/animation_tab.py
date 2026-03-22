from app.data.resources.resources import RESOURCES

from app.extensions.custom_gui import ResourceListView
from app.editor.data_editor import SingleResourceEditor
from app.editor.base_database_gui import DatabaseTab

from app.editor.animation_editor import animation_model, animation_properties

class AnimationDatabase(DatabaseTab):
    @classmethod
    def create(cls, parent=None):
        data = RESOURCES.animations
        title = "Map Animation"
        right_frame = animation_properties.AnimationProperties
        collection_model = animation_model.AnimationModel
        deletion_criteria = None

        dialog = cls(data, title, right_frame, deletion_criteria,
                     collection_model, parent, button_text="Add New %s...",
                     view_type=ResourceListView)
        return dialog

# Testing
# Run "python -m app.editor.animation_editor.animation_tab" from main directory
if __name__ == '__main__':
    import sys
    from PyQt5.QtWidgets import QApplication
    app = QApplication(sys.argv)
    RESOURCES.load('default.ltproj')
    window = SingleResourceEditor(AnimationDatabase, ['animations'])
    window.show()
    app.exec_()
