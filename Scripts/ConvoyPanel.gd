class_name ConvoyPanel
extends Panel

@onready var convoy_list: ItemList = $HBoxContainer/ConvoyList
@onready var unit_inventory: ItemList = $HBoxContainer/UnitInventory
@onready var take_button: Button = $VBoxContainer/TakeButton
@onready var store_button: Button = $VBoxContainer/StoreButton
@onready var close_button: Button = $VBoxContainer/CloseButton

var convoy_items: Array[Item] = []
var current_unit: Unit = null

signal item_transferred(from_convoy: bool, item: Item)

func _ready():
	take_button.pressed.connect(_on_take_pressed)
	store_button.pressed.connect(_on_store_pressed)
	close_button.pressed.connect(_on_close_pressed)
	hide()

func open_convoy(items: Array[Item], unit: Unit):
	"""Abre el convoy con los items disponibles"""
	convoy_items = items
	current_unit = unit
	
	update_lists()
	show()

func update_lists():
	"""Actualiza ambas listas de items"""
	# Convoy
	convoy_list.clear()
	for item in convoy_items:
		var text = item.item_name
		if "current_durability" in item:
			text += " (%d/%d)" % [item.current_durability, item.max_durability]
		convoy_list.add_item(text)
	
	# Inventario de unidad
	unit_inventory.clear()
	if current_unit:
		for item in current_unit.inventory:
			var text = item.item_name
			if item is Weapon:
				text += " (%d/%d)" % [item.current_durability, item.max_durability]
			unit_inventory.add_item(text)

func _on_take_pressed():
	"""Toma un item del convoy"""
	var selected = convoy_list.get_selected_items()
	if selected.size() == 0:
		return
	
	if not current_unit:
		return
	
	if current_unit.inventory.size() >= 5:
		show_error("Inventario lleno")
		return
	
	var item = convoy_items[selected[0]]
	item_transferred.emit(true, item)
	update_lists()

func _on_store_pressed():
	"""Guarda un item en el convoy"""
	var selected = unit_inventory.get_selected_items()
	if selected.size() == 0:
		return
	
	if not current_unit:
		return
	
	var item = current_unit.inventory[selected[0]]
	item_transferred.emit(false, item)
	update_lists()

func _on_close_pressed():
	hide()

func show_error(msg: String):
	var popup = AcceptDialog.new()
	popup.dialog_text = msg
	add_child(popup)
	popup.popup_centered()

