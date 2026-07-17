class_name ArenaSystem
extends RefCounted

# Arena del Castillo Base (modelo HÍBRIDO — spec del usuario).
#   · Cada capítulo trae 7 rivales FIJOS en orden (data/fe4/arena/fe4.json,
#     sourced de fireemblemwod).  Cada posición puede tener variante A (cuerpo a
#     cuerpo) y B (a distancia, se usa cuando el jugador ataca a rango).
#   · Un personaje empieza por el rival nº1 y avanza al vencer (arena_fixed_index).
#   · Tras vencer a los 7 fijos, la arena genera GENÉRICOS de nivel = nivel del
#     personaje + (1..3).
#   · Tope de 10 victorias por capítulo (arena_wins).
#   · Perder NO es muerte: se restaura el HP y se vuelve al menú de la Base.
#   · El progreso vive en la Unit (no se persiste) → se reinicia cada visita al
#     castillo = una vez por capítulo.

const MAX_WINS := 10
const FIXED_COUNT := 7
const DATA_PATH := "res://data/fe4/arena/fe4.json"
const DUEL_ROUND_CAP := 60   # anti-bucle si dos unidades no pueden dañarse

# Clases genéricas por defecto para la fase post-fijos (variedad simple).
const GENERIC_CLASSES := ["Swordfighter", "Fighter", "Cavalier", "Archer", "Mage"]

static var _cache: Dictionary = {}   # chapter_label -> Array[Dictionary]

# ── Datos ─────────────────────────────────────────────────────────────────────

static func _load_all() -> Dictionary:
	if not _cache.is_empty():
		return _cache
	if not FileAccess.file_exists(DATA_PATH):
		push_warning("[Arena] no existe %s" % DATA_PATH)
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if parsed is Dictionary and parsed.has("chapters"):
		_cache = parsed["chapters"]
	return _cache

## Rivales fijos de un capítulo, agrupados por posición (1..7).
## Devuelve Array de {order, A: Dict|null, B: Dict|null}.
static func chapter_positions(chapter_label: String) -> Array:
	var rows: Array = _load_all().get(chapter_label, [])
	var by_order := {}
	for r in rows:
		var o := int(r.get("order", 0))
		var slot: Dictionary = by_order.get(o, {"order": o, "A": null, "B": null})
		# El primer '*' (Chulainn) se prioriza como variante A reclutable.
		if str(r.get("variant", "A")) == "B":
			slot["B"] = r
		elif slot["A"] == null:
			slot["A"] = r
		by_order[o] = slot
	var out := []
	for o in range(1, FIXED_COUNT + 1):
		if by_order.has(o):
			out.append(by_order[o])
	return out

## ¿El capítulo tiene arena?  (El Prólogo y el Cap. 6 no la tienen en FE4.)
static func chapter_has_arena(chapter_label: String) -> bool:
	return not chapter_positions(chapter_label).is_empty()

# ── Selección del próximo rival ───────────────────────────────────────────────

## Devuelve el próximo reto para `unit` en el capítulo, o {} si ya no puede pelear
## (tope de victorias alcanzado o capítulo sin arena).
##   {opponent: Dict, is_generic: bool, position: int}
static func next_challenge(unit, chapter_label: String) -> Dictionary:
	if unit.arena_wins >= MAX_WINS:
		return {}
	var positions := chapter_positions(chapter_label)
	if positions.is_empty():
		return {}
	var ranged := unit_is_ranged(unit)
	if unit.arena_fixed_index < FIXED_COUNT and unit.arena_fixed_index < positions.size():
		var slot: Dictionary = positions[unit.arena_fixed_index]
		var opp = slot["B"] if (ranged and slot["B"] != null) else slot["A"]
		if opp == null:
			opp = slot["A"] if slot["A"] != null else slot["B"]
		return {"opponent": opp, "is_generic": false, "position": int(slot.get("order", 0))}
	# Fase genérica: nivel del personaje + 1..3.
	var lvl: int = int(unit.level) + (randi() % 3 + 1)
	return {"opponent": _make_generic(lvl, unit.arena_wins), "is_generic": true, "position": 0}

## Genérico simple: escala bases con el nivel.  Son valores de RELLENO de arena
## (no stats canónicas de personaje), por eso se generan y no se sourcean.
static func _make_generic(level: int, seed_i: int) -> Dictionary:
	var klass: String = GENERIC_CLASSES[seed_i % GENERIC_CLASSES.size()]
	var base := 18 + level
	var is_mage := (klass == "Mage")
	return {
		"order": 0, "variant": "A", "name": "Gladiator Lv%d" % level, "klass": klass,
		"level": level,
		"bases": {
			"HP": base + 6, "STR": 0 if is_mage else 4 + level, "MAG": 4 + level if is_mage else 0,
			"SKL": 3 + level, "SPD": 3 + level, "LCK": 0, "DEF": 2 + level / 2, "RES": level / 3,
		},
		"weapon": _generic_weapon(klass), "weapon_ranged": null, "ring": null, "note": null,
	}

static func _generic_weapon(klass: String) -> String:
	match klass:
		"Fighter": return "Steel Axe"
		"Cavalier": return "Steel Lance"
		"Archer": return "Steel Bow"
		"Mage": return "Elfire"
		_: return "Steel Sword"

# ── Fábrica de Unit rival ─────────────────────────────────────────────────────

