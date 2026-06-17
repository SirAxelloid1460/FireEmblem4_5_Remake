class_name BlacksmithPanel
extends Panel

@onready var weapon_list: ItemList = $VBoxContainer/WeaponList
@onready var cost_label: Label = $VBoxContainer/CostLabel
@onready var repair_button: Button = $VBoxContainer/RepairButton
@onready var close_button: Button = $VBoxContainer/CloseButton

var current_unit: Unit = null
var player_gold: int = 0
var selected_weapon: Weapon = null

signal weapon_repaired(weapon: Weapon, cost: int)

func _ready():
	weapon_list.item_selected.connect(_on_weapon_selected)
	repair_button.pressed.connect(_on_repair_pressed)
	close_button.pressed.connect(_on_close_pressed)
	hide()

func open_blacksmith(unit: Unit, gold: int):
	"""Abre la herrería"""
	current_unit = unit
	player_gold = gold
	
	update_weapon_list()
	show()

func update_weapon_list():
	"""Actualiza la lista de armas"""
	weapon_list.clear()
	
	if not current_unit:
		return
	
	# Añadir arma equipada
	if current_unit.weapon:
		add_weapon_to_list(current_unit.weapon)
	
	# Añadir armas del inventario
	for item in current_unit.inventory:
		if item is Weapon:
			add_weapon_to_list(item)

func add_weapon_to_list(weapon: Weapon):
	"""Añade un arma a la lista"""
	var durability_percent = float(weapon.current_durability) / float(weapon.max_durability)
	var text = "%s (%d/%d)" % [weapon.weapon_name, weapon.current_durability, weapon.max_durability]
	
	weapon_list.add_item(text)
	
	var idx = weapon_list.item_count - 1
	
	# Colorear según durabilidad
	if durability_percent >= 1.0:
		weapon_list.set_item_custom_fg_color(idx, Color.GREEN)
	elif durability_percent < 0.3:
		weapon_list.set_item_custom_fg_color(idx, Color.RED)

func _on_weapon_selected(index: int):
	"""Cuando se selecciona un arma"""
	# Obtener arma seleccionada
	var weapons = []
	if current_unit.weapon:
		weapons.append(current_unit.weapon)
	for item in current_unit.inventory:
		if item is Weapon:
			weapons.append(item)
	
	if index >= 0 and index < weapons.size():
		selected_weapon = weapons[index]
		
		# Calcular costo
		var cost = calculate_repair_cost(selected_weapon)
		cost_label.text = "Costo: %d G" % cost
		
		repair_button.disabled = cost > player_gold or selected_weapon.current_durability == selected_weapon.max_durability

func calculate_repair_cost(weapon: Weapon) -> int:
	"""Calcula el costo de reparar un arma"""
	var missing_durability = weapon.max_durability - weapon.current_durability
	return missing_durability * 10

func _on_repair_pressed():
	"""Repara el arma seleccionada"""
	if not selected_weapon:
		return
	
	var cost = calculate_repair_cost(selected_weapon)
	
	if cost > player_gold:
		return
	
	weapon_repaired.emit(selected_weapon, cost)
	update_weapon_list()
	cost_label.text = "¡Reparado!"

func _on_close_pressed():
	hide()

