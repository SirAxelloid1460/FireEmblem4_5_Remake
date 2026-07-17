extends Control
class_name LevelUpScreen

# Referencias UI
@onready var character_portrait: TextureRect = $Panel/CharacterPortrait
@onready var character_name: Label = $Panel/CharacterName
@onready var level_label: Label = $Panel/LevelLabel
@onready var stats_container: VBoxContainer = $Panel/StatsContainer
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var sfx_player: AudioStreamPlayer = $SFXPlayer

# Configuración
@export var stat_reveal_delay: float = 0.15
@export var total_display_time: float = 3.0

# Estado
var unit_data: Dictionary = {}
var stat_gains: Dictionary = {}
var is_animating: bool = false

# Señales
signal level_up_complete

# Colores
const STAT_GAIN_COLOR = Color(0.3, 1.0, 0.3)  # Verde brillante
const STAT_NO_GAIN_COLOR = Color(0.7, 0.7, 0.7)  # Gris
const LEVEL_UP_COLOR = Color(1.0, 0.9, 0.5)  # Dorado

func _ready():
	hide()
	modulate.a = 0

# ============================================
# MOSTRAR LEVEL UP
# ============================================

func show_level_up(unit: Unit, gains: Dictionary):
	"""
	Muestra la pantalla de level up con las ganancias de stats.
	
	Parámetros:
	- unit: La unidad que subió de nivel
	- gains: Dictionary con las ganancias {stat_name: gain_amount}
	  Ejemplo: {"hp": 1, "str": 1, "spd": 0, "def": 1}
	"""
	
	# Guardar datos
	unit_data = {
		"name": unit.unit_name,
		"class": unit.unit_class,
		"level": unit.level,
		"portrait": str(unit.portrait_path) if "portrait_path" in unit else ""
	}
	stat_gains = gains
	
	# Configurar UI
	setup_display()
	
	# Mostrar con animación
	show()
	is_animating = true
	
	await animate_level_up()
	
	is_animating = false
	level_up_complete.emit()

func setup_display():
	"""Configura la información básica del display"""
	# Nombre y clase
	character_name.text = "%s" % unit_data["name"]
	character_name.add_theme_color_override("font_color", LEVEL_UP_COLOR)
	
	# Nivel
	level_label.text = "Level %d" % unit_data["level"]
	level_label.add_theme_color_override("font_color", LEVEL_UP_COLOR)
	
	# Retrato (si existe)
	if unit_data["portrait"] != "":
		if FileAccess.file_exists(unit_data["portrait"]):
			character_portrait.texture = load(unit_data["portrait"])
	
	# Limpiar stats container
	for child in stats_container.get_children():
		child.queue_free()

# ============================================
# ANIMACIONES
# ============================================

func animate_level_up():
	"""Anima la secuencia completa de level up"""
	
	# 1. Fade in del panel
	await fade_in_panel()
	
	# 2. Mostrar "LEVEL UP!"
	await show_level_up_text()
	
	# 3. Revelar stats una por una
	await reveal_stat_gains()
	
	# 4. Esperar antes de cerrar
	await get_tree().create_timer(total_display_time).timeout
	
	# 5. Fade out
	await fade_out_panel()
	
	hide()

func fade_in_panel():
	"""Fade in del panel completo"""
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 1.0, 0.3)
	await tween.finished

func fade_out_panel():
	"""Fade out del panel"""
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	await tween.finished

func show_level_up_text():
	"""Muestra el texto 'LEVEL UP!' con efecto"""
	var level_up_label = Label.new()
	level_up_label.text = "LEVEL UP!"
	level_up_label.add_theme_font_size_override("font_size", 48)
	level_up_label.add_theme_color_override("font_color", LEVEL_UP_COLOR)
	level_up_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	$Panel.add_child(level_up_label)
	level_up_label.position = Vector2(
		$Panel.size.x / 2 - 150,
		50
	)
	
	# Efecto de escala
	level_up_label.scale = Vector2.ZERO
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(level_up_label, "scale", Vector2.ONE, 0.5)
	
	# Sonido
	play_level_up_sound()
	
	await tween.finished
	await get_tree().create_timer(0.5).timeout
	
	# Remover el label
	level_up_label.queue_free()

func reveal_stat_gains():
	"""Revela las ganancias de stats una por una"""
	var stat_names = ["HP", "Str", "Mag", "Skl", "Spd", "Lck", "Def", "Res"]
	var stat_keys = ["hp", "str", "mag", "skl", "spd", "lck", "def", "res"]
	
	for i in range(stat_names.size()):
		var stat_name = stat_names[i]
		var stat_key = stat_keys[i]
		var gain = stat_gains.get(stat_key, 0)
		
		# Crear línea de stat
		var stat_line = create_stat_line(stat_name, gain)
		stats_container.add_child(stat_line)
		
		# Animación de aparición
		stat_line.modulate.a = 0
		stat_line.position.x = -20
		
		var tween = create_tween()
		tween.set_parallel(true)
		tween.set_trans(Tween.TRANS_CUBIC)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(stat_line, "modulate:a", 1.0, 0.2)
		tween.tween_property(stat_line, "position:x", 0, 0.2)
		
		# Sonido si hubo ganancia
		if gain > 0:
			play_stat_gain_sound()
		
		await tween.finished
		await get_tree().create_timer(stat_reveal_delay).timeout

