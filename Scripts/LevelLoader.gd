# LevelLoader.gd
# Carga capítulos del proyecto LT-maker (formato JSON) en Godot.
#
# FORMATO DE UN CAPÍTULO LT (verificado contra GotHW/Thracia776):
#   {
#     "nid": "1",
#     "name": "Chapter 1",
#     "tilemap": "Prologue",        # ID del tilemap (resource externo)
#     "objective": {"win":..., "loss":..., "simple":...},
#     "music": { player_phase, enemy_phase, ... },
#     "party": "Sigurd",            # ID del party
#     "units": [
#       { "nid":..., "team":..., "ai":..., "starting_position":[x,y],
#         "generic":bool, ... + (si generic) klass/level/faction/items }
#     ],
#     "regions": [
#       { "nid":..., "region_type":..., "position":[x,y], "size":[w,h],
#         "sub_nid":..., "condition":..., "only_once":bool }
#     ],
#     "unit_groups": [
#       { "nid":..., "units":[id1, id2, ...], "positions": {} }
#     ]
#   }
#
# OBJETIVO DEL CAPÍTULO:
#   El campo objective.win es texto libre — el LevelLoader interpreta los
#   tipos canónicos: "Seize", "Rout", "Escape", "Survive N turns", "Defeat boss".
#   Esto se delega al ChapterObjective (clase aparte).
#
# TILEMAP:
#   El proyecto LT no incluye los archivos de tilemap en el rar de game_data
#   — son recursos externos en project/resources/tilemaps/<nid>.json.  Aquí
#   esperamos un Dictionary { "width":int, "height":int, "terrain": {[x,y]: nid} }
#   que el caller proporciona o deja vacío para generar plano.
#
# UNIDADES:
#   • "named" (generic=false): se buscan en units.json del proyecto y se
#     instancian con sus stats reales.
#   • "generic" (generic=true): se construyen con klass+level+faction y los
#     starting_items definidos directamente en el capítulo.

class_name LevelLoader
extends RefCounted


# ── Resultado de carga ────────────────────────────────────────────────────────

class LoadedLevel:
	var nid: String = ""
	var name_str: String = ""
	var tilemap_id: String = ""
	var width: int = 0
	var height: int = 0
	var objective: Dictionary = {}
	var music: Dictionary = {}
	var party_id: String = ""
	var units: Array[Unit] = []
	var regions: Array[Dictionary] = []
	var unit_groups: Dictionary = {}        # nid → grupo completo (units + positions)
	var fow_enabled: bool = false
	var fow_radius: int = 3
	var fog_los: bool = false


# ══════════════════════════════════════════════════════════════════════════════
# CARGA PRINCIPAL
# ══════════════════════════════════════════════════════════════════════════════

## Carga un capítulo desde su JSON y lo aplica al grid dado.
##   chapter_path  : ruta absoluta o res:// del archivo /levels/N.json
##   project_data  : Dictionary {units, classes, items, terrain, ai} cargado
##                   previamente por LTImporter (todos como Dictionary indexado por nid)
##   tilemap_data  : Dictionary {width, height, terrain} con el tile data del cap
##                   (puede ser vacío para tilemap plano por defecto)
##   grid          : el Grid donde colocar las unidades
##
## Devuelve un LoadedLevel completo con los campos rellenos.
static func load_chapter(chapter_path: String, project_data: Dictionary,
		tilemap_data: Dictionary, grid: Grid) -> LoadedLevel:
	var f := FileAccess.open(chapter_path, FileAccess.READ)
	if f == null:
		push_error("LevelLoader: no se pudo abrir %s" % chapter_path)
		return LoadedLevel.new()
	var raw_text := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(raw_text)
	if parsed == null or not (parsed is Array) or parsed.is_empty():
		push_error("LevelLoader: JSON inválido en %s" % chapter_path)
		return LoadedLevel.new()
	# El formato LT envuelve el capítulo en un Array de 1 elemento.
	return _build_level(parsed[0], project_data, tilemap_data, grid)


