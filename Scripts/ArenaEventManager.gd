extends Node
class_name ArenaEventManager

# Sistema de eventos que se disparan al derrotar campeones de arena
# Inspirado en Fire Emblem 4 donde derrotar a ciertos gladiadores
# desbloquea eventos de reclutamiento

# Señales
signal event_triggered(event_id: String, event_data: Dictionary)
signal unit_recruited(unit_data: Dictionary)
signal special_item_obtained(item_data: Dictionary)
signal dialogue_triggered(dialogue_sequence: Array)

# Estado
var triggered_events: Array[String] = []

# ============================================
# EVENTOS POR CAPÍTULO
# ============================================

func trigger_arena_event(chapter: int, event_id: String):
	"""Dispara un evento basado en el campeón derrotado"""
	
	# Evitar disparar el mismo evento dos veces
	if event_id in triggered_events:
		return
	
	triggered_events.append(event_id)
	
	# Ejecutar evento específico
	match event_id:
		"beowolf_recruitment":
			await event_beowolf_recruitment()
		
		"holyn_recruitment":
			await event_holyn_recruitment()
		
		"lex_recruitment":
			await event_lex_recruitment()
		
		"ayra_recruitment":
			await event_ayra_recruitment()
		
		"special_sword":
			await event_special_sword()
		
		_:
			# Evento genérico
			await generic_arena_event(event_id)

# ============================================
# EVENTOS ESPECÍFICOS
# ============================================

func event_beowolf_recruitment():
	"""Evento: Beowolf se une después de ser derrotado (Capítulo 1)"""
	
	# Diálogo
	var dialogue = [
		{
			"character": "Beowolf",
			"text": "¡Impresionante! Hace mucho que no me derrotaban en la arena.",
			"portrait": "res://assets/portraits/beowolf.png"
		},
		{
			"character": "Beowolf",
			"text": "Veo potencial en ti. ¿Qué te parece si me uno a tu ejército?",
			"portrait": "res://assets/portraits/beowolf.png"
		},
		{
			"character": "Sigurd",
			"text": "Tu fuerza sería muy valiosa. ¡Bienvenido!",
			"portrait": "res://assets/portraits/sigurd.png"
		},
		{
			"character": "Beowolf",
			"text": "Pero... hay un pequeño detalle. Necesito 10,000 de oro como anticipo.",
			"portrait": "res://assets/portraits/beowolf.png"
		}
	]
	
	dialogue_triggered.emit(dialogue)
	
	# Esperar a que se complete el diálogo
	await get_tree().create_timer(1.0).timeout
	
	# Verificar si el jugador tiene suficiente oro
	var player_gold = get_player_gold()
	
	if player_gold >= 10000:
		# Ofrecer reclutamiento
		var choice = await show_recruitment_choice(
			"¿Pagar 10,000 de oro para reclutar a Beowolf?",
			10000
		)
		
		if choice:
			# Reclutar a Beowolf
			var beowolf_data = create_beowolf_unit()
			unit_recruited.emit(beowolf_data)
			
			# Deducir oro
			deduct_player_gold(10000)
			
			show_message("¡Beowolf se ha unido al ejército!")
		else:
			show_message("Beowolf se marcha decepcionado...")
	else:
		show_message("No tienes suficiente oro. Beowolf espera tu oferta...")

func event_holyn_recruitment():
	"""Evento: Holyn se une después de ser derrotado (Capítulo 2)"""
	
	var dialogue = [
		{
			"character": "Holyn",
			"text": "¡Increíble! Tu técnica de espada es excepcional.",
			"portrait": "res://assets/portraits/holyn.png"
		},
		{
			"character": "Holyn",
			"text": "He estado buscando un maestro digno. Permíteme servirte.",
			"portrait": "res://assets/portraits/holyn.png"
		}
	]
	
	dialogue_triggered.emit(dialogue)
	await get_tree().create_timer(1.0).timeout
	
	# Holyn se une gratis
	var holyn_data = create_holyn_unit()
	unit_recruited.emit(holyn_data)
	show_message("¡Holyn se ha unido al ejército!")

func event_lex_recruitment():
	"""Evento: Lex se une después de ser derrotado (Capítulo 3)"""
	
	var dialogue = [
		{
			"character": "Lex",
			"text": "¡Jajaja! ¡Qué pelea tan emocionante!",
			"portrait": "res://assets/portraits/lex.png"
		},
		{
			"character": "Lex",
			"text": "Me recuerdas a mi viejo amigo. ¿Qué dices? ¿Te vendría bien un guerrero como yo?",
			"portrait": "res://assets/portraits/lex.png"
		}
	]
	
	dialogue_triggered.emit(dialogue)
	await get_tree().create_timer(1.0).timeout
	
	# Lex se une gratis
	var lex_data = create_lex_unit()
	unit_recruited.emit(lex_data)
	show_message("¡Lex se ha unido al ejército!")

func event_ayra_recruitment():
	"""Evento: Ayra ofrece un item especial (Capítulo 4)"""
	
	var dialogue = [
		{
			"character": "Ayra",
			"text": "Tu destreza con la espada es admirable.",
			"portrait": "res://assets/portraits/ayra.png"
		},
		{
			"character": "Ayra",
			"text": "Toma esto. Es una espada que he usado durante años. Siento que tú sabrás usarla mejor.",
			"portrait": "res://assets/portraits/ayra.png"
		}
	]
	
	dialogue_triggered.emit(dialogue)
	await get_tree().create_timer(1.0).timeout
	
	# Otorgar espada especial
	var special_sword = {
		"name": "Ayra's Blade",
		"type": "Weapon",
		"weapon_type": "Sword",
		"might": 12,
		"accuracy": 90,
		"critical": 20,
		"weight": 6,
		"description": "Espada legendaria de Ayra"
	}
	
	special_item_obtained.emit(special_sword)
	show_message("¡Has obtenido la Ayra's Blade!")

