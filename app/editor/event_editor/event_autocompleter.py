from typing import List, Tuple, Type

from PyQt5.QtCore import QStringListModel, Qt, pyqtSignal
from PyQt5.QtWidgets import QCompleter

from app.data.database.database import DB, Database
from app.data.resources.resources import RESOURCES, Resources
from app.editor.settings import MainSettingsController
from app.events import event_commands, event_validators
from app.utilities import str_utils
from app.utilities.typing import NID


class EventScriptCompleter(QCompleter):
    insertText = pyqtSignal(str)
    def __init__(self, parent=None):
        super().__init__(parent)
        self.settings = MainSettingsController()
        self.setFilterMode(Qt.MatchContains)
        self.activated.connect(self.changeCompletion)

    def changeCompletion(self, completion):
        self.insertText.emit(completion)
        self.popup().hide()

    def handleKeyPressEvent(self, event) -> bool:
        if event.key() == self.settings.get_autocomplete_button(Qt.Key_Tab):
            if self.popup().isVisible() and len(self.popup().selectedIndexes()) > 0:
                # If completer is up, Tab/Enter can auto-complete
                completion = self.popup().selectedIndexes()[0].data(Qt.DisplayRole)
                self.changeCompletion(completion)
                return True # should not enter a tab
        elif event.key() == Qt.Key_Backspace:
            # autofill functionality, hides autofill windows
            if self.popup().isVisible():
                self.popup().hide()
        elif event.key() == Qt.Key_Escape:
            if self.popup().isVisible():
                self.popup().hide()
        return False

    def setTextToComplete(self, line: str, cursor_pos: int, level_nid: NID):
        # line is of the form, e.g.:
        # "remove_unit;E" -> User is in the middle of typing "Eirika"
        def arg_text_under_cursor(text: str, cursor_pos):
            before_text = text[0:cursor_pos]
            after_text = text[cursor_pos:]
            idx = before_text.rfind(';')
            before_arg = before_text[idx + 1:]
            idx = after_text.find(';')
            after_arg = after_text[0:idx]
            return (before_arg + after_arg)
        arg_under_cursor = arg_text_under_cursor(line, cursor_pos)
        # determine what dictionary to use for completion
        validator, flags = detect_type_under_cursor(line, cursor_pos, arg_under_cursor)
        autofill_dict = generate_wordlist_from_validator_type(validator, level_nid, arg_under_cursor, DB, RESOURCES)
        if flags:
            autofill_dict = autofill_dict + generate_flags_wordlist(flags)
        if len(autofill_dict) == 0:
            try:
                if self.popup().isVisible():
                    self.popup().hide()
            except: # popup doesn't exist?
                pass
            return False
        self.setModel(QStringListModel(autofill_dict, self))
        trimmed_line = line[0:cursor_pos]
        start_last_arg = max(max([trimmed_line.rfind(c) for c in ';,']), 0)
        completionPrefix = trimmed_line[start_last_arg + 1:]
        self.setCompletionPrefix(completionPrefix)
        self.popup().setCurrentIndex(self.completionModel().index(0, 0))
        return True

def generate_wordlist_from_validator_type(validator: Type[event_validators.Validator], level: NID = None, arg: str = None,
                                          db: Database = None, resources: Resources = None) -> List[str]:
    if not validator:
        return []
    valid_entries = validator(db, resources).valid_entries(level, arg)
    autofill_dict = []
    for entry in valid_entries:
        if entry[0] is None:
            # no name, but has nid
            autofill_dict.append('{}'.format(entry[1]))
        else:
            # has name and nid
            autofill_dict.append('{name} ({nid})'.format(
                name=entry[0], nid=entry[1]))
    return autofill_dict


def generate_flags_wordlist(flags: List[str] = []) -> List[str]:
    flaglist = []
    if len(flags) > 0:
        # then we can also put flags in this slot
        for flag in flags:
            flaglist.append('FLAG({flag})'.format(flag=flag))
    return flaglist

def detect_command_under_cursor(line: str) -> event_commands.EventCommand:
    return event_commands.determine_command_type(line)

def detect_type_under_cursor(line: str, cursor_pos: int, arg_under_cursor: str = None) -> Tuple[event_validators.Validator, List[str]]:
    # turn off typechecking for comments
    comment_index = line.find("#")
    if cursor_pos > comment_index and comment_index > 0:
        return (event_validators.Validator, [])

    if arg_under_cursor:
        # see if we're in the middle of a bracket/eval expression
        # filter out all paired brackets
        arg_under_cursor = str_utils.remove_all_matched(arg_under_cursor, '{', '}')
        eval_bracket = arg_under_cursor.rfind('{')
        eval_colon = arg_under_cursor.rfind(':')
        eval_end = arg_under_cursor.rfind('}')
        if eval_colon > eval_bracket and eval_bracket > eval_end:
            # get eval type
            eval_tag = arg_under_cursor[eval_bracket+1:eval_colon]
            return (event_validators.get(eval_tag), [])

    args = event_commands.get_command_arguments(line)
    arg_idx = -1
    while cursor_pos > 0:
        current_arg = args.pop()
        cursor_pos -= len(current_arg) + 1
        arg_idx += 1
    arg_idx -= 1

    flags = []
    # -1 is the command itself, and 0, 1, 2, etc. are the args
    if arg_idx <= -1:
        return (event_validators.EventFunction, [])
    try:
        command = detect_command_under_cursor(line)
        validator_name = None
        if arg_under_cursor and '=' in arg_under_cursor:
            arg_name = arg_under_cursor.split('=')[0]
            if command.get_index_from_keyword(arg_name) != 0:
                arg_idx = command.get_index_from_keyword(arg_name)
        if command:
            if arg_idx >= len(command.keywords):
                # no longer required keywords, now add optionals and flags
                flags = command.flags
                i = arg_idx - len(command.keywords)
                if i < len(command.optional_keywords):
                    validator_name = command.get_keyword_types()[arg_idx]
            else:
                validator_name = command.get_keyword_types()[arg_idx]
        if validator_name:
            validator = event_validators.get(validator_name)
        else:
            validator = event_validators.Validator
        return (validator, flags)
    except Exception as e:
        print(e)
        import traceback
        traceback.print_exc()
        return (event_validators.Validator, [])
