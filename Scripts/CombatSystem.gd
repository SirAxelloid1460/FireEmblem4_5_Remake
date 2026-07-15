# CombatSystem.gd
# Sistema de combate completo — FE Remake
#
# CORRECCIONES v3:
#   - Terrain DEF/AVO integrado en todas las fórmulas
#   - Wrath: HP ≤ 1/3 (no 25%)
#   - Charisma: +15 HIT/AVO/CRIT (fiel al LT real, no +10)
#   - Rescue penalty: SPD/2 y STR/2 al cargar unidad
#   - Pavise: proc = promedio de niveles (def+atk)/2 % (port GBA)
#   - Miracle añadido: LCK%, sobrevive golpe letal con 1 HP
#   - Nihil (FE5): niega todas las proc del bando enemigo
#   - Awareness (FE4): niega crít + sword skills + effectividad (distinto de Nihil)
#   - Vantage (unifica Ambush/Desperation): HP≤50% → el defensor golpea primero
#   - Hel: el tomo homónimo deja al objetivo a 1 HP (nunca mata)
#   - Sol/Luna/Astra: procean solo si el golpe acertaría (FE5 style)

class_name CombatSystem
extends Node

const SPEED_TO_DOUBLE    := 4
const CRIT_MULTIPLIER    := 3
const WRATH_THRESHOLD    := 3       # HP <= max_hp / 3
const KILL_MULTIPLIER    := 3.0
const BOSS_BONUS_EXP     := 55
const MIN_DAMAGE         := 0
const TRIANGLE_DMG       := 1
const TRIANGLE_HIT       := 15
const CHARISMA_BONUS     := 15
const EFFECTIVE_MULT     := 2.5
const EFFECTIVE_BONUS    := 5
const EFFECTIVE_DEF_DIV  := 2
const EFFECTIVE_RES_DIV  := 3
const ASTRA_HITS         := 5

class AttackResult:
	var attacker_name: String
	var defender_name: String
	var damage:     int
	var hit:        bool
	var critical:   bool
	var effective:  bool
	var skill_proc: String

	func _init(atk: String, def_n: String, dmg: int, did_hit: bool,
			is_crit: bool, is_eff: bool = false, proc: String = ""):
		attacker_name = atk; defender_name = def_n
		damage = dmg; hit = did_hit; critical = is_crit
		effective = is_eff; skill_proc = proc


class CombatResult:
	var attacker: Unit
	var defender: Unit
	var attacker_attacks: Array[AttackResult] = []
	var defender_attacks: Array[AttackResult] = []
	var attacker_died: bool = false
	var defender_died: bool = false
	var exp_attacker:  int  = 0
	var exp_defender:  int  = 0

	func get_summary() -> String:
		var s := "=== %s vs %s ===\n" % [attacker.unit_name, defender.unit_name]
		for a in attacker_attacks: s += _fmt(a)
		for a in defender_attacks: s += _fmt(a)
		if attacker_died: s += "\n%s has fallen!\n" % attacker.unit_name
		if defender_died: s += "\n%s has fallen!\n" % defender.unit_name
		if exp_attacker > 0: s += "\n%s gained %d EXP.\n" % [attacker.unit_name, exp_attacker]
		return s

	func _fmt(a: AttackResult) -> String:
		if not a.hit: return "%s misses!\n" % a.attacker_name
		var tag := ""
		if   a.critical:          tag = " [CRIT!]"
		elif a.effective:         tag = " [EFFECTIVE!]"
		elif a.skill_proc != "":  tag = " [%s!]" % a.skill_proc
		return "%s hits for %d!%s\n" % [a.attacker_name, a.damage, tag]


