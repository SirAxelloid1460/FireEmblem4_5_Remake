import functools
import logging
import math
import os
import re
from dataclasses import dataclass

from PyQt5.QtCore import (QRect, QRegularExpression, QSize,
                          QSortFilterProxyModel, Qt,
                          pyqtSignal)
from PyQt5.QtGui import (QColor, QFont, QFontMetrics, QIcon, QPainter,
                         QPalette, QSyntaxHighlighter, QTextCharFormat,
                         QTextCursor)
from PyQt5.QtWidgets import (QAbstractItemView, QAction, QApplication,
                             QCheckBox, QCompleter, QDialog, QFrame,
                             QGridLayout, QHBoxLayout, QHeaderView, QLabel,
                             QLineEdit, QListView, QMenu, QMessageBox,
                             QPlainTextEdit, QPushButton, QSizePolicy,
                             QSpinBox, QSplitter, QStyle, QStyledItemDelegate,
                             QTextEdit, QToolBar, QVBoxLayout, QWidget)

import app.editor.game_actions.game_actions as GAME_ACTIONS
from app.data.database.database import DB
from app.data.resources.resources import RESOURCES
from app.editor import table_model, timer
from app.editor.base_database_gui import CollectionModel
from app.editor.event_editor import event_autocompleter, find_and_replace
from app.editor.lib.components.validated_line_edit import \
    NoParentheticalLineEdit
from app.editor.map_view import SimpleMapView
from app.editor.settings import MainSettingsController
from app.events import event_commands, event_validators
from app.events.mock_event import IfStatementStrategy
from app.events.regions import RegionType
from app.events.triggers import ALL_TRIGGERS
from app.extensions.custom_gui import (ComboBox, PropertyBox, PropertyCheckBox,
                                       QHLine, TableView)
from app.extensions.markdown2 import Markdown
from app.utilities import str_utils

from app.data.database.levels import LevelPrefab
from app.editor.custom_widgets import TilemapBox


@dataclass
class Rule():
    pattern: QRegularExpression
    _format: QTextCharFormat

class HighlighterState():
    EVENT_CODE = -1
    PYTHON_CODE = 0
    TRIPLE_SINGLE_QUOTES = 1
    TRIPLE_DOUBLE_QUOTES = 2

class Highlighter(QSyntaxHighlighter):
    def __init__(self, parent, window):
        super().__init__(parent)
        self.window = window
        self.highlight_rules = []

        settings = MainSettingsController()
        theme = settings.get_theme()
        if theme == 0:
            self.func_color = QColor(52, 103, 174)
            self.comment_color = Qt.darkGray
            self.bad_color = Qt.red
            self.text_color = QColor(63, 109, 58)
            self.special_text_color = Qt.darkMagenta
            self.special_func_color = Qt.red
        else:
            self.func_color = QColor(102, 217, 239)
            self.comment_color = QColor(117, 113, 94)
            self.bad_color = QColor(249, 38, 114)
            self.text_color = QColor(230, 219, 116)
            self.special_text_color = QColor(174, 129, 255)
            self.special_func_color = (249, 38, 114)

        function_head_format = QTextCharFormat()
        function_head_format.setForeground(self.func_color)
        function_head_format.setFontWeight(QFont.Bold)
        # First part of line with semicolon
        self.function_head_rule1 = Rule(
            QRegularExpression("^(.*?);"), function_head_format)
        # Any line without a semicolon
        self.function_head_rule2 = Rule(
            QRegularExpression("^[^;]+$"), function_head_format)
        self.highlight_rules.append(self.function_head_rule1)
        self.highlight_rules.append(self.function_head_rule2)

        self.text_format = QTextCharFormat()
        self.text_format.setForeground(self.text_color)
        self.special_text_format = QTextCharFormat()
        self.special_text_format.setForeground(self.special_text_color)

        comment_format = QTextCharFormat()
        comment_format.setForeground(self.comment_color)
        comment_format.setFontItalic(True)
        self.comment_rule = Rule(
            QRegularExpression("#[^\n]*"), comment_format)
        self.highlight_rules.append(self.comment_rule)

        self.setCurrentBlockState(HighlighterState.EVENT_CODE)

    def highlightBlock(self, text: str):
        if text.startswith("python"):
            self.setCurrentBlockState(HighlighterState.PYTHON_CODE)
            self.highlightEventCode(text)
        elif text.startswith("end_python"):
            self.setCurrentBlockState(HighlighterState.EVENT_CODE)
            self.highlightEventCode(text)
        else:
            if self.previousBlockState() == HighlighterState.EVENT_CODE:
                self.highlightEventCode(text)
            else:
                self.highlightPython(text)
            self.setCurrentBlockState(self.previousBlockState())

    def highlightPython(self, text):
        pass

    def highlightEventCode(self, text):
        text = text.replace('\u2028', ' ')
        for rule in self.highlight_rules:
            match_iterator = rule.pattern.globalMatch(text)
            while match_iterator.hasNext():
                match = match_iterator.next()
                self.setFormat(match.capturedStart(), match.capturedLength(), rule._format)

        lint_format = QTextCharFormat()
        lint_format.setUnderlineStyle(QTextCharFormat.SpellCheckUnderline)
        lint_format.setUnderlineColor(self.bad_color)
        lines = text.splitlines()

        for line in lines:
            # Don't consider tabs when formatting
            num_tabs = 0
            while line.startswith('    '):
                line = line[4:]
                num_tabs += 1
            # Don't process comments
            line = line.split('#', 1)[0]
            if not line:
                continue
            broken_sections = self.validate_line(line)
            if broken_sections == 'all':
                self.setFormat(num_tabs * 4, len(line), lint_format)
            else:
                sections = line.split(';')
                running_length = num_tabs * 4
                for idx, section in enumerate(sections):
                    if idx in broken_sections:
                        self.setFormat(running_length, len(section), lint_format)
                    running_length += len(section) + 1

        # Extra formatting
        for line in lines:
            # Don't consider tabs
            num_tabs = 0
            while line.startswith('    '):
                line = line[4:]
                num_tabs += 1

            line = line.split('#', 1)[0]
            if not line:
                continue
            sections = event_commands.get_command_arguments(line)
            # handle eval, vars, commands, etc.
            for idx, section in enumerate(sections):
                start = num_tabs * 4 + len(';'.join(sections[:idx])) + 1
                if '{' in section and '}' in section:
                    brace_mode = 0
                    for idx, char in enumerate(section):
                        if char == '{':
                            if brace_mode == 0:
                                special_start = start + idx
                            brace_mode += 1
                        if char == '}':
                            if brace_mode > 0:
                                self.setFormat(special_start, start + idx - special_start + 1, self.special_text_format)
                                brace_mode -= 1

            # Handle text format
            if sections[0] in ('s', 'speak') and len(sections) >= 3:
                start = num_tabs * 4 + len(';'.join(sections[:2])) + 1
                self.setFormat(start, len(sections[2]), self.text_format)
                # Handle special text format
                special_start = 0
                brace_mode = 0
                for idx, char in enumerate(sections[2]):
                    if char == '|':
                        self.setFormat(start + idx, 1, self.special_text_format)
                    elif char == '{':
                        if brace_mode == 0:
                            special_start = start + idx
                        brace_mode += 1
                    elif char == '}':
                        if brace_mode > 0:
                            self.setFormat(special_start, start + idx - special_start + 1, self.special_text_format)
                            brace_mode -= 1

    def validate_line(self, line: str) -> list:
        try:
            command, error_loc = event_commands.parse_text_to_command(line, strict=True)
            if command:
                parameters, flags = event_commands.parse(command)
                for keyword in command.keywords:
                    if keyword not in parameters:
                        return 'all'
                broken_args = []
                for keyword, value in parameters.items():
                    validator = command.get_validator_from_keyword(keyword)
                    level_nid = self.window.current.level_nid
                    level = DB.levels.get(level_nid)
                    text = event_validators.validate(validator, value, level, DB, RESOURCES)
                    if text is None:
                        broken_args.append(command.get_index_from_keyword(keyword) + 1)
                return broken_args
            elif error_loc:
                return [error_loc + 1]  # Integer that points to the first idx that is broken
            else:
                return [0]  # First arg is broken
        except Exception as e:
            logging.error("Error while validating %s %s", line, e)
            return 'all'

