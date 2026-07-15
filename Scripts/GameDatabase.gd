# GameDatabase.gd
# Autoload "GameDB". Base de datos NATIVA del juego: carga los .json de
# res://data/general/ (generados offline por tools/build_*.py desde el
# spreadsheet y los proyectos LT) y los expone como Resources tipados.
# Reemplaza a LTDatabase + LTImporter — el runtime NO parsea formato LT.
#
# Sin class_name (es autoload) → se accede globalmente como `GameDB`.
extends Node

const DATA_DIR := "res://data/general/"

var classes: Dictionary = {}     # nid (id) -> UnitClassData
var weapons: Dictionary = {}     # nid      -> WeaponData
var skills: Dictionary = {}      # nid      -> SkillData
var items: Dictionary = {}       # nid      -> ConsumableData
var units: Dictionary = {}       # nid      -> UnitDef
var levels: Dictionary = {}      # "game/nid" -> LevelData (ej. "fe4/0")
var terrains: Dictionary = {}    # game -> { terrain_nid -> entry Dictionary }

const GAMES := ["fe4", "fe5"]

func _ready() -> void:
	reload()

func reload() -> void:
	_load_terrains()
	# Indexado por nid LT (único). Los eventos LT referencian items/skills por
	# nid (give_item "Speed Ring", give_skill "Canto_Plus"); para casi todos los
	# items nid == name. Algunos skills comparten name (p.ej. Canto/Canto+),
	# por eso la clave debe ser nid, no name.
	classes = _load("classes.json", UnitClassData, "id")
	weapons = _load("weapons.json", WeaponData, "nid")
	skills  = _load("skills.json",  SkillData, "nid")
	items   = _load("items.json",   ConsumableData, "nid")
	units   = _load("units.json",   UnitDef, "nid")
	_load_levels()
	print("[GameDB] classes=%d weapons=%d skills=%d items=%d units=%d levels=%d" % [
		classes.size(), weapons.size(), skills.size(), items.size(), units.size(), levels.size()])

## Los niveles son un dict por archivo (no array) bajo data/<game>/levels/.
func _load_levels() -> void:
	levels.clear()
	for game in GAMES:
		var idx_path := "res://data/%s/levels/_index.json" % game
		if not FileAccess.file_exists(idx_path):
			continue
		var idx = JSON.parse_string(FileAccess.get_file_as_string(idx_path))
		if typeof(idx) != TYPE_ARRAY:
			continue
		for e in idx:
			var nid: String = str(e.get("nid", ""))
			var p := "res://data/%s/levels/%s.json" % [game, nid]
			if not FileAccess.file_exists(p):
				continue
			var d = JSON.parse_string(FileAccess.get_file_as_string(p))
			# Los niveles ahora son LT crudo (Array[1]); tomamos el dict.
			if typeof(d) == TYPE_ARRAY and not d.is_empty():
				d = d[0]
			if typeof(d) == TYPE_DICTIONARY:
				levels["%s/%s" % [game, nid]] = LevelData.from_dict(d)

## Carga tables/terrain.json por juego → terrains[game] = {nid: entry}.
func _load_terrains() -> void:
	terrains.clear()
	for game in GAMES:
		var p := "res://data/%s/tables/terrain.json" % game
		if not FileAccess.file_exists(p):
			continue
		var arr = JSON.parse_string(FileAccess.get_file_as_string(p))
		if typeof(arr) != TYPE_ARRAY:
			continue
		var by_nid := {}
		for e in arr:
			if typeof(e) == TYPE_DICTIONARY:
				by_nid[str(e.get("nid", ""))] = e
		terrains[game] = by_nid

## Entrada de terreno LT (name/color/mtype/status…) por nid y juego.
func get_terrain(game: String, nid: String) -> Dictionary:
	var by_nid: Dictionary = terrains.get(game, {})
	return by_nid.get(nid, {})

## Nombre legible del terreno (para mapear a TerrainSystem). "" si desconocido.
func terrain_name(game: String, nid: String) -> String:
	return str(get_terrain(game, nid).get("name", ""))


# ── Tablas de referencia LT (factions/parties/tags/lore/affinities/…) ─────────
# Cargadas bajo demanda de data/<game>/tables/<name>.json (Array), con caché.

var _tables_cache: Dictionary = {}   # "game/name" -> Array

## Devuelve una tabla como Array (o [] si no existe).
func get_table(game: String, name: String) -> Array:
	var key := "%s/%s" % [game, name]
	if not _tables_cache.has(key):
		_tables_cache[key] = _read_array("res://data/%s/tables/%s.json" % [game, name])
	return _tables_cache[key]

## La misma tabla indexada por 'nid'.
func get_table_indexed(game: String, name: String) -> Dictionary:
	var out := {}
	for e in get_table(game, name):
		if e is Dictionary:
			out[str(e.get("nid", ""))] = e
	return out

