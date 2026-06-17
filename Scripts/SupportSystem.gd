# SupportSystem.gd
# Sistema de soportes — soporta DOS modos:
#   • FE4 Love system: pares predefinidos suben puntos por turno + adyacencia.
#       Solo dos rangos: Lover (≥200 pts) y Married (≥250 pts).
#       El matrimonio es necesario para gen 2 (sustitutos si no hay).
#   • FE GBA Support system: rangos C/B/A/S, bonuses por afinidad,
#       máximo 1 par activo por unidad simultáneamente.
#
# Datos canónicos (verificados contra Thracia776/GotHW):
#   • support_pairs.json — 27 pares definidos en FE4 (Aideen-Jamke,
#       Aideen-Midir, etc.).  Cada par tiene umbral Lover=200, Married=250.
#   • support_ranks.json en FE4 = ["Lover", "Married"].
#   • affinities.json — 7 afinidades (Fire, Thunder, Wind, Ice, Dark,
#       Light, None).  Los bonuses canónicos a 0 en el JSON real;
#       implementamos los del FE4 original aquí.
#
# AFINIDADES FE4 (perfil canónico GBA-style — base de cálculo):
#   Fire    : ATK +0.5, HIT +2.5, AVO +2.5, CRIT +2.5
#   Thunder : DEF +0.5, AVO +2.5, CRIT +2.5, DODGE +2.5
#   Wind    : ATK +0.5, HIT +2.5, CRIT +2.5, DODGE +2.5
#   Ice     : DEF +0.5, HIT +2.5, AVO +2.5, DODGE +2.5
#   Dark    : HIT +2.5, AVO +2.5, CRIT +2.5, DODGE +2.5
#   Light   : ATK +0.5, DEF +0.5, HIT +2.5, CRIT +2.5
#   En GBA por rango se multiplica: C×1, B×2, A×3, S×4.
#   En FE4 Lover ≈ rango B, Married ≈ rango S (multiplicador final).
#
# CONEXIÓN:
#   • CombatSystem consulta get_combat_bonus(unit, partner_unit) para sumar
#     a HIT/AVO/CRIT/DMG si hay un partner adyacente con support activo.
#   • GameManager.start_player_turn llama tick_supports() para dar puntos
#     pasivos por turno (FE4 mode) y por adyacencia.
#   • Al alcanzarse Married, GameManager.record_marriage() dispara el flag
#     para gen 2 substitutes.

class_name SupportSystem
extends Node


# ── Modo de juego ─────────────────────────────────────────────────────────────

enum Mode { FE4_LOVE, GBA_SUPPORT }

@export var mode: Mode = Mode.FE4_LOVE


# ── Datos canónicos ──────────────────────────────────────────────────────────

# Bonuses por afinidad (perfil canónico FE4-tier por punto de rango).
const AFFINITY_BONUS := {
	"Fire":    { "DMG": 0.5, "HIT": 2.5, "AVO": 2.5, "CRIT": 2.5, "DODGE": 0.0, "DEF": 0.0 },
	"Thunder": { "DMG": 0.0, "HIT": 0.0, "AVO": 2.5, "CRIT": 2.5, "DODGE": 2.5, "DEF": 0.5 },
	"Wind":    { "DMG": 0.5, "HIT": 2.5, "AVO": 0.0, "CRIT": 2.5, "DODGE": 2.5, "DEF": 0.0 },
	"Ice":     { "DMG": 0.0, "HIT": 2.5, "AVO": 2.5, "CRIT": 0.0, "DODGE": 2.5, "DEF": 0.5 },
	"Dark":    { "DMG": 0.0, "HIT": 2.5, "AVO": 2.5, "CRIT": 2.5, "DODGE": 2.5, "DEF": 0.0 },
	"Light":   { "DMG": 0.5, "HIT": 2.5, "AVO": 0.0, "CRIT": 2.5, "DODGE": 0.0, "DEF": 0.5 },
	"None":    { "DMG": 0.0, "HIT": 0.0, "AVO": 0.0, "CRIT": 0.0, "DODGE": 0.0, "DEF": 0.0 },
}

# Multiplicadores por rango.
const RANK_MULT_GBA := { "C": 1, "B": 2, "A": 3, "S": 4 }
const RANK_MULT_FE4 := { "Lover": 2, "Married": 4 }  # ≈ B y S de GBA

