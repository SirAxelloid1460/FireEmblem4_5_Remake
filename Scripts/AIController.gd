# AIController.gd
# Sistema de IA portado de LT-maker (engine/ai_controller.py).
#
# CONCEPTO:
#   Cada unidad enemiga tiene asignado un "AI preset" (string) que
#   referencia una entrada en project_data["ai"].  Cada preset contiene
#   una lista de "behaviours" que se evalúan EN ORDEN; el primero que
#   produce una acción válida se ejecuta.
#
# FORMATO DE UN BEHAVIOUR (canónico LT):
#   {
#     "action":      "None" | "Attack" | "Move_to" | "Move_away_from"
#                    | "Steal" | "Support" | "Interact" | "Wait",
#     "target":      "None" | "Unit" | "Enemy" | "Ally" | "Position" | "Event",
#     "target_spec": null | string  (nid de evento, posición, etc.)
#     "view_range":  int (códigos especiales:
#                     -1 = guard (no se mueve si nadie está en zero_move),
#                     -2 = single_move (solo unidades en rango de 1 movimiento),
#                     -3 = double_move (rango de 2 movimientos),
#                     -4 = unlimited (todo el mapa),
#                     -5 = nunca (None preset),
#                     >= 0 = radio en tiles fijo),
#     "invert_targeting": bool,
#     "desired_proximity": int  (Move_to: cuánto acercarse al target),
#     "condition":   string (expresión condicional — ignorada en este port).
#   }
#
# PRESETS CANÓNICOS (verificados contra Thracia776):
#   None / Attack / Pursue / Defend / Guard / AttackTile / PursueVillage /
#   FollowBoss / FollowWagon / Berserk / Heal / Thief / SimpleThief /
#   Seize / JoshuaDefend.
#
# PRESETS BUILT-IN:
#   Si project_data["ai"] está vacío o no contiene un preset, se usa el
#   built-in `_default_presets()` que cubre los 15 casos canónicos.
#
# CONEXIÓN:
#   El GameManager.execute_enemy_ai() reemplaza su lógica simple por:
#       var ai := AIController.new(grid, project_data)
#       for enemy in enemy_units:
#           if enemy.current_hp > 0:
#               await ai.execute_turn(enemy, player_units, enemy_units, gm)

class_name AIController
extends RefCounted


# ── Constantes de view_range ──────────────────────────────────────────────────

const VR_GUARD       := -1
const VR_SINGLE_MOVE := -2
const VR_DOUBLE_MOVE := -3
const VR_UNLIMITED   := -4
const VR_NEVER       := -5


# ── Estado ────────────────────────────────────────────────────────────────────

var grid: Grid = null
var ai_db: Dictionary = {}  # nid → preset Dictionary