class LineNumberArea(QWidget):
    def __init__(self, parent):
        super().__init__(parent)
        self.editor = parent

    def sizeHint(self):
        return QSize(self.editor.lineNumberAreaWidth(), 0)

    def paintEvent(self, event):
        self.editor.lineNumberAreaPaintEvent(event)

class CodeEditor(QPlainTextEdit):
    clicked = pyqtSignal()

    def mouseReleaseEvent(self, event):
        self.clicked.emit()
        return super().mouseReleaseEvent(event)

    def __init__(self, parent):
        super().__init__(parent)
        self.window = parent
        self.line_number_area = LineNumberArea(self)

        self.settings = MainSettingsController()
        theme = self.settings.get_theme()
        if theme == 0:
            self.line_number_color = Qt.darkGray
        else:
            self.line_number_color = QColor(144, 144, 138)

        self.blockCountChanged.connect(self.updateLineNumberAreaWidth)
        self.updateRequest.connect(self.updateLineNumberArea)
        self.cursorPositionChanged.connect(self.line_number_area.update)

        self.updateLineNumberAreaWidth(0)
        # Set tab to four spaces
        fm = QFontMetrics(self.font())
        self.setTabStopWidth(4 * fm.width(' '))

        self.completer: QCompleter = None
        self.function_annotator: QLabel = QLabel(self)
        self.markdown_converter: Markdown = Markdown()

        if not bool(self.settings.get_event_autocomplete()):
            return  # Event auto completer is turned off
        else:
            # completer
            self.setCompleter(event_autocompleter.EventScriptCompleter(parent=self))
            self.textChanged.connect(self.complete)
            self.textChanged.connect(self.display_function_hint)
            self.clicked.connect(self.display_function_hint)
            self.cursorPositionChanged.connect(self.display_function_hint)
            self.prev_keyboard_press = None

            # function helper
            self.function_annotator.setTextFormat(Qt.RichText)
            self.function_annotator.setWordWrap(True)
            with open(os.path.join(os.path.dirname(__file__),'event_styles.css'), 'r') as stylecss:
                self.function_annotator.setStyleSheet(stylecss.read())

    def setCompleter(self, completer):
        if not completer:
            return
        completer.setWidget(self)
        completer.setCompletionMode(QCompleter.PopupCompletion)
        completer.setCaseSensitivity(Qt.CaseInsensitive)
        self.completer = completer
        self.completer.insertText.connect(self.insertCompletion)

    def insertCompletion(self, completion):
        tc = self.textCursor()
        while not tc.atBlockEnd():
            tc.movePosition(QTextCursor.NextCharacter, QTextCursor.KeepAnchor)
            if tc.selectedText() in ";,":
                break
            tc.clearSelection()
        end = tc.position()
        while not tc.atBlockStart():
            tc.movePosition(QTextCursor.PreviousCharacter, QTextCursor.KeepAnchor)
            if tc.selectedText() in ';,':
                break
            tc.clearSelection()
        start = tc.position()
        for i in range(start, end):
            tc.movePosition(QTextCursor.NextCharacter, QTextCursor.KeepAnchor)
        tc.removeSelectedText()
        tc.insertText(completion)
        self.setTextCursor(tc)

    def textUnderCursor(self):
        tc = self.textCursor()
        tc.select(QTextCursor.WordUnderCursor)
        return tc.selectedText()

    def display_function_hint(self):
        if not bool(self.settings.get_event_autocomplete()):
            return  # Event auto completer is turned off
        tc = self.textCursor()
        line = tc.block().text()
        cursor_pos = tc.positionInBlock()
        if len(line) != cursor_pos and line[cursor_pos - 1] != ';':
            self.function_annotator.hide()
            return  # Only do function hint on end of line or when clicking at the beginning of a field
        if tc.blockNumber() <= 0 and cursor_pos <= 0:  # don't do hint if cursor is at the very top left of event
            self.function_annotator.hide()
            return
        if self.prev_keyboard_press == Qt.Key_Return: # don't do hint on newline
            self.function_annotator.hide()
            return

        if len(line) > 0 and line[cursor_pos - 1] == ';':
            self.function_annotator.show()

        # determine which command and validator is under the cursor
        command = event_autocompleter.detect_command_under_cursor(line)
        validator, flags = event_autocompleter.detect_type_under_cursor(line, cursor_pos, None)

        if not command or command == event_commands.Comment:
            return

        hint_words = []
        hint_words.append(command.nid)
        all_keywords = command.keywords + command.optional_keywords
        for idx, keyword in enumerate(all_keywords):
            if command.keyword_types:
                keyword_type = command.keyword_types[idx]
                hint_words.append(keyword + "=" + keyword_type)
            else:
                hint_words.append(keyword)
        if command.flags:
            hint_words.append('FLAGS')
        hint_cmd = ""
        hint_desc = ""

        if validator == event_validators.EventFunction:
            self.function_annotator.hide()
            return
        else:
            try:
                arg_idx = line.count(';', 0, cursor_pos)
                if arg_idx != len(hint_words) - 1:
                    hint_words[arg_idx] = '<b>' + hint_words[arg_idx] + '</b>'
                    hint_desc = validator.__name__ + ' ' + str(validator().desc)
                elif cursor_pos > 0 and command.flags:
                    hint_words[-1] = '<b>' + hint_words[-1] + '</b>'
                    hint_desc = 'Must be one of (`' + str.join('`,`', flags) + '`)'
            except:
                if cursor_pos > 0 and command.flags:
                    hint_words[-1] = '<b>' + hint_words[-1] + '</b>'
                    hint_desc = 'Must be one of (`' + str.join('`,`', flags) + '`)'

        hint_cmd = str.join(';\u200b', hint_words)
        # style both components
        hint_cmd = '<div class="command_text">' + hint_cmd + '</div>'
        hint_desc = '<div class="desc_text">' + hint_desc + '</div>'
        hint_command_desc = '<div class="desc_text">' + self.markdown_converter.convert('\n'.join(command.desc.split('\n')[:3])) + '</div>'

        style = """
            <style>
                .command_text {font-family: 'Courier New', Courier, monospace;}
                .desc_text {font-family: Arial, Helvetica, sans-serif;}
            </style>
        """

        hint_text = style + hint_cmd + '<hr>' + hint_desc
        if self.settings.get_event_autocomplete_desc():
            hint_text += '<hr>' + hint_command_desc
        self.function_annotator.setText(hint_text)
        self.function_annotator.setWordWrap(True)
        self.function_annotator.adjustSize()

        # offset the position and display
        tc_top_right = self.mapTo(self.parent(), self.cursorRect(tc).topRight())
        height = self.function_annotator.height()

        top, left = tc_top_right.y() - height - 5, min(tc_top_right.x() + 15, self.width() - self.function_annotator.width())
        if top < 0:
            if self.completer.popup().isVisible():
                top = tc_top_right.y() + self.completer.popup().height() + 6
                left = min(tc_top_right.x(), self.width() - self.function_annotator.width())
            else:
                top = tc_top_right.y() + 5
        tc_top_right.setY(top)
        tc_top_right.setX(left)
        self.function_annotator.move(tc_top_right)

    def complete(self):
        if not self.completer or not bool(self.settings.get_event_autocomplete()):
            return  # Event auto completer is turned off
        tc = self.textCursor()
        line = tc.block().text()
        cursor_pos = tc.positionInBlock()
        if len(line) != cursor_pos:
            return  # Only do autocomplete on end of line
        if tc.blockNumber() <= 0 and cursor_pos <= 0:  # Remove if cursor is at the very top left of event
            return
        if self.prev_keyboard_press in (Qt.Key_Backspace, Qt.Key_Return, Qt.Key_Tab): # don't do autocomplete on backspace
            try:
                if self.completer.popup().isVisible():
                    self.completer.popup().hide()
            except: # popup doesn't exist?
                pass
            return

        if not self.completer.setTextToComplete(line, cursor_pos, self.window.current.level_nid):
            return
        cr = self.cursorRect()
        cr.setWidth(
            self.completer.popup().sizeHintForColumn(0) + self.completer.popup().verticalScrollBar().sizeHint().width())
        self.completer.complete(cr)

    def lineNumberAreaPaintEvent(self, event):
        painter = QPainter(self.line_number_area)
        bg_color = self.palette().color(QPalette.Base)
        painter.fillRect(event.rect(), bg_color)

        block = self.firstVisibleBlock()
        block_number = block.blockNumber()
        top = round(self.blockBoundingGeometry(block).translated(self.contentOffset()).top())
        bottom = top + round(self.blockBoundingRect(block).height())

        while (block.isValid() and top <= event.rect().bottom()):
            if (block.isVisible() and bottom >= event.rect().top()):
                number = str(block_number + 1)
                if self.textCursor().blockNumber() == block_number:
                    color = self.palette().color(QPalette.Window)
                    painter.fillRect(0, top, self.line_number_area.width(), self.fontMetrics().height(), color)
                painter.setPen(self.line_number_color)
                painter.drawText(0, top, self.line_number_area.width() - 2, self.fontMetrics().height(), Qt.AlignRight, number)

            block = block.next()
            top = bottom
            bottom = top + round(self.blockBoundingRect(block).height())
            block_number += 1

    def lineNumberAreaWidth(self) -> int:
        num_blocks = max(1, self.blockCount())
        digits = math.ceil(math.log(num_blocks, 10))
        space = 3 + self.fontMetrics().horizontalAdvance("9") * digits

        return space

    def resizeEvent(self, event):
        super().resizeEvent(event)
        cr = self.contentsRect()
        self.line_number_area.setGeometry(QRect(cr.left(), cr.top(), self.lineNumberAreaWidth(), cr.height()))

    def updateLineNumberAreaWidth(self, newBlockCount: int):
        self.setViewportMargins(self.lineNumberAreaWidth(), 0, 0, 0)

    def updateLineNumberArea(self, rect, dy: int):
        if dy:
            self.line_number_area.scroll(0, dy)
        else:
            self.line_number_area.update(0, rect.y(), self.line_number_area.width(), rect.height())

        if rect.contains(self.viewport().rect()):
            self.updateLineNumberAreaWidth(0)

    def keyPressEvent(self, event):
        self.prev_keyboard_press = event.key()
        # Shift + Tab is not the same as catching a shift modifier + tab key
        # Shift + Tab is a Backtab
        if self.completer:  # let the autocomplete handle the event first
            stop_handling = self.completer.handleKeyPressEvent(event)
            if stop_handling:
                return
        # autocomplete didn't handle the event, or doesn't consume it
        # let the textbox handle
        if event.key() == Qt.Key_Tab:
            cur = self.textCursor()
            cur.insertText("    ")
        elif event.key() == Qt.Key_Backspace:
            # autofill functionality, hides autofill windows
            if self.function_annotator.isVisible():
                self.function_annotator.hide()
            return super().keyPressEvent(event)
        elif event.key() == Qt.Key_Return:
            return super().keyPressEvent(event)
        elif event.key() == Qt.Key_Backtab:
            cur = self.textCursor()
            # Copy the current selection
            pos = cur.position()  # Where a selection ends
            anchor = cur.anchor()  # Where a selection starts (can be the same as above)
            cur.setPosition(pos)
            # Move the position back one, selecting the character prior to the original position
            cur.setPosition(pos - 1, QTextCursor.KeepAnchor)

            if str(cur.selectedText()) == "\t":
                # The prior character is a tab, so delete the selection
                cur.removeSelectedText()
                # Reposition the cursor
                cur.setPosition(anchor - 1)
                cur.setPosition(pos - 1, QTextCursor.KeepAnchor)
            elif str(cur.selectedText()) == " ":
                # Remove up to four spaces
                counter = 0
                while counter < 4 and all(c == " " for c in str(cur.selectedText())):
                    counter += 1
                    cur.setPosition(pos - 1 - counter, QTextCursor.KeepAnchor)
                cur.setPosition(pos - counter, QTextCursor.KeepAnchor)
                cur.removeSelectedText()
                # Reposition the cursor
                cur.setPosition(anchor)
                cur.setPosition(pos, QTextCursor.KeepAnchor)
            else:
                # Try all of the above, looking before the anchor
                cur.setPosition(anchor)
                cur.setPosition(anchor - 1, QTextCursor.KeepAnchor)
                if str(cur.selectedText()) == "\t":
                    cur.removeSelectedText()
                    cur.setPosition(anchor - 1)
                    cur.setPosition(pos - 1, QTextCursor.KeepAnchor)
                else:
                    # It's not a tab, so reset the selection to what it was
                    cur.setPosition(anchor)
                    cur.setPosition(pos, QTextCursor.KeepAnchor)
        elif event.key() == Qt.Key_Escape:
            # autofill functionality, hides autofill windows
            if self.function_annotator.isVisible():
                self.function_annotator.hide()
        else:
            return super().keyPressEvent(event)

