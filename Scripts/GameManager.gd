extends Node

enum GameState {
	PLAYER_TURN,
	ENEMY_TURN,
	ANIMATION,
	MENU,
	GAME_OVER,
	VICTORY
}

enum PlayerPhase {
	IDLE,
	UNIT_SELECTED,
	MOVING,
	ACTION_MENU,
	TARGETING
}

# Referencias
@onready var grid: Grid
@onready var camera: Camera2D

# Contenedor Node2D con Y-sort: ordena las unidades por su Y (fila) para que las
# de filas inferiores (más abajo en pantalla) se dibujen DELANTE de las de arriba.
var unit_layer: Node2D

# Sistemas auxiliares (Fase 1).
# fow_system se instancia al cargar un capítulo con FoW activo (LevelLoader
# llamará a setup_fog_of_war()). Si está null, FoW está desactivado y todo
# es visible.  TerrainSystem y BallistaSystem son utilidades estáticas.
var fow_system: FogOfWarSystem = null

# Estado persistente del ejército para sustitutos gen 2.  Mapa
# mother_id → { alive, married_to, father_data }.  El GameManager mantiene
# este registro durante toda gen 1 y lo consume al iniciar gen 2.
var mother_states: Dictionary = {}

# Sistemas auxiliares (Fases 2/3/4).
var ai_controller: AIController = null
var event_system: EventSystem = null
var support_system: SupportSystem = null
var current_objective: ChapterObjective = null
var loaded_level: LevelLoader.LoadedLevel = null   # contiene unit_groups, regions, etc.

# Datos del proyecto (cargados por LTImporter al inicio del juego).
# Estructura: { units, classes, items, terrain, ai, weapons, ... }
# Cada categoría es un Dictionary indexado por nid.
var project_data: Dictionary = {}

# Refuerzos pendientes del capítulo actual.  El LevelLoader los rellena
# desde events de tipo "spawn".  Se evalúan en cada start_enemy_turn.
var reinforcements: Array = []

# Lista de eventos disparados (para reinforcements con trigger por evento
# y para detectar only_once events ya consumidos).
var fired_event_names: Array = []

# Estado del juego
var current_state: GameState = GameState.PLAYER_TURN
var player_phase: PlayerPhase = PlayerPhase.IDLE
var current_turn: int = 1

# Unidades
var player_units: Array[Unit] = []
var enemy_units: Array[Unit] = []

# Selección y movimiento
var selected_unit: Unit = null
var reachable_tiles: Array[Vector2i] = []
var attackable_tiles: Array[Vector2i] = []
var current_path: Array[Vector2i] = []
var target_position: Vector2i

# Señales
signal turn_changed(new_turn: int, is_player: bool)
signal unit_moved(unit: Unit, from: Vector2i, to: Vector2i)
signal combat_started(attacker: Unit, defender: Unit)
signal game_state_changed(new_state: GameState)

## Devuelve (creando si hace falta) la capa Node2D con Y-sort donde cuelgan las
## unidades. Todas las unidades deben añadirse aquí (no a GameManager directo)
## para que se ordenen por fila.
func _ensure_unit_layer() -> Node2D:
	if unit_layer == null or not is_instance_valid(unit_layer):
		unit_layer = Node2D.new()
		unit_layer.name = "UnitLayer"
		unit_layer.y_sort_enabled = true
		add_child(unit_layer)
	return unit_layer

func _ready():
	# Buscar o crear el grid
	grid = get_node_or_null("Grid")
	if not grid:
		grid = Grid.new()
		add_child(grid)

	# Capa de unidades con Y-sort (se añade DESPUÉS del grid → encima de él).
	_ensure_unit_layer()

	# Si no se cargó un capítulo (escena de test directa), usar el escenario
	# de prueba.  En el flow normal, MainMenu → CastleBase → load_chapter()
	# carga datos antes de instanciar el GameManager y start_player_turn
	# se llama tras load_chapter().
	# Solo el escenario de prueba si se corre ESTA escena directamente (F6).
	# Como autoload (/root/GameManager) o como hijo de main_game, current_scene
	# != self → NO se autogenera (antes spawneaba unidades de test que capturaban
	# los clics del menú principal).
	if get_tree().current_scene == self and player_units.is_empty() and enemy_units.is_empty():
		setup_test_scenario()
		start_player_turn()

