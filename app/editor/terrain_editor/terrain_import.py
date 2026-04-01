import xml.etree.ElementTree as ET

from app.utilities import utils, str_utils
from app.data.database.database import DB
from app.data.database import terrain

def get_from_xml(parent_dir: str, xml_fn: str) -> list:
    terrain_xml = ET.parse(xml_fn)
    terrain_list = []
    for terra in terrain_xml.getroot().findall('terrain'):
        nids = DB.terrain.keys()
        nid = str_utils.get_next_name(terra.find('id').text, nids)
        name = terra.get('name')
        color = tuple(utils.clamp(int(_), 0, 255) for _ in terra.find('color').text.split(','))
        minimap = terra.find('minimap').text
        platform = terra.find('platform').text
        mtype = terra.find('mtype').text
        if mtype not in DB.mcost.terrain_types:
            mtype = DB.mcost.terrain_types[0]

        new_terrain = terrain.Terrain(nid, name, color, minimap, platform, mtype)
        terrain_list.append(new_terrain)
    return terrain_list
