extends Node2D
class_name WorldMap

# Referencias a nodos
@onready var camera: Camera2D = $Camera2D
@onready var map_sprite: Sprite2D = $MapSprite
@onready var location_markers_container: Node2D = $LocationMarkers
@onready var path_line: Line2D = $PathLine
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var dialogue_box: DialogueBox = $CanvasLayer/DialogueBox

# Configuración
@export var default_camera_zoom: Vector2 = Vector2(0.5, 0.5)
@export var focused_camera_zoom: Vector2 = Vector2(1.0, 1.0)
@export var camera_move_duration: float = 2.0
@export var path_draw_speed: float = 100.0

# Datos de ubicaciones
var locations: Dictionary = {}
var current_location_id: String = ""
var unlocked_locations: Array[String] = []
var campaign_progress: int = 0

# Estado de cinemática
var is_playing_cinematic: bool = false
var cinematic_queue: Array[Dictionary] = []

# Señales
signal location_selected(location_id: String)
signal cinematic_started
signal cinematic_finished
signal location_unlocked(location_id: String)

func _ready():
	setup_world_map()
	initialize_camera()
	
	# Ocultar diálogo inicialmente
	if dialogue_box:
		dialogue_box.hide()

func setup_world_map():
	"""Configura el mapa del mundo con todas las ubicaciones"""
	# Definir ubicaciones (nombre, posición, capítulo)
	register_location("prologue", "Prólogo: El Inicio", Vector2(200, 400), 0)
	register_location("chapter1", "Capítulo 1: La Fortaleza", Vector2(350, 350), 1)
	register_location("chapter2", "Capítulo 2: El Bosque Oscuro", Vector2(500, 280), 2)
	register_location("chapter3", "Capítulo 3: Puerto de Mar", Vector2(650, 320), 3)
	register_location("chapter4", "Capítulo 4: Montañas Heladas", Vector2(700, 200), 4)
	register_location("chapter5", "Capítulo 5: La Capital", Vector2(800, 250), 5)
	
	# Desbloquear el prólogo por defecto
	unlock_location("prologue")
	
	# Crear marcadores visuales
	create_location_markers()

func register_location(id: String, name: String, position: Vector2, chapter: int):
	"""Registra una ubicación en el mapa"""
	locations[id] = {
		"id": id,
		"name": name,
		"position": position,
		"chapter": chapter,
		"unlocked": false,
		"completed": false,
		"marker": null
	}

func unlock_location(location_id: String):
	"""Desbloquea una ubicación en el mapa"""
	if not locations.has(location_id):
		return
	
	locations[location_id]["unlocked"] = true
	unlocked_locations.append(location_id)
	
	# Actualizar marcador visual
	if locations[location_id].has("marker") and locations[location_id]["marker"]:
		locations[location_id]["marker"].set_unlocked(true)
	
	location_unlocked.emit(location_id)

func complete_location(location_id: String):
	"""Marca una ubicación como completada"""
	if not locations.has(location_id):
		return
	
	locations[location_id]["completed"] = true
	
	# Actualizar marcador visual
	if locations[location_id].has("marker") and locations[location_id]["marker"]:
		locations[location_id]["marker"].set_completed(true)

func create_location_markers():
	"""Crea los marcadores visuales para cada ubicación"""
	for loc_id in locations.keys():
		var loc_data = locations[loc_id]
		var marker = LocationMarker.new()
		marker.setup(loc_data["id"], loc_data["name"], loc_data["position"])
		marker.location_clicked.connect(_on_location_clicked)
		location_markers_container.add_child(marker)
		
		locations[loc_id]["marker"] = marker
		
		# Configurar estado inicial
		if loc_data["unlocked"]:
			marker.set_unlocked(true)
		else:
			marker.set_locked()

func initialize_camera():
	"""Inicializa la cámara del mapa"""
	camera.zoom = default_camera_zoom
	
	# Posicionar en la primera ubicación desbloqueada
	if unlocked_locations.size() > 0:
		var first_loc = locations[unlocked_locations[0]]
		camera.global_position = first_loc["position"]

