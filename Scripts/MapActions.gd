# MapActions.gd
# Acciones de mapa especiales: Refresh (Dancer) y Steal (Thief).
#
# REFRESH (FE4 style — distinto de GBA):
#   En FE4 Sylvia (y en gen 2 Lene/Laylea) "danzaban" devolviendo el turno
#   a TODAS las unidades aliadas adyacentes ya movidas (1-tile radius, 4
#   direcciones).  En FE GBA solo se podía refrescar a 1 unidad por uso.
#   Para FE5: Lara (Dancer) refresca a 1 unidad como en GBA.
#
#   Implementamos dos modos seleccionables por el caller:
#     • "fe4" — refresca todos los adyacentes (Sylvia, Lene, Laylea).
#     • "fe5" — refresca solo el target seleccionado (Lara).
#
# STEAL (FE4/5 style):
#   • Solo unidades con la skill "Steal" (Thief tiers nativos) o que
#     porten un Thief Ring pueden ejecutar Steal.
#   • Condición: SPD del ladrón > SPD del objetivo (estricto).
#   • En FE5 también requiere BUILD del ladrón > Item.weight.  En FE4
#     no había BUILD check.  Implementamos ambos modos.
#   • Solo items NO equipados son robables.  En FE4/5 el arma equipada
#     no se puede robar bajo ninguna circunstancia.
#   • Adyacencia obligatoria (1 tile, 4 direcciones).
#
# CONEXIÓN:
#   El menú de acción de unidad (UnitMenu.gd futuro) llama a:
#       MapActions.can_refresh(unit) → mostrar entrada "Dance"
#       MapActions.can_steal(unit, grid) → mostrar entrada "Steal"
#   y al confirmar:
#       MapActions.execute_refresh(unit, grid, mode)
#       MapActions.execute_steal(thief, victim, item)

class_name MapActions
extends RefCounted


# ══════════════════════════════════════════════════════════════════════════════
# REFRESH (Dancer)
# ══════════════════════════════════════════════════════════════════════════════

## ¿La unidad puede ejecutar Refresh?
##   Los Dancers/Bards tienen skill "Refresh" o tag "Dancer".
static func can_refresh(unit: Unit) -> bool:
	if unit == null or unit.current_hp <= 0:
		return false
	if unit.has_acted:
		return false
	if "Dancer" in unit.tags or "Bard" in unit.tags:
		return true
	if unit.has_method("has_skill") and unit.has_skill("Refresh"):
		return true
	return false


## Lista de unidades aliadas adyacentes que pueden ser refrescadas
## (que ya hayan actuado).  Usado por el target picker.
static func get_refresh_targets(dancer: Unit, grid: Grid) -> Array:
	var out: Array = []
	if not can_refresh(dancer) or grid == null:
		return out
	var p := dancer.grid_position
	var deltas := [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]
	for d in deltas:
		var u: Unit = grid.get_unit_at(p + d)
		if u == null or u == dancer:
			continue
		if u.is_player_unit != dancer.is_player_unit:
			continue
		if not u.has_acted:
			continue
		out.append(u)
	return out


## Ejecuta Refresh.
##   mode == "fe4" → refresca a todos los adyacentes (Sylvia/Lene/Laylea).
##   mode == "fe5" → refresca al target seleccionado únicamente.
##   target — solo se usa en modo fe5.
##
## Devuelve la lista de unidades refrescadas.
static func execute_refresh(dancer: Unit, grid: Grid,
		mode: String = "fe4", target: Unit = null) -> Array:
	if not can_refresh(dancer) or grid == null:
		return []
	var refreshed: Array = []
	var targets := get_refresh_targets(dancer, grid)
	if mode == "fe5":
		if target == null or not (target in targets):
			return []
		_refresh_unit(target)
		refreshed.append(target)
	else:
		for t in targets:
			_refresh_unit(t)
			refreshed.append(t)
	# El propio Dancer consume su acción.
	dancer.has_acted = true
	dancer.has_moved = true
	if dancer.has_method("update_visual"):
		dancer.update_visual()
	return refreshed


