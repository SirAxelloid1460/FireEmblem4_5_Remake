from __future__ import annotations
from enum import Enum
from typing import Any, List
from app.engine.exp_calculator import ExpCalcType
from app.data.database.difficulty_modes import GrowthOption
from app.utilities.data import Data
from app.utilities.typing import NID

class ConstantType(Enum):
    BOOL = 1
    INT = 2
    FLOAT = 3
    STR = 4
    MUSIC = 5

class Constant(object):
    def __init__(self, nid: NID, name: str = '', attr: ConstantType | List[str] = ConstantType.BOOL, default_value: Any=False, tag='other'):
        self.nid: NID = nid
        self.name: str = name
        self.attr: ConstantType | List[str] = attr
        self.value: Any = default_value
        self.tag = tag

    def set_value(self, val):
        self.value = val

    def save(self):
        return (self.nid, self.value)

class ConstantCatalog(Data[Constant]):
    def save(self):
        return [elem.save() for elem in self._list]

    def restore(self, ser_data):
        # Assign each constant with the correct value
        for nid, value in ser_data:
            constant = self.get(nid)
            if constant:
                constant.value = value

    def value(self, const_nid):
        constant = self.get(const_nid)
        if constant:
            return constant.value
        raise ValueError("No such Constant %s" % const_nid)

    def total_items(self):
        return self.value('num_items') + self.value('num_accessories')

tags = ['title', 'features', 'inventory', 'line_of_sight', 'leveling', 'ai', 'wexp', 'other', 'hidden']

