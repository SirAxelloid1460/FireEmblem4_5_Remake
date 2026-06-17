extends CanvasLayer
class_name CinematicTransitions

# Tipos de transición disponibles
enum TransitionType {
	FADE,
	WIPE_LEFT,
	WIPE_RIGHT,
	WIPE_UP,
	WIPE_DOWN,
	CIRCLE_CLOSE,
	CIRCLE_OPEN,
	DIAGONAL,
	CURTAIN
}

# Referencias
@onready var transition_rect: ColorRect = $TransitionRect
@onready var animation_player: AnimationPlayer = $AnimationPlayer

# Estado
var is_transitioning: bool = false

signal transition_started
signal transition_midpoint
signal transition_finished

func _ready():
	# Configurar el ColorRect para cubrir toda la pantalla
	transition_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	transition_rect.color = Color.BLACK
	transition_rect.visible = false

# ============================================
# TRANSICIONES PRINCIPALES
# ============================================

func fade_out(duration: float = 1.0, color: Color = Color.BLACK):
	"""Fade out a negro (o color especificado)"""
	if is_transitioning:
		return
	
	is_transitioning = true
	transition_started.emit()
	
	transition_rect.color = color
	transition_rect.modulate.a = 0
	transition_rect.visible = true
	
	var tween = create_tween()
	tween.tween_property(transition_rect, "modulate:a", 1.0, duration)
	await tween.finished
	
	transition_midpoint.emit()
	is_transitioning = false
	transition_finished.emit()

func fade_in(duration: float = 1.0):
	"""Fade in desde negro"""
	if is_transitioning:
		return
	
	is_transitioning = true
	transition_started.emit()
	
	transition_rect.modulate.a = 1.0
	transition_rect.visible = true
	
	var tween = create_tween()
	tween.tween_property(transition_rect, "modulate:a", 0.0, duration)
	await tween.finished
	
	transition_rect.visible = false
	is_transitioning = false
	transition_finished.emit()

func fade_to_scene(scene_path: String, fade_out_duration: float = 1.0, fade_in_duration: float = 1.0):
	"""Fade out, cambia de escena, y fade in"""
	await fade_out(fade_out_duration)
	get_tree().change_scene_to_file(scene_path)
	await fade_in(fade_in_duration)

# ============================================
# TRANSICIONES ESTILO FIRE EMBLEM
# ============================================

func wipe_transition(direction: TransitionType, duration: float = 1.0):
	"""Transición de barrido (wipe) en dirección especificada"""
	if is_transitioning:
		return
	
	is_transitioning = true
	transition_started.emit()
	
	var shader_material = create_wipe_shader(direction)
	transition_rect.material = shader_material
	transition_rect.visible = true
	
	var tween = create_tween()
	tween.tween_method(update_wipe_progress, 0.0, 1.0, duration)
	await tween.finished
	
	transition_midpoint.emit()
	is_transitioning = false
	transition_finished.emit()

func create_wipe_shader(direction: TransitionType) -> ShaderMaterial:
	"""Crea un shader material para wipe"""
	var shader_code = """
	shader_type canvas_item;
	
	uniform float progress : hint_range(0.0, 1.0) = 0.0;
	uniform int direction = 0; // 0=left, 1=right, 2=up, 3=down
	
	void fragment() {
		vec2 uv = UV;
		float threshold;
		
		if (direction == 0) { // Left
			threshold = uv.x;
		} else if (direction == 1) { // Right
			threshold = 1.0 - uv.x;
		} else if (direction == 2) { // Up
			threshold = uv.y;
		} else { // Down
			threshold = 1.0 - uv.y;
		}
		
		if (threshold < progress) {
			COLOR = vec4(0.0, 0.0, 0.0, 1.0);
		} else {
			discard;
		}
	}
	"""
	
	var shader = Shader.new()
	shader.code = shader_code
	
	var material = ShaderMaterial.new()
	material.shader = shader
	
	# Establecer dirección
	var dir_value = 0
	match direction:
		TransitionType.WIPE_LEFT: dir_value = 0
		TransitionType.WIPE_RIGHT: dir_value = 1
		TransitionType.WIPE_UP: dir_value = 2
		TransitionType.WIPE_DOWN: dir_value = 3
	
	material.set_shader_parameter("direction", dir_value)
	material.set_shader_parameter("progress", 0.0)
	
	return material

func update_wipe_progress(value: float):
	"""Actualiza el progreso del wipe"""
	if transition_rect.material is ShaderMaterial:
		transition_rect.material.set_shader_parameter("progress", value)

