extends Control
class_name PromotionScreen

# Referencias UI
@onready var bg_flash: ColorRect = $BackgroundFlash
@onready var character_sprite: Sprite2D = $CharacterSprite
@onready var old_class_label: Label = $OldClassLabel
@onready var new_class_label: Label = $NewClassLabel
@onready var arrow_label: Label = $ArrowLabel
@onready var stats_before: VBoxContainer = $StatsPanel/BeforeStats
@onready var stats_after: VBoxContainer = $StatsPanel/AfterStats
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var particles: CPUParticles2D = $Particles

# Configuración
@export var flash_color: Color = Color(1, 1, 1, 0.8)
@export var promotion_duration: float = 4.0

# Estado
var unit_data: Dictionary = {}
var old_stats: Dictionary = {}
var new_stats: Dictionary = {}
var is_animating: bool = false

# Señales
signal promotion_complete

func _ready():
	hide()
	modulate.a = 0

# ============================================
# MOSTRAR PROMOCIÓN
# ============================================

func show_promotion(unit: Unit, old_class: String, new_class: String, stat_bonuses: Dictionary):
	"""
	Muestra la pantalla de promoción con animación completa.
	
	Parámetros:
	- unit: La unidad que se promociona
	- old_class: Nombre de la clase anterior
	- new_class: Nombre de la nueva clase
	- stat_bonuses: Dictionary con los bonuses {stat_name: bonus}
	  Ejemplo: {"hp": 3, "str": 2, "spd": 2}
	"""
	
	# Guardar datos
	unit_data = {
		"name": unit.unit_name,
		"sprite_path": unit.get("sprite_path") if "sprite_path" in unit else "",
		"portrait": unit.get("portrait_path") if "portrait_path" in unit else ""
	}
	
	# Guardar stats antes/después
	old_stats = {
		"hp": unit.max_hp - stat_bonuses.get("hp", 0),
		"str": unit.strength - stat_bonuses.get("str", 0),
		"mag": unit.magic - stat_bonuses.get("mag", 0),
		"skl": unit.skill - stat_bonuses.get("skl", 0),
		"spd": unit.speed - stat_bonuses.get("spd", 0),
		"lck": unit.luck - stat_bonuses.get("lck", 0),
		"def": unit.defense - stat_bonuses.get("def", 0),
		"res": unit.resistance - stat_bonuses.get("res", 0)
	}
	
	new_stats = {
		"hp": unit.max_hp,
		"str": unit.strength,
		"mag": unit.magic,
		"skl": unit.skill,
		"spd": unit.speed,
		"lck": unit.luck,
		"def": unit.defense,
		"res": unit.resistance
	}
	
	# Configurar labels de clase
	old_class_label.text = old_class
	new_class_label.text = new_class
	
	# Mostrar
	show()
	is_animating = true
	
	await animate_promotion()
	
	is_animating = false
	promotion_complete.emit()

# ============================================
# ANIMACIÓN PRINCIPAL
# ============================================

func animate_promotion():
	"""Secuencia completa de animación de promoción"""
	
	# 1. Fade in inicial
	await fade_in()
	
	# 2. Mostrar clase antigua
	await show_old_class()
	
	# 3. Flash brillante + transformación
	await transformation_sequence()
	
	# 4. Mostrar nueva clase
	await show_new_class()
	
	# 5. Mostrar comparación de stats
	await show_stat_comparison()
	
	# 6. Esperar y fade out
	await get_tree().create_timer(2.0).timeout
	await fade_out()
	
	hide()

func fade_in():
	"""Fade in inicial"""
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.5)
	await tween.finished

func fade_out():
	"""Fade out final"""
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	await tween.finished

func show_old_class():
	"""Muestra la clase antigua"""
	old_class_label.modulate.a = 0
	old_class_label.position.y += 50
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(old_class_label, "modulate:a", 1.0, 0.5)
	tween.tween_property(old_class_label, "position:y", old_class_label.position.y - 50, 0.5)
	
	await tween.finished
	await get_tree().create_timer(1.0).timeout

func transformation_sequence():
	"""Secuencia de transformación con efectos"""
	
	# Flash blanco brillante
	bg_flash.color = flash_color
	bg_flash.modulate.a = 0
	
	var flash_tween = create_tween()
	flash_tween.tween_property(bg_flash, "modulate:a", 1.0, 0.2)
	await flash_tween.finished
	
	# Iniciar partículas
	start_particles()
	
	# Hacer desaparecer clase antigua
	var fade_old = create_tween()
	fade_old.tween_property(old_class_label, "modulate:a", 0.0, 0.3)
	
	# Shake del personaje (si existe)
	if character_sprite.texture:
		await shake_character()
	
	# Flash fade out
	var flash_out = create_tween()
	flash_out.tween_property(bg_flash, "modulate:a", 0.0, 0.5)
	
	await flash_out.finished