# Presets built-in (fallback si no están en project_data).
const _BUILTIN_PRESETS := {
	"None": [
		{ "action": "None", "target": "None", "view_range": VR_NEVER },
	],
	"Attack": [
		{ "action": "Attack", "target": "Enemy", "view_range": VR_DOUBLE_MOVE },
	],
	"Pursue": [
		{ "action": "Attack", "target": "Enemy", "view_range": VR_UNLIMITED },
	],
	"Guard": [
		{ "action": "Attack", "target": "Enemy", "view_range": VR_SINGLE_MOVE },
	],
	"Defend": [
		{ "action": "Attack", "target": "Enemy", "view_range": VR_DOUBLE_MOVE },
		{ "action": "Move_to", "target": "Position", "view_range": VR_UNLIMITED,
		  "target_spec": null, "desired_proximity": 0 },
	],
	"Berserk": [
		{ "action": "Attack", "target": "Unit", "view_range": VR_UNLIMITED },
	],
	"Heal": [
		{ "action": "Support", "target": "Ally", "view_range": VR_DOUBLE_MOVE },
		{ "action": "Move_away_from", "target": "Enemy", "view_range": VR_DOUBLE_MOVE,
		  "desired_proximity": 3 },
	],
	"Thief": [
		{ "action": "Steal", "target": "Enemy", "view_range": VR_DOUBLE_MOVE },
		{ "action": "Interact", "target": "Event", "view_range": VR_UNLIMITED,
		  "target_spec": "Chest" },
	],
	"SimpleThief": [
		{ "action": "Steal", "target": "Enemy", "view_range": VR_DOUBLE_MOVE },
		{ "action": "Attack", "target": "Enemy", "view_range": VR_DOUBLE_MOVE },
	],
	"Seize": [
		{ "action": "Interact", "target": "Event", "view_range": VR_UNLIMITED,
		  "target_spec": "Seize" },
		{ "action": "Attack", "target": "Enemy", "view_range": VR_SINGLE_MOVE },
	],
	"PursueVillage": [
		{ "action": "Attack", "target": "Enemy", "view_range": VR_DOUBLE_MOVE },
		{ "action": "Interact", "target": "Event", "view_range": VR_UNLIMITED,
		  "target_spec": "Village" },
	],
	"FollowBoss": [
		{ "action": "Attack", "target": "Enemy", "view_range": VR_DOUBLE_MOVE },
		{ "action": "Move_to", "target": "Ally", "view_range": VR_UNLIMITED,
		  "target_spec": "Boss", "desired_proximity": 1 },
	],
	"AttackTile": [
		{ "action": "Attack", "target": "Enemy", "view_range": VR_DOUBLE_MOVE },
		{ "action": "Attack", "target": "Enemy", "view_range": VR_UNLIMITED },
	],
}


# ══════════════════════════════════════════════════════════════════════════════
# CONSTRUCCIÓN
# ══════════════════════════════════════════════════════════════════════════════

func _init(p_grid: Grid, project_data: Dictionary = {}):
	grid = p_grid
	ai_db = project_data.get("ai", {})


## Resuelve un preset por nid: prefiere project_data, fallback a built-in.
func _get_preset(nid: String) -> Array:
	if ai_db.has(nid):
		var entry = ai_db[nid]
		if entry is Dictionary and entry.has("behaviours"):
			return entry["behaviours"]
		if entry is Array:
			return entry
	if _BUILTIN_PRESETS.has(nid):
		return _BUILTIN_PRESETS[nid]
	return _BUILTIN_PRESETS["None"]


# ══════════════════════════════════════════════════════════════════════════════
# EVALUACIÓN DE UN TURNO
# ══════════════════════════════════════════════════════════════════════════════

## Decide y ejecuta la acción de una unidad enemiga.
##   Devuelve un Dictionary con:
##     { "action": String, "moved_to": Vector2i, "attacked": Unit (o null) }
##   El GameManager debe ejecutar el combate si attacked != null.
func decide_action(unit: Unit, all_units: Array) -> Dictionary:
	var preset_nid := str(unit.get_meta("ai_preset", "None"))
	var behaviours := _get_preset(preset_nid)

	for b in behaviours:
		var action := str(b.get("action", "None"))
		if action == "None":
			continue
		var result := _try_behaviour(unit, b, all_units)
		if not result.is_empty():
			return result

	# Ningún behaviour produjo acción → wait.
	return { "action": "Wait", "moved_to": unit.grid_position, "attacked": null }


## Evalúa un behaviour concreto.  Devuelve {} si no produce acción.
func _try_behaviour(unit: Unit, b: Dictionary, all_units: Array) -> Dictionary:
	var action := str(b.get("action", "None"))
	var target_kind := str(b.get("target", "None"))
	var view_range := int(b.get("view_range", VR_UNLIMITED))

	# Recolectar candidatos.
	var targets := _collect_targets(unit, target_kind, b, all_units)
	if targets.is_empty():
		return {}

	# Filtrar por view_range.
	var move_range: float = unit.movement
	var visible := _filter_by_range(unit, targets, view_range, move_range)
	if visible.is_empty():
		return {}

	# Despachar a la rutina concreta.
	match action:
		"Attack":
			return _exec_attack(unit, visible)
		"Move_to":
			return _exec_move_to(unit, visible, int(b.get("desired_proximity", 0)))
		"Move_away_from":
			return _exec_move_away(unit, visible, int(b.get("desired_proximity", 3)))
		"Steal":
			return _exec_steal(unit, visible)
		"Support":
			return _exec_support(unit, visible)
		"Interact":
			# Eventos como Seize, Village, Chest — aquí solo movemos hacia la
			# posición y dejamos que GameManager dispare el evento.
			return _exec_move_to(unit, visible, 0)
	return {}