func event_special_sword():
	"""Evento genérico: Obtener espada especial"""
	
	var special_sword = {
		"name": "Brave Sword",
		"type": "Weapon",
		"weapon_type": "Sword",
		"might": 9,
		"accuracy": 80,
		"weight": 10,
		"brave": true,
		"description": "Espada que ataca dos veces"
	}
	
	special_item_obtained.emit(special_sword)
	show_message("¡El campeón derrotado dejó caer una Brave Sword!")

func generic_arena_event(event_id: String):
	"""Evento genérico para campeones sin evento específico"""
	show_message("¡Has derrotado al campeón de la arena!\n¡Felicitaciones!")
	
	# Recompensa genérica (oro extra)
	add_player_gold(1000)
	show_message("¡Has recibido 1000 de oro adicional!")

# ============================================
# CREACIÓN DE UNIDADES RECLUTADAS
# ============================================

func create_beowolf_unit() -> Dictionary:
	"""Crea los datos de Beowolf para reclutamiento"""
	return {
		"name": "Beowolf",
		"class": "Mercenary",
		"level": 7,
		"hp": 30,
		"max_hp": 30,
		"str": 10,
		"mag": 0,
		"skl": 11,
		"spd": 11,
		"lck": 6,
		"def": 6,
		"res": 3,
		"mov": 6,
		"weapon": {
			"name": "Steel Sword",
			"might": 8,
			"accuracy": 85,
			"weight": 8
		},
		"skills": [],
		"portrait": "res://assets/portraits/beowolf.png"
	}

func create_holyn_unit() -> Dictionary:
	"""Crea los datos de Holyn para reclutamiento"""
	return {
		"name": "Holyn",
		"class": "Swordmaster",
		"level": 8,
		"hp": 28,
		"max_hp": 28,
		"str": 10,
		"mag": 0,
		"skl": 14,
		"spd": 14,
		"lck": 8,
		"def": 5,
		"res": 4,
		"mov": 7,
		"weapon": {
			"name": "Killing Edge",
			"might": 9,
			"accuracy": 80,
			"critical": 30
		},
		"skills": ["Critical"],
		"portrait": "res://assets/portraits/holyn.png"
	}

func create_lex_unit() -> Dictionary:
	"""Crea los datos de Lex para reclutamiento"""
	return {
		"name": "Lex",
		"class": "Warrior",
		"level": 10,
		"hp": 40,
		"max_hp": 40,
		"str": 15,
		"mag": 0,
		"skl": 12,
		"spd": 11,
		"lck": 5,
		"def": 8,
		"res": 4,
		"mov": 6,
		"weapon": {
			"name": "Brave Axe",
			"might": 9,
			"accuracy": 75,
			"weight": 13,
			"brave": true
		},
		"skills": ["Elite_Skill"],  # Doble EXP
		"portrait": "res://assets/portraits/lex.png"
	}

# ============================================
# UTILIDADES
# ============================================

func show_recruitment_choice(message: String, cost: int) -> bool:
	"""Muestra una opción de reclutamiento y retorna la decisión"""
	# Esto debería mostrar un diálogo personalizado
	# Por ahora, simulación simple
	
	var confirm = ConfirmationDialog.new()
	confirm.dialog_text = message
	confirm.title = "Reclutamiento"
	get_tree().root.add_child(confirm)
	confirm.popup_centered()
	
	var result = await confirm.confirmed
	confirm.queue_free()
	
	return result != null

func show_message(text: String):
	"""Muestra un mensaje al jugador"""
	var popup = AcceptDialog.new()
	popup.dialog_text = text
	popup.title = "Evento de Arena"
	get_tree().root.add_child(popup)
	popup.popup_centered()

func get_player_gold() -> int:
	"""Obtiene el oro actual del jugador"""
	# Esto debería conectarse con tu GameManager
	if has_node("/root/GameManager"):
		return get_node("/root/GameManager").get_army_gold()
	return 0

func add_player_gold(amount: int):
	"""Añade oro al jugador"""
	if has_node("/root/GameManager"):
		var gm = get_node("/root/GameManager")
		gm.set_army_gold(gm.get_army_gold() + amount)

func deduct_player_gold(amount: int):
	"""Deduce oro del jugador"""
	if has_node("/root/GameManager"):
		var gm = get_node("/root/GameManager")
		gm.set_army_gold(gm.get_army_gold() - amount)

func is_event_triggered(event_id: String) -> bool:
	"""Verifica si un evento ya fue disparado"""
	return event_id in triggered_events

func get_triggered_events() -> Array[String]:
	"""Retorna la lista de eventos disparados"""
	return triggered_events

func save_event_state() -> Dictionary:
	"""Guarda el estado de los eventos para save/load"""
	return {
		"triggered_events": triggered_events
	}

func load_event_state(data: Dictionary):
	"""Carga el estado de eventos desde save"""
	triggered_events = data.get("triggered_events", [])


# ============================================
# SISTEMA DE DIÁLOGOS INTEGRADO
# ============================================

func play_event_dialogue(dialogue_sequence: Array):
	"""Reproduce una secuencia de diálogos de evento"""
	# Esto se conectaría con tu DialogueBox
	if has_node("/root/DialogueManager"):
		var dm = get_node("/root/DialogueManager")
		await dm.play_dialogue_sequence(dialogue_sequence)
	else:
		# Fallback: mostrar en consola
		for dialogue in dialogue_sequence:
			print("%s: %s" % [dialogue["character"], dialogue["text"]])
			await get_tree().create_timer(2.0).timeout
