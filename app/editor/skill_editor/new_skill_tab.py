from __future__ import annotations

from typing import Optional
import os

from PyQt5.QtGui import QIcon
from PyQt5.QtWidgets import QFileDialog
from app.editor.settings.main_settings_controller import MainSettingsController

import app.engine.skill_component_access as SCA
from app.data.database.skills import SkillCatalog, SkillPrefab
from app.editor import timer
from app.editor.component_object_editor import ComponentObjectEditor
from app.editor.data_editor import SingleDatabaseEditor
from app.editor.component_editor_properties import NewComponentProperties
from app.editor.skill_editor import skill_model, skill_import


class NewSkillProperties(NewComponentProperties[SkillPrefab]):
    title = "Skill"
    get_components = staticmethod(SCA.get_skill_components)
    get_templates = staticmethod(SCA.get_templates)
    get_tags = staticmethod(SCA.get_skill_tags)


class NewSkillDatabase(ComponentObjectEditor):
    catalog_type = SkillCatalog
    properties_type = NewSkillProperties

    @classmethod
    def edit(cls, parent=None):
        timer.get_timer().stop_for_editor()  # Don't need these while running game
        window = SingleDatabaseEditor(NewSkillDatabase, parent)
        window.exec_()
        timer.get_timer().start_for_editor()

    @property
    def data(self):
        return self._db.skills

    def get_icon(self, skill_nid) -> Optional[QIcon]:
        pix = skill_model.get_pixmap(self.data.get(skill_nid))
        if pix:
            return QIcon(pix.scaled(32, 32))
        return None

    def import_xml(self):
        settings = MainSettingsController()
        starting_path = settings.get_last_open_path()
        fn, ok = QFileDialog.getOpenFileName(self, _("Import skills from status.xml"), starting_path, "Status XML (status.xml);;All Files(*)")
        if ok and fn.endswith('status.xml'):
            parent_dir = os.path.split(fn)[0]
            settings.set_last_open_path(parent_dir)
            new_skills = skill_import.get_from_xml(parent_dir, fn)
            for skill in new_skills:
                self.data.append(skill)
            self.reset()

    def import_csv(self):
        return

# Testing
# Run "python -m app.editor.skill_editor.new_skill_tab" from main directory
if __name__ == '__main__':
    import sys
    from app.data.database.database import DB
    from PyQt5.QtWidgets import QApplication
    app = QApplication(sys.argv)
    from app.data.resources.resources import RESOURCES
    DB.load('default.ltproj')
    RESOURCES.load('default.ltproj')
    window = NewSkillDatabase(None, DB)
    window.show()
    app.exec_()
