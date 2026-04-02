from app.editor.lib.components.validated_line_edit import NidLineEdit
from PyQt5.QtWidgets import QVBoxLayout, QLineEdit, \
    QWidget, QPushButton, QMessageBox, QLabel, QComboBox, QHBoxLayout, QDialog, QCheckBox
from PyQt5.QtCore import Qt, QEvent
from app.events import node_events
from app.editor.base_database_gui import DragDropCollectionModel
from app.editor.custom_widgets import EventBox
from app.utilities.data import Data
from app.utilities import str_utils
from app.extensions.custom_gui import ComboBox, SimpleDialog, PropertyBox, PropertyCheckBox, QHLine, RightClickListView
from app.data.database.database import DB

class NodeEventPropertiesMenu(QWidget):
    def __init__(self, state_manager, parent=None):
        super().__init__(parent)
        self.window = parent
        self.state_manager = state_manager
        _layout = QVBoxLayout()

        self.view = RightClickListView(
            (None, None, None), parent=self)
        self.view.currentChanged = self.on_item_changed

        self._data = Data()
        self.model = OptionModel(self._data, self)
        self.view.setModel(self.model)

        _layout.addWidget(self.view)

        self.create_button = QPushButton("Create Event...")
        self.create_button.clicked.connect(self.create_event)
        _layout.addWidget(self.create_button)

        self.modify_option_widget = ModifyOptionsWidget(self._data, self)
        _layout.addWidget(self.modify_option_widget)

        self.setLayout(_layout)

        self.state_manager.subscribe_to_key(
            NodeEventPropertiesMenu.__name__, 'ui_refresh_signal', self._refresh_view)

    def _refresh_view(self, _=None):
        self.model.layoutChanged.emit()

    def update_list(self):
        self.state_manager.change_and_broadcast('ui_refresh_signal', None)

    def select(self, idx):
        index = self.model.index(idx)
        self.view.setCurrentIndex(index)

    def deselect(self):
        self.view.clearSelection()

    def on_item_changed(self, curr, prev):
        if self._data:
            opt = self._data[curr.row()]
            self.modify_option_widget.set_current(opt)

    def on_node_changed(self):
        if self._data:
            opt = self._data[0]
            self.modify_option_widget.set_current(opt)

    def get_current(self):
        for index in self.view.selectionModel().selectedIndexes():
            idx = index.row()
            if len(self._data) > 0 and idx < len(self._data):
                return self._data[idx]
        return None

    def create_event(self, example=None):
        nid = str_utils.get_next_name('New Event', self._data.keys())
        created_event = node_events.NodeMenuEvent(nid)
        self._data.append(created_event)
        self.modify_option_widget.setEnabled(True)
        self.model.update()
        # Select the event
        idx = self._data.index(created_event.nid)
        index = self.model.index(idx)
        self.view.setCurrentIndex(index)
        self.state_manager.change_and_broadcast('ui_refresh_signal', None)
        self.toggle_details()
        self.modify_option_widget.set_current(created_event)
        return created_event

    def set_data(self, node_data):
        self._data = node_data
        self.model._data = self._data
        self.model.update()
        self.modify_option_widget._data = self._data
        self.toggle_details()

    def toggle_details(self):
        if len(self._data):
            self.modify_option_widget.show()
        else:
            self.modify_option_widget.hide()

class OptionModel(DragDropCollectionModel):
    def data(self, index, role):
        if not index.isValid():
            return None
        if role == Qt.DisplayRole:
            opt = self._data[index.row()]
            text = opt.nid + ': ' + opt.option_name
            return text
        return None

    def new(self, idx):
        ok = self.window.create_event()
        if ok:
            self._data.move_index(len(self._data) - 1, idx + 1)
            self.layoutChanged.emit()

    def duplicate(self, idx):
        view = self.window.view
        obj = self._data[idx]
        new_nid = str_utils.get_next_name(obj.nid, self._data.keys())
        serialized_obj = obj.save()
        new_obj = node_events.NodeEvent.restore(serialized_obj)
        new_obj.nid = new_nid
        self._data.insert(idx + 1, new_obj)
        self.layoutChanged.emit()
        new_index = self.index(idx + 1)
        view.setCurrentIndex(new_index)
        return new_index

class ModifyOptionsWidget(QWidget):
    def __init__(self, data, parent=None, current=None):
        super().__init__(parent)
        self.window = parent
        self._data = data

        layout = QVBoxLayout()
        self.setLayout(layout)

        self.current = current

        self.opt_nid_box = PropertyBox("Menu Option ID", NidLineEdit, self)
        self.opt_nid_box.edit.textChanged.connect(self.option_nid_changed)
        self.opt_nid_box.edit.editingFinished.connect(self.option_nid_done_editing)
        layout.addWidget(self.opt_nid_box)

        self.option_name_box = PropertyBox("Display Name", QLineEdit, self)
        self.option_name_box.edit.textChanged.connect(self.sub_nid_changed)
        layout.addWidget(self.option_name_box)

        self.event_box = EventBox(self)
        self.event_box.edit.currentIndexChanged.connect(self.event_changed)
        layout.addWidget(self.event_box)

        self.visible_box = PropertyCheckBox("Visible in menu?", QCheckBox, self)
        self.visible_box.edit.stateChanged.connect(self.visibility_changed)
        layout.addWidget(self.visible_box)

        self.enabled_box = PropertyCheckBox("Can be selected?", QCheckBox, self)
        self.enabled_box.edit.stateChanged.connect(self.selectable_changed)
        layout.addWidget(self.enabled_box)

    def option_nid_changed(self, text):
        if self.current:
            self.current.nid = text
            self.window.update_list()

    def option_nid_done_editing(self):
        if not self.current:
            return
        # Check validity of nid!
        other_nids = [d.nid for d in self._data.values()
                      if d is not self.current]
        if self.current.nid in other_nids:
            QMessageBox.warning(self.window, 'Warning',
                                'Option ID %s already in use' % self.current.nid)
            self.current.nid = str_utils.get_next_name(
                self.current.nid, other_nids)
        self._data.update_nid(self.current, self.current.nid)
        self.window.update_list()

    def sub_nid_changed(self, text):
        self.current.option_name = text
        self.window.update_list()

    def event_changed(self, index):
        self.current.event = self.event_box.edit.currentText()

    def visibility_changed(self, state):
        self.current.visible = bool(state)

    def selectable_changed(self, state):
        self.current.enabled = bool(state)

    def set_current(self, current):
        self.current = current
        if DB.events:
            #This currently forces OW menu events to be limited to Global events
            #My preference would be to have OW be its own category of event, but that is not my judgement call to make
            self.event_box.model._data = [event for event in DB.events.get_by_level(None)]
            self.event_box.model.layoutChanged.emit()
        self.opt_nid_box.edit.setText(current.nid)
        self.option_name_box.edit.setText(current.option_name)
        if current.event:
            self.event_box.edit.setValue(current.event)
        else:
            self.event_box.edit.setValue(None)
        self.visible_box.edit.setChecked(bool(current.visible))
        self.enabled_box.edit.setChecked(bool(current.enabled))

