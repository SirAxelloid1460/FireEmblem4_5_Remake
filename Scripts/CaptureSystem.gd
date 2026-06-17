# CaptureSystem.gd
# Sistema de Captura — exclusivo de niveles FE5 (Thracia 776)
#
# SISTEMA DE CAPTURA — versión del proyecto (basada en FE5 con modificaciones):
#
#   CUALQUIER unidad melee puede intentar capturar. El resultado depende del BUILD:
#
#   BUILD capturador > BUILD objetivo → CAPTURA REAL (fiel a FE5):
#     • La unidad queda viva con 1 HP, cargada por el capturador
#     • Stats del portador a la mitad (STR/MAG/SKL/SPD/DEF), no HP ni LCK
#     • Si BUILD_capturado > BUILD_portador/2 → MOV también a la mitad
#     • Se puede saquear el inventario libremente
#     • Se puede transferir a otro aliado (TAKE) si tiene BUILD suficiente
#     • Al terminar de explotar al capturado, dos opciones:
#         LIBERAR  → se va del mapa, paga rescate en oro (BASE + nivel×100)
#         DESPACHAR → muere, da EXP al ejecutor
#
#   BUILD capturador <= BUILD objetivo → LOOT + KILL automático:
#     • El objetivo es saqueado al morir (todos sus items al capturador/convoy)
#     • La unidad muere normalmente, da EXP normal
#     • No hay opción de cargarla ni liberarla
#
#   Casos especiales (igual que FE5):
#     • Unidades sin arma → captura instantánea sin combate
#     • Unidades dormidas → pierden el montado, capturables como infantería
#     • Montados (no dormidos) → BUILD efectivo 20, solo capturables con BUILD 20+
#     • Los enemigos también pueden capturar unidades del jugador
#     • Si el enemigo escapa del mapa con una unidad → recuperable en capítulo especial
#
# INTEGRACIÓN CON COMBATSYSTEM:
#   - Cuando una unidad intenta capturar, se llama a CaptureSystem.begin_capture()
#     que aplica las penalizaciones y devuelve el modificador de stats
#   - CombatSystem detecta is_capture_attempt y usa stats modificadas
#   - Al llegar el defensor a 0 HP: CaptureSystem.on_capture_success()
#
# USO:
#   # En el GameManager, al elegir "Capture" en el menú de acción:
#   if CaptureSystem.can_capture(attacker, target):
#       CombatSystem.calculate_combat(attacker, target, dist,
#           terrain_atk, terrain_def, {"is_capture": true})
#
# SOLO SE ACTIVA cuando chapter.has_meta("is_fe5_chapter") == true

class_name CaptureSystem
extends RefCounted

const MOUNTED_BUILD := 20  # Las unidades montadas cuentan como BUILD 20
const CAPTURE_STAT_DIVISOR := 2  # Stats se dividen entre 2 al capturar/cargar
const MOV_HALVE_THRESHOLD := 2   # Si BUILD_capturado > BUILD_capturador / 2

# ── MODOS DE CAPTURA ─────────────────────────────────────────────────────────
#
# Cualquier unidad MELEE puede intentar capturar. El resultado depende del BUILD:
#
#   BUILD capturador > BUILD objetivo → CAPTURA REAL
#       La unidad queda viva, puede ser cargada, saqueada, transferida.
#       Al "liberarla": opción LIBERAR (rescate en oro) o DESPACHAR (matar).
#
#   BUILD capturador <= BUILD objetivo → LOOT + KILL
#       La unidad es saqueada automáticamente al morir.
#       No se puede cargar ni transferir.
#       No hay opción de liberarla — simplemente muere.

# Rescate en oro al liberar: BASE + nivel del capturado × multiplicador
const RANSOM_PER_TIER   := 150
const RANSOM_PER_LEVEL  := 25

# ── Condiciones ───────────────────────────────────────────────────────────────

## Cualquier unidad con arma de rango 1 puede intentar capturar
static func can_attempt_capture(captor: Unit, target: Unit) -> bool:
	if not _is_fe5_context(): return false
	# Solo melee (rango 1)
	if captor.weapon == null or captor.weapon.rng_min > 1: return false
	# Los bosses no pueden ser capturados
	if target.has_meta("is_boss") and target.get_meta("is_boss"): return false
	return true


## Si además tiene BUILD suficiente, la unidad quedará viva y capturable
static func will_truly_capture(captor: Unit, target: Unit) -> bool:
	return captor.constitution > _effective_build(target)


static func is_instant_capture(target: Unit) -> bool:
	if target.weapon == null: return true
	if _has_status(target, "Sleep"): return true
	return false


static func _effective_build(unit: Unit) -> int:
	if _is_mounted(unit) and not _has_status(unit, "Sleep"):
		return MOUNTED_BUILD
	return unit.constitution


