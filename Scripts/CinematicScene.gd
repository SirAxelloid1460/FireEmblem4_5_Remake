extends Node2D
class_name CinematicScene

# Referencias a nodos
@onready var camera: Camera2D = $Camera2D
@onready var map_sprite: Sprite2D = $MapSprite
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var dialogue_box: DialogueBox = $CanvasLayer/DialogueBox

# Configuración
@export var auto_play: bool = true
@export var skip_enabled: bool = true

# Estado
var is_playing: bool = false
var current_sequence_index: int = 0
var cinematic_sequence: Array[Dictionary] = []

# Señales
signal cinematic_started
signal cinematic_finished
signal sequence_step_started(step_index: int)
signal sequence_step_finished(step_index: int)

func _ready():
	if dialogue_box:
		dialogue_box.hide()
	
	if auto_play:
		await get_tree().create_timer(0.5).timeout
		play_cinematic()

# ============================================
# REPRODUCCIÓN DE CINEMÁTICAS
# ============================================

func play_cinematic():
	"""Reproduce la secuencia cinemática completa automáticamente"""
	if is_playing:
		return
	
	is_playing = true
	cinematic_started.emit()
	
	# Construir la secuencia cinemática
	cinematic_sequence = build_cinematic_sequence()
	
	# Ejecutar cada paso de la secuencia
	for i in range(cinematic_sequence.size()):
		current_sequence_index = i
		sequence_step_started.emit(i)
		
		var step = cinematic_sequence[i]
		await execute_cinematic_step(step)
		
		sequence_step_finished.emit(i)
	
	is_playing = false
	cinematic_finished.emit()
	
	# Transición al siguiente nivel/escena
	await get_tree().create_timer(1.0).timeout
	transition_to_next_scene()

func build_cinematic_sequence() -> Array[Dictionary]:
	"""
	Construye la secuencia de pasos cinemáticos.
	Sobrescribe esta función en escenas hijas para crear cinemáticas específicas.
	"""
	var sequence: Array[Dictionary] = []
	
	# Ejemplo de secuencia (puedes sobrescribir esto)
	sequence.append({
		"type": "fade_in",
		"duration": 2.0
	})
	
	sequence.append({
		"type": "show_title",
		"text": "FIRE EMBLEM",
		"duration": 3.0
	})
	
	sequence.append({
		"type": "camera_move",
		"target": Vector2(400, 300),
		"duration": 3.0,
		"zoom": Vector2(1.0, 1.0)
	})
	
	sequence.append({
		"type": "dialogue_sequence",
		"dialogues": [
			{
				"character": "Narrador",
				"text": "Hace mucho tiempo, en tierras lejanas...",
				"portrait": ""
			}
		]
	})
	
	sequence.append({
		"type": "camera_pan",
		"waypoints": [
			Vector2(400, 300),
			Vector2(600, 400),
			Vector2(800, 350)
		],
		"duration": 5.0
	})
	
	sequence.append({
		"type": "fade_out",
		"duration": 2.0
	})
	
	return sequence

func execute_cinematic_step(step: Dictionary):
	"""Ejecuta un paso individual de la cinemática"""
	match step["type"]:
		"fade_in":
			await fade_in(step.get("duration", 1.0))
		
		"fade_out":
			await fade_out(step.get("duration", 1.0))
		
		"show_title":
			await show_title(step["text"], step.get("duration", 2.0))
		
		"camera_move":
			await camera_move_to(
				step["target"],
				step.get("duration", 2.0),
				step.get("zoom", Vector2(1.0, 1.0))
			)
		
		"camera_pan":
			await camera_pan_through_waypoints(
				step["waypoints"],
				step.get("duration", 3.0)
			)
		
		"camera_zoom":
			await camera_zoom(
				step.get("zoom", Vector2(1.0, 1.0)),
				step.get("duration", 1.0)
			)
		
		"dialogue_sequence":
			await play_dialogue_sequence(step["dialogues"])
		
		"wait":
			await get_tree().create_timer(step.get("duration", 1.0)).timeout
		
		"flash":
			await flash_screen(
				step.get("color", Color.WHITE),
				step.get("duration", 0.3)
			)
		
		"shake":
			await shake_camera(
				step.get("intensity", 20.0),
				step.get("duration", 0.5)
			)
		
		"play_animation":
			if animation_player and animation_player.has_animation(step["animation"]):
				animation_player.play(step["animation"])
				await animation_player.animation_finished

# ============================================
# EFECTOS DE CÁMARA
# ============================================

func camera_move_to(target: Vector2, duration: float, target_zoom: Vector2 = Vector2(1.0, 1.0)):
	"""Mueve la cámara a una posición con zoom opcional"""
	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN_OUT)
	
	tween.tween_property(camera, "global_position", target, duration)
	tween.tween_property(camera, "zoom", target_zoom, duration)
	
	await tween.finished

func camera_pan_through_waypoints(waypoints: Array, total_duration: float):
	"""Hace un paneo de cámara a través de múltiples puntos"""
	if waypoints.size() == 0:
		return
	
	var duration_per_waypoint = total_duration / waypoints.size()
	
	for waypoint in waypoints:
		var tween = create_tween()
		tween.set_trans(Tween.TRANS_SINE)
		tween.set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(camera, "global_position", waypoint, duration_per_waypoint)
		await tween.finished

func camera_zoom(target_zoom: Vector2, duration: float):
	"""Hace zoom en la cámara"""
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(camera, "zoom", target_zoom, duration)
	await tween.finished