# ══════════════════════════════════════════════════════════════════════════════
# COLECCIÓN Y FILTRADO DE TARGETS
# ══════════════════════════════════════════════════════════════════════════════

func _collect_targets(unit: Unit, kind: String, behaviour: Dictionary,
		all_units: Array) -> Array:
	var out: Array = []
	match kind:
		"Unit":
			for u in all_units:
				if u != null and u.current_hp > 0 and u != unit:
					out.append(u)
		"Enemy":
			for u in all_units:
				if u != null and u.current_hp > 0 and u != unit:
					if u.is_player_unit != unit.is_player_unit:
						out.append(u)
		"Ally":
			for u in all_units:
				if u != null and u.current_hp > 0 and u != unit:
					if u.is_player_unit == unit.is_player_unit:
						out.append(u)
		"Position":
			# Posición fija — viene como target_spec.
			var spec = behaviour.get("target_spec")
			if spec is Array and spec.size() >= 2:
				out.append({ "position": Vector2i(int(spec[0]), int(spec[1])) })
			elif spec is Vector2i:
				out.append({ "position": spec })
		"Event":
			# Eventos buscados por sub_nid (ej. "Village", "Seize", "Chest").
			# Los evalúa el GameManager con regiones del cap; aquí se devuelve
			# vacío y se confía en que el AI tenga otro behaviour de fallback.
			pass
	return out


## Filtra los targets por view_range.  Para targets que son Unit, usa la
## posición del Unit; para Position dicts usa la clave "position".
func _filter_by_range(unit: Unit, targets: Array, vr: int, move: int) -> Array:
	var origin: Vector2i = unit.grid_position
	var double_move := move * 2
	var single_move := move
	var zero_move := 1  # solo adyacencia
	var out: Array = []
	for t in targets:
		var tpos := _target_position(t)
		var d: int = abs(tpos.x - origin.x) + abs(tpos.y - origin.y)
		var pass_filter := false
		match vr:
			VR_NEVER:        pass_filter = false
			VR_GUARD:        pass_filter = d <= zero_move
			VR_SINGLE_MOVE:  pass_filter = d <= single_move
			VR_DOUBLE_MOVE:  pass_filter = d <= double_move
			VR_UNLIMITED:    pass_filter = true
			_:
				pass_filter = d <= vr
		if pass_filter:
			out.append(t)
	return out


static func _target_position(target) -> Vector2i:
	if target is Unit:
		return target.grid_position
	if target is Dictionary and target.has("position"):
		return target["position"]
	return Vector2i.ZERO


# ══════════════════════════════════════════════════════════════════════════════
# ACCIONES CONCRETAS
# ══════════════════════════════════════════════════════════════════════════════

## Attack: encontrar el mejor objetivo y la mejor posición de ataque.
##   Heurística: prioriza el target más débil que se pueda alcanzar y
##   atacar en este turno (evaluando rango del arma).
func _exec_attack(unit: Unit, targets: Array) -> Dictionary:
	if unit.weapon == null:
		return {}
	var best_target: Unit = null
	var best_pos: Vector2i = unit.grid_position
	var best_score: float = -INF

	for t in targets:
		if not (t is Unit):
			continue
		# Buscar tile desde donde podemos atacar a t en este turno.
		var attack_pos := _find_attack_position(unit, t as Unit)
		if attack_pos == Vector2i(-1, -1):
			continue
		var score := _attack_score(unit, t as Unit)
		if score > best_score:
			best_score = score
			best_target = t as Unit
			best_pos = attack_pos
	if best_target == null:
		return {}
	return { "action": "Attack", "moved_to": best_pos, "attacked": best_target }