constants = ConstantCatalog([
    Constant('num_items', "Max number of Items in inventory", ConstantType.INT, 5, 'inventory'),
    Constant('num_accessories', "Max number of Accessories in inventory", ConstantType.INT, 0, 'inventory'),
    Constant('turnwheel', "Turnwheel", ConstantType.BOOL, False, 'features'),
    Constant('initiative', "Per Unit Initiative Order", ConstantType.BOOL, False, 'features'),
    Constant('fatigue', "Fatigue", ConstantType.BOOL, False, 'features'),
    Constant('reset_fatigue', "Automatically reset fatigue to 0 for benched units", ConstantType.BOOL, False, 'features'),
    Constant('minimap', "Enable Minimap", ConstantType.BOOL, True, 'features'),
    Constant('pairup', "Pair Up", ConstantType.BOOL, False, 'features'),
    Constant('limit_attack_stance', "Limit Attack Stance to first attack only", ConstantType.BOOL, False, 'features'),
    Constant('attack_stance_only', "Only attack stance allowed", ConstantType.BOOL, False, 'features'),
    Constant('player_pairup_only', "Only player units can pairup", ConstantType.BOOL, False, 'features'),
    Constant('lead', "Global Leadership Stars", ConstantType.BOOL, False, 'features'),
    Constant('bexp', "Bonus Experience", ConstantType.BOOL, False, 'features'),
    Constant('rd_bexp_lvl', "Always gain 3 stat-ups when using Bonus Exp.", ConstantType.BOOL, False, 'features'),
    Constant('support', "Supports", ConstantType.BOOL, False, 'features'),
    Constant('overworld', "Overworld", ConstantType.BOOL, False, 'features'),
    Constant('overworld_start', "Start in Overworld", ConstantType.BOOL, False, 'features'),
    Constant('unit_notes', "Unit Notes", ConstantType.BOOL, False, 'features'),
    Constant('crit', "Allow Criticals", ConstantType.BOOL, True, 'features'),
    Constant('trade', "Can trade items on map", ConstantType.BOOL, True, 'features'),
    Constant('growth_info', "Can view unit growths in Info Menu", ConstantType.BOOL, True, 'features'),
    Constant('glancing_hit', "Chance (%) to score a glancing hit", ConstantType.INT, 0, 'features'),
    Constant('backpropagate_difficulty_growths', "Apply difficulty bonus growths to past levels", ConstantType.BOOL, True, 'features'),
    Constant('traveler_time_decrement', "Timed skills applied to traveler units will decrease.", ConstantType.BOOL, False, 'features'),
    Constant('line_of_sight', "Force items and abilities to obey line of sight rules", ConstantType.BOOL, False, 'line_of_sight'),
    Constant('aura_los', "Force auras to obey line of sight rules", ConstantType.BOOL, False, 'line_of_sight'),
    Constant('fog_los', "Fog of War will also be affected by line of sight", ConstantType.BOOL, False, 'line_of_sight'),
    Constant('ai_fog_of_war', "AI will also be affected by Fog of War", ConstantType.BOOL, False, 'line_of_sight'),
    Constant('def_double', "Defender can double counterattack", ConstantType.BOOL, True, 'features'),
    Constant('unit_stats_as_bonus', "Add class stats to non-generic base stats", ConstantType.BOOL, False, 'leveling'),
    Constant('enemy_leveling', "Method for autoleveling generic units", [growth.value for growth in GrowthOption if growth != GrowthOption.PLAYER_CHOICE] + ["Match"], "Match", 'leveling'),
    Constant('auto_promote', "Units will promote automatically upon reaching max level", ConstantType.BOOL, False, 'leveling'),
    Constant('promote_skill_inheritance', "Promoted units will have the skills of their previous classes", ConstantType.BOOL, True, 'leveling'),
    Constant('promote_level_reset', "Promotion resets level back to 1", ConstantType.BOOL, True, 'leveling'),
    Constant('class_change_level_reset', "Class Change resets level back to 1", ConstantType.BOOL, False, 'leveling'),
    Constant('learn_skills_on_reclass', "Learn the appropriate skills of your new class when you reclass", ConstantType.BOOL, True, 'leveling'),
    Constant('learn_skills_on_promote', "Learn the appropriate skills of your new class when you promote", ConstantType.BOOL, True, 'leveling'),
    Constant('negative_growths', "Negative growth rates will reduce stats", ConstantType.BOOL, True, 'leveling'),
    Constant('class_change_same_tier', "Class Change only between classes of the same tier", ConstantType.BOOL, False, 'leveling'),
    Constant('generic_feats', "Generic units will be given random feats when appropriate", ConstantType.BOOL, False, 'leveling'),
    Constant('min_damage', "Min damage dealt by an attack", ConstantType.INT, 0),
    Constant('boss_crit', "Final blow on boss will use critical animation", ConstantType.BOOL, False, 'aesthetic'),
    Constant('battle_platforms', "Use battle platforms when battle backgrounds are on", ConstantType.BOOL, True, 'aesthetic'),
    Constant('roam_hide_hp', "Hide hp bars during free roam", ConstantType.BOOL, False, 'aesthetic'),
    Constant('autogenerate_grey_map_sprites', 'Automatically generate grey "wait" map sprites', ConstantType.BOOL, True, 'aesthetic'),
    Constant('convoy_on_death', "Items held by dead player units are sent to convoy", ConstantType.BOOL),
    Constant('repair_shop', "Access the Repair Shop in prep and base", ConstantType.BOOL, False),
    Constant('sound_room_in_codex', "Can access sound room from Codex menu in base", ConstantType.BOOL, True),
    Constant('give_and_take', "Units can give a unit after taking a unit", ConstantType.BOOL),
    Constant('combat_art_category', "Combat Arts get put in their own category in the menu", ConstantType.BOOL, False),
    Constant('reset_mana', "Mana resets to full for units upon completion of the chapter", ConstantType.BOOL),
    Constant('double_splash', "When doubling, splash/aoe damage applied on second strike", ConstantType.BOOL),
    Constant('num_save_slots', "Number of save slots", ConstantType.INT, 3, 'title'),
    Constant('sell_modifier', "Value multiplier when selling an item", ConstantType.FLOAT, 0.5, 'inventory'),
    Constant('attack_zero_hit', "Enemy AI attacks even if Hit is 0", ConstantType.BOOL, True, 'ai'),
    Constant('attack_zero_dam', "Enemy AI attacks even if Damage is 0", ConstantType.BOOL, True, 'ai'),
    Constant('zero_move', "Show Movement as 0 if AI does not move", ConstantType.BOOL, False, 'ai'),
    Constant('game_nid', "Game Unique Identifier", ConstantType.STR, "LT", 'title'),
    Constant('title', "Game Title", ConstantType.STR, "Lex Talionis Game", 'title'),
    Constant('title_particles', "Display particle effect on title screen", ConstantType.BOOL, True, 'title_screen'),
    Constant('music_main', "Music to play on title screen", ConstantType.MUSIC, None, 'music'),
    Constant('music_promotion', "Music to play on promotion", ConstantType.MUSIC, None, 'music'),
    Constant('music_class_change', "Music to play on class change", ConstantType.MUSIC, None, 'music'),
    Constant('restart_phase_music', "Restart phase music at beginning of new phase", ConstantType.BOOL, True, 'music'),
    Constant('restart_battle_music', "Restart battle music at beginning of each combat", ConstantType.BOOL, True, 'music'),
    Constant('kill_wexp', "Kills give double weapon exp", ConstantType.BOOL, True, 'wexp'),
    Constant('double_wexp', "Each hit when doubling grants weapon exp", ConstantType.BOOL, True, 'wexp'),
    Constant('miss_wexp', "Gain weapon exp even on miss", ConstantType.BOOL, True, 'wexp'),
    # Experience constants below
    Constant('exp_curve', "How linear the exp curve is; Higher = less linear", ConstantType.FLOAT, 0.035, 'exp'),
    Constant('exp_magnitude', "How much base exp is received for each interaction", ConstantType.FLOAT, 10, 'exp'),
    Constant('exp_offset', "Tries to keep player character this many levels above enemies", ConstantType.INT, 0, 'exp'),
    Constant('gexp_max', "Maximum exp that can be earned from a hit", ConstantType.FLOAT, 30, 'exp'),
    Constant('gexp_min', "Minimum exp that can be earned from a hit", ConstantType.FLOAT, 1, 'exp'),
    Constant('gexp_slope', "How sharply exp drops off", ConstantType.FLOAT, 0.25, 'exp'),
    Constant('gexp_intercept', "Exp earned by two equal-level units fighting", ConstantType.FLOAT, 10, 'exp'),
    Constant('exp_formula', "Which exp formula to use", [calcType.value for calcType in ExpCalcType], ExpCalcType.STANDARD.value, 'exp'),
    Constant('kill_multiplier', "Exp multiplier on kill", ConstantType.FLOAT, 3, 'exp'),
    Constant('boss_bonus', "Extra exp for killing a boss", ConstantType.INT, 40, 'exp'),
    Constant('min_exp', "Min exp gained in combat", ConstantType.INT, 1, 'exp'),
    Constant('default_exp', "Default exp gain", ConstantType.INT, 11, 'exp'),
    Constant('heal_curve', "How much to multiply the amount healed by to determine experience gain", ConstantType.FLOAT, 0, 'exp'),
    Constant('heal_magnitude', "Added to total exp for healing", ConstantType.INT, 0, 'exp'),
    Constant('heal_offset', "Modifies expected healing", ConstantType.INT, 11, 'exp'),
    Constant('heal_min', "Min exp gained for healing", ConstantType.INT, 11, 'exp'),
    # Hidden constants below
    Constant('dark_sprites', "Use darker map sprites", ConstantType.BOOL, False, 'hidden')
])
