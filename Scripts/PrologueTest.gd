# PrologueTest.gd
# Escena de test que carga el Prologue real de Genealogy of the Holy War.
#
# REQUISITOS:
#   1. Tener los datos del proyecto FE4 LT-maker en res://data/fe4/  con
#      la estructura:
#        res://data/fe4/
#          ├── units.json
#          ├── classes.json
#          ├── items.json
#          ├── terrain.json
#          ├── ai.json
#          ├── support_pairs.json
#          ├── support_ranks.json
#          └── levels/0.json
#   2. Tener los tilemaps en res://data/fe4_tilemaps/  con:
#        ├── tilemap.json
#        └── tilemap_data/Prologue.json
#   3. Los scripts de Fase 1-4 ya copiados a res://Scripts/.
#
# USO:
#   1. Crear una nueva escena en Godot:
#        Scene2D root → añadir hijo Camera2D
#                     → añadir hijo Node llamado "GameManager" con script GameManager.gd
#   2. Asignar a la raíz este script (PrologueTest.gd).
#   3. Run scene (F6).
#
# El test carga el cap, instancia las unidades en el grid y arranca el
# turno del jugador.  El log de la consola debería mostrar las posiciones
# y stats de las unidades cargadas.
#
# DEPURACIÓN:
#   • Si ves "[LevelLoader] unidad named 'Sigurd' no encontrada" → el
#     project_data no se cargó correctamente.  Comprueba la ruta DATA_ROOT.
#   • Si las unidades aparecen sin armas → el shimmer Items todavía no
#     funciona; revisa el ItemDB.
#   • Si "Tilemap loader devuelve {}" → la ruta TILEMAP_ROOT es incorrecta.

extends Node2D

# ── Configuración ────────────────────────────────────────────────────────────

const DATA_ROOT     := "res://data/fe4/"
const TILEMAP_ROOT  := "res://assets/tilemaps/FE4/"
const CHAPTER_PATH  := "res://data/fe4/levels/0.json"

# Si está activo, hace prints muy verbosos del estado tras cargar.
const VERBOSE := true

# Desplazamiento vertical del objetivo de cámara al centrar en una unidad, en
# casillas (negativo = hacia arriba). El sprite se ancla con los pies bajo el
# centro de la casilla, así que subimos ~media casilla para centrar la unidad.
const CAMERA_Y_OFFSET_CELLS := -0.5

# DEBUG: instancia una rejilla de unidades en cada paleta de equipo para
# verificar el shader. Poner en false para desactivar.
const DEBUG_PALETTES := true

# ── Referencias ──────────────────────────────────────────────────────────────

@onready var game_manager: Node = $GameManager
@onready var camera: Camera2D = $Camera2D


# ══════════════════════════════════════════════════════════════════════════════
# CICLO DE VIDA
# ══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	if game_manager == null:
		push_error("[PrologueTest] GameManager no encontrado como hijo.")
		return

	# 1. project_data desde la base de datos NATIVA (GameDB) — sin capa LT.
	#    GameDB lee data/general/* + data/fe4/tables/* y lo entrega en la forma
	#    que LevelLoader/AIController/EventSystem esperan.
	var project_data: Dictionary = GameDB.build_project_data("fe4")
	game_manager.project_data = project_data
	if VERBOSE:
		print("[PrologueTest] Datos cargados:")
		print("  units:    %d" % project_data.get("units",   {}).size())
		print("  classes:  %d" % project_data.get("classes", {}).size())
		print("  items:    %d" % project_data.get("items",   {}).size())
		print("  terrain:  %d" % project_data.get("terrain", {}).size())
		print("  ai:       %d" % project_data.get("ai",      {}).size())

	# 2. Tilemap real del Prologue desde GameDB (res://data/fe4/tilemaps).
	var tilemap_data := GameDB.get_tilemap("fe4", "Prologue")
	if VERBOSE:
		print("[PrologueTest] Tilemap: %dx%d, %d tiles definidos" % [
			tilemap_data.get("width", 0),
			tilemap_data.get("height", 0),
			tilemap_data.get("terrain", {}).size(),
		])

	# 3. Cargar support pairs / ranks.
	var support_pairs: Array = _load_json_array(DATA_ROOT + "support_pairs.json")
	var support_ranks: Array = _load_json_array(DATA_ROOT + "support_ranks.json")

	# 4. Cargar todos los eventos del proyecto.
	var events_data: Array = _load_all_events(DATA_ROOT + "events/")
	if VERBOSE:
		print("[PrologueTest] Eventos: %d" % events_data.size())

	# 5. Cargar el capítulo.
	game_manager.load_chapter(CHAPTER_PATH, tilemap_data, events_data,
			support_pairs, support_ranks)

	if VERBOSE:
		_dump_chapter_state()

	# 5.5. Pintar el mapa pre-renderizado como fondo.  El PNG está en
	#      res://assets/tilesets/FE4/Prologue.png y mide 1024×512 (64×32 tiles
	#      a 16px nativo).  MapBackground lo escala al cell_size del Grid.
	_setup_map_background()

	# 6. Centrar cámara en Sigurd.
	_center_camera_on_lord()

	# 7. Arrancar turno del jugador.
	game_manager.start_player_turn()

	# 8. DEBUG: rejilla de unidades en todas las paletas de equipo.
	_spawn_palette_debug()