## Accesores concretos.
func get_factions(game: String) -> Array:       return get_table(game, "factions")
func get_faction(game: String, nid: String) -> Dictionary: return get_table_indexed(game, "factions").get(nid, {})
func get_parties(game: String) -> Array:         return get_table(game, "parties")
func get_party(game: String, nid: String) -> Dictionary:   return get_table_indexed(game, "parties").get(nid, {})
func get_tags(game: String) -> Array:            return get_table(game, "tags")           # Array[String]
func get_lore(game: String) -> Array:            return get_table(game, "lore")
func get_lore_entry(game: String, nid: String) -> Dictionary: return get_table_indexed(game, "lore").get(nid, {})
func get_affinities(game: String) -> Array:      return get_table(game, "affinities")
func get_affinity(game: String, nid: String) -> Dictionary: return get_table_indexed(game, "affinities").get(nid, {})
func get_raw_data(game: String, nid: String) -> Dictionary: return get_table_indexed(game, "raw_data").get(nid, {})
func get_support_constants(game: String) -> Array: return get_table(game, "support_constants")  # Array[[k,v]]
func get_difficulty_modes(game: String) -> Array:  return get_table(game, "difficulty_modes")
func get_difficulty_mode(game: String, nid: String) -> Dictionary:
	return get_table_indexed(game, "difficulty_modes").get(nid, {})

## Constante de soporte por clave (support_constants es Array de pares [k, v]).
func get_support_constant(game: String, key: String, default_val = null):
	for pair in get_support_constants(game):
		if pair is Array and pair.size() >= 2 and str(pair[0]) == key:
			return pair[1]
	return default_val

## Carga el grid de un tilemap nativo (res://data/<game>/tilemaps) vía
## TilemapLoader → { width, height, terrain: {Vector2i: terrain_nid} }.
## {} si no existe (el caller hace fallback a mapa plano).
func get_tilemap(game: String, nid: String) -> Dictionary:
	return TilemapLoader.load_tilemap("res://data/%s/tilemaps" % game, nid)

## Arma el `project_data` que LevelLoader/AIController/EventSystem consumen, a
## partir de la data NATIVA (sin capa LT). Devuelve dicts crudos indexados por
## nid en la forma que esos sistemas esperan:
##   units   -> general/units.json   (holy_blood Dict; LevelLoader lo acepta)
##   classes -> general/classes.json (clave "id")
##   items   -> union de general/weapons.json + items.json (armas con components)
##   terrain -> data/<game>/tables/terrain.json (clave nid)
##   ai      -> data/<game>/tables/ai.json (clave nid)
func build_project_data(game: String) -> Dictionary:
	var units := _read_indexed("res://data/general/units.json", "nid")
	# Reañadir los tags XxxHeir desde holy_blood Major (el generador los movió a
	# holy_blood) para que el gating prf de armas sagradas por tag funcione.
	for nid in units:
		var u: Dictionary = units[nid]
		var hb = u.get("holy_blood", {})
		if hb is Dictionary:
			var tags: Array = u.get("tags", []).duplicate() if u.get("tags") is Array else []
			for crus in hb:
				if str(hb[crus]) == "Major":
					var t := str(crus) + "Heir"
					if not (t in tags):
						tags.append(t)
			u["tags"] = tags
	var items := {}
	for fname in ["weapons.json", "items.json"]:
		for e in _read_array("res://data/general/" + fname):
			if e is Dictionary:
				items[str(e.get("nid", ""))] = e
	# Dificultad activa (Normal/Elite): la fija MainMenu como meta en GameMode.
	# Se incluye el modo entero para que LevelLoader aplique player/enemy/boss_bases.
	var diff_nid := "Normal"
	var gm := get_node_or_null("/root/GameMode")
	if gm != null and gm.has_meta("difficulty"):
		diff_nid = str(gm.get_meta("difficulty"))
	return {
		"units": units,
		"classes": _read_indexed("res://data/general/classes.json", "id"),
		"items": items,
		"terrain": _read_indexed("res://data/%s/tables/terrain.json" % game, "nid"),
		"ai": _read_indexed("res://data/%s/tables/ai.json" % game, "nid"),
		"difficulty": get_difficulty_mode(game, diff_nid),
	}

## Lee un .json array y devuelve el Array (o [] si falla).
func _read_array(path: String) -> Array:
	if not FileAccess.file_exists(path):
		return []
	var p = JSON.parse_string(FileAccess.get_file_as_string(path))
	return p if p is Array else []

## Lee un .json array de dicts y lo indexa por `key`.
func _read_indexed(path: String, key: String) -> Dictionary:
	var out := {}
	for e in _read_array(path):
		if e is Dictionary:
			out[str(e.get(key, ""))] = e
	return out

## Lee un .json (array de dicts) y construye {key_field: Resource via from_dict}.
func _load(file_name: String, type, key_field: String) -> Dictionary:
	var out := {}
	var path := DATA_DIR + file_name
	if not FileAccess.file_exists(path):
		push_warning("[GameDB] no existe %s" % path)
		return out
	var txt := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(txt)
	if typeof(parsed) != TYPE_ARRAY:
		push_error("[GameDB] %s no es un array JSON" % file_name)
		return out
	for entry in parsed:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var res = type.from_dict(entry)
		out[entry.get(key_field, "")] = res
	return out

# ── Accesores cómodos ─────────────────────────────────────────────────────────
func get_class_data(nid: String) -> UnitClassData: return classes.get(nid, null)
func get_weapon(nid: String) -> WeaponData:      return weapons.get(nid, null)
func get_skill(nid: String) -> SkillData:        return skills.get(nid, null)
func get_item(nid: String) -> ConsumableData:    return items.get(nid, null)
func get_unit(nid: String) -> UnitDef:           return units.get(nid, null)
func get_level(game: String, nid: String) -> LevelData: return levels.get("%s/%s" % [game, nid], null)

## Roster filtrado por juego ("FE4" / "FE5").
func units_for_game(game: String) -> Array:
	var r := []
	for u in units.values():
		if game in u.games:
			r.append(u)
	return r