## Helper interno: marca una unidad como NO actuada y refresca su visual.
static func _refresh_unit(u: Unit) -> void:
	u.has_acted = false
	u.has_moved = false
	if u.has_method("update_visual"):
		u.update_visual()


# ══════════════════════════════════════════════════════════════════════════════
# STEAL
# ══════════════════════════════════════════════════════════════════════════════

const _THIEF_CLASSES := ["Thief", "AThief", "BThief", "Rogue",
		"ThiefFighter", "Assassin"]

## ¿La unidad puede ejecutar Steal?
##   Tiene skill "Steal", clase ladrón, o lleva un Thief Ring.
static func can_steal(thief: Unit, _grid: Grid = null) -> bool:
	if thief == null or thief.current_hp <= 0 or thief.has_acted:
		return false
	if thief.unit_class in _THIEF_CLASSES:
		return true
	if thief.has_method("has_skill") and thief.has_skill("Steal"):
		return true
	# Thief Ring otorga skill temporal; ya cubierto por has_skill().
	return false


## Items robables del inventario de la víctima.
##   Reglas: items NO equipados (la arma equipada NO se roba).
##   En FE5 con BUILD check: además item.weight < thief.constitution.
static func get_stealable_items(thief: Unit, victim: Unit,
		use_build_check: bool = true) -> Array:
	var out: Array = []
	if thief == null or victim == null:
		return out
	if victim.inventory == null:
		return out
	for it in victim.inventory:
		if it == null:
			continue
		# Item equipado nunca robable (en FE4/5 esto es dura regla).
		if "weapon" in victim and victim.weapon == it:
			continue
		# BUILD check FE5 (opcional):
		if use_build_check and "weight" in it:
			if int(it.weight) >= thief.constitution:
				continue
		out.append(it)
	return out


## Intenta robar un item concreto.
##   Verifica:
##     • can_steal(thief) y target válido
##     • adyacencia (Manhattan == 1)
##     • thief.SPD > victim.SPD (estricto, canon FE)
##     • item está en stealable_items
##     • inventario del ladrón con espacio (max 5)
##
## Devuelve true si el robo se realizó.
static func execute_steal(thief: Unit, victim: Unit, item,
		max_inventory: int = 5, use_build_check: bool = true) -> bool:
	if not can_steal(thief):
		return false
	if victim == null or item == null:
		return false
	# Adyacencia.
	var dx: int = abs(thief.grid_position.x - victim.grid_position.x)
	var dy: int = abs(thief.grid_position.y - victim.grid_position.y)
	if dx + dy != 1:
		return false
	# SPD check estricto.
	if thief.speed <= victim.speed:
		return false
	# El item debe estar en la lista de robables (re-evalúa para evitar
	# skip de validaciones desde un caller poco fiable).
	var stealable := get_stealable_items(thief, victim, use_build_check)
	if not (item in stealable):
		return false
	# Inventario del ladrón.
	if thief.inventory.size() >= max_inventory:
		return false
	# Transferir.
	victim.inventory.erase(item)
	thief.inventory.append(item)
	# El ítem pudo cambiar de manos con un status_on_hold: recalcular pasivos.
	if victim.has_method("refresh_item_effects"):
		victim.refresh_item_effects()
	if thief.has_method("refresh_item_effects"):
		thief.refresh_item_effects()
	# Steal consume la acción del turno (en FE clásico, Steal SÍ consume
	# la acción — distinto de Open/Door, que en FE5 no la consumían).
	thief.has_acted = true
	thief.has_moved = true
	if thief.has_method("update_visual"):
		thief.update_visual()
	return true


## Probabilidad de éxito del robo — en FE clásico es determinístico
## (cumple las condiciones o no).  Esta función expone un porcentaje
## SIMBÓLICO (100 si todas las condiciones se cumplen, 0 si no) para
## que el preview UI pueda mostrar feedback uniforme con el resto de
## acciones que sí tienen tirada.
static func steal_success_chance(thief: Unit, victim: Unit, item,
		use_build_check: bool = true) -> int:
	if not can_steal(thief) or victim == null or item == null:
		return 0
	if thief.speed <= victim.speed:
		return 0
	if not (item in get_stealable_items(thief, victim, use_build_check)):
		return 0
	return 100