static func calculate_combat(attacker: Unit, defender: Unit, distance: int,
		terrain_atk: Dictionary = {}, terrain_def: Dictionary = {},
		combat_flags: Dictionary = {}) -> CombatResult:

	var result := CombatResult.new()
	result.attacker = attacker
	result.defender = defender

	var atk_wpn = attacker.weapon
	var def_wpn = defender.weapon

	if not atk_wpn or not atk_wpn.can_attack_at_range(distance):
		return result

	var def_can_counter: bool = def_wpn != null and def_wpn.can_attack_at_range(distance)
	var atk_can_double  := _can_double(attacker, defender, atk_wpn)
	var def_can_double  := _can_double(defender, attacker, def_wpn)

	# Nihil (FE5): niega TODAS las proc del bando contrario
	var atk_proc_blocked := _has_skill(defender, "Nihil")
	var def_proc_blocked := _has_skill(attacker, "Nihil")

	# Pre-combat proc rolls
	var atk_sword := "" if atk_proc_blocked else _roll_sword_skill(attacker)

	# Vantage (unifica Ambush/Desperation): defensor ataca primero si HP <= 50%
	if def_can_counter and not def_proc_blocked and _has_skill(defender, "Vantage") \
			and defender.current_hp <= defender.max_hp / 2:
		_do(defender, attacker, distance, result, false,
				terrain_def, terrain_atk, "", def_proc_blocked)
		if result.attacker_died:
			_finalize_exp(result); return result

	# Astra: 5 golpes antes del contraataque
	if atk_sword == "Astra":
		for i in range(ASTRA_HITS):
			_do(attacker, defender, distance, result, true,
					terrain_atk, terrain_def, "Astra" if i == 0 else "", atk_proc_blocked)
			if result.defender_died:
				_finalize_exp(result); return result
	else:
		# Brave: 2 ataques antes del contra
		if atk_wpn != null and atk_wpn.has_component("brave"):
			_do(attacker, defender, distance, result, true,
					terrain_atk, terrain_def, "", atk_proc_blocked)
			if result.defender_died:
				_finalize_exp(result); return result

		# Primer ataque normal
		_do(attacker, defender, distance, result, true,
				terrain_atk, terrain_def, atk_sword, atk_proc_blocked, combat_flags)
		if result.defender_died:
			_finalize_exp(result); return result

	# Contraataque
	if def_can_counter:
		_do(defender, attacker, distance, result, false,
				terrain_def, terrain_atk, "", def_proc_blocked)
		if result.attacker_died:
			_finalize_exp(result); return result

	# Doble ataque simetrico
	if atk_can_double and def_can_double:
		if calculate_attack_speed(attacker) >= calculate_attack_speed(defender):
			_do(attacker, defender, distance, result, true,
					terrain_atk, terrain_def, "", atk_proc_blocked)
			if not result.defender_died and def_can_counter:
				_do(defender, attacker, distance, result, false,
						terrain_def, terrain_atk, "", def_proc_blocked)
		else:
			if def_can_counter:
				_do(defender, attacker, distance, result, false,
						terrain_def, terrain_atk, "", def_proc_blocked)
			if not result.attacker_died:
				_do(attacker, defender, distance, result, true,
						terrain_atk, terrain_def, "", atk_proc_blocked)
	elif atk_can_double:
		_do(attacker, defender, distance, result, true,
				terrain_atk, terrain_def, "", atk_proc_blocked)
	elif def_can_double and def_can_counter:
		_do(defender, attacker, distance, result, false,
				terrain_def, terrain_atk, "", def_proc_blocked)

	# Charge: ronda extra si AS y HP > los del defensor
	if not result.attacker_died and not result.defender_died \
			and not atk_proc_blocked and _has_skill(attacker, "Charge") \
			and calculate_attack_speed(attacker) > calculate_attack_speed(defender) \
			and attacker.current_hp > defender.current_hp:
		_do(attacker, defender, distance, result, true,
				terrain_atk, terrain_def, "", atk_proc_blocked)
		if not result.defender_died and def_can_counter:
			_do(defender, attacker, distance, result, false,
					terrain_def, terrain_atk, "", def_proc_blocked)

	_finalize_exp(result)
	return result