## Variante para uso desde memoria (testing o capítulos generados).
static func load_chapter_from_dict(chapter_dict: Dictionary, project_data: Dictionary,
		tilemap_data: Dictionary, grid: Grid) -> LoadedLevel:
	return _build_level(chapter_dict, project_data, tilemap_data, grid)


# ══════════════════════════════════════════════════════════════════════════════
# CONSTRUCCIÓN INTERNA
# ══════════════════════════════════════════════════════════════════════════════

static func _build_level(chap: Dictionary, project_data: Dictionary,
		tilemap_data: Dictionary, grid: Grid) -> LoadedLevel:
	var lvl := LoadedLevel.new()
	lvl.nid       = str(chap.get("nid", ""))
	lvl.name_str  = str(chap.get("name", ""))
	lvl.tilemap_id = str(chap.get("tilemap", ""))
	lvl.objective = chap.get("objective", {}) if chap.get("objective") else {}
	lvl.music     = chap.get("music", {}) if chap.get("music") else {}
	lvl.party_id  = str(chap.get("party", ""))

	# Aplicar tilemap (terrain_grid → grid.tiles).
	_apply_tilemap(grid, tilemap_data, project_data.get("terrain", {}))
	lvl.width  = grid.grid_width
	lvl.height = grid.grid_height

	# Cargar regiones — también pueden contener fog regions.
	for r in chap.get("regions", []):
		lvl.regions.append(_normalize_region(r))

	# Detectar fow_enabled y radio.  En LT el FoW se activa vía level_vars
	# (no en el JSON crudo); aquí soportamos un campo opcional "fow_enabled".
	# Si no está, se busca alguna región tipo "fog" como heurística.
	lvl.fow_enabled = bool(chap.get("fow_enabled", _has_fog_region(lvl.regions)))
	lvl.fow_radius  = int(chap.get("fow_radius", 3))
	lvl.fog_los     = bool(chap.get("fog_los", false))

	# Unit groups: guardamos el grupo completo (incluye nid, units, positions)
	# para que EventSystem pueda usar las positions canon de cada grupo.
	for g in chap.get("unit_groups", []):
		var nid := str(g.get("nid", ""))
		if nid != "":
			lvl.unit_groups[nid] = g

	# Cargar unidades.
	for u in chap.get("units", []):
		var unit := build_unit(u, project_data)
		if unit == null:
			continue
		lvl.units.append(unit)
		grid.place_unit(unit, unit.grid_position)

	return lvl


## Aplica el terrain_grid al grid de Godot.  Si tilemap_data está vacío,
## genera un plano por defecto del tamaño del grid actual.
static func _apply_tilemap(grid: Grid, tilemap_data: Dictionary,
		terrain_db: Dictionary) -> void:
	if tilemap_data.is_empty():
		# Re-inicializar el grid existente como plain, sin tocar dimensiones.
		grid.initialize_grid()
		return
	# Reconfigurar dimensiones si el tilemap las define.
	if tilemap_data.has("width"):
		grid.grid_width = int(tilemap_data["width"])
	if tilemap_data.has("height"):
		grid.grid_height = int(tilemap_data["height"])
	grid.tiles.clear()
	# Inicialización plana base.
	for x in range(grid.grid_width):
		for y in range(grid.grid_height):
			grid.tiles[Vector2i(x, y)] = {
				"walkable": true, "terrain_type": "plain",
				"defense_bonus": 0, "avoid_bonus": 0,
			}
	# Aplicar el terrain real desde el tilemap.
	var terrain_grid: Dictionary = tilemap_data.get("terrain", {})
	for key in terrain_grid.keys():
		var pos: Vector2i = _coord_to_vec(key)
		var nid: String   = str(terrain_grid[key])
		var t_id: String  = _resolve_terrain_id(nid, terrain_db)
		var tdata := TerrainSystem.get_terrain_data(t_id)
		grid.tiles[pos] = {
			"walkable": float(tdata.get("mov", 1.0)) >= 0.0,
			"terrain_type": t_id,
			"defense_bonus": int(tdata.get("def", 0)),
			"avoid_bonus":  int(tdata.get("avo", 0)),
		}