func _input(event):
	if current_state != GameState.PLAYER_TURN:
		return
	# Durante un evento/diálogo (speak, cinemática) el input es del EventSystem
	# (avanzar diálogo) — no mover unidades ni seleccionar.
	if event_system != null and event_system.has_method("is_busy") and event_system.is_busy():
		return
	# Sin batalla activa (p.ej. el autoload mientras se ve el menú) → ignorar.
	if player_units.is_empty() and enemy_units.is_empty():
		return

	# Sólo clic IZQUIERDO. Ojo: la rueda del ratón también es InputEventMouseButton
	# con pressed==true (button_index WHEEL_UP/DOWN), por eso hay que filtrar.
	# Clic DERECHO en modo targeting = cancelar el ataque y volver al menú de
	# acciones (no se fuerza a atacar tras mover).
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_RIGHT \
			and player_phase == PlayerPhase.TARGETING:
		attackable_tiles.clear()
		show_action_menu()
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# event.position son COORDENADAS DE PANTALLA — hay que convertirlas
		# a coordenadas de mundo respetando la cámara (zoom + posición).
		# Si no hay cámara, world_pos == screen_pos.
		var world_pos: Vector2 = event.position
		var viewport := get_viewport()
		if viewport != null:
			var camera := viewport.get_camera_2d()
			if camera != null:
				var canvas_xform := viewport.get_canvas_transform()
				world_pos = canvas_xform.affine_inverse() * event.position
		handle_mouse_click(world_pos)

func handle_mouse_click(mouse_pos: Vector2):
	"""Maneja clicks del mouse en el grid"""
	var grid_pos = grid.world_to_grid(mouse_pos)
	
	if not grid.is_valid_position(grid_pos):
		return
	
	match player_phase:
		PlayerPhase.IDLE:
			# Intentar seleccionar una unidad
			var unit = grid.get_unit_at(grid_pos)
			if unit and unit.is_player_unit and not unit.has_acted:
				select_unit(unit)
		
		PlayerPhase.UNIT_SELECTED:
			# Verificar si clickeó una casilla alcanzable
			if grid_pos in reachable_tiles:
				move_selected_unit(grid_pos)
			else:
				deselect_unit()
		
		PlayerPhase.ACTION_MENU:
			# Aquí se manejaría el menú de acciones
			pass
		
		PlayerPhase.TARGETING:
			# Verificar si clickeó un enemigo atacable
			var target = grid.get_unit_at(grid_pos)
			if target and not target.is_player_unit and grid_pos in attackable_tiles:
				initiate_combat(selected_unit, target)

func select_unit(unit: Unit):
	"""Selecciona una unidad del jugador"""
	if selected_unit:
		deselect_unit()
	
	selected_unit = unit
	selected_unit.select()
	player_phase = PlayerPhase.UNIT_SELECTED
	
	# Calcular casillas alcanzables (pasando unit para que aliados se atraviesen).
	reachable_tiles = Pathfinding.get_reachable_tiles(
		grid, 
		unit.grid_position, 
		unit.movement,
		unit
	)
	
	# Calcular casillas atacables
	if unit.weapon:
		attackable_tiles = Pathfinding.get_tiles_in_attack_range_after_move(
			grid,
			unit.grid_position,
			unit.movement,
			unit.weapon.range_min,
			unit.weapon.range_max,
			unit
		)
	
	print("Unit selected: ", unit.unit_name)
	print("Can reach %d tiles" % reachable_tiles.size())

func deselect_unit():
	"""Deselecciona la unidad actual"""
	if selected_unit:
		selected_unit.deselect()
		selected_unit = null
	
	player_phase = PlayerPhase.IDLE
	reachable_tiles.clear()
	attackable_tiles.clear()
	current_path.clear()

func move_selected_unit(target: Vector2i):
	"""Mueve la unidad seleccionada a la posición objetivo (con animación de paso)."""
	if not selected_unit:
		return
	if player_phase == PlayerPhase.MOVING:
		return   # ya hay un movimiento en curso — ignora clics repetidos

	var path = Pathfinding.find_path(grid, selected_unit.grid_position, target, selected_unit.movement, selected_unit)

	if path.size() == 0:
		return

	var unit := selected_unit
	var from = unit.grid_position
	# Bloquea el input y oculta los resaltados mientras la unidad camina.
	player_phase = PlayerPhase.MOVING
	reachable_tiles.clear()
	attackable_tiles.clear()
	# El grid lógico se actualiza ya; la animación es puramente visual.
	grid.move_unit(from, target)

	# Recorrido en coordenadas de mundo (sin la casilla de inicio, path[0]).
	var pts: Array = []
	for i in range(1, path.size()):
		pts.append(grid.grid_to_world(path[i]))
	await unit.animate_move_along(pts)
	unit.global_position = grid.grid_to_world(target)   # asegura encaje exacto
	unit.has_moved = true

	unit_moved.emit(unit, from, target)

	# Recalcular FoW del jugador — el movimiento puede revelar tiles.
	if fow_system:
		fow_system.update_team_vision("player", player_units)

	# Disparar eventos de región — si el tile destino tiene una región
	# event-type asociada, EventSystem la procesa.
	if event_system and current_objective:
		_check_region_events(target, unit)

	# Mostrar menú de acciones
	show_action_menu()