class EventCollection(QWidget):
    def __init__(self, deletion_criteria, collection_model, parent,
                 button_text="Create %s", view_type=TableView):
        super().__init__(parent)
        self.window = parent
        self.database_editor = self.window.window
        self.main_editor = self.database_editor.window
        current_level_nid = self.main_editor.app_state_manager.state.selected_level
        self.current_level = DB.levels.get(current_level_nid)

        self._data = self.window._data
        self.title = self.window.title

        self.settings = MainSettingsController()

        self.display = None
        grid = QGridLayout()
        self.setLayout(grid)

        self.level_filter_box = PropertyBox("Level Filter", ComboBox, self)
        self.level_filter_box.edit.addItem("All")
        self.level_filter_box.edit.addItem("Global")
        self.level_filter_box.edit.addItems(DB.levels.keys())
        self.level_filter_box.edit.currentIndexChanged.connect(self.filter_changed)

        self.event_name_filter_box = PropertyBox("Filter by name", QLineEdit, self)
        self.event_name_filter_box.edit.textChanged.connect(self.filter_changed)

        self.model = collection_model(self._data, self)
        self.name_filtered_model = table_model.ProxyModel()
        self.name_filtered_model.setSourceModel(self.model)
        self.level_filtered_model = table_model.ProxyModel()
        self.level_filtered_model.setSourceModel(self.name_filtered_model)
        self.view: TableView = view_type(self)
        self.view.setAlternatingRowColors(True)
        self.view.setSelectionBehavior(QAbstractItemView.SelectRows)
        self.view.setModel(self.level_filtered_model)
        # self.view.setModel(self.model)
        self.view.setSortingEnabled(True)
        self.view.horizontalHeader().setSectionResizeMode(0, QHeaderView.ResizeToContents)
        self.view.horizontalHeader().setSectionResizeMode(2, QHeaderView.ResizeToContents)
        # sort is stored as (col, dir)
        # see leaveEvent
        sort = self.settings.component_controller.get_sort(self.__class__.__name__)
        if sort:
            self.view.sortByColumn(sort[0], sort[1])
        # self.view.clicked.connect(self.on_single_click)
        # Remove edit on double click
        self.view.setEditTriggers(QAbstractItemView.NoEditTriggers)
        # self.view.currentChanged = self.on_item_changed
        self.view.selectionModel().selectionChanged.connect(self.on_item_changed)

        self.setSizePolicy(QSizePolicy.Preferred, QSizePolicy.Preferred)

        self.button = QPushButton(button_text % self.title)
        self.button.clicked.connect(self.create_new_event)

        self.create_actions()
        self.create_toolbar()
        grid.addWidget(self.toolbar, 0, 0, Qt.AlignLeft)
        grid.addWidget(self.event_name_filter_box, 0, 1, Qt.AlignRight)
        grid.addWidget(self.level_filter_box, 0, 2, Qt.AlignRight)
        grid.addWidget(self.view, 1, 0, 1, 3)
        grid.addWidget(self.button, 2, 0, 1, 3)

        if self.current_level:
            self.level_filter_box.edit.setValue(self.current_level.nid)
        else:
            self.level_filter_box.edit.setValue("All")

    def create_actions(self):
        theme = self.settings.get_theme()
        if theme == 0:
            icon_folder = 'icons/icons'
        else:
            icon_folder = 'icons/dark_icons'

        self.new_action = QAction(QIcon(f"{icon_folder}/file-plus.png"), "New Event", triggered=self.new)
        self.new_action.setShortcut("Ctrl+N")
        self.duplicate_action = QAction(QIcon(f"{icon_folder}/duplicate.png"), "Duplicate Event", triggered=self.duplicate)
        self.duplicate_action.setShortcut("Ctrl+D")
        self.delete_action = QAction(QIcon(f"{icon_folder}/x-circle.png"), "Delete Event", triggered=self.delete)
        self.delete_action.setShortcut("Del")
        self._set_enabled(False)

    def _set_enabled(self, val: bool):
        if self.display:
            self.display.setEnabled(val)
        self.delete_action.setEnabled(val)
        self.duplicate_action.setEnabled(val)

    def create_toolbar(self):
        self.toolbar = QToolBar(self)
        self.toolbar.addAction(self.new_action)
        self.toolbar.addAction(self.duplicate_action)
        self.toolbar.addAction(self.delete_action)

    def delete(self):
        current_index = self.view.currentIndex()
        model_index = self.name_filtered_model.mapToSource(self.level_filtered_model.mapToSource(current_index))
        row = current_index.row()
        self.model.delete(model_index)

        if self.level_filtered_model.rowCount() > 0:
            if row >= self.level_filtered_model.rowCount():
                new_index = self.level_filtered_model.index(row - 1, 0)
            else:
                new_index = self.level_filtered_model.index(row, 0)
            self.view.setCurrentIndex(new_index)
            self.set_current_index(new_index)
        else:
            self._set_enabled(False)

    def new(self):
        """
        # Identical to regular create new event
        # since it will just be sorted anyway
        """
        self.create_new_event()

    def duplicate(self):
        current_index = self.view.currentIndex()
        model_index = self.name_filtered_model.mapToSource(self.level_filtered_model.mapToSource(current_index))
        new_index = self.model.duplicate(model_index)
        if new_index:
            name_index = self.name_filtered_model.mapFromSource(new_index)
            new_proxy_index = self.level_filtered_model.mapFromSource(name_index)

            self.view.setCurrentIndex(new_proxy_index)
            self.set_current_index(new_proxy_index)

    def _get_level_nid(self) -> str:
        if self.level_filter_box.edit.currentText() == 'All':
            level_nid = None
        elif self.level_filter_box.edit.currentText() == 'Global':
            level_nid = None
        else:
            level_nid = self.level_filter_box.edit.currentText()
        return level_nid

    def create_new_event(self):
        level_nid = self._get_level_nid()

        self.model.layoutAboutToBeChanged.emit()
        output = self.model.create_new(level_nid)
        self.model.layoutChanged.emit()
        if not output:
            return

        last_index = self.model.index(self.model.rowCount() - 1, 0)

        proxy_last_index = self.level_filtered_model.mapFromSource(self.name_filtered_model.mapFromSource(last_index))
        self.view.setCurrentIndex(proxy_last_index)
        self.set_current_index(proxy_last_index)

        self._set_enabled(True)

    def on_item_changed(self, curr, prev):
        if self._data:
            if curr.indexes():
                index = curr.indexes()[0]
                correct_index = self.name_filtered_model.mapToSource(self.level_filtered_model.mapToSource(index))
                row = correct_index.row()
            else:
                return
            # new_data = curr.internalPointer()  # Internal pointer is way too powerful
            # if not new_data:
            new_data = self._data[row]
            if self.display:
                self.display.set_current(new_data)
                self.display.setEnabled(True)

    def set_current_index(self, index):
        correct_index = self.name_filtered_model.mapToSource(self.level_filtered_model.mapToSource(index))
        row = correct_index.row()
        new_data = self._data[row]
        if self.display:
            self.display.set_current(new_data)
            self.display.setEnabled(True)

    def set_display(self, disp):
        self.display = disp
        first_index = self.level_filtered_model.index(0, 0)
        self.view.setCurrentIndex(first_index)

        self.display.setEnabled(False)
        if self.level_filtered_model.rowCount() > 0:
            self.display.setEnabled(True)

    def filter_changed(self, idx):
        level = self.level_filter_box.edit.currentText()
        name = self.event_name_filter_box.edit.text()

        if level == 'All':
            level = ""
        if not name:
            name = ""

        if not name:
            self.name_filtered_model.setFilterFixedString("")
        else:
            self.name_filtered_model.setFilterRegularExpression('(?i){}'.format(name))

        self.view.selectionModel().selectionChanged.disconnect(self.on_item_changed)
        self.level_filtered_model.setFilterKeyColumn(1)
        if not level:
            self.level_filtered_model.setFilterFixedString("")
        else:
            search = "^" + re.escape(level) + "$"
            self.level_filtered_model.setFilterRegularExpression(search)
        self.view.selectionModel().selectionChanged.connect(self.on_item_changed)
        # Determine if we should reselect something
        if level and self.display:
            # current_index = self.view.currentIndex()
            # real_index = self.level_filtered_model.mapToSource(current_index)
            # obj = self._data[real_index.row()]
            obj = self.display.current
            if obj and ((level != "Global" and level != obj.level_nid) or (level == "Global" and obj.level_nid)):
                # Change selection only if we need to!
                first_index = self.level_filtered_model.index(0, 0)
                self.view.setCurrentIndex(first_index)
                self.set_current_index(first_index)
        elif self.display and not self.display.current:
            # Change selection only if we need to!
            first_index = self.level_filtered_model.index(0, 0)
            self.view.setCurrentIndex(first_index)
            self.set_current_index(first_index)

        self.update_list()

        if self.level_filtered_model.rowCount() > 0:
            self._set_enabled(True)
        else:
            self._set_enabled(False)


    def update_list(self):
        # self.model.layoutChanged.emit()
        # self.level_filtered_model.invalidate()
        self.level_filtered_model.layoutChanged.emit()

    def leaveEvent(self, event) -> None:
        sort_dir = self.view.horizontalHeader().sortIndicatorOrder()
        sort_col = self.view.horizontalHeader().sortIndicatorSection()
        self.settings.component_controller.set_sort(self.__class__.__name__, (sort_col, sort_dir))
        return super().leaveEvent(event)

