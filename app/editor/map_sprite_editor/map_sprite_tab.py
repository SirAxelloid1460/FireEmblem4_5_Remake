from PyQt5.QtWidgets import QDialog

from app.data.resources.resources import RESOURCES

from app.extensions.custom_gui import ResourceListView
from app.editor.data_editor import SingleResourceEditor
from app.editor.base_database_gui import DatabaseTab

from app.editor.map_sprite_editor import map_sprite_model, map_sprite_properties

class MapSpriteDatabase(DatabaseTab):
    @classmethod
    def create(cls, parent=None):
        data = RESOURCES.map_sprites
        title = "Map Sprite"
        right_frame = map_sprite_properties.MapSpriteProperties
        collection_model = map_sprite_model.MapSpriteModel
        deletion_criteria = None

        dialog = cls(data, title, right_frame, deletion_criteria,
                     collection_model, parent, button_text="Add New %s...",
                     view_type=ResourceListView)
        return dialog

    @classmethod
    def edit(cls, parent=None):
        window = SingleResourceEditor(MapSpriteDatabase, ['map_sprites'], parent)
        window.exec_()

def get():
    window = SingleResourceEditor(MapSpriteDatabase, ['map_sprites'])
    result = window.exec_()
    if result == QDialog.Accepted:
        selected_map_sprite = window.tab.right_frame.current
        return selected_map_sprite, True
    else:
        return None, False

# Testing
# Run "python -m app.editor.map_sprite_editor.map_sprite_tab" from main directory
if __name__ == '__main__':
    import sys
    from PyQt5.QtWidgets import QApplication
    app = QApplication(sys.argv)
    RESOURCES.load('default.ltproj')
    window = SingleResourceEditor(MapSpriteDatabase, ['map_sprites'])
    window.show()
    app.exec_()
