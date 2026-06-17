extends Panel
class_name ArenaPanel

# Referencias UI
@onready var opponent_list: ItemList = $VBoxContainer/OpponentList
@onready var opponent_details: RichTextLabel = $VBoxContainer/OpponentDetails
@onready var battle_preview: RichTextLabel = $VBoxContainer/BattlePreview
@onready var bet_label: Label = $VBoxContainer/BetLabel
@onready var fight_button: Button = $VBoxContainer/ButtonContainer/FightButton
@onready var leave_button: Button = $VBoxContainer/ButtonContainer/LeaveButton
@onready var champion_indicator: Label = $VBoxContainer/ChampionIndicator

# Estado
var current_unit: Unit = null
var player_gold: int = 0
var arena_opponents: Array[Dictionary] = []
var selected_opponent_index: int = -1
var current_chapter: int = 1
var defeated_opponents: Array[String] = []  # IDs de oponentes derrotados
var champion_defeated: bool = false

# Señales
signal arena_finished(victory: bool, gold_earned: int, exp_gained: int)
signal champion_defeated_event(chapter: int, champion_id: String)
signal arena_closed

func _ready():
	opponent_list.item_selected.connect(_on_opponent_selected)
	fight_button.pressed.connect(_on_fight_pressed)
	leave_button.pressed.connect(_on_leave_pressed)
	hide()

# ============================================
# INICIALIZACIÓN
# ============================================

func start_arena(unit: Unit, gold: int, chapter: int = 1):
	"""Inicia la arena con la unidad seleccionada"""
	current_unit = unit
	player_gold = gold
	current_chapter = chapter
	
	# Cargar oponentes de este capítulo
	load_arena_opponents()
	
	# Actualizar UI
	update_opponent_list()
	champion_indicator.hide()
	
	show()

