import json
import logging
import os
import shutil
from datetime import datetime
from pathlib import Path
from time import time_ns

from app.constants import VERSION
from app.data.database.database import DB, Database
from app.editor import timer
from app.editor.lib.csv import text_data_exporter, csv_data_exporter
from app.editor.new_game_dialog import NewGameDialog
from app.editor.settings import MainSettingsController
from app.data.resources.resources import RESOURCES
from app.utilities import exceptions
from PyQt5.QtCore import QDir, Qt
from PyQt5.QtWidgets import QFileDialog, QMessageBox, QProgressDialog


class ProjectFileBackend():
    def __init__(self, parent, app_state_manager):
        self.parent = parent
        self.app_state_manager = app_state_manager
        self.settings = MainSettingsController()
        self.current_proj = self.settings.get_current_project()

        self.save_progress = QProgressDialog("Saving project to %s" % self.current_proj, None, 0, 100, self.parent)
        self.save_progress.setAutoClose(True)
        self.save_progress.setWindowTitle("Saving Project")
        self.save_progress.setWindowModality(Qt.WindowModal)
        self.save_progress.setWindowFlag(Qt.WindowContextHelpButtonHint, False)
        self.save_progress.reset()

        project_nid = DB.constants.value('game_nid').replace(' ', '_')
        autosave_path = os.path.abspath('autosave_%s.ltproj' % project_nid)
        self.autosave_progress = QProgressDialog("Autosaving project to %s" % autosave_path, None, 0, 100, self.parent)
        self.autosave_progress.setAutoClose(True)
        self.autosave_progress.setWindowTitle("Autosaving Project")
        self.autosave_progress.setWindowModality(Qt.WindowModal)
        self.autosave_progress.setWindowFlag(Qt.WindowContextHelpButtonHint, False)
        self.autosave_progress.reset()

        timer.get_timer().autosave_timer.timeout.connect(self.autosave)

    def maybe_save(self):
        # if not self.undo_stack.isClean():
        if True:  # For now, since undo stack is not being used
            ret = QMessageBox.warning(self.parent, "Main Editor", "The current project may have been modified.\n"
                                      "Do you want to save your changes?",
                                      QMessageBox.Save | QMessageBox.Discard | QMessageBox.Cancel)
            if ret == QMessageBox.Save:
                return self.save()
            elif ret == QMessageBox.Cancel:
                return False
        return True

    def save(self, new=False):
        # check if we're editing default, if so, prompt to save as
        if self.current_proj and os.path.basename(self.current_proj) == 'default.ltproj':
            self.current_proj = None
        if new or not self.current_proj:
            starting_path = self.current_proj or QDir.currentPath()
            fn, ok = QFileDialog.getSaveFileName(self.parent, "Save Project", starting_path,
                                                 "All Files (*)")
            if ok:
                # Make sure you can't save as "autosave" or "default"
                if os.path.split(fn)[-1] in ('autosave.ltproj', 'default.ltproj', 'autosave', 'default'):
                    QMessageBox.critical(self.parent, "Save Error", "You cannot save project as <b>default.ltproj</b> or <b>autosave.ltproj</b>!\nChoose another name.")
                    return False
                if fn.endswith('.ltproj'):
                    self.current_proj = fn
                else:
                    self.current_proj = fn + '.ltproj'
                self.settings.set_current_project(self.current_proj)
            else:
                return False
            new = True

        if new:
            if os.path.exists(self.current_proj):
                ret = QMessageBox.warning(self.parent, "Save Project", "The file already exists.\nDo you want to overwrite it?",
                                          QMessageBox.Save | QMessageBox.Cancel)
                if ret == QMessageBox.Save:
                    pass
                else:
                    return False

        # Make directory for saving if it doesn't already exist
        if not new and self.settings.get_should_make_backup_save():
            # we will copy the existing save (whichever is more recent)
            # as a backup
            self.tmp_proj = self.current_proj + '.lttmp'
            self.save_progress.setLabelText("Making backup to %s" % self.tmp_proj)
            self.save_progress.setValue(1)
            if os.path.exists(self.tmp_proj):
                shutil.rmtree(self.tmp_proj)

            most_recent_path = self.current_proj
            shutil.move(most_recent_path, self.tmp_proj)
        self.save_progress.setLabelText("Saving project to %s" % self.current_proj)
        self.save_progress.setValue(10)

        # Actually save project
        RESOURCES.save(self.current_proj, progress=self.save_progress)
        self.save_progress.setValue(75)
        DB.serialize(self.current_proj)
        self.save_progress.setValue(85)

        # Save metadata
        self.save_metadata(self.current_proj)
        self.save_progress.setValue(87)
        if not new and self.settings.get_should_make_backup_save():
            # we have fully saved the current project.
            # first, delete the .json files that don't appear in the new project
            for old_dir, dirs, files in os.walk(self.tmp_proj):
                new_dir = old_dir.replace(self.tmp_proj, self.current_proj)
                for f in files:
                    if f.endswith('.json'):
                        old_file = os.path.join(old_dir, f)
                        new_file = os.path.join(new_dir, f)
                        if not os.path.exists(new_file):
                            os.remove(old_file)
            # then replace the files in the original backup folder and rename it back
            for src_dir, dirs, files in os.walk(self.current_proj):
                dst_dir = src_dir.replace(self.current_proj, self.tmp_proj)
                for f in files:
                    src_file = os.path.join(src_dir, f)
                    dst_file = os.path.join(dst_dir, f)
                    if os.path.exists(dst_file + '.bak'):
                        os.remove(dst_file)
                    os.rename(src_file, dst_file + '.bak')
                    if os.path.exists(dst_file):
                        os.remove(dst_file)
                    os.rename(dst_file + '.bak', dst_file)
            if os.path.isdir(self.current_proj):
                shutil.rmtree(self.current_proj)
            os.rename(self.tmp_proj, self.current_proj)
        self.save_progress.setValue(100)

        return True

    def new(self):
        if not self.maybe_save():
            return False
        result = NewGameDialog.get()
        if not result:
            return False
        identifier, title = result
        curr_path = QDir()
        curr_path.cdUp()
        starting_path = curr_path.path() + '/' + title + '.ltproj'
        fn, ok = QFileDialog.getSaveFileName(self.parent, "Save Project", starting_path,
                                             "All Files (*)")
        if not ok:
            return
        shutil.copytree(QDir.currentPath() + '/' + 'default.ltproj', fn)
        self.current_proj = fn
        self.settings.set_current_project(fn)
        self.load()
        DB.constants.get('game_nid').set_value(identifier)
        DB.constants.get('title').set_value(title)
        return result

    def open(self):
        if self.maybe_save():
            # Go up one directory when starting
            if self.current_proj:
                starting_path = os.path.join(self.current_proj, '..')
            else:
                starting_path = QDir.currentPath()
            fn = QFileDialog.getExistingDirectory(
                self.parent, "Open Project Directory", starting_path)
            if fn:
                if not fn.endswith('.ltproj'):
                    QMessageBox.warning(self.parent, "Incorrect directory type",
                                        "%s is not an .ltproj." % fn)
                    return False
                self.current_proj = fn
                self.settings.set_current_project(self.current_proj)
                logging.info("Opening project %s" % self.current_proj)
                self.load()
                return True
            else:
                return False
        return False

    def auto_open_fallback(self):
        self.current_proj = "default.ltproj"
        self.settings.set_current_project(self.current_proj)
        self.load()

    def auto_open(self):
        path = self.settings.get_current_project()
        logging.info("Auto Open: %s" % path)

        if path and os.path.exists(path):
            try:
                self.current_proj = path
                self.settings.set_current_project(self.current_proj)
                self.load()
                return True
            except exceptions.CustomComponentsException as e:
                logging.exception(e)
                logging.error("Failed to load project at %s due to syntax error. Likely there's a problem in your Custom Components file, located at %s. See error above." % (path, RESOURCES.get_custom_components_path()))
                QMessageBox.warning(self.parent, "Load of project failed",
                                    "Failed to load project at %s due to syntax error. Likely there's a problem in your Custom Components file, located at %s. Exception:\n%s." % (path, RESOURCES.get_custom_components_path(), e))
                logging.warning("falling back to default.ltproj")
                self.auto_open_fallback()
                return False
            except Exception as e:
                logging.exception(e)
                backup_project_name = path + '.lttmp'
                corrupt_project_name = path + '.ltcorrupt'
                logging.warning("Failed to load project at %s. Likely that project is corrupted.", path)
                logging.warning("the corrupt project will be stored at %s.", corrupt_project_name)
                QMessageBox.warning(self.parent, "Load of project failed",
                                    "Failed to load project at %s. Likely that project is corrupted.\nLoading from backup if available." % path)
                logging.info("Attempting load from backup project %s, which will be renamed to %s", backup_project_name, path)
                if os.path.exists(backup_project_name):
                    try:
                        if os.path.exists(corrupt_project_name):
                            shutil.rmtree(corrupt_project_name)
                        shutil.copytree(path, corrupt_project_name)
                        shutil.rmtree(path)
                        shutil.copytree(backup_project_name, path)
                        self.current_proj = path
                        self.settings.set_current_project(self.current_proj)
                        self.load()
                        return True
                    except Exception as e:
                        logging.error(e)
                        logging.warning("failed to load project at %s.", backup_project_name)
                else:
                    logging.warning("no project found at %s", backup_project_name)
                logging.warning("falling back to default.ltproj")
                self.auto_open_fallback()
                return False
        else:
            logging.warning("path %s not found. Falling back to default.ltproj" % path)
            self.auto_open_fallback()
            return False

    def load(self):
        if os.path.exists(self.current_proj):
            RESOURCES.load(self.current_proj)
            DB.load(self.current_proj)

    def autosave(self):
        project_nid = DB.constants.value('game_nid').replace(' ', '_')
        autosave_path = os.path.abspath('autosave_%s.ltproj' % project_nid)
        self.autosave_progress.setLabelText("Autosaving project to %s" % autosave_path)
        autosave_dir = os.path.abspath(autosave_path)
        # Make directory for saving if it doesn't already exist
        if not os.path.isdir(autosave_dir):
            os.mkdir(autosave_dir)
        self.autosave_progress.setValue(1)

        try:
            self.parent.status_bar.showMessage(
                'Autosaving project to %s...' % autosave_dir)
        except Exception:
            pass

        # Actually save project
        logging.info("Autosaving project to %s..." % autosave_dir)
        RESOURCES.autosave(self.current_proj, autosave_dir, self.autosave_progress)
        self.autosave_progress.setValue(75)
        DB.serialize(autosave_dir)
        self.autosave_progress.setValue(99)

        # Save metadata
        self.save_metadata(autosave_dir)

        try:
            self.parent.status_bar.showMessage(
                'Autosave to %s complete!' % autosave_dir)
        except Exception:
            pass
        self.autosave_progress.setValue(100)

    def save_metadata(self, save_dir):
        metadata_loc = os.path.join(save_dir, 'metadata.json')
        metadata = {}
        metadata['date'] = str(datetime.now())
        metadata['version'] = VERSION
        metadata['project'] = DB.constants.get('game_nid').value
        with open(metadata_loc, 'w') as serialize_file:
            json.dump(metadata, serialize_file, indent=4)

    def clean(self):
        RESOURCES.clean(self.current_proj)

    def dump_csv(self, db: Database):
        starting_path = self.current_proj or QDir.currentPath()
        fn = QFileDialog.getExistingDirectory(
            self.parent, "Choose dump location", starting_path)
        if fn:
            csv_direc = fn
            for ttype, tstr in csv_data_exporter.dump_as_csv(db):
                with open(os.path.join(csv_direc, ttype + '.csv'), 'w') as f:
                    f.write(tstr)
        else:
            return False

    def dump_script(self, db: Database, single_block=True):
        starting_path = self.current_proj or QDir.currentPath()
        fn = QFileDialog.getExistingDirectory(
            self.parent, "Choose dump location", starting_path)
        if fn:
            script_direc = os.path.join(fn, 'script')
            if not os.path.exists(script_direc):
                os.mkdir(script_direc)
            else:
                shutil.rmtree(script_direc)
                os.mkdir(script_direc)
            if single_block:
                with open(os.path.join(script_direc, "script.txt"), 'w') as f:
                    for level_nid, event_dict in text_data_exporter.dump_script(db.events, db.levels).items():
                        for event_nid, event_script in event_dict.items():
                            f.write(event_script + "\n")
            else:
                for level_nid, event_dict in text_data_exporter.dump_script(db.events, db.levels).items():
                    level_direc = os.path.join(script_direc, level_nid)
                    if not os.path.exists(level_direc):
                        os.mkdir(level_direc)
                    else:
                        shutil.rmtree(level_direc)
                        os.mkdir(level_direc)
                    for event_nid, event_script in event_dict.items():
                        with open(os.path.join(level_direc, event_nid + '.txt'), 'w') as f:
                            f.write(event_script)
        else:
            return False