## Convierte un nid de terrain LT al id usado por TerrainSystem.
##   El terrain_db viene de project_data["terrain"] y mapea nid → name.
##   Soporta dos formatos:
##     • Dictionary crudo: { "name": "Plain", ... }
##     • LTData.TerrainData (Resource con propiedad .name)
##   Ej: "1" → "Plain" → "plain".
static func _resolve_terrain_id(nid: String, terrain_db: Dictionary) -> String:
	if terrain_db.has(nid):
		var entry = terrain_db[nid]
		var name_str := ""
		if entry is Dictionary:
			name_str = str(entry.get("name", ""))
		elif "name" in entry:
			name_str = str(entry.name)
		return name_str.to_lower() if name_str != "" else "plain"
	# Si no hay db, asumir que el nid ya viene en formato legible (testing).
	return nid.to_lower()


## Coordenadas pueden venir como "[x,y]" o como Array [x,y] o como String "x,y".
static func _coord_to_vec(key) -> Vector2i:
	if key is Array and key.size() >= 2:
		return Vector2i(int(key[0]), int(key[1]))
	if key is Vector2i:
		return key
	# strip_edges en GDScript NO acepta caracteres (solo bools left/right).
	# Limpiamos los corchetes y espacios manualmente con replace.
	var s := str(key).replace("[", "").replace("]", "").replace(" ", "").strip_edges()
	var parts := s.split(",")
	if parts.size() >= 2:
		return Vector2i(int(parts[0]), int(parts[1]))
	return Vector2i.ZERO


## Construye una Unit a partir de la entrada JSON de un capítulo.
##   Para unidades named (generic=false): busca su definición en
##   project_data["units"] y aplica clase, stats y skills.
##   Para genéricas: usa klass + level del capítulo + items del capítulo.
static func build_unit(udef: Dictionary, project_data: Dictionary) -> Unit:
	var unit := Unit.new()
	var nid := str(udef.get("nid", ""))
	var team := str(udef.get("team", "enemy"))
	unit.unit_name = nid
	unit.is_player_unit = (team == "player")
	unit.team = team   # para la paleta del map sprite (Player/Enemy/Ally/Other)

	# Posición.
	var sp = udef.get("starting_position", [0, 0])
	if sp is Array and sp.size() >= 2:
		unit.grid_position = Vector2i(int(sp[0]), int(sp[1]))

	# AI preset (string).  Lo guardamos en metadata para AIController.
	unit.set_meta("ai_preset", str(udef.get("ai", "None")))
	if udef.get("ai_group"):
		unit.set_meta("ai_group", str(udef["ai_group"]))

	# Generic vs named.
	var is_generic := bool(udef.get("generic", false))
	if is_generic:
		_apply_generic(unit, udef, project_data)
	else:
		_apply_named(unit, nid, project_data)

	# Género: prioridad al override de la def del cap; si no, el de units.json
	# (nombradas); default M para nombradas y U (universal) para genéricas.
	var gender = udef.get("gender", null)
	if gender == null and not is_generic:
		var udb = project_data.get("units", {})
		if udb is Dictionary and udb.has(nid) and udb[nid] is Dictionary:
			gender = udb[nid].get("gender", null)
	if gender == null:
		gender = "U" if is_generic else "M"
	unit.gender = str(gender).to_upper()

	# Tag de boss si el preset AI lo indica explícitamente o el nid lo lleva.
	# (LT marca bosses normalmente vía fields o ai dedicada — heurística.)
	var ai_name := str(udef.get("ai", ""))
	if ai_name in ["Boss", "Berserk", "JoshuaDefend"]:
		unit.set_meta("is_boss", true)

	# Bonus de dificultad (Normal/Elite) según bando/boss.
	_apply_difficulty(unit, udef, project_data)

	# Inicializar ballista si la clase lo es.
	if BallistaSystem.is_ballista(unit):
		BallistaSystem.initialize(unit, "enemy" if team == "enemy" else "player")

	# Aplicar efectos pasivos del equipo (anillos on_hold, arma on_equip).
	if unit.has_method("refresh_item_effects"):
		unit.refresh_item_effects()

	return unit


