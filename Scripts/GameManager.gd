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
	# Durante la cinemática de combate, ignorar clics del mapa.
	if _combat_busy:
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


# ══════════════════════════════════════════════════════════════════════════════
# EVENTOS DE ITEM (Return Ring / báculo Return, etc.)
# ══════════════════════════════════════════════════════════════════════════════

## Punto de entrada que ItemSystem._fire_event llama al usar un item con
## event_on_use. Despacha al handler concreto.
func trigger_item_event(event_id: String, user, target) -> void:
	match event_id:
		"ReturnToHomeCastle":
			# El Return Ring se auto-apunta (target == user → vuelve el portador);
			# el báculo Return apunta a un aliado (vuelve el aliado).
			_return_to_home_castle(target if target != null else user)
		_:
			push_warning("GameManager: evento de item no implementado '%s'" % event_id)

## Posición del castillo principal del capítulo: la región llamada "Return"
## (así se marca en los .ltproj de FE4/FE5). Fallback: primera región de
## formación (zona de despliegue del jugador). (-1,-1) si no hay ninguna.
func _home_castle_position() -> Vector2i:
	if not has_meta("chapter_regions"):
		return Vector2i(-1, -1)
	var regions: Array = get_meta("chapter_regions")
	for r in regions:
		if r is Dictionary and str(r.get("nid", "")) == "Return":
			return r.get("position", Vector2i(-1, -1))
	for r in regions:
		if r is Dictionary and str(r.get("region_type", "")) == "formation":
			return r.get("position", Vector2i(-1, -1))
	return Vector2i(-1, -1)

## Casilla libre y caminable más cercana a `center` (BFS por anillos). El grid
## debe tener la unidad ya retirada para no chocar consigo misma.
func _nearest_free_tile(center: Vector2i) -> Vector2i:
	if grid == null:
		return Vector2i(-1, -1)
	var visited := {center: true}
	var queue: Array[Vector2i] = [center]
	var guard := 0
	while not queue.is_empty() and guard < 4000:
		guard += 1
		var p: Vector2i = queue.pop_front()
		if grid.is_walkable(p):   # válida + sin unidad + terreno caminable
			return p
		for n in grid.get_neighbors(p):
			if not visited.has(n):
				visited[n] = true
				queue.append(n)
	return Vector2i(-1, -1)

## Teleporta `unit` al castillo principal (o a la casilla libre más cercana).
## Consume el turno de la unidad (has_moved). No hace nada si no hay castillo
## o no hay casilla libre.
func _return_to_home_castle(unit) -> void:
	if unit == null or grid == null:
		return
	var home := _home_castle_position()
	if home == Vector2i(-1, -1):
		push_warning("GameManager: sin región 'Return'/formación; no se puede volver al castillo")
		return
	var from: Vector2i = unit.grid_position
	grid.remove_unit(from)                  # retirar antes de buscar hueco
	var dest := _nearest_free_tile(home)
	if dest == Vector2i(-1, -1):
		grid.place_unit(unit, from)         # revertir: vuelve a su sitio
		push_warning("GameManager: sin casilla libre junto al castillo principal")
		return
	grid.place_unit(unit, dest)             # fija grid_position + global_position
	unit.has_moved = true                   # gasta el turno
	unit_moved.emit(unit, from, dest)
	if fow_system:
		fow_system.update_team_vision("player", player_units)


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
	# Dance (Refresh): solo si hay aliados adyacentes que ya actuaron.
	if MapActions.can_refresh(selected_unit) \
			and MapActions.get_refresh_targets(selected_unit, grid).size() > 0:
		options.append({ "id": "dance", "text": "Dance" })
	if _unit_has_usable_item(selected_unit):
		options.append({ "id": "item", "text": "Item" })
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
		"item":
			_show_item_menu(selected_unit)
		"dance":
			# FE4: refresca a todos los aliados adyacentes que ya actuaron.
			MapActions.execute_refresh(selected_unit, grid, "fe4")
			end_unit_action()
		_:  # "wait" y cualquier fallback seguro
			end_unit_action()


