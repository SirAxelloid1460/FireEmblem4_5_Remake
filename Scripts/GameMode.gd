# GameMode.gd
# Singleton que gestiona qué modo de juego está activo y la cronología
# de capítulos asociada.
#
# Configurar como autoload en project.godot:
#   GameMode="*res://Scripts/GameMode.gd"
#
# Tres modos disponibles:
#
#   1. FE4_ONLY   — Solo Genealogy of the Holy War.  12 caps en orden
#                   canónico (Prologue → Cap 5 Gen1 → Cap 6 Gen2 → ...
#                   → Final).
#
#   2. FE5_ONLY   — Solo Thracia 776.  ~25 caps en orden canónico.
#
#   3. SAGA_MODE  — La saga completa con FE5 y FE4 Gen2 entrelazados
#                   por ARCOS NARRATIVOS (bloques de 2-3 caps de cada
#                   campaña según cronología canon 775-776 dC).  Al
#                   completar el endgame de FE5, Leif y todo su escuadrón
#                   se unen automáticamente al ejército de Seliph para el
#                   asalto final de FE4 (canon estricto).

extends Node


enum Mode {
	FE4_ONLY,
	FE5_ONLY,
	SAGA_MODE,
}


## Modo activo.  Se setea desde el menú principal antes de cargar el
## primer capítulo de la partida.
var current_mode: Mode = Mode.FE4_ONLY

## Índice del capítulo actual dentro de la cronología del modo.
var current_chapter_index: int = 0

## Snapshot de las unidades de Leif al final de FE5, para transferirlas
## al ejército de Seliph en el endgame de FE4 (modo SAGA_MODE).
var leif_party_snapshot: Array = []

## Flag que indica si Leif ya se unió a Seliph (endgame FE4).
var leif_joined_seliph: bool = false


signal chapter_changed(new_chapter_id: String, new_index: int)
signal mode_changed(new_mode: Mode)
signal saga_armies_joined()


# ══════════════════════════════════════════════════════════════════════════════
# Cronologías por modo
# ══════════════════════════════════════════════════════════════════════════════
#
# Cada entrada es un Dictionary:
#   "id":     nid del cap (path se infiere desde el game)
#   "game":   "fe4" o "fe5"
#   "title":  título humano del cap
#   "gen":    1 o 2 (FE4) — todo FE5 es gen 1
#   "arc":    nombre del arco narrativo (solo SAGA)

const CHAPTERS_FE4: Array = [
	{ "id": "0",       "game": "fe4", "gen": 1, "title": "Prologue: Birth of a Holy Knight" },
	{ "id": "1",       "game": "fe4", "gen": 1, "title": "Chapter 1: Lady of the Forest" },
	{ "id": "2",       "game": "fe4", "gen": 1, "title": "Chapter 2: Crisis in Agustria" },
	{ "id": "3",       "game": "fe4", "gen": 1, "title": "Chapter 3: Eldigan, the Lionheart" },
	{ "id": "4",       "game": "fe4", "gen": 1, "title": "Chapter 4: Dance in the Skies" },
	{ "id": "5",       "game": "fe4", "gen": 1, "title": "Chapter 5: Doors of Destiny" },
	{ "id": "6",       "game": "fe4", "gen": 2, "title": "Chapter 6: Inheritors of Light" },
	{ "id": "7",       "game": "fe4", "gen": 2, "title": "Chapter 7: Beyond the Desert" },
	{ "id": "8",       "game": "fe4", "gen": 2, "title": "Chapter 8: The Eldest Daughter" },
	{ "id": "9",       "game": "fe4", "gen": 2, "title": "Chapter 9: For Whose Sake" },
	{ "id": "10",      "game": "fe4", "gen": 2, "title": "Chapter 10: Light and Dark" },
	{ "id": "endgame", "game": "fe4", "gen": 2, "title": "Final Chapter: End of the Holy War" },
]

