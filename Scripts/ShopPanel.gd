extends Panel
class_name ShopPanel

# Referencias
@onready var item_list: ItemList = $VBoxContainer/ItemList
@onready var item_details: RichTextLabel = $VBoxContainer/ItemDetails
@onready var buy_button: Button = $VBoxContainer/ButtonContainer/BuyButton
@onready var close_button: Button = $VBoxContainer/ButtonContainer/CloseButton
@onready var gold_label: Label = $VBoxContainer/GoldLabel

# Estado
var available_items: Array[Dictionary] = []
var player_gold: int = 0
var current_unit: Unit = null
var selected_item_index: int = -1

# Señales
signal item_purchased(item: Item, cost: int)
signal shop_closed

func _ready():
	item_list.item_selected.connect(_on_item_selected)
	buy_button.pressed.connect(_on_buy_pressed)
	close_button.pressed.connect(_on_close_pressed)
	
	hide()

func open_shop(gold: int, unit: Unit = null):
	"""Abre la tienda con el oro disponible"""
	player_gold = gold
	current_unit = unit
	
	# Cargar items disponibles
	load_shop_inventory()
	
	# Actualizar UI
	update_item_list()
	update_gold_display()
	
	show()

func load_shop_inventory():
	"""Carga el inventario de la tienda según el capítulo"""
	available_items.clear()
	
	# Espadas
	available_items.append({
		"name": "Iron Sword",
		"type": "Weapon",
		"cost": 460,
		"description": "Espada básica de hierro\nMight: 5, Hit: 90, Wt: 5",
		"weapon_type": "Sword",
		"might": 5,
		"accuracy": 90,
		"weight": 5
	})
	
	available_items.append({
		"name": "Steel Sword",
		"type": "Weapon",
		"cost": 980,
		"description": "Espada de acero mejorada\nMight: 8, Hit: 85, Wt: 8",
		"weapon_type": "Sword",
		"might": 8,
		"accuracy": 85,
		"weight": 8
	})
	
	available_items.append({
		"name": "Silver Sword",
		"type": "Weapon",
		"cost": 2500,
		"description": "Espada de plata poderosa\nMight: 13, Hit: 80, Wt: 7",
		"weapon_type": "Sword",
		"might": 13,
		"accuracy": 80,
		"weight": 7
	})
	
	# Lanzas
	available_items.append({
		"name": "Iron Lance",
		"type": "Weapon",
		"cost": 360,
		"description": "Lanza básica de hierro\nMight: 6, Hit: 85, Wt: 7",
		"weapon_type": "Lance",
		"might": 6,
		"accuracy": 85,
		"weight": 7
	})
	
	available_items.append({
		"name": "Steel Lance",
		"type": "Weapon",
		"cost": 840,
		"description": "Lanza de acero mejorada\nMight: 9, Hit: 80, Wt: 10",
		"weapon_type": "Lance",
		"might": 9,
		"accuracy": 80,
		"weight": 10
	})
	
	# Hachas
	available_items.append({
		"name": "Iron Axe",
		"type": "Weapon",
		"cost": 270,
		"description": "Hacha básica de hierro\nMight: 7, Hit: 75, Wt: 9",
		"weapon_type": "Axe",
		"might": 7,
		"accuracy": 75,
		"weight": 9
	})
	
	available_items.append({
		"name": "Hand Axe",
		"type": "Weapon",
		"cost": 540,
		"description": "Hacha arrojadiza\nMight: 5, Hit: 70, Wt: 8, Rango: 1-2",
		"weapon_type": "Axe",
		"might": 5,
		"accuracy": 70,
		"weight": 8,
		"range_min": 1,
		"range_max": 2
	})
	
	# Arcos
	available_items.append({
		"name": "Iron Bow",
		"type": "Weapon",
		"cost": 560,
		"description": "Arco básico de hierro\nMight: 6, Hit: 85, Wt: 6, Rango: 2",
		"weapon_type": "Bow",
		"might": 6,
		"accuracy": 85,
		"weight": 6,
		"range_min": 2,
		"range_max": 2
	})
	
	# Magia
	available_items.append({
		"name": "Fire",
		"type": "Weapon",
		"cost": 630,
		"description": "Magia de fuego básica\nMight: 5, Hit: 90, Wt: 4",
		"weapon_type": "Anima",
		"might": 5,
		"accuracy": 90,
		"weight": 4,
		"is_magic": true
	})
	
	available_items.append({
		"name": "Thunder",
		"type": "Weapon",
		"cost": 970,
		"description": "Magia de trueno\nMight: 8, Hit: 80, Wt: 6",
		"weapon_type": "Anima",
		"might": 8,
		"accuracy": 80,
		"weight": 6,
		"is_magic": true
	})
	
	# Items curativos
	available_items.append({
		"name": "Vulnerary",
		"type": "Item",
		"cost": 300,
		"description": "Cura 10 HP\nUsos: 3",
		"heal_amount": 10,
		"uses": 3
	})
	
	available_items.append({
		"name": "Elixir",
		"type": "Item",
		"cost": 3000,
		"description": "Restaura toda la vida\nUsos: 1",
		"heal_amount": 99,
		"uses": 1
	})