class EventProperties(QWidget):
    def __init__(self, parent, current=None):
        super().__init__(parent)
        self.window = parent
        self._data = self.window._data

        self.current = current

        self.text_box = CodeEditor(self)
        self.text_box.textChanged.connect(self.text_changed)

        self.find_action = QAction("Find...", self, shortcut="Ctrl+F", triggered=find_and_replace.Find(self).show)
        self.replace_action = QAction("Replace...", self, shortcut="Ctrl+H", triggered=find_and_replace.Find(self).show)
        self.replace_all_action = QAction("Replace all...", self, shortcut="Ctrl+Shift+H", triggered=find_and_replace.Find(self).show)
        self.addAction(self.find_action)
        self.addAction(self.replace_action)
        self.addAction(self.replace_all_action)

        # Text setup
        self.cursor = self.text_box.textCursor()
        self.code_font = QFont()
        self.code_font.setFamily("Courier")
        self.code_font.setFixedPitch(True)
        self.code_font.setPointSize(10)
        self.text_box.setFont(self.code_font)
        self.highlighter = Highlighter(self.text_box.document(), self)

        main_section = QVBoxLayout()
        self.setLayout(main_section)
        main_section.addWidget(self.text_box)

        left_frame = self.window.left_frame
        self.level_filter_box = left_frame.level_filter_box
        grid = left_frame.layout()

        self.name_box = PropertyBox("Name", NoParentheticalLineEdit, self)
        self.name_box.edit.textChanged.connect(self.name_changed)
        self.name_box.edit.editingFinished.connect(self.name_done_editing)

        self.trigger_box = PropertyBox("Trigger", ComboBox, self)
        items = self.get_trigger_items("Global")
        self.trigger_box.edit.addItems(items)
        self.trigger_box.edit.activated.connect(self.trigger_changed)

        self.level_nid_box = PropertyBox("Level", ComboBox, self)
        self.level_nid_box.edit.addItem("Global")
        self.level_nid_box.edit.addItems(DB.levels.keys())
        self.level_nid_box.edit.currentIndexChanged.connect(self.level_nid_changed)

        self.condition_box = PropertyBox("Condition", QLineEdit, self)
        self.condition_box.edit.setPlaceholderText("Condition required for event to fire")
        self.condition_box.edit.textChanged.connect(self.condition_changed)

        self.only_once_box = PropertyCheckBox("Trigger only once?", QCheckBox, self)
        self.only_once_box.edit.stateChanged.connect(self.only_once_changed)

        self.priority_box = PropertyBox("Priority", QSpinBox, self)
        self.priority_box.edit.setRange(0, 99)
        self.priority_box.edit.setAlignment(Qt.AlignRight)
        self.priority_box.setToolTip("Higher Priority happens first")
        self.priority_box.edit.valueChanged.connect(self.priority_changed)

        grid.addWidget(QHLine(), 3, 0, 1, 3)
        grid.addWidget(self.name_box, 4, 0, 1, 3)
        grid.addWidget(self.level_nid_box, 5, 0, 1, 3)
        trigger_layout = QHBoxLayout()
        self.trigger_box.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Fixed)
        trigger_layout.addWidget(self.trigger_box)
        trigger_layout.addWidget(self.priority_box, alignment=Qt.AlignRight)
        grid.addLayout(trigger_layout, 6, 0, 1, 3)
        grid.addWidget(self.condition_box, 7, 0, 1, 3)
        grid.addWidget(self.only_once_box, 8, 0, 1, 3, Qt.AlignLeft)

        bottom_section = QHBoxLayout()
        main_section.addLayout(bottom_section)

        self.show_map_dialog = None
        self.show_map_button = QPushButton("Show Map")
        self.show_map_button.clicked.connect(self.show_map)
        bottom_section.addWidget(self.show_map_button)
        self.show_map_button.setEnabled(False)

        self.show_commands_dialog = None
        self.show_commands_button = QPushButton("Show Commands")
        self.show_commands_button.clicked.connect(self.show_commands)
        bottom_section.addWidget(self.show_commands_button)

        self.test_event_button = QPushButton("Test Event")
        test_menu = QMenu("Test", self)
        test_menu.addAction(QAction("with If Statements always True", self, triggered=functools.partial(self.test_event, IfStatementStrategy.ALWAYS_TRUE)))
        test_menu.addAction(QAction("with If Statements always False", self, triggered=functools.partial(self.test_event, IfStatementStrategy.ALWAYS_FALSE)))
        self.test_event_button.setMenu(test_menu)
        # self.test_event_button.clicked.connect(self.test_event)
        bottom_section.addWidget(self.test_event_button)

    def setEnabled(self, val):
        super().setEnabled(val)
        # Need to also set these, since they are considered
        # part of the left frame by Qt
        self.name_box.setEnabled(val)
        self.level_nid_box.setEnabled(val)
        self.trigger_box.setEnabled(val)
        self.condition_box.setEnabled(val)
        self.only_once_box.setEnabled(val)

    def get_trigger_items(self, level_nid: str) -> list:
        all_items = ["None"]
        all_custom_triggers = set()
        for level in DB.levels:
            if level_nid == 'Global' or level_nid == level.nid:
                for region in level.regions:
                    if region.region_type == RegionType.EVENT:
                        all_custom_triggers.add(region.sub_nid)
        all_items += list(all_custom_triggers)
        all_items += [trigger.nid for trigger in ALL_TRIGGERS]
        return all_items

    def insert_text(self, text):
        self.text_box.insertPlainText(text)

    def insert_text_with_newline(self, text):
        self.cursor.movePosition(QTextCursor.NextBlock)
        self.text_box.insertPlainText(text)

    def show_map(self):
        # Modeless dialog
        if not self.show_map_dialog:
            current_level = DB.levels.get(self.current.level_nid)
            self.show_map_dialog = ShowMapDialog(current_level, self)
        self.show_map_dialog.setAttribute(Qt.WA_ShowWithoutActivating, True)
        # self.show_map_dialog.setWindowFlags(self.show_map_dialog.windowFlags() | Qt.WindowDoesNotAcceptFocus)
        self.show_map_dialog.show()
        self.show_map_dialog.raise_()
        # self.show_map_dialog.activateWindow()

    def close_map(self):
        if self.show_map_dialog:
            self.show_map_dialog.done(0)
            self.show_map_dialog = None

    def show_commands(self):
        # Modeless dialog
        if not self.show_commands_dialog:
            self.show_commands_dialog = ShowCommandsDialog(self)
        # self.show_commands_dialog.setAttribute(Qt.WA_ShowWithoutActivating, True)
        # self.show_commands_dialog.setWindowFlags(self.show_commands_dialog.windowFlags() | Qt.WindowDoesNotAcceptFocus)
        self.show_commands_dialog.show()
        self.show_commands_dialog.raise_()
        # self.show_commands_dialog.activateWindow()

    def close_commands(self):
        if self.show_commands_dialog:
            self.show_commands_dialog.done(0)
            self.show_commands_dialog = None

    def test_event(self, strategy):
        if self.current:
            commands = self.current.commands
            cursor_position = 0
            timer.get_timer().stop()
            GAME_ACTIONS.test_event(commands, cursor_position, strategy)
            timer.get_timer().start()

    def name_changed(self, text):
        self.current.name = text
        self.window.update_list()

    def name_done_editing(self):
        # Check validity of nid!
        other_nids = [d.nid for d in self._data.values() if d is not self.current]
        other_names = [d.name for d in self._data.values() if d is not self.current and d.level_nid == self.current.level_nid]
        if self.current.nid in other_nids:
            QMessageBox.warning(self.window, 'Warning', 'Event ID %s already in use' % self.current.nid)
            self.current.name = str_utils.get_next_name(self.current.name, other_names)
            self.name_box.edit.setText(self.current.name)
        self._data.update_nid(self.current, self.current.nid, set_nid=False)
        self.window.update_list()

    def trigger_changed(self, idx):
        cur_val = self.trigger_box.edit.currentText()
        if cur_val == 'None':
            self.current.trigger = None
        elif cur_val in [trigger.nid for trigger in ALL_TRIGGERS]:
            self.current.trigger = cur_val
        else:
            self.current.trigger = cur_val
        self.window.update_list()

    def level_nid_changed(self, idx):
        if idx == 0:
            self.current.level_nid = None
            self.name_done_editing()
            self.show_map_button.setEnabled(False)
            if self.level_filter_box.edit.currentText() != "All":
                self.level_filter_box.edit.setValue("Global")
        else:
            self.current.level_nid = DB.levels[idx - 1].nid
            self.name_done_editing()
            current_level = DB.levels.get(self.current.level_nid)
            if current_level.tilemap:
                self.show_map_button.setEnabled(True)
            else:
                self.show_map_button.setEnabled(False)
            if self.level_filter_box.edit.currentText() != "All":
                self.level_filter_box.edit.setValue(self.current.level_nid)

        # Update trigger box to match current level
        self.trigger_box.edit.clear()
        if idx == 0:
            self.trigger_box.edit.addItems(self.get_trigger_items("Global"))
        else:
            self.trigger_box.edit.addItems(self.get_trigger_items(self.current.level_nid))
        self.trigger_box.edit.setValue(self.current.trigger)
        self.window.update_list()

    def condition_changed(self, text):
        self.current.condition = text

    def only_once_changed(self, state):
        self.current.only_once = bool(state)

    def priority_changed(self, value):
        self.current.priority = value

    def text_changed(self):
        self.current.commands.clear()
        lines = []
        for doc_idx in range(self.text_box.document().blockCount()):
            line = self.text_box.document().findBlockByNumber(doc_idx).text().strip()
            if line:
                lines.append(line)
        for line in lines:
            command, error_loc = event_commands.parse_text_to_command(line)
            if command:
                self.current.commands.append(command)

    def set_current(self, current):
        self.current = current
        self.name_box.edit.setText(current.name)
        # self.trigger_box.edit.clear()
        if current.level_nid is not None:
            self.level_nid_box.edit.setValue(current.level_nid)
            # self.trigger_box.edit.addItems(self.get_trigger_items(current.level_nid))
        else:
            self.level_nid_box.edit.setValue('Global')
            # self.trigger_box.edit.addItems(self.get_trigger_items("Global"))
        if current.trigger:
            self.trigger_box.edit.setValue(current.trigger)
        else:
            self.trigger_box.edit.setValue("None")
        self.condition_box.edit.setText(current.condition)
        self.only_once_box.edit.setChecked(bool(current.only_once))
        self.priority_box.edit.setValue(current.priority)

        # Convert text
        text = ''
        num_tabs = 0
        for command in current.commands:
            if command:
                if command.nid in ('else', 'elif', 'end', 'endf'):
                    num_tabs -= 1
                text += '    ' * num_tabs
                text += command.to_plain_text()
                text += '\n'
                if command.nid in ('if', 'elif', 'else', 'for'):
                    num_tabs += 1
            else:
                logging.warning("NoneType in current.commands")

        self.text_box.setPlainText(text)

    def hideEvent(self, event):
        self.close_map()
        self.close_commands()

