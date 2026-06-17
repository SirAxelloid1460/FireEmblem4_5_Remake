extends Node2D
class_name Grid

# Configuración del grid
@export var grid_width: int = 15
@export var grid_height: int = 10
@export var cell_size: int = 64

# Almacenamiento de datos del grid
var tiles: Dictionary = {} # Posición -> Tile data
var units: Dictionary = {} # Posición -> Unit

# Colores para visualización
const COLOR_WALKABLE = Color(0.3, 0.3, 0.3, 0.3)
const COLOR_MOVEMENT = Color(0.2, 0.5, 0.8, 0.5)
const COLOR_ATTACK = Color(0.8, 0.2, 0.2, 0.5)
const COLOR_SELECTED = Color(0.9, 0.9, 0.3, 0.6)

func _ready():
	add_to_group("grid")   # las unidades resuelven cell_size buscando este grupo
	initialize_grid()

func initialize_grid():
	# Inicializar todas las casillas como caminables
	for x in range(grid_width):
		for y in range(grid_height):
			var pos = Vector2i(x, y)
			tiles[pos] = {
				"walkable": true,
				"terrain_type": "plain",
				"defense_bonus": 0,
				"avoid_bonus": 0
			}

func world_to_grid(world_pos: Vector2) -> Vector2i:
	"""Convierte posición del mundo a coordenadas de grid"""
	return Vector2i(
		int(world_pos.x / cell_size),
		int(world_pos.y / cell_size)
	)

func grid_to_world(grid_pos: Vector2i) -> Vector2:
	"""Convierte coordenadas de grid a posición del mundo (centrado)"""
	return Vector2(
		grid_pos.x * cell_size + cell_size / 2,
		grid_pos.y * cell_size + cell_size / 2
	)

func is_valid_position(pos: Vector2i) -> bool:
	"""Verifica si una posición está dentro del grid"""
	return pos.x >= 0 and pos.x < grid_width and pos.y >= 0 and pos.y < grid_height

func is_walkable(pos: Vector2i) -> bool:
	"""Verifica si una casilla es caminable y no tiene unidad"""
	if not is_valid_position(pos):
		return false
	if units.has(pos):
		return false
	return tiles.get(pos, {}).get("walkable", false)

func get_neighbors(pos: Vector2i) -> Array[Vector2i]:
	"""Retorna las casillas adyacentes (4 direcciones)"""
	var neighbors: Array[Vector2i] = []
	var directions = [
		Vector2i(1, 0),   # Derecha
		Vector2i(-1, 0),  # Izquierda
		Vector2i(0, 1),   # Abajo
		Vector2i(0, -1)   # Arriba
	]
	
	for dir in directions:
		var neighbor = pos + dir
		if is_valid_position(neighbor):
			neighbors.append(neighbor)
	
	return neighbors

func place_unit(unit: Unit, pos: Vector2i):
	"""Coloca una unidad en el grid"""
	if is_valid_position(pos):
		units[pos] = unit
		unit.grid_position = pos
		unit.global_position = grid_to_world(pos)

func move_unit(from: Vector2i, to: Vector2i):
	"""Mueve una unidad de una posición a otra"""
	if units.has(from):
		var unit = units[from]
		units.erase(from)
		units[to] = unit
		unit.grid_position = to

func get_unit_at(pos: Vector2i) -> Unit:
	"""Obtiene la unidad en una posición específica"""
	return units.get(pos, null)

func remove_unit(pos: Vector2i):
	"""Remueve una unidad del grid"""
	units.erase(pos)

# Dibuja el grid y las casillas resaltadas
func _draw():
	# Dibujar el grid completo
	for x in range(grid_width + 1):
		draw_line(
			Vector2(x * cell_size, 0),
			Vector2(x * cell_size, grid_height * cell_size),
			Color(0.5, 0.5, 0.5, 0.3),
			1.0
		)
	
	for y in range(grid_height + 1):
		draw_line(
			Vector2(0, y * cell_size),
			Vector2(grid_width * cell_size, y * cell_size),
			Color(0.5, 0.5, 0.5, 0.3),
			1.0
		)

func highlight_cells(cells: Array, color: Color):
	"""Resalta un conjunto de casillas con un color"""
	queue_redraw()
	# Esto se conectará con un sistema de overlay visual
