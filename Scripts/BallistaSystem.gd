# BallistaSystem.gd
# Sistema de ballistas (siege/long-range) colocadas en el mapa.
#
# DEFINICIÓN CANÓNICA (FE5 LT-maker):
#   class Ballistae — tier 1, MOV=0, CON=60, HP=50, solo Bow C, ArenaIgnore.
#   La Ballista es una "unidad" en términos del engine: está sobre el grid,
#   tiene HP, puede atacar con su arco montado, y se enfrenta al jugador.
#
# REGLAS (lock):
#   • CAPTURABLE estilo FE5: el sistema reusa CaptureSystem.  Para
#     capturar la Ballista, una unidad de jugador adyacente debe usar
#     "Capture" sobre ella; la condición de BUILD se cumple si BUILD del
#     atacante > BUILD de la Ballista (CON=60, ¡imposible!).  Para hacer
#     viable la captura redefinimos:
#         - La Ballista NO opone resistencia a la captura (siempre se
#           captura si la unidad del jugador la golpea hasta dejarla a
#           1 HP usando el comando Capture).
#         - Una vez capturada, la Ballista NO se "lleva sobre el hombro";
#           queda en el tile y la unidad capturadora la "ocupa", pudiendo
#           dispararla en su próximo turno hasta que la abandone.
#   • Si una unidad del jugador es derrotada sobre la Ballista, ésta
#     vuelve a ser neutral y cualquiera puede ocuparla.
#   • La Ballista NO se puede mover.  MOV=0 hace que Pathfinding no
#     encuentre rutas para ella.
#   • Si la Ballista llega a 0 HP, se DESTRUYE (no da EXP — son objetos
#     de mapa, no enemigos vivos).
#
# DATOS DEL ARMA:
#   La Ballista usa un arma "Ballista" canónica con range 3-10 (siege),
#   might variable (Iron Ballista=8, Killer Ballista=10, Long Ballista=5
#   con range 4-15).  El arma forma parte del item de la unidad y se
#   descuenta usos al disparar.

class_name BallistaSystem
extends RefCounted

# ── Marcadores de estado ─────────────────────────────────────────────────────

## Estados posibles de una Ballista en el mapa.
const STATE_ENEMY    := "enemy"     # controlada por el bando enemigo
const STATE_NEUTRAL  := "neutral"   # nadie la opera, no dispara
const STATE_PLAYER   := "player"    # capturada y operada por jugador

# Tag canónico LT que identifica una unidad como ballista.
const BALLISTA_TAG   := "Ballistae"


# ══════════════════════════════════════════════════════════════════════════════
# IDENTIFICACIÓN
# ══════════════════════════════════════════════════════════════════════════════

## ¿Una unidad es una ballista?  Detección por tag canónico LT.
static func is_ballista(unit: Unit) -> bool:
	if unit == null:
		return false
	return BALLISTA_TAG in unit.tags


## Estado actual de la ballista — leído del meta de la Unit.
##   Las unidades Ballista tienen meta "ballista_state" que actualizan
##   capture/abandon/destroy.
static func get_state(unit: Unit) -> String:
	if not is_ballista(unit):
		return ""
	if unit.has_meta("ballista_state"):
		return str(unit.get_meta("ballista_state"))
	# Default: si is_player_unit ⇒ player; si tiene HP ⇒ enemy; muerta ⇒ neutral.
	if unit.is_player_unit:
		return STATE_PLAYER
	return STATE_ENEMY


# ══════════════════════════════════════════════════════════════════════════════
# CAPTURA
# ══════════════════════════════════════════════════════════════════════════════

