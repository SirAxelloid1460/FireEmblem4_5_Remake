extends Control
class_name CastleBase

# Referencias a nodos UI
@onready var unit_list: ItemList = $MarginContainer/HBoxContainer/LeftPanel/UnitList
@onready var unit_details_panel: Panel = $MarginContainer/HBoxContainer/CenterPanel/UnitDetailsPanel
@onready var facility_panel: Panel = $MarginContainer/HBoxContainer/RightPanel/FacilityPanel
@onready var gold_label: Label = $MarginContainer/HBoxContainer/LeftPanel/GoldLabel
@onready var animation_player: AnimationPlayer = $AnimationPlayer

# Paneles de facilidades — las clases *Panel ya existen como class_name (ConvoyPanel,
# BlacksmithPanel, FortuneTellerPanel, PromotionPanel, ShopPanel, ArenaPanel). Estos nodos
# placeholder de castle_base.tscn aún deben construir su estructura interna y tener el
# script asignado para quedar tipados/funcionales. (Set *Menu redundante movido a docs/_deprecated/.)
@onready var shop_panel = $ShopPanel
@onready var convoy_panel = get_node_or_null("ConvoyPanel")
@onready var arena_panel = get_node_or_null("ArenaPanel")
@onready var blacksmith_panel = get_node_or_null("BlacksmithPanel")
@onready var fortune_teller_panel = get_node_or_null("FortuneTellerPanel")
@onready var promotion_panel = get_node_or_null("PromotionPanel")

# Estado del juego
var player_units: Array[Unit] = []
var selected_unit: Unit = null
var army_gold: int = 5000
var convoy_items: Array[Item] = []
var current_chapter: int = 1

# Configuración
@export var next_battle_scene: String = "res://Scenes/battle.tscn"
@export var allow_saving: bool = true

# Señales
signal preparation_complete
signal unit_selected(unit: Unit)
signal facility_opened(facility_name: String)

func _ready():
	setup_ui()
	hide_all_facility_panels()
	load_player_army()
	
	# Activar el ConvoySystem central — el convoy solo es accesible aquí
	# (decisión Fase 1: solo en castillo).
	var convoy := _get_convoy()
	if convoy != null:
		convoy.enter_castle()
		# Sincronizar la lista local con el convoy compartido.
		convoy_items.clear()
		for it in convoy.get_accessible():
			convoy_items.append(it)
	
	update_unit_list()
	update_gold_display()
	
	# Reproducir música de preparación
	play_preparation_music()


## Resuelve la referencia al ConvoySystem (autoload o hijo del root).
## Devuelve null si no se encuentra — la lógica antigua basada en
## convoy_items local sigue funcionando como fallback.
func _get_convoy() -> ConvoySystem:
	var node := get_tree().get_root().get_node_or_null("Convoy")
	if node and node is ConvoySystem:
		return node
	return null


## Llamar al salir del castillo a iniciar batalla.  Bloquea el acceso
## al convoy mientras la unidad está en el mapa.
func _leave_castle() -> void:
	var convoy := _get_convoy()
	if convoy != null:
		convoy.leave_castle()

# ============================================
# INICIALIZACIÓN
# ============================================

func setup_ui():
	"""Configura la interfaz del castillo"""
	# Conectar señales de la lista de unidades
	unit_list.item_selected.connect(_on_unit_selected)
	
	# Configurar botones de facilidades
	setup_facility_buttons()

func setup_facility_buttons():
	"""Configura los botones de las facilidades del castillo"""
	# Estos botones estarían en FacilityPanel
	var facilities = {
		"Shop": _on_shop_button_pressed,
		"Convoy": _on_convoy_button_pressed,
		"Arena": _on_arena_button_pressed,
		"Blacksmith": _on_blacksmith_button_pressed,
		"Fortune": _on_fortune_teller_button_pressed,
		"Promote": _on_promotion_button_pressed,
		"Manage": _on_manage_button_pressed,
		"Save": _on_save_button_pressed,
		"StartBattle": _on_start_battle_button_pressed
	}
	
	# Conectar botones (asume que existen en FacilityPanel)
	for button_name in facilities.keys():
		var button = facility_panel.get_node_or_null(button_name + "Button")
		if button:
			button.pressed.connect(facilities[button_name])