func load_arena_opponents():
	"""Carga la lista fija de oponentes según el capítulo"""
	arena_opponents.clear()
	
	# Capítulo 1: Prólogo
	if current_chapter == 1:
		arena_opponents = [
			{
				"id": "ch1_fighter1",
				"name": "Novato de Arena",
				"class": "Fighter",
				"level": 3,
				"hp": 24,
				"str": 7,
				"skl": 6,
				"spd": 6,
				"def": 4,
				"res": 1,
				"weapon": {"name": "Iron Axe", "might": 7, "hit": 75, "weight": 9},
				"bet": 150,
				"exp": 30
			},
			{
				"id": "ch1_myrmidon1",
				"name": "Espadachín Ágil",
				"class": "Myrmidon",
				"level": 4,
				"hp": 22,
				"str": 6,
				"skl": 9,
				"spd": 10,
				"def": 3,
				"res": 1,
				"weapon": {"name": "Iron Sword", "might": 5, "hit": 90, "weight": 5},
				"bet": 200,
				"exp": 40
			},
			{
				"id": "ch1_soldier1",
				"name": "Lancero Experimentado",
				"class": "Soldier",
				"level": 5,
				"hp": 26,
				"str": 8,
				"skl": 7,
				"spd": 7,
				"def": 5,
				"res": 2,
				"weapon": {"name": "Iron Lance", "might": 6, "hit": 85, "weight": 7},
				"bet": 250,
				"exp": 50
			},
			{
				"id": "ch1_champion",
				"name": "Beowolf",  # Campeón del Capítulo 1
				"class": "Mercenary",
				"level": 7,
				"hp": 30,
				"str": 10,
				"skl": 11,
				"spd": 11,
				"def": 6,
				"res": 3,
				"weapon": {"name": "Steel Sword", "might": 8, "hit": 85, "weight": 8},
				"bet": 500,
				"exp": 100,
				"is_champion": true,
				"event_trigger": "beowolf_recruitment"
			}
		]
	
	# Capítulo 2
	elif current_chapter == 2:
		arena_opponents = [
			{
				"id": "ch2_knight1",
				"name": "Caballero Pesado",
				"class": "Armor Knight",
				"level": 5,
				"hp": 28,
				"str": 9,
				"skl": 6,
				"spd": 4,
				"def": 10,
				"res": 2,
				"weapon": {"name": "Iron Lance", "might": 6, "hit": 85, "weight": 7},
				"bet": 250,
				"exp": 50
			},
			{
				"id": "ch2_archer1",
				"name": "Arquero Certero",
				"class": "Archer",
				"level": 6,
				"hp": 24,
				"str": 7,
				"skl": 10,
				"spd": 8,
				"def": 4,
				"res": 2,
				"weapon": {"name": "Iron Bow", "might": 6, "hit": 85, "weight": 6, "range": 2},
				"bet": 300,
				"exp": 60
			},
			{
				"id": "ch2_cavalier1",
				"name": "Caballero Montado",
				"class": "Cavalier",
				"level": 7,
				"hp": 26,
				"str": 9,
				"skl": 8,
				"spd": 9,
				"def": 6,
				"res": 3,
				"weapon": {"name": "Steel Lance", "might": 9, "hit": 80, "weight": 10},
				"bet": 350,
				"exp": 70
			},
			{
				"id": "ch2_champion",
				"name": "Holyn",  # Campeón del Capítulo 2
				"class": "Swordmaster",
				"level": 8,
				"hp": 28,
				"str": 10,
				"skl": 14,
				"spd": 14,
				"def": 5,
				"res": 4,
				"weapon": {"name": "Killing Edge", "might": 9, "hit": 80, "crit": 30},
				"bet": 600,
				"exp": 120,
				"is_champion": true,
				"event_trigger": "holyn_recruitment"
			}
		]
	
	# Capítulo 3
	elif current_chapter == 3:
		arena_opponents = [
			{
				"id": "ch3_mage1",
				"name": "Mago de Fuego",
				"class": "Mage",
				"level": 7,
				"hp": 22,
				"str": 3,
				"mag": 10,
				"skl": 8,
				"spd": 9,
				"def": 3,
				"res": 7,
				"weapon": {"name": "Fire", "might": 5, "hit": 90, "weight": 4, "magic": true},
				"bet": 350,
				"exp": 70
			},
			{
				"id": "ch3_hero1",
				"name": "Héroe Veterano",
				"class": "Hero",
				"level": 8,
				"hp": 32,
				"str": 12,
				"skl": 10,
				"spd": 10,
				"def": 7,
				"res": 4,
				"weapon": {"name": "Steel Axe", "might": 10, "hit": 75, "weight": 12},
				"bet": 400,
				"exp": 80
			},
			{
				"id": "ch3_paladin1",
				"name": "Paladín Real",
				"class": "Paladin",
				"level": 9,
				"hp": 34,
				"str": 13,
				"skl": 11,
				"spd": 12,
				"def": 9,
				"res": 6,
				"weapon": {"name": "Silver Lance", "might": 13, "hit": 80, "weight": 7},
				"bet": 450,
				"exp": 90
			},
			{
				"id": "ch3_champion",
				"name": "Lex",  # Campeón del Capítulo 3
				"class": "Warrior",
				"level": 10,
				"hp": 40,
				"str": 15,
				"skl": 12,
				"spd": 11,
				"def": 8,
				"res": 4,
				"weapon": {"name": "Brave Axe", "might": 9, "hit": 75, "weight": 13, "brave": true},
				"bet": 700,
				"exp": 140,
				"is_champion": true,
				"event_trigger": "lex_recruitment"
			}
		]
	
	else:
		# Capítulos avanzados - oponentes genéricos más fuertes
		generate_advanced_opponents()

func generate_advanced_opponents():
	"""Genera oponentes genéricos para capítulos sin arena especial"""
	var base_level = 5 + (current_chapter * 2)
	
	for i in range(5):
		var level = base_level + i
		var classes = ["Fighter", "Myrmidon", "Soldier", "Cavalier", "Mage"]
		var selected_class = classes[i % classes.size()]
		
		arena_opponents.append({
			"id": "ch%d_generic%d" % [current_chapter, i],
			"name": "Gladiador Lv%d" % level,
			"class": selected_class,
			"level": level,
			"hp": 20 + (level * 2),
			"str": 5 + level,
			"skl": 5 + level,
			"spd": 5 + level,
			"def": 3 + (level / 2),
			"res": 2 + (level / 3),
			"weapon": {"name": "Iron Sword", "might": 5, "hit": 90},
			"bet": 50 * level,
			"exp": 10 * level
		})

