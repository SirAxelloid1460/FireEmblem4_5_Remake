class_name LocationMarker
extends Node2D

var location_id: String
var location_name: String
var is_unlocked: bool = false
var is_completed: bool = false
var is_hovered: bool = false

signal location_clicked(location_id: String)

func setup(id: String, name: String, pos: Vector2):
	location_id = id
	location_name = name
	global_position = pos

func _ready():
	# Crear área de detección
	var area = Area2D.new()
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 30
	collision.shape = shape
	
	area.add_child(collision)
	add_child(area)
	
	area.mouse_entered.connect(_on_mouse_entered)
	area.mouse_exited.connect(_on_mouse_exited)
	area.input_event.connect(_on_input_event)

func set_locked():
	is_unlocked = false
	modulate = Color(0.4, 0.4, 0.4, 0.5)

func set_unlocked(unlock: bool):
	is_unlocked = unlock
	modulate = Color.WHITE

func set_completed(completed: bool):
	is_completed = completed
	if completed:
		modulate = Color(0.5, 1.0, 0.5, 1.0)

func play_unlock_animation():
	"""Animación cuando se desbloquea"""
	var tween = create_tween()
	tween.set_loops(3)
	tween.tween_property(self, "scale", Vector2(1.3, 1.3), 0.2)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.2)

func _draw():
	# Dibujar marcador
	var color = Color.GRAY
	
	if is_completed:
		color = Color.GREEN
	elif is_unlocked:
		color = Color.GOLD
	
	if is_hovered and is_unlocked:
		color = color.lightened(0.3)
	
	# Círculo principal
	draw_circle(Vector2.ZERO, 25, color)
	
	# Borde
	draw_arc(Vector2.ZERO, 25, 0, TAU, 32, Color.BLACK, 3.0)
	
	# Icono (estrella si completado, punto si desbloqueado)
	if is_completed:
		draw_star(Vector2.ZERO, 5, 12, 7, Color.YELLOW)
	elif not is_unlocked:
		draw_circle(Vector2.ZERO, 8, Color.BLACK)

func draw_star(center: Vector2, points: int, outer_radius: float, inner_radius: float, color: Color):
	"""Dibuja una estrella"""
	var angle_step = TAU / points
	var vertices = PackedVector2Array()
	
	for i in range(points * 2):
		var angle = i * angle_step / 2 - PI / 2
		var radius = outer_radius if i % 2 == 0 else inner_radius
		vertices.append(center + Vector2(cos(angle), sin(angle)) * radius)
	
	draw_colored_polygon(vertices, color)

func _on_mouse_entered():
	if not is_unlocked:
		return
	is_hovered = true
	queue_redraw()

func _on_mouse_exited():
	is_hovered = false
	queue_redraw()

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		location_clicked.emit(location_id)
