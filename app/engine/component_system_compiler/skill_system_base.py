from __future__ import annotations
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from app.engine.objects.item import ItemObject
    from app.engine.objects.unit import UnitObject

class Defaults():
    @staticmethod
    def can_select(unit) -> bool:
        return unit.team == 'player'

    @staticmethod
    def check_ally(unit1, unit2) -> bool:
        if unit1 is unit2:
            return True
        elif unit1.team == 'player' or unit1.team == 'other':
            return unit2.team == 'player' or unit2.team == 'other'
        else:
            return unit2.team == unit1.team
        return False

    @staticmethod
    def check_enemy(unit1, unit2) -> bool:
        if unit1.team == 'player' or unit1.team == 'other':
            return not (unit2.team == 'player' or unit2.team == 'other')
        else:
            return not unit2.team == unit1.team
        return True

    @staticmethod
    def can_trade(unit1, unit2) -> bool:
        return unit1.team == unit2.team and check_ally(unit1, unit2) and not no_trade(unit1) and not no_trade(unit2)

    @staticmethod
    def no_trade(unit) -> bool:
        return False

    @staticmethod
    def num_items_offset(unit) -> int:
        return 0

    @staticmethod
    def num_accessories_offset(unit) -> int:
        return 0

    @staticmethod
    def witch_warp(unit) -> list:
        return []

    @staticmethod
    def exp_multiplier(unit1, unit2) -> float:
        return 1.0

    @staticmethod
    def enemy_exp_multiplier(unit1, unit2) -> float:
        return 1.0

    @staticmethod
    def wexp_multiplier(unit1, unit2) -> float:
        return 1.0

    @staticmethod
    def enemy_wexp_multiplier(unit1, unit2) -> float:
        return 1.0

    @staticmethod
    def wexp_usable_skill(unit1, unit2) -> float:
        return False

    @staticmethod
    def wexp_unusable_skill(unit1, unit2) -> float:
        return False

    @staticmethod
    def change_variant(unit) -> str:
        return unit.variant

    @staticmethod
    def change_animation(unit) -> str:
        return unit.klass

    @staticmethod
    def change_ai(unit) -> str:
        return unit.ai

    @staticmethod
    def change_roam_ai(unit) -> str:
        return unit.roam_ai

    @staticmethod
    def has_canto(unit1, unit2) -> bool:
        return False

    @staticmethod
    def empower_heal(unit1, unit2) -> int:
        return 0

    @staticmethod
    def empower_heal_received(unit2, unit1) -> int:
        return 0

    @staticmethod
    def canto_movement(unit, unit2) -> int:
        return unit.movement_left

    @staticmethod
    def limit_maximum_range(unit, item) -> int:
        return 1000

    @staticmethod
    def movement_type(unit):
        return None

    @staticmethod
    def sight_range(unit):
        return 0

    @staticmethod
    def empower_splash(unit):
        return 0

    @staticmethod
    def modify_buy_price(unit, item) -> float:
        return 1.0

    @staticmethod
    def modify_sell_price(unit, item) -> float:
        return 1.0

    @staticmethod
    def damage_formula(unit) -> str:
        return 'DAMAGE'

    @staticmethod
    def resist_formula(unit) -> str:
        return 'DEFENSE'

    @staticmethod
    def accuracy_formula(unit) -> str:
        return 'HIT'

    @staticmethod
    def avoid_formula(unit) -> str:
        return 'AVOID'

    @staticmethod
    def crit_accuracy_formula(unit) -> str:
        return 'CRIT_HIT'

    @staticmethod
    def crit_avoid_formula(unit) -> str:
        return 'CRIT_AVOID'

    @staticmethod
    def attack_speed_formula(unit) -> str:
        return 'ATTACK_SPEED'

    @staticmethod
    def defense_speed_formula(unit) -> str:
        return 'DEFENSE_SPEED'

    @staticmethod
    def critical_multiplier_formula(unit) -> str:
        return 'CRIT_MULT'

    @staticmethod
    def critical_addition_formula(unit) -> str:
        return 'CRIT_ADD'

    @staticmethod
    def thracia_critical_multiplier_formula(unit) -> str:
        return 'THRACIA_CRIT'

def condition(skill, unit: UnitObject, item=None) -> bool:
    if not item:
        item = unit.equipped_weapon
    for component in skill.components:
        if component.defines('condition'):
            if not component.condition(unit, item):
                return False
    return True

def is_grey(skill, unit) -> bool:
    return (not condition(skill, unit) and skill.grey_if_inactive)

def hidden(skill, unit) -> bool:
    return skill.hidden or skill.is_terrain or (skill.hidden_if_inactive and not condition(skill, unit))

def available(unit, item) -> bool:
    """
    If any hook reports false, then it is false
    """
    for skill in unit.skills:
        for component in skill.components:
            if component.defines('available'):
                if component.ignore_conditional or condition(skill, unit):
                    if not component.available(unit, item):
                        return False
    return True