const CHAPTERS_FE5: Array = [
	{ "id": "1",       "game": "fe5", "gen": 1, "title": "Chapter 1: The Warriors of Fiana" },
	{ "id": "2",       "game": "fe5", "gen": 1, "title": "Chapter 2: The Coastal Village of Ith" },
	{ "id": "2x",      "game": "fe5", "gen": 1, "title": "Chapter 2x: Diamonds in the Rough" },
	{ "id": "3",       "game": "fe5", "gen": 1, "title": "Chapter 3: Kelves' Pirates" },
	{ "id": "4",       "game": "fe5", "gen": 1, "title": "Chapter 4: The Dagdar Mountains" },
	{ "id": "4x",      "game": "fe5", "gen": 1, "title": "Chapter 4x: A Strange Bird" },
	{ "id": "5",       "game": "fe5", "gen": 1, "title": "Chapter 5: The Scion of Light" },
	{ "id": "6",       "game": "fe5", "gen": 1, "title": "Chapter 6: The Escape" },
	{ "id": "7",       "game": "fe5", "gen": 1, "title": "Chapter 7: Dandrum Fortress" },
	{ "id": "8",       "game": "fe5", "gen": 1, "title": "Chapter 8: Mt Violdrake" },
	{ "id": "8x",      "game": "fe5", "gen": 1, "title": "Chapter 8x: Mother and Daughter" },
	{ "id": "9",       "game": "fe5", "gen": 1, "title": "Chapter 9: The Emblem of Njorun" },
	{ "id": "10",      "game": "fe5", "gen": 1, "title": "Chapter 10: Noel Canyon" },
	{ "id": "11",      "game": "fe5", "gen": 1, "title": "Chapter 11: Dagdar's Hideout" },
	{ "id": "11x",     "game": "fe5", "gen": 1, "title": "Chapter 11x: The Thieves of Dakia" },
	{ "id": "12",      "game": "fe5", "gen": 1, "title": "Chapter 12: The Thieves of Dakia" },
	{ "id": "12x",     "game": "fe5", "gen": 1, "title": "Chapter 12x: Dandelion's Den" },
	{ "id": "13",      "game": "fe5", "gen": 1, "title": "Chapter 13: A New Resistance" },
	{ "id": "14",      "game": "fe5", "gen": 1, "title": "Chapter 14: Open Fire" },
	{ "id": "14x",     "game": "fe5", "gen": 1, "title": "Chapter 14x: A Reunion" },
	{ "id": "15",      "game": "fe5", "gen": 1, "title": "Chapter 15: The Two Paths" },
	{ "id": "16A",     "game": "fe5", "gen": 1, "title": "Chapter 16A: The Gate of Kelves" },
	{ "id": "17A",     "game": "fe5", "gen": 1, "title": "Chapter 17A: First Encounter" },
	{ "id": "18",      "game": "fe5", "gen": 1, "title": "Chapter 18: The Dark Forest" },
	{ "id": "19",      "game": "fe5", "gen": 1, "title": "Chapter 19: The Bridge of Rishel" },
	{ "id": "20",      "game": "fe5", "gen": 1, "title": "Chapter 20: The Liberation of Leonster" },
	{ "id": "21",      "game": "fe5", "gen": 1, "title": "Chapter 21: The Liberation War" },
	{ "id": "21x",     "game": "fe5", "gen": 1, "title": "Chapter 21x: The Detention Center" },
	{ "id": "22",      "game": "fe5", "gen": 1, "title": "Chapter 22: Across the River" },
	{ "id": "23",      "game": "fe5", "gen": 1, "title": "Chapter 23: The Palace of Evil" },
	{ "id": "24",      "game": "fe5", "gen": 1, "title": "Chapter 24: The Baron in Black" },
	{ "id": "endgame", "game": "fe5", "gen": 1, "title": "Endgame: An Undying Oath" },
]


