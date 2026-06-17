# Weapon.gd
# Clase de arma "ligera" que envuelve datos LT-maker canónicos.
#
# Se usa como TIPO concreto de Unit.weapon — LevelLoader devuelve instancias
# de esta clase al instanciar items con componente "weapon".
#
# Implementa la interfaz que CombatSystem y AIController esperan:
#   • might / accuracy / critical / weight / weapon_type / weapon_rank
#   • min_range / max_range
#   • is_magic
#   • can_attack_at_range(distance) -> bool
#   • has_component(name) -> bool         (para brave, status_on_hit Devil)
#   • get_component(name) -> any
#   • get_effective_tags() -> Array       (effective vs Armor/Cavalry/Flying)
#   • get_weapon_triangle_bonus(other) -> int
#   • use() / current_uses
#   • lose_uses_on_miss
#   • is_devil flag para DevilWeaponSystem

class_name Weapon
extends RefCounted

var id: String = ""
var name: String = ""
var weapon_type: String = ""
var weapon_rank: String = "E"
var might: int = 0
var accuracy: int = 0
var critical: int = 0
var weight: int = 0
var min_range: int = 1
var max_range: int = 1
var max_uses: int = -1
var current_uses: int = -1
var is_magic: bool = false
var is_devil: bool = false
var lose_uses_on_miss: bool = false
var status_on_hit: String = ""
var effective_tags: Array = []
# Componentes "raw" para has_component / get_component genéricos.
var _components: Dictionary = {}
# wexp_gain canónico LT: [bool, int]  (False/True usable + cuánto otorga).
var wexp_gain = null


# ── Aliases de compatibilidad (Weapon antiguo del proyecto) ──────────────────
#
# El proyecto Godot original tenía un Weapon con propiedades distintas
# (weapon_name, current_durability, max_durability).  Las siguientes
# propiedades getter-style mapean las antiguas a las nuevas.

@warning_ignore("unused_private_class_variable")
var weapon_name: String:
	get: return name
	set(v): name = v

@warning_ignore("unused_private_class_variable")
var current_durability: int:
	get: return current_uses if current_uses != -1 else 99
	set(v): current_uses = v

@warning_ignore("unused_private_class_variable")
var max_durability: int:
	get: return max_uses if max_uses != -1 else 99
	set(v): max_uses = v


# Aliases adicionales: range_min/range_max  ↔  min_range/max_range
# Algunos archivos usan unos y otros los otros.
@warning_ignore("unused_private_class_variable")
var range_min: int:
	get: return min_range
	set(v): min_range = v

@warning_ignore("unused_private_class_variable")
var range_max: int:
	get: return max_range
	set(v): max_range = v

# Tipos de armas que cuentan como mágicas para AS = SPD - max(0, WT - MAG).
const _MAGIC_TYPES := ["Anima", "Light", "Dark", "Fire", "Thunder", "Wind",
		"Ice", "Staff", "Tome", "Holy"]


# ══════════════════════════════════════════════════════════════════════════════
# CONSTRUCCIÓN
# ══════════════════════════════════════════════════════════════════════════════

## Construye un arma desde un Dictionary canónico LT (formato JSON crudo).
##   lt = { "nid":..., "name":..., "components": [["weapon",null], ["damage",5], ...] }
static func from_lt(lt_data: Dictionary):
	var w := Weapon.new()
	w.id = str(lt_data.get("nid", ""))
	w.name = str(lt_data.get("name", w.id))
	w._parse_components(lt_data.get("components", []))
	w.current_uses = w.max_uses
	return w


## Construye un arma desde un WeaponData nativo (GameDB.get_weapon). Reaprovecha
## los `components` crudos LT que el generador conservó → fidelidad idéntica a
## from_lt, sin depender de la capa LT. Es la ruta canónica del motor nativo.
static func from_data(wd) -> Weapon:
	var w := Weapon.new()
	if wd == null:
		return w
	w.id = str(wd.nid)
	w.name = str(wd.name)
	if not wd.components.is_empty():
		w._parse_components(wd.components)
	else:
		# Fallback a campos tipados (por si un WeaponData no llevara components).
		w.weapon_type = str(wd.weapon_type)
		w.might = int(wd.might); w.accuracy = int(wd.hit); w.critical = int(wd.crit)
		w.weight = int(wd.weight); w.min_range = int(wd.rng_min); w.max_range = int(wd.rng_max)
		w.max_uses = int(wd.uses) if wd.uses > 0 else -1
		w.is_magic = bool(wd.magic) or (w.weapon_type in _MAGIC_TYPES)
		w.status_on_hit = str(wd.status_on_hit)
		w.effective_tags = wd.effective_tags.duplicate()
	# El weapon_rank de las armas prf (sagradas/personales) viene vacío en
	# components → usar el typed ("" = sin requisito de rango).
	if w.weapon_rank == "E" and str(wd.rank) != "":
		w.weapon_rank = str(wd.rank)
	if not wd.prf_tags.is_empty():
		w._components["prf_tags"] = wd.prf_tags
	if not wd.prf_units.is_empty():
		w._components["prf_unit"] = wd.prf_units
	if str(wd.status_on_equip) != "":
		w._components["status_on_equip"] = wd.status_on_equip
	w.current_uses = w.max_uses
	return w