func load_player_army():
	"""Carga el ejército del jugador desde el estado del juego"""
	# Esto debería cargar desde tu GameManager o SaveSystem
	# Por ahora, crear unidades de ejemplo
	
	var unit1 = Unit.new()
	unit1.unit_name = "Sigurd"
	unit1.unit_class = "Lord"
	unit1.level = 5
	unit1.max_hp = 28
	unit1.current_hp = 28
	unit1.strength = 12
	unit1.skill = 10
	unit1.speed = 11
	unit1.defense = 8
	unit1.resistance = 3
	unit1.movement = 7
	
	var unit2 = Unit.new()
	unit2.unit_name = "Arden"
	unit2.unit_class = "Armor Knight"
	unit2.level = 3
	unit2.max_hp = 25
	unit2.current_hp = 20
	unit2.strength = 10
	unit2.skill = 5
	unit2.speed = 3
	unit2.defense = 12
	unit2.resistance = 1
	unit2.movement = 4
	
	player_units.append(unit1)
	player_units.append(unit2)
	
	# Cargar convoy inicial
	load_convoy_items()

func load_convoy_items():
	"""Carga los items del convoy del ejército"""
	# Aquí cargarías items guardados
	# Por ahora, algunos items de ejemplo
	var iron_sword = Weapon.new()
	iron_sword.weapon_name = "Iron Sword"
	iron_sword.weapon_type = "Sword"
	iron_sword.might = 5
	iron_sword.accuracy = 90
	
	convoy_items.append(iron_sword)

# ============================================
# ACTUALIZACIÓN DE UI
# ============================================

func update_unit_list():
	"""Actualiza la lista visual de unidades"""
	unit_list.clear()
	
	for unit in player_units:
		var hp_status = "HP: %d/%d" % [unit.current_hp, unit.max_hp]
		var item_text = "%s - Lv%d %s (%s)" % [
			unit.unit_name,
			unit.level,
			unit.unit_class,
			hp_status
		]
		
		unit_list.add_item(item_text)
		
		# Colorear según estado de HP
		var idx = unit_list.item_count - 1
		if unit.current_hp < unit.max_hp * 0.3:
			unit_list.set_item_custom_fg_color(idx, Color.RED)
		elif unit.current_hp < unit.max_hp * 0.6:
			unit_list.set_item_custom_fg_color(idx, Color.YELLOW)

func update_unit_details(unit: Unit):
	"""Actualiza el panel de detalles de la unidad seleccionada"""
	if not unit:
		return
	
	# Crear o actualizar labels de stats
	var details_container = unit_details_panel.get_node_or_null("VBoxContainer")
	if not details_container:
		details_container = VBoxContainer.new()
		details_container.name = "VBoxContainer"
		unit_details_panel.add_child(details_container)
	
	# Limpiar contenido previo
	for child in details_container.get_children():
		child.queue_free()
	
	# Información básica
	var name_label = create_stat_label("%s - Lv %d %s" % [unit.unit_name, unit.level, unit.unit_class])
	name_label.add_theme_font_size_override("font_size", 24)
	details_container.add_child(name_label)
	
	details_container.add_child(HSeparator.new())
	
	# Stats
	var stats = [
		"HP: %d/%d" % [unit.current_hp, unit.max_hp],
		"Str: %d" % unit.strength,
		"Mag: %d" % unit.magic,
		"Skl: %d" % unit.skill,
		"Spd: %d" % unit.speed,
		"Lck: %d" % unit.luck,
		"Def: %d" % unit.defense,
		"Res: %d" % unit.resistance,
		"Mov: %d" % int(unit.movement)
	]
	
	for stat_text in stats:
		details_container.add_child(create_stat_label(stat_text))
	
	details_container.add_child(HSeparator.new())
	
	# Arma equipada
	if unit.weapon:
		var weapon_label = create_stat_label("Arma: %s (%d/%d)" % [
			unit.weapon.weapon_name,
			unit.weapon.current_durability,
			unit.weapon.max_durability
		])
		details_container.add_child(weapon_label)
	else:
		details_container.add_child(create_stat_label("Arma: Ninguna"))
	
	# Items en inventario
	details_container.add_child(create_stat_label("Inventario:"))
	if unit.inventory.size() == 0:
		details_container.add_child(create_stat_label("  (vacío)"))
	else:
		for item in unit.inventory:
			details_container.add_child(create_stat_label("  - " + item.item_name))

