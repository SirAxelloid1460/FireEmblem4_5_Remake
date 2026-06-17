# ChapterObjective.gd
# Sistema de objetivos de capítulo: condiciones de victoria y derrota.
#
# TIPOS CANÓNICOS:
#   • Seize       — capturar una posición específica (típicamente trono).
#                   Win: una unidad del jugador (o una específica) está en pos X.
#   • Rout        — eliminar todas las unidades enemigas.
#   • Escape      — una unidad concreta llega a una posición/región.
#                   En FE5 común con Leif.  Si "escape_all", todas las unidades
#                   deben llegar.  Las que no lleguen pueden contar como muertas.
#   • Survive     — aguantar N turnos sin perder al lord.
#   • DefeatBoss  — matar al boss específico (unidad con meta is_boss).
#
# DERROTAS:
#   • LordDies    — el lord muere.  El nid del lord viene del party.
#   • TimeOut     — superar N turnos sin completar el objetivo (en algunos caps).
#   • LordEscapes — solo en algunos caps de Escape, si el lord escapa solo.
#
# El objetivo se construye desde el campo `objective` del capítulo LT:
#   { "win": "Seize Evans", "loss": "Lord dies", "simple": "Seize Evans" }
# Como `win` y `loss` son texto libre, parseamos heurísticamente las palabras
# clave.  El caller puede sobrescribir manualmente vía configure().

class_name ChapterObjective
extends RefCounted

# Tipos de victoria.
enum WinType {
	NONE,
	SEIZE,
	ROUT,
	ESCAPE,
	SURVIVE,
	DEFEAT_BOSS,
}

# Tipos de derrota.
enum LossType {
	NONE,
	LORD_DIES,
	TIME_OUT,
	ALLY_DIES,
}

# ── Configuración del objetivo ────────────────────────────────────────────────

var win_type: WinType = WinType.ROUT
var loss_type: LossType = LossType.LORD_DIES

var seize_position: Vector2i = Vector2i(-1, -1)   # tile a capturar
var escape_position: Vector2i = Vector2i(-1, -1)  # tile de escape (Escape maps)
var survive_turns: int = 0                        # turnos a aguantar
var boss_nid: String = ""                         # boss a matar
var lord_nid: String = ""                         # lord cuya muerte es game-over
var ally_protect_nid: String = ""                 # NPC a proteger (Hannibal, etc.)

var description: String = ""

# Estado.
var is_completed: bool = false
var is_failed: bool = false


# ══════════════════════════════════════════════════════════════════════════════
# CONSTRUCCIÓN DESDE EL CAPÍTULO LT
# ══════════════════════════════════════════════════════════════════════════════

## Crea un ChapterObjective parseando los strings de objective del JSON LT.
##   chapter_objective : el campo "objective" del JSON {win, loss, simple}
##   regions           : lista de regions del cap (para resolver "Seize <Region>")
##   lord_nid          : nid de la unidad lord del cap (para LordDies).
static func from_chapter(chapter_objective: Dictionary, regions: Array,
		lord_nid_str: String = "") -> ChapterObjective:
	var obj := ChapterObjective.new()
	obj.lord_nid = lord_nid_str
	var win_text  := str(chapter_objective.get("win", "")).strip_edges()
	var loss_text := str(chapter_objective.get("loss", "")).strip_edges()
	obj.description = str(chapter_objective.get("simple", win_text))

	# Parser de WIN.
	var win_lower := win_text.to_lower()
	if win_lower.begins_with("seize"):
		obj.win_type = WinType.SEIZE
		# Extraer el nombre tras "seize " — es el nid de una región.
		var region_name := win_text.substr(5).strip_edges()
		obj.seize_position = _find_region_position(regions, region_name)
	elif win_lower.begins_with("rout"):
		obj.win_type = WinType.ROUT
	elif win_lower.begins_with("escape"):
		obj.win_type = WinType.ESCAPE
		var region_name := win_text.substr(6).strip_edges()
		obj.escape_position = _find_region_position(regions, region_name)
	elif win_lower.begins_with("survive"):
		obj.win_type = WinType.SURVIVE
		# Extraer el número de turnos del texto.
		var n := _extract_int(win_text)
		obj.survive_turns = n if n > 0 else 10
	elif win_lower.begins_with("defeat") or win_lower.begins_with("kill"):
		obj.win_type = WinType.DEFEAT_BOSS
		# El nid del boss debe inyectarse aparte (vía set_boss).

	# Parser de LOSS.
	var loss_lower := loss_text.to_lower()
	if "lord" in loss_lower or "dies" in loss_lower:
		obj.loss_type = LossType.LORD_DIES
	elif "turn" in loss_lower:
		obj.loss_type = LossType.TIME_OUT

	return obj