static func _do(atk: Unit, def: Unit, dist: int, result: CombatResult,
		is_atk_side: bool, t_atk: Dictionary, t_def: Dictionary,
		sword_skill: String, nihil: bool, flags: Dictionary = {}) -> void:
	var ar := execute_attack(atk, def, dist, t_atk, t_def, sword_skill, nihil, flags)
	if is_atk_side: result.attacker_attacks.append(ar)
	else:           result.defender_attacks.append(ar)
	if ar.hit:
		# Devil weapon: (31 - LCK) % de redirigir el daño al portador.
		# Mínimo 1 % siempre.  El check solo se hace si el ataque acierta,
		# canon FE3+ (en FE5 también funciona así).
		if DevilWeaponSystem.is_devil_weapon(atk.weapon) \
				and DevilWeaponSystem.check_backfire(atk):
			ar.skill_proc = "Devil"
			DevilWeaponSystem.apply_backfire(atk, ar.damage)
			if atk.current_hp <= 0:
				if is_atk_side: result.attacker_died = true
				else:           result.defender_died = true
			return
		def.take_damage(ar.damage)
		if def.current_hp <= 0:
			if is_atk_side: result.defender_died = true
			else:           result.attacker_died = true
		if ar.skill_proc == "Sol": atk.heal(ar.damage)


static func execute_attack(atk: Unit, def: Unit, dist: int,
		t_atk: Dictionary = {}, t_def: Dictionary = {},
		sword_skill: String = "", nihil: bool = false,
		combat_flags: Dictionary = {}) -> AttackResult:

	var wpn = atk.weapon
	if not wpn:
		return AttackResult.new(atk.unit_name, def.unit_name, 0, false, false)
	var is_magic: bool = bool(wpn.is_magic) if "is_magic" in wpn else false

	var did_hit := sword_skill == "Sol" or \
			_true_hit(calculate_hit(atk, def, dist, t_def))

	if not did_hit:
		_gain_wexp(atk, wpn, false)
		_use_weapon(wpn, false)
		return AttackResult.new(atk.unit_name, def.unit_name, 0, false, false)

	# Awareness (FE4): niega crit + sword skills + effectividad
	var aware := (not nihil) and _has_skill(def, "Awareness")

	var is_crit := false
	if not aware:
		if atk.current_hp <= atk.max_hp / WRATH_THRESHOLD and _has_skill(atk, "Wrath"):
			is_crit = true
		else:
			is_crit = randi() % 100 < calculate_crit(atk, def)

	var is_eff := (not aware) and _is_effective(wpn, def)
	var dmg    := _calc_dmg(atk, def, is_crit, is_eff, sword_skill, t_def, combat_flags)

	# Pavise (Great Shield): anula el daño con probabilidad = promedio de los
	# niveles de defensor y atacante.  FE4/FE5 usan solo el nivel propio y FE8
	# el del enemigo; como el port es a GBA tomamos la media de ambos.
	if not nihil and not is_crit and _has_skill(def, "Pavise"):
		var pavise_rate: int = (def.level + atk.level) / 2
		if randi() % 100 < pavise_rate:
			dmg = 0

	# Miracle (LCK%): sobrevive golpe letal con 1 HP
	if not nihil and dmg >= def.current_hp and _has_skill(def, "Miracle") \
			and randi() % 100 < _stat(def, "LCK"):
		dmg = def.current_hp - 1

	_gain_wexp(atk, wpn, true)
	_use_weapon(wpn, true)
	return AttackResult.new(atk.unit_name, def.unit_name, dmg, true, is_crit, is_eff, sword_skill)


static func _roll_sword_skill(unit: Unit) -> String:
	var s: int = _stat(unit, "SKL")
	if _has_skill(unit, "Astra") and randi() % 100 < s: return "Astra"
	if _has_skill(unit, "Luna")  and randi() % 100 < s: return "Luna"
	if _has_skill(unit, "Sol")   and randi() % 100 < s: return "Sol"
	return ""