# ══════════════════════════════════════════════════════════════════════════════
# USO DE OBJETOS EN EL MAPA (acción "Item")
# ══════════════════════════════════════════════════════════════════════════════

## Consumibles del inventario que se pueden USAR en el campo sobre el portador
## (no rings pasivos on_hold, no armas). Duck-typed sobre ConsumableData.
func _unit_usable_items(unit) -> Array:
	var out: Array = []
	if unit == null:
		return out
	for it in unit.inventory:
		if _is_usable_consumable(it, unit):
			out.append(it)
	return out

func _unit_has_usable_item(unit) -> bool:
	return not _unit_usable_items(unit).is_empty()

## ¿Es un consumible de auto-uso en el campo? (ConsumableData con efecto activo).
func _is_usable_consumable(it, unit = null) -> bool:
	if it == null or it is Weapon:
		return false
	if "status_on_hold" in it and str(it.status_on_hold) != "":
		return false   # ring pasivo: aplica su efecto mientras se porta, no se "usa"
	if "uses" in it and int(it.uses) == 0:
		return false
	if "heal" in it and int(it.heal) > 0:
		return true
	if "status_on_hit" in it and str(it.status_on_hit) != "":
		return true   # manual: enseña skill
	if "permanent_stat_change" in it and not (it.permanent_stat_change as Dictionary).is_empty():
		return true
	if "restore_specific" in it and str(it.restore_specific) != "":
		return true
	if "restore" in it and bool(it.restore):
		return true
	if _item_component(it, "event_on_use") != null:
		return true   # Return Ring, etc.
	if _item_component(it, "status_applied") != null:
		return true   # Holy Water (buff temporal), etc.
	# Llave/ganzúa: solo si hay una casilla adyacente cerrada que abrir.
	if _item_component(it, "can_unlock") != null:
		return unit != null and _adjacent_unlockable(unit) != Vector2i(-1, -1)
	return false

## Posición de una casilla adyacente CERRADA (puerta/cofre/puente bloqueado) que
## una llave puede abrir, o (-1,-1). "Cerrada" = terreno door/chest/bridge y no
## transitable (el mapa las coloca con walkable=false hasta abrirlas).
func _adjacent_unlockable(unit) -> Vector2i:
	if unit == null or grid == null:
		return Vector2i(-1, -1)
	for n in grid.get_neighbors(unit.grid_position):
		if grid.tiles.has(n):
			var t: Dictionary = grid.tiles[n]
			var terr := str(t.get("terrain_type", "plain"))
			if terr in ["door", "chest", "bridge"] and not bool(t.get("walkable", true)):
				return n
	return Vector2i(-1, -1)

## Aplica el status de un item consumible sobre la unidad.
func _apply_item_status(unit, sid: String) -> void:
	match sid:
		"HolyWater":
			# FE5: sube MAG +7 y decae 1/turno (Unit._apply_status_upkeep lo baja).
			unit.add_status_modifier("HolyWater", {"MAG": 7})
			unit.apply_status("HolyWater", {})
		"CurePoison":
			unit.remove_status("Poison")
		_:
			unit.apply_status(sid, {})

## Abre la casilla (puerta/cofre/puente): la vuelve transitable. Si es un cofre
## con contenido (tiles[pos]["contents"] = item_nid), lo entrega al que abre.
func _unlock_tile(pos: Vector2i, opener = null) -> void:
	if grid == null or not grid.tiles.has(pos):
		return
	var t: Dictionary = grid.tiles[pos]
	t["walkable"] = true
	t["locked"] = false
	var terr := str(t.get("terrain_type", "plain"))
	if terr == "door" or terr == "bridge":
		t["terrain_type"] = "plain"    # queda abierta/transitable
	elif terr == "chest":
		# Contenido del cofre: el nivel lo define en tiles[pos]["contents"].
		var contents := str(t.get("contents", ""))
		if contents != "" and opener != null:
			_give_item(opener, contents)
			t["contents"] = ""         # cofre vaciado
	if fow_system:
		fow_system.update_team_vision("player", player_units)