## Búsqueda de una región por nid (case-insensitive).  Devuelve el centro
## del rect; (-1,-1) si no se encuentra.
static func _find_region_position(regions: Array, nid: String) -> Vector2i:
	if nid == "":
		return Vector2i(-1, -1)
	var nid_low := nid.to_lower()
	for r in regions:
		if r is Dictionary and str(r.get("nid", "")).to_lower() == nid_low:
			var pos = r.get("position", Vector2i.ZERO)
			if pos is Vector2i:
				return pos
			if pos is Array and pos.size() >= 2:
				return Vector2i(int(pos[0]), int(pos[1]))
	return Vector2i(-1, -1)


## Extrae el primer entero positivo de un string ("Survive 10 turns" → 10).
static func _extract_int(s: String) -> int:
	var current := ""
	for c in s:
		if c >= "0" and c <= "9":
			current += c
		elif current != "":
			break
	if current == "":
		return 0
	return int(current)


# ══════════════════════════════════════════════════════════════════════════════
# CONFIGURACIÓN MANUAL (override)
# ══════════════════════════════════════════════════════════════════════════════

func set_seize(pos: Vector2i) -> void:
	win_type = WinType.SEIZE
	seize_position = pos

func set_rout() -> void:
	win_type = WinType.ROUT

func set_escape(pos: Vector2i) -> void:
	win_type = WinType.ESCAPE
	escape_position = pos

func set_survive(turns: int) -> void:
	win_type = WinType.SURVIVE
	survive_turns = turns

func set_boss(nid: String) -> void:
	win_type = WinType.DEFEAT_BOSS
	boss_nid = nid


# ══════════════════════════════════════════════════════════════════════════════
# EVALUACIÓN
# ══════════════════════════════════════════════════════════════════════════════

## ¿El jugador ha completado el objetivo?  Llamar al final de cada turno.
##   player_units : lista de unidades vivas del jugador
##   enemy_units  : lista de unidades vivas enemigas
##   current_turn : turno actual del juego
func check_victory(player_units: Array, enemy_units: Array, current_turn: int) -> bool:
	if is_completed:
		return true
	match win_type:
		WinType.SEIZE:
			# Una unidad del jugador está en seize_position.
			for u in player_units:
				if u != null and u.current_hp > 0 and u.grid_position == seize_position:
					is_completed = true
					return true
		WinType.ROUT:
			# Quitamos enemigos no combatientes (ballistas neutralizadas, etc.)
			var combatants := enemy_units.filter(func(u): return u != null and u.current_hp > 0 \
					and not BallistaSystem.is_ballista(u))
			if combatants.is_empty():
				is_completed = true
				return true
		WinType.ESCAPE:
			# Si hay un nid específico (por defecto el lord), basta con que
			# llegue a la posición.  Si no, todos los aliados deben llegar.
			# Implementación simple: el lord en escape_position.
			for u in player_units:
				if u != null and u.unit_name == lord_nid \
						and u.current_hp > 0 and u.grid_position == escape_position:
					is_completed = true
					return true
		WinType.SURVIVE:
			if current_turn >= survive_turns:
				is_completed = true
				return true
		WinType.DEFEAT_BOSS:
			# El boss ya no está vivo en enemy_units si fue eliminado.
			var alive := false
			for u in enemy_units:
				if u != null and u.current_hp > 0 and u.unit_name == boss_nid:
					alive = true
					break
			if not alive:
				is_completed = true
				return true
	return false


## ¿El jugador ha perdido?
func check_defeat(player_units: Array, current_turn: int, max_turns: int = -1) -> bool:
	if is_failed:
		return true
	match loss_type:
		LossType.LORD_DIES:
			if lord_nid == "":
				return false
			var lord_alive := false
			for u in player_units:
				if u != null and u.unit_name == lord_nid and u.current_hp > 0:
					lord_alive = true
					break
			if not lord_alive:
				is_failed = true
				return true
		LossType.TIME_OUT:
			if max_turns > 0 and current_turn > max_turns:
				is_failed = true
				return true
		LossType.ALLY_DIES:
			if ally_protect_nid == "":
				return false
			var ally_alive := false
			for u in player_units:
				if u != null and u.unit_name == ally_protect_nid and u.current_hp > 0:
					ally_alive = true
					break
			if not ally_alive:
				is_failed = true
				return true
	# Caso general: si no quedan unidades del jugador, derrota automática.
	if player_units.is_empty():
		is_failed = true
		return true
	return false


## Texto descriptivo para mostrar en HUD.
func get_summary() -> String:
	if description != "":
		return description
	match win_type:
		WinType.SEIZE:        return "Seize tile %s" % seize_position
		WinType.ROUT:         return "Rout all enemies"
		WinType.ESCAPE:       return "Escape with lord to %s" % escape_position
		WinType.SURVIVE:      return "Survive %d turns" % survive_turns
		WinType.DEFEAT_BOSS:  return "Defeat %s" % boss_nid
	return ""