## Cronología SAGA — bloques por ARCO NARRATIVO según cronología canon
## (años 775-776 dC).  Cada bloque es una unidad coherente de 2-3 caps
## que avanza una "fase" de cada campaña en paralelo.
##
## Estructura general:
##   ARCO 0:  Gen 1 FE4 (intacto, 757-761 — Sigurd hasta Belhalla)
##   ARCO 1+: Gen 2 + FE5 entrelazados (776 — paralelo)
##   ARCO 7:  Endgame FE4 (Leif se une a Seliph para el asalto final)
const CHAPTERS_SAGA: Array = [
	# ARCO 0: Gen 1 — La Caída del Ejército Sagrado (757-761)
	{ "id": "0", "game": "fe4", "gen": 1, "arc": "Gen 1: The Holy Knight",       "title": "Prologue: Birth of a Holy Knight" },
	{ "id": "1", "game": "fe4", "gen": 1, "arc": "Gen 1: The Holy Knight",       "title": "Chapter 1: Lady of the Forest" },
	{ "id": "2", "game": "fe4", "gen": 1, "arc": "Gen 1: The Holy Knight",       "title": "Chapter 2: Crisis in Agustria" },
	{ "id": "3", "game": "fe4", "gen": 1, "arc": "Gen 1: The Holy Knight",       "title": "Chapter 3: Eldigan, the Lionheart" },
	{ "id": "4", "game": "fe4", "gen": 1, "arc": "Gen 1: The Holy Knight",       "title": "Chapter 4: Dance in the Skies" },
	{ "id": "5", "game": "fe4", "gen": 1, "arc": "Gen 1: The Holy Knight",       "title": "Chapter 5: Doors of Destiny" },

	# ARCO 1: Awakening — Seliph desde Isaach, Leif desde Fiana
	{ "id": "6",       "game": "fe4", "gen": 2, "arc": "Awakening",              "title": "Chapter 6: Inheritors of Light" },
	{ "id": "1",       "game": "fe5", "gen": 1, "arc": "Awakening",              "title": "Thracia 1: The Warriors of Fiana" },
	{ "id": "2",       "game": "fe5", "gen": 1, "arc": "Awakening",              "title": "Thracia 2: The Coastal Village of Ith" },
	{ "id": "2x",      "game": "fe5", "gen": 1, "arc": "Awakening",              "title": "Thracia 2x: Diamonds in the Rough" },
	{ "id": "3",       "game": "fe5", "gen": 1, "arc": "Awakening",              "title": "Thracia 3: Kelves' Pirates" },

	# ARCO 2: Wildlands — Seliph cruza Yied, Leif busca refugio
	{ "id": "7",       "game": "fe4", "gen": 2, "arc": "Wildlands",              "title": "Chapter 7: Beyond the Desert" },
	{ "id": "4",       "game": "fe5", "gen": 1, "arc": "Wildlands",              "title": "Thracia 4: The Dagdar Mountains" },
	{ "id": "4x",      "game": "fe5", "gen": 1, "arc": "Wildlands",              "title": "Thracia 4x: A Strange Bird" },
	{ "id": "5",       "game": "fe5", "gen": 1, "arc": "Wildlands",              "title": "Thracia 5: The Scion of Light" },

	# ARCO 3: The Captive Daughters — Lachesis y Tinny en Friege; Leif hacia Manster
	{ "id": "8",       "game": "fe4", "gen": 2, "arc": "The Captive Daughters",  "title": "Chapter 8: The Eldest Daughter" },
	{ "id": "6",       "game": "fe5", "gen": 1, "arc": "The Captive Daughters",  "title": "Thracia 6: The Escape" },
	{ "id": "7",       "game": "fe5", "gen": 1, "arc": "The Captive Daughters",  "title": "Thracia 7: Dandrum Fortress" },
	{ "id": "8",       "game": "fe5", "gen": 1, "arc": "The Captive Daughters",  "title": "Thracia 8: Mt Violdrake" },
	{ "id": "8x",      "game": "fe5", "gen": 1, "arc": "The Captive Daughters",  "title": "Thracia 8x: Mother and Daughter" },

	# ARCO 4: The Tide Turns — los dos ejércitos cruzan Thracia
	{ "id": "9",       "game": "fe4", "gen": 2, "arc": "The Tide Turns",         "title": "Chapter 9: For Whose Sake" },
	{ "id": "9",       "game": "fe5", "gen": 1, "arc": "The Tide Turns",         "title": "Thracia 9: The Emblem of Njorun" },
	{ "id": "10",      "game": "fe5", "gen": 1, "arc": "The Tide Turns",         "title": "Thracia 10: Noel Canyon" },
	{ "id": "11",      "game": "fe5", "gen": 1, "arc": "The Tide Turns",         "title": "Thracia 11: Dagdar's Hideout" },
	{ "id": "11x",     "game": "fe5", "gen": 1, "arc": "The Tide Turns",         "title": "Thracia 11x: The Thieves of Dakia" },

	# ARCO 5: Approach — Seliph hacia Julius, Leif libera el este
	{ "id": "10",      "game": "fe4", "gen": 2, "arc": "Approach",               "title": "Chapter 10: Light and Dark" },
	{ "id": "12",      "game": "fe5", "gen": 1, "arc": "Approach",               "title": "Thracia 12: The Thieves of Dakia" },
	{ "id": "12x",     "game": "fe5", "gen": 1, "arc": "Approach",               "title": "Thracia 12x: Dandelion's Den" },
	{ "id": "13",      "game": "fe5", "gen": 1, "arc": "Approach",               "title": "Thracia 13: A New Resistance" },
	{ "id": "14",      "game": "fe5", "gen": 1, "arc": "Approach",               "title": "Thracia 14: Open Fire" },
	{ "id": "14x",     "game": "fe5", "gen": 1, "arc": "Approach",               "title": "Thracia 14x: A Reunion" },

	# ARCO 6: Liberation of Thracia — Leif termina Thracia ANTES del endgame FE4
	{ "id": "15",      "game": "fe5", "gen": 1, "arc": "Liberation of Thracia",  "title": "Thracia 15: The Two Paths" },
	{ "id": "16A",     "game": "fe5", "gen": 1, "arc": "Liberation of Thracia",  "title": "Thracia 16A: The Gate of Kelves" },
	{ "id": "17A",     "game": "fe5", "gen": 1, "arc": "Liberation of Thracia",  "title": "Thracia 17A: First Encounter" },
	{ "id": "18",      "game": "fe5", "gen": 1, "arc": "Liberation of Thracia",  "title": "Thracia 18: The Dark Forest" },
	{ "id": "19",      "game": "fe5", "gen": 1, "arc": "Liberation of Thracia",  "title": "Thracia 19: The Bridge of Rishel" },
	{ "id": "20",      "game": "fe5", "gen": 1, "arc": "Liberation of Thracia",  "title": "Thracia 20: The Liberation of Leonster" },
	{ "id": "21",      "game": "fe5", "gen": 1, "arc": "Liberation of Thracia",  "title": "Thracia 21: The Liberation War" },
	{ "id": "21x",     "game": "fe5", "gen": 1, "arc": "Liberation of Thracia",  "title": "Thracia 21x: The Detention Center" },
	{ "id": "22",      "game": "fe5", "gen": 1, "arc": "Liberation of Thracia",  "title": "Thracia 22: Across the River" },
	{ "id": "23",      "game": "fe5", "gen": 1, "arc": "Liberation of Thracia",  "title": "Thracia 23: The Palace of Evil" },
	{ "id": "24",      "game": "fe5", "gen": 1, "arc": "Liberation of Thracia",  "title": "Thracia 24: The Baron in Black" },
	{ "id": "endgame", "game": "fe5", "gen": 1, "arc": "Liberation of Thracia",  "title": "Thracia Endgame: An Undying Oath" },

	# ARCO 7: The Holy War — UNIÓN FINAL.  Leif y supervivientes se unen
	# a Seliph para el asalto a Belhalla.  leif_party_snapshot se inyecta
	# como aliados extra en este cap.
	{ "id": "endgame", "game": "fe4", "gen": 2, "arc": "The Holy War",           "title": "Final Chapter: End of the Holy War" },
]