func circle_transition(closing: bool = true, duration: float = 1.0, center: Vector2 = Vector2(0.5, 0.5)):
	"""Transición circular (iris in/out) estilo Fire Emblem"""
	if is_transitioning:
		return
	
	is_transitioning = true
	transition_started.emit()
	
	var shader_material = create_circle_shader(center)
	transition_rect.material = shader_material
	transition_rect.visible = true
	
	var start_value = 0.0 if closing else 1.0
	var end_value = 1.0 if closing else 0.0
	
	var tween = create_tween()
	tween.tween_method(update_circle_progress, start_value, end_value, duration)
	await tween.finished
	
	if not closing:
		transition_rect.visible = false
	
	transition_midpoint.emit()
	is_transitioning = false
	transition_finished.emit()

func create_circle_shader(center: Vector2) -> ShaderMaterial:
	"""Crea shader para transición circular"""
	var shader_code = """
	shader_type canvas_item;
	
	uniform float progress : hint_range(0.0, 1.0) = 0.0;
	uniform vec2 center = vec2(0.5, 0.5);
	
	void fragment() {
		vec2 uv = UV;
		float dist = distance(uv, center);
		float max_dist = 0.7071; // Distancia máxima desde el centro
		
		if (dist > progress * max_dist) {
			COLOR = vec4(0.0, 0.0, 0.0, 1.0);
		} else {
			discard;
		}
	}
	"""
	
	var shader = Shader.new()
	shader.code = shader_code
	
	var material = ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("center", center)
	material.set_shader_parameter("progress", 0.0)
	
	return material

func update_circle_progress(value: float):
	"""Actualiza el progreso de la transición circular"""
	if transition_rect.material is ShaderMaterial:
		transition_rect.material.set_shader_parameter("progress", value)

# ============================================
# EFECTOS ESPECIALES
# ============================================

func battle_transition(duration: float = 0.8):
	"""Transición estilo inicio de batalla de Fire Emblem"""
	if is_transitioning:
		return
	
	is_transitioning = true
	transition_started.emit()
	
	# Efecto de líneas diagonales convergentes
	var shader_material = create_battle_shader()
	transition_rect.material = shader_material
	transition_rect.visible = true
	
	var tween = create_tween()
	tween.tween_method(update_battle_progress, 0.0, 1.0, duration)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	await tween.finished
	
	transition_midpoint.emit()
	is_transitioning = false
	transition_finished.emit()

func create_battle_shader() -> ShaderMaterial:
	"""Crea shader para transición de batalla"""
	var shader_code = """
	shader_type canvas_item;
	
	uniform float progress : hint_range(0.0, 1.0) = 0.0;
	uniform float line_width = 0.05;
	
	void fragment() {
		vec2 uv = UV;
		
		// Crear líneas diagonales
		float diagonal = (uv.x + uv.y) * 0.5;
		float line_pattern = abs(sin(diagonal * 20.0 + TIME * 5.0));
		
		if (line_pattern < progress || progress > 0.95) {
			COLOR = vec4(0.0, 0.0, 0.0, 1.0);
		} else {
			discard;
		}
	}
	"""
	
	var shader = Shader.new()
	shader.code = shader_code
	
	var material = ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("progress", 0.0)
	
	return material

func update_battle_progress(value: float):
	"""Actualiza progreso de transición de batalla"""
	if transition_rect.material is ShaderMaterial:
		transition_rect.material.set_shader_parameter("progress", value)

func flash_screen(color: Color = Color.WHITE, duration: float = 0.3, intensity: float = 1.0):
	"""Flash de pantalla (útil para impactos dramáticos)"""
	transition_rect.color = color
	transition_rect.modulate.a = intensity
	transition_rect.visible = true
	
	var tween = create_tween()
	tween.tween_property(transition_rect, "modulate:a", 0.0, duration)
	await tween.finished
	
	transition_rect.visible = false

func shake_screen(intensity: float = 20.0, duration: float = 0.5):
	"""Sacude la pantalla (para terremotos o impactos)"""
	var camera = get_viewport().get_camera_2d()
	if not camera:
		return
	
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
# TRANSICIONES COMBINADAS
# ============================================

func dramatic_scene_transition(scene_path: String):
	"""Transición dramática completa para cambio de escena importante"""
	# Flash blanco
	await flash_screen(Color.WHITE, 0.2, 0.8)
	
	# Shake
	shake_screen(15.0, 0.3)
	await get_tree().create_timer(0.1).timeout
	
	# Circle close
	await circle_transition(true, 0.8)
	
	# Cambiar escena
	get_tree().change_scene_to_file(scene_path)
	
	# Circle open
	await circle_transition(false, 0.8)

func battle_start_transition(scene_path: String):
	"""Transición específica para inicio de batalla"""
	await battle_transition(0.8)
	get_tree().change_scene_to_file(scene_path)
	await fade_in(0.5)

# ============================================
# UTILIDADES
# ============================================

func reset_transition():
	"""Resetea el estado de transición"""
	is_transitioning = false
	transition_rect.visible = false
	transition_rect.material = null
	transition_rect.modulate.a = 1.0

func is_busy() -> bool:
	"""Verifica si hay una transición en curso"""
	return is_transitioning