static func build_opponent_unit(opp: Dictionary):
	var u = Unit.new()
	u.unit_name = str(opp.get("name", "Arena"))
	u.unit_class = str(opp.get("klass", "Swordfighter"))
	u.level = int(opp.get("level", 1))
	var b: Dictionary = opp.get("bases", {})
	u.max_hp = int(b.get("HP", 20)); u.current_hp = u.max_hp
	u.strength = int(b.get("STR", 0)); u.magic = int(b.get("MAG", 0))
	u.skill = int(b.get("SKL", 0));   u.speed = int(b.get("SPD", 0))
	u.luck = int(b.get("LCK", 0));    u.defense = int(b.get("DEF", 0))
	u.resistance = int(b.get("RES", 0))
	# CON del rival: base de su clase (los datos de arena no traen CON).
	var db := _gamedb()
	var con := 0
	if db != null:
		var cd = db.get_class_data(u.unit_class)
		if cd != null and cd.bases is Dictionary:
			con = int(cd.bases.get("CON", 0))
	u.constitution = con
	u.movement = 0
	# Arma (nid ya remapeado en el JSON de arena).
	var wnid := str(opp.get("weapon", ""))
	if wnid != "" and db != null:
		var wd = db.get_weapon(wnid)
		if wd != null:
			u.weapon = Weapon.from_data(wd)
	return u

# ── Duelo ─────────────────────────────────────────────────────────────────────

## ¿La unidad ataca SOLO a distancia (arco)?  Determina la variante A/B del rival
## y la distancia del duelo.
static func unit_is_ranged(unit) -> bool:
	return unit != null and unit.weapon != null and int(unit.weapon.min_range) >= 2

## Resuelve el duelo a muerte entre `player` y el rival.  Reutiliza las fórmulas
## puras de CombatSystem (hit/crit/daño/AS/doblaje).  NO muta al player salvo su
## HP (que el caller restaura si pierde).  Devuelve {victory: bool, player_hp: int}.
static func resolve_duel(player, opp_unit, ranged: bool) -> Dictionary:
	var dist := 2 if ranged else 1
	var rounds := 0
	while player.current_hp > 0 and opp_unit.current_hp > 0 and rounds < DUEL_ROUND_CAP:
		rounds += 1
		# El jugador inicia.
		_strike(player, opp_unit, dist)
		if opp_unit.current_hp <= 0:
			break
		# Contraataque si el rival alcanza a esa distancia.
		if opp_unit.weapon != null and opp_unit.weapon.can_attack_at_range(dist):
			_strike(opp_unit, player, dist)
			if player.current_hp <= 0:
				break
		# Doblajes.
		if CombatSystem._can_double(player, opp_unit, player.weapon):
			_strike(player, opp_unit, dist)
			if opp_unit.current_hp <= 0:
				break
		elif opp_unit.weapon != null and opp_unit.weapon.can_attack_at_range(dist) \
				and CombatSystem._can_double(opp_unit, player, opp_unit.weapon):
			_strike(opp_unit, player, dist)
	return {"victory": opp_unit.current_hp <= 0 and player.current_hp > 0,
			"player_hp": max(0, player.current_hp)}

## Un golpe con las fórmulas reales (tirada de acierto/crítico + daño).
static func _strike(atk, def, dist: int) -> void:
	if atk.weapon == null:
		return
	var hit := CombatSystem.calculate_hit(atk, def, dist)
	if (randi() % 100) >= hit:
		return   # falla
	var is_crit := (randi() % 100) < CombatSystem.calculate_crit(atk, def)
	var is_eff := CombatSystem._is_effective(atk.weapon, def)
	var dmg := CombatSystem._calc_dmg(atk, def, is_crit, is_eff, "", {}, {"dist": dist})
	def.current_hp = max(0, def.current_hp - dmg)

# ── Aplicar resultado ─────────────────────────────────────────────────────────

## Tras un duelo: victoria → +1 victoria (avanza fijo si tocaba) + recompensa;
## derrota → restaura HP, sin avance.  Devuelve {gold, exp} ganados (0 si perdió).
static func apply_result(unit, challenge: Dictionary, victory: bool) -> Dictionary:
	if not victory:
		unit.current_hp = unit.max_hp   # sin permadeath: se restaura y vuelve al menú
		return {"gold": 0, "exp": 0}
	unit.arena_wins += 1
	if not bool(challenge.get("is_generic", false)):
		unit.arena_fixed_index += 1
	var opp: Dictionary = challenge.get("opponent", {})
	var opp_lvl := int(opp.get("level", unit.level))
	# Recompensas de arena = valores de DISEÑO (tunables), no stats sourced.
	var exp_gain: int = clampi(30 + (opp_lvl - int(unit.level)) * 3, 10, 100)
	var gold_gain: int = 100 + opp_lvl * 10
	if unit.has_method("gain_exp"):
		unit.gain_exp(exp_gain)
	return {"gold": gold_gain, "exp": exp_gain}

# ── Utilidades ────────────────────────────────────────────────────────────────

static func _gamedb():
	var loop := Engine.get_main_loop()
	if loop is SceneTree and loop.root != null:
		return loop.root.get_node_or_null("GameDB")
	return null

## Etiqueta de capítulo para el JSON de arena, desde GameMode (o "" si no aplica).
static func current_chapter_label() -> String:
	var loop := Engine.get_main_loop()
	if loop is SceneTree and loop.root != null:
		var gm = loop.root.get_node_or_null("GameMode")
		if gm != null and gm.has_method("get_current_chapter_entry"):
			var entry: Dictionary = gm.get_current_chapter_entry()
			# Solo FE4 tiene tabla de arena por ahora.
			if str(entry.get("game", "fe4")) == "fe4":
				return str(entry.get("id", ""))
	return ""
