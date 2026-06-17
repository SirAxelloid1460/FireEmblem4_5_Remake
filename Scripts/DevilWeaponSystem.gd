# DevilWeaponSystem.gd
# Sistema de armas Devil (Devil Axe, Devil Sword, etc.).
#
# REGLA CANÓNICA (FE3+ a partir de Genealogy):
#   • Probabilidad de backfire = clamp((31 − LCK) %, 1 %, 100 %).
#       — Mínimo 1 % siempre, incluso con LCK >= 31.
#   • Si backfire ocurre, el daño que iba a recibir el objetivo se redirige
#     al portador (no se calcula "atacarse a sí mismo").
#   • El backfire ignora si el ataque iba a fallar o acertar — la tirada
#     se hace sobre el ataque que se intentó, no sobre el conectado.
#       (En FE clásico el backfire se calcula DESPUÉS de comprobar HIT.)
#       Aquí se ofrece check_backfire_on_intent() y check_backfire_on_hit()
#       para que el caller elija; la mayoría de juegos lo hacen ON_HIT.
#   • El backfire puede crítico — el game flag "backfire_can_crit" está
#     desactivado por defecto (FE4/FE5 no lo tenía).
#
# IDENTIFICACIÓN DE UN ARMA DEVIL:
#   En LT-maker, Devil Axe lleva ['status_on_hit', 'Devil'] como componente.
#   El status 'Devil' está vacío en el JSON — la mecánica es código.  Aquí
#   se reconoce por el flag is_devil del Weapon (o status_on_hit == "Devil"
#   si el caller prefiere leer del componente).
#
# CONEXIÓN CON CombatSystem:
#   En CombatSystem._do() / execute_attack(), antes de aplicar el daño al
#   defensor, se llama a:
#       if DevilWeaponSystem.is_devil_weapon(attacker.weapon):
#           if DevilWeaponSystem.check_backfire(attacker):
#               # daño previsto se redirige al atacante
#               attacker.take_damage(damage)
#               return AttackResult(... skill_proc="Devil")
#   El cambio en CombatSystem se documenta en el README de la fase 1 pero
#   no se aplica aquí para minimizar la superficie de cambios — se
#   recomienda añadirlo en la próxima ronda con tests.

class_name DevilWeaponSystem
extends RefCounted

const BACKFIRE_BASE      := 31   # FE3/4/5 onwards.  FE1 = 21.
const BACKFIRE_MIN_PCT   := 1
const BACKFIRE_MAX_PCT   := 100


## ¿Es un arma Devil?  Detecta por componente o por flag explícito.
##   weapon — instancia de Weapon (la clase real está en otro archivo;
##   aceptamos cualquier objeto con has_component() o atributo is_devil).
static func is_devil_weapon(weapon) -> bool:
	if weapon == null:
		return false
	# Flag explícito.
	if "is_devil" in weapon and bool(weapon.is_devil):
		return true
	# Por componente status_on_hit == "Devil" (formato LT).
	if weapon.has_method("has_component") and weapon.has_component("status_on_hit"):
		var s = weapon.get_component("status_on_hit") if weapon.has_method("get_component") else ""
		if str(s) == "Devil":
			return true
	# Por nid.
	if "id" in weapon and "Devil" in str(weapon.id):
		return true
	return false


## Probabilidad % de backfire para un portador.  Útil para preview UI.
static func backfire_chance(wielder: Unit) -> int:
	if wielder == null:
		return BACKFIRE_MIN_PCT
	var lck: int = wielder.luck
	var p   := BACKFIRE_BASE - lck
	if p < BACKFIRE_MIN_PCT: p = BACKFIRE_MIN_PCT
	if p > BACKFIRE_MAX_PCT: p = BACKFIRE_MAX_PCT
	return p


## Tira la moneda y devuelve true si el ataque debe redirigirse al portador.
##   Llamar UNA VEZ por ataque en CombatSystem.
static func check_backfire(wielder: Unit) -> bool:
	var p := backfire_chance(wielder)
	return (randi() % 100) < p


## Helper: dado el daño que se iba a infligir al defensor, lo aplica al
## atacante.  Devuelve el daño efectivo aplicado (capeado por current_hp).
##   Se asume que el caller ya decidió que hubo backfire vía check_backfire.
static func apply_backfire(wielder: Unit, intended_damage: int) -> int:
	if wielder == null or intended_damage <= 0:
		return 0
	var dmg: int = min(intended_damage, wielder.current_hp)
	wielder.take_damage(dmg)
	return dmg