def stat_change(unit, stat_nid) -> int:
    bonus = 0
    for skill in unit.skills:
        for component in skill.components:
            if component.defines('stat_change'):
                d = component.stat_change(unit)
                d_bonus = d.get(stat_nid, 0)
                if d_bonus == 0:
                    continue
                # Why did we write the component condition check after the evaluation of the bonus?
                # Was there a good reason?
                if component.ignore_conditional or condition(skill, unit):
                    bonus += d_bonus
    return bonus

def subtle_stat_change(unit, stat_nid) -> int:
    bonus = 0
    for skill in unit.skills:
        for component in skill.components:
            if component.defines('subtle_stat_change'):
                d = component.subtle_stat_change(unit)
                d_bonus = d.get(stat_nid, 0)
                if d_bonus == 0:
                    continue
                if component.ignore_conditional or condition(skill, unit):
                    bonus += d_bonus
    return bonus

def stat_change_contribution(unit, stat_nid) -> dict:
    contribution = {}
    for skill in unit.skills:
        for component in skill.components:
            if component.defines('stat_change') and not component.defines('subtle_stat_change'):
                if component.ignore_conditional or condition(skill, unit):
                    d = component.stat_change(unit)
                    val = d.get(stat_nid, 0)
                    if val != 0:
                        if skill.name in contribution:
                            contribution[skill.name] += val
                        else:
                            contribution[skill.name] = val
    return contribution

def growth_change(unit, stat_nid) -> int:
    bonus = 0
    for skill in unit.skills:
        for component in skill.components:
            if component.defines('growth_change'):
                if component.ignore_conditional or condition(skill, unit):
                    d = component.growth_change(unit)
                    bonus += d.get(stat_nid, 0)
    return bonus

def unit_sprite_flicker_tint(unit) -> list:
    flicker = []
    for skill in unit.skills:
        for component in skill.components:
            if component.defines('unit_sprite_flicker_tint'):
                if component.ignore_conditional or condition(skill, unit):
                    d = component.unit_sprite_flicker_tint(unit, skill)
                    flicker.append(d)
    return flicker

def should_draw_anim(unit) -> list:
    avail = []
    for skill in unit.skills:
        for component in skill.components:
            if component.defines('should_draw_anim'):
                if component.ignore_conditional or condition(skill, unit):
                    d = component.should_draw_anim(unit, skill)
                    avail.append(d)
    return avail

def additional_tags(unit) -> set:
    new_tags = set()
    for skill in unit.skills:
        if skill.has_tags and skill.has_tags.value and condition(skill, unit):
            new_tags = new_tags | set(skill.has_tags.value)
    return new_tags

def mana(playback, unit, item, target) -> int:
    mana = 0
    for skill in unit.skills:
        for component in skill.components:
            if component.defines('mana'):
                if component.ignore_conditional or condition(skill, unit):
                    d = component.mana(playback, unit, item, target)
                    mana += d
    return mana

def can_unlock(unit, region) -> bool:
    for skill in unit.skills:
        for component in skill.components:
            if component.defines('can_unlock'):
                if component.ignore_conditional or condition(skill, unit):
                    if component.can_unlock(unit, region):
                        return True
    return False

def target_icon(cur_unit, displaying_unit) -> list:
    markers = []
    for skill in cur_unit.skills:
        for component in skill.components:
            if component.defines('target_icon'):
                if component.ignore_conditional or condition(skill, cur_unit):
                    marker = component.target_icon(cur_unit, displaying_unit)
                    if marker:
                        markers.append(marker)
    return markers

def before_crit(actions, playback, attacker, item, defender, mode, attack_info) -> bool:
    for skill in attacker.skills:
        for component in skill.components:
            if component.defines('before_crit'):
                component.before_crit(actions, playback, attacker, item, defender, mode, attack_info)

def on_upkeep(actions, playback, unit) -> tuple:  # actions, playback
    for skill in unit.skills:
        for component in skill.components:
            if component.defines('on_upkeep'):
                if component.ignore_conditional or condition(skill, unit):
                    component.on_upkeep(actions, playback, unit)
    return actions, playback

def on_endstep(actions, playback, unit) -> tuple:  # actions, playback
    for skill in unit.skills:
        for component in skill.components:
            if component.defines('on_endstep'):
                if component.ignore_conditional or condition(skill, unit):
                    component.on_endstep(actions, playback, unit)
    return actions, playback

def on_end_chapter(unit, skill):
    for component in skill.components:
        if component.defines('on_end_chapter'):
            if component.ignore_conditional or condition(skill, unit):
                component.on_end_chapter(unit, skill)

def init(skill):
    """
    Initializes any data on the parent skill if necessary
    """
    for component in skill.components:
        if component.defines('init'):
            component.init(skill)