static func _can_double(unit: Unit, target: Unit, wpn) -> bool:
	if wpn == null: return false
	return calculate_attack_speed(unit) >= calculate_attack_speed(target) + SPEED_TO_DOUBLE


static func calculate_attack_speed(unit: Unit) -> int:
	# La penalización de captura (SPD/2) ya viene aplicada vía el modifier
	# "Carrying" que lee get_effective_stat — no se vuelve a restar aquí.
	if not unit.weapon: return _stat(unit, "SPD")
	var spd: int = _stat(unit, "SPD")
	var con  := _stat(unit, "MAG") if unit.weapon.is_magic else _stat(unit, "CON")
	return spd - max(0, unit.weapon.weight - con)


static func calculate_hit(atk: Unit, def: Unit, _dist: int,
		t_def: Dictionary = {}) -> int:
	if not atk.weapon: return 0
	var hit: int = atk.weapon.accuracy + (_stat(atk, "SKL") * 2) + (_stat(atk, "LCK") / 2)
	if _charisma_near(atk): hit += CHARISMA_BONUS
	hit += _tri_hit(atk, def)
	hit += _support_bonus(atk, "HIT")
	var def_as: int = calculate_attack_speed(def)
	# Captura: SPD/2 del atacante reduce su AS (ya incluido via flag en _calc_dmg)
	var avoid: int = (def_as * 2) + _stat(def, "LCK") + int(t_def.get("AVO", 0))
	if _is_carrying(def): avoid = avoid / 2
	if _charisma_near(def): avoid += CHARISMA_BONUS
	avoid += _support_bonus(def, "AVO")
	return clampi(hit - avoid, 0, 100)


static func calculate_crit(atk: Unit, def: Unit) -> int:
	if not atk.weapon: return 0
	var atk_skl: int = _stat(atk, "SKL")
	var crit: int = atk.weapon.critical + \
			(int(atk_skl * 1.5) if _has_skill(atk, "Critical") else atk_skl / 2)
	if _charisma_near(atk): crit += CHARISMA_BONUS
	crit += _support_bonus(atk, "CRIT")
	var ca: int = _stat(def, "LCK")
	if _charisma_near(def): ca += CHARISMA_BONUS
	ca += _support_bonus(def, "DODGE")
	return max(0, crit - ca)


static func _calc_dmg(atk: Unit, def: Unit, is_crit: bool, is_eff: bool,
		sword_skill: String = "", t_def: Dictionary = {},
		flags: Dictionary = {}) -> int:

	var wpn = atk.weapon
	var is_magic: bool = bool(wpn.is_magic) if wpn and "is_magic" in wpn else false
	# Hel (efecto del tomo homónimo): deja al objetivo a 1 HP; nunca mata.
	#   HP objetivo != 1 → daño = HP_actual - 1;  si ya está a 1 → daño = 0.
	if _has_skill(atk, "Hel"):
		return def.current_hp - 1 if def.current_hp != 1 else 0
	# STR/MAG efectivos: incluyen anillos on_hold, Holy Water y la penalización
	# de captura ("Carrying" → STR/MAG a la mitad ya aplicada vía modifier).
	var stat_m: int = _stat(atk, "MAG") if is_magic else _stat(atk, "STR")
	# Captura FE5: STR/MAG a la mitad DURANTE el intento (estado transitorio,
	# aún sin modifier — se resta aquí explícitamente).
	if flags.get("is_capture_attempt", false): stat_m = stat_m / 2
	var wep_m: int = int(wpn.might) if wpn else 0
	var mt_total: int = wep_m + stat_m
	var def_raw: int = _stat(def, "RES") if is_magic else _stat(def, "DEF")

	var dmg_mult := 1.0; var def_mult := 1.0; var flat := 0
	if   _has_skill(atk, "DarknessSword"): dmg_mult = 2.0; def_mult = 0.5
	elif _has_skill(atk, "HolySword"):     flat = 20;      def_mult = 0.5

	if is_eff:
		var eff_d: int = def_raw / EFFECTIVE_RES_DIV if is_magic else def_raw / EFFECTIVE_DEF_DIV
		return max(MIN_DAMAGE, ceili(mt_total * EFFECTIVE_MULT) + EFFECTIVE_BONUS - eff_d)

	if sword_skill == "Luna": def_raw = 0

	var eff_def: int = int(def_raw * def_mult) + int(t_def.get("DEF", 0)) + _support_bonus(def, "DEF")
	var dmg: int = int((mt_total + flat - eff_def + _tri_dmg(atk, def) + _support_bonus(atk, "DMG")) * dmg_mult)
	dmg = max(MIN_DAMAGE, dmg)
	if is_crit: dmg *= CRIT_MULTIPLIER
	return dmg


