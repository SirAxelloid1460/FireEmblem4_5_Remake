# EventSystem.gd
# Sistema de eventos del juego portado del scripting de LT-maker.
#
# UN EVENTO LT:
#   {
#     "name": "NorthVillage",
#     "trigger": "Visit" | "level_start" | "turn_change" | "unit_death" | ...
#     "level_nid": "1",
#     "condition": "region.nid == 'NorthVillage'",
#     "commands": [
#       ["speak", ["NPC", "Hello traveler", ...]],
#       ["give_item", ["{unit}", "Vulnerary"]],
#       ["set_flag", ["village_visited"]],
#       ...
#     ],
#   }
#
# TRIGGERS SOPORTADOS (subset relevante para gameplay):
#   level_start    : al cargar el capítulo
#   level_end      : al ganar
#   turn_change    : cada inicio de turno
#   region_visit   : una unidad pisa una región (sub_nid = "Visit")
#   region_enter   : una unidad entra en una región (event-type, condition)
#   unit_death     : una unidad concreta muere
#   combat_start   : antes de un combate
#   combat_end     : tras un combate
#
# COMANDOS SOPORTADOS (subset esencial):
#   speak              : delega a DialogueBox
#   give_item          : da un item a una unidad
#   level_var / set_flag : guarda variables persistentes del capítulo
#   spawn_unit         : aparece una unidad nueva (refuerzo)
#   change_team        : cambia el bando de una unidad
#   give_gold          : suma oro al ejército
#   victory / defeat   : fuerza fin de capítulo
#   wait               : pausa (para diálogos)
#
# COMANDOS NO IMPLEMENTADOS (delegados o ignorados):
#   change_tilemap, multi_add_portrait, music_*, transition, etc. — son
#   efectos visuales que se ignoran en runtime y se loggean para que
#   el sistema de cinemáticas (ya implementado en CinematicScene.gd) los
#   procese si están conectados.
#
# CONEXIÓN:
#   • LevelLoader carga events en EventSystem.load_chapter_events().
#   • GameManager invoca trigger_event() en los puntos relevantes
#     (start_player_turn, _handle_unit_death, region pisada, etc.).

class_name EventSystem
extends Node


# ── Estado ────────────────────────────────────────────────────────────────────

# Eventos cargados, indexados por trigger.
#   { trigger_name → Array de event Dictionaries }
var events_by_trigger: Dictionary = {}
# Eventos indexados por nombre (para trigger_script).
var events_by_name: Dictionary = {}
# Anti-recursión de trigger_script.
var _script_depth: int = 0

# Eventos disparados (only_once, set_flag, etc.).
var fired_events: Array = []

# Variables del nivel (level_var / set_flag).
var level_vars: Dictionary = {}

# Referencias al juego para ejecutar comandos.
var game_manager: Node = null
var dialogue_box: Node = null

# Convoy para give_item con inventario lleno.
var convoy: Node = null

# ── Presentación (comandos speak/music/transition/change_background) ──────────
# Se crean bajo demanda en un CanvasLayer propio (screen-space), sin depender de
# ninguna .tscn (patrón fiable del proyecto). Ver EventDialogue.gd.
var _pres_layer: CanvasLayer = null
var _dialogue: EventDialogue = null
var _bg_rect: TextureRect = null
var _fade_rect: ColorRect = null
var _music_player: AudioStreamPlayer = null
# Profundidad de ejecución de eventos: >0 mientras corre un evento (bloquea el
# input de gameplay para no mover unidades durante una cinemática/diálogo).
var _busy_depth: int = 0


## True mientras se ejecuta algún evento (lo consulta GameManager._input).
func is_busy() -> bool:
	return _busy_depth > 0


# ── Señales ──────────────────────────────────────────────────────────────────

signal event_started(event_name: String)
signal event_finished(event_name: String)
signal force_victory()
signal force_defeat()


# ══════════════════════════════════════════════════════════════════════════════
# CARGA DE EVENTOS
# ══════════════════════════════════════════════════════════════════════════════

## Carga los eventos de un capítulo.  events_data es la lista directa del
## directorio /events/ filtrada por level_nid del capítulo actual.
func load_chapter_events(events_data: Array, level_nid: String) -> void:
	events_by_trigger.clear()
	events_by_name.clear()
	fired_events.clear()
	level_vars.clear()
	for ev in events_data:
		if not (ev is Dictionary):
			continue
		# Filtrar por level_nid — los eventos globales tienen level_nid=null o "global".
		var raw_level = ev.get("level_nid", "")
		var ev_level := str(raw_level) if raw_level != null else ""
		if ev_level != "" and ev_level != level_nid and ev_level != "global":
			continue
		# Indexar por nombre (para trigger_script), incluso sin trigger de disparo.
		var ev_name := str(ev.get("name", ""))
		if ev_name != "":
			events_by_name[ev_name] = ev
		var trigger := str(ev.get("trigger", ""))
		if trigger == "":
			continue
		if not events_by_trigger.has(trigger):
			events_by_trigger[trigger] = []
		events_by_trigger[trigger].append(ev)


## Configura las dependencias del sistema (caller las inyecta tras crear).
func configure(p_game_manager: Node, p_dialogue: Node = null, p_convoy: Node = null) -> void:
	game_manager = p_game_manager
	dialogue_box = p_dialogue
	convoy = p_convoy


# ══════════════════════════════════════════════════════════════════════════════
# DISPARO DE EVENTOS
# ══════════════════════════════════════════════════════════════════════════════

## Dispara todos los eventos asociados a un trigger.  context es un
## Dictionary con datos del momento (unit, region, etc.).
##   Devuelve la lista de event names disparados (para reinforcements y
##   demás triggers en cadena).
func trigger_event(trigger_name: String, context: Dictionary = {}) -> Array:
	var fired_now: Array = []
	if not events_by_trigger.has(trigger_name):
		return fired_now
	_busy_depth += 1
	for ev in events_by_trigger[trigger_name]:
		var ev_name := str(ev.get("name", ""))
		# only_once: si ya se disparó, saltar.
		if ev_name in fired_events and bool(ev.get("only_once", false)):
			continue
		# Evaluar condition (heurística mínima — no soportamos expresiones
		# Python completas; verificamos cosas básicas).
		if not _evaluate_condition(str(ev.get("condition", "True")), context):
			continue
		# Ejecutar.
		event_started.emit(ev_name)
		await _execute_commands(ev.get("commands", []), context)
		fired_events.append(ev_name)
		fired_now.append(ev_name)
		event_finished.emit(ev_name)
	# Fin del lote de este trigger: limpiar la presentación para no dejar la
	# pantalla tapada (diálogo, fondo o fundido a negro colgados).
	if _dialogue != null and is_instance_valid(_dialogue):
		_dialogue.finish()
	if _bg_rect != null and is_instance_valid(_bg_rect):
		_bg_rect.visible = false
	if _fade_rect != null and is_instance_valid(_fade_rect):
		_fade_rect.color.a = 0.0
	_busy_depth -= 1
	return fired_now