func create_stat_label(text: String) -> Label:
	"""Crea un label estilizado para stats"""
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 18)
	return label

func update_gold_display():
	"""Actualiza la visualización del oro del ejército"""
	gold_label.text = "Oro: %d G" % army_gold

# ============================================
# CALLBACKS DE SELECCIÓN
# ============================================

func _on_unit_selected(index: int):
	"""Cuando se selecciona una unidad de la lista"""
	if index >= 0 and index < player_units.size():
		selected_unit = player_units[index]
		update_unit_details(selected_unit)
		unit_selected.emit(selected_unit)

# ============================================
# CALLBACKS DE FACILIDADES
# ============================================

func _on_shop_button_pressed():
	"""Abre la tienda del castillo. Con Member Card en el ejército se desbloquea
	la Secret Shop (stock adicional)."""
	facility_opened.emit("Shop")
	hide_all_facility_panels()
	shop_panel.show()
	var secret := _army_has_item("MemberCard")
	shop_panel.open_shop(army_gold, selected_unit, secret)
	shop_panel.item_purchased.connect(_on_item_purchased)

func _on_convoy_button_pressed():
	"""Abre el convoy del ejército"""
	facility_opened.emit("Convoy")
	hide_all_facility_panels()
	convoy_panel.show()
	convoy_panel.open_convoy(convoy_items, selected_unit)
	convoy_panel.item_transferred.connect(_on_convoy_item_transferred)

func _on_arena_button_pressed():
	"""Abre la arena de combate"""
	if not selected_unit:
		show_message("Selecciona una unidad primero")
		return
	
	facility_opened.emit("Arena")
	hide_all_facility_panels()
	arena_panel.show()
	arena_panel.start_arena(selected_unit, army_gold)
	arena_panel.arena_finished.connect(_on_arena_finished)

func _on_blacksmith_button_pressed():
	"""Abre la herrería para reparar armas"""
	if not selected_unit:
		show_message("Selecciona una unidad primero")
		return
	
	facility_opened.emit("Blacksmith")
	hide_all_facility_panels()
	blacksmith_panel.show()
	blacksmith_panel.open_blacksmith(selected_unit, army_gold)
	blacksmith_panel.weapon_repaired.connect(_on_weapon_repaired)

func _on_fortune_teller_button_pressed():
	"""Abre el adivinador de fortunas"""
	if not selected_unit:
		show_message("Selecciona una unidad primero")
		return
	
	facility_opened.emit("Fortune")
	hide_all_facility_panels()
	fortune_teller_panel.show()
	fortune_teller_panel.show_fortune(selected_unit)

func _on_promotion_button_pressed():
	"""Abre el panel de promoción de unidades"""
	if not selected_unit:
		show_message("Selecciona una unidad primero")
		return
	
	if not can_promote(selected_unit):
		show_message("%s no puede ser promocionado todavía" % selected_unit.unit_name)
		return
	if not _army_has_item(["Knight Proof", "KnightProof"]):
		show_message("Necesitas un Knight Proof para promocionar")
		return

	facility_opened.emit("Promotion")
	hide_all_facility_panels()
	promotion_panel.show()
	promotion_panel.start_promotion(selected_unit)
	promotion_panel.promotion_completed.connect(_on_unit_promoted)

func _on_manage_button_pressed():
	"""Abre el panel de gestión de unidades"""
	# Aquí podrías abrir un panel para reorganizar unidades, 
	# intercambiar items, etc.
	show_message("Gestión de unidades - Por implementar")