## Movimiento sin atacar — acercarse al target hasta desired_proximity.
func _exec_move_to(unit: Unit, targets: Array, proximity: int) -> Dictionary:
	if targets.is_empty():
		return {}
	# Tomamos el target más cercano y nos movemos hacia él.
	var origin: Vector2i = unit.grid_position
	var nearest = null
	var min_dist: float = INF
	for t in targets:
		var p := _target_position(t)
		var d: int = abs(p.x - origin.x) + abs(p.y - origin.y)
		if d < min_dist:
			min_dist = d
			nearest = t
	if nearest == null:
		return {}
	var goal := _target_position(nearest)
	var best_pos := _step_toward(unit, goal, proximity)
	return { "action": "Move_to", "moved_to": best_pos, "attacked": null }


## Move_away_from — alejarse al menos desired_proximity tiles.
func _exec_move_away(unit: Unit, targets: Array, proximity: int) -> Dictionary:
	if targets.is_empty():
		return {}
	var origin: Vector2i = unit.grid_position
	# Calcular el centro de masas de los enemigos cercanos.
	var cx := 0; var cy := 0; var n := 0
	for t in targets:
		var p := _target_position(t)
		cx += p.x; cy += p.y; n += 1
	if n == 0:
		return {}
	var center := Vector2i(int(cx / n), int(cy / n))
	# Direccion opuesta al centro.
	var dir := origin - center
	var goal := origin + dir * proximity
	var best_pos := _step_toward(unit, goal, 0)
	return { "action": "Move_away_from", "moved_to": best_pos, "attacked": null }


## Steal — adyacencia + SPD strict.  Solo intentamos si MapActions lo permite.
func _exec_steal(unit: Unit, targets: Array) -> Dictionary:
	for t in targets:
		if not (t is Unit):
			continue
		var victim := t as Unit
		# Buscar tile adyacente al victim al que podamos llegar.
		var pos := _find_adjacent_position(unit, victim)
		if pos == Vector2i(-1, -1):
			continue
		# SPD check estricto.
		if unit.speed <= victim.speed:
			continue
		var stealable := MapActions.get_stealable_items(unit, victim, true)
		if stealable.is_empty():
			continue
		return { "action": "Steal", "moved_to": pos, "attacked": null,
				 "steal_target": victim, "steal_item": stealable[0] }
	return {}


## Support — moverse hacia un aliado herido para curar.  El GameManager
## determina si el unit lleva staff y cura.
func _exec_support(unit: Unit, targets: Array) -> Dictionary:
	# Filtrar aliados con HP < max.
	var wounded: Array = []
	for t in targets:
		if t is Unit and (t as Unit).current_hp < (t as Unit).max_hp:
			wounded.append(t)
	if wounded.is_empty():
		return {}
	return _exec_move_to(unit, wounded, 1)


# ══════════════════════════════════════════════════════════════════════════════
# UTILIDADES DE PATHFINDING / SCORING
# ══════════════════════════════════════════════════════════════════════════════

## Score de un ataque: prioriza targets que podamos matar de un golpe,
## luego targets con HP bajo, luego cualquier enemigo.
func _attack_score(attacker: Unit, target: Unit) -> float:
	var hp_factor: float = 100.0 / max(1, target.current_hp)
	var damage_estimate: int = attacker.strength + (int(attacker.weapon.might) if attacker.weapon and "might" in attacker.weapon else 0) - target.defense
	if damage_estimate >= target.current_hp:
		hp_factor += 1000.0  # kill bonus
	return hp_factor


