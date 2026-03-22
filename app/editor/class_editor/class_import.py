import os
import xml.etree.ElementTree as ET

from app.utilities import str_utils, utils
from app.data.resources.resources import RESOURCES
from app.data.database.database import DB
from app.data.database.klass import Klass

import logging

def get_from_xml(parent_dir: str, xml_fn: str) -> list:
    class_xml = ET.parse(xml_fn)
    class_list = []
    for klass in class_xml.getroot().findall('class'):
        nids = DB.classes.keys()
        nid = str_utils.get_next_name(klass.get('id'), nids)
        name = klass.find('long_name').text
        desc = klass.find('desc').text
        tier = utils.clamp(int(klass.find('tier').text), 1, 5)

        mgroup_idx = int(klass.find('movement_group').text)
        if len(DB.mcost.unit_types) > mgroup_idx:
            movement_group = DB.mcost.unit_types[mgroup_idx]
        else:
            movement_group = DB.mcost.unit_types[0]
        promotes_from = klass.find('promotes_from').text if klass.find('promotes_from') is not None else None
        turns_into = klass.find('turns_into').text.split(',') if klass.find('turns_into').text is not None else []
        tags = klass.find('tags').text.split(',') if klass.find('tags').text is not None else []
        max_level = int(klass.find('max_level').text) if klass.find('max_level') is not None else 20

        # Handle stats
        stat_list = ('HP', 'STR', 'MAG', 'SKL', 'SPD', 'LCK', 'DEF', 'RES', 'CON', 'MOV')
        klass_stats = str_utils.intify(klass.find('bases').text)
        bases = {nid: 0 for nid in DB.stats.keys()}
        for idx, num in enumerate(klass_stats):
            if stat_list[idx] in DB.stats.keys():
                bases[stat_list[idx]] = num
        klass_growths = str_utils.intify(klass.find('growths').text)
        growths = {nid: 0 for nid in DB.stats.keys()}
        for idx, num in enumerate(klass_growths):
            if stat_list[idx] in DB.stats.keys():
                growths[stat_list[idx]] = num
        klass_max = str_utils.intify(klass.find('max').text)
        maxes = {nid: 30 for nid in DB.stats.keys()}
        for idx, num in enumerate(klass_max):
            if stat_list[idx] in DB.stats.keys():
                maxes[stat_list[idx]] = num
        promotion = {nid: 0 for nid in DB.stats.keys()}
        if klass.find('promotion') is not None and klass.find('promotion').text is not None:
            klass_promotion = str_utils.intify(klass.find('promotion').text)
            for idx, num in enumerate(klass_promotion):
                if stat_list[idx] in DB.stats.keys():
                    promotion[stat_list[idx]] = num
        growth_bonus = {nid: 0 for nid in DB.stats.keys()}

        learned_skills = str_utils.skill_parser(klass.find('skills').text)

        # Create weapon experience
        wexp = klass.find('wexp_gain').text.split(',')
        wexp_gain = {weapon_nid: DB.weapons.default() for weapon_nid in DB.weapons.keys()}
        weapon_order = ['Sword', 'Lance', 'Axe', 'Bow', 'Staff', 'Light', 'Anima', 'Dark']
        if os.path.exists(parent_dir + '/weapon_triangle.txt'):
            with open(parent_dir + '/weapon_triangle.txt') as wfn:
                weapon_order = [l.strip().split(';')[0] for l in wfn.readlines() if l.strip()]
        for idx, w in enumerate(wexp):
            if w in DB.weapon_ranks.keys():
                num = DB.weapon_ranks.get(w).requirement
            else:
                num = int(w)
            try:
                if weapon_order[idx] in DB.weapons.keys():
                    gain = wexp_gain.get(weapon_order[idx])
                    gain.wexp_gain = num
                    if num > 0:
                        gain.usable = True
            except IndexError as e:
                logging.warning("Failed to determine weapon experience")

        icon_nid = 'Generic_Portrait_%s' % nid
        if icon_nid not in RESOURCES.icons80.keys():
            icon_nid = None
        icon_index = (0, 0)

        if nid in RESOURCES.map_sprites.keys():
            map_sprite_nid = nid
        else:
            map_sprite_nid = None

        new_class = Klass(
            nid, name, desc, tier, movement_group, promotes_from, turns_into,
            tags, max_level, bases, growths, growth_bonus, promotion, maxes,
            learned_skills, wexp_gain, icon_nid, icon_index, map_sprite_nid, None, [])
        class_list.append(new_class)

    # Turns into
    valid_nids = [_.nid for _ in class_list]
    for klass in class_list:
        klass.turns_into = [k for k in klass.turns_into if DB.classes.get(k) or k in valid_nids]
    return class_list