def on_add(unit, skill):
    for component in skill.components:
        if component.defines('on_add'):
            component.on_add(unit, skill)
    for other_skill in unit.skills:
        for component in other_skill.components:
            if component.defines('on_gain_skill'):
                component.on_gain_skill(unit, skill)

def on_remove(unit, skill):
    for component in skill.components:
        if component.defines('on_remove'):
            component.on_remove(unit, skill)

def re_add(unit, skill):
    for component in skill.components:
        if component.defines('re_add'):
            component.re_add(unit, skill)

def on_true_remove(unit, skill):
    """
    This one does not intrinsically interact with the turnwheel
    It only fires when the skill is actually removed for the first time
    Not on execute or reverse
    """
    for component in skill.components:
        if component.defines('on_true_remove'):
            component.on_true_remove(unit, skill)

def get_text(skill) -> str:
    for component in skill.components:
        if component.defines('text'):
            return component.text()
    return None

def get_cooldown(skill) -> float:
    for component in skill.components:
        if component.defines('cooldown'):
            return component.cooldown()
    return None

def get_hide_skill_icon(unit, skill) -> bool:
    # Check if we should be hiding this skill
    for component in skill.components:
        if component.defines('hide_skill_icon') and \
                component.hide_skill_icon(unit, skill):
            return True
    return False

def get_show_skill_icon(unit, skill) -> bool:
    for component in skill.components:
        if component.defines('show_skill_icon') and \
                component.show_skill_icon(unit):
            return True
    return False

def trigger_charge(unit, skill):
    for component in skill.components:
        if component.defines('trigger_charge'):
            component.trigger_charge(unit, skill)
    return None

def get_extra_abilities(unit):
    abilities = {}
    for skill in unit.skills:
        for component in skill.components:
            if component.defines('extra_ability'):
                if component.ignore_conditional or condition(skill, unit):
                    new_item = component.extra_ability(unit)
                    ability_name = new_item.name
                    abilities[ability_name] = new_item
    return abilities

def get_combat_arts(unit):
    from app.engine import item_funcs, target_system, action
    combat_arts = {}
    for skill in unit.skills:
        if not condition(skill, unit):
            continue
        combat_art = None
        combat_art_weapons = [item for item in item_funcs.get_all_items(unit) if item_funcs.available(unit, item)]
        for component in skill.components:
            if component.defines('combat_art'):
                combat_art = component.combat_art(unit)
            if component.defines('weapon_filter'):
                combat_art_weapons = \
                    [item for item in combat_art_weapons if component.weapon_filter(unit, item)]

        if combat_art and combat_art_weapons:
            good_weapons = []
            # Check which of the good weapons meet the range requirements
            for weapon in combat_art_weapons:
                # activate_combat_art(unit, skill)
                act = action.AddSkill(unit, skill.combat_art.value)
                act.do()
                targets = target_system.get_valid_targets(unit, weapon)
                act.reverse()
                # deactivate_combat_art(unit, skill)
                if targets:
                    good_weapons.append(weapon)

            if good_weapons:
                combat_arts[skill.name] = (skill, good_weapons)

    return combat_arts

def activate_combat_art(unit, skill):
    for component in skill.components:
        if component.defines('on_activation'):
            component.on_activation(unit)

def deactivate_combat_art(unit, skill):
    for component in skill.components:
        if component.defines('on_deactivation'):
            component.on_deactivation(unit)

def deactivate_all_combat_arts(unit):
    for skill in unit.skills:
        deactivate_combat_art(unit, skill)

def on_pairup(unit, leader):
    for skill in unit.skills:
        for component in skill.components:
            if component.defines('on_pairup'):
                component.on_pairup(unit, leader)

def on_separate(unit, leader):
    for skill in unit.skills:
        for component in skill.components:
            if component.defines('on_separate'):
                component.on_separate(unit, leader)

item_override_recursion_stack = set()
def item_override(unit, item: ItemObject):
    all_override_components = []
    components_so_far = set()
    if not unit or not item:
        return all_override_components
    for skill in reversed(unit.skills):
        for component in skill.components:
            if component.nid == 'item_override':
                # Conditions for item overrides might rely on e.g.
                # what item is equipped, which would itself
                # make an item override call on the same skill.
                # Therefore, we simply assume - probably safely -
                # that the skill cannot influence its own condition.
                if skill.nid not in item_override_recursion_stack:
                    item_override_recursion_stack.add(skill.nid)
                    if condition(skill, unit):
                        new_override_components = list(component.get_components(unit))
                        new_override_components = [comp for comp in new_override_components if comp.nid not in components_so_far]
                        components_so_far |= set([comp.nid for comp in new_override_components])
                        all_override_components += new_override_components
                    item_override_recursion_stack.remove(skill.nid)
                break
    return all_override_components