func show_new_class():
	"""Muestra la nueva clase con efecto dramático"""
	# Mostrar flecha de promoción
	arrow_label.text = "→"
	arrow_label.modulate.a = 0
	arrow_label.scale = Vector2.ZERO
	
	var arrow_tween = create_tween()
	arrow_tween.set_parallel(true)
	arrow_tween.set_trans(Tween.TRANS_BACK)
	arrow_tween.set_ease(Tween.EASE_OUT)
	arrow_tween.tween_property(arrow_label, "modulate:a", 1.0, 0.3)
	arrow_tween.tween_property(arrow_label, "scale", Vector2.ONE, 0.5)
	
	await arrow_tween.finished
	
	# Mostrar nueva clase
	new_class_label.modulate.a = 0
	new_class_label.scale = Vector2(1.5, 1.5)
	
	var class_tween = create_tween()
	class_tween.set_parallel(true)
	class_tween.set_trans(Tween.TRANS_CUBIC)
	class_tween.set_ease(Tween.EASE_OUT)
	class_tween.tween_property(new_class_label, "modulate:a", 1.0, 0.5)
	class_tween.tween_property(new_class_label, "scale", Vector2.ONE, 0.5)
	
	# Sonido de promoción
	play_promotion_sound()
	
	await class_tween.finished
	await get_tree().create_timer(1.0).timeout

func show_stat_comparison():
	"""Muestra la comparación de stats antes/después"""
	# Limpiar containers
	for child in stats_before.get_children():
		child.queue_free()
	for child in stats_after.get_children():
		child.queue_free()
	
	# Crear títulos
	var before_title = Label.new()
	before_title.text = "Antes"
	before_title.add_theme_font_size_override("font_size", 24)
	before_title.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	stats_before.add_child(before_title)
	
	var after_title = Label.new()
	after_title.text = "Después"
	after_title.add_theme_font_size_override("font_size", 24)
	after_title.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
	stats_after.add_child(after_title)
	
	# Añadir stats
	var stat_names = ["HP", "Str", "Mag", "Skl", "Spd", "Lck", "Def", "Res"]
	var stat_keys = ["hp", "str", "mag", "skl", "spd", "lck", "def", "res"]
	
	for i in range(stat_names.size()):
		var stat_name = stat_names[i]
		var stat_key = stat_keys[i]
		
		# Antes
		var before_label = create_stat_label(stat_name, old_stats[stat_key])
		stats_before.add_child(before_label)
		
		# Después
		var after_value = new_stats[stat_key]
		var bonus = after_value - old_stats[stat_key]
		var after_label = create_stat_label_with_bonus(stat_name, after_value, bonus)
		stats_after.add_child(after_label)
		
		# Animar aparición
		before_label.modulate.a = 0
		after_label.modulate.a = 0
		
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(before_label, "modulate:a", 1.0, 0.2)
		tween.tween_property(after_label, "modulate:a", 1.0, 0.2)
		
		await tween.finished
		await get_tree().create_timer(0.1).timeout

func create_stat_label(stat_name: String, value: int) -> Label:
	"""Crea un label simple de stat"""
	var label = Label.new()
	label.text = "%s: %d" % [stat_name, value]
	label.add_theme_font_size_override("font_size", 20)
	return label

func create_stat_label_with_bonus(stat_name: String, value: int, bonus: int) -> Label:
	"""Crea un label de stat con indicador de bonus"""
	var label = Label.new()
	if bonus > 0:
		label.text = "%s: %d (+%d)" % [stat_name, value, bonus]
		label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
	else:
		label.text = "%s: %d" % [stat_name, value]
	
	label.add_theme_font_size_override("font_size", 20)
	return label

# ============================================
# EFECTOS VISUALES
# ============================================

func start_particles():
	"""Inicia el sistema de partículas"""
	if not particles:
		return
	
	particles.emitting = true
	particles.amount = 50
	particles.lifetime = 1.0
	particles.gravity = Vector2(0, -100)
	
	# Configurar aspecto de partículas
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color(1, 1, 0.5, 1))
	gradient.add_point(1.0, Color(1, 0.5, 0, 0))
	
	particles.color_ramp = gradient
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 4.0

func shake_character():
	"""Hace temblar el sprite del personaje"""
	if not character_sprite:
		return
	
	var original_pos = character_sprite.position
	var shake_intensity = 10.0
	var shake_duration = 0.5
	var shake_count = int(shake_duration / 0.05)
	
	for i in range(shake_count):
		character_sprite.position = original_pos + Vector2(
			randf_range(-shake_intensity, shake_intensity),
			randf_range(-shake_intensity, shake_intensity)
		)
		await get_tree().create_timer(0.05).timeout
	
	character_sprite.position = original_pos

# ============================================
# SONIDOS
# ============================================

func play_promotion_sound():
	"""Reproduce el sonido de promoción"""
	# TODO: Cargar y reproducir sonido
	# var sfx = AudioStreamPlayer.new()
	# sfx.stream = preload("res://assets/GBA/audio/sfx/promotion.wav")
	# add_child(sfx)
	# sfx.play()
	pass

# ============================================
# INPUT
# ============================================

func _input(event):
	"""Permite saltar la animación"""
	if not is_animating:
		return
	
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
		skip_animation()

func skip_animation():
	"""Salta la animación"""
	if not is_animating:
		return
	
	# Detener todos los tweens
	for tween in get_tree().get_nodes_in_group("promotion_tweens"):
		if tween != null and tween.has_method("kill"):
			tween.kill()
	
	is_animating = false
	modulate.a = 0
	hide()
	promotion_complete.emit()