## Comprueba si el tile destino activa algún evento de región.  Llamado
## tras cada movimiento de unidad jugador.
func _check_region_events(pos: Vector2i, unit: Unit) -> void:
	# Las regiones se cargan en LoadedLevel.regions y se almacenan también
	# como atributo del current_objective implícitamente (se pasaron al
	# from_chapter para resolver Seize/Escape).  Aquí necesitamos las
	# regiones completas; las guardamos en metadata si están disponibles.
	if not has_meta("chapter_regions"):
		return
	var regions: Array = get_meta("chapter_regions")
	for r in regions:
		if not (r is Dictionary):
			continue
		var rpos: Vector2i = r.get("position", Vector2i.ZERO)
		var size: Vector2i = r.get("size", Vector2i.ONE)
		var rect := Rect2i(rpos, size)
		if not rect.has_point(pos):
			continue
		var rtype := str(r.get("region_type", "normal"))
		if rtype == "event":
			var sub_nid := str(r.get("sub_nid", ""))
			# El sub_nid del LT actúa como nombre del trigger
			# (Visit, Seize, etc.).
			if sub_nid != "":
				event_system.trigger_event(sub_nid,
						{ "unit": unit, "region": r })

var _action_menu: ActionMenu = null
var ui_layer: CanvasLayer = null

## Capa de pantalla (screen-space) para la UI de gameplay (menú de acciones).
func _ensure_ui_layer() -> CanvasLayer:
	if ui_layer == null or not is_instance_valid(ui_layer):
		ui_layer = CanvasLayer.new()
		ui_layer.name = "UILayer"
		ui_layer.layer = 10
		add_child(ui_layer)
	return ui_layer


func show_action_menu():
	"""Muestra el menú de acciones (Attack/Wait…) tras mover la unidad."""
	player_phase = PlayerPhase.ACTION_MENU
	if selected_unit == null:
		return

	# Opciones disponibles según el contexto de la unidad.
	var options: Array = []
	var enemies_in_range = get_enemies_in_attack_range(selected_unit)
	if enemies_in_range.size() > 0:
		options.append({ "id": "attack", "text": "Attack" })
	options.append({ "id": "wait", "text": "Wait" })

	_close_action_menu()
	_action_menu = ActionMenu.new()
	_ensure_ui_layer().add_child(_action_menu)
	_action_menu.setup(options, _unit_menu_anchor(selected_unit))
	_action_menu.action_selected.connect(_on_action_selected)


## Ancla de pantalla para el menú, junto a la unidad (con la transform de cámara).
func _unit_menu_anchor(unit: Unit) -> Vector2:
	var vp := get_viewport()
	if vp == null:
		return Vector2(-1, -1)
	var xform := vp.get_canvas_transform()
	var screen_pos: Vector2 = xform * unit.global_position
	return screen_pos + Vector2(48, -24)


func _close_action_menu() -> void:
	if _action_menu != null and is_instance_valid(_action_menu):
		_action_menu.queue_free()
	_action_menu = null


## Resuelve la acción elegida en el menú.
func _on_action_selected(id: String) -> void:
	_action_menu = null   # el menú se auto-libera tras emitir
	match id:
		"attack":
			enter_targeting_mode()
		_:  # "wait" y cualquier fallback seguro
			end_unit_action()

func enter_targeting_mode():
	"""Entra en modo de selección de objetivo"""
	player_phase = PlayerPhase.TARGETING
	
	# Recalcular enemigos atacables desde la posición actual
	if selected_unit.weapon:
		var attack_range = Pathfinding.get_attack_range(
			grid,
			selected_unit.grid_position,
			selected_unit.weapon.range_min,
			selected_unit.weapon.range_max
		)
		
		attackable_tiles = attack_range.filter(func(pos): 
			var unit = grid.get_unit_at(pos)
			return unit != null and not unit.is_player_unit
		)

func get_enemies_in_attack_range(unit: Unit) -> Array[Unit]:
	"""Obtiene lista de enemigos atacables desde la posición actual"""
	var enemies: Array[Unit] = []
	
	if not unit.weapon:
		return enemies
	
	var attack_range = Pathfinding.get_attack_range(
		grid,
		unit.grid_position,
		unit.weapon.range_min,
		unit.weapon.range_max
	)
	
	for pos in attack_range:
		var target = grid.get_unit_at(pos)
		if target and not target.is_player_unit:
			enemies.append(target)
	
	return enemies

