# HOOK CATALOG
# false priority hooks default to false
# and will be false if any single component returns false
false_priority_hooks = \
    ('is_weapon', 'is_spell', 'is_accessory', 'equippable',
     'can_counter', 'can_be_countered', 'can_double',
     'can_use', 'can_use_in_base', 'locked', 'unstealable', 'allow_same_target', 'allow_less_than_max_targets',
     'ignore_weapon_advantage', 'unrepairable', 'unsplashable', 'targets_items',
     'menu_after_combat', 'transforms', 'no_attack_after_move', 'no_map_hp_display',
     'cannot_dual_strike', 'can_attack_after_combat', 'simple_target_restrict', 'force_map_anim', 'ignore_line_of_sight')
# All default hooks are exclusive
formula = ('damage_formula', 'resist_formula', 'accuracy_formula', 'avoid_formula',
           'crit_accuracy_formula', 'crit_avoid_formula', 'attack_speed_formula', 'defense_speed_formula')
default_hooks = ('full_price', 'buy_price', 'sell_price', 'special_sort', 'num_targets', 'minimum_range', 'maximum_range',
                 'weapon_type', 'weapon_rank', 'modify_weapon_triangle', 'damage', 'hit', 'crit', 'effect_animation', 'text_color')
default_hooks += formula

target_hooks = ('wexp',)
simple_target_hooks = ('target_icon', )

dynamic_hooks = ('dynamic_damage', 'dynamic_accuracy', 'dynamic_crit_accuracy',
                 'dynamic_attack_speed', 'dynamic_multiattacks')
modify_hooks = ('modify_damage', 'modify_resist', 'modify_accuracy', 'modify_avoid',
                'modify_crit_accuracy', 'modify_crit_avoid', 'modify_attack_speed',
                'modify_defense_speed')

# None of these are exclusive
event_hooks = ('on_end_chapter', 'reverse_use',
               'on_equip_item', 'on_unequip_item', 'on_add_item', 'on_remove_item')

combat_event_hooks = ('start_combat', 'end_combat')
aesthetic_combat_hooks = ('battle_music', 'combat_effect')

status_event_hooks = ('on_upkeep', 'on_endstep')

exclusive_hooks = false_priority_hooks + default_hooks

def compile_item_system():
    import os
    dir_path = os.path.dirname(os.path.realpath(__file__))
    compiled_item_system = open(os.path.join(dir_path, '..', 'item_system.py'), 'w')
    item_system_base = open(os.path.join(dir_path, 'item_system_base.py'), 'r')
    warning_msg = open(os.path.join(dir_path, 'warning_msg.txt'), 'r')

    # write warning msg
    for line in warning_msg.readlines():
        compiled_item_system.write(line)

    # copy item system base
    for line in item_system_base.readlines():
        compiled_item_system.write(line)

    # compile item system
    for hook in false_priority_hooks:
        func = """
def %s(unit, item):
    all_components = get_all_components(unit, item)
    all_true = False
    for component in all_components:
        if component.defines('%s'):
            if not component.%s(unit, item):
                return False
            else:
                all_true = True
    return all_true""" \
            % (hook, hook, hook)
        compiled_item_system.write(func)
        compiled_item_system.write('\n')

    for hook in default_hooks:
        func = """
def %s(unit, item):
    all_components = get_all_components(unit, item)
    for component in all_components:
        if component.defines('%s'):
            return component.%s(unit, item)
    return Defaults.%s(unit, item)""" \
            % (hook, hook, hook, hook)
        compiled_item_system.write(func)
        compiled_item_system.write('\n')

    for hook in simple_target_hooks:
        func = """
def %s(cur_unit, item, displaying_unit):
    all_components = get_all_components(displaying_unit, item)
    markers = []
    for component in all_components:
        if component.defines('%s'):
            marker = component.%s(cur_unit, item, displaying_unit)
            if marker:
                markers.append(marker)
    return markers""" \
            % (hook, hook, hook)
        compiled_item_system.write(func)
        compiled_item_system.write('\n')

    for hook in target_hooks:
        func = """
def %s(playback, unit, item, target):
    all_components = get_all_components(unit, item)
    val = 0
    for component in all_components:
        if component.defines('%s'):
            val += component.%s(playback, unit, item, target)
    return val""" \
            % (hook, hook, hook)
        compiled_item_system.write(func)
        compiled_item_system.write('\n')

    for hook in modify_hooks:
        func = """
def %s(unit, item):
    all_components = get_all_components(unit, item)
    val = 0
    for component in all_components:
        if component.defines('%s'):
            val += component.%s(unit, item)
    return val""" \
            % (hook, hook, hook)
        compiled_item_system.write(func)
        compiled_item_system.write('\n')

    for hook in dynamic_hooks:
        func = """
def %s(unit, item, target, mode, attack_info, base_value):
    all_components = get_all_components(unit, item)
    val = 0
    for component in all_components:
        if component.defines('%s'):
            val += component.%s(unit, item, target, mode, attack_info, base_value)
    return val""" \
            % (hook, hook, hook)
        compiled_item_system.write(func)
        compiled_item_system.write('\n')

    for hook in event_hooks:
        func = """
def %s(unit, item):
    all_components = get_all_components(unit, item)
    for component in all_components:
        if component.defines('%s'):
            component.%s(unit, item)
    if item.parent_item:
        for component in item.parent_item.components:
            if component.defines('%s'):
                component.%s(unit, item.parent_item)""" \
            % (hook, hook, hook, hook, hook)
        compiled_item_system.write(func)
        compiled_item_system.write('\n')

    for hook in combat_event_hooks:
        func = """
def %s(playback, unit, item, target, mode):
    all_components = get_all_components(unit, item)
    for component in all_components:
        if component.defines('%s'):
            component.%s(playback, unit, item, target, mode)
    if item.parent_item:
        for component in item.parent_item.components:
            if component.defines('%s'):
                component.%s(playback, unit, item.parent_item, target, mode)""" \
            % (hook, hook, hook, hook, hook)
        compiled_item_system.write(func)
        compiled_item_system.write('\n')

    for hook in status_event_hooks:
        func = """
def %s(actions, playback, unit, item):
    all_components = get_all_components(unit, item)
    for component in all_components:
        if component.defines('%s'):
            component.%s(actions, playback, unit, item)
    if item.parent_item:
        for component in item.parent_item.components:
            if component.defines('%s'):
                component.%s(actions, playback, unit, item.parent_item)""" \
            % (hook, hook, hook, hook, hook)
        compiled_item_system.write(func)
        compiled_item_system.write('\n')

    for hook in aesthetic_combat_hooks:
        func = """
def %s(unit, item, target, mode):
    all_components = get_all_components(unit, item)
    for component in all_components:
        if component.defines('%s'):
            return component.%s(unit, item, target, mode)
    return None""" \
            % (hook, hook, hook)
        compiled_item_system.write(func)
        compiled_item_system.write('\n')