class ShowMapDialog(QDialog):
    def __init__(self, current_level: LevelPrefab, parent=None):
        super().__init__(parent)
        self.setWindowFlag(Qt.WindowContextHelpButtonHint, False)
        self.setWindowTitle("Level Map View")
        self.window = parent
        self.current_level = current_level

        self.map_selector = TilemapBox(self)
        self.map_selector.edit.activated.connect(self.select_current)
        if self.current_level and self.current_level.tilemap:
            self.map_selector.edit.setCurrentIndex(self.map_selector.edit.findText(self.current_level.tilemap))

        self.map_view = SimpleMapView(self)
        self.map_view.position_clicked.connect(self.position_clicked)
        self.map_view.position_moved.connect(self.position_moved)
        self.map_view.set_current_level(self.current_level)

        self.position_edit = QLineEdit(self)
        self.position_edit.setAlignment(Qt.AlignRight)
        self.position_edit.setReadOnly(True)

        layout = QVBoxLayout()
        self.setLayout(layout)
        layout.addWidget(self.map_selector)
        layout.addWidget(self.map_view)
        layout.addWidget(self.position_edit, Qt.AlignRight)

        timer.get_timer().tick_elapsed.connect(self.map_view.update_view)

    def select_current(self):
        tilemap_nid = self.map_selector.edit.currentText()
        if tilemap_nid == self.current_level.tilemap:
            self.map_view.set_current_level(self.current_level)
        else:
            tilemap = RESOURCES.tilemaps.get(tilemap_nid)
            if tilemap:
                self.map_view.set_current_map(tilemap)

    def position_clicked(self, x, y):
        self.window.insert_text("%d,%d" % (x, y))

    def position_moved(self, x, y):
        if x >= 0 and y >= 0:
            unit_name = None
            for unit in self.current_level.units:
                if unit.starting_position and unit.starting_position[0] == x and unit.starting_position[1] == y:
                    unit_name = unit.nid
                    break
            if unit_name:
                self.position_edit.setText("%s: %d,%d" % (unit_name, x, y))
            else:
                self.position_edit.setText("%d,%d" % (x, y))
        else:
            self.position_edit.setText("")

    def update(self):
        self.map_view.update_view()

    def set_current(self, current):
        self.current_level = current
        self.map_view.set_current_level(self.current_level)
        tilemap = RESOURCES.tilemaps.get(self.current_level.tilemap)
        if tilemap:
            self.map_view.set_current_map(tilemap)

    def closeEvent(self, event):
        self.window.show_map_dialog = None

