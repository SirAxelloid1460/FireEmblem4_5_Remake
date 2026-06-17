extends Control
class_name DialogueBox

# Referencias a nodos UI
@onready var dialogue_panel: PanelContainer = $DialoguePanel
@onready var character_name_label: Label = $DialoguePanel/MarginContainer/VBoxContainer/NameLabel
@onready var dialogue_text_label: RichTextLabel = $DialoguePanel/MarginContainer/VBoxContainer/DialogueLabel
@onready var portrait_left: TextureRect = $PortraitLeft
@onready var portrait_right: TextureRect = $PortraitRight
@onready var continue_indicator: Label = $DialoguePanel/ContinueIndicator
@onready var animation_player: AnimationPlayer = $AnimationPlayer

# Configuración
@export var text_speed: float = 0.05  # Segundos por carácter
@export var auto_advance_delay: float = 2.0

# Estado
var current_text: String = ""
var displayed_text: String = ""
var is_displaying: bool = false
var is_waiting_for_input: bool = false
var can_skip: bool = true

# Cola de diálogos
var dialogue_queue: Array[Dictionary] = []
var current_dialogue_index: int = 0

# Señales
signal dialogue_started
signal dialogue_line_finished
signal dialogue_finished
signal text_displayed

func _ready():
	hide()
	continue_indicator.hide()
	setup_ui_style()

func setup_ui_style():
	"""Configura el estilo visual del diálogo estilo Fire Emblem"""
	# Configurar panel
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	style_box.border_width_left = 3
	style_box.border_width_top = 3
	style_box.border_width_right = 3
	style_box.border_width_bottom = 3
	style_box.border_color = Color(0.8, 0.7, 0.5, 1.0)
	style_box.corner_radius_top_left = 8
	style_box.corner_radius_top_right = 8
	style_box.corner_radius_bottom_left = 8
	style_box.corner_radius_bottom_right = 8
	
	dialogue_panel.add_theme_stylebox_override("panel", style_box)
	
	# Configurar texto
	character_name_label.add_theme_color_override("font_color", Color(1, 0.9, 0.7, 1))
	character_name_label.add_theme_font_size_override("font_size", 24)
	
	dialogue_text_label.add_theme_color_override("default_color", Color(1, 1, 1, 1))
	dialogue_text_label.add_theme_font_size_override("normal_font_size", 20)

func show_dialogue(character: String, text: String, portrait_path: String = "") -> void:
	"""Muestra un diálogo individual"""
	show()
	dialogue_started.emit()
	
	# Configurar nombre del personaje
	character_name_label.text = character
	current_text = text
	displayed_text = ""
	
	# Configurar retrato
	setup_portrait(character, portrait_path)
	
	# Animar entrada del panel
	if animation_player and animation_player.has_animation("dialogue_enter"):
		animation_player.play("dialogue_enter")
		await animation_player.animation_finished
	
	# Mostrar texto con efecto de escritura
	await display_text_gradually()
	
	# Esperar input del jugador
	await wait_for_continue()
	
	# Animar salida
	if animation_player and animation_player.has_animation("dialogue_exit"):
		animation_player.play("dialogue_exit")
		await animation_player.animation_finished
	
	dialogue_line_finished.emit()

func show_dialogue_sequence(dialogues: Array[Dictionary]):
	"""Muestra una secuencia de diálogos"""
	dialogue_queue = dialogues
	current_dialogue_index = 0
	
	for dialogue_data in dialogue_queue:
		await show_dialogue(
			dialogue_data["character"],
			dialogue_data["text"],
			dialogue_data.get("portrait", "")
		)
		current_dialogue_index += 1
	
	hide()
	dialogue_finished.emit()

func display_text_gradually():
	"""Muestra el texto gradualmente con efecto de escritura"""
	is_displaying = true
	dialogue_text_label.text = ""
	displayed_text = ""
	continue_indicator.hide()
	
	for i in range(current_text.length()):
		if not is_displaying:
			# Si se saltó, mostrar todo el texto
			dialogue_text_label.text = current_text
			displayed_text = current_text
			break
		
		displayed_text += current_text[i]
		dialogue_text_label.text = displayed_text
		
		# Reproducir sonido de texto (opcional)
		play_text_sound()
		
		# Pausa entre caracteres
		await get_tree().create_timer(text_speed).timeout
	
	is_displaying = false
	continue_indicator.show()
	animate_continue_indicator()
	text_displayed.emit()

