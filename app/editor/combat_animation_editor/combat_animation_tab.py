from PyQt5.QtWidgets import QDialog, QWidget

from app.data.resources.resources import RESOURCES

from app.editor.base_database_gui import DatabaseTab
from app.editor.combat_animation_editor.combat_animation_display import CombatAnimProperties
from app.editor.combat_animation_editor.combat_effect_display import CombatEffectProperties
from app.editor.combat_animation_editor.palette_tab import PaletteDatabase
from app.editor.combat_animation_editor.combat_animation_model import CombatAnimModel, CombatEffectModel
from app.extensions.custom_gui import ResourceListView
from app.editor.data_editor import SingleResourceEditor, MultiResourceEditor

class CombatAnimDisplay(DatabaseTab):
    @classmethod
    def create(cls, parent=None):
        data = RESOURCES.combat_anims
        title = "Combat Animation"
        right_frame = CombatAnimProperties
        collection_model = CombatAnimModel
        deletion_criteria = None

        dialog = cls(data, title, right_frame, deletion_criteria,
                     collection_model, parent, button_text="Add New %s...",
                     view_type=ResourceListView)

        return dialog

class SimpleCombatAnimProperties(QWidget):
    def __init__(self, parent, current=None):
        QWidget.__init__(self, parent)
        self.window = parent
        self.current = current

    def set_current(self, current):
        self.current = current

class SimpleCombatAnimDisplay(DatabaseTab):
    @classmethod
    def create(cls, parent=None):
        data = RESOURCES.combat_anims
        title = "Combat Animation"
        right_frame = SimpleCombatAnimProperties
        collection_model = CombatAnimModel
        deletion_criteria = None

        dialog = cls(data, title, right_frame, deletion_criteria,
                     collection_model, parent, button_text="Add New %s...",
                     view_type=ResourceListView)

        return dialog

class CombatEffectDisplay(DatabaseTab):
    @classmethod
    def create(cls, parent=None):
        data = RESOURCES.combat_effects
        title = "Combat Effect"
        right_frame = CombatEffectProperties
        collection_model = CombatEffectModel
        deletion_criteria = None

        dialog = cls(data, title, right_frame, deletion_criteria,
                     collection_model, parent, button_text="Add New %s...",
                     view_type=ResourceListView)
        return dialog

def get_full_editor() -> MultiResourceEditor:
    editor = MultiResourceEditor((CombatAnimDisplay, CombatEffectDisplay, PaletteDatabase),
                                 ('combat_anims', 'combat_effects', 'combat_palettes'))
    editor.setWindowTitle("Combat Animation Editor")
    return editor

def get_animations() -> tuple:
    window = SingleResourceEditor(SimpleCombatAnimDisplay, ['combat_anims'])
    result = window.exec_()
    if result == QDialog.Accepted:
        selected_combat_anim = window.tab.right_frame.current
        return selected_combat_anim, True
    else:
        return None, False