# ============================================
# ACTUALIZACIÓN DE UI
# ============================================

func update_opponent_list():
	"""Actualiza la lista visual de oponentes"""
	opponent_list.clear()
	
	for i in range(arena_opponents.size()):
		var opp = arena_opponents[i]
		var is_champion = opp.get("is_champion", false)
		var is_defeated = opp["id"] in defeated_opponents
		
		# Texto del item
		var text = ""
		if is_champion:
			text = "👑 "
		
		text += "%s - Lv%d %s" % [opp["name"], opp["level"], opp["class"]]
		
		if is_defeated:
			text += " [DERROTADO]"
		
		opponent_list.add_item(text)
		
		# Colorear según estado
		var idx = opponent_list.item_count - 1
		
		if is_defeated:
			opponent_list.set_item_custom_fg_color(idx, Color(0.5, 0.5, 0.5))
			opponent_list.set_item_disabled(idx, true)
		elif is_champion:
			opponent_list.set_item_custom_fg_color(idx, Color(1.0, 0.8, 0.0))  # Dorado

func _on_opponent_selected(index: int):
	"""Cuando se selecciona un oponente"""
	if index < 0 or index >= arena_opponents.size():
		return
	
	selected_opponent_index = index
	var opp = arena_opponents[index]
	
	# Verificar si ya fue derrotado
	if opp["id"] in defeated_opponents:
		fight_button.disabled = true
		return
	
	# Mostrar detalles del oponente
	show_opponent_details(opp)
	
	# Mostrar preview de combate
	show_battle_preview(opp)
	
	# Mostrar apuesta
	bet_label.text = "Apuesta: %d G | EXP: %d" % [opp["bet"], opp["exp"]]
	
	# Indicador de campeón
	if opp.get("is_champion", false):
		champion_indicator.text = "⚠️ CAMPEÓN DE LA ARENA ⚠️"
		champion_indicator.show()
	else:
		champion_indicator.hide()
	
	# Habilitar botón de pelear
	fight_button.disabled = false

func show_opponent_details(opp: Dictionary):
	"""Muestra los detalles del oponente seleccionado"""
	var details = "[center][b]%s[/b][/center]\n" % opp["name"]
	details += "[center]Lv %d %s[/center]\n\n" % [opp["level"], opp["class"]]
	
	details += "HP:  %d\n" % opp["hp"]
	details += "Str: %d\n" % opp["str"]
	details += "Skl: %d\n" % opp["skl"]
	details += "Spd: %d\n" % opp["spd"]
	details += "Def: %d\n" % opp["def"]
	details += "Res: %d\n\n" % opp["res"]
	
	var weapon = opp["weapon"]
	details += "[b]Arma:[/b] %s\n" % weapon["name"]
	details += "Mt: %d | Hit: %d" % [weapon["might"], weapon["hit"]]
	
	if weapon.get("brave", false):
		details += "\n[color=red]¡Ataque doble![/color]"
	
	if weapon.get("crit", 0) > 0:
		details += "\nCrit: +%d" % weapon["crit"]
	
	opponent_details.text = details

