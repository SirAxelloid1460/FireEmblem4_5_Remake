import math
from collections import namedtuple
from enum import Enum
from typing import Tuple

from PyQt5 import QtWidgets
from PyQt5 import QtCore

from app.data.database.database import DB
# Data
from app.data.database.overworld import OverworldPrefab
from app.data.database.overworld_node import OverworldNodePrefab
# Components
from app.editor.lib.components.dock import Dock
# utils
from app.editor.lib.math.math_utils import distance_from_line
from app.editor.lib.state_editor.state_enums import MainEditorScreenStates
# Application State
from app.editor.settings import MainSettingsController
from app.editor.world_map_view import WorldMapView
from app.utilities import str_utils, utils
from app.utilities.typing import Point
from PyQt5.QtCore import Qt
from PyQt5.QtGui import QIcon
from PyQt5.QtWidgets import QAction, QDockWidget, QMainWindow, QLabel, QFrame

from .node_properties import NodePropertiesMenu
from .overworld_properties import OverworldPropertiesMenu


class OverworldEditorEditMode(Enum):
    NONE = 0
    NODES = 1

class OverworldEditorInternalTypes(Enum):
    NONE = 0
    # distinguishing between unfinished and finished roads is useful for context
    UNFINISHED_ROAD = 1
    FINISHED_ROAD = 2
    MAP_NODE = 3

SelectedObject = namedtuple('SelectedObject', ['type', 'obj'])