func initiate_combat(attacker: Unit, defender: Unit):
	"""Inicia el combate entre dos unidades"""
	combat_started.emit(attacker, defender)
	
	var distance = Pathfinding.get_manhattan_distance(
		attacker.grid_position,
		defender.grid_position
	)
	
	# Calcular bonuses de terreno para cada bando (DEF/AVO).
	# TerrainSystem ya filtra a voladores (sin bonus) y devuelve {} para
	# Plain — pasarlos siempre es seguro.
	var t_atk := TerrainSystem.get_combat_terrain(attacker, grid)
	var t_def := TerrainSystem.get_combat_terrain(defender, grid)
	
	# Cachear support bonuses en meta para que CombatSystem los lea.
	if support_system != null:
		var all := player_units + enemy_units
		attacker.set_meta("support_bonus", support_system.get_combat_bonus(attacker, all))
		defender.set_meta("support_bonus", support_system.get_combat_bonus(defender, all))
	
	# Disparar evento combat_start para eventos de cap (ej. cinemáticas
	# de jefe, pre-batalla con boss).
	if event_system:
		event_system.trigger_event("combat_start",
				{ "attacker": attacker, "defender": defender })
	
	# Ejecutar combate
	var result = CombatSystem.calculate_combat(attacker, defender, distance, t_atk, t_def)
	
	print(result.get_summary())
	
	# Eliminar unidades muertas — los items van al convoy automáticamente.
	if result.defender_died:
		_handle_unit_death(defender)
	
	if result.attacker_died:
		_handle_unit_death(attacker)
	
	# Bonus de support por kill compartido / battle-buddy.
	if support_system != null and result.defender_died and not attacker.is_player_unit == defender.is_player_unit:
		# Dar puntos a parejas adyacentes al ganador.
		for ally in player_units:
			if ally != attacker and ally.unit_name != attacker.unit_name:
				var d: int = abs(ally.grid_position.x - attacker.grid_position.x) \
						+ abs(ally.grid_position.y - attacker.grid_position.y)
				if d <= 3:
					support_system.add_event_bonus(attacker.unit_name, ally.unit_name, 3)
	
	# Recalcular visión del jugador tras un combate (la unidad atacante
	# pudo haberse movido, y haber matado a un enemigo "destapa" tiles).
	if fow_system:
		fow_system.update_team_vision("player", player_units)
	
	# Disparar evento combat_end.
	if event_system:
		event_system.trigger_event("combat_end",
				{ "attacker": attacker, "defender": defender, "result": result })
	
	# Limpiar el cache de support bonus tras combate.
	if attacker.has_meta("support_bonus"): attacker.remove_meta("support_bonus")
	if defender.has_meta("support_bonus"): defender.remove_meta("support_bonus")
	
	end_unit_action()
	check_victory_conditions()


## Maneja la muerte de una unidad: ballistas se destruyen sin más; las
## unidades normales depositan su inventario en el convoy y se eliminan
## del grid + de las listas de bando correspondientes.
func _handle_unit_death(unit: Unit) -> void:
	if unit == null:
		return
	# Ballistas: destrucción de objeto del mapa, no muerte de unidad.
	if BallistaSystem.is_ballista(unit):
		BallistaSystem.on_damage_taken(unit, grid)
		# Limpiar de las listas independientemente del bando que la opere.
		player_units.erase(unit)
		enemy_units.erase(unit)
		return
	# Unidad normal: items al convoy (constants.convoy_on_death = 1).
	var convoy: ConvoySystem = _get_convoy()
	if convoy != null:
		convoy.absorb_dead_unit_inventory(unit)
	grid.remove_unit(unit.grid_position)
	if unit.is_player_unit:
		player_units.erase(unit)
		# Si era una madre potencial, marcarla muerta para gen 2.
		_record_mother_death(unit)
	else:
		enemy_units.erase(unit)
	# Romper soportes del fallecido (canon FE4).
	if support_system != null:
		support_system.break_supports_on_death(unit.unit_name)
	# Disparar evento unit_death (eventos de muerte específica).
	if event_system != null:
		event_system.trigger_event("unit_death", { "unit": unit })


## Resuelve la referencia al ConvoySystem.  Soporta dos modos:
##   1) Autoload — se busca en el árbol como /root/Convoy.
##   2) Hijo manual — se busca como nodo hijo de este GameManager.
## Si no se encuentra ninguno, devuelve null y el caller seguirá sin
## convoy (compatibilidad con escenas de test).
func _get_convoy() -> ConvoySystem:
	# Autoload primero.
	var node := get_tree().get_root().get_node_or_null("Convoy")
	if node and node is ConvoySystem:
		return node
	# Hijo del GameManager.
	for child in get_children():
		if child is ConvoySystem:
			return child
	return null


## Registra la muerte de una madre potencial (gen 1 → gen 2 substitutes).
## Solo aplica a las 7 madres canónicas FE4 que tienen sustituto definido.
func _record_mother_death(unit: Unit) -> void:
	const MOTHERS := ["Aideen", "Ayra", "Lachesis", "Sylvia", "Erinys", "Brigid", "Tailtiu"]
	if not (unit.unit_name in MOTHERS):
		return
	if not mother_states.has(unit.unit_name):
		mother_states[unit.unit_name] = {
			"alive": false, "married_to": "", "father_data": {}
		}
	else:
		mother_states[unit.unit_name]["alive"] = false