func update_item_list():
	"""Actualiza la lista visual de items"""
	item_list.clear()
	
	for i in range(available_items.size()):
		var item = available_items[i]
		var text = "%s - %d G" % [item["name"], item["cost"]]
		
		item_list.add_item(text)
		
		# Colorear si no se puede comprar
		if item["cost"] > player_gold:
			item_list.set_item_custom_fg_color(i, Color(0.5, 0.5, 0.5))

func update_gold_display():
	"""Actualiza la visualización del oro"""
	gold_label.text = "Oro disponible: %d G" % player_gold

func _on_item_selected(index: int):
	"""Cuando se selecciona un item de la lista"""
	selected_item_index = index
	
	if index >= 0 and index < available_items.size():
		var item = available_items[index]
		show_item_details(item)
		
		# Habilitar/deshabilitar botón de compra
		buy_button.disabled = item["cost"] > player_gold

func show_item_details(item: Dictionary):
	"""Muestra los detalles del item seleccionado"""
	var details = "[b]%s[/b]\n" % item["name"]
	details += "Precio: %d G\n\n" % item["cost"]
	details += item["description"]
	
	item_details.text = details

func _on_buy_pressed():
	"""Cuando se presiona el botón de comprar"""
	if selected_item_index < 0:
		return
	
	var item_data = available_items[selected_item_index]
	
	# Verificar si se puede comprar
	if item_data["cost"] > player_gold:
		show_error("No tienes suficiente oro")
		return
	
	# Crear el item
	var item = create_item_from_data(item_data)
	
	if not item:
		show_error("Error al crear el item")
		return
	
	# Emitir señal de compra
	item_purchased.emit(item, item_data["cost"])
	
	# Actualizar oro local
	player_gold -= item_data["cost"]
	update_gold_display()
	update_item_list()
	
	show_success("¡%s comprado!" % item_data["name"])

func create_item_from_data(data: Dictionary) -> Item:
	"""Crea un objeto Item desde los datos de la tienda"""
	if data["type"] == "Weapon":
		var weapon = Weapon.new()
		weapon.weapon_name = data["name"]
		weapon.weapon_type = data["weapon_type"]
		weapon.might = data["might"]
		weapon.accuracy = data["accuracy"]
		weapon.weight = data["weight"]
		weapon.is_magic = data.get("is_magic", false)
		weapon.range_min = data.get("range_min", 1)
		weapon.range_max = data.get("range_max", 1)
		weapon.max_durability = 50
		weapon.current_durability = 50
		return weapon
	
	elif data["type"] == "Item":
		var item = Item.new()
		item.item_name = data["name"]
		item.heal_amount = data["heal_amount"]
		item.uses = data["uses"]
		return item
	
	return null

func show_error(message: String):
	"""Muestra un mensaje de error"""
	var popup = AcceptDialog.new()
	popup.dialog_text = message
	popup.title = "Error"
	add_child(popup)
	popup.popup_centered()

func show_success(message: String):
	"""Muestra un mensaje de éxito"""
	var popup = AcceptDialog.new()
	popup.dialog_text = message
	popup.title = "¡Éxito!"
	add_child(popup)
	popup.popup_centered()
	await popup.confirmed
	popup.queue_free()

func _on_close_pressed():
	"""Cierra la tienda"""
	shop_closed.emit()
	hide()
