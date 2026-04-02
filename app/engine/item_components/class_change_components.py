from app.data.database.database import DB

from app.data.database.item_components import ItemComponent, ItemTags
from app.data.database.components import ComponentType

from app.engine.game_state import game

class Promote(ItemComponent):
    nid = 'promote'
    desc = "Promotes the targeted unit (most often the user) into whatever promotions their class has available to them."
    tag = ItemTags.CLASS_CHANGE

    _did_hit = False

    def on_hit(self, actions, playback, unit, item, target, target_pos, mode, attack_info):
        self._did_hit = True

    def end_combat(self, playback, unit, item, target, mode):
        if self._did_hit and target:
            klass = DB.classes.get(target.klass)
            if len(klass.turns_into) == 0:
                return
            elif len(klass.turns_into) == 1:
                new_klass = klass.turns_into[0]
            else:
                new_klass = None
            game.memory['current_unit'] = target
            game.memory['combat_item'] = item
            game.memory['can_go_back'] = True
            if new_klass:
                game.memory['next_class'] = new_klass
                game.memory['next_state'] = 'promotion'
                game.state.change('transition_to')
            else:
                game.memory['next_state'] = 'promotion_choice'
                game.state.change('transition_to')
        self._did_hit = False

class ForcePromote(Promote, ItemComponent):
    nid = 'force_promote'
    desc = "Forcibly promotes the targeted unit into the class specified in the component."
    tag = ItemTags.CLASS_CHANGE

    expose = ComponentType.Class

    def end_combat(self, playback, unit, item, target, mode):
        if self._did_hit and target:
            game.memory['current_unit'] = target
            game.memory['next_class'] = self.value
            game.state.change('promotion')
            game.state.change('transition_out')
        self._did_hit = False

class ClassChange(Promote, ItemComponent):
    nid = 'class_change'
    desc = "Item allows target to change class after hit. Define reclass options on the unit's unit screen."
    tag = ItemTags.CLASS_CHANGE

    def end_combat(self, playback, unit, item, target, mode):
        if self._did_hit and target:
            unit_prefab = DB.units.get(target.nid)
            if target.generic or not unit_prefab:
                return
            if not unit_prefab.alternate_classes:
                return
            elif len(unit_prefab.alternate_classes) == 1:
                new_klass = unit_prefab.alternate_classes[0]
            else:
                new_klass = None
            game.memory['current_unit'] = target
            game.memory['combat_item'] = item
            game.memory['can_go_back'] = True
            if new_klass:
                game.memory['next_class'] = new_klass
                game.state.change('class_change')
                game.state.change('transition_out')
            else:
                game.state.change('class_change_choice')
                game.state.change('transition_out')
        self._did_hit = False

class ForceClassChange(Promote, ItemComponent):
    nid = 'force_class_change'
    desc = "Item forcibly changes target's class after hit"
    tag = ItemTags.CLASS_CHANGE

    expose = ComponentType.Class

    def end_combat(self, playback, unit, item, target, mode):
        if self._did_hit and target:
            game.memory['current_unit'] = target
            game.memory['next_class'] = self.value
            game.state.change('class_change')
            game.state.change('transition_out')
        self._did_hit = False