func _on_save_button_pressed():
	"""Guarda el progreso del juego"""
	if not allow_saving:
		show_message("No se puede guardar en este momento")
		return
	
	save_game()
	show_message("Partida guardada exitosamente")

func _on_start_battle_button_pressed():
	"""Inicia la batalla del capítulo"""
	# Verificar que el ejército esté listo
	if not is_army_ready():
		show_message("Prepara tu ejército antes de comenzar")
		return
	
	# Confirmar inicio de batalla
	var confirm = ConfirmationDialog.new()
	confirm.dialog_text = "¿Comenzar la batalla?\n\nNo podrás volver a la preparación después."
	confirm.title = "Confirmar"
	confirm.confirmed.connect(_on_battle_start_confirmed)
	add_child(confirm)
	confirm.popup_centered()

func _on_battle_start_confirmed():
	"""Confirmación de inicio de batalla"""
	# Bloquear acceso al convoy mientras se está en mapa.
	_leave_castle()
	preparation_complete.emit()
	transition_to_battle()

# ============================================
# CALLBACKS DE FACILIDADES
# ============================================

func _on_item_purchased(item: Item, cost: int):
	"""Cuando se compra un item en la tienda"""
	army_gold -= cost
	
	if selected_unit and selected_unit.inventory.size() < 5:
		selected_unit.inventory.append(item)
	else:
		convoy_items.append(item)
		var convoy := _get_convoy()
		if convoy != null:
			convoy.absorb_purchase(item)
	
	update_gold_display()
	update_unit_details(selected_unit)

func _on_convoy_item_transferred(from_convoy: bool, item: Item):
	"""Cuando se transfiere un item del convoy"""
	var convoy := _get_convoy()
	if from_convoy:
		# Del convoy a la unidad
		convoy_items.erase(item)
		if selected_unit:
			selected_unit.inventory.append(item)
		if convoy != null:
			convoy.transfer_convoy_to_unit(selected_unit, item)
	else:
		# De la unidad al convoy
		if selected_unit:
			selected_unit.inventory.erase(item)
		convoy_items.append(item)
		if convoy != null:
			convoy.transfer_unit_to_convoy(selected_unit, item)
	
	update_unit_details(selected_unit)

func _on_arena_finished(victory: bool, gold_earned: int, exp_gained: int):
	"""Cuando termina un combate de arena"""
	if victory:
		army_gold += gold_earned
		selected_unit.gain_experience(exp_gained)
		show_message("¡Victoria! Ganaste %d oro y %d EXP" % [gold_earned, exp_gained])
	else:
		show_message("Derrota en la arena...")
	
	update_gold_display()
	update_unit_details(selected_unit)
	update_unit_list()

func _on_weapon_repaired(weapon: Weapon, cost: int):
	"""Cuando se repara un arma"""
	army_gold -= cost
	weapon.current_durability = weapon.max_durability
	
	update_gold_display()
	update_unit_details(selected_unit)
	show_message("Arma reparada por %d oro" % cost)

func _on_unit_promoted(old_class: String, new_class: String):
	"""Cuando una unidad es promocionada — consume un Knight Proof."""
	_army_consume_item(["Knight Proof", "KnightProof"])
	show_message("%s ha sido promocionado a %s!" % [selected_unit.unit_name, new_class])
	update_unit_details(selected_unit)
	update_unit_list()


# ── Helpers de inventario del ejército (Member Card, Knight Proof…) ───────────

## nid de un item del inventario (ConsumableData/Item) o arma.
func _item_nid(it) -> String:
	if it == null:
		return ""
	if "nid" in it:
		return str(it.nid)
	if "weapon_name" in it:
		return str(it.weapon_name)
	return ""

## ¿Alguna unidad del ejército (o el convoy) lleva alguno de estos nids?
func _army_has_item(nids) -> bool:
	var want: Array = nids if nids is Array else [nids]
	for u in player_units:
		for it in u.inventory:
			if _item_nid(it) in want:
				return true
	for it in convoy_items:
		if _item_nid(it) in want:
			return true
	return false