class ShowCommandsDialog(QDialog):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setWindowFlag(Qt.WindowContextHelpButtonHint, False)
        self.setWindowTitle("Event Commands")
        self.window = parent

        self.commands = event_commands.get_commands()
        self.categories = [category.value for category in event_commands.Tags]
        self._data = []
        for category in self.categories:
            # Ignore hidden category
            if category == event_commands.Tags.HIDDEN.value:
                continue
            self._data.append(category)
            commands = [command() for command in self.commands if command.tag.value == category]
            self._data += commands

        self.model = EventCommandModel(self._data, self.categories, self)
        self.proxy_model = QSortFilterProxyModel()
        self.proxy_model.setSourceModel(self.model)
        self.view = QListView(self)
        self.view.setMinimumSize(256, 360)
        self.view.setModel(self.proxy_model)
        self.view.doubleClicked.connect(self.on_double_click)

        self.delegate = CommandDelegate(self._data, self)
        self.view.setItemDelegate(self.delegate)

        self.search_box = QLineEdit(self)
        self.search_box.setPlaceholderText("Enter search term here...")
        self.search_box.textChanged.connect(self.search)

        self.desc_box = QTextEdit(self)
        self.desc_box.setReadOnly(True)
        self.view.selectionModel().selectionChanged.connect(self.on_item_changed)

        left_layout = QVBoxLayout()
        left_layout.addWidget(self.search_box)
        left_layout.addWidget(self.view)
        left_frame = QFrame(self)
        left_frame.setLayout(left_layout)

        splitter = QSplitter(self)
        splitter.setOrientation(Qt.Horizontal)
        splitter.setChildrenCollapsible(False)
        splitter.setStyleSheet("QSplitter::handle:horizontal {background: qlineargradient(x1:0, y1:0, x2:1, y2:1, stop:0 #eee, stop:1 #ccc); border: 1px solid #777; width: 13px; margin-top: 2px; margin-bottom: 2px; border-radius: 4px;}")
        splitter.addWidget(left_frame)
        splitter.addWidget(self.desc_box)

        main_layout = QHBoxLayout()
        main_layout.addWidget(splitter)
        self.setLayout(main_layout)

    def search(self, text):
        self.proxy_model.setFilterRegularExpression(text.lower())

    def on_double_click(self, index):
        index = self.proxy_model.mapToSource(index)
        idx = index.row()
        command = self._data[idx]
        if command not in self.categories:
            self.window.insert_text_with_newline(command.nid)

    def on_item_changed(self, curr, prev):
        if curr.indexes():
            index = curr.indexes()[0]
            index = self.proxy_model.mapToSource(index)
            idx = index.row()
            command = self._data[idx]
            if command not in self.categories:
                # command name
                if command.nickname:
                    text = '**%s**' % command.nickname
                else:
                    text = '**%s**' % command.nid
                text += ';'

                # command keywords
                i = 0
                all_keywords = command.keywords + command.optional_keywords
                for i, kwyd in enumerate(all_keywords):
                    next_text = kwyd
                    if command.keyword_types:
                        next_text = next_text + '=' + command.keyword_types[i]
                    if not i < len(command.keywords): # it's an optional
                        next_text = '_' + next_text + '_'
                    next_text += ';'
                    text += next_text
                if command.flags:
                    text += '_flags_'
                else:
                    if text[-1] == ';':
                        text = text[:-1]
                text += '\n\n'
                if command.flags:
                    text += '_Optional Flags:_ ' + ';'.join(command.flags) + '\n\n'
                text += " --- \n\n"
                already = []
                for keyword in command.keywords + command.optional_keywords:
                    if keyword in already:
                        continue
                    else:
                        already.append(keyword)
                    validator = event_validators.get(keyword)
                    if validator and validator().desc:
                        text += '_%s_ %s\n\n' % (keyword, str(validator().desc))
                    else:
                        text += '_%s_ %s\n\n' % (keyword, "")
                if command.desc:
                    text += " --- \n\n"
                text += str(command.desc)
                self.desc_box.setMarkdown(text)
            else:
                self.desc_box.setMarkdown(command + ' Section')
        else:
            self.desc_box.setMarkdown('')