# ── Penalizaciones al capturar ────────────────────────────────────────────────

## Devuelve un diccionario con los stats modificados para usar en CombatSystem
## durante el intento de captura. Los stats originales NO se tocan —
## CombatSystem multiplica el daño por los divisores correspondientes.
static func get_capture_penalties(captor: Unit) -> Dictionary:
	return {
		"is_capture_attempt": true,
		"str_div": CAPTURE_STAT_DIVISOR,
		"mag_div": CAPTURE_STAT_DIVISOR,
		"skl_div": CAPTURE_STAT_DIVISOR,
		"spd_div": CAPTURE_STAT_DIVISOR,
		"def_div": CAPTURE_STAT_DIVISOR,
		# HP y LCK no se dividen
	}


## Penalizaciones mientras se carga al capturado (después de capturar)
static func apply_carrying_penalties(carrier: Unit, captive: Unit) -> void:
	# STR, MAG, SKL, SPD, DEF a la mitad
	carrier.add_status_modifier("Carrying", {
		"STR": -carrier.strength / 2,
		"MAG": -carrier.magic   / 2,
		"SKL": -carrier.skill   / 2,
		"SPD": -carrier.speed   / 2,
		"DEF": -carrier.defense / 2,
	})

	# MOV también se reduce si BUILD del capturado > BUILD del portador / 2
	var mov_threshold := carrier.constitution / CAPTURE_STAT_DIVISOR
	if _is_mounted(carrier): mov_threshold += 5
	if captive.constitution > mov_threshold:
		carrier.add_status_modifier("CarryingHeavy", {
			"MOV": -carrier.movement / 2,
		})

	carrier.set_meta("captive", captive)
	carrier.set_meta("is_carrying_captive", true)


static func remove_carrying_penalties(carrier: Unit) -> void:
	carrier.remove_status_modifier("Carrying")
	carrier.remove_status_modifier("CarryingHeavy")
	if carrier.has_meta("captive"):    carrier.remove_meta("captive")
	if carrier.has_meta("is_carrying_captive"): carrier.remove_meta("is_carrying_captive")


# ── Resultado de la captura ───────────────────────────────────────────────────

## Llamar cuando el objetivo llega a 0 HP en un intento de captura.
## Gestiona automáticamente los dos modos según el BUILD.
static func on_capture_success(captor: Unit, captive: Unit) -> void:
	if will_truly_capture(captor, captive):
		# ── CAPTURA REAL: BUILD suficiente ────────────────────────────────────
		captive.current_hp = 1
		captive.set_meta("is_captured", true)
		captive.set_meta("captor", captor)
		apply_carrying_penalties(captor, captive)
		captor.end_turn()
		print("[Capture] %s capturó a %s (BUILD suficiente)" % [captor.unit_name, captive.unit_name])
	else:
		# ── LOOT + KILL: BUILD insuficiente ──────────────────────────────────
		_auto_loot(captor, captive)
		captive.die()
		captor.end_turn()
		print("[Capture] %s saqueó y eliminó a %s (BUILD insuficiente)" % [captor.unit_name, captive.unit_name])


## Saqueo automático: transfiere todos los items del objetivo al captor
## (o al convoy si el inventario está lleno)
static func _auto_loot(captor: Unit, target: Unit) -> void:
	var taken: Array = []
	for item in target.inventory.duplicate():
		if captor.inventory.size() < 5:
			captor.inventory.append(item)
			taken.append(item.name)
		else:
			# Inventario lleno → va al convoy del ejército
			var gm = _gm()
			if gm:
				gm.add_to_convoy(item)
			taken.append(item.name + " (convoy)")
	target.inventory.clear()
	if taken.size() > 0:
		print("[Capture] Items saqueados: %s" % ", ".join(taken))


## Saquear el inventario del capturado (intercambio libre)
static func loot_captive(captor: Unit, captive: Unit,
		item_index: int, target_unit: Unit = null) -> bool:
	if not captive.has_meta("is_captured"): return false
	if item_index >= captive.inventory.size(): return false

	var item = captive.inventory[item_index]
	var receiver := target_unit if target_unit != null else captor

	# El receptor debe tener espacio en el inventario
	if receiver.inventory.size() >= 5:  # max 5 items
		push_warning("[Capture] %s no tiene espacio para %s" % [receiver.unit_name, item.name])
		return false

	captive.inventory.remove_at(item_index)
	receiver.inventory.append(item)
	print("[Capture] %s tomó %s de %s" % [receiver.unit_name, item.name, captive.unit_name])
	return true