func show_battle_preview(opp: Dictionary):
	"""Muestra una preview del combate"""
	if not current_unit:
		return
	
	# Calcular stats de combate
	var player_atk = calculate_attack(current_unit, current_unit.weapon)
	var player_hit = calculate_hit_rate(current_unit, opp)
	var player_crit = calculate_crit_rate(current_unit, opp)
	var player_as = calculate_attack_speed(current_unit)
	
	var enemy_atk = calculate_attack_from_data(opp)
	var enemy_hit = calculate_hit_rate_enemy(opp, current_unit)
	var enemy_crit = calculate_crit_rate_enemy(opp)
	var enemy_as = opp["spd"]
	
	var player_doubles = player_as >= enemy_as + 4
	var enemy_doubles = enemy_as >= player_as + 4
	
	# Construir preview
	var preview = "[b]%s[/b]\n" % current_unit.unit_name
	preview += "Atk: %d | Hit: %d | Crit: %d\n" % [player_atk, player_hit, player_crit]
	if player_doubles:
		preview += "[color=green]x2 ataques[/color]\n"
	
	preview += "\nVS\n\n"
	
	preview += "[b]%s[/b]\n" % opp["name"]
	preview += "Atk: %d | Hit: %d | Crit: %d\n" % [enemy_atk, enemy_hit, enemy_crit]
	if enemy_doubles:
		preview += "[color=red]x2 ataques[/color]\n"
	
	# Advertencia de peligro
	if enemy_atk * (2 if enemy_doubles else 1) >= current_unit.current_hp:
		preview += "\n[color=red]⚠️ PELIGRO DE MUERTE ⚠️[/color]"
	
	battle_preview.text = preview

# ============================================
# CÁLCULOS DE COMBATE
# ============================================

func calculate_attack(unit: Unit, weapon: Weapon) -> int:
	if not weapon:
		return 0
	var base_stat = unit.strength if not weapon.is_magic else unit.magic
	return base_stat + weapon.might

func calculate_attack_from_data(opp: Dictionary) -> int:
	var base_stat = opp.get("mag", opp["str"])
	return base_stat + opp["weapon"]["might"]

func calculate_hit_rate(unit: Unit, opp: Dictionary) -> int:
	if not unit.weapon:
		return 0
	var hit = unit.weapon.accuracy + (unit.skill * 2) + (unit.luck / 2)
	var avoid = (opp["spd"] * 2) + opp.get("lck", 0) / 2
	return clamp(hit - avoid, 0, 100)

func calculate_hit_rate_enemy(opp: Dictionary, unit: Unit) -> int:
	var hit = opp["weapon"]["hit"] + (opp["skl"] * 2)
	var avoid = (unit.speed * 2) + (unit.luck / 2)
	return clamp(hit - avoid, 0, 100)

func calculate_crit_rate(unit: Unit, opp: Dictionary) -> int:
	if not unit.weapon:
		return 0
	var crit = unit.weapon.critical + (unit.skill / 2)
	var dodge = opp.get("lck", 0)
	return max(0, crit - dodge)

func calculate_crit_rate_enemy(opp: Dictionary) -> int:
	var crit = opp["weapon"].get("crit", 0) + (opp["skl"] / 2)
	return crit

func calculate_attack_speed(unit: Unit) -> int:
	if not unit.weapon:
		return unit.speed
	var weight_penalty = max(0, unit.weapon.weight - unit.constitution)
	return unit.speed - weight_penalty

# ============================================
# COMBATE
# ============================================

func _on_fight_pressed():
	"""Inicia el combate contra el oponente seleccionado"""
	if selected_opponent_index < 0:
		return
	
	var opp = arena_opponents[selected_opponent_index]
	
	# Simular combate
	var result = simulate_arena_battle(current_unit, opp)
	
	if result["victory"]:
		# Victoria
		current_unit.current_hp = result["player_hp"]
		
		# Marcar como derrotado
		defeated_opponents.append(opp["id"])
		
		# Recompensas
		var gold_earned = opp["bet"]
		var exp_gained = opp["exp"]
		
		# Verificar si es campeón
		if opp.get("is_champion", false):
			champion_defeated = true
			show_champion_victory(opp)
			
			# Trigger evento especial
			if opp.has("event_trigger"):
				champion_defeated_event.emit(current_chapter, opp["event_trigger"])
		
		arena_finished.emit(true, gold_earned, exp_gained)
		update_opponent_list()
		
	else:
		# Derrota - muerte permanente
		current_unit.current_hp = 0
		arena_finished.emit(false, 0, 0)
		hide()