func shake_camera(intensity: float, duration: float):
	"""Sacude la cámara"""
	var original_offset = camera.offset
	var shake_count = int(duration / 0.05)
	
	for i in range(shake_count):
		camera.offset = original_offset + Vector2(
			randf_range(-intensity, intensity),
			randf_range(-intensity, intensity)
		)
		await get_tree().create_timer(0.05).timeout
	
	camera.offset = original_offset

# ============================================
# EFECTOS VISUALES
# ============================================

func fade_in(duration: float):
	"""Fade in desde negro"""
	var fade_rect = create_fade_rect()
	fade_rect.modulate.a = 1.0
	
	var tween = create_tween()
	tween.tween_property(fade_rect, "modulate:a", 0.0, duration)
	await tween.finished
	
	fade_rect.queue_free()

func fade_out(duration: float):
	"""Fade out a negro"""
	var fade_rect = create_fade_rect()
	fade_rect.modulate.a = 0.0
	
	var tween = create_tween()
	tween.tween_property(fade_rect, "modulate:a", 1.0, duration)
	await tween.finished

func create_fade_rect() -> ColorRect:
	"""Crea un ColorRect para efectos de fade"""
	var rect = ColorRect.new()
	rect.color = Color.BLACK
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	$CanvasLayer.add_child(rect)
	return rect

func show_title(text: String, duration: float):
	"""Muestra un título en pantalla"""
	var label = create_title_label(text)
	$CanvasLayer.add_child(label)
	
	# Animación de entrada
	label.modulate.a = 0
	var tween = create_tween()
	tween.tween_property(label, "modulate:a", 1.0, 0.5)
	await tween.finished
	
	# Mantener visible
	await get_tree().create_timer(duration - 1.0).timeout
	
	# Animación de salida
	tween = create_tween()
	tween.tween_property(label, "modulate:a", 0.0, 0.5)
	await tween.finished
	
	label.queue_free()

func create_title_label(text: String) -> Label:
	"""Crea un label estilizado para títulos"""
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 64)
	label.add_theme_color_override("font_color", Color(1, 0.9, 0.7, 1))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	label.add_theme_constant_override("outline_size", 10)
	
	label.set_anchors_preset(Control.PRESET_CENTER)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	return label

func flash_screen(color: Color, duration: float):
	"""Flash de pantalla"""
	var flash_rect = ColorRect.new()
	flash_rect.color = color
	flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	$CanvasLayer.add_child(flash_rect)
	
	var tween = create_tween()
	tween.tween_property(flash_rect, "modulate:a", 0.0, duration)
	await tween.finished
	
	flash_rect.queue_free()

# ============================================
# DIÁLOGOS
# ============================================

func play_dialogue_sequence(dialogues: Array):
	"""Reproduce una secuencia de diálogos"""
	for dialogue_data in dialogues:
		await dialogue_box.show_dialogue(
			dialogue_data["character"],
			dialogue_data["text"],
			dialogue_data.get("portrait", "")
		)

# ============================================
# INPUT Y SKIP
# ============================================

func _input(event):
	"""Manejo de input para saltar cinemática"""
	if not is_playing:
		return
	
	if event.is_action_pressed("skip_cinematic") and skip_enabled:
		skip_cinematic()
	
	# También permitir saltar con ESC o Start
	if event.is_action_pressed("ui_cancel") and skip_enabled:
		skip_cinematic()

func skip_cinematic():
	"""Salta la cinemática completa"""
	print("Skipping cinematic...")
	is_playing = false
	
	# Detener todos los tweens
	var tweens = get_tree().get_nodes_in_group("tweens")
	for tween in tweens:
		if tween is Tween:
			tween.kill()
	
	# Ocultar diálogos
	if dialogue_box:
		dialogue_box.skip_dialogue_sequence()
	
	cinematic_finished.emit()
	transition_to_next_scene()

# ============================================
# TRANSICIÓN
# ============================================

func transition_to_next_scene():
	"""Transiciona a la siguiente escena"""
	# Sobrescribe esto en escenas específicas
	print("Cinematic finished, transitioning to next scene...")
	# Por defecto, volver al menú principal
	get_tree().change_scene_to_file("res://Scenes/main_menu.tscn")


# ============================================
# CINEMATIC PRESETS
# ============================================

# Puedes crear funciones helper para secuencias comunes
static func create_opening_sequence() -> Array[Dictionary]:
	"""Crea una secuencia de apertura típica"""
	return [
		{"type": "fade_in", "duration": 2.0},
		{"type": "show_title", "text": "FIRE EMBLEM", "duration": 3.0},
		{"type": "fade_out", "duration": 1.0}
	]

static func create_chapter_intro(chapter_name: String, location: Vector2) -> Array[Dictionary]:
	"""Crea una intro de capítulo estándar"""
	return [
		{"type": "fade_in", "duration": 1.5},
		{"type": "camera_move", "target": location, "duration": 3.0, "zoom": Vector2(1.5, 1.5)},
		{"type": "show_title", "text": chapter_name, "duration": 2.5},
		{"type": "camera_zoom", "zoom": Vector2(1.0, 1.0), "duration": 1.5}
	]

static func create_dramatic_reveal(text: String) -> Array[Dictionary]:
	"""Crea una revelación dramática"""
	return [
		{"type": "flash", "color": Color.WHITE, "duration": 0.2},
		{"type": "shake", "intensity": 30.0, "duration": 0.5},
		{"type": "show_title", "text": text, "duration": 3.0}
	]
