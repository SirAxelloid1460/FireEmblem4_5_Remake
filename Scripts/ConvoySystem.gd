# ConvoySystem.gd
# Almacén central de items del ejército — solo accesible desde el castillo.
#
# DECISIÓN DE DISEÑO (lock):
#   Solo se accede al convoy en el castillo (CastleBase / CastleFacilities).
#   No hay prep screen GBA-style en mitad del capítulo: una vez la unidad
#   sale del castillo, no puede sacar items del convoy hasta volver.  Esto
#   es más fiel a FE4 — donde el convoy NO existía y solo había Pawn Shop —
#   pero introducimos un convoy real para no perder items en muerte de unidad
#   y para tener un punto de transferencia entre capítulos.
#
# REGLAS:
#   • Al inicio del juego el convoy está vacío.
#   • Items que las unidades muertas dejan al morir entran al convoy
#     (constants.convoy_on_death = 1 en LT).
#   • Items comprados en tienda con inventario lleno entran al convoy.
#   • En castillo: el jugador puede mover items entre cualquier unidad
#     y el convoy libremente (sin coste, sin acción).
#   • Fuera del castillo (durante batalla): NO se puede acceder.
#     get_accessible() devuelve [] si is_in_castle == false.
#
# AUTOLOAD:
#   Para que sea accesible globalmente sin pasar referencias, este script
#   está pensado para registrarse como autoload en project.godot:
#       Convoy = res://Scripts/ConvoySystem.gd
#   y consumirse así: Convoy.deposit(item)
#   Si se prefiere instancia explícita, basta crear un Node con este script
#   y guardar la referencia en GameManager.

class_name ConvoySystem
extends Node


# ── Estado interno ────────────────────────────────────────────────────────────

## Lista plana de items en el convoy.  No hay límite de capacidad.
var items: Array = []

## Solo el castillo puede entrar/sacar.  El GameManager / CastleBase
## activan esta flag al entrar/salir del castillo.
var is_in_castle: bool = false

# ── Señales ──────────────────────────────────────────────────────────────────

signal item_deposited(item)
signal item_withdrawn(item)
signal convoy_changed()


# ══════════════════════════════════════════════════════════════════════════════
# CONTROL DE ACCESO
# ══════════════════════════════════════════════════════════════════════════════

## El CastleBase.gd llama enter_castle() al entrar y leave_castle() al salir.
func enter_castle() -> void:
	is_in_castle = true

func leave_castle() -> void:
	is_in_castle = false

## ¿El convoy es accesible ahora mismo?  (Para UIs que ocultan el botón.)
func is_accessible() -> bool:
	return is_in_castle


# ══════════════════════════════════════════════════════════════════════════════
# OPERACIONES BÁSICAS
# ══════════════════════════════════════════════════════════════════════════════

## Deposita un item en el convoy.  Funciona dentro o fuera del castillo
## porque las muertes de unidades en mapa también lo usan.
func deposit(item) -> void:
	if item == null:
		return
	items.append(item)
	item_deposited.emit(item)
	convoy_changed.emit()


## Saca un item del convoy.  Solo permitido en castillo.
##   Devuelve true si la operación tuvo éxito.
func withdraw(item) -> bool:
	if not is_in_castle:
		push_warning("ConvoySystem: withdraw() solo permitido en castillo")
		return false
	if not items.has(item):
		return false
	items.erase(item)
	item_withdrawn.emit(item)
	convoy_changed.emit()
	return true


## Lista de items accesibles desde la UI.  Devuelve copia para que el
## caller no pueda mutar la lista original.
func get_accessible() -> Array:
	if not is_in_castle:
		return []
	return items.duplicate()


## Total de items en el convoy.  Siempre disponible (no requiere castillo)
## para que la UI de save/cap-clear pueda mostrar "Convoy: 12 items".
func count() -> int:
	return items.size()


# ══════════════════════════════════════════════════════════════════════════════
# TRANSFERENCIAS UNIDAD ↔ CONVOY
# ══════════════════════════════════════════════════════════════════════════════

## Transfiere un item del inventario de una unidad al convoy.
##   Devuelve true si tuvo éxito.
func transfer_unit_to_convoy(unit: Unit, item) -> bool:
	if not is_in_castle:
		return false
	if unit == null or item == null:
		return false
	if not unit.inventory.has(item):
		return false
	unit.inventory.erase(item)
	deposit(item)
	# Si el item era arma equipada, la unidad la pierde — quien usa este
	# sistema debe re-evaluar weapon equipado tras la transferencia.
	if "weapon" in unit and unit.weapon == item:
		unit.weapon = null
	# Recalcular efectos pasivos: el item ya no está en el inventario/equipo.
	if unit.has_method("refresh_item_effects"):
		unit.refresh_item_effects()
	return true


## Transfiere un item del convoy al inventario de una unidad.
##   Devuelve true si tuvo éxito.  Falla si la unidad ya tiene el inventario
##   lleno (límite estándar 5 — leído de constants).
func transfer_convoy_to_unit(unit: Unit, item, max_inventory: int = 5) -> bool:
	if not is_in_castle:
		return false
	if unit == null or item == null:
		return false
	if unit.inventory.size() >= max_inventory:
		return false
	if not items.has(item):
		return false
	if not withdraw(item):
		return false
	unit.inventory.append(item)
	# Recalcular efectos pasivos: el item nuevo puede llevar status_on_hold.
	if unit.has_method("refresh_item_effects"):
		unit.refresh_item_effects()
	return true


# ══════════════════════════════════════════════════════════════════════════════
# AUTOMATISMOS
# ══════════════════════════════════════════════════════════════════════════════

## Llamado por GameManager cuando una unidad muere — todos sus items
## entran al convoy.  Funciona DURANTE la batalla, sin importar
## is_in_castle (es un drop automático, no acción de jugador).
func absorb_dead_unit_inventory(unit: Unit) -> void:
	if unit == null:
		return
	for it in unit.inventory:
		if it != null:
			items.append(it)
	unit.inventory.clear()
	if "weapon" in unit:
		unit.weapon = null
	convoy_changed.emit()


## Llamado por ShopPanel cuando se compra un item con el inventario del
## comprador lleno.  Se deposita directo.
func absorb_purchase(item) -> void:
	deposit(item)


# ══════════════════════════════════════════════════════════════════════════════
# CONSULTAS
# ══════════════════════════════════════════════════════════════════════════════

## Filtra el convoy por categoría/tipo.  Útil para UI que separa armas,
## consumibles, etc.
func filter_by_category(category: String) -> Array:
	if not is_in_castle:
		return []
	var out: Array = []
	for it in items:
		if it != null and "category" in it and str(it.category) == category:
			out.append(it)
	return out


## ¿El convoy contiene un item con el id dado?
func has_item_with_id(item_id: String) -> bool:
	for it in items:
		if it != null and "id" in it and str(it.id) == item_id:
			return true
	return false
