from PyQt5.QtWidgets import QListWidget
from PyQt5.QtCore import pyqtSignal

class WidgetList(QListWidget):
    order_swapped = pyqtSignal(int, int)
    
    def __init__(self, parent):
        super().__init__(parent)
        self.window = parent
        self.index_list = []

        self.setDragEnabled(True)
        self.setAcceptDrops(True)
        self.setDragDropMode(4)  # Internal Move

        self.model().rowsMoved.connect(self.row_moved)

    def clear(self):
        super().clear()
        self.index_list.clear()

    def row_moved(self, parent, start, end, destination, row):
        elem = self.index_list.pop(start)
        if row > start:
            self.index_list.insert(row - 1, elem)
            self.order_swapped.emit(start, row - 1)
        else:
            self.index_list.insert(row, elem)
            self.order_swapped.emit(start, row)
