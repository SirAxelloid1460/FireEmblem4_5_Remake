from app.engine import item_system

def can_wield(unit, item) -> bool:
    weapon = item_system.is_weapon(unit, item)
    spell = item_system.is_weapon(unit, item)
    avail = item_system.available(unit, item)
    if (weapon or spell):
        if avail:
            return True
        else:
            return False
    return True