## Evaluador de condiciones LT.  Soporta los patrones más comunes en los
## eventos canónicos de GotHW/Thracia776:
##
##   "True"  / "False"
##   "region.nid == 'X'"           — comparación de región actual
##   "unit.team == 'player'"       — bando de la unidad activa
##   "unit.nid == 'Sigurd'"        — nid de la unidad activa
##   "unit.klass == 'Lord'"        — clase de la unidad
##   "game.turncount == N"         — turno actual (alias: game.turn, turn)
##   "game.turncount >= N"         — comparaciones >= y <=
##   "game.level_vars.get('flag') == 1" / "...flag') == True"
##   "game.level_vars.get('flag')" — truthy check
##   "not <expr>"                  — negación
##   "<expr> and <expr>"           — AND lógico (sin paréntesis)
##
## Las condiciones más complejas (paréntesis, OR, llamadas a métodos) caen
## en el fallback permisivo (return true) — el caller debe poner ese tipo
## de lógica en commands del propio evento.
func _evaluate_condition(cond: String, context: Dictionary) -> bool:
	cond = cond.strip_edges()
	if cond == "" or cond == "True":
		return true
	if cond == "False":
		return false
	# Soporte de "and" — evaluación cortocircuito.
	if " and " in cond:
		var parts := cond.split(" and ")
		for p in parts:
			if not _evaluate_condition(str(p).strip_edges(), context):
				return false
		return true
	# Soporte de "not".
	if cond.begins_with("not "):
		return not _evaluate_condition(cond.substr(4).strip_edges(), context)
	# region.nid == '<nid>'
	if cond.begins_with("region.nid =="):
		var expected := cond.substr(13).strip_edges().trim_prefix("'").trim_suffix("'")
		var region: Dictionary = context.get("region", {})
		return str(region.get("nid", "")) == expected
	# unit.team == '<team>'
	if cond.begins_with("unit.team =="):
		var expected := cond.substr(12).strip_edges().trim_prefix("'").trim_suffix("'")
		var unit = context.get("unit")
		if unit == null:
			return false
		var team := "player" if unit.is_player_unit else "enemy"
		return team == expected
	# unit.nid == '<nid>'
	if cond.begins_with("unit.nid =="):
		var expected := cond.substr(11).strip_edges().trim_prefix("'").trim_suffix("'")
		var unit = context.get("unit")
		if unit == null:
			return false
		return unit.unit_name == expected
	# unit.klass == '<class>'
	if cond.begins_with("unit.klass =="):
		var expected := cond.substr(13).strip_edges().trim_prefix("'").trim_suffix("'")
		var unit = context.get("unit")
		if unit == null:
			return false
		return unit.unit_class == expected
	# game.turncount [op] N  (también: game.turn, turn)
	if cond.begins_with("game.turncount") or cond.begins_with("game.turn") \
			or cond.begins_with("turn ") or cond.begins_with("turn=="):
		# Buscar el operador y el operando.
		return _eval_turncount_compare(cond)
	# game.level_vars.get('X') == <value>
	if cond.begins_with("game.level_vars[") or cond.begins_with("game.game_vars["):
		var ob := cond.find("[")
		var cb := cond.find("]", ob)
		if ob < 0 or cb < 0:
			return true
		var vkey := cond.substr(ob + 1, cb - ob - 1).strip_edges() \
				.trim_prefix("'").trim_suffix("'").trim_prefix("\"").trim_suffix("\"")
		var vrest := cond.substr(cb + 1).strip_edges()
		var vactual = level_vars.get(vkey, null)
		if vrest == "":
			return vactual != null and bool(vactual)
		return _compare_var(vactual, vrest)
	if cond.begins_with("game.level_vars.get("):
		var open_paren := cond.find("(")
		var close_paren := cond.find(")", open_paren)
		if open_paren < 0 or close_paren < 0:
			return true
		var key := cond.substr(open_paren + 1, close_paren - open_paren - 1) \
				.strip_edges().trim_prefix("'").trim_suffix("'")
		var rest := cond.substr(close_paren + 1).strip_edges()
		var actual_val = level_vars.get(key, null)
		if rest == "":
			return actual_val != null and bool(actual_val)
		if rest.begins_with("=="):
			var expected_str := rest.substr(2).strip_edges()
			var clean := expected_str.trim_prefix("'").trim_suffix("'")
			if clean == "True":
				return bool(actual_val)
			if clean == "False":
				return not bool(actual_val)
			return str(actual_val) == clean
	# cf.SETTINGS['debug'] / cf.SETTINGS['<flag>']  → siempre false en runtime
	# (es una bandera del editor LT, no afecta al gameplay).
	if cond.begins_with("cf.SETTINGS"):
		return false
	# Fallback permisivo
	if OS.is_debug_build():
		print("[EventSystem] condición no parseada: %s" % cond)
	return true


## Compara game.turncount con un valor.  Soporta "==", ">=", "<=", ">", "<".
func _eval_turncount_compare(cond: String) -> bool:
	# Extraer el número objetivo y el operador del string.
	# Formato típico: "game.turncount == 2" / "game.turncount >= 5"
	var current_turn := 1
	if game_manager != null and "current_turn" in game_manager:
		current_turn = int(game_manager.current_turn)
	var rest := cond
	# Quitar el prefijo (game.turncount, game.turn, turn).
	for prefix in ["game.turncount", "game.turn", "turn"]:
		if rest.begins_with(prefix):
			rest = rest.substr(prefix.length()).strip_edges()
			break
	# Detectar el operador.
	var op := ""
	for candidate in ["==", ">=", "<=", "!=", ">", "<"]:
		if rest.begins_with(candidate):
			op = candidate
			rest = rest.substr(candidate.length()).strip_edges()
			break
	if op == "":
		return false
	var target := int(rest)
	match op:
		"==": return current_turn == target
		"!=": return current_turn != target
		">=": return current_turn >= target
		"<=": return current_turn <= target
		">":  return current_turn > target
		"<":  return current_turn < target
	return false