class OverworldEditor(QMainWindow):
    def __init__(self, state_manager):
        super().__init__()
        self.state_manager = state_manager
        self.settings = MainSettingsController()
        self._initialize_editor_components()
        self._initialize_window_components()
        self._initialize_subscriptions()

        # editor state
        self.set_current_overworld(self.state_manager.state.selected_overworld)
        self.edit_mode = OverworldEditorEditMode.NONE
        self.selected_object = SelectedObject(type=OverworldEditorInternalTypes.NONE, obj=None)

    @property
    def double_fit_ghost_road(self) -> bool:
        modifiers = QtWidgets.QApplication.keyboardModifiers()
        if modifiers == QtCore.Qt.ShiftModifier:
            return False
        return True

    @property
    def selected_object(self):
        return self._selected_object

    @selected_object.setter
    def selected_object(self, sel: SelectedObject):
        """contains the selected object

        Args:
            sel SelectedObject(OverworldEditorInternalTypes type, Union(NodePrefab, list, None) obj):
                internal type. 'obj' is either a node (NodePrefab), or a list (road array) or None, which means deselect
        """
        self._selected_object = sel
        obj = sel.obj
        if sel.type == OverworldEditorInternalTypes.MAP_NODE:
            # is a node
            self.map_view.set_selected(obj.pos)
            self.state_manager.change_and_broadcast('selected_node', obj.nid)
        elif sel.type == OverworldEditorInternalTypes.FINISHED_ROAD:
            # is a road
            self.map_view.set_selected(obj)
        else:
            # deselect
            self.map_view.set_selected(obj)
            self.state_manager.change_and_broadcast('selected_node', None)

    @selected_object.deleter
    def selected_object(self):
        """Deletes the selected_object from the DB (if necessary) and resets the selection.
        """
        sel = self.selected_object
        if sel.type == OverworldEditorInternalTypes.UNFINISHED_ROAD:
            # this requires no special treatment; the road will be obliterated upon deselection
            pass
        elif sel.type == OverworldEditorInternalTypes.FINISHED_ROAD:
            # delete current road from overworld
            current_road = sel.obj
            road_key = OverworldPrefab.points_to_key(current_road[0], current_road[-1])
            if not self.current_overworld.map_paths.pop(road_key, None):
                # this shouldn't happen, but in the interest of supporting legacy data:
                reverse_road_key = str(tuple(current_road[-1])) + '-' + str(tuple(current_road[0]))
                self.current_overworld.map_paths.pop(reverse_road_key, None)
                reverse_road_key = str(tuple(current_road[0])) + '-' + str(tuple(current_road[-1]))
                self.current_overworld.map_paths.pop(reverse_road_key, None)
        elif sel.type == OverworldEditorInternalTypes.MAP_NODE:
            # delete node from overworld
            current_node = sel.obj
            nid_to_delete = current_node.nid
            self.current_overworld.overworld_nodes.remove_key(nid_to_delete)
        # reset selection
        self.selected_object = SelectedObject(type=OverworldEditorInternalTypes.NONE, obj=None)

    def set_current_overworld(self, overworld_nid):
        self.current_overworld = DB.overworlds.get(overworld_nid)

    def on_map_double_left_click(self, x, y):
        if self.edit_mode == OverworldEditorEditMode.NODES:
            self.create_node(x, y)

    def on_map_right_click(self, x, y):
        if self.edit_mode == OverworldEditorEditMode.NODES:
            self.edit_road(x, y)

    def on_map_left_click(self, x, y):
        """Left click handler. NB: this uses float granularity (see where it's bound in this class)

        Args:
            x (float): float-granular x-coordinate of click
            y (float): float-granular y-coordinate of click
        """
        if self.edit_mode == OverworldEditorEditMode.NODES:
            self.select_object_on_map(x, y)

    def on_map_hover(self, x, y):
        self.set_position_bar((x, y))
        if self.selected_object.type == OverworldEditorInternalTypes.UNFINISHED_ROAD:
            first_point = self.lock_angle(self.selected_object.obj[-1], (x, y), self.double_fit_ghost_road)
            second_point = self.lock_angle(first_point, (x, y), self.double_fit_ghost_road)
            if not self.double_fit_ghost_road:
                second_point = first_point
            self.map_view.set_ghost_road_endpoint([first_point, second_point])
        elif self.selected_object.type == OverworldEditorInternalTypes.MAP_NODE:
            first_point = self.lock_angle(self.selected_object.obj.pos, (x, y), self.double_fit_ghost_road)
            second_point = self.lock_angle(first_point, (x, y), self.double_fit_ghost_road)
            if not self.double_fit_ghost_road:
                second_point = first_point
            self.map_view.set_ghost_road_endpoint([first_point, second_point])
        else:
            self.map_view.set_ghost_road_endpoint(None)

    def keyPressEvent(self, event):
        if event.key() == Qt.Key_Delete:
            del self.selected_object
        elif event.key() == Qt.Key_Space:
            self.map_view.should_draw_ghost = not self.map_view.should_draw_ghost

    def create_node(self, x, y):
        """Function handles node creation.

        Args:
            x (int): x-coord of cell of click
            y (int): y-coord of cell of click
        """
        node = self.find_node(x, y)
        if(node):
            # node already exists, and you probably already selected it via the other method
            return
        else:
            # create a node and select it
            nids = []
            for overworld in DB.overworlds:
                for node in overworld.overworld_nodes:
                    nids.append(node.nid)
            next_nid = str(str_utils.get_next_int("0", nids))
            new_node = OverworldNodePrefab(next_nid, 'New Location', (x, y))
            self.current_overworld.overworld_nodes.append(new_node)
            self.selected_object = SelectedObject(type=OverworldEditorInternalTypes.MAP_NODE, obj=new_node)

    def select_object_on_map(self, x, y, search_radius=0.5, node_priority=0.2):
        """Handles selecting nearest object (road, node) to clicked coordinate.
        Selection is stored in self.selected_object.

        Note: Prioritizes nodes.

        Args:
            x (float): x-coordinate
            y (float): y-coordinate
            search_radius (float): coord range within which to search. Highly recommend this be below 1.
            node_priority (float): extra subtraction from node distance in order to prioritize nodes
        """
        closest_dist = search_radius
        closest_obj = None
        closest_obj_type = OverworldEditorInternalTypes.NONE

        # search through the nodes
        for node in self.current_overworld.overworld_nodes.values():
            distance = utils.distance((x, y), node.pos) - node_priority
            if distance < closest_dist:
                closest_dist = distance
                closest_obj = node
                closest_obj_type = OverworldEditorInternalTypes.MAP_NODE

        # search through the roads
        for road in self.current_overworld.map_paths.values():
            # sanity check
            if(len(road) < 2):
                continue
            for i in range(len(road) - 1):
                segment_begin = road[i]
                segment_end = road[i+1]
                distance = distance_from_line(segment_begin, segment_end, (x, y))
                if distance < closest_dist:
                    closest_dist = distance
                    closest_obj = road
                    closest_obj_type = OverworldEditorInternalTypes.FINISHED_ROAD

        self.selected_object = SelectedObject(type=closest_obj_type, obj=closest_obj)
        if closest_obj_type == OverworldEditorInternalTypes.FINISHED_ROAD:
            self.set_message("Selected road")
        elif closest_obj_type == OverworldEditorInternalTypes.MAP_NODE:
            self.set_message("Selected map node: %s" % closest_obj.nid)

    def lock_angle(self, prev_point: Point, next_point: Point, short=True) -> Point:
        """Roads can only run either horizontal/vertical, or in 45 degree angles.
        Therefore, when adding a new segment, we must 'lock' the new point to
        one of these angles relative to the old point.

        Args:
            prev_point (Point): point of reference
            next_point (Point): new point to lock
            short (bool): whether or not the segment should be short or long. Hard to describe.

        Returns:
            Point: adjusted point that is correctly angled from the old point.
        """
        segment_vec = utils.tuple_sub(next_point, prev_point)
        seg_y = abs(segment_vec[1])
        seg_x = abs(segment_vec[0])

        snapped_vec: Tuple[int, int] = (0, 0)
        if seg_y * math.sqrt(3) < seg_x: # we're at a low angle, snap horizontal
            if short:
                # ask @mag about this logic, it's a bit confusing. This is meant to prepare
                # lock_angle for usage with two-segment flexible fits
                segment_len = abs(abs(seg_x) - abs(seg_y))
            else:
                segment_len = max(seg_x, seg_y)

            snapped_vec = (segment_len * utils.sign(segment_vec[0]), 0)
        elif seg_y > seg_x * math.sqrt(3): # we're at a high angle, snap vertical
            if short:
                segment_len = abs(abs(seg_x) - abs(seg_y))
            else:
                segment_len = max(seg_x, seg_y)
            snapped_vec = (0, segment_len * utils.sign(segment_vec[1]))
        else: # we're at a mid angle, snap 45
            if short:
                segment_len = min(seg_x, seg_y)
            else:
                segment_len = max(seg_x, seg_y)
            snapped_vec = (segment_len * utils.sign(segment_vec[0]), segment_len * utils.sign(segment_vec[1]))
        return utils.tuple_add(prev_point, snapped_vec)

    def edit_road(self, x: int, y: int):
        """Function handles road creation and termination.
        Contextually creates a road and enters road editing mode, appends
        the clicked coordinate to the current road being edited, or
        finishes and saves a road into the db.

        Args:
            x (int): x-coord of cell of click
            y (int): y-coord of cell of click
        """
        # pre-process based on what we had selected before
        if(self.selected_object.type == OverworldEditorInternalTypes.MAP_NODE):
            # we have a node selected; start drawing a road from it and make it our focused object
            node = self.selected_object.obj
            new_road = []
            new_road.append(node.pos)
            self.selected_object = SelectedObject(type=OverworldEditorInternalTypes.UNFINISHED_ROAD, obj=new_road)
        elif(self.selected_object.type == OverworldEditorInternalTypes.NONE or
             self.selected_object.type == OverworldEditorInternalTypes.FINISHED_ROAD):
            # nothing to do here, abandon
            return
        else:
            # we have a road in progress, continue
            pass

        # now we have a road in progress
        # process the node we just clicked on, but make sure to lock it first
        current_road = self.selected_object.obj
        xp, yp = self.lock_angle(current_road[-1], (x, y), self.double_fit_ghost_road)
        x, y = self.lock_angle((xp, yp), (x, y), self.double_fit_ghost_road)
        if not self.double_fit_ghost_road:
            x, y = xp, yp

        # make sure our midpoint isn't accidentally ending the road
        if (xp, yp) != (x, y):
            if self.find_node(xp, yp):
                return

        other_node = self.find_node(x, y)
        if (other_node):
            # we clicked on another node; terminate our road and save into prefab
            if (x, y) not in current_road:
                if (xp, yp) != (x, y):
                    current_road.append((xp, yp))
                current_road.append((x, y))
                start_point = current_road[0]
                end_point = current_road[-1]
                self.current_overworld.map_paths[OverworldPrefab.points_to_key(start_point, end_point)] = current_road
                # select the node to clean up
                self.selected_object = SelectedObject(type=OverworldEditorInternalTypes.MAP_NODE, obj=other_node)
        else:
            # we clicked on empty space, add it to our road
            if (x, y) not in current_road and (xp, yp) not in current_road:
                if (xp, yp) != (x, y):
                    current_road.append((xp, yp))
                current_road.append((x, y))
            self.selected_object = SelectedObject(type=OverworldEditorInternalTypes.UNFINISHED_ROAD, obj=current_road)

    def find_node(self, x, y):
        if self.current_overworld:
            for node in self.current_overworld.overworld_nodes:
                if node.pos == (x, y):
                    return node

    """=========Editor UI related functions========="""

    def _initialize_editor_components(self):
        self.map_view = WorldMapView()
        self._connect_listeners()
        self.setCentralWidget(self.map_view)
        self._initialize_docks()

        self.create_statusbar()

    def create_statusbar(self):
        self.status_bar = self.statusBar()
        self.position_bar = QLabel("", self)
        self.position_bar.setFrameStyle(QFrame.Panel | QFrame.Sunken)
        self.position_bar.setMinimumWidth(100)
        self.status_bar.addPermanentWidget(self.position_bar)

    def set_position_bar(self, pos):
        if pos:
            self.position_bar.setText("Position (%d, %d)" % (pos[0], pos[1]))
        else:
            self.position_bar.setText("")

    def set_message(self, msg):
        if msg:
            self.status_bar.showMessage(msg)
        else:
            self.status_bar.clearMessage()

    def _initialize_docks(self):
        self.docks = {}

        self.docks['Properties']= Dock(
            'Properties', self, self.on_property_tab_select)
        self.properties_menu = OverworldPropertiesMenu(self.state_manager)
        self.docks['Properties'].setWidget(self.properties_menu)

        self.docks['Node Editor'] = Dock(
            'Node Editor', self, self.on_node_tab_select)
        self.node_menu = NodePropertiesMenu(self.state_manager)
        self.docks['Node Editor'].setWidget(self.node_menu)

        for title, dock in self.docks.items():
            dock.setAllowedAreas(Qt.RightDockWidgetArea)
            dock.setFeatures(QDockWidget.NoDockWidgetFeatures)
            self.addDockWidget(Qt.RightDockWidgetArea, dock)

        self.tabifyDockWidget(self.docks['Properties'], self.docks['Node Editor'])

        for title, dock in self.docks.items():
            dock.show()

        self.docks['Properties'].raise_()

    def _connect_listeners(self):
        self.map_view.position_double_clicked.connect(self.on_map_double_left_click)
        self.map_view.position_clicked_float.connect(self.on_map_left_click)
        self.map_view.position_right_clicked.connect(self.on_map_right_click)
        self.map_view.position_moved.connect(self.on_map_hover)

    def on_node_tab_select(self, visible):
        if visible:
            self.edit_mode = OverworldEditorEditMode.NODES
            self.set_message(" L-click to select a node or road."
                             " R-click to place a road, L-click to cancel current road."
                             " Del to delete current selected object."
                             " Double L-click to create a new node."
                             " Space to toggle road guide."
                             " Hold Shift to lock road guide to a straight line.")

    def on_property_tab_select(self, visible):
        if visible:
            self.edit_mode = OverworldEditorEditMode.NONE
            self.set_message("Edit Overworld Properties")

    def update_view(self, _=None):
        self.map_view.update_view()

    def _initialize_subscriptions(self):
        self.state_manager.subscribe_to_key(OverworldEditor.__name__, 'selected_overworld', self.set_current_overworld)
        self.state_manager.subscribe_to_key(OverworldEditor.__name__, 'ui_refresh_signal', self.update_view)
        self.state_manager.subscribe_to_key(WorldMapView.__name__, 'selected_overworld', self.map_view.set_current_level)

    """=========MainEditorWindow related functions========="""

    def navigate_to_global(self):
        self.state_manager.change_and_broadcast('main_editor_mode', MainEditorScreenStates.GLOBAL_EDITOR)

    def _initialize_window_components(self):
        self.create_actions()
        self.set_icons()

    def create_actions(self):
        # menu actions
        self.zoom_in_act = QAction(
            "Zoom in", self, shortcut="Ctrl++", triggered=self.map_view.zoom_in)
        self.zoom_out_act = QAction(
            "Zoom out", self, shortcut="Ctrl+-", triggered=self.map_view.zoom_out)
        # toolbar actions
        self.back_to_main_act = QAction(
            "Back", self, shortcut="E", triggered=self.navigate_to_global)

    def set_icons(self):
        theme = self.settings.get_theme(0)
        if theme == 0:
            icon_folder = 'icons/icons'
        else:
            icon_folder = 'icons/dark_icons'
        self.zoom_in_act.setIcon(QIcon(f'{icon_folder}/zoom_in.png'))
        self.zoom_out_act.setIcon(QIcon(f'{icon_folder}/zoom_out.png'))
        self.back_to_main_act.setIcon(QIcon(f'{icon_folder}/left_arrow.png'))

    def create_toolbar(self, toolbar):
        toolbar.addAction(self.back_to_main_act, 0)

    def create_menus(self, app_menu_bar):
        edit_menu = app_menu_bar.getMenu('Edit')
        edit_menu.addSeparator()
        edit_menu.addAction(self.zoom_in_act)
        edit_menu.addAction(self.zoom_out_act)