## Suma los `*_bases` del modo de dificultad activo (project_data["difficulty"])
## a los stats de la unidad: player→player_bases, boss→boss_bases, resto→enemy_bases.
static func _apply_difficulty(unit: Unit, udef: Dictionary, project_data: Dictionary) -> void:
	var diff = project_data.get("difficulty", {})
	if not (diff is Dictionary) or diff.is_empty():
		return
	var team := str(udef.get("team", "enemy"))
	var bases
	if team == "player":
		bases = diff.get("player_bases", {})
	elif unit.has_meta("is_boss") and bool(unit.get_meta("is_boss")):
		bases = diff.get("boss_bases", {})
	else:
		bases = diff.get("enemy_bases", {})
	if not (bases is Dictionary):
		return
	if bases.has("HP"):
		unit.max_hp += int(bases["HP"])
		unit.current_hp = unit.max_hp
	if bases.has("STR"): unit.strength     += int(bases["STR"])
	if bases.has("MAG"): unit.magic        += int(bases["MAG"])
	if bases.has("SKL"): unit.skill        += int(bases["SKL"])
	if bases.has("SPD"): unit.speed        += int(bases["SPD"])
	if bases.has("LCK"): unit.luck         += int(bases["LCK"])
	if bases.has("DEF"): unit.defense      += int(bases["DEF"])
	if bases.has("RES"): unit.resistance   += int(bases["RES"])
	if bases.has("CON"): unit.constitution += int(bases["CON"])
	if bases.has("MOV"): unit.movement     += int(bases["MOV"])


## Aplica los stats de una unidad GENÉRICA (la definición está en el cap).
static func _apply_generic(unit: Unit, udef: Dictionary, project_data: Dictionary) -> void:
	unit.unit_class = str(udef.get("klass", "Soldier"))
	unit.level      = int(udef.get("level", 1))
	# Bases de la clase.
	var classes: Dictionary = project_data.get("classes", {})
	if classes.has(unit.unit_class):
		_apply_class_data(unit, _resolve_class_version(classes[unit.unit_class]))
	# Skills iniciales — formato puede ser:
	#   ["SkillName", ...]               (string suelto)
	#   [[level, "SkillName"], ...]      (formato canónico LT)
	for entry in udef.get("starting_skills", []):
		var skill_nid := ""
		if entry is Array and entry.size() >= 2:
			skill_nid = str(entry[1])
		elif entry is String:
			skill_nid = str(entry)
		if skill_nid != "":
			unit.learn_skill(skill_nid)
	# Items iniciales — formato LT [[item_nid, dropable_bool], ...]
	var items_db: Dictionary = project_data.get("items", {})
	for entry in udef.get("starting_items", []):
		var item_nid := ""
		if entry is Array and entry.size() >= 1:
			item_nid = str(entry[0])
		else:
			item_nid = str(entry)
		var item = _instantiate_item(item_nid, items_db)
		if item != null:
			unit.inventory.append(item)
			# El primer item armable se equipa por defecto.
			if "weapon" in unit and unit.weapon == null and _is_weapon(item):
				unit.weapon = item


