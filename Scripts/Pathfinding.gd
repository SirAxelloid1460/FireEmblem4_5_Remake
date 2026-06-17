extends Node
class_name Pathfinding

# Pathfinding con costes de movimiento DECIMALES nativos.
#
# FE4 usa costes decimales para movimiento (road = 0.7, plain = 1.0,
# forest = 2.0, etc.) — esto refleja que los caminos son más rápidos
# que el terreno normal y que ciertos terrenos son más difíciles.
#
# Godot soporta float nativamente, así que aquí no hay escalado: la
# unidad MOV 9.0 puede recorrer 9 plain (1.0×9 = 9.0) o ~12 road
# (0.7×12 ≈ 8.4) o 4 forest (2.0×4 = 8.0).
#
# El coste de cada tile lo provee TerrainSystem.get_movement_cost(terrain_id).
# Los tiles con coste -1.0 son intransitables.


# ══════════════════════════════════════════════════════════════════════════════
# A* — camino más corto entre dos puntos
# ══════════════════════════════════════════════════════════════════════════════

static func find_path(grid: Grid, start: Vector2i, goal: Vector2i,
		max_distance: float = 999.0, for_unit = null) -> Array[Vector2i]:
	if not _can_pass(grid, goal, for_unit) and goal != start:
		return []

	var open_set: Array[Vector2i] = [start]
	var came_from: Dictionary = {}
	var g_score: Dictionary = {start: 0.0}
	var f_score: Dictionary = {start: float(heuristic(start, goal))}

	while open_set.size() > 0:
		var current: Vector2i = get_lowest_f_score(open_set, f_score)

		if current == goal:
			return reconstruct_path(came_from, current)

		open_set.erase(current)

		for neighbor in grid.get_neighbors(current):
			if not _can_pass(grid, neighbor, for_unit) and neighbor != goal:
				continue
			var step_cost: float = _tile_cost(grid, neighbor)
			if step_cost < 0.0:
				continue
			var tentative_g: float = float(g_score[current]) + step_cost
			if tentative_g > max_distance:
				continue

			if not g_score.has(neighbor) or tentative_g < float(g_score[neighbor]):
				came_from[neighbor] = current
				g_score[neighbor] = tentative_g
				f_score[neighbor] = tentative_g + float(heuristic(neighbor, goal))
				if neighbor not in open_set:
					open_set.append(neighbor)

	return []


## Comprueba si una unidad puede ATRAVESAR un tile (no necesariamente
## quedarse encima — eso se filtra después).  Reglas canon FE:
##   • Tile fuera de mapa o intransitable por terreno → false.
##   • Tile con enemigo → false (no se puede atravesar).
##   • Tile con aliado → true (sí se atraviesa, pero no se puede acabar ahí).
##   • Tile vacío → true.
##
## Si for_unit es null, se mantiene comportamiento legacy (cualquier
## unidad bloquea — útil para el escenario de test simple sin bandos).
static func _can_pass(grid: Grid, pos: Vector2i, for_unit) -> bool:
	if not grid.is_valid_position(pos):
		return false
	if not grid.tiles.get(pos, {}).get("walkable", false):
		return false
	if grid.units.has(pos):
		var blocker = grid.units[pos]
		if for_unit == null:
			return false
		if "is_player_unit" in blocker and "is_player_unit" in for_unit:
			return blocker.is_player_unit == for_unit.is_player_unit
		return false
	return true


# ══════════════════════════════════════════════════════════════════════════════
# Casillas alcanzables — Dijkstra con coste float
# ══════════════════════════════════════════════════════════════════════════════