## Pasar el capturado a otro aliado (TAKE/SWAP)
static func transfer_captive(from_unit: Unit, to_unit: Unit) -> bool:
	if not from_unit.has_meta("is_carrying_captive"): return false

	var captive: Unit = from_unit.get_meta("captive")

	# El receptor debe tener BUILD > BUILD del capturado
	if not (to_unit.constitution > _effective_build(captive)):
		push_warning("[Capture] %s no tiene suficiente BUILD para cargar a %s" %
				[to_unit.unit_name, captive.unit_name])
		return false

	# Transferir
	remove_carrying_penalties(from_unit)
	apply_carrying_penalties(to_unit, captive)
	captive.set_meta("captor", to_unit)

	print("[Capture] %s transfirió a %s a %s" %
			[from_unit.unit_name, captive.unit_name, to_unit.unit_name])
	return true


## LIBERAR — la unidad enemiga se va del mapa y paga un rescate en oro
## El dinero va al pool compartido del ejército
static func release_captive(carrier: Unit) -> int:
	if not carrier.has_meta("is_carrying_captive"): return 0

	var captive: Unit = carrier.get_meta("captive")
	remove_carrying_penalties(carrier)
	captive.set_meta("is_captured", false)

	# Calcular rescate
	var tier := captive.get_class_tier() if captive.has_method("get_class_tier") else 1
	var ransom := (tier * RANSOM_PER_TIER) + (captive.level * RANSOM_PER_LEVEL)

	# Añadir al oro del ejército
	var gm = _gm()
	if gm:
		gm.add_gold(ransom)

	# La unidad se va del mapa (no cuenta como muerta — no da EXP)
	captive.queue_free()
	print("[Capture] %s liberado. Rescate recibido: %d oro" % [captive.unit_name, ransom])
	return ransom


## DESPACHAR — ejecutar al capturado (muere, cuenta como kill normal)
static func dispatch_captive(carrier: Unit, killer: Unit = null) -> void:
	if not carrier.has_meta("is_carrying_captive"): return

	var captive: Unit = carrier.get_meta("captive")
	remove_carrying_penalties(carrier)
	captive.set_meta("is_captured", false)

	# No da EXP — la EXP ya se obtuvo durante el combate de captura
	var executor := killer if killer != null else carrier
	captive.die()
	print("[Capture] %s despachó a %s" % [executor.unit_name, captive.unit_name])


# ── Captura enemiga (IA captura unidades del jugador) ─────────────────────────

## Verifica si un enemigo puede capturar esta unidad del jugador
static func enemy_can_capture(enemy: Unit, player_unit: Unit) -> bool:
	if not _is_fe5_context(): return false
	return enemy.constitution > _effective_build(player_unit)


## Cuando un enemigo captura una unidad del jugador y escapa del mapa
## → la unidad se pierde hasta el capítulo de rescate
static func on_player_unit_captured_and_escaped(unit: Unit) -> void:
	unit.set_meta("captured_by_enemy", true)
	unit.set_meta("recoverable_in_chapter", "21x")
	# Guardar inventario que perdió
	unit.set_meta("lost_inventory", unit.inventory.duplicate())
	unit.inventory.clear()
	print("[Capture] ¡%s fue capturado por el enemigo y se ha perdido!" % unit.unit_name)


# ── Helpers ───────────────────────────────────────────────────────────────────

## Acceso al autoload GameManager desde contexto estático (no hay self/get_node).
static func _gm() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("GameManager") if tree else null


static func _is_fe5_context() -> bool:
	var gm = _gm()
	if gm:
		return gm.has_meta("is_fe5_chapter") and gm.get_meta("is_fe5_chapter")
	return false


static func _is_mounted(unit: Unit) -> bool:
	if unit.has_method("has_tag"): return unit.has_tag("Mounted")
	return "Mounted" in unit.tags


static func _has_status(unit: Unit, status_id: String) -> bool:
	if unit.has_method("has_status"): return unit.has_status(status_id)
	return false


# ── Integración con CombatSystem ──────────────────────────────────────────────
# Para aplicar las penalizaciones de captura en el cálculo de combate,
# CombatSystem._calc_dmg() debe detectar el flag is_capture_attempt
# y dividir los stats ofensivos del atacante entre 2.
#
# Añadir en CombatSystem._calc_dmg() tras calcular stat_m:
#
#   if combat_flags.get("is_capture_attempt", false):
#       stat_m = stat_m / CAPTURE_STAT_DIVISOR
#       # DEF también se divide — ya reducida en calculate_hit via AS penalizado
#
# Y en calculate_attack_speed():
#   if combat_flags.get("is_capture_attempt", false):
#       spd = spd / 2  # SKL y SPD a la mitad reducen AS
#
# El parámetro combat_flags se pasa como diccionario adicional opcional
# a calculate_combat() junto con terrain_atk y terrain_def.