class EventCommandModel(CollectionModel):
    def __init__(self, data, categories, window):
        super().__init__(data, window)
        self.categories = categories

    def get_text(self, command) -> str:
        full_text = command.nid + ';'.join(command.keywords) + ';'.join(command.optional_keywords) + \
            ';'.join(command.flags) + ':' + str(command.desc)
        return full_text

    def data(self, index, role):
        if not index.isValid():
            return None
        if role == Qt.DisplayRole:
            command = self._data[index.row()]
            if command in self.categories:
                category = command
                # We want to include the header if any of it's children are counted
                return '-'.join([self.get_text(command).lower() for command in self._data if command not in self.categories and command.tag == category])
            else:
                return self.get_text(command).lower()

class CommandDelegate(QStyledItemDelegate):
    def __init__(self, data, parent=None):
        super().__init__(parent=None)
        self.window = parent
        self._data = data

    def sizeHint(self, option, index):
        index = self.window.proxy_model.mapToSource(index)
        command = self._data[index.row()]
        if hasattr(command, 'nid'):
            return QSize(0, 24)
        else:
            return QSize(0, 32)

    def paint(self, painter, option, index):
        index = self.window.proxy_model.mapToSource(index)
        command = self._data[index.row()]
        rect = option.rect
        left = rect.left()
        right = rect.right()
        top = rect.top()
        bottom = rect.bottom()
        if option.state & QStyle.State_Selected:
            palette = QApplication.palette()
            color = palette.color(QPalette.Highlight)
            painter.fillRect(rect, color)
        font = painter.font()
        if hasattr(command, 'nid'):
            font.setBold(True)
            font_height = QFontMetrics(font).lineSpacing()
            painter.setFont(font)
            painter.drawText(left, top + font_height, command.nid)
            horiz_advance = QFontMetrics(font).horizontalAdvance(command.nid)
            font.setBold(False)
            painter.setFont(font)
            keywords = ";".join(command.keywords)
            if keywords:
                painter.drawText(left + horiz_advance, top + font_height, ";" + keywords)
        else:
            prev_size = font.pointSize()
            font.setPointSize(prev_size + 4)
            font_height = QFontMetrics(font).lineSpacing()
            painter.setFont(font)
            painter.drawText(left, top + font_height, command)
            font.setPointSize(prev_size)
            painter.setFont(font)
            painter.drawLine(left, top + 1.25 * font_height, right, top + 1.25 * font_height)