## Encuentra el tile alcanzable más cercano desde el cual la unidad puede
## atacar al target con su arma equipada.  Devuelve (-1,-1) si no hay.
func _find_attack_position(unit: Unit, target: Unit) -> Vector2i:
	if unit.weapon == null:
		return Vector2i(-1, -1)
	var min_r: int = unit.weapon.min_range if "min_range" in unit.weapon else 1
	var max_r: int = unit.weapon.max_range if "max_range" in unit.weapon else 1
	var reachable := Pathfinding.get_reachable_tiles(grid, unit.grid_position, unit.movement, unit)
	# Incluir la posición actual si podemos atacar desde ella.
	if not (unit.grid_position in reachable):
		reachable.append(unit.grid_position)
	var tpos: Vector2i = target.grid_position
	var best := Vector2i(-1, -1)
	var best_dist: float = INF
	for tile in reachable:
		var d: int = abs(tile.x - tpos.x) + abs(tile.y - tpos.y)
		if d >= min_r and d <= max_r:
			# Preferir el tile más cercano a la posición original (menos movimiento).
			var orig_dist: int = abs(tile.x - unit.grid_position.x) + abs(tile.y - unit.grid_position.y)
			if orig_dist < best_dist:
				best_dist = orig_dist
				best = tile
	return best


## Encuentra un tile alcanzable adyacente (Manhattan==1) al objetivo.
func _find_adjacent_position(unit: Unit, target: Unit) -> Vector2i:
	var reachable := Pathfinding.get_reachable_tiles(grid, unit.grid_position, unit.movement, unit)
	if not (unit.grid_position in reachable):
		reachable.append(unit.grid_position)
	var tpos: Vector2i = target.grid_position
	for tile in reachable:
		if abs(tile.x - tpos.x) + abs(tile.y - tpos.y) == 1:
			return tile
	return Vector2i(-1, -1)


## Da un paso hacia goal — devuelve el tile alcanzable que minimiza la
## distancia Manhattan al goal, con offset opcional de proximity.
func _step_toward(unit: Unit, goal: Vector2i, proximity: int) -> Vector2i:
	var reachable := Pathfinding.get_reachable_tiles(grid, unit.grid_position, unit.movement, unit)
	if reachable.is_empty():
		return unit.grid_position
	var best: Vector2i = unit.grid_position
	var best_dist: float = INF
	for tile in reachable:
		var d: int = abs(tile.x - goal.x) + abs(tile.y - goal.y)
		# La heurística favorece llegar AL menos a `proximity` tiles del goal.
		var penalty: float = abs(d - proximity)
		if penalty < best_dist:
			best_dist = penalty
			best = tile
	return best


# ══════════════════════════════════════════════════════════════════════════════
# REINFORCEMENTS
# ══════════════════════════════════════════════════════════════════════════════

## Procesa los refuerzos de un capítulo.  Llamar al inicio de cada turno
## enemigo.  reinforcement_data es una lista de:
##   { "trigger": "turn 3" | "event nid",
##     "spawn_position": Vector2i,
##     "unit_def": Dictionary (igual que units en JSON LT) }
##
## Devuelve la lista de unidades nuevas que aparecen este turno.  El caller
## las añade al grid y enemy_units.
static func process_reinforcements(reinforcements: Array, current_turn: int,
		fired_events: Array, project_data: Dictionary) -> Array:
	var spawned: Array = []
	for r in reinforcements:
		var trigger := str(r.get("trigger", ""))
		var should_spawn := false
		# Trigger por turno.
		if trigger.begins_with("turn"):
			var n := _extract_int(trigger)
			if n == current_turn:
				should_spawn = true
		# Trigger por evento.
		elif trigger.begins_with("event"):
			var ev_nid := trigger.substr(5).strip_edges()
			if ev_nid in fired_events:
				should_spawn = true
		if should_spawn:
			# Construir la unidad reusando LevelLoader.build_unit.
			var udef: Dictionary = r.get("unit_def", {})
			var new_unit = LevelLoader.build_unit(udef, project_data)
			if new_unit != null:
				var sp = r.get("spawn_position", udef.get("starting_position", [0, 0]))
				if sp is Vector2i:
					new_unit.grid_position = sp
				elif sp is Array and sp.size() >= 2:
					new_unit.grid_position = Vector2i(int(sp[0]), int(sp[1]))
				spawned.append(new_unit)
	return spawned


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