func end_unit_action():
	"""Finaliza la acción de la unidad actual"""
	_close_action_menu()
	if selected_unit:
		selected_unit.end_turn()

	deselect_unit()
	
	# Verificar si todas las unidades del jugador actuaron
	if all_player_units_acted():
		end_player_turn()

func all_player_units_acted() -> bool:
	"""Verifica si todas las unidades del jugador ya actuaron"""
	for unit in player_units:
		if not unit.has_acted:
			return false
	return true

func start_player_turn():
	"""Inicia el turno del jugador"""
	current_state = GameState.PLAYER_TURN
	player_phase = PlayerPhase.IDLE
	
	# Resetear todas las unidades del jugador
	for unit in player_units:
		unit.reset_turn()
	
	# Regeneración de terreno (Fort 75% / Throne-Gate 20%) — solo afecta
	# a unidades del bando que comienza turno y están sobre fortaleza
	# de su mismo equipo (TerrainSystem ya filtra por team_only).
	var heals := TerrainSystem.process_turn_regeneration(player_units, grid)
	for h in heals:
		print("  %s regenera %d HP en %s" % [h["unit"].unit_name, h["amount"], h["terrain"]])
	
	# Fog of War: decrementar Torch + recalcular visión del jugador.
	if fow_system:
		fow_system.tick_torches()
		fow_system.update_team_vision("player", player_units)
	
	# Soportes: ganar puntos por turno (FE4) y por adyacencia.
	if support_system:
		support_system.tick_supports(player_units)
	
	# Disparar evento turn_change.
	if event_system:
		event_system.trigger_event("turn_change",
				{ "turn": current_turn, "team": "player" })
	
	turn_changed.emit(current_turn, true)
	print("\n=== PLAYER TURN %d ===" % current_turn)

func end_player_turn():
	"""Finaliza el turno del jugador"""
	print("Player turn ended")
	start_enemy_turn()

func start_enemy_turn():
	"""Inicia el turno del enemigo"""
	current_state = GameState.ENEMY_TURN
	
	# Resetear todas las unidades enemigas
	for unit in enemy_units:
		unit.reset_turn()
	
	# Procesar refuerzos del capítulo (turn-based + event-triggered).
	_process_reinforcements()
	
	# Regeneración del enemigo en sus propias fortalezas.
	var heals := TerrainSystem.process_turn_regeneration(enemy_units, grid)
	for h in heals:
		print("  %s (enemy) regenera %d HP en %s" % [h["unit"].unit_name, h["amount"], h["terrain"]])
	
	# FoW: si el enemigo respeta FoW (ai_fog_of_war en LT), recalcular.
	if fow_system:
		fow_system.update_team_vision("enemy", enemy_units)
	
	# Disparar evento turn_change.
	if event_system:
		event_system.trigger_event("turn_change",
				{ "turn": current_turn, "team": "enemy" })
	
	turn_changed.emit(current_turn, false)
	print("\n=== ENEMY TURN %d ===" % current_turn)
	
	# Ejecutar IA enemiga
	await execute_enemy_ai()
	
	end_enemy_turn()

func execute_enemy_ai():
	"""Ejecuta la IA para todas las unidades enemigas usando AIController."""
	# Crear/reusar el AIController.  Necesita el grid y los presets cargados.
	if ai_controller == null:
		ai_controller = AIController.new(grid, project_data)
	
	# Combinar todas las unidades vivas en un solo array (AI necesita ver
	# tanto aliados como enemigos para evaluar targets correctamente).
	var all_units: Array = []
	all_units.append_array(player_units)
	all_units.append_array(enemy_units)
	
	for enemy in enemy_units:
		if enemy == null or enemy.current_hp <= 0 or enemy.has_acted:
			continue
		# Las ballistas controladas por el enemigo disparan según su preset
		# pero respetando MOV=0 — el AIController ya filtra por movement.
		var decision := ai_controller.decide_action(enemy, all_units)
		await execute_enemy_decision(enemy, decision)
		await get_tree().create_timer(0.3).timeout


