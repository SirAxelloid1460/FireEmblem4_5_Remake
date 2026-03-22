from app.data.database.item_components import ItemComponent, ItemTags
from app.data.database.components import ComponentType
from app.data.database.database import DB

class Spell(ItemComponent):
    nid = 'spell'
    desc = "This item will be included under the Spells menu instead of the Attack menu. A useful way to separate weapons from utility items like staves or non-damaging tomes. It cannot counterattack, be counterattacked, or double."
    tag = ItemTags.BASE

    def is_spell(self, unit, item):
        return True

    def is_weapon(self, unit, item):
        return False

    def equippable(self, unit, item):
        return False

    def wexp(self, playback, unit, item, target):
        return 1

    def can_double(self, unit, item):
        return False

    def can_counter(self, unit, item):
        return False

    def can_be_countered(self, unit, item):
        return False

class Weapon(ItemComponent):
    nid = 'weapon'
    desc = "Item is a weapon that can be used to attack and initiate combat. Important to add to anything that's being used for that purpose. Can double, counterattack, be equipped, etc."
    tag = ItemTags.BASE

    def is_weapon(self, unit, item):
        return True

    def is_spell(self, unit, item):
        return False

    def equippable(self, unit, item):
        return True

    def can_be_countered(self, unit, item):
        return True

    def can_counter(self, unit, item):
        return True

    def can_double(self, unit, item):
        return True

    def wexp(self, playback, unit, item, target):
        return 1

class SiegeWeapon(ItemComponent):
    nid = 'siege_weapon'
    desc = "The weapon cannot counterattack or be counterattacked, but can be equipped and double. Used instead of the weapon component. Cannot counterattack or be counterattacked, but can still be equipped and can double."
    tag = ItemTags.BASE

    def is_weapon(self, unit, item):
        return True

    def is_spell(self, unit, item):
        return False

    def equippable(self, unit, item):
        return True

    def can_double(self, unit, item):
        return True

    def can_counter(self, unit, item):
        return False

    def can_be_countered(self, unit, item):
        return False

    def wexp(self, playback, unit, item, target):
        return 1

class Usable(ItemComponent):
    nid = 'usable'
    desc = "Item can be used from the items menu. Must be paired with the Targets Allies or Target Anything component."
    tag = ItemTags.BASE

    def can_use(self, unit, item):
        return True

class UsableInBase(ItemComponent):
    nid = 'usable_in_base'
    desc = "Item is usable in base. Must be paired with the Targets Allies or Target Anything component."
    tag = ItemTags.BASE

    def can_use_in_base(self, unit, item):
        return True

    def simple_target_restrict(self, unit, item):
        return True

class Unrepairable(ItemComponent):
    nid = 'unrepairable'
    desc = "An item with the repair component cannot repair an item with this component."
    tag = ItemTags.BASE

    def unrepairable(self, unit, item):
        return True

class Unsplashable(ItemComponent):
    nid = 'unsplashable'
    desc = "Item cannot have its targeting affected by splash"
    tag = ItemTags.BASE

    def unsplashable(self, unit, item):
        return True

class Value(ItemComponent):
    nid = 'value'
    desc = "Item has a value and can be bought and sold. Items sell for a reduced value based on the value multiplier constant."
    tag = ItemTags.BASE

    expose = ComponentType.Int
    value = 0

    def full_price(self, unit, item):
        return self.value

    def buy_price(self, unit, item):
        if item.uses:
            frac = item.data['uses'] / item.data['starting_uses']
            return self.value * frac
        return self.value

    def sell_price(self, unit, item):
        if item.uses:
            frac = item.data['uses'] / item.data['starting_uses']
            return self.value * frac * DB.constants.value('sell_modifier')
        return self.value * DB.constants.value('sell_modifier')

class Accessory(ItemComponent):
    nid = 'accessory'
    desc = "The item is considered an accessory and takes up an accessory slot in a unit's inventory. Make sure to increase the number of accessory slots to more than zero and have a total number of inventory + accessory slots less than six."
    tag = ItemTags.BASE

    def is_accessory(self, unit, item) -> bool:
        return True

class EquippableAccessory(ItemComponent):
    nid = 'equippable_accessory'
    desc = "Item is an equippable accessory"
    tag = ItemTags.BASE

    def is_accessory(self, unit, item) -> bool:
        return True

    def equippable(self, unit, item) -> bool:
        return True

class Transform(ItemComponent):
    nid = 'transform'
    desc = "Item allows unit to transform. Use for Dragonstones, etc."
    tag = ItemTags.BASE

    def transforms(self, unit, item):
        return True

class ItemPrefab(ItemComponent):
    nid = 'item_prefab'
    desc = "This item will automatically inherit the components of the chosen item"
    tag = ItemTags.BASE

    expose = ComponentType.Item

class ItemTags(ItemComponent):
    nid = 'item_tags'
    desc = 'attach arbitrary tags to items. Useful for conditionals.'
    tag = ItemTags.BASE

    expose = (ComponentType.List, ComponentType.Tag)
    value = []