## Aplica los stats de una unidad NAMED (definición en project_data["units"]).
##
## IMPORTANTE — formato canónico LT:
##   Los `bases` del personaje en units.json son los stats ABSOLUTOS al
##   nivel de aparición — NO son deltas sobre la clase.  Por eso aquí
##   NO llamamos a _apply_class_data para los stats; solo heredamos los
##   tags de la clase (Mounted, Flying, etc.).
##   El campo MOV viene escalado ×10 (90 = 9 tiles), lo dividimos.
static func _apply_named(unit: Unit, nid: String, project_data: Dictionary) -> void:
	var units_db: Dictionary = project_data.get("units", {})
	if not units_db.has(nid):
		push_warning("LevelLoader: unidad named '%s' no encontrada en project_data" % nid)
		return
	var udata: Dictionary = units_db[nid]
	# Personajes cross-game (aparecen en FE4 y FE5): resuelve el bloque de
	# versión según el modo de juego (FE4_ONLY→FE4, FE5_ONLY→FE5, SAGA→la más
	# débil, que luego escala a través de ambos juegos).
	udata = _resolve_game_version(udata)
	unit.unit_class = str(udata.get("klass", "Soldier"))
	unit.level      = int(udata.get("level", 1))
	# Stats absolutos del personaje al nivel de aparición.
	var bases: Dictionary = udata.get("bases", {})
	_apply_bases_to_unit(unit, bases)
	# Heredar tags de la clase (Mounted, Flying, etc.) sin sobrescribir stats.
	var classes: Dictionary = project_data.get("classes", {})
	if classes.has(unit.unit_class):
		var cdata = _resolve_class_version(classes[unit.unit_class])
		var class_tags = cdata.get("tags", []) if cdata is Dictionary else cdata.tags
		for tag in class_tags:
			var s := str(tag)
			if not (s in unit.tags):
				unit.tags.append(s)
	# Tags propios del personaje (Lord, BaldrHeir, etc.)
	for tag in udata.get("tags", []):
		var s := str(tag)
		if not (s in unit.tags):
			unit.tags.append(s)
	# Skills personales.
	# Formato canónico LT: [[level_int, skill_nid_string], ...]
	# Cada entrada indica el nivel al que se aprende esa skill.
	# Para una unidad recién cargada solo aprendemos las skills cuyo
	# learn_level sea <= unit.level.
	for entry in udata.get("learned_skills", []):
		var skill_nid := ""
		var learn_level := 1
		if entry is Array and entry.size() >= 2:
			learn_level = int(entry[0])
			skill_nid = str(entry[1])
		elif entry is String:
			skill_nid = str(entry)
		if skill_nid != "" and learn_level <= unit.level:
			unit.learn_skill(skill_nid)
	# Weapon EXP inicial — nativo: {type: wexp_int} (E/D/C/B/A/Holy por umbral).
	var wg = udata.get("wexp_gain", {})
	if wg is Dictionary and "wexp" in unit:
		for wt in wg:
			unit.wexp[str(wt)] = int(wg[wt])
	# Holy blood — nativo: Dict {"Baldr":"Major"}; legacy LT: [["Baldr","Major"]].
	var hb_data = udata.get("holy_blood", {})
	if hb_data is Dictionary:
		for crus in hb_data:
			unit.holy_blood[str(crus)] = str(hb_data[crus])
	elif hb_data is Array:
		for hb in hb_data:
			if hb is Array and hb.size() >= 2:
				unit.holy_blood[str(hb[0])] = str(hb[1])
	# Inventario inicial.
	var items_db: Dictionary = project_data.get("items", {})
	for entry in udata.get("starting_items", []):
		var item_nid := ""
		if entry is Array and entry.size() >= 1:
			item_nid = str(entry[0])
		else:
			item_nid = str(entry)
		var item = _instantiate_item(item_nid, items_db)
		if item != null:
			unit.inventory.append(item)
			if "weapon" in unit and unit.weapon == null and _is_weapon(item):
				unit.weapon = item


