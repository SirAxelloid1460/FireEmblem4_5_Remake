class_name FortuneTellerPanel
extends Panel

@onready var fortune_text: RichTextLabel = $VBoxContainer/FortuneText
@onready var close_button: Button = $VBoxContainer/CloseButton

func _ready():
	close_button.pressed.connect(_on_close_pressed)
	hide()

func show_fortune(unit: Unit):
	"""Muestra la fortuna de la unidad"""
	var fortune = generate_fortune(unit)
	fortune_text.text = fortune
	show()

func generate_fortune(unit: Unit) -> String:
	"""Genera una fortuna basada en las stats de la unidad"""
	var text = "[center][b]Fortuna de %s[/b][/center]\n\n" % unit.unit_name
	
	# Calcular "suerte" en combate
	var avg_hit = (unit.skill * 2 + unit.luck) / 2
	var avg_avoid = (unit.speed * 2 + unit.luck) / 2
	var avg_crit = unit.skill / 2
	
	text += "En combate:\n"
	text += "  Precisión promedio: ~%d%%\n" % avg_hit
	text += "  Evasión promedia: ~%d%%\n" % avg_avoid
	text += "  Crítico promedio: ~%d%%\n\n" % avg_crit
	
	# Predicción de nivel
	if unit.level < 20:
		var levels_to_promote = 20 - unit.level
		text += "Niveles hasta promoción: %d\n\n" % levels_to_promote
	else:
		text += "¡Listo para promoción!\n\n"

	# Tasas de crecimiento (portado de FortuneTellerMenu al unificar)
	var growths = get_growth_rates(unit.unit_class)
	text += "Tasas de crecimiento:\n"
	for stat_name in growths:
		text += "  %s: %d%%\n" % [stat_name, growths[stat_name]]
	text += "\n"

	# Mensaje místico
	var messages = [
		"Las estrellas predicen grandes batallas por delante...",
		"Tu destino está ligado a la espada...",
		"Veo valentía en tu futuro...",
		"Ten cuidado con los enemigos de lanza...",
		"La fortuna te sonríe en el campo de batalla..."
	]
	
	text += "[i]%s[/i]" % messages[randi() % messages.size()]
	
	return text

func get_growth_rates(unit_class: String) -> Dictionary:
	"""Tasas de crecimiento por clase (portado de FortuneTellerMenu)."""
	var growth_tables = {
		"Lord": {"HP": 80, "Fuerza": 50, "Magia": 30, "Habilidad": 50, "Velocidad": 50, "Suerte": 40, "Defensa": 30, "Resistencia": 20},
		"Knight": {"HP": 70, "Fuerza": 40, "Magia": 10, "Habilidad": 40, "Velocidad": 40, "Suerte": 30, "Defensa": 50, "Resistencia": 15},
		"Mage": {"HP": 50, "Fuerza": 10, "Magia": 60, "Habilidad": 50, "Velocidad": 40, "Suerte": 30, "Defensa": 20, "Resistencia": 50}
	}
	return growth_tables.get(unit_class, growth_tables["Knight"])

func _on_close_pressed():
	hide()

