from dataclasses import dataclass
from enum import Enum
from app.utilities.data import Data, Prefab

class PermadeathOption(str, Enum):
    PLAYER_CHOICE = 'Player Choice'
    CLASSIC = 'Classic'
    CASUAL = 'Casual'

class GrowthOption(str, Enum):
    PLAYER_CHOICE = 'Player Choice'
    RANDOM = 'Random'
    FIXED = 'Fixed'
    DYNAMIC = 'Dynamic'

class RNGOption(str, Enum):
    CLASSIC = 'Classic'
    TRUE_HIT = 'True Hit'
    TRUE_HIT_PLUS = 'True Hit Plus'
    GRANDMASTER = 'Grandmaster'

@dataclass
class DifficultyModePrefab(Prefab):
    nid: str = None
    name: str = None
    color: str = 'green'

    permadeath_choice: PermadeathOption = PermadeathOption.PLAYER_CHOICE
    growths_choice: GrowthOption = GrowthOption.PLAYER_CHOICE
    rng_choice: RNGOption = RNGOption.TRUE_HIT

    player_bases: dict = None
    enemy_bases: dict = None
    boss_bases: dict = None

    player_growths: dict = None
    enemy_growths: dict = None
    boss_growths: dict = None

    player_autolevels: int = 0
    enemy_autolevels: int = 0
    boss_autolevels: int = 0

    promoted_autolevels_fraction: float = 1.0
    
    start_locked: bool = False

    def init_bases(self, db):
        self.player_bases = {k: 0 for k in db.stats.keys()}
        self.enemy_bases = {k: 0 for k in db.stats.keys()}
        self.boss_bases = {k: 0 for k in db.stats.keys()}

    def init_growths(self, db):
        self.player_growths = {k: 0 for k in db.stats.keys()}
        self.enemy_growths = {k: 0 for k in db.stats.keys()}
        self.boss_growths = {k: 0 for k in db.stats.keys()}

    def get_stat_titles(self):
        return ["Bases", "Growths"]

    def get_player_stat_lists(self):
        return [self.player_bases, self.player_growths]

    def get_enemy_stat_lists(self):
        return [self.enemy_bases, self.enemy_growths]

    def get_boss_stat_lists(self):
        return [self.boss_bases, self.boss_growths]

    def get_base_bonus(self, unit) -> dict:
        if unit.team in ('player', 'other'):
            return self.player_bases
        elif 'Boss' in unit.tags:
            return self.boss_bases
        else:
            return self.enemy_bases

    def get_growth_bonus(self, unit) -> dict:
        if unit.team in ('player', 'other'):
            return self.player_growths
        elif 'Boss' in unit.tags:
            return self.boss_growths
        else:
            return self.enemy_growths

    def get_difficulty_autolevels(self, unit) -> dict:
        if unit.team in ('player', 'other'):
            return self.player_autolevels
        elif 'Boss' in unit.tags:
            return self.boss_autolevels
        else:
            return self.enemy_autolevels

class DifficultyModeCatalog(Data[DifficultyModePrefab]):
    datatype = DifficultyModePrefab
