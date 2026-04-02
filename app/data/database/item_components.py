from __future__ import annotations
from enum import Enum
from typing import TYPE_CHECKING, Optional

from app.data.database.components import Component, ComponentType

if TYPE_CHECKING:
    from app.engine.objects.item import ItemObject


class ItemTags(Enum):
    BASE = 'base'
    TARGET = 'target'
    WEAPON = 'weapon'
    USES = 'uses'
    EXP = 'exp'
    CLASS_CHANGE = 'class_change'
    EXTRA = 'extra'
    UTILITY = 'utility'
    SPECIAL = 'special'
    FORMULA = 'formula'
    AOE = 'aoe'
    AESTHETIC = 'aesthetic'
    ADVANCED = 'advanced'

    CUSTOM = 'custom'
    HIDDEN = 'hidden'
    DEPRECATED = 'deprecated'

class ItemComponent(Component):
    item: Optional[ItemObject] = None

def get_items_using(expose: ComponentType, value, db) -> list:
    affected_items = []
    for item in db.items:
        for component in item.components:
            if component.expose == expose and component.value == value:
                affected_items.append(item)
    return affected_items

def swap_values(affected_items: list, expose: ComponentType, old_value, new_value):
    for item in affected_items:
        for component in item.components:
            if component.expose == expose and component.value == old_value:
                component.value = new_value