## Ejecuta la decisión que tomó el AIController para una unidad enemiga.
func execute_enemy_decision(enemy: Unit, decision: Dictionary) -> void:
	if decision.is_empty():
		return
	var action := str(decision.get("action", "Wait"))
	var moved_to: Vector2i = decision.get("moved_to", enemy.grid_position)
	var attacked: Unit = decision.get("attacked")
	
	# Mover si la posición decidida es distinta (con animación de paso).
	if moved_to != enemy.grid_position:
		var from_pos: Vector2i = enemy.grid_position
		var path = Pathfinding.find_path(grid, from_pos, moved_to, enemy.movement, enemy)
		grid.move_unit(from_pos, moved_to)
		# enemy.grid_position se actualiza automáticamente en grid.move_unit().
		if enemy.has_method("animate_move_along") and path.size() > 1:
			var pts: Array = []
			for i in range(1, path.size()):
				pts.append(grid.grid_to_world(path[i]))
			await enemy.animate_move_along(pts)
		enemy.global_position = grid.grid_to_world(moved_to)
		print("[AI] %s moves %s → %s" % [enemy.unit_name, from_pos, moved_to])
	
	# Ejecutar la acción específica.
	match action:
		"Attack":
			if attacked != null and attacked.current_hp > 0:
				print("[AI] %s attacks %s!" % [enemy.unit_name, attacked.unit_name])
				initiate_combat(enemy, attacked)
				return  # initiate_combat ya consume la acción.
		"Steal":
			var victim: Unit = decision.get("steal_target")
			var item = decision.get("steal_item")
			if victim != null and item != null:
				MapActions.execute_steal(enemy, victim, item)
				return
		"Move_to", "Move_away_from", "Wait":
			pass  # El movimiento ya se hizo arriba.
	
	enemy.has_acted = true
	enemy.has_moved = true
	if enemy.has_method("update_visual"):
		enemy.update_visual()

func find_nearest_player_unit(from_unit: Unit) -> Unit:
	"""Encuentra la unidad del jugador más cercana"""
	var nearest: Unit = null
	var min_distance = INF
	
	for player in player_units:
		if player.current_hp <= 0:
			continue
		
		var distance = Pathfinding.get_manhattan_distance(
			from_unit.grid_position,
			player.grid_position
		)
		
		if distance < min_distance:
			min_distance = distance
			nearest = player
	
	return nearest

func find_closest_position_to_target(positions: Array[Vector2i], target: Vector2i) -> Vector2i:
	"""Encuentra la posición más cercana al objetivo"""
	var closest = positions[0] if positions.size() > 0 else Vector2i.ZERO
	var min_distance = INF
	
	for pos in positions:
		var distance = Pathfinding.get_manhattan_distance(pos, target)
		if distance < min_distance:
			min_distance = distance
			closest = pos
	
	return closest

func end_enemy_turn():
	"""Finaliza el turno del enemigo"""
	print("Enemy turn ended")
	current_turn += 1
	start_player_turn()

func check_victory_conditions():
	"""Verifica las condiciones de victoria/derrota usando ChapterObjective."""
	if current_objective != null:
		await _evaluate_objective()
		return
	# Fallback al modo legacy (para escenarios de test sin objective).
	if enemy_units.is_empty():
		current_state = GameState.VICTORY
		game_state_changed.emit(GameState.VICTORY)
		print("\n=== VICTORY! ===")
	elif player_units.is_empty():
		current_state = GameState.GAME_OVER
		game_state_changed.emit(GameState.GAME_OVER)
		print("\n=== GAME OVER ===")

# ══════════════════════════════════════════════════════════════════════════════
# CONFIGURACIÓN POR CAPÍTULO
# ══════════════════════════════════════════════════════════════════════════════

## Configura el sistema de Fog of War para el capítulo actual.  Llamar
## desde el LevelLoader tras cargar el mapa.  chapter_data debe contener
## al menos los flags fow_enabled y opcionalmente fog_los, _fog_of_war_radius.
##   Si fow_enabled = false, fow_system queda en null y todo es visible.
func setup_fog_of_war(chapter_data: Dictionary) -> void:
	if not bool(chapter_data.get("fow_enabled", false)):
		fow_system = null
		return
	fow_system = FogOfWarSystem.new(grid)
	fow_system.configure_from_chapter(chapter_data)
	# Pintar la visión inicial inmediatamente (player_units ya colocadas).
	fow_system.update_team_vision("player", player_units)
	fow_system.update_team_vision("enemy", enemy_units)


## Activa Torch en una unidad — invocado por ItemSystem cuando se usa el
## ítem Torch en mapa.  Wrapper sobre fow_system.apply_torch.
func apply_torch_to(unit: Unit, bonus: int = 4, turns: int = 4) -> void:
	if fow_system == null:
		return
	fow_system.apply_torch(unit, bonus, turns)
	fow_system.update_team_vision("player", player_units)


# ══════════════════════════════════════════════════════════════════════════════
# CARGA DE CAPÍTULO  (FASE 2)
# ══════════════════════════════════════════════════════════════════════════════