## Devuelve todas las casillas a las que la unidad puede LLEGAR (no quedarse
## a medio camino) gastando como mucho `movement` puntos de movimiento.
##   movement: float — puntos de MOV de la unidad (Sigurd = 9.0).
##   for_unit: Unit opcional — si se pasa, los aliados SÍ se pueden atravesar
##             durante el cálculo (canon FE), los enemigos no.  Las casillas
##             ocupadas por OTRA unidad (de cualquier bando) NO aparecen en
##             el resultado final, porque no se puede acabar el turno encima.
##
## El tile inicial NO se incluye en la salida (la unidad ya está allí).
static func get_reachable_tiles(grid: Grid, start: Vector2i,
		movement: float, for_unit = null) -> Array[Vector2i]:
	var reachable: Array[Vector2i] = []
	var best_cost: Dictionary = {start: 0.0}
	var frontier: Array = [start]

	while frontier.size() > 0:
		# Sacar el tile con menor coste actual (Dijkstra simple).
		var idx: int = 0
		var min_c: float = float(best_cost[frontier[0]])
		for i in range(1, frontier.size()):
			var c: float = float(best_cost[frontier[i]])
			if c < min_c:
				min_c = c
				idx = i
		var current: Vector2i = frontier[idx]
		frontier.remove_at(idx)
		var current_cost: float = float(best_cost[current])

		for neighbor in grid.get_neighbors(current):
			# Verificación de pasable: el tile NO está bloqueado por terreno
			# Y no hay un enemigo en él (los aliados sí se atraviesan).
			if not _can_pass(grid, neighbor, for_unit):
				continue
			var step_cost: float = _tile_cost(grid, neighbor)
			if step_cost < 0.0:
				continue
			var new_cost: float = current_cost + step_cost
			if new_cost > movement:
				continue
			if not best_cost.has(neighbor) or new_cost < float(best_cost[neighbor]):
				best_cost[neighbor] = new_cost
				if neighbor not in frontier:
					frontier.append(neighbor)
				# Solo añadir a reachable si la unidad puede TERMINAR su turno
				# allí — no puede quedarse encima de otra unidad (incl. aliada).
				if not grid.units.has(neighbor) and neighbor not in reachable:
					reachable.append(neighbor)

	return reachable


# ══════════════════════════════════════════════════════════════════════════════
# Rangos de ataque
# ══════════════════════════════════════════════════════════════════════════════

static func get_attack_range(grid: Grid, position: Vector2i,
		min_range: int, max_range: int) -> Array[Vector2i]:
	var in_range: Array[Vector2i] = []
	for x in range(position.x - max_range, position.x + max_range + 1):
		for y in range(position.y - max_range, position.y + max_range + 1):
			var target := Vector2i(x, y)
			if not grid.is_valid_position(target):
				continue
			var distance: int = get_manhattan_distance(position, target)
			if distance >= min_range and distance <= max_range:
				in_range.append(target)
	return in_range


static func get_tiles_in_attack_range_after_move(grid: Grid, start: Vector2i,
		movement: float, weapon_min_range: int,
		weapon_max_range: int, for_unit = null) -> Array[Vector2i]:
	var attackable: Array[Vector2i] = []
	var reachable: Array[Vector2i] = get_reachable_tiles(grid, start, movement, for_unit)
	reachable.append(start)  # también puede atacar sin moverse
	for pos in reachable:
		var attack_tiles: Array[Vector2i] = get_attack_range(grid, pos,
				weapon_min_range, weapon_max_range)
		for tile in attack_tiles:
			if tile not in attackable and tile not in reachable:
				attackable.append(tile)
	return attackable


# ══════════════════════════════════════════════════════════════════════════════
# Helpers
# ══════════════════════════════════════════════════════════════════════════════

## Coste de mover ENTRAR en este tile.  Lee del Grid si tiene terrain_type
## y delega a TerrainSystem.get_movement_cost().
static func _tile_cost(grid: Grid, pos: Vector2i) -> float:
	if not grid.tiles.has(pos):
		return 1.0
	var data: Dictionary = grid.tiles[pos]
	var terrain_id := str(data.get("terrain_type", "plain"))
	return TerrainSystem.get_movement_cost(terrain_id)


static func heuristic(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)


static func get_manhattan_distance(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)


static func get_lowest_f_score(open_set: Array[Vector2i],
		f_score: Dictionary) -> Vector2i:
	var lowest: Vector2i = open_set[0]
	var lowest_score: float = float(f_score.get(lowest, INF))
	for node in open_set:
		var score: float = float(f_score.get(node, INF))
		if score < lowest_score:
			lowest = node
			lowest_score = score
	return lowest


static func reconstruct_path(came_from: Dictionary, current: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = [current]
	while came_from.has(current):
		current = came_from[current]
		path.push_front(current)
	return path