## Compara un valor de level_var contra el lado derecho de una condición
## (`== 3`, `!= True`, `>= 5`, `< 2`...). Numérico si ambos lados lo son;
## si no, comparación de strings (con True/False como bool).
func _compare_var(actual, rest: String) -> bool:
	var op := ""
	for candidate in ["==", ">=", "<=", "!=", ">", "<"]:
		if rest.begins_with(candidate):
			op = candidate
			rest = rest.substr(candidate.length()).strip_edges()
			break
	if op == "":
		return actual != null and bool(actual)
	var clean := rest.trim_prefix("'").trim_suffix("'").trim_prefix("\"").trim_suffix("\"")
	# Booleanos.
	if clean == "True":
		return bool(actual) if op == "==" else not bool(actual)
	if clean == "False":
		return (not bool(actual)) if op == "==" else bool(actual)
	# Numérico si el rhs es entero (los level_vars sin fijar valen 0).
	if clean.is_valid_int():
		var a := int(actual) if actual != null and str(actual).is_valid_int() else 0
		var b := int(clean)
		match op:
			"==": return a == b
			"!=": return a != b
			">=": return a >= b
			"<=": return a <= b
			">":  return a > b
			"<":  return a < b
	# String.
	match op:
		"==": return str(actual) == clean
		"!=": return str(actual) != clean
	return false


# ══════════════════════════════════════════════════════════════════════════════
# EJECUTOR DE COMANDOS
# ══════════════════════════════════════════════════════════════════════════════

func _execute_commands(commands: Array, context: Dictionary) -> void:
	await _run_block(commands, 0, commands.size(), context)


## Ejecuta commands[start, end) respetando bloques condicionales LT
## (if / elif / else / end), anidamiento incluido. Sólo corre la rama cuya
## condición se cumple; el resto se salta.
func _run_block(commands: Array, start: int, end: int, context: Dictionary) -> void:
	var i := start
	while i < end:
		var entry = commands[i]
		if not (entry is Array) or entry.size() < 1:
			i += 1
			continue
		var cmd := str(entry[0])
		if cmd == "if":
			var block := _find_conditional(commands, i, end)
			for clause in block["clauses"]:
				if clause["is_else"] or _evaluate_condition(str(clause["cond"]), context):
					await _run_block(commands, clause["body_start"], clause["body_end"], context)
					break
			i = block["after"]
			continue
		if cmd == "elif" or cmd == "else" or cmd == "end":
			# Terminador suelto (no debería ocurrir a este nivel) — ignorar.
			i += 1
			continue
		var args = entry[1] if entry.size() >= 2 else []
		await _exec_one(cmd, args, context)
		i += 1


## Analiza una estructura if/elif/else/end desde `if_index`. Devuelve
## { "clauses": [ { cond, is_else, body_start, body_end } ], "after": idx }
## donde `after` es el índice tras el `end` correspondiente.
func _find_conditional(commands: Array, if_index: int, end: int) -> Dictionary:
	var clauses: Array = []
	var if_entry = commands[if_index]
	var cur_cond := "True"
	if if_entry.size() >= 2 and if_entry[1] is Array and if_entry[1].size() >= 1:
		cur_cond = str(if_entry[1][0])
	var cur_is_else := false
	var cur_body_start := if_index + 1
	var depth := 0
	var i := if_index + 1
	while i < end:
		var entry = commands[i]
		var cmd := ""
		if entry is Array and entry.size() >= 1:
			cmd = str(entry[0])
		if cmd == "if":
			depth += 1
		elif cmd == "end":
			if depth == 0:
				clauses.append({ "cond": cur_cond, "is_else": cur_is_else,
						"body_start": cur_body_start, "body_end": i })
				return { "clauses": clauses, "after": i + 1 }
			depth -= 1
		elif (cmd == "elif" or cmd == "else") and depth == 0:
			clauses.append({ "cond": cur_cond, "is_else": cur_is_else,
					"body_start": cur_body_start, "body_end": i })
			if cmd == "elif":
				cur_cond = "False"
				if entry.size() >= 2 and entry[1] is Array and entry[1].size() >= 1:
					cur_cond = str(entry[1][0])
				cur_is_else = false
			else:
				cur_cond = "True"
				cur_is_else = true
			cur_body_start = i + 1
		i += 1
	# Sin 'end' correspondiente (malformado) — cerrar en el límite.
	clauses.append({ "cond": cur_cond, "is_else": cur_is_else,
			"body_start": cur_body_start, "body_end": end })
	return { "clauses": clauses, "after": end }


func _exec_one(cmd: String, args: Array, context: Dictionary) -> void:
	match cmd:
		"speak":
			await _cmd_speak(args, context)
		"add_portrait":
			_cmd_add_portrait(args, context)
		"multi_add_portrait":
			_cmd_multi_add_portrait(args, context)
		"remove_portrait":
			_cmd_remove_portrait(args, context)
		"multi_remove_portrait":
			_cmd_multi_remove_portrait(args, context)
		"move_portrait":
			_cmd_move_portrait(args, context)
		"change_portrait":
			_cmd_change_portrait(args, context)
		"expression":
			_cmd_expression(args, context)
		"give_item":
			_cmd_give_item(args, context)
		"give_gold", "give_money":
			_cmd_give_gold(args)
		"set_flag":
			_cmd_set_flag(args)
		"level_var", "game_var":
			_cmd_level_var(args)
		"spawn_unit", "add_unit":
			_cmd_add_unit(args)
		"move_unit":
			_cmd_move_unit(args)
		"remove_unit", "kill_unit":
			_cmd_remove_unit(args)
		"remove_all_units":
			_cmd_remove_all_units()
		"change_team":
			_cmd_change_team(args)
		"add_talk":
			_cmd_add_talk(args)
		"unlock_support_rank":
			_cmd_unlock_support_rank(args)
		"autolevel_to":
			_cmd_autolevel_to(args)
		"increment_support_points":
			_cmd_increment_support_points(args)
		"add_group":
			_cmd_add_group(args)
		"spawn_group":
			_cmd_spawn_group(args)
		"move_group":
			_cmd_move_group(args)
		"victory":
			force_victory.emit()
		"defeat":
			force_defeat.emit()
		"win_game":
			force_victory.emit()
		"lose_game":
			force_defeat.emit()
		"inc_level_var":
			_cmd_inc_level_var(args)
		"remove_region":
			_cmd_remove_region(args)
		"add_tag":
			_cmd_add_tag(args, context)
		"give_skill":
			_cmd_unit_skill(args, context, true)
		"remove_skill":
			_cmd_unit_skill(args, context, false)
		"music":
			_cmd_music(args)
		"music_clear":
			_cmd_music_clear()
		"transition":
			await _cmd_transition(args)
		"change_background":
			_cmd_change_background(args)
		"map_anim":
			await _cmd_map_anim(args)
		"center_cursor", "move_cursor":
			await _cmd_center_cursor(args)
		"chapter_title":
			await _cmd_chapter_title()
		"change_ai":
			_cmd_change_ai(args, context)
		"trigger_script":
			await _cmd_trigger_script(args, context)
		"remove_group":
			_cmd_remove_group(args)
		"remove_item":
			_cmd_remove_item(args, context)
		"wait":
			var ms: int = int(args[0]) if args.size() > 0 else 500
			if game_manager and game_manager.has_method("get_tree"):
				await game_manager.get_tree().create_timer(ms / 1000.0).timeout
		# Comandos de presentación / aún sin subsistema — silenciados sin ruido.
		# (portraits, capas, animaciones de mapa, música, cinemáticas, tiendas,
		#  base/prep, y unos pocos de gameplay que requieren sistemas no portados
		#  todavía: change_ai, change_stats, interact_unit, trigger_script…).
		"change_tilemap", "comment", "credits", "overworld_cinematic", "fade_to_black", "end_skip", "reveal_overworld_node", "screen_shake", "flicker_cursor", "show_layer", "hide_layer", "remove_talk", "add_market_item", "arrange_formation", "prep", "base", "shop", "choice", "interact_unit", "change_stats", "has_traded":
			pass
		_:
			# Comandos no reconocidos — log para detectar nuevos a implementar.
			if OS.is_debug_build():
				print("[EventSystem] cmd ignorado: %s %s" % [cmd, args])