## Crea un MapBackground hijo con el tilemap del Prologue.  Si los assets
## no están copiados todavía, simplemente no hace nada (sin error).
func _setup_map_background() -> void:
	# Buscar el Prologue.png en la nueva estructura tilesets/{FE4,FE5,raíz}.
	var bg_path := ""
	for base in ["res://assets/tilesets/FE4/",
			"res://assets/tilesets/FE5/",
			"res://assets/tilesets/"]:
		var candidate: String = base + "Prologue.png"
		if ResourceLoader.exists(candidate):
			bg_path = candidate
			break
	if bg_path == "":
		if VERBOSE:
			print("[PrologueTest] Prologue.png no encontrado — sin fondo de mapa")
		return
	var bg := MapBackground.new()
	bg.name = "MapBackground"
	bg.tilemap_nid = "Prologue"
	if game_manager.grid != null:
		bg.cell_size = game_manager.grid.cell_size
	else:
		bg.cell_size = 32
	add_child(bg)
	move_child(bg, 0)
	if VERBOSE:
		print("[PrologueTest] MapBackground cargado: %s (%dx escalado)" % [
			bg_path,
			bg.cell_size / bg.native_tile_size
		])


# ══════════════════════════════════════════════════════════════════════════════
# CARGA DE DATOS DEL PROYECTO
# ══════════════════════════════════════════════════════════════════════════════

## Lee TODOS los JSONs del proyecto y los convierte a Dictionaries indexados
## por nid.  Cada JSON top-level es un Array de objetos con campo "nid".
func _load_project_data(root: String) -> Dictionary:
	var dir := root if root.ends_with("/") else root + "/"
	return {
		"units":   _load_indexed_json(dir + "units.json"),
		"classes": _load_indexed_json(dir + "classes.json"),
		"items":   _load_indexed_json(dir + "items.json"),
		"terrain": _load_indexed_json(dir + "terrain.json", true),  # también por nid
		"ai":      _load_indexed_json(dir + "ai.json"),
	}


## Lee un JSON tipo [{nid:..., ...}, ...] y devuelve {nid: obj}.
##   include_name_too: si true, indexa también por entry["name"].
func _load_indexed_json(path: String, include_name_too: bool = false) -> Dictionary:
	var arr := _load_json_array(path)
	var out: Dictionary = {}
	for entry in arr:
		if not (entry is Dictionary):
			continue
		var nid := str(entry.get("nid", ""))
		if nid != "":
			out[nid] = entry
		if include_name_too and entry.has("name"):
			out[str(entry["name"])] = entry
	return out


## Lee un archivo JSON que es un Array.  Devuelve [] si falla.
func _load_json_array(path: String) -> Array:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_warning("[PrologueTest] No se pudo abrir %s" % path)
		return []
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is Array:
		return parsed
	return []


## Carga todos los eventos de un directorio (un evento por archivo).
##   Cada archivo es un Array[1] con un Dict.
func _load_all_events(events_dir: String) -> Array:
	var out: Array = []
	var d := DirAccess.open(events_dir)
	if d == null:
		return out
	d.list_dir_begin()
	var fname := d.get_next()
	while fname != "":
		if not d.current_is_dir() and fname.ends_with(".json"):
			var arr := _load_json_array(events_dir + fname)
			for ev in arr:
				if ev is Dictionary:
					out.append(ev)
		fname = d.get_next()
	d.list_dir_end()
	return out