# ══════════════════════════════════════════════════════════════════════════════
# API PRINCIPAL
# ══════════════════════════════════════════════════════════════════════════════

func start_game(mode: Mode) -> void:
	current_mode = mode
	current_chapter_index = 0
	leif_party_snapshot.clear()
	leif_joined_seliph = false
	mode_changed.emit(mode)
	_sync_asset_loader_with_current_chapter()


func get_chronology() -> Array:
	match current_mode:
		Mode.FE4_ONLY:  return CHAPTERS_FE4
		Mode.FE5_ONLY:  return CHAPTERS_FE5
		Mode.SAGA_MODE: return CHAPTERS_SAGA
	return []


func get_current_chapter_entry() -> Dictionary:
	var chrono := get_chronology()
	if current_chapter_index < 0 or current_chapter_index >= chrono.size():
		return {}
	return chrono[current_chapter_index]


## Avanza al siguiente capítulo.  En modo SAGA, detecta cuando acabamos
## el endgame FE5 y marca la unión de ejércitos para el endgame FE4.
##
## Devuelve true si hay siguiente cap, false si la partida ha terminado.
func advance_to_next_chapter() -> bool:
	var current := get_current_chapter_entry()
	var was_fe5_endgame: bool = (
		current_mode == Mode.SAGA_MODE
		and not leif_joined_seliph
		and str(current.get("game", "")) == "fe5"
		and str(current.get("id", "")) == "endgame"
	)

	current_chapter_index += 1
	var chrono := get_chronology()
	if current_chapter_index >= chrono.size():
		return false

	if was_fe5_endgame:
		leif_joined_seliph = true
		saga_armies_joined.emit()
		print("[SagaMode] Leif y su ejército se unen a Seliph (%d unidades)"
				% leif_party_snapshot.size())

	_sync_asset_loader_with_current_chapter()
	var entry := get_current_chapter_entry()
	chapter_changed.emit(str(entry.get("id", "")), current_chapter_index)
	return true


func jump_to_chapter(index: int) -> bool:
	var chrono := get_chronology()
	if index < 0 or index >= chrono.size():
		return false
	current_chapter_index = index
	_sync_asset_loader_with_current_chapter()
	var entry := get_current_chapter_entry()
	chapter_changed.emit(str(entry.get("id", "")), index)
	return true


func is_final_chapter() -> bool:
	return current_chapter_index >= get_chronology().size() - 1


func get_data_root() -> String:
	var entry := get_current_chapter_entry()
	var game = entry.get("game", "fe4")
	return "res://data/%s/" % game


