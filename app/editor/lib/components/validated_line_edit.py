import re
from PyQt5.QtWidgets import QPushButton, QLineEdit
from PyQt5.QtCore import QSize, QRegExp
from PyQt5.QtGui import QRegExpValidator

# Custom Widgets
from app.utilities.data import Data
from app.data.database.database import DB

from app.extensions.custom_gui import PropertyBox, ComboBox

class BetterRegExpValidator(QRegExpValidator):
  def fixup(self, a0: str) -> str:
    return re.sub("[^A-Za-z0-9_]", '_', a0)

class NidLineEdit(QLineEdit):
  """For strict limiting on NID forms. Alphanumerics and underscore only.
  """
  def __init__(self, *args, **kwargs) -> None:
    super().__init__(*args, **kwargs)
    reg_ex = QRegExp(r"[A-Za-z0-9_]*")
    input_validator = BetterRegExpValidator(reg_ex, self)
    self.setValidator(input_validator)

class NoParentheticalLineEdit(QLineEdit):
  """Less limiting. Allows periods and spaces, but no parentheses.

  Also doesn't allow semicolons.
  """
  def __init__(self, *args, **kwargs) -> None:
    super().__init__(*args, **kwargs)
    reg_ex = QRegExp(r"[^\(\);]*")
    input_validator = QRegExpValidator(reg_ex, self)
    self.setValidator(input_validator)