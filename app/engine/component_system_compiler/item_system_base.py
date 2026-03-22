import random
from typing import Set, Tuple

class Defaults():
    @staticmethod
    def full_price(unit, item) -> int:
        return None

    @staticmethod
    def buy_price(unit, item) -> float:
        return None

    @staticmethod
    def sell_price(unit, item) -> float:
        return None

    @staticmethod
    def special_sort(unit, item):
        return None

    @staticmethod
    def num_targets(unit, item) -> int:
        return 1

    @staticmethod
    def minimum_range(unit, item) -> int:
        return 0

    @staticmethod
    def maximum_range(unit, item) -> int:
        return 0

    @staticmethod
    def weapon_type(unit, item):
        return None

    @staticmethod
    def weapon_rank(unit, item):
        return None

    @staticmethod
    def modify_weapon_triangle(unit, item) -> float:
        return 1.0

    @staticmethod
    def effect_animation(unit, item) -> str:
        return None

    @staticmethod
    def damage(unit, item) -> int:
        return None

    @staticmethod
    def hit(unit, item) -> int:
        return None

    @staticmethod
    def crit(unit, item) -> int:
        return None

    @staticmethod
    def exp(playback, unit, item) -> int:
        return 0

    @staticmethod
    def wexp(playback, unit, item, target) -> int:
        return 1

    @staticmethod
    def damage_formula(unit, item) -> str:
        return 'DAMAGE'

    @staticmethod
    def resist_formula(unit, item) -> str:
        return 'DEFENSE'

    @staticmethod
    def accuracy_formula(unit, item) -> str:
        return 'HIT'

    @staticmethod
    def avoid_formula(unit, item) -> str:
        return 'AVOID'

    @staticmethod
    def crit_accuracy_formula(unit, item) -> str:
        return 'CRIT_HIT'

    @staticmethod
    def crit_avoid_formula(unit, item) -> str:
        return 'CRIT_AVOID'

    @staticmethod
    def attack_speed_formula(unit, item) -> str:
        return 'ATTACK_SPEED'

    @staticmethod
    def defense_speed_formula(unit, item) -> str:
        return 'DEFENSE_SPEED'

    @staticmethod
    def text_color(unit, item) -> str:
        return None

def get_all_components(unit, item) -> list:
    from app.engine import skill_system
    override_components = skill_system.item_override(unit, item)
    override_component_nids = [c.nid for c in override_components]
    if not item:
        return override_components
    all_components = override_components + [c for c in item.components if c.nid not in override_component_nids]
    return all_components

def available(unit, item) -> bool:
    """
    If any hook reports false, then it is false
    """
    all_components = get_all_components(unit, item)
    for component in all_components:
        if component.defines('available'):
            if not component.available(unit, item):
                return False
    if item.parent_item:
        for component in item.parent_item.components:
            if component.defines('available'):
                if not component.available(unit, item.parent_item):
                    return False
    return True

def exp(playback, unit, item):
    all_components = get_all_components(unit, item)
    val = 0
    for component in all_components:
        if component.defines('exp'):
            val += component.exp(playback, unit, item)
    return val

def stat_change(unit, item, stat_nid) -> int:
    bonus = 0
    all_components = get_all_components(unit, item)
    for component in all_components:
        if component.defines('stat_change'):
            d = component.stat_change(unit)
            bonus += d.get(stat_nid, 0)
    return bonus

def stat_change_contribution(unit, item, stat_nid) -> list:
    contribution = {}
    all_components = get_all_components(unit, item)
    for component in all_components:
        if component.defines('stat_change'):
            d = component.stat_change(unit)
            val = d.get(stat_nid, 0)
            if val != 0:
                if item.name in contribution:
                    contribution[item.name] += val
                else:
                    contribution[item.name] = val
    return contribution

def is_broken(unit, item) -> bool:
    """
    If any hook reports true, then it is true
    """
    all_components = get_all_components(unit, item)
    for component in all_components:
        if component.defines('is_broken'):
            if component.is_broken(unit, item):
                return True
    if item.parent_item:
        for component in item.parent_item.components:
            if component.defines('is_broken'):
                if component.is_broken(unit, item.parent_item):
                    return True
    return False

def on_broken(unit, item) -> bool:
    alert = False
    all_components = get_all_components(unit, item)
    for component in all_components:
        if component.defines('on_broken'):
            if component.on_broken(unit, item):
                alert = True
    if item.parent_item:
        for component in item.parent_item.components:
            if component.defines('on_broken'):
                if component.on_broken(unit, item.parent_item):
                    alert = True
    return alert