# ── Comandos concretos ───────────────────────────────────────────────────────

func _cmd_speak(args: Array, context: Dictionary) -> void:
	if args.is_empty():
		return
	var nid := _portrait_nid(str(args[0]), context)
	var line := str(args[1]) if args.size() >= 2 else ""
	# Retrato de respaldo por si el hablante no estaba en escena (sin add_portrait).
	var fallback := _portrait_tex(nid)
	await _ensure_dialogue().play_line(nid, nid, line, fallback)


## nid de retrato: resuelve tokens {unit}/{unit2} al nombre de la unidad.
func _portrait_nid(token: String, context: Dictionary) -> String:
	if token.begins_with("{"):
		return _resolve_token(token, context)
	return token


## Textura del retrato de un nid (hoja LT), o null si no existe.
func _portrait_tex(nid: String) -> Texture2D:
	if nid == "" or not has_node("/root/AssetLoader"):
		return null
	return get_node("/root/AssetLoader").get_portrait(nid)


var _portrait_offsets: Dictionary = {}
var _offsets_loaded: bool = false

## Offset de parpadeo (blinking_offset) de un retrato, o (-1,-1) si no hay dato.
func _portrait_blink(nid: String) -> Vector2:
	if not _offsets_loaded:
		_offsets_loaded = true
		var path := "res://data/general/portrait_offsets.json"
		if FileAccess.file_exists(path):
			var f := FileAccess.open(path, FileAccess.READ)
			var d = JSON.parse_string(f.get_as_text())
			f.close()
			if d is Dictionary:
				_portrait_offsets = d
	var e = _portrait_offsets.get(nid)
	if e is Dictionary and e.has("blink"):
		var b = e["blink"]
		if b is Array and b.size() >= 2:
			return Vector2(float(b[0]), float(b[1]))
	return Vector2(-1, -1)


# ── Comandos de retrato (escenario del EventDialogue) ────────────────────────

func _cmd_add_portrait(args: Array, context: Dictionary) -> void:
	if args.size() < 2:
		return
	var nid := _portrait_nid(str(args[0]), context)
	_ensure_dialogue().add_portrait(nid, str(args[1]), _portrait_tex(nid), _portrait_blink(nid))


func _cmd_multi_add_portrait(args: Array, context: Dictionary) -> void:
	# Pares [nid, pos, nid, pos, ...].
	var i := 0
	while i + 1 < args.size():
		var nid := _portrait_nid(str(args[i]), context)
		_ensure_dialogue().add_portrait(nid, str(args[i + 1]), _portrait_tex(nid), _portrait_blink(nid))
		i += 2


## expression(unit, expr) — cambia el estado de ojos del retrato en escena.
func _cmd_expression(args: Array, context: Dictionary) -> void:
	if args.size() < 2:
		return
	_ensure_dialogue().set_expression(_portrait_nid(str(args[0]), context), str(args[1]))


func _cmd_remove_portrait(args: Array, context: Dictionary) -> void:
	if args.is_empty():
		return
	_ensure_dialogue().remove_portrait(_portrait_nid(str(args[0]), context))


func _cmd_multi_remove_portrait(args: Array, context: Dictionary) -> void:
	for a in args:
		_ensure_dialogue().remove_portrait(_portrait_nid(str(a), context))


func _cmd_move_portrait(args: Array, context: Dictionary) -> void:
	if args.size() < 2:
		return
	_ensure_dialogue().move_portrait(_portrait_nid(str(args[0]), context), str(args[1]))


## change_portrait(unit, new_portrait_nid) — cambia la hoja del retrato en escena.
func _cmd_change_portrait(args: Array, context: Dictionary) -> void:
	if args.size() < 2:
		return
	var nid := _portrait_nid(str(args[0]), context)
	var new_tex := _portrait_tex(str(args[1]))
	_ensure_dialogue().change_portrait(nid, new_tex)


# ── Presentación: capa, diálogo, música, transiciones, fondo ─────────────────

func _ensure_presentation() -> CanvasLayer:
	if _pres_layer == null or not is_instance_valid(_pres_layer):
		_pres_layer = CanvasLayer.new()
		_pres_layer.name = "EventPresentation"
		_pres_layer.layer = 20
		add_child(_pres_layer)
	return _pres_layer


func _ensure_dialogue() -> EventDialogue:
	if _dialogue == null or not is_instance_valid(_dialogue):
		_dialogue = EventDialogue.new()
		_ensure_presentation().add_child(_dialogue)
	return _dialogue


func _ensure_bg() -> TextureRect:
	if _bg_rect == null or not is_instance_valid(_bg_rect):
		_bg_rect = TextureRect.new()
		_bg_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_bg_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		_bg_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_bg_rect.visible = false
		_ensure_presentation().add_child(_bg_rect)
		_ensure_presentation().move_child(_bg_rect, 0)   # detrás del diálogo
	return _bg_rect


func _ensure_fade() -> ColorRect:
	if _fade_rect == null or not is_instance_valid(_fade_rect):
		_fade_rect = ColorRect.new()
		_fade_rect.color = Color(0, 0, 0, 0)
		_fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ensure_presentation().add_child(_fade_rect)   # encima de todo
	return _fade_rect


