from PyQt5.QtGui import QIcon, QPixmap, QColor
from PyQt5.QtCore import Qt

from app.data.resources.resources import RESOURCES
from app.data.database.database import DB

from app.editor.base_database_gui import DragDropCollectionModel
from app.utilities import str_utils

from app.data.database import terrain

class TerrainModel(DragDropCollectionModel):
    def data(self, index, role):
        if not index.isValid():
            return None
        if role == Qt.DisplayRole:
            terrain = self._data[index.row()]
            text = terrain.nid + " : " + terrain.name
            return text
        elif role == Qt.DecorationRole:
            terrain = self._data[index.row()]
            color = terrain.color
            pixmap = QPixmap(32, 32)
            pixmap.fill(QColor(color[0], color[1], color[2]))
            return QIcon(pixmap)
        return None

    def create_new(self):
        nids = [d.nid for d in self._data]
        nid = name = str_utils.get_next_name("New Terrain", nids)
        terrain_mcost = DB.mcost.terrain_types[0]
        platform = RESOURCES.get_platform_types()[0][0]
        new_terrain = terrain.Terrain(nid, name, (0, 0, 0), 'Grass', platform, terrain_mcost)
        DB.terrain.append(new_terrain)
        return new_terrain
