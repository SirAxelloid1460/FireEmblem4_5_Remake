from app.data.database.skill_components import SkillComponent, SkillTags
from app.data.database.components import ComponentType

from app.engine import equations, item_system, item_funcs, skill_system
from app.engine.combat import playback as pb
from app.utilities.enums import Strike

class UnitAnim(SkillComponent):
    nid = 'unit_anim'
    desc = "Displays MapAnimation over unit"
    tag = SkillTags.AESTHETIC

    expose = ComponentType.MapAnimation

    def on_add(self, unit, skill):
        unit.sprite.add_animation(self.value, contingent=True)

    def re_add(self, unit, skill):
        unit.sprite.add_animation(self.value, contingent=True)

    def on_remove(self, unit, skill):
        unit.sprite.remove_animation(self.value)

    def should_draw_anim(self, unit, skill):
        return self.value

class UnitFlickeringTint(SkillComponent):
    nid = 'unit_flickering_tint'
    desc = "Displays a flickering tint on the unit"
    tag = SkillTags.AESTHETIC

    expose = ComponentType.Color3

    def unit_sprite_flicker_tint(self, unit, skill) -> tuple:
        return (self.value, 900, 300)

class UpkeepAnimation(SkillComponent):
    nid = 'upkeep_animation'
    desc = "Displays map animation at beginning of turn"
    tag = SkillTags.AESTHETIC

    expose = ComponentType.MapAnimation

    def on_upkeep(self, actions, playback, unit):
        playback.append(pb.CastAnim(self.value))

class UpkeepSound(SkillComponent):
    nid = 'upkeep_sound'
    desc = "Plays sound at beginning of turn"
    tag = SkillTags.AESTHETIC

    expose = ComponentType.Sound

    def on_upkeep(self, actions, playback, unit):
        playback.append(pb.HitSound(self.value))

class DisplaySkillIconInCombat(SkillComponent):
    nid = 'display_skill_icon_in_combat'
    desc = "Displays the skill's icon in combat even if it's not a proc skill"
    tag = SkillTags.AESTHETIC

    def show_skill_icon(self, unit) -> bool:
        return True

class HideSkillIconInCombat(SkillComponent):
    nid = 'hide_skill_icon_in_combat'
    desc = """
        Hide's the skill's icon in combat even if it's a proc skill.
        Overrides `display_skill_icon_in_combat` if both are present
           """
    tag = SkillTags.AESTHETIC

    def hide_skill_icon(self, unit) -> bool:
        return True

# Show steal icon
class StealIcon(SkillComponent):
    nid = 'steal_icon'
    desc = "Displays icon above units with stealable items"
    tag = SkillTags.AESTHETIC

    def target_icon(self, unit, target) -> str:
        # Unit has item that can be stolen
        if skill_system.check_enemy(unit, target):
            attack = equations.parser.steal_atk(unit)
            defense = equations.parser.steal_def(target)
            if attack >= defense:
                for def_item in target.items:
                    if self._item_restrict(unit, target, def_item):
                        return 'steal'
        return None

    def _item_restrict(self, unit, defender, def_item) -> bool:
        if item_system.unstealable(defender, def_item):
            return False
        if item_funcs.inventory_full(unit, def_item):
            return False
        if def_item is defender.get_weapon():
            return False
        return True

class GBAStealIcon(StealIcon, SkillComponent):
    nid = 'gba_steal_icon'

    def _item_restrict(self, unit, defender, def_item) -> bool:
        if item_system.unstealable(defender, def_item):
            return False
        if item_funcs.inventory_full(unit, def_item):
            return False
        if item_system.is_weapon(defender, def_item) or item_system.is_spell(defender, def_item):
            return False
        return True

class AlternateBattleAnim(SkillComponent):
    nid = 'alternate_battle_anim'
    desc = "Use a specific pose when attacking in an animation combat (except on miss)"
    tag = SkillTags.AESTHETIC

    expose = ComponentType.String
    value = 'Critical'

    def after_strike(self, actions, playback, unit, item, target, mode, attack_info, strike):
        if strike != Strike.MISS:
            playback.append(pb.AlternateBattlePose(self.value))

class ChangeVariant(SkillComponent):
    nid = 'change_variant'
    desc = "Change the unit's variant"
    tag = SkillTags.AESTHETIC

    expose = ComponentType.String
    value = ''

    def on_add(self, unit, skill):
        unit.sprite.load_sprites()

    def re_add(self, unit, skill):
        unit.sprite.load_sprites()

    def on_remove(self, unit, skill):
        unit.sprite.load_sprites()

    def change_variant(self, unit):
        return self.value

class ChangeAnimation(SkillComponent):
    nid = 'change_animation'
    desc = "Change the unit's animation"
    tag = SkillTags.AESTHETIC

    expose = ComponentType.String
    value = ''

    def change_animation(self, unit):
        return self.value

class MapCastAnim(SkillComponent):
    nid = 'map_cast_anim'
    desc = "Adds a map animation on cast"
    tag = SkillTags.AESTHETIC

    expose = ComponentType.MapAnimation

    def start_combat(self, playback, unit, item, target, mode):
        playback.append(pb.CastAnim(self.value))

class BattleAnimMusic(SkillComponent):
    nid = 'battle_animation_music'
    desc = "Uses custom battle music"
    tag = SkillTags.AESTHETIC

    expose = ComponentType.Music
    value = None

    def battle_music(self, playback, unit, item, target, mode):
        return self.value