func _ensure_music() -> AudioStreamPlayer:
	if _music_player == null or not is_instance_valid(_music_player):
		_music_player = AudioStreamPlayer.new()
		if AudioServer.get_bus_index("Music") >= 0:
			_music_player.bus = "Music"
		add_child(_music_player)
	return _music_player


func _cmd_music(args: Array) -> void:
	if args.is_empty():
		return
	var nid := str(args[0])
	var stream = null
	if has_node("/root/AssetLoader"):
		stream = get_node("/root/AssetLoader").get_music(nid)
	if stream == null:
		return
	if "loop" in stream:
		stream.loop = true
	var p := _ensure_music()
	p.stream = stream
	p.play()


func _cmd_music_clear() -> void:
	if _music_player != null and is_instance_valid(_music_player):
		_music_player.stop()


## transition("Close"/"Open"[, ms]) — cubre/revela la pantalla con un fundido.
func _cmd_transition(args: Array) -> void:
	var mode := (str(args[0]).to_lower() if args.size() >= 1 else "close")
	var dur := 0.4
	if args.size() >= 2 and str(args[1]).is_valid_int():
		dur = int(args[1]) / 1000.0
	var rect := _ensure_fade()
	var target := 0.0 if mode.begins_with("open") else 1.0
	var t := create_tween()
	t.tween_property(rect, "color:a", target, dur)
	await t.finished


## change_background(nid) — muestra un panorama a pantalla completa; vacío = oculta.
func _cmd_change_background(args: Array) -> void:
	var rect := _ensure_bg()
	if args.is_empty() or str(args[0]) == "":
		rect.visible = false
		return
	var tex: Texture2D = null
	if has_node("/root/AssetLoader"):
		tex = get_node("/root/AssetLoader").get_panorama(str(args[0]))
	if tex == null:
		rect.visible = false
		return
	rect.texture = tex
	rect.visible = true


# ── map_anim (animación de mapa one-shot en una casilla) ─────────────────────

var _anim_defs: Dictionary = {}
var _anim_defs_loaded: bool = false

## Definición de una animación de mapa (frame_x/frame_y/num_frames) desde
## assets/animations/animations.json.
func _anim_def(nid: String):
	if not _anim_defs_loaded:
		_anim_defs_loaded = true
		var path := "res://assets/animations/animations.json"
		if FileAccess.file_exists(path):
			var f := FileAccess.open(path, FileAccess.READ)
			var arr = JSON.parse_string(f.get_as_text())
			f.close()
			if arr is Array:
				for a in arr:
					if a is Dictionary and a.has("nid"):
						_anim_defs[str(a["nid"])] = a
	return _anim_defs.get(nid)


## map_anim(nid, "x,y") — reproduce la animación `nid` sobre la casilla dada.
func _cmd_map_anim(args: Array) -> void:
	if args.size() < 2 or game_manager == null:
		return
	var nid := str(args[0])
	var d = _anim_def(nid)
	var tex_path := "res://assets/animations/" + nid + ".png"
	if d == null or not ResourceLoader.exists(tex_path):
		return
	var tex: Texture2D = load(tex_path)
	var fx: int = int(d.get("frame_x", 1))
	var fy: int = int(d.get("frame_y", 1))
	var nframes: int = int(d.get("num_frames", fx * fy))
	if fx <= 0 or fy <= 0 or nframes <= 0:
		return
	var cw := tex.get_width() / fx
	var ch := tex.get_height() / fy
	# Posición de mundo desde la casilla (usa el grid del GameManager si existe).
	var cell := _parse_position(str(args[1]))
	var world := Vector2.ZERO
	if "grid" in game_manager and game_manager.grid != null:
		world = game_manager.grid.grid_to_world(cell)
	var spr := Sprite2D.new()
	spr.texture = tex
	spr.region_enabled = true
	spr.centered = true
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.position = world
	spr.z_index = 100
	game_manager.add_child(spr)   # Node2D en el árbol → espacio de mundo (cámara)
	for fr in range(nframes):
		var col := fr % fx
		var row := fr / fx
		spr.region_rect = Rect2(col * cw, row * ch, cw, ch)
		await get_tree().create_timer(0.06).timeout
	spr.queue_free()


## center_cursor/move_cursor("x,y"[, "immediate"]) — panea la cámara a la casilla.
func _cmd_center_cursor(args: Array) -> void:
	if game_manager == null or args.is_empty():
		return
	var vp := get_viewport()
	if vp == null:
		return
	var cam := vp.get_camera_2d()
	if cam == null or not ("grid" in game_manager) or game_manager.grid == null:
		return
	var world: Vector2 = game_manager.grid.grid_to_world(_parse_position(str(args[0])))
	if args.size() >= 2 and str(args[1]) == "immediate":
		cam.position = world
		return
	var t := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(cam, "position", world, 0.4)
	await t.finished


## chapter_title — rótulo con el nombre del capítulo (de LoadedLevel.name_str).
func _cmd_chapter_title() -> void:
	var title := ""
	if game_manager != null and game_manager.loaded_level != null \
			and "name_str" in game_manager.loaded_level:
		title = str(game_manager.loaded_level.name_str)
	if title == "":
		return
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.0)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ensure_presentation().add_child(overlay)
	var label := Label.new()
	label.text = title
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.modulate.a = 0.0
	var f = load("res://assets/fonts/IMFellFrenchCanonSC-Regular.ttf")
	if f != null:
		label.add_theme_font_override("font", f)
	label.add_theme_font_size_override("font_size", 64)
	label.add_theme_color_override("font_color", Color(0.95, 0.90, 0.70, 1.0))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	overlay.add_child(label)
	var t := create_tween()
	t.tween_property(overlay, "color:a", 0.6, 0.5)
	t.parallel().tween_property(label, "modulate:a", 1.0, 0.5)
	t.tween_interval(1.4)
	t.tween_property(overlay, "color:a", 0.0, 0.5)
	t.parallel().tween_property(label, "modulate:a", 0.0, 0.5)
	await t.finished
	overlay.queue_free()


## change_ai(unit, preset) — cambia el preset de IA de la unidad. El AIController
## lo lee vía `unit.get_meta("ai_preset")`, así que basta con fijar la meta.
func _cmd_change_ai(args: Array, context: Dictionary) -> void:
	if args.size() < 2:
		return
	var unit = _resolve_unit(str(args[0]), context)
	if unit == null:
		return
	unit.set_meta("ai_preset", str(args[1]))