## Entrega un item (por nid) a la unidad; si el inventario está lleno, al convoy.
func _give_item(unit, item_nid: String) -> void:
	var gdb = get_node_or_null("/root/GameDB")
	if gdb == null or not gdb.has_method("get_item"):
		return
	var item = gdb.get_item(item_nid)
	if item == null:
		return
	if item is Resource:
		item = item.duplicate(true)    # instancia propia (usos por-objeto)
	if "inventory" in unit and unit.inventory.size() < 5:
		unit.inventory.append(item)
		# El item nuevo puede llevar status_on_hold — recalcular efectos.
		if unit.has_method("refresh_item_effects"):
			unit.refresh_item_effects()
	else:
		var convoy = get_node_or_null("/root/Convoy")
		if convoy != null and convoy.has_method("deposit"):
			convoy.deposit(item)

## Lee un componente [key, val] de un ConsumableData (formato LT). null si falta.
func _item_component(it, key: String):
	if not ("components" in it):
		return null
	for c in it.components:
		if c is Array and c.size() >= 1 and str(c[0]) == key:
			return c[1] if c.size() > 1 else true
	return null

## Submenú con los objetos usables del inventario.
func _show_item_menu(unit) -> void:
	var items := _unit_usable_items(unit)
	if items.is_empty():
		show_action_menu()
		return
	var options: Array = []
	for i in items.size():
		var it = items[i]
		var nm: String = str(it.name) if ("name" in it and str(it.name) != "") else str(it.nid)
		if "uses" in it and int(it.uses) > 0:
			nm += "  (%d)" % int(it.uses)
		options.append({ "id": "use:%d" % i, "text": nm })
	options.append({ "id": "back", "text": "Back" })
	_close_action_menu()
	_action_menu = ActionMenu.new()
	_ensure_ui_layer().add_child(_action_menu)
	_action_menu.setup(options, _unit_menu_anchor(unit))
	_action_menu.action_selected.connect(_on_item_menu_selected)

func _on_item_menu_selected(id: String) -> void:
	_action_menu = null
	if id == "back":
		show_action_menu()
		return
	if id.begins_with("use:"):
		var idx := int(id.substr(4))
		var items := _unit_usable_items(selected_unit)
		if idx >= 0 and idx < items.size():
			_use_consumable(selected_unit, items[idx])
	end_unit_action()