## Carga un capítulo completo desde su JSON.
##   chapter_path : ruta al JSON del capítulo
##   tilemap_data : tilemap del capítulo (puede estar vacío)
##   events_data  : array completo de eventos del proyecto
##   support_pairs / support_ranks : datos canónicos del proyecto
##
## Llamar UNA VEZ tras cargar project_data y antes de start_player_turn.
func load_chapter(chapter_path: String, tilemap_data: Dictionary,
		events_data: Array = [], support_pairs: Array = [],
		support_ranks: Array = []) -> void:
	# 1. Limpiar estado del capítulo anterior.
	player_units.clear()
	enemy_units.clear()
	reinforcements.clear()
	fired_event_names.clear()
	current_turn = 1
	
	# 2. Cargar el nivel — colocará unidades en el grid.
	var loaded := LevelLoader.load_chapter(chapter_path, project_data,
			tilemap_data, grid)
	loaded_level = loaded  # para que EventSystem acceda a unit_groups, etc.
	# Distribuir unidades en player/enemy.
	for u in loaded.units:
		_ensure_unit_layer().add_child(u)  # cuelga de UnitLayer (Y-sort)
		if u.is_player_unit:
			player_units.append(u)
		else:
			enemy_units.append(u)
	
	# 3. Configurar FoW del capítulo.
	setup_fog_of_war({
		"fow_enabled": loaded.fow_enabled,
		"_fog_of_war_radius": loaded.fow_radius,
		"fog_los": loaded.fog_los,
	})
	
	# 4. Construir el objetivo del capítulo.
	var lord_nid := _detect_lord_nid()
	current_objective = ChapterObjective.from_chapter(loaded.objective,
			loaded.regions, lord_nid)
	# Guardar regiones para que move_selected_unit pueda procesar visits.
	set_meta("chapter_regions", loaded.regions)
	
	# 5. Configurar Support system.
	support_system = SupportSystem.new()
	add_child(support_system)
	if not support_pairs.is_empty():
		support_system.load_from_project(support_pairs, support_ranks)
	
	# 6. Configurar Event system y cargar eventos del cap.
	event_system = EventSystem.new()
	add_child(event_system)
	event_system.load_chapter_events(events_data, loaded.nid)
	event_system.configure(self, null, _get_convoy())
	event_system.force_victory.connect(_on_force_victory)
	event_system.force_defeat.connect(_on_force_defeat)
	
	# 7. AI controller para este capítulo.
	ai_controller = AIController.new(grid, project_data)
	
	# 8. Disparar event level_start.
	await event_system.trigger_event("level_start", {})


## Detecta el nid del lord del capítulo (la unidad con tag "Lord" del bando
## jugador).  Devuelve "" si no se encuentra.
func _detect_lord_nid() -> String:
	for u in player_units:
		if u != null and "Lord" in u.tags:
			return u.unit_name
	# Fallback: la primera unidad del jugador.
	if not player_units.is_empty():
		return player_units[0].unit_name
	return ""


# ══════════════════════════════════════════════════════════════════════════════
# OBJETIVOS Y REFUERZOS
# ══════════════════════════════════════════════════════════════════════════════

## Evaluación del objetivo del capítulo — invocada en check_victory_conditions.
func _evaluate_objective() -> void:
	if current_objective == null:
		return
	if current_objective.check_victory(player_units, enemy_units, current_turn):
		current_state = GameState.VICTORY
		game_state_changed.emit(GameState.VICTORY)
		print("\n=== VICTORY! [%s] ===" % current_objective.get_summary())
		if event_system:
			await event_system.trigger_event("level_end", {})
	elif current_objective.check_defeat(player_units, current_turn):
		current_state = GameState.GAME_OVER
		game_state_changed.emit(GameState.GAME_OVER)
		print("\n=== GAME OVER ===")


## Procesa refuerzos al inicio del turno enemigo.
func _process_reinforcements() -> void:
	if reinforcements.is_empty():
		return
	var spawned := AIController.process_reinforcements(reinforcements,
			current_turn, fired_event_names, project_data)
	for u in spawned:
		_ensure_unit_layer().add_child(u)
		grid.place_unit(u, u.grid_position)
		if u.is_player_unit:
			player_units.append(u)
		else:
			enemy_units.append(u)
		print("[Reinforcement] %s spawns at %s" % [u.unit_name, u.grid_position])


# ══════════════════════════════════════════════════════════════════════════════
# CALLBACKS DE EVENTOS
# ══════════════════════════════════════════════════════════════════════════════

func _on_force_victory() -> void:
	current_state = GameState.VICTORY
	game_state_changed.emit(GameState.VICTORY)

func _on_force_defeat() -> void:
	current_state = GameState.GAME_OVER
	game_state_changed.emit(GameState.GAME_OVER)


# ══════════════════════════════════════════════════════════════════════════════
# GEN 1 → GEN 2 (FE4 substitutes)
# ══════════════════════════════════════════════════════════════════════════════

## Registra el matrimonio de una madre potencial — el GameManager lo invoca
## desde el sistema de Love cuando una pareja alcanza el rango Married.
##   father_data debe ser { nid, bases, growths, holy_blood }.
func record_marriage(mother_id: String, father_id: String, father_data: Dictionary) -> void:
	if not mother_states.has(mother_id):
		mother_states[mother_id] = { "alive": true, "married_to": "", "father_data": {} }
	mother_states[mother_id]["married_to"] = father_id
	mother_states[mother_id]["father_data"] = father_data


