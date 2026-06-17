class_name PromotionPanel
extends Panel

@onready var before_stats: VBoxContainer = $HBoxContainer/BeforeStats
@onready var after_stats: VBoxContainer = $HBoxContainer/AfterStats
@onready var promote_button: Button = $VBoxContainer/PromoteButton
@onready var cancel_button: Button = $VBoxContainer/CancelButton

var current_unit: Unit = null
var promotion_data: Dictionary = {}

signal promotion_completed(old_class: String, new_class: String)

func _ready():
	promote_button.pressed.connect(_on_promote_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)
	hide()

func start_promotion(unit: Unit):
	"""Inicia el proceso de promoción"""
	current_unit = unit
	
	# Obtener datos de promoción
	promotion_data = get_promotion_data(unit.unit_class)
	
	if promotion_data.is_empty():
		return
	
	show_promotion_preview()
	show()

func get_promotion_data(base_class: String) -> Dictionary:
	"""Datos de promoción — fuente única: PromotionSystem (sin tabla duplicada).
	Remapea el formato {promoted_class, bonuses:{...}} al formato plano que
	usa este panel ({new_class, hp, str, ...})."""
	var data = PromotionSystem.get_promotion_data(base_class)
	if data.is_empty():
		return {}
	var flat := {"new_class": data["promoted_class"]}
	for k in data["bonuses"]:
		flat[k] = data["bonuses"][k]
	return flat

func show_promotion_preview():
	"""Muestra preview de stats antes/después"""
	# Limpiar
	for child in before_stats.get_children():
		child.queue_free()
	for child in after_stats.get_children():
		child.queue_free()
	
	# Antes
	var before_title = Label.new()
	before_title.text = "[b]Antes: %s[/b]" % current_unit.unit_class
	before_title.add_theme_font_size_override("font_size", 20)
	before_stats.add_child(before_title)
	
	add_stat_label(before_stats, "HP: %d" % current_unit.max_hp)
	add_stat_label(before_stats, "Str: %d" % current_unit.strength)
	add_stat_label(before_stats, "Skl: %d" % current_unit.skill)
	add_stat_label(before_stats, "Spd: %d" % current_unit.speed)
	add_stat_label(before_stats, "Def: %d" % current_unit.defense)
	add_stat_label(before_stats, "Res: %d" % current_unit.resistance)
	
	# Después
	var after_title = Label.new()
	after_title.text = "[b]Después: %s[/b]" % promotion_data["new_class"]
	after_title.add_theme_font_size_override("font_size", 20)
	after_stats.add_child(after_title)
	
	add_stat_label(after_stats, "HP: %d (+%d)" % [current_unit.max_hp + promotion_data["hp"], promotion_data["hp"]], Color.GREEN)
	add_stat_label(after_stats, "Str: %d (+%d)" % [current_unit.strength + promotion_data["str"], promotion_data["str"]], Color.GREEN)
	add_stat_label(after_stats, "Skl: %d (+%d)" % [current_unit.skill + promotion_data["skl"], promotion_data["skl"]], Color.GREEN)
	add_stat_label(after_stats, "Spd: %d (+%d)" % [current_unit.speed + promotion_data["spd"], promotion_data["spd"]], Color.GREEN)
	add_stat_label(after_stats, "Def: %d (+%d)" % [current_unit.defense + promotion_data["def"], promotion_data["def"]], Color.GREEN)
	add_stat_label(after_stats, "Res: %d (+%d)" % [current_unit.resistance + promotion_data["res"], promotion_data["res"]], Color.GREEN)

func add_stat_label(container: VBoxContainer, text: String, color: Color = Color.WHITE):
	var label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	container.add_child(label)

func _on_promote_pressed():
	"""Promociona la unidad"""
	var old_class = current_unit.unit_class
	
	# Aplicar bonuses
	current_unit.unit_class = promotion_data["new_class"]
	current_unit.max_hp += promotion_data["hp"]
	current_unit.current_hp = current_unit.max_hp
	current_unit.strength += promotion_data["str"]
	current_unit.magic += promotion_data["mag"]
	current_unit.skill += promotion_data["skl"]
	current_unit.speed += promotion_data["spd"]
	current_unit.luck += promotion_data["lck"]
	current_unit.defense += promotion_data["def"]
	current_unit.resistance += promotion_data["res"]
	current_unit.level = 1  # Resetear a nivel 1
	
	promotion_completed.emit(old_class, promotion_data["new_class"])
	hide()

func _on_cancel_pressed():
	hide()