func get_chapter_json_path() -> String:
	var entry := get_current_chapter_entry()
	if entry.is_empty():
		return ""
	return "%slevels/%s.json" % [get_data_root(), entry.get("id")]


func get_mode_name() -> String:
	match current_mode:
		Mode.FE4_ONLY:  return "Genealogy of the Holy War"
		Mode.FE5_ONLY:  return "Thracia 776"
		Mode.SAGA_MODE: return "Saga Mode"
	return "Unknown"


# ══════════════════════════════════════════════════════════════════════════════
# UNIÓN FINAL (SAGA_MODE)
# ══════════════════════════════════════════════════════════════════════════════

## El GameManager debe llamar a esta función al COMPLETAR el endgame FE5
## en modo SAGA, ANTES de cambiar de cap.  Captura el estado de las
## unidades supervivientes de Leif para que se reincorporen al ejército
## de Seliph en el cap final de FE4.
##
##   units: Array[Unit] de las unidades del jugador supervivientes.
func capture_leif_party(units: Array) -> void:
	if current_mode != Mode.SAGA_MODE:
		return
	leif_party_snapshot.clear()
	for unit in units:
		if unit == null:
			continue
		var snap := {
			"nid": unit.unit_name,
			"unit_class": unit.unit_class,
			"level": unit.level,
			"max_hp": unit.max_hp,
			"current_hp": unit.current_hp,
			"strength": unit.strength,
			"magic": unit.magic,
			"skill": unit.skill,
			"speed": unit.speed,
			"luck": unit.luck,
			"defense": unit.defense,
			"resistance": unit.resistance,
			"constitution": unit.constitution,
			"movement": unit.movement,
			"tags": unit.tags.duplicate() if unit.tags is Array else [],
			"weapon_exp": unit.weapon_exp.duplicate() if unit.weapon_exp is Dictionary else {},
			"holy_blood": unit.holy_blood.duplicate() if unit.holy_blood is Dictionary else {},
			"inventory": _serialize_inventory(unit),
		}
		leif_party_snapshot.append(snap)
	print("[SagaMode] Capturado party de Leif: %d unidades" % leif_party_snapshot.size())


## Devuelve las unidades de Leif listas para spawn en el endgame FE4.
##   Si leif_joined_seliph es false, devuelve [] (la unión aún no ocurrió
##   o el modo no es SAGA).
func get_leif_reinforcements() -> Array:
	return leif_party_snapshot if leif_joined_seliph else []


# ══════════════════════════════════════════════════════════════════════════════
# HELPERS
# ══════════════════════════════════════════════════════════════════════════════

## Sincroniza AssetLoader con el game del cap actual.
func _sync_asset_loader_with_current_chapter() -> void:
	if not has_node("/root/AssetLoader"):
		return
	var entry := get_current_chapter_entry()
	if entry.has("game"):
		var loader = get_node("/root/AssetLoader")
		loader.set_active_game(entry["game"])


## Serializa el inventario de una unidad.
func _serialize_inventory(unit) -> Array:
	var out: Array = []
	if not ("inventory" in unit) or not (unit.inventory is Array):
		return out
	for item in unit.inventory:
		if item == null:
			continue
		var data := {}
		for attr in ["id", "weapon_name", "item_name", "name",
				"weapon_type", "item_type", "uses", "max_uses",
				"current_durability", "max_durability"]:
			if attr in item:
				data[attr] = item.get(attr)
		out.append(data)
	return out


# ══════════════════════════════════════════════════════════════════════════════
# UTILIDADES PARA UI
# ══════════════════════════════════════════════════════════════════════════════

## En modo SAGA, devuelve el nombre del arco narrativo del cap actual.
func get_current_arc_name() -> String:
	var entry := get_current_chapter_entry()
	return str(entry.get("arc", ""))


## Lista de arcos del modo SAGA con índices [start, end] de cada uno.
##   Útil para construir un "chapter select" agrupado por arco.
func get_saga_arcs() -> Array:
	if current_mode != Mode.SAGA_MODE:
		return []
	var arcs: Array = []
	var current_arc := ""
	var arc_start := 0
	for i in range(CHAPTERS_SAGA.size()):
		var arc := str(CHAPTERS_SAGA[i].get("arc", ""))
		if arc != current_arc:
			if current_arc != "":
				arcs.append({ "name": current_arc, "start": arc_start, "end": i - 1 })
			current_arc = arc
			arc_start = i
	if current_arc != "":
		arcs.append({ "name": current_arc, "start": arc_start, "end": CHAPTERS_SAGA.size() - 1 })
	return arcs