## Gasta (borra) un item con alguno de estos nids. true si lo consumió.
func _army_consume_item(nids) -> bool:
	var want: Array = nids if nids is Array else [nids]
	for u in player_units:
		for it in u.inventory:
			if _item_nid(it) in want:
				u.inventory.erase(it)
				return true
	for it in convoy_items:
		if _item_nid(it) in want:
			convoy_items.erase(it)
			return true
	return false

# ============================================
# UTILIDADES
# ============================================

func hide_all_facility_panels():
	"""Oculta todos los paneles de facilidades"""
	shop_panel.hide()
	convoy_panel.hide()
	arena_panel.hide()
	blacksmith_panel.hide()
	fortune_teller_panel.hide()
	promotion_panel.hide()

func can_promote(unit: Unit) -> bool:
	"""Verifica si una unidad puede ser promocionada"""
	# Requisitos de FE4: nivel 20+, clase base
	if unit.level < 20:
		return false
	
	# Verificar si ya está promocionado
	var promoted_classes = ["Paladin", "Great Knight", "Swordmaster", "Hero"]
	if unit.unit_class in promoted_classes:
		return false
	
	return true

func is_army_ready() -> bool:
	"""Verifica si el ejército está listo para la batalla"""
	# Al menos una unidad debe tener HP > 0
	for unit in player_units:
		if unit.current_hp > 0:
			return true
	return false

func show_message(text: String):
	"""Muestra un mensaje temporal al jugador"""
	var popup = AcceptDialog.new()
	popup.dialog_text = text
	popup.title = "Información"
	add_child(popup)
	popup.popup_centered()

func save_game():
	"""Guarda el estado del juego"""
	var save_data = {
		"chapter": current_chapter,
		"gold": army_gold,
		"units": serialize_units(),
		"convoy": serialize_items(convoy_items)
	}
	
	# SaveSystem no está implementado aún — comentado para que parsee.
	# Cuando exista, descomentar y poner el script en res://Scripts/SaveSystem.gd
	# SaveSystem.save_game(save_data)
	print("[CastleBase] save_game() llamado (SaveSystem no implementado)")

func serialize_units() -> Array:
	"""Serializa las unidades para guardar"""
	var data = []
	for unit in player_units:
		data.append({
			"name": unit.unit_name,
			"class": unit.unit_class,
			"level": unit.level,
			"hp": unit.current_hp,
			"max_hp": unit.max_hp,
			# ... más stats
		})
	return data

func serialize_items(items: Array) -> Array:
	"""Serializa items para guardar"""
	var data = []
	for item in items:
		data.append({
			"name": item.item_name,
			"type": item.item_type,
			# ... más propiedades
		})
	return data

func transition_to_battle():
	"""Transiciona a la escena de batalla"""
	# Primero fade out
	var fade = ColorRect.new()
	fade.color = Color.BLACK
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fade)
	fade.modulate.a = 0
	
	var tween = create_tween()
	tween.tween_property(fade, "modulate:a", 1.0, 1.0)
	await tween.finished
	
	# Guardar datos del ejército en el GameManager
	# GameManager.set_player_units(player_units)
	# GameManager.set_army_gold(army_gold)
	
	# Cambiar a escena de batalla
	get_tree().change_scene_to_file(next_battle_scene)

func play_preparation_music():
	"""Reproduce la música de preparación"""
	# Implementar cuando tengas el sistema de audio
	pass

# ============================================
# INPUT
# ============================================

func _input(event):
	"""Manejo de input"""
	if event.is_action_pressed("ui_cancel"):
		# Si hay un panel abierto, cerrarlo
		if shop_panel.visible or convoy_panel.visible or arena_panel.visible:
			hide_all_facility_panels()
		else:
			# Confirmar salir al menú
			var confirm = ConfirmationDialog.new()
			confirm.dialog_text = "¿Volver al menú principal?\nSe perderá el progreso no guardado."
			confirm.title = "Confirmar"
			confirm.confirmed.connect(func(): get_tree().change_scene_to_file("res://Scenes/main_menu.tscn"))
			add_child(confirm)
			confirm.popup_centered()