def valid_targets(unit, item) -> set:
    targets = set()
    all_components = get_all_components(unit, item)
    for component in all_components:
        if component.defines('valid_targets'):
            targets |= component.valid_targets(unit, item)
    return targets

def ai_targets(unit, item) -> set:
    targets = set()
    all_components = get_all_components(unit, item)
    for component in all_components:
        if component.defines('ai_targets'):
            if targets:  # If we already have targets, just make them smaller
                targets &= component.ai_targets(unit, item)
            else:
                targets |= component.ai_targets(unit, item)
    return targets

def target_restrict(unit, item, def_pos, splash) -> bool:
    all_components = get_all_components(unit, item)
    for component in all_components:
        if component.defines('target_restrict'):
            if not component.target_restrict(unit, item, def_pos, splash):
                return False
    return True

def range_restrict(unit, item) -> Tuple[Set, bool]:
    restricted_range = set()
    any_defined = False
    all_components = get_all_components(unit, item)
    for component in all_components:
        if component.defines('range_restrict'):
            any_defined = True
            restricted_range |= component.range_restrict(unit, item)
    if any_defined:
        return restricted_range
    else:
        return None

def item_restrict(unit, item, defender, def_item) -> bool:
    all_components = get_all_components(unit, item)
    for component in all_components:
        if component.defines('item_restrict'):
            if not component.item_restrict(unit, item, defender, def_item):
                return False
    return True

def ai_priority(unit, item, target, move) -> float:
    custom_ai_flag: bool = False
    ai_priority = 0
    all_components = get_all_components(unit, item)
    for component in all_components:
        if component.defines('ai_priority'):
            custom_ai_flag = True
            ai_priority += component.ai_priority(unit, item, target, move)
    if custom_ai_flag:
        return ai_priority
    else:
        # Returns None when no custom ai is available
        return None

def splash(unit, item, position) -> tuple:
    """
    Returns main target position and splash positions
    """
    main_target = []
    splash = []
    all_components = get_all_components(unit, item)
    for component in all_components:
        if component.defines('splash'):
            new_target, new_splash = component.splash(unit, item, position)
            main_target.append(new_target)
            splash += new_splash
    # Handle having multiple main targets
    if len(main_target) > 1:
        splash += main_target
        main_target = None
    elif len(main_target) == 1:
        main_target = main_target[0]
    else:
        main_target = None

    # If not default
    if main_target or splash:
        return main_target, splash
    else: # DEFAULT
        from app.engine import skill_system
        alternate_splash_component = skill_system.alternate_splash(unit)
        if alternate_splash_component and not unsplashable(unit, item):
            main_target, splash = alternate_splash_component.splash(unit, item, position)
            return main_target, splash
        else:
            return position, []

def splash_positions(unit, item, position) -> set:
    positions = set()
    all_components = get_all_components(unit, item)
    for component in all_components:
        if component.defines('splash_positions'):
            positions |= component.splash_positions(unit, item, position)
    # DEFAULT
    if not positions:
        from app.engine import skill_system
        alternate_splash_component = skill_system.alternate_splash(unit)
        if alternate_splash_component and not unsplashable(unit, item):
            positions = alternate_splash_component.splash_positions(unit, item, position)
            return positions
        else:
            return {position}
    return positions

def find_hp(actions, target):
    from app.engine import action
    starting_hp = target.get_hp()
    for subaction in actions:
        if isinstance(subaction, action.ChangeHP):
            starting_hp += subaction.num
    return starting_hp

def after_strike(actions, playback, unit, item, target, mode, attack_info, strike):
    all_components = get_all_components(unit, item)
    for component in all_components:
        if component.defines('after_strike'):
            component.after_strike(actions, playback, unit, item, target, mode, attack_info, strike)
    if item.parent_item:
        for component in item.parent_item.components:
            if component.defines('after_strike'):
                component.after_strike(actions, playback, unit, item.parent_item, target, mode, attack_info, strike)

def on_hit(actions, playback, unit, item, target, target_pos, mode, attack_info, first_item):
    all_components = get_all_components(unit, item)
    for component in all_components:
        if component.defines('on_hit'):
            component.on_hit(actions, playback, unit, item, target, target_pos, mode, attack_info)
    if item.parent_item and first_item:
        for component in item.parent_item.components:
            if component.defines('on_hit'):
                component.on_hit(actions, playback, unit, item.parent_item, target, target_pos, mode, attack_info)

    # Default playback
    import app.engine.combat.playback as pb
    if target and find_hp(actions, target) <= 0:
        playback.append(pb.Shake(2))
        if not any(brush.nid == 'hit_sound' for brush in playback):
            playback.append(pb.HitSound('Final Hit'))
    else:
        playback.append(pb.Shake(1))
        if not any(brush.nid == 'hit_sound' for brush in playback):
            playback.append(pb.HitSound('Attack Hit ' + str(random.randint(1, 5))))
    if target and not any(brush.nid in ('unit_tint_add', 'unit_tint_sub') for brush in playback):
        playback.append(pb.UnitTintAdd(target, (255, 255, 255)))