## Aplica el efecto de un consumible sobre su portador y gasta un uso.
func _use_consumable(unit, item) -> void:
	if unit == null or item == null:
		return
	if "heal" in item and int(item.heal) > 0:
		unit.heal(int(item.heal))
	# Manual: enseña la(s) skill(s) (status_on_hit).
	if "status_on_hit" in item and str(item.status_on_hit) != "":
		for sk in str(item.status_on_hit).split(","):
			sk = sk.strip_edges()
			if sk != "" and not unit.has_skill(sk):
				unit.learn_skill(sk)
	# Boost permanente de stats.
	if "permanent_stat_change" in item:
		for stat in (item.permanent_stat_change as Dictionary):
			unit.increase_stat_permanently(str(stat), int(item.permanent_stat_change[stat]))
	# Restaurar estados.
	if "restore_specific" in item and str(item.restore_specific) != "":
		unit.remove_status(str(item.restore_specific))
	# Status aplicado por componente (Holy Water, etc.).
	var sa = _item_component(item, "status_applied")
	if sa != null and str(sa) != "":
		_apply_item_status(unit, str(sa))
	# Evento de item (Return Ring, etc.).
	var ev = _item_component(item, "event_on_use")
	if ev != null and str(ev) != "":
		trigger_item_event(str(ev), unit, unit)
	# Llave/ganzúa: abre la casilla cerrada adyacente.
	if _item_component(item, "can_unlock") != null:
		var lock_pos := _adjacent_unlockable(unit)
		if lock_pos != Vector2i(-1, -1):
			_unlock_tile(lock_pos, unit)
	# Gastar un uso; si se agota, retirar del inventario.
	if "uses" in item and int(item.uses) > 0:
		item.uses = int(item.uses) - 1
		if int(item.uses) <= 0:
			unit.inventory.erase(item)
	# Recalcular efectos pasivos (el inventario pudo cambiar).
	if unit.has_method("refresh_item_effects"):
		unit.refresh_item_effects()

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
	
	# HP inicial (calculate_combat aplica el daño de inmediato; lo guardamos
	# para poder REPRODUCIR el intercambio en la cinemática sin doble conteo).
	var atk_hp0: int = attacker.current_hp
	var def_hp0: int = defender.current_hp

	# Ejecutar combate
	var result = CombatSystem.calculate_combat(attacker, defender, distance, t_atk, t_def)

	print(result.get_summary())

	# Cinemática de combate (si AMBOS tienen animación resoluble). Restaura el HP
	# inicial, reproduce los golpes, y reaplica el HP final autoritativo. Si falta
	# alguna animación, se salta y el combate es instantáneo (comportamiento previo).
	if COMBAT_CINEMATIC and _combat_anims_available(attacker, defender):
		var atk_hp1: int = attacker.current_hp
		var def_hp1: int = defender.current_hp
		attacker.current_hp = atk_hp0
		defender.current_hp = def_hp0
		await _play_combat_cinematic(result)
		attacker.current_hp = atk_hp1   # HP final autoritativo (de calculate_combat)
		defender.current_hp = def_hp1
		if attacker.has_method("update_visual"): attacker.update_visual()
		if defender.has_method("update_visual"): defender.update_visual()

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


# ── Cinemática de combate (animaciones LT) ───────────────────────────────────
const COMBAT_CINEMATIC := true          # poner false para forzar combate instantáneo
const COMBAT_ANIM_SCALE := 5.0          # 240×160 nativo ×5 ≈ 1200×800 (tunable)
var _combat_busy: bool = false          # bloquea input del mapa durante la cinemática

## True mientras se reproduce la cinemática de combate.
func is_combat_busy() -> bool:
	return _combat_busy


## ¿Ambas unidades resuelven a una animación de combate existente?
func _combat_anims_available(a: Unit, b: Unit) -> bool:
	return _unit_has_anim(a) and _unit_has_anim(b)


func _unit_has_anim(u: Unit) -> bool:
	if u == null:
		return false
	var wt := ""
	var ranged := false
	var w = u.weapon if "weapon" in u else null
	if w != null:
		if "weapon_type" in w:
			wt = str(w.weapon_type)
		if "min_range" in w:
			ranged = int(w.min_range) > 1
	if wt == "":
		wt = "Unarmed"
	return CombatAnimDatabase.has_anim(CombatAnimResolver.resolve(u, wt, ranged))


## Muestra la escena de combate animada (CombatAnimScene) sobre un CanvasLayer,
## escalada y centrada, y espera a que termine. Fondo oscuro; degrada solo si
## faltan nodos opcionales (background/flash/HP bars).
func _play_combat_cinematic(result) -> void:
	_combat_busy = true
	var layer := CanvasLayer.new()
	layer.name = "CombatCinematic"
	layer.layer = 50
	add_child(layer)
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.07, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(bg)
	var scene := CombatAnimScene.new()
	scene.scale = Vector2(COMBAT_ANIM_SCALE, COMBAT_ANIM_SCALE)
	var vp := get_viewport().get_visible_rect().size
	scene.position = Vector2(
			(vp.x - 240.0 * COMBAT_ANIM_SCALE) * 0.5,
			(vp.y - 160.0 * COMBAT_ANIM_SCALE) * 0.5)
	layer.add_child(scene)
	await scene.play_combat(result)
	await get_tree().create_timer(0.35).timeout
	layer.queue_free()
	_combat_busy = false


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
				await initiate_combat(enemy, attacked)
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