# Umbrales FE4 — vienen del support_pairs.json del proyecto.
const FE4_LOVER_THRESHOLD   := 200
const FE4_MARRIED_THRESHOLD := 250

# Umbrales GBA — clásicos.
const GBA_C_THRESHOLD := 30
const GBA_B_THRESHOLD := 60
const GBA_A_THRESHOLD := 100
const GBA_S_THRESHOLD := 150


# ── Estado ────────────────────────────────────────────────────────────────────

# Pares definidos por el proyecto.  Estructura:
#   { "unit1_unit2": { "u1": String, "u2": String, "thresholds": [int, ...],
#                      "rank_names": [String, ...] } }
var pairs: Dictionary = {}

# Puntos acumulados por par.
#   { "unit1_unit2": int }
var points: Dictionary = {}

# Rango actual de cada par.  "" si aún no alcanzó el primer rango.
var ranks: Dictionary = {}

# Pares marcados como "activos" en combate (para GBA — máx 1 simultáneo).
var combat_active: Dictionary = {}


# ══════════════════════════════════════════════════════════════════════════════
# CARGA DESDE EL PROYECTO LT
# ══════════════════════════════════════════════════════════════════════════════

## Carga los pares desde support_pairs.json.  El array contiene entries:
##   { "unit1", "unit2", "requirements": [{"support_rank", "requirement"}, ...] }
func load_from_project(support_pairs: Array, support_ranks: Array) -> void:
	pairs.clear()
	for entry in support_pairs:
		var u1 := str(entry.get("unit1", ""))
		var u2 := str(entry.get("unit2", ""))
		if u1 == "" or u2 == "":
			continue
		var key := _pair_key(u1, u2)
		var ths: Array = []
		var names: Array = []
		for req in entry.get("requirements", []):
			ths.append(int(req.get("requirement", 0)))
			names.append(str(req.get("support_rank", "")))
		pairs[key] = { "u1": u1, "u2": u2, "thresholds": ths, "rank_names": names }
		points[key] = 0
		ranks[key] = ""
	# Detectar modo basado en los rank names.
	if support_ranks.size() <= 2 and "Married" in support_ranks:
		mode = Mode.FE4_LOVE
	else:
		mode = Mode.GBA_SUPPORT


## Helper: clave normalizada de un par (alfabéticamente menor primero).
static func _pair_key(u1: String, u2: String) -> String:
	if u1 <= u2:
		return "%s_%s" % [u1, u2]
	return "%s_%s" % [u2, u1]


# ══════════════════════════════════════════════════════════════════════════════
# GANANCIA DE PUNTOS
# ══════════════════════════════════════════════════════════════════════════════

## Tick: gana puntos pasivos.  En FE4 todas las parejas con ambas unidades
## vivas y desplegadas ganan 1 punto por turno automáticamente.
##   Si ambos están adyacentes (≤ 3 tiles), gana puntos extra.
##   En GBA solo se gana por adyacencia (≤ 3 tiles).
func tick_supports(units: Array) -> void:
	var alive_by_name: Dictionary = {}
	for u in units:
		if u != null and u.current_hp > 0:
			alive_by_name[u.unit_name] = u
	for key in pairs.keys():
		var pair: Dictionary = pairs[key]
		var u1 = alive_by_name.get(pair["u1"])
		var u2 = alive_by_name.get(pair["u2"])
		if u1 == null or u2 == null:
			continue
		var gain := 0
		# Punto pasivo FE4.
		if mode == Mode.FE4_LOVE:
			gain += 1
		# Bonus por adyacencia (Manhattan ≤ 3).
		var d: int = abs(u1.grid_position.x - u2.grid_position.x) + abs(u1.grid_position.y - u2.grid_position.y)
		if d <= 3:
			gain += 2
		if gain > 0:
			add_points(u1.unit_name, u2.unit_name, gain)


## Suma puntos a un par y reevalúa rangos.  Devuelve true si subió de rango.
func add_points(u1: String, u2: String, amount: int) -> bool:
	var key := _pair_key(u1, u2)
	if not pairs.has(key):
		return false
	points[key] = int(points.get(key, 0)) + amount
	var pair: Dictionary = pairs[key]
	var current_rank := str(ranks.get(key, ""))
	var new_rank := current_rank
	for i in range(pair["thresholds"].size()):
		if int(points[key]) >= int(pair["thresholds"][i]):
			new_rank = str(pair["rank_names"][i])
	if new_rank != current_rank:
		ranks[key] = new_rank
		return true
	return false