def on_crit(actions, playback, unit, item, target, target_pos, mode, attack_info, first_item):
    all_components = get_all_components(unit, item)
    for component in all_components:
        if component.defines('on_crit'):
            component.on_crit(actions, playback, unit, item, target, target_pos, mode, attack_info)
        elif component.defines('on_hit'):
            component.on_hit(actions, playback, unit, item, target, target_pos, mode, attack_info)
    if item.parent_item and first_item:
        for component in item.parent_item.components:
            if component.defines('on_crit'):
                component.on_crit(actions, playback, unit, item.parent_item, target, target_pos, mode, attack_info)
            elif component.defines('on_hit'):
                component.on_hit(actions, playback, unit, item.parent_item, target, target_pos, mode, attack_info)

    # Default playback
    import app.engine.combat.playback as pb
    playback.append(pb.Shake(3))
    if target:
        playback.append(pb.CritVibrate(target))
        if not any(brush.nid == 'hit_sound' for brush in playback):
            if find_hp(actions, target) <= 0:
                playback.append(pb.HitSound('Final Hit'))
            playback.append(pb.HitSound('Critical Hit ' + str(random.randint(1, 2))))
        if not any(brush.nid == 'crit_tint' for brush in playback):
            playback.append(pb.CritTint(target, (255, 255, 255)))

def on_glancing_hit(actions, playback, unit, item, target, target_pos, mode, attack_info, first_item):
    all_components = get_all_components(unit, item)
    for component in all_components:
        if component.defines('on_glancing_hit'):
            component.on_glancing_hit(actions, playback, unit, item, target, target_pos, mode, attack_info)
        elif component.defines('on_hit'):
            component.on_hit(actions, playback, unit, item, target, target_pos, mode, attack_info)
    if item.parent_item and first_item:
        for component in item.parent_item.components:
            if component.defines('on_glancing_hit'):
                component.on_glancing_hit(actions, playback, unit, item.parent_item, target, target_pos, mode, attack_info)
            elif component.defines('on_hit'):
                component.on_hit(actions, playback, unit, item.parent_item, target, target_pos, mode, attack_info)

    # Default playback
    import app.engine.combat.playback as pb
    if target and find_hp(actions, target) <= 0:
        playback.append(pb.Shake(2))
        if not any(brush.nid == 'hit_sound' for brush in playback):
            playback.append(pb.HitSound('Final Hit'))
    else:
        playback.append(pb.Shake(4))
        if not any(brush.nid == 'hit_sound' for brush in playback):
            playback.append(pb.HitSound('No Damage'))
    if target and not any(brush.nid in ('unit_tint_add', 'unit_tint_sub') for brush in playback):
        playback.append(pb.UnitTintAdd(target, (255, 255, 255)))

def on_miss(actions, playback, unit, item, target, target_pos, mode, attack_info, first_item):
    all_components = get_all_components(unit, item)
    for component in all_components:
        if component.defines('on_miss'):
            component.on_miss(actions, playback, unit, item, target, target_pos, mode, attack_info)
    if item.parent_item and first_item:
        for component in item.parent_item.components:
            if component.defines('on_miss'):
                component.on_miss(actions, playback, unit, item.parent_item, target, target_pos, mode, attack_info)

    # Default playback
    import app.engine.combat.playback as pb
    playback.append(pb.HitSound('Attack Miss 2'))
    playback.append(pb.HitAnim('MapMiss', target))

def item_icon_mod(unit, item, target, sprite):
    all_components = get_all_components(unit, item)
    for component in all_components:
        if component.defines('item_icon_mod'):
            sprite = component.item_icon_mod(unit, item, target, sprite)
    return sprite

def can_unlock(unit, item, region) -> bool:
    all_components = get_all_components(unit, item)
    for component in all_components:
        if component.defines('can_unlock'):
            if component.can_unlock(unit, item, region):
                return True
    return False

def init(item):
    """
    Initializes any data on the parent item if necessary
    Do not put attribute initialization
    (ie, self._property = True) in this function
    """
    for component in item.components:
        if component.defines('init'):
            component.init(item)