func play_text_sound():
	"""Reproduce sonido de texto (bip corto)"""
	# Aquí puedes añadir un AudioStreamPlayer con un sonido corto
	pass

func wait_for_continue():
	"""Espera a que el jugador presione una tecla para continuar"""
	is_waiting_for_input = true
	
	# Esperar input
	while is_waiting_for_input:
		await get_tree().process_frame
	
	continue_indicator.hide()

func skip_text_display():
	"""Salta el efecto de escritura y muestra todo el texto"""
	if is_displaying:
		is_displaying = false

func advance_dialogue():
	"""Avanza al siguiente diálogo"""
	if is_displaying:
		skip_text_display()
	elif is_waiting_for_input:
		is_waiting_for_input = false

func setup_portrait(character: String, portrait_path: String):
	"""Configura el retrato del personaje"""
	# Resetear retratos
	portrait_left.modulate.a = 0.4
	portrait_right.modulate.a = 0.4
	
	if portrait_path == "":
		# Sin retrato
		portrait_left.hide()
		portrait_right.hide()
		return
	
	# Cargar retrato
	var portrait_texture = load_portrait(portrait_path)
	if not portrait_texture:
		return
	
	# Determinar si va a la izquierda o derecha (basado en si es jugador o enemigo)
	var is_player_character = CharacterDatabase.is_player_character(character)
	
	if is_player_character:
		portrait_left.texture = portrait_texture
		portrait_left.show()
		portrait_left.modulate.a = 1.0
		portrait_right.hide()
		
		# Animación de entrada
		animate_portrait_enter(portrait_left)
	else:
		portrait_right.texture = portrait_texture
		portrait_right.show()
		portrait_right.modulate.a = 1.0
		portrait_left.hide()
		
		# Animación de entrada
		animate_portrait_enter(portrait_right)

func load_portrait(path: String) -> Texture2D:
	"""Carga un retrato desde el path especificado"""
	if FileAccess.file_exists(path):
		return load(path)
	return null

func animate_portrait_enter(portrait: TextureRect):
	"""Anima la entrada de un retrato"""
	var original_pos = portrait.position
	portrait.position.x -= 50 if portrait == portrait_left else 50
	portrait.modulate.a = 0
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(portrait, "position", original_pos, 0.3)
	tween.tween_property(portrait, "modulate:a", 1.0, 0.3)

func animate_continue_indicator():
	"""Anima el indicador de continuar (flecha parpadeante)"""
	continue_indicator.text = "▼"
	
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(continue_indicator, "modulate:a", 0.3, 0.5)
	tween.tween_property(continue_indicator, "modulate:a", 1.0, 0.5)

func _input(event):
	"""Maneja el input del jugador"""
	if not visible:
		return
	
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_select"):
		advance_dialogue()
	
	if event.is_action_pressed("ui_cancel") and can_skip:
		# Saltar toda la secuencia de diálogos
		skip_dialogue_sequence()

func skip_dialogue_sequence():
	"""Salta toda la secuencia de diálogos"""
	is_displaying = false
	is_waiting_for_input = false
	dialogue_queue.clear()
	hide()
	dialogue_finished.emit()

# ============================================
# EFECTOS ESPECIALES
# ============================================

func shake_portrait(portrait: TextureRect, intensity: float = 10.0, duration: float = 0.5):
	"""Hace temblar el retrato (para énfasis emocional)"""
	var original_pos = portrait.position
	var shake_count = int(duration / 0.05)
	
	for i in range(shake_count):
		var offset = Vector2(
			randf_range(-intensity, intensity),
			randf_range(-intensity, intensity)
		)
		portrait.position = original_pos + offset
		await get_tree().create_timer(0.05).timeout
	
	portrait.position = original_pos

func flash_portrait(portrait: TextureRect, color: Color = Color.WHITE, duration: float = 0.2):
	"""Flash de color en el retrato"""
	var original_modulate = portrait.modulate
	
	var tween = create_tween()
	tween.tween_property(portrait, "modulate", color, duration / 2)
	tween.tween_property(portrait, "modulate", original_modulate, duration / 2)

func zoom_portrait(portrait: TextureRect, scale_to: float = 1.2, duration: float = 0.3):
	"""Hace zoom en el retrato"""
	var tween = create_tween()
	tween.tween_property(portrait, "scale", Vector2(scale_to, scale_to), duration)
