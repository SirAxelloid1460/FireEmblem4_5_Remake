# Item.gd
# Clase base de items personalizados (consumibles, anillos, manuales).
#
# IMPORTANTE — relación con Weapon.gd:
#   Las ARMAS son Weapon (Weapon.gd).  Los Items NO son armas — son
#   consumibles, anillos, llaves, etc.  Estructura distinta.
#
# Antes esta clase estaba dentro de Items.gd con class_name Item, pero
# eso causaba "Unexpected class_name in class body" porque Items.gd
# ya declaraba class_name ItemDatabase.  Cada archivo .gd solo puede
# tener un class_name a nivel top.

class_name Item
extends RefCounted

var id: String = ""
var item_name: String = ""
var item_type: String = "Consumable"  # Consumable, Ring, Manual, Key, etc.
var description: String = ""
var uses: int = 1
var max_uses: int = 1
var value: int = 0
var heal_amount: int = 0   # consumibles de cura (Vulnerary, etc.)

# Heurística: para que LevelLoader los identifique como NO-armas.
var weapon_type: String = ""

# Compatibilidad con la API antigua del Item del proyecto.
# Algunos archivos usan .name en lugar de item_name.
var name: String:
	get: return item_name
	set(v): item_name = v


func _init(p_id: String = "", p_name: String = "", p_type: String = "Consumable",
		p_uses: int = 1, p_value: int = 0, p_desc: String = ""):
	id = p_id
	item_name = p_name
	item_type = p_type
	uses = p_uses
	max_uses = p_uses
	value = p_value
	description = p_desc


## Override en subclases.  Devuelve true si el item se consumió.
func use_on(_target) -> bool:
	return false


## Reduce los usos del item.  Devuelve true si aún quedan usos.
func consume_use() -> bool:
	uses = max(0, uses - 1)
	return uses > 0


## ¿Item gastado?
func is_depleted() -> bool:
	return uses <= 0
