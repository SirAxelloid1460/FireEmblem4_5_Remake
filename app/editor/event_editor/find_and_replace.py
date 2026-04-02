import re

from PyQt5.QtWidgets import QWidget, QLineEdit, QLabel, \
    QDialog, QPushButton, QRadioButton, QCheckBox, QGridLayout
from PyQt5.QtGui import QTextCursor

class Find(QDialog):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.window = parent

        self.last_match = None

        self.init_ui()

    def init_ui(self):
        find_button = QPushButton("Find", self)
        find_button.clicked.connect(self.find)

        replace_button = QPushButton("Replace", self)
        replace_button.clicked.connect(self.replace)

        all_button = QPushButton("Replace all", self)
        all_button.clicked.connect(self.replace_all)

        self.normal_radio = QRadioButton("Normal", self)
        self.normal_radio.toggled.connect(self.normal_mode)

        self.regex_radio = QRadioButton("RegEx", self)
        self.regex_radio.toggled.connect(self.regex_mode)

        self.find_field = QLineEdit(self)

        self.replace_field = QLineEdit(self)

        options_label = QLabel("Options: ", self)

        self.case_sens = QCheckBox("Case sensitive", self)
        self.whole_words = QCheckBox("Whole words", self)

        layout = QGridLayout()

        layout.addWidget(self.find_field, 1, 0, 1, 4)
        layout.addWidget(self.normal_radio, 2, 2)
        layout.addWidget(self.regex_radio, 2, 3)
        layout.addWidget(find_button, 2, 0, 1, 2)

        layout.addWidget(self.replace_field, 3, 0, 1, 4)
        layout.addWidget(replace_button, 4, 0, 1, 2)
        layout.addWidget(all_button, 4, 2, 1, 2)

        spacer = QWidget(self)
        spacer.setFixedSize(0, 10)
        layout.addWidget(spacer, 5, 0)

        layout.addWidget(options_label, 6, 0)
        layout.addWidget(self.case_sens, 6, 1)
        layout.addWidget(self.whole_words, 6, 2)

        self.setWindowTitle("Find and Replace")
        self.setLayout(layout)

        self.normal_radio.setChecked(True)

    def find(self):
        text = self.window.text_box.toPlainText()
        query = self.find_field.text()

        if self.whole_words.isChecked():
            query = r'\W' + query + r'\W'

        if self.normal_radio.isChecked():
            query = re.escape(query)

        flags = 0 if self.case_sens.isChecked() else re.I
        try:
            pattern = re.compile(query, flags)
        except:
            # todo(rainlash): display an error message for invalid regex or smth
            return
        start = self.last_match.start() + 1 if self.last_match else 0
        self.last_match = pattern.search(text, start)

        if self.last_match:
            start = self.last_match.start()
            end = self.last_match.end()

            if self.whole_words.isChecked():
                start += 1
                end -= 1

            self.moveCursor(start, end)
            return (start, end)

        else:
            self.window.text_box.moveCursor(QTextCursor.End)
            return None

    def replace(self):
        cursor = self.window.text_box.textCursor()
        if self.last_match and cursor.hasSelection():
            cursor.insertText(self.replace_field.text())
            self.window.text_box.setTextCursor(cursor)

    def replace_all(self):
        self.last_match = None  # To start from beginning of document
        all_finds = []
        all_finds.append(self.find())
        while self.last_match:
            all_finds.append(self.find())
        all_finds.pop()  # Remove last one which failed

        # Now actually do the replacing
        change_in_length = 0
        for start, end in all_finds:
            orig_length = end - start
            new_length = len(self.replace_field.text())
            self.moveCursor(start + change_in_length, end + change_in_length)
            change_in_length += (new_length - orig_length)
            self.last_match = True
            self.replace()

        self.last_match = None

    def regex_mode(self):
        self.case_sens.setChecked(False)
        self.whole_words.setChecked(False)

        self.case_sens.setEnabled(False)
        self.whole_words.setEnabled(False)

    def normal_mode(self):
        self.case_sens.setEnabled(True)
        self.whole_words.setEnabled(True)

    def moveCursor(self, start, end):
        cursor = self.window.text_box.textCursor()
        cursor.setPosition(start)
        cursor.movePosition(QTextCursor.Right, QTextCursor.KeepAnchor, end - start)
        self.window.text_box.setTextCursor(cursor)
