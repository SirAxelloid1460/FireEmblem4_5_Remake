# LaraPromotion.gd
# Maneja la ruta de promoción especial del personaje Lara (Thracia 776).
#
# === COMPORTAMIENTO CANÓNICO ===
#
# Lara tiene una ruta de promoción única en FE5:
#
#   1. Empieza como Thief.
#   2. Puede promocionar a Rogue normalmente con un Knight Proof.
#   3. En el Capítulo 12x, si habla con Perne:
#        - Si ya es Rogue → promociona Rogue → Dancer.
#        - Si todavía es Thief → promociona Thief → Dancer.
#   4. Una vez Dancer, puede usar otro Knight Proof para promocionar
#      Dancer → Rogue.
#   5. Por balance: Rogue y Dancer en Lara COMPARTEN el nivel.
#      Promocionar de uno a otro mantiene el level y la EXP acumulada.
#
# === API ===
#
#   LaraPromotion.is_lara(unit)                           → bool
#   LaraPromotion.can_perne_event_promote(unit)           → bool
#   LaraPromotion.perne_event_promote(unit)               → String (nueva clase)
#   LaraPromotion.can_use_knight_proof(unit)              → bool
#   LaraPromotion.knight_proof_promote(unit)              → String
#   LaraPromotion.shared_level_swap(unit, target_class)   → void
#
# === INTEGRACIÓN ===
#
# El sistema de items debería invocar can_use_knight_proof() antes de
# permitir que Knight Proof se use en Lara, para validar la dirección de
# la promoción.
#
# El evento del cap 12x debe llamar perne_event_promote() cuando Lara
# habla con Perne.

class_name LaraPromotion
extends RefCounted


## NID canónico del personaje Lara.  Si quieres usar otro identificador,
## cámbialo aquí — todo el código se basa en este string.
const LARA_NID: String = "Lara"

## Clases válidas en la ruta de Lara.
const CLASS_THIEF:  String = "Thief"
const CLASS_ROGUE:  String = "Rogue"
const CLASS_DANCER: String = "Dancer"


## Devuelve true si el unit es Lara.
static func is_lara(unit) -> bool:
	if unit == null:
		return false
	if not "unit_name" in unit:
		return false
	# Comparamos por nid si existe, o por unit_name como fallback.
	if "nid" in unit and str(unit.nid) == LARA_NID:
		return true
	return str(unit.unit_name) == LARA_NID


# ══════════════════════════════════════════════════════════════════════════════
# EVENTO DE PERNE (CAP 12x)
# ══════════════════════════════════════════════════════════════════════════════

## ¿Puede Lara recibir el efecto del evento Perne ahora mismo?
## Solo si es Lara y está en Thief o Rogue.
static func can_perne_event_promote(unit) -> bool:
	if not is_lara(unit):
		return false
	var current: String = str(unit.unit_class) if "unit_class" in unit else ""
	return current == CLASS_THIEF or current == CLASS_ROGUE


## Aplica el efecto del evento Perne: promociona a Lara a Dancer
## conservando nivel y EXP.  Devuelve la nueva clase asignada.
##
## Lanza push_error si no aplica (validar antes con can_perne_event_promote).
static func perne_event_promote(unit) -> String:
	if not can_perne_event_promote(unit):
		push_error("LaraPromotion: perne_event_promote llamado en condiciones inválidas")
		return ""
	# Cambiar clase a Dancer manteniendo nivel y EXP.
	_swap_class(unit, CLASS_DANCER)
	return CLASS_DANCER


# ══════════════════════════════════════════════════════════════════════════════
# KNIGHT PROOF (PROMOCIÓN POR ITEM)
# ══════════════════════════════════════════════════════════════════════════════

## ¿Puede Lara usar un Knight Proof?
## - Si es Thief → puede (Thief → Rogue).
## - Si es Dancer → puede (Dancer → Rogue).
## - Si ya es Rogue → no puede (no hay promoción adicional).
##
## Notar: para personajes que NO son Lara, esta función devuelve false.
## El sistema de items general decide si Knight Proof aplica a otros
## personajes con su lógica habitual de promoción.
static func can_use_knight_proof(unit) -> bool:
	if not is_lara(unit):
		return false
	var current: String = str(unit.unit_class) if "unit_class" in unit else ""
	if current == CLASS_THIEF:
		return true
	if current == CLASS_DANCER:
		return true
	return false  # Rogue ya está en su tier final


## Aplica un Knight Proof a Lara.  Devuelve la nueva clase, "" si falló.
##   Thief  → Rogue  (promoción estándar)
##   Dancer → Rogue  (intercambio: nivel se conserva)
static func knight_proof_promote(unit) -> String:
	if not can_use_knight_proof(unit):
		push_error("LaraPromotion: knight_proof_promote en condiciones inválidas")
		return ""
	var current: String = str(unit.unit_class)
	if current == CLASS_THIEF:
		# Promoción estándar: Thief → Rogue.
		# El nivel debe resetearse a 1 si tu sistema de promoción lo hace
		# para todos.  Aquí seguimos esa convención: la conversión de
		# Thief a Rogue es una promoción "real", no un swap balanceado.
		_promote_class(unit, CLASS_ROGUE)
		return CLASS_ROGUE
	elif current == CLASS_DANCER:
		# Swap balanceado: Lara cambia entre Rogue y Dancer manteniendo
		# nivel/EXP (las dos clases comparten progresión por balance).
		_swap_class(unit, CLASS_ROGUE)
		return CLASS_ROGUE
	return ""


# ══════════════════════════════════════════════════════════════════════════════
# UTILIDADES INTERNAS
# ══════════════════════════════════════════════════════════════════════════════

## Cambia la clase del unit conservando nivel y EXP (swap balanceado entre
## Rogue y Dancer).  Refuerza tier 2 (promocionada).
static func _swap_class(unit, new_class_nid: String) -> void:
	if unit == null:
		return
	if "unit_class" in unit:
		unit.unit_class = new_class_nid
	if "class_tier" in unit:
		unit.class_tier = 2  # Rogue y Dancer son ambas tier 2 promocionadas.
	# El nivel y la EXP se conservan tal cual (esto es el swap, no
	# promoción nueva).


## Cambia la clase como promoción real (reset de nivel a 1 según convención
## del proyecto).
static func _promote_class(unit, new_class_nid: String) -> void:
	if unit == null:
		return
	if "unit_class" in unit:
		unit.unit_class = new_class_nid
	if "class_tier" in unit:
		unit.class_tier = 2
	if "level" in unit:
		unit.level = 1
	# La EXP también se reinicia si tu Unit la lleva por separado.
	if "exp" in unit:
		unit.exp = 0
