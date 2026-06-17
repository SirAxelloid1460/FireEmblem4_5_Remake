class_name PromotionSystem
extends Node

# Base de datos de promociones
static var promotions = {
	# Clases básicas
	"Lord": {
		"promoted_class": "Master Lord",
		"bonuses": {"hp": 3, "str": 2, "mag": 1, "skl": 2, "spd": 2, "lck": 0, "def": 2, "res": 2}
	},
	"Cavalier": {
		"promoted_class": "Paladin",
		"bonuses": {"hp": 4, "str": 2, "mag": 0, "skl": 2, "spd": 2, "lck": 0, "def": 2, "res": 1}
	},
	"Knight": {
		"promoted_class": "General",
		"bonuses": {"hp": 5, "str": 3, "mag": 0, "skl": 2, "spd": 1, "lck": 0, "def": 3, "res": 2}
	},
	"Armor Knight": {
		"promoted_class": "General",
		"bonuses": {"hp": 5, "str": 3, "mag": 0, "skl": 2, "spd": 1, "lck": 0, "def": 3, "res": 2}
	},
	"Myrmidon": {
		"promoted_class": "Swordmaster",
		"bonuses": {"hp": 3, "str": 1, "mag": 0, "skl": 3, "spd": 3, "lck": 1, "def": 1, "res": 1}
	},
	"Fighter": {
		"promoted_class": "Hero",
		"bonuses": {"hp": 4, "str": 3, "mag": 0, "skl": 2, "spd": 2, "lck": 0, "def": 2, "res": 1}
	},
	"Mercenary": {
		"promoted_class": "Hero",
		"bonuses": {"hp": 4, "str": 2, "mag": 0, "skl": 2, "spd": 2, "lck": 1, "def": 2, "res": 1}
	},
	"Soldier": {
		"promoted_class": "Halberdier",
		"bonuses": {"hp": 4, "str": 2, "mag": 0, "skl": 2, "spd": 2, "lck": 0, "def": 2, "res": 1}
	},
	"Archer": {
		"promoted_class": "Sniper",
		"bonuses": {"hp": 3, "str": 2, "mag": 0, "skl": 3, "spd": 2, "lck": 0, "def": 1, "res": 1}
	},
	"Mage": {
		"promoted_class": "Sage",
		"bonuses": {"hp": 3, "str": 0, "mag": 3, "skl": 2, "spd": 2, "lck": 0, "def": 1, "res": 3}
	},
	"Priest": {
		"promoted_class": "Bishop",
		"bonuses": {"hp": 4, "str": 0, "mag": 2, "skl": 2, "spd": 2, "lck": 1, "def": 1, "res": 3}
	},
	"Cleric": {
		"promoted_class": "Bishop",
		"bonuses": {"hp": 4, "str": 0, "mag": 2, "skl": 2, "spd": 2, "lck": 1, "def": 1, "res": 3}
	},
	"Pegasus Knight": {
		"promoted_class": "Falcon Knight",
		"bonuses": {"hp": 3, "str": 1, "mag": 1, "skl": 2, "spd": 3, "lck": 1, "def": 1, "res": 2}
	},
	"Wyvern Rider": {
		"promoted_class": "Wyvern Lord",
		"bonuses": {"hp": 5, "str": 3, "mag": 0, "skl": 2, "spd": 2, "lck": 0, "def": 3, "res": 1}
	}
}

# Rutas de promoción ramificadas (recuperado de PromotionMenu al unificar).
# Clases con MÁS de una opción de promoción. Las que no aparezcan aquí usan
# la ruta única definida en `promotions`.
static var branch_paths = {
	"Lord": ["Master Lord", "Great Lord"],
	"Knight": ["Paladin", "Great Knight"],
	"Mage": ["Sage", "Mage Knight"],
	"Fighter": ["Hero", "Warrior"],
	"Cavalier": ["Paladin"],
	"Pegasus Knight": ["Falcon Knight"]
}

## Devuelve TODAS las clases a las que puede promocionar `base_class`.
## Usa las ramas si existen; si no, cae a la ruta única de `promotions`.
static func get_promotion_paths(base_class: String) -> Array:
	if branch_paths.has(base_class):
		return branch_paths[base_class].duplicate()
	if promotions.has(base_class):
		return [promotions[base_class]["promoted_class"]]
	return []

## Bonuses de promoción. Hoy son por clase BASE (no por destino), porque solo
## existe una tabla de bonuses por base. Si en el futuro cada destino ramificado
## tiene bonuses propios, extender esta función con esa data.
static func get_bonuses(base_class: String) -> Dictionary:
	if promotions.has(base_class):
		return promotions[base_class]["bonuses"]
	return {}

static func can_promote(unit: Unit) -> bool:
	"""Verifica si una unidad puede promocionarse"""
	# Requisitos: Nivel 20+ y clase base
	if unit.level < 20:
		return false
	
	return promotions.has(unit.unit_class)

static func get_promotion_data(base_class: String) -> Dictionary:
	"""Obtiene los datos de promoción de una clase"""
	return promotions.get(base_class, {})

static func promote_unit(unit: Unit) -> Dictionary:
	"""
	Promociona una unidad y retorna los datos de la promoción.
	Retorna: {"old_class": String, "new_class": String, "bonuses": Dictionary}
	"""
	if not can_promote(unit):
		return {}
	
	var promo_data = get_promotion_data(unit.unit_class)
	if promo_data.is_empty():
		return {}
	
	var old_class = unit.unit_class
	var new_class = promo_data["promoted_class"]
	var bonuses = promo_data["bonuses"]
	
	# Aplicar bonuses
	unit.max_hp += bonuses["hp"]
	unit.current_hp = unit.max_hp  # Curar completamente
	unit.strength += bonuses["str"]
	unit.magic += bonuses["mag"]
	unit.skill += bonuses["skl"]
	unit.speed += bonuses["spd"]
	unit.luck += bonuses["lck"]
	unit.defense += bonuses["def"]
	unit.resistance += bonuses["res"]
	
	# Cambiar clase
	unit.unit_class = new_class
	
	# Resetear nivel a 1 (estilo FE clásico)
	unit.level = 1
	
	return {
		"old_class": old_class,
		"new_class": new_class,
		"bonuses": bonuses
	}