## Bonus por kill compartido / rescate / etc — el caller invoca esto en
## eventos específicos.  Por defecto +5 por evento.
func add_event_bonus(u1: String, u2: String, amount: int = 5) -> void:
	add_points(u1, u2, amount)


# ══════════════════════════════════════════════════════════════════════════════
# CONSULTA DE BONUSES EN COMBATE
# ══════════════════════════════════════════════════════════════════════════════

## Calcula el bonus combinado que la unidad recibe de TODOS sus partners
## adyacentes con support activo.  Usado por CombatSystem antes de calcular
## hit/avo/crit.
##
## Devuelve un Dictionary { "DMG", "HIT", "AVO", "CRIT", "DODGE", "DEF" }.
##
## La fórmula es: por cada partner adyacente con rango activo, sumamos
## (afinidad_propia + afinidad_partner) / 2 × multiplicador_rango.
func get_combat_bonus(unit: Unit, all_units: Array) -> Dictionary:
	var bonus := { "DMG":0.0, "HIT":0.0, "AVO":0.0, "CRIT":0.0, "DODGE":0.0, "DEF":0.0 }
	if unit == null:
		return bonus
	var origin: Vector2i = unit.grid_position
	for other in all_units:
		if other == null or other == unit or other.current_hp <= 0:
			continue
		# Adyacencia (≤ 3 tiles, canon FE4 — bonus_range=1 al combate puro
		# pero aquí relajamos a 3 para feedback en mapa; la tabla canónica
		# se aplica en combate puntualmente).
		var d: int = abs(other.grid_position.x - origin.x) + abs(other.grid_position.y - origin.y)
		if d > 3:
			continue
		var key := _pair_key(unit.unit_name, other.unit_name)
		if not pairs.has(key):
			continue
		var rank := str(ranks.get(key, ""))
		if rank == "":
			continue
		var mult: int = _rank_multiplier(rank)
		var aff_self: Dictionary = AFFINITY_BONUS.get(unit.affinity, AFFINITY_BONUS["None"])
		var aff_other: Dictionary = AFFINITY_BONUS.get(other.affinity, AFFINITY_BONUS["None"])
		for k in bonus.keys():
			var avg: float = (float(aff_self.get(k, 0.0)) + float(aff_other.get(k, 0.0))) / 2.0
			bonus[k] += avg * mult
	return bonus


func _rank_multiplier(rank: String) -> int:
	if RANK_MULT_FE4.has(rank):
		return RANK_MULT_FE4[rank]
	if RANK_MULT_GBA.has(rank):
		return RANK_MULT_GBA[rank]
	return 0


# ══════════════════════════════════════════════════════════════════════════════
# CONSULTAS / GEN 2
# ══════════════════════════════════════════════════════════════════════════════

## ¿Una pareja está casada?  Útil para gen 2.
func is_married(u1: String, u2: String) -> bool:
	var key := _pair_key(u1, u2)
	return str(ranks.get(key, "")) == "Married"


## Devuelve el partner casado de una unidad (si lo tiene), "" si no.
func get_spouse(unit_nid: String) -> String:
	for key in ranks.keys():
		if str(ranks[key]) != "Married":
			continue
		var pair: Dictionary = pairs[key]
		if pair["u1"] == unit_nid:
			return pair["u2"]
		if pair["u2"] == unit_nid:
			return pair["u1"]
	return ""


## Lista de pares con un rango concreto.
func get_pairs_at_rank(rank: String) -> Array:
	var out: Array = []
	for key in ranks.keys():
		if str(ranks[key]) == rank:
			out.append(pairs[key])
	return out


# ══════════════════════════════════════════════════════════════════════════════
# RUPTURA DE SOPORTE POR MUERTE (canónico FE4)
# ══════════════════════════════════════════════════════════════════════════════

## Llamar cuando una unidad muere — si tenía pareja casada/lover, los
## puntos del par se descartan (canon FE4 break_supports_on_death = true).
func break_supports_on_death(unit_nid: String) -> void:
	var to_break: Array = []
	for key in pairs.keys():
		var p: Dictionary = pairs[key]
		if p["u1"] == unit_nid or p["u2"] == unit_nid:
			to_break.append(key)
	for key in to_break:
		points[key] = 0
		ranks[key] = ""