# ══════════════════════════════════════════════════════════════════════════════
# DEPURACIÓN
# ══════════════════════════════════════════════════════════════════════════════

func _dump_chapter_state() -> void:
	print()
	print("════════════════════════════════════════════════════════════════")
	var obj_desc: String = "(?)"
	if game_manager.current_objective != null:
		obj_desc = str(game_manager.current_objective.description)
	print("  CAPÍTULO CARGADO: %s" % obj_desc)
	print("════════════════════════════════════════════════════════════════")
	print("  Player units (%d):" % game_manager.player_units.size())
	for u in game_manager.player_units:
		var weapon_name := "(none)"
		if u.weapon != null and "name" in u.weapon:
			weapon_name = str(u.weapon.name)
		print("    %-12s %-15s lvl %2d  HP %2d  pos %s  weapon=%s" % [
			u.unit_name, u.unit_class, u.level, u.current_hp, u.grid_position, weapon_name,
		])
	print("  Enemy units (%d):" % game_manager.enemy_units.size())
	for u in game_manager.enemy_units:
		var ai := str(u.get_meta("ai_preset", "?"))
		print("    %-15s %-15s lvl %2d  HP %2d  pos %s  ai=%s" % [
			u.unit_name, u.unit_class, u.level, u.current_hp, u.grid_position, ai,
		])
	print("════════════════════════════════════════════════════════════════")
	print()


func _center_camera_on_lord() -> void:
	if game_manager.player_units.is_empty():
		return
	# Buscar el lord (tag "Lord") o usar el primero.
	var lord = null
	for u in game_manager.player_units:
		if "Lord" in u.tags:
			lord = u
			break
	if lord == null:
		lord = game_manager.player_units[0]
	# Asumimos que Grid expone grid_to_world.
	if camera and game_manager.grid:
		var g = game_manager.grid
		# Limitar la cámara al área del mapa para no mostrar el gris exterior.
		var cs: int = int(g.cell_size) if "cell_size" in g else 32
		camera.limit_left = 0
		camera.limit_top = 0
		camera.limit_right = g.grid_width * cs
		camera.limit_bottom = g.grid_height * cs
		camera.position = g.grid_to_world(lord.grid_position) + Vector2(0, CAMERA_Y_OFFSET_CELLS * cs)


## DEBUG: rejilla de map sprites en cada paleta de equipo (Player/Enemy/Ally/
## Other/Used) cerca del lord, para verificar el palette-swap. Son sólo visuales
## (no se registran en el grid ni en los turnos).
func _spawn_palette_debug() -> void:
	if not DEBUG_PALETTES:
		return
	var grid = game_manager.grid
	if grid == null:
		return
	var layer: Node = game_manager.unit_layer if game_manager.unit_layer != null else game_manager
	var classes := ["Cavalier", "Archer", "Armour"]
	var labels := ["Player", "Enemy", "Ally", "Other", "Used"]
	var origin := Vector2i(51, 8)

	# Etiquetas de columna.
	for col in labels.size():
		var lbl := Label.new()
		lbl.text = labels[col]
		lbl.add_theme_font_size_override("font_size", 24)
		lbl.add_theme_color_override("font_color", Color.WHITE)
		lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		lbl.add_theme_constant_override("outline_size", 5)
		lbl.position = grid.grid_to_world(Vector2i(origin.x + col, origin.y - 1)) - Vector2(34, 16)
		lbl.z_index = 100
		layer.add_child(lbl)

	# Rejilla clase × paleta.
	for ci in classes.size():
		for col in labels.size():
			var u := Unit.new()
			u.unit_class = classes[ci]
			u.unit_name = "DBG"
			u.is_player_unit = false   # no participa en turnos
			u.team = "player"
			var gpos := Vector2i(origin.x + col, origin.y + ci)
			u.grid_position = gpos
			layer.add_child(u)         # _ready -> setup_map_sprite
			u.global_position = grid.grid_to_world(gpos)
			if col < 4:
				u.set_team_palette(col)      # 0=Player 1=Enemy 2=Ally 3=Other
			else:
				u.set_team_palette(0)
				u.set_used_palette(true)     # Used (gris)
	if VERBOSE:
		print("[PrologueTest] DEBUG paletas: %d clases x %d paletas en origen %s" % [
			classes.size(), labels.size(), origin])