static func _is_effective(wpn, def: Unit) -> bool:
	if not wpn or not wpn.has_method("get_effective_tags"): return false
	for t in wpn.get_effective_tags():
		if t in def.tags: return true
	return false

static func _tri_hit(a: Unit, d: Unit) -> int:
	if not a.weapon or not d.weapon: return 0
	return a.weapon.get_weapon_triangle_bonus(d.weapon) * TRIANGLE_HIT

static func _tri_dmg(a: Unit, d: Unit) -> int:
	if not a.weapon or not d.weapon: return 0
	return a.weapon.get_weapon_triangle_bonus(d.weapon) * TRIANGLE_DMG

static func _true_hit(h: int) -> bool:
	return ((randi() % 100) + (randi() % 100)) / 2 < h

static func _gain_wexp(unit: Unit, wpn, hit: bool) -> void:
	if wpn == null:
		return
	# constants.miss_wexp = 1 en LT (el wexp se gana incluso al fallar).
	# Si el motor decide cambiarlo a 0, basta con `if not hit: return`.
	# Determinar el tipo de arma — en LT-maker es weapon.weapon_type.
	var wt: String = ""
	if "weapon_type" in wpn:
		wt = str(wpn.weapon_type)
	elif wpn.has_method("get_weapon_type"):
		wt = str(wpn.get_weapon_type())
	# Cantidad ganada — el item puede definir su propio wexp_gain
	# (LT-maker: lista [bool, int]); fallback 1 (= ganancia normal en hit).
	var amount: int = 1
	if "wexp_gain" in wpn:
		var wg = wpn.wexp_gain
		if wg is int:
			amount = wg
		elif wg is Array and wg.size() >= 2:
			amount = int(wg[1])
	if wt != "" and unit.has_method("gain_weapon_exp"):
		unit.gain_weapon_exp(wt, amount)
	# Compatibilidad con el método antiguo del Weapon (si existe).
	elif wpn.has_method("add_wexp"):
		wpn.add_wexp(amount)

static func _use_weapon(wpn, hit: bool) -> void:
	if not wpn or not wpn.has_method("use"): return
	var lose: bool = wpn.get("lose_uses_on_miss") if "lose_uses_on_miss" in wpn else false
	if hit or lose: wpn.use()

static func _finalize_exp(result: CombatResult) -> void:
	# Las ballistas no son enemigos vivos — son objetos del mapa.
	# No se concede EXP por destruirlas (canon FE clásico).
	if result.defender_died and BallistaSystem.is_ballista(result.defender):
		result.exp_attacker = 0
		if result.attacker_died:
			result.exp_defender = int(_base_exp(result.defender, result.attacker) * KILL_MULTIPLIER)
		return
	var base: int = _base_exp(result.attacker, result.defender)
	var exp_value: int = int(base * KILL_MULTIPLIER) if result.defender_died else max(1, base)
	if result.defender_died and result.defender.has_meta("is_boss") \
			and result.defender.get_meta("is_boss"):
		exp_value += BOSS_BONUS_EXP
	if _has_skill(result.attacker, "Elite_Skill"):
		exp_value = min(100, exp_value * 2)
	result.exp_attacker = exp_value
	if result.attacker_died:
		result.exp_defender = int(_base_exp(result.defender, result.attacker) * KILL_MULTIPLIER)

