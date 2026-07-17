class_name PromotionSystem
extends Node

# Sistema de promoción DATA-DRIVEN.  La fuente de verdad son las clases de
# data/general/classes.json:
#   · `turns_into`      → destinos de promoción (lista de ids).
#   · `promotes_from`   → clase origen.
#   · `promotion_gains` → ganancias al promocionar, EN LA CLASE DESTINO, keyed
#                         por clase ORIGEN (+ override "Origen@Personaje").
#                         Orden de stats: STR·MAG·SKL·SPD·DEF·RES·MOV·LCK (sin HP).
# Todo se resuelve por MODO de juego (FE4/FE5/SAGA) vía GameDB.resolved_class /
# GameDB.promotion_gains (SAGA = max(FE4,FE5)).  Ya NO hay tabla hardcodeada.

const PROMOTION_LEVEL := 20

## Resuelve el autoload GameDB desde un contexto estático.
static func _db():
	var loop := Engine.get_main_loop()
	if loop is SceneTree and loop.root != null:
		return loop.root.get_node_or_null("GameDB")
	return null

static func _mode() -> String:
	return LevelLoader._current_game_mode()

## TODAS las clases a las que puede promocionar `base_class` (por modo).
static func get_promotion_paths(base_class: String) -> Array:
	var db = _db()
	if db == null:
		return []
	var paths = db.resolved_class(base_class).get("turns_into", [])
	return (paths as Array).duplicate() if paths is Array else []

## ¿La unidad puede promocionar?  Requiere destino disponible y nivel suficiente.
static func can_promote(unit) -> bool:
	if unit == null:
		return false
	if get_promotion_paths(unit.unit_class).is_empty():
		return false
	return int(unit.level) >= PROMOTION_LEVEL

## Ganancias crudas (claves MAYÚSCULAS, sin HP) al pasar base_class -> dest_class,
## resueltas por modo y con override @personaje.  {} si no hay ruta.
static func get_gains(base_class: String, dest_class: String, character: String = "") -> Dictionary:
	var db = _db()
	if db == null:
		return {}
	return db.promotion_gains(dest_class, base_class, character)

## COMPAT con PromotionPanel: {promoted_class, bonuses:{hp,str,mag,skl,spd,lck,def,res,mov}}.
## `dest_class` vacío usa el primer destino de `turns_into`.  hp=0 (las promociones
## de FE4/FE5 en nuestros datos no otorgan HP).
static func get_promotion_data(base_class: String, dest_class: String = "", character: String = "") -> Dictionary:
	var paths := get_promotion_paths(base_class)
	if paths.is_empty():
		return {}
	var dest := dest_class if dest_class != "" else str(paths[0])
	var gains := get_gains(base_class, dest, character)
	var bonuses := {"hp": 0, "str": 0, "mag": 0, "skl": 0, "spd": 0, "lck": 0, "def": 0, "res": 0, "mov": 0}
	var mapk := {"STR": "str", "MAG": "mag", "SKL": "skl", "SPD": "spd",
		"DEF": "def", "RES": "res", "MOV": "mov", "LCK": "lck"}
	for k in gains:
		if mapk.has(k):
			bonuses[mapk[k]] = int(gains[k])
	return {"promoted_class": dest, "bonuses": bonuses}

## COMPAT: bonuses (claves minúsculas) de la ruta indicada / primera.
static func get_bonuses(base_class: String, dest_class: String = "", character: String = "") -> Dictionary:
	var d := get_promotion_data(base_class, dest_class, character)
	return d.get("bonuses", {}) if not d.is_empty() else {}

## COMPAT: datos de promoción de la primera ruta.
static func get_promotion_data_simple(base_class: String) -> Dictionary:
	return get_promotion_data(base_class)

## Promociona la unidad: aplica ganancias por modo (orden STR·MAG·SKL·SPD·DEF·RES·MOV·LCK),
## cambia de clase, recorta a los caps de la nueva clase y gestiona el nivel.
## Retorna {old_class, new_class, gains} o {} si no procede.
static func promote_unit(unit, dest_class: String = "") -> Dictionary:
	if not can_promote(unit):
		return {}
	var base_class: String = unit.unit_class
	var paths := get_promotion_paths(base_class)
	var dest := dest_class if dest_class != "" else str(paths[0])
	var character: String = unit.unit_name if "unit_name" in unit else ""
	var gains := get_gains(base_class, dest, character)

	# Ganancias (sin HP en los datos de promoción de FE4/FE5).
	unit.strength   += int(gains.get("STR", 0))
	unit.magic      += int(gains.get("MAG", 0))
	unit.skill      += int(gains.get("SKL", 0))
	unit.speed      += int(gains.get("SPD", 0))
	unit.defense    += int(gains.get("DEF", 0))
	unit.resistance += int(gains.get("RES", 0))
	if "movement" in unit:
		unit.movement += int(gains.get("MOV", 0))
	unit.luck       += int(gains.get("LCK", 0))

	unit.unit_class = dest

	# Nivel tras promocionar:
	#   FE5 (Thracia) → reinicia a nivel 1 (estilo GBA/clásico).
	#   FE4 / SAGA    → continúa (se promociona a los 20 y sigue subiendo a 30).
	if _mode() == "FE5":
		unit.level = 1

	# Recortar a los topes de la clase destino (por modo).
	if unit.has_method("clamp_to_caps"):
		unit.clamp_to_caps()
	unit.current_hp = unit.max_hp

	return {"old_class": base_class, "new_class": dest, "gains": gains}
