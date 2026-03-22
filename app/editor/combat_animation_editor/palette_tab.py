from PyQt5.QtWidgets import QDialog

from app.data.resources.resources import RESOURCES

from app.editor.data_editor import SingleResourceEditor
from app.editor.base_database_gui import DatabaseTab

from app.editor.combat_animation_editor import palette_model, palette_properties

class PaletteDatabase(DatabaseTab):

    @classmethod
    def create(cls, parent=None):
        data = RESOURCES.combat_palettes
        title = "Palette"
        right_frame = palette_properties.PaletteProperties
        collection_model = palette_model.PaletteModel
        deletion_criteria = None

        dialog = cls(data, title, right_frame, deletion_criteria,
                     collection_model, parent, button_text="Add New %s...")
        return dialog

    @classmethod
    def edit(cls, parent=None):
        window = SingleResourceEditor(PaletteDatabase, ['combat_palettes'], parent)
        window.exec_()

def get():
    window = SingleResourceEditor(PaletteDatabase, ['combat_palettes'])
    result = window.exec_()
    if result == QDialog.Accepted:
        selected_palette = window.tab.right_frame.current
        return selected_palette, True
    else:
        return None, False

# Testing
# Run "python -m app.editor.combat_animation_editor.palette_tab" from main directory
if __name__ == '__main__':
    import sys
    from PyQt5.QtWidgets import QApplication
    from app.editor.combat_animation_editor.combat_animation_display import populate_anim_pixmaps
    app = QApplication(sys.argv)
    RESOURCES.load('sacred_stones.ltproj')
    for anim in RESOURCES.combat_anims:
        populate_anim_pixmaps(anim)
    window = SingleResourceEditor(PaletteDatabase, ['combat_palettes'])
    window.show()
    app.exec_()