func create_stat_line(stat_name: String, gain: int) -> HBoxContainer:
	"""Crea una línea visual para una stat"""
	var container = HBoxContainer.new()
	container.add_theme_constant_override("separation", 20)
	
	# Nombre de la stat
	var name_label = Label.new()
	name_label.text = stat_name
	name_label.custom_minimum_size = Vector2(80, 0)
	name_label.add_theme_font_size_override("font_size", 24)
	container.add_child(name_label)
	
	# Ganancia
	var gain_label = Label.new()
	if gain > 0:
		gain_label.text = "+%d" % gain
		gain_label.add_theme_color_override("font_color", STAT_GAIN_COLOR)
		
		# Efecto de brillo para ganancias
		var tween = create_tween()
		tween.set_loops()
		tween.tween_property(gain_label, "modulate:a", 0.7, 0.5)
		tween.tween_property(gain_label, "modulate:a", 1.0, 0.5)
	else:
		gain_label.text = "--"
		gain_label.add_theme_color_override("font_color", STAT_NO_GAIN_COLOR)
	
	gain_label.add_theme_font_size_override("font_size", 24)
	container.add_child(gain_label)
	
	return container

# ============================================
# SONIDOS
# ============================================

func play_level_up_sound():
	"""Reproduce el sonido de level up"""
	# TODO: Cargar y reproducir tu sonido de level up
	# sfx_player.stream = preload("res://assets/audio/sfx/level_up.wav")
	# sfx_player.play()
	pass

func play_stat_gain_sound():
	"""Reproduce el sonido de ganancia de stat"""
	# TODO: Cargar y reproducir tu sonido de stat gain
	# sfx_player.stream = preload("res://assets/audio/sfx/stat_gain.wav")
	# sfx_player.play()
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
	"""Salta la animación y cierra inmediatamente"""
	if not is_animating:
		return
	
	# Detener todos los tweens
	for tween in get_tree().get_nodes_in_group("level_up_tweens"):
		if tween != null and tween.has_method("kill"):
			tween.kill()
	
	is_animating = false
	modulate.a = 0
	hide()
	level_up_complete.emit()


# ============================================
# UTILIDADES ESTÁTICAS
# ============================================

static func calculate_stat_gains(unit: Unit, growth_rates: Dictionary) -> Dictionary:
	"""
	Calcula las ganancias de stats al subir de nivel basado en tasas de crecimiento.
	
	Parámetros:
	- unit: La unidad que sube de nivel
	- growth_rates: Dictionary con las tasas de crecimiento (0-100)
	  Ejemplo: {"hp": 80, "str": 50, "spd": 60}
	
	Aplica los siguientes modificadores antes del roll:
	- growth_change de skills activas (Elite +10 a todas; scrolls de sangre
	  como Baldr/Sety/… mientras se portan; etc.), sumado a cada growth.
	
	Retorna:
	- Dictionary con las ganancias {stat_name: 0 o 1}
	"""
	var effective_rates := growth_rates.duplicate()

	# growth_change de skills activas: Elite (+10 todos), scrolls de sangre
	# (Baldr/Sety/…) mientras se portan, etc.  ADITIVO al rate (ej. STR 50 →
	# 60), no multiplicativo, igual que LT.  Las claves del skill son en
	# mayúsculas (STR); las del rate en minúsculas (str).
	var growth_key := {
		"HP": "hp", "STR": "str", "MAG": "mag", "SKL": "skl",
		"SPD": "spd", "LCK": "lck", "DEF": "def", "RES": "res",
	}
	if unit != null and unit.has_method("get_growth_bonuses"):
		var bonuses: Dictionary = unit.get_growth_bonuses()
		for up in bonuses:
			var lo: String = growth_key.get(up, "")
			if lo != "" and effective_rates.has(lo):
				effective_rates[lo] = int(effective_rates[lo]) + int(bonuses[up])

	var gains := {}
	for stat in effective_rates.keys():
		var growth_rate: int = int(effective_rates[stat])
		# Cap a 100 para evitar ganancia garantizada en stats > 100 % real.
		# (En FE clásico growths > 100 dan stat doble; aquí simplificamos.)
		if growth_rate >= 100:
			gains[stat] = 1
			continue
		if growth_rate <= 0:
			gains[stat] = 0
			continue
		var roll := randi() % 100
		gains[stat] = 1 if roll < growth_rate else 0
	
	return gains

static func apply_stat_gains(unit: Unit, gains: Dictionary):
	"""Aplica las ganancias de stats a la unidad"""
	unit.max_hp += gains.get("hp", 0)
	unit.current_hp += gains.get("hp", 0)  # También curar el HP ganado
	unit.strength += gains.get("str", 0)
	unit.magic += gains.get("mag", 0)
	unit.skill += gains.get("skl", 0)
	unit.speed += gains.get("spd", 0)
	unit.luck += gains.get("lck", 0)
	unit.defense += gains.get("def", 0)
	unit.resistance += gains.get("res", 0)