func simulate_arena_battle(player: Unit, enemy_data: Dictionary) -> Dictionary:
	"""Simula un combate completo de arena"""
	var player_hp = player.current_hp
	var enemy_hp = enemy_data["hp"]
	
	var player_atk = calculate_attack(player, player.weapon)
	var enemy_atk = calculate_attack_from_data(enemy_data)
	
	var player_hit = calculate_hit_rate(player, enemy_data)
	var enemy_hit = calculate_hit_rate_enemy(enemy_data, player)
	
	var player_crit = calculate_crit_rate(player, enemy_data)
	var enemy_crit = calculate_crit_rate_enemy(enemy_data)
	
	var player_as = calculate_attack_speed(player)
	var enemy_as = enemy_data["spd"]
	
	var player_doubles = player_as >= enemy_as + 4
	var enemy_doubles = enemy_as >= player_as + 4
	
	var is_brave_weapon = enemy_data["weapon"].get("brave", false)
	
	# Ronda 1: Jugador ataca
	if randf() * 100 < player_hit:
		var damage = max(0, player_atk - enemy_data["def"])
		var is_crit = randf() * 100 < player_crit
		if is_crit:
			damage *= 3
		enemy_hp -= damage
	
	if enemy_hp <= 0:
		return {"victory": true, "player_hp": player_hp}
	
	# Enemigo contraataca
	if randf() * 100 < enemy_hit:
		var damage = max(0, enemy_atk - player.defense)
		var is_crit = randf() * 100 < enemy_crit
		if is_crit:
			damage *= 3
		player_hp -= damage
	
	if player_hp <= 0:
		return {"victory": false, "player_hp": 0}
	
	# Si enemigo tiene Brave weapon, ataca de nuevo
	if is_brave_weapon:
		if randf() * 100 < enemy_hit:
			var damage = max(0, enemy_atk - player.defense)
			player_hp -= damage
		
		if player_hp <= 0:
			return {"victory": false, "player_hp": 0}
	
	# Ronda 2: Si alguien dobla
	if player_doubles:
		if randf() * 100 < player_hit:
			var damage = max(0, player_atk - enemy_data["def"])
			var is_crit = randf() * 100 < player_crit
			if is_crit:
				damage *= 3
			enemy_hp -= damage
	elif enemy_doubles:
		if randf() * 100 < enemy_hit:
			var damage = max(0, enemy_atk - player.defense)
			var is_crit = randf() * 100 < enemy_crit
			if is_crit:
				damage *= 3
			player_hp -= damage
	
	return {
		"victory": player_hp > 0 and enemy_hp <= 0,
		"player_hp": max(0, player_hp)
	}

# ============================================
# EVENTOS ESPECIALES
# ============================================

func show_champion_victory(champion: Dictionary):
	"""Muestra mensaje especial al derrotar al campeón"""
	var popup = AcceptDialog.new()
	popup.dialog_text = "¡Has derrotado a %s, el Campeón de la Arena!\n\n¡Un evento especial ha sido desbloqueado!" % champion["name"]
	popup.title = "🏆 ¡VICTORIA ÉPICA! 🏆"
	add_child(popup)
	popup.popup_centered()
	await popup.confirmed
	popup.queue_free()

func get_defeated_champion_ids() -> Array[String]:
	"""Retorna lista de IDs de campeones derrotados"""
	var champions = []
	for opp_id in defeated_opponents:
		for opp in arena_opponents:
			if opp["id"] == opp_id and opp.get("is_champion", false):
				champions.append(opp_id)
	return champions

func reset_arena_progress():
	"""Resetea el progreso de la arena (para nuevo capítulo)"""
	defeated_opponents.clear()
	champion_defeated = false

# ============================================
# UTILIDADES
# ============================================

func _on_leave_pressed():
	"""Sale de la arena"""
	arena_closed.emit()
	hide()

func is_champion_available() -> bool:
	"""Verifica si hay un campeón disponible en este capítulo"""
	for opp in arena_opponents:
		if opp.get("is_champion", false) and opp["id"] not in defeated_opponents:
			return true
	return false

func get_champion_data() -> Dictionary:
	"""Obtiene los datos del campeón del capítulo actual"""
	for opp in arena_opponents:
		if opp.get("is_champion", false):
			return opp
	return {}
