from dataclasses import dataclass
from typing import Dict

from app.utilities.data import Data, Prefab
from app.data.database.weapons import WexpGain

@dataclass
class Klass(Prefab):
    nid: str = None
    name: str = None

    desc: str = ""
    tier: int = 1
    movement_group: str = None

    promotes_from: str = None
    turns_into: list = None
    tags: list = None
    max_level: int = 20

    bases: dict = None
    growths: dict = None
    growth_bonus: dict = None
    promotion: dict = None
    max_stats: dict = None

    learned_skills: list = None
    wexp_gain: dict = None

    icon_nid: str = None
    icon_index: tuple = (0, 0)
    map_sprite_nid: str = None
    combat_anim_nid: str = None

    fields: list = None # arbitrary field, allow players to fill out anything they want for XTRA POWERFUL SCRIPTING

    def get_stat_titles(self):
        return ['Generic Bases', 'Generic Growths', 'Promotion Gains', 'Growth Bonuses', 'Stat Maximums']

    def get_stat_lists(self):
        return [self.bases, self.growths, self.promotion, self.growth_bonus, self.max_stats]

    def get_skills(self):
        return [skill[1] for skill in self.learned_skills]

    def replace_skill_nid(self, old_nid, new_nid):
        for skill in self.learned_skills:
            if skill[1] == old_nid:
                skill[1] = new_nid

    def promotion_options(self, db) -> list:
        return [option for option in self.turns_into if db.classes.get(option).tier == self.tier + 1]

    def save_attr(self, name, value):
        if name in ('bases', 'growths', 'growth_bonus', 'promotion', 'max_stats', 'fields', 'tags'):
            return value.copy()  # So we don't make a copy
        elif name == 'learned_skills':
            return [val.copy() for val in value]  # So we don't make a copy
        elif name == 'wexp_gain':
            return {k: v.save() for (k, v) in self.wexp_gain.items()}
        else:
            return super().save_attr(name, value)

    def restore_attr(self, name, value):
        if name in ('bases', 'growths', 'growth_bonus', 'promotion', 'max_stats'):
            if isinstance(value, list):
                value = {k: v for (k, v) in value}
            else:
                value = value
        elif name == 'wexp_gain':
            if isinstance(value, list):
                value = {nid: WexpGain(usable, wexp_gain) for (usable, nid, wexp_gain) in value}
            else:
                value = {k: WexpGain(usable, wexp_gain) for (k, (usable, wexp_gain)) in value.items()}
        elif name == 'fields':
            if value is None:
                return []
        else:
            value = super().restore_attr(name, value)
        return value

class ClassCatalog(Data[Klass]):
    datatype = Klass