## ── Versiones por juego (personajes cross-game FE4/FE5) ──────────────────────
## Una unidad con campo `versions` lleva bloques específicos por juego, p.ej.:
##   "versions": {
##     "FE4": { "klass": "CavalierS", "level": 1, "bases": {...}, ... },
##     "FE5": { "klass": "Ranger",    "level": 3, "bases": {...}, ... }
##   }
## El bloque elegido SOBREESCRIBE los campos que declara sobre la unidad base
## (klass/level/bases/growths/learned_skills/starting_items/wexp_gain/holy_blood);
## los campos ausentes se heredan del nivel superior (portrait, tags, etc.).
##   FE4_ONLY → FE4 · FE5_ONLY → FE5 · SAGA → la versión más débil (menor suma
##   de bases; desempata por menor nivel), que luego escala a través de ambos.
static func _resolve_game_version(udata: Dictionary) -> Dictionary:
	var versions = udata.get("versions", null)
	if not (versions is Dictionary) or (versions as Dictionary).is_empty():
		return udata
	var mode := _current_game_mode()
	var chosen: Dictionary = {}
	if mode == "FE4" and versions.has("FE4"):
		chosen = versions["FE4"]
	elif mode == "FE5" and versions.has("FE5"):
		chosen = versions["FE5"]
	else:
		chosen = _weaker_version(versions)   # SAGA (o modo sin versión propia)
	if not (chosen is Dictionary) or chosen.is_empty():
		return udata
	var merged := udata.duplicate(true)
	for k in chosen:
		merged[k] = chosen[k]
	merged.erase("versions")
	return merged

## Resuelve el bloque de stats de clase por modo. Una clase con campo
## `versions` lleva sets por juego, p.ej.:
##   "versions": { "FE4": {"bases":{...},"caps":{...},"promotion":{...}, ...},
##                 "FE5": {...}, "SAGA": {...} }
## El bloque del modo activo SOBREESCRIBE los campos que declara.  Los dicts
## anidados (bases/caps/promotion/growths/wexp_gain) se mezclan POR-STAT, así que
## un bloque que solo trae 8 stats conserva CON/MOV (y demás) del nivel superior.
## Si el modo NO tiene bloque propio, se usa el nivel superior tal cual (es el
## valor por defecto / SAGA).  Sólo actúa sobre cdata en forma de Dictionary.
static func _resolve_class_version(cdata):
	if not (cdata is Dictionary):
		return cdata
	var versions = (cdata as Dictionary).get("versions", null)
	if not (versions is Dictionary) or (versions as Dictionary).is_empty():
		return cdata
	var block = versions.get(_current_game_mode(), null)
	if not (block is Dictionary):
		# Modo sin bloque propio → nivel superior (default/SAGA), sin `versions`.
		var base_only: Dictionary = (cdata as Dictionary).duplicate(true)
		base_only.erase("versions")
		return base_only
	var merged: Dictionary = (cdata as Dictionary).duplicate(true)
	for k in block:
		if k == "versions":
			continue
		if merged.has(k) and merged[k] is Dictionary and block[k] is Dictionary:
			var sub: Dictionary = (merged[k] as Dictionary).duplicate(true)
			for sk in block[k]:
				sub[sk] = block[k][sk]
			merged[k] = sub
		else:
			merged[k] = block[k]
	merged.erase("versions")
	return merged


## "FE4" | "FE5" | "SAGA" a partir de GameMode.current_mode (autoload).
static func _current_game_mode() -> String:
	var loop := Engine.get_main_loop()
	if loop is SceneTree and loop.root != null:
		var gm = loop.root.get_node_or_null("GameMode")
		if gm != null and "current_mode" in gm:
			match int(gm.current_mode):
				0: return "FE4"   # Mode.FE4_ONLY
				1: return "FE5"   # Mode.FE5_ONLY
				2: return "SAGA"  # Mode.SAGA_MODE
	return "SAGA"