## Construye un arma desde una LTData.ItemData ya parseada por LTImporter.
##   item_data = LTData.ItemData con propiedades (might, hit, weapon_type, etc.)
##   ya rellenas.  Útil para integrar con tu LTImporter existente.
static func from_item_data(item_data):
	var w := Weapon.new()
	w.id = str(item_data.id)
	w.name = str(item_data.name)
	w.might = int(item_data.might)
	w.accuracy = int(item_data.hit)
	w.critical = int(item_data.crit)
	w.weight = int(item_data.weight)
	w.weapon_type = str(item_data.weapon_type)
	w.weapon_rank = str(item_data.level_req)
	w.min_range = int(item_data.rng_min)
	w.max_range = int(item_data.rng_max)
	w.max_uses = int(item_data.uses) if item_data.uses > 0 else -1
	w.current_uses = w.max_uses
	# effective_against viene como Array[String] de tags.
	for t in item_data.effective_against:
		w.effective_tags.append(str(t))
	# is_magic se infiere del weapon_type (mismos tipos que LT).
	w.is_magic = w.weapon_type in _MAGIC_TYPES
	# Devil weapon: el componente status_on_hit == "Devil".
	if "status_on_hit" in item_data.extra:
		w.status_on_hit = str(item_data.extra["status_on_hit"])
		if w.status_on_hit == "Devil":
			w.is_devil = true
	# lose_uses_on_miss — viene en extra desde LTImporter.
	if "lose_uses_on_miss" in item_data.extra:
		w.lose_uses_on_miss = bool(item_data.extra["lose_uses_on_miss"])
	# Volcar todos los components a _components para has_component.
	for c in item_data.components:
		w._components[str(c)] = true
	# prf_tags: armas Holy con restricción de blood.
	if "prf_tags" in item_data.extra:
		w._components["prf_tags"] = item_data.extra["prf_tags"]
	return w


# ══════════════════════════════════════════════════════════════════════════════
# PARSER DE COMPONENTES LT (para from_lt)
# ══════════════════════════════════════════════════════════════════════════════

func _parse_components(comps: Array) -> void:
	for c in comps:
		if not (c is Array) or c.size() < 1:
			continue
		var key := str(c[0])
		var val = c[1] if c.size() >= 2 else null
		_components[key] = val
		match key:
			"weapon":         pass  # marcador
			"target_enemy":   pass
			"damage":         might = int(val)
			"hit":             accuracy = int(val)
			"crit":           critical = int(val)
			"weight":         weight = int(val)
			"weapon_type":    weapon_type = str(val)
			"weapon_rank":    weapon_rank = str(val)
			"uses":           max_uses = int(val); current_uses = max_uses
			"min_range":      min_range = int(val)
			"max_range":      max_range = int(val)
			"magic":          is_magic = true
			"status_on_hit":
				status_on_hit = str(val)
				if status_on_hit == "Devil":
					is_devil = true
			"effective_tag":
				if val is Array:
					for t in val:
						effective_tags.append(str(t))
				else:
					effective_tags.append(str(val))
			"effective":
				# Componente canónico effective: [["tag"], damage_mult]
				if val is Array and val.size() >= 1 and val[0] is Array:
					for t in val[0]:
						effective_tags.append(str(t))
			"brave":          pass  # check vía has_component
			"lose_uses_on_miss": lose_uses_on_miss = true
			"uses_options":
				# Formato LT: [["LoseUsesOnMiss", "T"], ...]
				if val is Array:
					for opt in val:
						if opt is Array and opt.size() >= 2 \
								and "LoseUsesOnMiss" in str(opt[0]):
							lose_uses_on_miss = str(opt[1]).to_upper() == "T"
	# Inferir is_magic por weapon_type si no se marcó explícitamente.
	if not is_magic and weapon_type in _MAGIC_TYPES:
		is_magic = true


# ══════════════════════════════════════════════════════════════════════════════
# INTERFAZ DE COMBATE
# ══════════════════════════════════════════════════════════════════════════════

func can_attack_at_range(distance: int) -> bool:
	if max_uses != -1 and current_uses <= 0:
		return false
	return distance >= min_range and distance <= max_range


func has_component(comp_name: String) -> bool:
	return _components.has(comp_name)


func get_component(comp_name: String):
	return _components.get(comp_name, null)


func get_effective_tags() -> Array:
	return effective_tags.duplicate()


## Bonus del triángulo de armas vs otro arma.  +1 si tenemos ventaja,
## -1 si la tiene el otro, 0 si neutral.  Tabla canónica:
##   Sword > Axe > Lance > Sword;  Anima > Light > Dark > Anima.
##
## Se puede sobrescribir registrando una tabla externa con
## set_triangle_table(dict) — útil para usar la tabla del proyecto LT.
static var _triangle_table: Dictionary = {
	"Sword": "Axe", "Axe": "Lance", "Lance": "Sword",
	"Anima": "Light", "Light": "Dark", "Dark": "Anima",
}

static func set_triangle_table(table: Dictionary) -> void:
	_triangle_table = table


func get_weapon_triangle_bonus(other) -> int:
	if other == null:
		return 0
	var other_type := ""
	if "weapon_type" in other:
		other_type = str(other.weapon_type)
	if _triangle_table.get(weapon_type, "") == other_type:
		return 1
	if _triangle_table.get(other_type, "") == weapon_type:
		return -1
	return 0


## Consumir un uso del arma.
func use() -> void:
	if max_uses == -1:
		return
	current_uses = max(0, current_uses - 1)


## Stub para compat con add_wexp del Weapon antiguo.
## La ganancia real va vía Unit.gain_weapon_exp ahora — esto es no-op.
func add_wexp(_amount: int) -> void:
	pass