static func _base_exp(atk: Unit, def: Unit) -> int:
	return int(clamp(15.0 * exp((def.level - atk.level) * 0.102), 1, 100))

static func _has_skill(unit: Unit, id: String) -> bool:
	return unit.has_method("has_skill") and unit.has_skill(id)

## Lee un stat EFECTIVO (base + item bonuses + status modifiers): anillos
## on_hold (Power/Speed/… Ring), armas on_equip (Balmung SKL/SPD), Holy Water
## (MAG), penalización de captura (Carrying). Fallback al campo crudo para
## Units mínimas de test sin get_effective_stat. `key` ∈ {STR,MAG,SKL,SPD,LCK,
## DEF,RES,CON,HP,MOV}.
static func _stat(unit: Unit, key: String) -> int:
	if unit.has_method("get_effective_stat"):
		return unit.get_effective_stat(key)
	match key:
		"STR": return unit.strength
		"MAG": return unit.magic
		"SKL": return unit.skill
		"SPD": return unit.speed
		"LCK": return unit.luck
		"DEF": return unit.defense
		"RES": return unit.resistance
		"CON": return unit.constitution
		"HP":  return unit.max_hp
		"MOV": return unit.movement
	return 0

static func _is_carrying(unit: Unit) -> bool:
	return unit.has_method("is_carrying") and unit.is_carrying()

static func _charisma_near(unit: Unit) -> bool:
	return unit.has_method("is_in_charisma_range") and unit.is_in_charisma_range()


## Lee el bonus de support cacheado en la Unit.  El GameManager lo
## actualiza antes de cada combate llamando a unit.set_meta("support_bonus", ...).
##   stat puede ser "HIT", "AVO", "CRIT", "DODGE", "DMG", "DEF".
static func _support_bonus(unit: Unit, stat: String) -> int:
	if unit == null:
		return 0
	if not unit.has_meta("support_bonus"):
		return 0
	var bonus: Dictionary = unit.get_meta("support_bonus")
	return int(bonus.get(stat, 0))


static func preview_combat(atk: Unit, def: Unit, dist: int,
		t_atk: Dictionary = {}, t_def: Dictionary = {}) -> Dictionary:
	var p := {
		"atk_damage": 0, "atk_hit": 0, "atk_crit": 0,
		"atk_doubles": false, "atk_effective": false, "atk_as": 0,
		"def_damage": 0, "def_hit": 0, "def_crit": 0,
		"def_doubles": false, "def_effective": false, "def_as": 0,
		"def_can_counter": false,
	}
	if not atk.weapon or not atk.weapon.can_attack_at_range(dist): return p
	var a_eff := _is_effective(atk.weapon, def)  and not _has_skill(def, "Awareness")
	var d_eff := def.weapon != null and _is_effective(def.weapon, atk) \
			and not _has_skill(atk, "Awareness")
	p["atk_damage"]    = _calc_dmg(atk, def, false, a_eff, "", t_def)
	p["atk_hit"]       = calculate_hit(atk, def, dist, t_def)
	p["atk_crit"]      = calculate_crit(atk, def)
	p["atk_doubles"]   = _can_double(atk, def, atk.weapon)
	p["atk_effective"] = a_eff
	p["atk_as"]        = calculate_attack_speed(atk)
	p["def_as"]        = calculate_attack_speed(def)
	if def.weapon and def.weapon.can_attack_at_range(dist):
		p["def_can_counter"] = true
		p["def_damage"]    = _calc_dmg(def, atk, false, d_eff, "", t_atk)
		p["def_hit"]       = calculate_hit(def, atk, dist, t_atk)
		p["def_crit"]      = calculate_crit(def, atk)
		p["def_doubles"]   = _can_double(def, atk, def.weapon)
		p["def_effective"] = d_eff
	return p