## trigger_script(name) — ejecuta los comandos del evento nombrado (eventos sin
## trigger propio que se lanzan desde otros). Anti-recursión con _script_depth.
func _cmd_trigger_script(args: Array, context: Dictionary) -> void:
	if args.is_empty() or _script_depth > 8:
		return
	var ev = events_by_name.get(str(args[0]))
	if ev == null:
		return
	_script_depth += 1
	await _execute_commands(ev.get("commands", []), context)
	_script_depth -= 1


## remove_group(group_nid) — despawnea (silencioso) las unidades de un grupo,
## p.ej. limpiar refuerzos. Reusa loaded_level.unit_groups vía _find_unit_group.
func _cmd_remove_group(args: Array) -> void:
	if args.is_empty() or game_manager == null:
		return
	var group := _find_unit_group(str(args[0]))
	if group.is_empty():
		return
	for unit_nid in group.get("units", []):
		var u = _resolve_unit(str(unit_nid), {})
		if u == null:
			continue
		if "grid" in game_manager and game_manager.grid != null:
			game_manager.grid.remove_unit(u.grid_position)
		if "player_units" in game_manager:
			game_manager.player_units.erase(u)
		if "enemy_units" in game_manager:
			game_manager.enemy_units.erase(u)
		u.queue_free()


## remove_item(unit, item) — quita un ítem del inventario de la unidad (por nombre).
func _cmd_remove_item(args: Array, context: Dictionary) -> void:
	if args.size() < 2:
		return
	var unit = _resolve_unit(str(args[0]), context)
	if unit == null or not ("inventory" in unit):
		return
	var item_name := str(args[1])
	for it in unit.inventory:
		var nm := ""
		if it is Object and "name" in it:
			nm = str(it.name)
		elif it is Dictionary:
			nm = str(it.get("name", ""))
		if nm == item_name:
			unit.inventory.erase(it)
			return


func _cmd_give_item(args: Array, context: Dictionary) -> void:
	if args.size() < 2 or game_manager == null:
		return
	var target_token := str(args[0])
	var item_nid := str(args[1])
	var target = _resolve_unit(target_token, context)
	# Buscar el item.  Estrategia:
	#   1) Si game_manager.project_data tiene el item (formato LT crudo),
	#      usar LevelLoader._instantiate_item con la factory configurada.
	#   2) Fallback: dict { id, name } mínimo.
	var item = null
	if "project_data" in game_manager:
		var items_db: Dictionary = game_manager.project_data.get("items", {})
		if items_db.has(item_nid):
			item = LevelLoader._instantiate_item(item_nid, items_db)
	if item == null:
		item = { "id": item_nid, "name": item_nid }
	if target != null and "inventory" in target:
		if target.inventory.size() < 5:
			target.inventory.append(item)
		elif convoy != null:
			convoy.deposit(item)


func _cmd_give_gold(args: Array) -> void:
	if args.size() < 1 or game_manager == null:
		return
	var amount := int(args[0])
	if "army_gold" in game_manager:
		game_manager.army_gold += amount


func _cmd_set_flag(args: Array) -> void:
	if args.size() < 1:
		return
	level_vars[str(args[0])] = true


func _cmd_level_var(args: Array) -> void:
	if args.size() < 2:
		return
	level_vars[str(args[0])] = args[1]


## inc_level_var(key[, amount]) — incrementa un contador de nivel (usado por los
## eventos de destructibles cuyos totales leen luego los bloques if/elif).
func _cmd_inc_level_var(args: Array) -> void:
	if args.is_empty():
		return
	var key := str(args[0])
	var amount := 1
	if args.size() >= 2 and str(args[1]).is_valid_int():
		amount = int(args[1])
	var cur = level_vars.get(key, 0)
	var base := int(cur) if str(cur).is_valid_int() else 0
	level_vars[key] = base + amount


## remove_region(nid) — quita una región del capítulo (p.ej. tras visitar un
## pueblo) para que no vuelva a dispararse su evento.
func _cmd_remove_region(args: Array) -> void:
	if args.is_empty() or game_manager == null:
		return
	if not game_manager.has_meta("chapter_regions"):
		return
	var nid := str(args[0])
	var regions: Array = game_manager.get_meta("chapter_regions")
	var kept: Array = []
	for r in regions:
		if r is Dictionary and str(r.get("nid", "")) == nid:
			continue
		kept.append(r)
	game_manager.set_meta("chapter_regions", kept)


## add_tag(unit, tag) — añade un tag a la unidad (Mounted/Boss/…) si no lo tiene.
func _cmd_add_tag(args: Array, context: Dictionary) -> void:
	if args.size() < 2:
		return
	var unit = _resolve_unit(str(args[0]), context)
	if unit == null or not ("tags" in unit):
		return
	var tag := str(args[1])
	if tag not in unit.tags:
		unit.tags.append(tag)


## give_skill/remove_skill(unit, skill) — modifica las skills de la unidad.
func _cmd_unit_skill(args: Array, context: Dictionary, add: bool) -> void:
	if args.size() < 2:
		return
	var unit = _resolve_unit(str(args[0]), context)
	if unit == null:
		return
	var skill := str(args[1])
	if add:
		if unit.has_method("learn_skill"):
			unit.learn_skill(skill)
	elif unit.has_method("remove_skill"):
		unit.remove_skill(skill)


## Formato canónico LT: ["nid", "x,y"] o ["nid", "x,y", "immediate"/"fade"/...]
## También acepta el formato ampliado [nid, x_int, y_int, team_str].
func _cmd_add_unit(args: Array) -> void:
	if args.size() < 2 or game_manager == null:
		return
	if not game_manager.has_method("spawn_unit_by_nid"):
		return
	var nid := str(args[0])
	var pos: Vector2i = _parse_position(args[1])
	# Team: cuarto argumento si es string "player"/"enemy", si no inferir de
	# si el nid existe ya en player_units (es de player) — por defecto "enemy".
	var team := "enemy"
	if args.size() >= 4 and (str(args[3]) == "player" or str(args[3]) == "enemy"):
		team = str(args[3])
	else:
		# Heurística: si el unit_nid existe en project_data["units"] y tiene
		# tag "Lord" o aparece en el party, asumir player.
		var udb: Dictionary = game_manager.project_data.get("units", {}) \
				if "project_data" in game_manager else {}
		if udb.has(nid):
			var udata = udb[nid]
			var tags = udata.get("tags", []) if udata is Dictionary else udata.tags
			# Si el evento está reclutando una unidad, suele ser player.
			# Marcadores típicos: Lord, BaldrHeir, etc.
			for t in tags:
				if str(t) in ["Lord", "BaldrHeir", "HezulHeir", "FjalarHeir",
						"NeirHeir", "BragiHeir", "ForsetiHeir", "NagaHeir",
						"OdHeir", "DainHeir", "SetyHeir", "UlirHeir"]:
					team = "player"
					break
	game_manager.spawn_unit_by_nid(nid, pos, team)