# ============================================
# CINEMÁTICAS
# ============================================

func play_chapter_intro_cinematic(chapter_id: String):
	"""Reproduce la cinemática de introducción a un capítulo"""
	if not locations.has(chapter_id):
		return
	
	is_playing_cinematic = true
	cinematic_started.emit()
	
	var loc = locations[chapter_id]
	
	# Secuencia de cinemática
	await camera_move_to_location(loc["position"], 2.0)
	await camera_zoom_in(focused_camera_zoom, 1.5)
	
	# Mostrar nombre de ubicación
	await show_location_title(loc["name"])
	
	# Si hay diálogos predefinidos, mostrarlos
	if has_chapter_dialogue(chapter_id):
		await play_chapter_dialogue(chapter_id)
	
	await camera_zoom_out(default_camera_zoom, 1.0)
	
	is_playing_cinematic = false
	cinematic_finished.emit()

func play_travel_cinematic(from_id: String, to_id: String):
	"""Reproduce cinemática de viaje entre dos ubicaciones"""
	if not locations.has(from_id) or not locations.has(to_id):
		return
	
	is_playing_cinematic = true
	cinematic_started.emit()
	
	var from_pos = locations[from_id]["position"]
	var to_pos = locations[to_id]["position"]
	
	# Dibujar línea de ruta
	await draw_travel_path(from_pos, to_pos)
	
	# Mover cámara siguiendo la ruta
	await camera_follow_path(from_pos, to_pos, camera_move_duration)
	
	# Zoom en destino
	await camera_zoom_in(focused_camera_zoom, 1.0)
	await show_location_title(locations[to_id]["name"])
	await get_tree().create_timer(1.5).timeout
	await camera_zoom_out(default_camera_zoom, 0.8)
	
	path_line.clear_points()
	
	is_playing_cinematic = false
	current_location_id = to_id
	cinematic_finished.emit()

func play_unlock_cinematic(location_id: String):
	"""Cinemática cuando se desbloquea una nueva ubicación"""
	if not locations.has(location_id):
		return
	
	is_playing_cinematic = true
	cinematic_started.emit()
	
	var loc = locations[location_id]
	
	# Desbloquear ubicación
	unlock_location(location_id)
	
	# Mover cámara a nueva ubicación
	await camera_move_to_location(loc["position"], 1.5)
	
	# Efecto de revelación
	if loc["marker"]:
		loc["marker"].play_unlock_animation()
	
	await show_location_title("Nueva ubicación desbloqueada!")
	await get_tree().create_timer(1.0).timeout
	await show_location_title(loc["name"])
	await get_tree().create_timer(2.0).timeout
	
	is_playing_cinematic = false
	cinematic_finished.emit()

# ============================================
# MOVIMIENTO DE CÁMARA
# ============================================

func camera_move_to_location(target_pos: Vector2, duration: float):
	"""Mueve la cámara suavemente a una ubicación"""
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(camera, "global_position", target_pos, duration)
	await tween.finished

func camera_zoom_in(target_zoom: Vector2, duration: float):
	"""Hace zoom in en la cámara"""
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(camera, "zoom", target_zoom, duration)
	await tween.finished

func camera_zoom_out(target_zoom: Vector2, duration: float):
	"""Hace zoom out en la cámara"""
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(camera, "zoom", target_zoom, duration)
	await tween.finished

func camera_follow_path(from: Vector2, to: Vector2, duration: float):
	"""Hace que la cámara siga una ruta"""
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	
	# Calcular puntos intermedios para una curva suave
	var mid_point = (from + to) / 2
	mid_point.y -= 50  # Arco hacia arriba
	
	tween.tween_property(camera, "global_position", mid_point, duration / 2)
	tween.tween_property(camera, "global_position", to, duration / 2)
	
	await tween.finished

# ============================================
# EFECTOS VISUALES
# ============================================

