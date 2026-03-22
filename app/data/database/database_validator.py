from app.data.database.weapons import WexpGain
from dataclasses import dataclass
import logging
from app.data.database.database import Database
from app.utilities.typing import NID
import re
from typing import Callable, Dict, List, Set

@dataclass
class ValidationError():
    category: str
    owner: str
    where: str
    what: str

    def __str__(self) -> str:
        return "Error in %s:%s:%s - %s" % self.category, self.owner, self.where, self.what

    @classmethod
    def does_not_exist(self, nid):
        return "%s does not exist" % nid

class DatabaseValidatorEngine():
    def __init__(self, db: Database):
        self.db = db

    def validate_unit(self, unit_nid):
        return unit_nid in self.db.units.keys()

    def validate_wtype(self, wtype_nid):
        return wtype_nid in self.db.weapons.keys()

    def validate_wrank(self, wrank_nid):
        return wrank_nid in self.db.weapons.keys()

    def validate_class(self, klass_nid):
        return klass_nid in self.db.classes.keys()

    def validate_tag(self, tag_nid):
        return tag_nid in self.db.tags.keys()

    def validate_item(self, item_nid):
        return item_nid in self.db.items.keys()

    def validate_skill(self, skill_nid):
        return skill_nid in self.db.skills.keys()

    def validate_stat(self, stat_nid):
        return stat_nid in self.db.stats.keys()

    def validate_units(self):
        errors: List[ValidationError] = []
        for unit in self.db.units:
            if not self.validate_class(unit.klass):
                errors.append(ValidationError("Units", unit.nid, "klass", ValidationError.does_not_exist(unit.klass)))
        return errors

    def validate(self):
        # @TODO(mag): WIP
        errors: List[ValidationError] = []
        errors += self.validate_units()
        for error in errors:
            logging.error("validation failed: %s", error)
        return errors

    def fill_and_trim(self, data_dict: dict, expected_keys: set, real_keys: set, default_value_factory: Callable):
        missing_keys = expected_keys - real_keys
        extraneous_keys = real_keys - expected_keys
        for key in missing_keys:
            data_dict[key] = default_value_factory()
        for key in extraneous_keys:
            del data_dict[key]

    def repair_units(self):
        all_weapon_types = set(self.db.weapons.keys())
        all_stats = set(self.db.stats.keys())
        for unit in self.db.units:
            # make sure each unit has an entry for every weapon type, and no extraneous ones
            self.fill_and_trim(unit.wexp_gain, all_weapon_types, set(unit.wexp_gain.keys()), lambda: WexpGain(False, 0))
            # make sure each unit has an entry for every stat, and no extraneous ones
            self.fill_and_trim(unit.bases, all_stats, set(unit.bases.keys()), lambda: 0)
            self.fill_and_trim(unit.growths, all_stats, set(unit.growths.keys()), lambda: 0)

    def repair_klasses(self):
        all_weapon_types = set(self.db.weapons.keys())
        all_stats = set(self.db.stats.keys())
        for klass in self.db.classes:
            # make sure each klass has an entry for every weapon type, and no extraneous ones
            self.fill_and_trim(klass.wexp_gain, all_weapon_types, set(klass.wexp_gain.keys()), lambda: WexpGain(False, 0))
            # make sure each klass has an entry for every stat in all dicts
            self.fill_and_trim(klass.bases, all_stats, set(klass.bases.keys()), lambda: 0)
            self.fill_and_trim(klass.growths, all_stats, set(klass.growths.keys()), lambda: 0)
            self.fill_and_trim(klass.growth_bonus, all_stats, set(klass.growth_bonus.keys()), lambda: 0)
            self.fill_and_trim(klass.promotion, all_stats, set(klass.promotion.keys()), lambda: 0)
            self.fill_and_trim(klass.max_stats, all_stats, set(klass.max_stats.keys()), lambda: 0)

    def repair_levels(self):
        for level in self.db.levels:
            all_level_units = set(level.units.keys())
            travelers: Dict[NID, NID] = {}
            for unit in level.units:
                # fix phantom travelers
                unit_traveler = unit.starting_traveler
                if unit_traveler and unit_traveler == unit.nid:
                    logging.error("Unit %s is its own traveler", unit.nid)
                    unit.starting_traveler = None
                    continue
                if unit_traveler and unit_traveler in travelers:
                    logging.error("Found traveler %s originally on unit %s, found duplicate on unit %s in level %s",
                                  unit_traveler, travelers[unit_traveler], unit.nid, level.nid)
                    unit.starting_traveler = None
                    continue
                if unit_traveler and unit_traveler not in all_level_units:
                    logging.error("Found traveler %s on unit %s in level %s that does not exist",
                                  unit_traveler, unit.nid, level.nid)
                    unit.starting_traveler = None
                    continue
                if unit_traveler and level.units.get(unit_traveler) and level.units.get(unit_traveler).starting_position:
                    logging.error("Traveler %s on unit %s is already on map", unit_traveler, unit.nid)
                    unit.starting_traveler = None
                    continue
                travelers[unit_traveler] = unit.nid

    def repair(self):
        """Only obvious repairs should be done here.
        """
        self.repair_units()
        self.repair_klasses()
        self.repair_levels()