func _cmd_move_unit(args: Array) -> void:
	# Formato canon: [unit_nid, "x,y", from_pos?, ...]
	# Para fines mecánicos (sin animación cinemática) basta con teleport.
	if args.size() < 2 or game_manager == null:
		return
	var nid := str(args[0])
	var unit = _resolve_unit(nid, {})
	if unit == null:
		return
	var pos: Vector2i = _parse_position(args[1])
	if "grid" in game_manager and game_manager.grid != null:
		game_manager.grid.move_unit(unit.grid_position, pos)
		unit.global_position = game_manager.grid.grid_to_world(pos)
	unit.grid_position = pos


func _cmd_remove_unit(args: Array) -> void:
	if args.size() < 1 or game_manager == null:
		return
	var unit = _resolve_unit(str(args[0]), {})
	if unit == null:
		return
	if game_manager.has_method("_handle_unit_death"):
		game_manager._handle_unit_death(unit)


func _cmd_remove_all_units() -> void:
	if game_manager == null:
		return
	# Eliminar TODAS las unidades (utilizado al recargar el mapa antes de
	# spawn de un cap nuevo).  Se hace silencioso: sin EXP ni eventos.
	var all := []
	if "player_units" in game_manager:
		all.append_array(game_manager.player_units.duplicate())
	if "enemy_units" in game_manager:
		all.append_array(game_manager.enemy_units.duplicate())
	for u in all:
		if u == null:
			continue
		if "grid" in game_manager and game_manager.grid != null:
			game_manager.grid.remove_unit(u.grid_position)
		u.queue_free()
	if "player_units" in game_manager:
		game_manager.player_units.clear()
	if "enemy_units" in game_manager:
		game_manager.enemy_units.clear()


## Marca dos unidades como aptas para conversación (talk event).
##   Formato canon LT: [unit1_nid, unit2_nid]
##   Guardamos la pareja como flag "talk:U1:U2" en level_vars.
func _cmd_add_talk(args: Array) -> void:
	if args.size() < 2:
		return
	var key := "talk:%s:%s" % [str(args[0]), str(args[1])]
	level_vars[key] = true


## Concede un rango de support a una pareja (atajo de eventos canon).
##   Formato canon: [u1, u2, rank_name]   ej: ["Quan", "Ethlyn", "Married"]
func _cmd_unlock_support_rank(args: Array) -> void:
	if args.size() < 3 or game_manager == null:
		return
	var u1 := str(args[0])
	var u2 := str(args[1])
	var rank := str(args[2])
	# Delegar al SupportSystem si existe.
	if "support_system" in game_manager and game_manager.support_system != null:
		var ss = game_manager.support_system
		# Sumar puntos hasta superar el umbral del rango.
		# Threshold canon FE4: Lover 200, Married 250.
		var threshold := 250 if rank == "Married" else 200
		ss.add_points(u1, u2, threshold)


## Nivela una unidad a un nivel concreto.
##   Formato canon: [unit_nid, target_level, "fixed"/"random"]
##   En modo "fixed" usamos los growth rates esperados; en "random" tira RNG.
##   Para simplificar el test, escalamos los stats proporcionalmente.
func _cmd_autolevel_to(args: Array) -> void:
	if args.size() < 2 or game_manager == null:
		return
	var unit = _resolve_unit(str(args[0]), {})
	if unit == null:
		return
	var target_level := int(args[1])
	if target_level <= unit.level:
		return
	var levels_to_gain: int = target_level - int(unit.level)
	# Aplicar growths probabilísticos por nivel (canon FE).
	if unit.has_method("level_up"):
		for i in range(levels_to_gain):
			unit.level_up()
	else:
		# Fallback: subir nivel sin tocar stats.
		unit.level = target_level


## Suma puntos de support entre dos personajes.
##   Formato canon: [unit1_nid, unit2_nid, points]
func _cmd_increment_support_points(args: Array) -> void:
	if args.size() < 3 or game_manager == null:
		return
	if not ("support_system" in game_manager) or game_manager.support_system == null:
		return
	var u1 := str(args[0])
	var u2 := str(args[1])
	var pts := int(args[2])
	game_manager.support_system.add_points(u1, u2, pts)


# ── Comandos de grupos (canon LT) ─────────────────────────────────────────────
#
# Los grupos se definen en el cap (level.unit_groups) con:
#   nid: id del grupo
#   units: [nid, nid, ...] lista de unit_nids miembros
#   positions: { nid: [x, y], ... } posiciones de spawn opcionales
#
# Los 3 comandos son variantes del mismo concepto: poner / mover unidades
# del grupo a sus posiciones canon.  Para fines mecánicos (sin animación
# cinemática), todos se reducen a: teletransportar al grupo a las posiciones
# del StartingGroup (o del propio grupo si no se especifica).


## Lookup de un unit_group por nid en el cap actual.
##   loaded_level.unit_groups es Dictionary { nid: grupo_dict }.
func _find_unit_group(nid: String) -> Dictionary:
	if game_manager == null:
		return {}
	# Camino preferido: GameManager.loaded_level.unit_groups (Dictionary).
	if "loaded_level" in game_manager and game_manager.loaded_level != null:
		var ll = game_manager.loaded_level
		if "unit_groups" in ll and ll.unit_groups is Dictionary:
			var g = ll.unit_groups.get(nid, null)
			if g is Dictionary:
				return g
	# Fallback: buscar en current_chapter_data["unit_groups"] (Array crudo).
	if "current_chapter_data" in game_manager and game_manager.current_chapter_data is Dictionary:
		var groups: Array = game_manager.current_chapter_data.get("unit_groups", [])
		for g in groups:
			if g is Dictionary and str(g.get("nid", "")) == nid:
				return g
	return {}


## Resuelve las posiciones de un grupo:
##   1. Si el grupo tiene `positions` rellenas, usarlas.
##   2. Si no, devolver dict vacío (las unidades ya están en sus pos canon).
func _group_positions(group: Dictionary) -> Dictionary:
	if group.is_empty():
		return {}
	var pos = group.get("positions", {})
	if pos is Dictionary:
		return pos
	return {}