## Devuelve el bloque de versión con MENOR suma de bases (desempate: menor
## nivel).  Es el arranque en SAGA: la versión más débil que luego escala.
static func _weaker_version(versions: Dictionary) -> Dictionary:
	var best: Dictionary = {}
	var best_key := 1 << 30
	for k in versions:
		var v = versions[k]
		if not (v is Dictionary):
			continue
		var b: Dictionary = v.get("bases", {})
		var s := 0
		for stat in ["HP", "STR", "MAG", "SKL", "SPD", "LCK", "DEF", "RES"]:
			s += int(b.get(stat, 0))
		# Empaqueta (suma_bases, nivel) para desempatar por nivel más bajo.
		var score := s * 1000 + int(v.get("level", 1))
		if score < best_key:
			best_key = score
			best = v
	return best


## Aplica los stats base de una clase a la unidad (bases + max_stats sirven
## como punto de partida si la unidad no tiene bases personales).
static func _apply_class_data(unit: Unit, cdata) -> void:
	# cdata puede ser Dictionary (datos crudos) o LTData.ClassData.
	var bases: Dictionary
	var tags
	var learned
	if cdata is Dictionary:
		bases = cdata.get("bases", {})
		tags = cdata.get("tags", [])
		learned = cdata.get("learned_skills", [])
	else:
		bases = cdata.bases if "bases" in cdata else {}
		tags = cdata.tags if "tags" in cdata else []
		learned = cdata.learned_skills if "learned_skills" in cdata else []
	_apply_bases_to_unit(unit, bases)
	for tag in tags:
		var s := str(tag)
		if not (s in unit.tags):
			unit.tags.append(s)
	# Skills de clase (canon LT: [[learn_level, skill_nid], ...])
	# Aplicar solo las que la unidad ya alcanzó por nivel.
	for entry in learned:
		var skill_nid := ""
		var learn_level := 1
		if entry is Array and entry.size() >= 2:
			learn_level = int(entry[0])
			skill_nid = str(entry[1])
		elif entry is String:
			skill_nid = str(entry)
		if skill_nid != "" and learn_level <= unit.level:
			unit.learn_skill(skill_nid)


## Mapea un Dictionary de bases LT a las propiedades concretas de Unit.
##
## NOTA — escalado de MOV en datos LT:
##   Los proyectos LT-maker guardan MOV escalado ×10 (Sigurd MOV 90, Cavalier
##   80) porque LT usa costes int y necesita simular costes decimales como
##   road=0.7 multiplicando todo por 10.  Aquí dividimos para usar floats
##   nativos: Sigurd → 9.0, Cavalier → 8.0, etc.  TerrainSystem usa los
##   costes decimales reales (plain=1.0, road=0.7, forest=2.0).
static func _apply_bases_to_unit(unit: Unit, bases: Dictionary) -> void:
	if bases.has("HP"):  unit.max_hp = int(bases["HP"]); unit.current_hp = unit.max_hp
	if bases.has("STR"): unit.strength = int(bases["STR"])
	if bases.has("MAG"): unit.magic = int(bases["MAG"])
	if bases.has("SKL"): unit.skill = int(bases["SKL"])
	if bases.has("SPD"): unit.speed = int(bases["SPD"])
	if bases.has("LCK"): unit.luck = int(bases["LCK"])
	if bases.has("DEF"): unit.defense = int(bases["DEF"])
	if bases.has("RES"): unit.resistance = int(bases["RES"])
	if bases.has("CON"): unit.constitution = int(bases["CON"])
	if bases.has("MOV"):
		# Datos LT vienen ×10.  Si parece pequeño (≤30) ya está en formato
		# real y lo usamos tal cual (compat con escenarios de test/legacy).
		var mov_raw: int = int(bases["MOV"])
		unit.movement = float(mov_raw) / 10.0 if mov_raw > 30 else float(mov_raw)


## Factory inyectable para items.  Por defecto se usa el ItemDatabase del
## proyecto (Items.gd).  Se puede sobrescribir desde tests con
## set_item_factory(func(nid) -> ...).
##
## La factory recibe (item_nid: String, lt_data: Dictionary) y debe devolver
## el item listo para usarse — típicamente un LTWeapon o un ItemData del
## proyecto.  Devolver null si el item no existe.
static var _item_factory: Callable = Callable()