## Intenta capturar una ballista enemiga.  Reglas simplificadas (no
## delegamos a CaptureSystem porque BUILD=60 lo haría imposible):
##   • La unidad atacante debe estar adyacente a la ballista.
##   • La ballista debe estar en estado ENEMY o NEUTRAL.
##   • La ballista no muere — pasa a estado PLAYER y is_player_unit=true.
##   • La unidad atacante NO se mueve al tile de la ballista; queda al
##     lado y la ballista permanece en su posición original (es un objeto
##     fijo del mapa, no se puede transportar).
##   • La unidad atacante consume su acción del turno (has_acted = true).
##
## Devuelve true si la captura se realizó.
static func attempt_capture(captor: Unit, ballista: Unit, grid: Grid) -> bool:
	if captor == null or ballista == null:
		return false
	if not is_ballista(ballista):
		return false
	if ballista.current_hp <= 0:
		return false
	# Adyacencia Manhattan == 1.
	var dx: int = abs(captor.grid_position.x - ballista.grid_position.x)
	var dy: int = abs(captor.grid_position.y - ballista.grid_position.y)
	if dx + dy != 1:
		return false
	var state := get_state(ballista)
	if state == STATE_PLAYER:
		return false  # ya es nuestra
	# Cambio de bando.
	ballista.is_player_unit = true
	ballista.set_meta("ballista_state", STATE_PLAYER)
	captor.has_acted = true
	captor.has_moved = true
	if captor.has_method("update_visual"):
		captor.update_visual()
	return true


## Abandona la ballista — vuelve a estado NEUTRAL.  Cualquier unidad
## puede capturarla después.  Útil si el jugador prefiere mover la
## unidad a otro sitio sin destruir la ballista.
static func abandon(ballista: Unit) -> void:
	if not is_ballista(ballista):
		return
	ballista.is_player_unit = false
	ballista.set_meta("ballista_state", STATE_NEUTRAL)


# ══════════════════════════════════════════════════════════════════════════════
# DAÑO Y DESTRUCCIÓN
# ══════════════════════════════════════════════════════════════════════════════

## Hook al recibir daño.  Si HP llega a 0, la ballista se destruye
## (se elimina del grid, NO se cuenta como kill para EXP — son objetos).
##   Devuelve true si la ballista fue destruida.
static func on_damage_taken(ballista: Unit, grid: Grid) -> bool:
	if not is_ballista(ballista):
		return false
	if ballista.current_hp > 0:
		return false
	# Destrucción: limpiar tile, eliminar Unit del juego.
	if grid != null:
		grid.remove_unit(ballista.grid_position)
	if ballista.has_method("queue_free"):
		ballista.queue_free()
	return true


## Override de EXP: las ballistas NO dan EXP al ser destruidas.  El
## CombatSystem debe llamar a esta función para decidir si conceder EXP
## al atacante después de matar a la unidad.
static func grants_exp_on_kill(victim: Unit) -> bool:
	if is_ballista(victim):
		return false
	return true


# ══════════════════════════════════════════════════════════════════════════════
# DISPARO
# ══════════════════════════════════════════════════════════════════════════════

## ¿Una ballista puede disparar este turno?  Solo si:
##   • Es del bando que está en turno.
##   • No ha actuado ya.
##   • Tiene HP y arma con usos.
static func can_fire(ballista: Unit, current_team_is_player: bool) -> bool:
	if not is_ballista(ballista) or ballista.current_hp <= 0:
		return false
	if ballista.has_acted:
		return false
	var on_player_turn: bool = ballista.is_player_unit
	if on_player_turn != current_team_is_player:
		return false
	if ballista.weapon == null:
		return false
	# La presencia de uses la valida el ItemSystem; si current_uses == 0
	# el weapon queda no-usable y can_attack_at_range devolverá false.
	return true


# ══════════════════════════════════════════════════════════════════════════════
# UTILIDADES
# ══════════════════════════════════════════════════════════════════════════════

## Marcar una ballista al cargar el capítulo.  El LevelLoader llama esto
## al instanciar cada unidad con tag Ballistae para inicializar el meta
## "ballista_state".
static func initialize(ballista: Unit, initial_team: String = "enemy") -> void:
	if not is_ballista(ballista):
		return
	ballista.set_meta("ballista_state", initial_team)
	ballista.is_player_unit = (initial_team == STATE_PLAYER)
	# MOV=0 ya viene de la clase canónica.  Nos aseguramos por si el
	# JSON la deja sin definir (fallback).
	if ballista.movement > 0:
		ballista.movement = 0