## add_group [Group, StartingGroup?, ...]
##   Añade unidades del grupo al mapa en las posiciones del StartingGroup
##   (o del propio grupo si StartingGroup no se especifica).
func _cmd_add_group(args: Array) -> void:
	if args.size() < 1 or game_manager == null:
		return
	var group_nid := str(args[0])
	var starting_nid := str(args[1]) if args.size() >= 2 and str(args[1]) != "" else group_nid
	var group := _find_unit_group(group_nid)
	if group.is_empty():
		return
	var members: Array = group.get("units", [])
	var pos_source := _find_unit_group(starting_nid)
	var positions := _group_positions(pos_source)
	for nid_v in members:
		var unit_nid := str(nid_v)
		var pos: Vector2i = Vector2i.ZERO
		if positions.has(unit_nid):
			pos = _parse_position(positions[unit_nid])
		# Spawn (heurística de team como en _cmd_add_unit).
		if game_manager.has_method("spawn_unit_by_nid"):
			game_manager.spawn_unit_by_nid(unit_nid, pos, _infer_team(unit_nid))


## spawn_group [Group, CardinalDirection, StartingGroup, ...]
##   Misma lógica que add_group pero conceptualmente "entran desde el
##   borde".  Sin animación cinemática se reduce a teleport directo.
func _cmd_spawn_group(args: Array) -> void:
	if args.size() < 1 or game_manager == null:
		return
	var group_nid := str(args[0])
	# args[1] = direction (north/south/east/west) — ignorado sin anim.
	var starting_nid := str(args[2]) if args.size() >= 3 and str(args[2]) != "" else group_nid
	var group := _find_unit_group(group_nid)
	if group.is_empty():
		return
	var members: Array = group.get("units", [])
	var pos_source := _find_unit_group(starting_nid)
	var positions := _group_positions(pos_source)
	for nid_v in members:
		var unit_nid := str(nid_v)
		var pos: Vector2i = Vector2i.ZERO
		if positions.has(unit_nid):
			pos = _parse_position(positions[unit_nid])
		if game_manager.has_method("spawn_unit_by_nid"):
			game_manager.spawn_unit_by_nid(unit_nid, pos, _infer_team(unit_nid))


## move_group [Group, StartingGroup, ...]
##   Mueve unidades del grupo (ya en el mapa) a las posiciones definidas
##   en StartingGroup.  Si la unidad no está aún en el mapa, se la spawnea.
func _cmd_move_group(args: Array) -> void:
	if args.size() < 1 or game_manager == null:
		return
	var group_nid := str(args[0])
	var starting_nid := str(args[1]) if args.size() >= 2 and str(args[1]) != "" else group_nid
	var group := _find_unit_group(group_nid)
	if group.is_empty():
		return
	var members: Array = group.get("units", [])
	var pos_source := _find_unit_group(starting_nid)
	var positions := _group_positions(pos_source)
	for nid_v in members:
		var unit_nid := str(nid_v)
		if not positions.has(unit_nid):
			continue
		var pos: Vector2i = _parse_position(positions[unit_nid])
		var unit = _resolve_unit(unit_nid, {})
		if unit == null:
			# No está en el mapa → spawn.
			if game_manager.has_method("spawn_unit_by_nid"):
				game_manager.spawn_unit_by_nid(unit_nid, pos, _infer_team(unit_nid))
			continue
		# Ya en el mapa → teleport.
		if "grid" in game_manager and game_manager.grid != null:
			game_manager.grid.move_unit(unit.grid_position, pos)
			unit.global_position = game_manager.grid.grid_to_world(pos)
		unit.grid_position = pos


## Heurística para detectar el team de un unit_nid.
##   Aliados de Sigurd (Lord, *Heir tags) → player.
##   Resto → enemy.
func _infer_team(nid: String) -> String:
	if game_manager == null or not ("project_data" in game_manager):
		return "enemy"
	var udb: Dictionary = game_manager.project_data.get("units", {})
	if not udb.has(nid):
		return "enemy"
	var udata = udb[nid]
	var tags = udata.get("tags", []) if udata is Dictionary else udata.tags
	for t in tags:
		if str(t) in ["Lord", "BaldrHeir", "HezulHeir", "FjalarHeir",
				"NeirHeir", "BragiHeir", "ForsetiHeir", "NagaHeir",
				"OdHeir", "DainHeir", "SetyHeir", "UlirHeir"]:
			return "player"
	return "enemy"


## Parser de "x,y" → Vector2i.  Acepta también [x, y] como Array.
static func _parse_position(arg) -> Vector2i:
	if arg is Vector2i:
		return arg
	if arg is Array and arg.size() >= 2:
		return Vector2i(int(arg[0]), int(arg[1]))
	var s := str(arg)
	var parts := s.split(",")
	if parts.size() >= 2:
		return Vector2i(int(parts[0]), int(parts[1]))
	return Vector2i.ZERO


func _cmd_change_team(args: Array) -> void:
	# args = [unit_nid, new_team]
	if args.size() < 2 or game_manager == null:
		return
	var unit = _resolve_unit(str(args[0]), {})
	if unit == null:
		return
	var new_team := str(args[1])
	unit.is_player_unit = (new_team == "player")
	# Mover entre listas del game_manager.
	if game_manager.has_method("move_unit_to_team"):
		game_manager.move_unit_to_team(unit, new_team)


# ══════════════════════════════════════════════════════════════════════════════
# RESOLUCIÓN DE TOKENS
# ══════════════════════════════════════════════════════════════════════════════

## Resuelve un token en string ("{unit}", "Sigurd", etc.) al valor real.
func _resolve_token(token: String, context: Dictionary) -> String:
	token = token.strip_edges()
	if token.begins_with("{") and token.ends_with("}"):
		var key := token.substr(1, token.length() - 2)
		if context.has(key):
			var v = context[key]
			if v is Unit:
				return v.unit_name
			return str(v)
		return ""
	return token


## Resuelve un token a una Unit real.
func _resolve_unit(token: String, context: Dictionary):
	if token.begins_with("{") and token.ends_with("}"):
		var key := token.substr(1, token.length() - 2)
		if context.has(key):
			var v = context[key]
			if v is Unit:
				return v
	# Buscar en game_manager.player_units / enemy_units.
	if game_manager == null:
		return null
	for u in (game_manager.player_units if "player_units" in game_manager else []):
		if u.unit_name == token:
			return u
	for u in (game_manager.enemy_units if "enemy_units" in game_manager else []):
		if u.unit_name == token:
			return u
	return null


# ══════════════════════════════════════════════════════════════════════════════
# CONSULTAS
# ══════════════════════════════════════════════════════════════════════════════

## ¿Una flag está activa?
func has_flag(flag: String) -> bool:
	return level_vars.has(flag) and bool(level_vars[flag])


## Valor de una variable de nivel.
func get_var(name_str: String, default = null):
	return level_vars.get(name_str, default)