static func set_item_factory(factory: Callable) -> void:
	_item_factory = factory


## Instancia un item desde la base de datos del proyecto.  Devuelve null si
## el item no existe.  Estrategia de resolución:
##   1) Si hay item_factory inyectada (testing), usarla.
##   2) Si los datos del item incluyen "components" con "weapon", construir
##      un Weapon vía Weapon.from_lt().  Esta es la ruta canónica para
##      datos LT crudos (formato JSON).
##   3) Si los datos vienen como LTData.ItemData (objeto Resource ya
##      parseado por LTImporter), construir vía Weapon.from_item_data().
##   4) Fallback: devolver el dict crudo (consumibles, anillos, etc.).
static func _instantiate_item(item_nid: String, items_db: Dictionary):
	# 1. Factory inyectada.
	if _item_factory.is_valid():
		var lt_data: Dictionary = items_db.get(item_nid, {}) if items_db.get(item_nid) is Dictionary else {}
		var fresh = _item_factory.call(item_nid, lt_data)
		if fresh != null:
			return fresh
	if not items_db.has(item_nid):
		return null
	var entry = items_db[item_nid]
	# 3. Si es un LTData.ItemData (tiene weapon_type como propiedad), Weapon
	# se construye vía from_item_data.  Detectamos por duck-typing.
	if not (entry is Dictionary):
		# Asumimos LTData.ItemData o similar — usar from_item_data si tiene
		# weapon_type definido.
		if "weapon_type" in entry and str(entry.weapon_type) != "":
			return Weapon.from_item_data(entry)
		# No es un arma — consumible. Se DUPLICA para que los usos (uses) sean
		# por-instancia y no corrompan el recurso compartido de GameDB.
		return entry.duplicate(true) if entry is Resource else entry
	# 2. Datos LT crudos en Dictionary.
	if _lt_is_weapon(entry):
		return Weapon.from_lt(entry)
	# 4. Item no-weapon (consumible, ring, etc.) → dict crudo.
	return entry.duplicate(true)


## ¿Un Dictionary de item LT representa un arma? — busca componente "weapon".
static func _lt_is_weapon(lt: Dictionary) -> bool:
	for c in lt.get("components", []):
		if c is Array and c.size() >= 1 and str(c[0]) == "weapon":
			return true
	return false


## Heurística para saber si un item es un arma (tiene weapon_type).
static func _is_weapon(item) -> bool:
	# Sólo las instancias Weapon (armas de combate) se equipan en unit.weapon.
	# Los báculos/objetos vuelven como Dictionary desde _instantiate_item (no
	# tienen componente "weapon") y NO deben asignarse a unit.weapon (tipo Weapon).
	return item is Weapon


# ══════════════════════════════════════════════════════════════════════════════
# REGIONS
# ══════════════════════════════════════════════════════════════════════════════

## Normaliza una región al formato que el GameManager / RegionSystem
## consumirá: incluye position, size y campos coercionados a tipos Godot.
static func _normalize_region(r: Dictionary) -> Dictionary:
	var pos = r.get("position", [0, 0])
	var size = r.get("size", [1, 1])
	return {
		"nid":            str(r.get("nid", "")),
		"region_type":    str(r.get("region_type", "normal")),
		"position":       Vector2i(int(pos[0]), int(pos[1])) if pos is Array else Vector2i.ZERO,
		"size":           Vector2i(int(size[0]), int(size[1])) if size is Array else Vector2i.ONE,
		"sub_nid":        str(r.get("sub_nid", "")),
		"condition":      str(r.get("condition", "True")),
		"only_once":      bool(r.get("only_once", false)),
		"interrupt_move": bool(r.get("interrupt_move", false)),
	}


## Heurística: si hay alguna región tipo "fog" se considera FoW activo.
static func _has_fog_region(regions: Array) -> bool:
	for r in regions:
		if r is Dictionary and str(r.get("region_type", "")) == "fog":
			return true
	return false