func draw_travel_path(from: Vector2, to: Vector2):
	"""Dibuja la línea de viaje entre dos puntos"""
	path_line.clear_points()
	path_line.default_color = Color(1, 1, 0, 0.8)
	path_line.width = 3.0
	
	var distance = from.distance_to(to)
	var steps = int(distance / 10)  # Un punto cada 10 píxeles
	
	for i in range(steps + 1):
		var t = float(i) / float(steps)
		var point = from.lerp(to, t)
		path_line.add_point(point)
		await get_tree().create_timer(0.02).timeout

func show_location_title(title: String):
	"""Muestra el título de una ubicación en pantalla"""
	var label = create_title_label(title)
	$CanvasLayer.add_child(label)
	
	# Animación de entrada
	label.modulate.a = 0
	var tween = create_tween()
	tween.tween_property(label, "modulate:a", 1.0, 0.5)
	await tween.finished
	
	await get_tree().create_timer(2.0).timeout
	
	# Animación de salida
	tween = create_tween()
	tween.tween_property(label, "modulate:a", 0.0, 0.5)
	await tween.finished
	
	label.queue_free()

func create_title_label(text: String) -> Label:
	"""Crea un label para títulos cinemáticos"""
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 48)
	label.add_theme_color_override("font_color", Color(1, 0.9, 0.7, 1))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	label.add_theme_constant_override("outline_size", 8)
	
	# Centrar en pantalla
	label.set_anchors_preset(Control.PRESET_CENTER)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	return label

# ============================================
# SISTEMA DE DIÁLOGOS
# ============================================

func has_chapter_dialogue(chapter_id: String) -> bool:
	"""Verifica si un capítulo tiene diálogos predefinidos"""
	return ChapterDialogues.dialogues.has(chapter_id)

func play_chapter_dialogue(chapter_id: String):
	"""Reproduce los diálogos de un capítulo"""
	if not has_chapter_dialogue(chapter_id):
		return
	
	var dialogues = ChapterDialogues.dialogues[chapter_id]
	
	for dialogue_data in dialogues:
		await dialogue_box.show_dialogue(
			dialogue_data["character"],
			dialogue_data["text"],
			dialogue_data.get("portrait", "")
		)

# ============================================
# INPUT
# ============================================

func _on_location_clicked(location_id: String):
	"""Maneja cuando se hace click en una ubicación"""
	if is_playing_cinematic:
		return
	
	if not locations[location_id]["unlocked"]:
		show_locked_message(locations[location_id]["name"])
		return
	
	location_selected.emit(location_id)
	
	# Si hay una ubicación actual, hacer cinemática de viaje
	if current_location_id != "" and current_location_id != location_id:
		await play_travel_cinematic(current_location_id, location_id)
	else:
		await play_chapter_intro_cinematic(location_id)
		current_location_id = location_id

func show_locked_message(location_name: String):
	"""Muestra mensaje cuando se intenta acceder a ubicación bloqueada"""
	var label = create_title_label("¡%s está bloqueado!" % location_name)
	label.add_theme_color_override("font_color", Color(1, 0.3, 0.3, 1))
	$CanvasLayer.add_child(label)
	
	# Animación
	label.modulate.a = 0
	var tween = create_tween()
	tween.tween_property(label, "modulate:a", 1.0, 0.3)
	await tween.finished
	await get_tree().create_timer(1.5).timeout
	tween = create_tween()
	tween.tween_property(label, "modulate:a", 0.0, 0.3)
	await tween.finished
	label.queue_free()

func _input(event):
	"""Manejo de input"""
	if event.is_action_pressed("ui_cancel") and not is_playing_cinematic:
		# Volver al menú principal
		get_tree().change_scene_to_file("res://Scenes/main_menu.tscn")
	
	if event.is_action_pressed("skip_cinematic") and is_playing_cinematic:
		skip_current_cinematic()

func skip_current_cinematic():
	"""Salta la cinemática actual"""
	# Detener todos los tweens
	for tween in get_tree().get_nodes_in_group("cinematics"):
		tween.kill()
	
	is_playing_cinematic = false
	cinematic_finished.emit()