## Resuelve la generación 2 — itera todas las madres y para cada una
## decide hijo canónico vs sustituto.  Devuelve { nid → unit_data }.
##   Llamar UNA SOLA VEZ al pasar de cap 5 a cap 6.
##   El caller recibe los datos y se encarga de instanciar las Units
##   (típicamente vía LevelLoader del cap 6).
func resolve_generation_2() -> Dictionary:
	var out := {}
	const MOTHERS := ["Aideen", "Ayra", "Lachesis", "Sylvia", "Erinys", "Brigid", "Tailtiu"]
	for mother_id in MOTHERS:
		var state: Dictionary = mother_states.get(mother_id,
			{ "alive": true, "married_to": "", "father_data": {} })
		var pair := SubstituteSystem.resolve_gen2_units(mother_id, state)
		# resolve_gen2_units devuelve null para canónicos (STUB) hasta que
		# se implemente _build_canonical_child.  Solo añadimos lo que
		# realmente sea sustituto.
		if pair.get("male") != null:
			out[pair["male"]["nid"]] = pair["male"]["data"]
		if pair.get("female") != null:
			out[pair["female"]["nid"]] = pair["female"]["data"]
	return out


## Spawn una unidad por nid (referenciado por EventSystem._cmd_spawn_unit).
##   Construye la unidad reusando LevelLoader.build_unit con datos del
##   project_data, la coloca en pos y la asigna al equipo correspondiente.
func spawn_unit_by_nid(nid: String, pos: Vector2i, team: String = "enemy") -> Unit:
	var udef := {
		"nid": nid,
		"team": team,
		"starting_position": [pos.x, pos.y],
		"generic": false,
		"ai": "Pursue",
	}
	var unit = LevelLoader.build_unit(udef, project_data)
	if unit == null:
		push_warning("[GameManager] spawn_unit_by_nid: no se pudo construir %s" % nid)
		return null
	_ensure_unit_layer().add_child(unit)
	unit.grid_position = pos
	grid.place_unit(unit, pos)
	if team == "player":
		player_units.append(unit)
	else:
		enemy_units.append(unit)
	# Recalcular FoW por si la nueva unidad es del jugador.
	if fow_system and team == "player":
		fow_system.update_team_vision("player", player_units)
	return unit


## Mueve una unidad entre listas de bandos — invocado por EventSystem
## change_team para cambiar la lealtad.
func move_unit_to_team(unit: Unit, new_team: String) -> void:
	if unit == null:
		return
	player_units.erase(unit)
	enemy_units.erase(unit)
	unit.is_player_unit = (new_team == "player")
	if new_team == "player":
		player_units.append(unit)
	else:
		enemy_units.append(unit)


func setup_test_scenario():
	"""Crea un escenario de prueba con algunas unidades"""
	# Crear armas de prueba — usando la API real de Weapon (Weapon.gd).
	var iron_sword: Weapon = Weapon.new()
	iron_sword.id = "Iron Sword"
	iron_sword.name = "Iron Sword"
	iron_sword.weapon_type = "Sword"
	iron_sword.might = 5
	iron_sword.accuracy = 90
	iron_sword.critical = 0
	iron_sword.weight = 5
	iron_sword.min_range = 1
	iron_sword.max_range = 1
	
	var iron_lance: Weapon = Weapon.new()
	iron_lance.id = "Iron Lance"
	iron_lance.name = "Iron Lance"
	iron_lance.weapon_type = "Lance"
	iron_lance.might = 7
	iron_lance.accuracy = 80
	iron_lance.weight = 8
	iron_lance.min_range = 1
	iron_lance.max_range = 1
	
	# Crear unidad del jugador
	var player_unit = Unit.new()
	player_unit.unit_name = "Eirika"
	player_unit.unit_class = "Lord"
	player_unit.is_player_unit = true
	player_unit.max_hp = 25
	player_unit.current_hp = 25
	player_unit.strength = 7
	player_unit.skill = 8
	player_unit.speed = 9
	player_unit.defense = 5
	player_unit.weapon = iron_sword
	add_child(player_unit)
	grid.place_unit(player_unit, Vector2i(2, 4))
	player_units.append(player_unit)
	
	# Crear unidad enemiga
	var enemy_unit = Unit.new()
	enemy_unit.unit_name = "Brigand"
	enemy_unit.unit_class = "Fighter"
	enemy_unit.is_player_unit = false
	enemy_unit.max_hp = 20
	enemy_unit.current_hp = 20
	enemy_unit.strength = 6
	enemy_unit.skill = 4
	enemy_unit.speed = 4
	enemy_unit.defense = 3
	enemy_unit.weapon = iron_lance
	add_child(enemy_unit)
	grid.place_unit(enemy_unit, Vector2i(7, 4))
	enemy_units.append(enemy_unit)
	
	print("Test scenario created!")
	print("Player units: ", player_units.size())
	print("Enemy units: ", enemy_units.size())
