# TerrainSystem.gd
# Sistema de terrain — DEF/AVO/regeneración por tipo de terreno.
#
# DATOS CANÓNICOS (LT-maker GotHW + Thracia776, idénticos en ambos proyectos):
#   Forest : DEF +1, AVO +20
#   Peak   : DEF +2, AVO +40   (hill canónico Thracia)
#   Fort   : DEF +3, AVO +20, Regen 75 % MaxHP/turno
#   Gate   : DEF +3, AVO +20, Regen 20 %
#   Throne : DEF +3, AVO +10, Regen 20 %
#
# Se conecta con:
#   • CombatSystem.calculate_combat() — recibe terrain_atk / terrain_def
#       como Dictionary {"AVO":int, "DEF":int}.  Esta clase produce ese
#       diccionario vía get_combat_terrain(unit) o get_combat_terrain_at(pos).
#   • GameManager.start_player_turn() / start_enemy_turn() — invocan
#       process_turn_regeneration(units) para curar unidades sobre Fort/
#       Gate/Throne al inicio de su fase.
#   • Grid.tiles  — TerrainSystem lee las claves "terrain_type",
#       "defense_bonus" y "avoid_bonus" que ya existen en cada tile.
#
# FE4 NOTA:  En Genealogy NO había los castillos pequeños tipo Fort.  Sólo
# castillos principales (= "Castle"), que se modelan aquí como Throne con
# regen 20 %.  Si en algún capítulo se quiere desactivar la regen para una
# casilla concreta basta con poner terrain_type = "plain" en el tile.

class_name TerrainSystem
extends RefCounted

# ── Tabla canónica de terrenos ────────────────────────────────────────────────
#
# Cada entrada:
#   def_bonus    : int  – sumado a DEF efectivo del defensor
#   avo_bonus    : int  – sumado a AVO del defensor
#   regen_pct    : float – fracción de MaxHP curada al inicio del turno (0–1)
#   mov_cost     : float – coste de movimiento por tile (-1.0 = intransitable)
#                          FE4 usa costes decimales:
#                            plain = 1.0  (tile estándar)
#                            road  = 0.7  (caminos rápidos canon FE4)
#                            forest = 2.0 (movimiento doble)
#                            peak  = 4.0  (terreno muy difícil)
#                            mountain/wall/sea = -1.0 (intransitable)
#                          Pathfinding usa A* con costes float — soporta
#                          decimales nativamente, no necesita escalar ×10.
#   opaque       : bool  – bloquea línea de visión en FoW
#   heal_only_my : bool  – sólo cura al equipo que controle la casilla
#                          (Castle/Fort/Throne en originales)
#
# Los IDs siguen el formato LT-maker (mismos nids exactos en GotHW/Thracia776).

const TERRAIN_DATA: Dictionary = {
	# id        def avo regen mov     opa heal_team_only
	"plain":    { "def":0, "avo":0,  "regen":0.0,  "mov":1.0,  "opaque":false, "team_only":false },
	"road":     { "def":0, "avo":0,  "regen":0.0,  "mov":0.7,  "opaque":false, "team_only":false },
	"bridge":   { "def":0, "avo":0,  "regen":0.0,  "mov":0.7,  "opaque":false, "team_only":false },
	"floor":    { "def":0, "avo":0,  "regen":0.0,  "mov":1.0,  "opaque":false, "team_only":false },
	"sand":     { "def":0, "avo":0,  "regen":0.0,  "mov":2.0,  "opaque":false, "team_only":false },
	"stairs":   { "def":0, "avo":0,  "regen":0.0,  "mov":1.0,  "opaque":false, "team_only":false },
	"forest":   { "def":1, "avo":20, "regen":0.0,  "mov":2.0,  "opaque":true,  "team_only":false },
	"thicket":  { "def":1, "avo":30, "regen":0.0,  "mov":3.0,  "opaque":true,  "team_only":false },
	"hill":     { "def":1, "avo":20, "regen":0.0,  "mov":2.0,  "opaque":false, "team_only":false },
	"peak":     { "def":2, "avo":40, "regen":0.0,  "mov":4.0,  "opaque":true,  "team_only":false },
	"mountain": { "def":2, "avo":40, "regen":0.0,  "mov":-1.0, "opaque":true,  "team_only":false },
	"cliff":    { "def":0, "avo":0,  "regen":0.0,  "mov":-1.0, "opaque":true,  "team_only":false },
	"river":    { "def":0, "avo":0,  "regen":0.0,  "mov":4.0,  "opaque":false, "team_only":false },
	"lake":     { "def":0, "avo":0,  "regen":0.0,  "mov":-1.0, "opaque":false, "team_only":false },
	"sea":      { "def":0, "avo":0,  "regen":0.0,  "mov":-1.0, "opaque":false, "team_only":false },
	"wall":     { "def":0, "avo":0,  "regen":0.0,  "mov":-1.0, "opaque":true,  "team_only":false },
	"fence":    { "def":0, "avo":0,  "regen":0.0,  "mov":-1.0, "opaque":true,  "team_only":false },
	"pillar":   { "def":1, "avo":10, "regen":0.0,  "mov":1.0,  "opaque":true,  "team_only":false },
	"barrel":   { "def":1, "avo":10, "regen":0.0,  "mov":1.0,  "opaque":true,  "team_only":false },
	"ruins":    { "def":1, "avo":10, "regen":0.0,  "mov":1.0,  "opaque":true,  "team_only":false },
	"door":     { "def":0, "avo":0,  "regen":0.0,  "mov":1.0,  "opaque":true,  "team_only":false },
	# Curación + bonuses defensivos (FE4/FE5 canon)
	"fort":     { "def":3, "avo":20, "regen":0.75, "mov":1.0,  "opaque":false, "team_only":true  },
	"gate":     { "def":3, "avo":20, "regen":0.20, "mov":1.0,  "opaque":false, "team_only":true  },
	"throne":   { "def":3, "avo":10, "regen":0.20, "mov":1.0,  "opaque":false, "team_only":true  },
	# Estructuras visitables
	"village":  { "def":0, "avo":0,  "regen":0.0,  "mov":1.0,  "opaque":false, "team_only":false },
	"house":    { "def":0, "avo":0,  "regen":0.0,  "mov":1.0,  "opaque":false, "team_only":false },
	"armory":   { "def":0, "avo":0,  "regen":0.0,  "mov":1.0,  "opaque":false, "team_only":false },
	"vendor":   { "def":0, "avo":0,  "regen":0.0,  "mov":1.0,  "opaque":false, "team_only":false },
	"chest":    { "def":0, "avo":0,  "regen":0.0,  "mov":1.0,  "opaque":false, "team_only":false },
	"arena":    { "def":0, "avo":0,  "regen":0.0,  "mov":1.0,  "opaque":false, "team_only":false },
}

# ── Identificadores que se consideran "fortalezas" para reclamarlas ──────────
const FORTRESS_TERRAIN := ["fort", "gate", "throne"]


# ══════════════════════════════════════════════════════════════════════════════
# CONSULTA DE TERRENOS
# ══════════════════════════════════════════════════════════════════════════════

## Devuelve los datos completos de un tipo de terreno.
## Si el id no existe, devuelve los datos de "plain".
static func get_terrain_data(terrain_id: String) -> Dictionary:
	return TERRAIN_DATA.get(terrain_id, TERRAIN_DATA["plain"])


## Devuelve el ID de terreno que ocupa una unidad mirando el grid.
## El campo "terrain_type" se establece al cargar el tilemap del capítulo.
static func get_terrain_at(grid: Grid, pos: Vector2i) -> String:
	if not grid or not grid.tiles.has(pos):
		return "plain"
	return grid.tiles[pos].get("terrain_type", "plain")


## Devuelve un Dictionary con las claves que CombatSystem espera:
##   { "DEF": int, "AVO": int }
## Si la unidad es voladora la mayoría de FE clásicos ignoran el bonus de
## terreno — replicamos esa regla.
static func get_combat_terrain(unit: Unit, grid: Grid) -> Dictionary:
	if unit == null:
		return { "DEF": 0, "AVO": 0 }
	# Voladores ignoran terrain bonus (canon FE4/FE5/GBA).
	if "Flying" in unit.tags:
		return { "DEF": 0, "AVO": 0 }
	var data := get_terrain_data(get_terrain_at(grid, unit.grid_position))
	return { "DEF": int(data["def"]), "AVO": int(data["avo"]) }


## Variante directa: dado un id de terreno, produce el dict para combate.
static func get_combat_terrain_from_id(terrain_id: String, is_flying: bool = false) -> Dictionary:
	if is_flying:
		return { "DEF": 0, "AVO": 0 }
	var data := get_terrain_data(terrain_id)
	return { "DEF": int(data["def"]), "AVO": int(data["avo"]) }


## Coste de movimiento al entrar en un terreno.
##   -1 si es intransitable.
##   En FE4/FE5 algunas clases tienen mov_groups distintos (ej. caballos no
##   pueden cruzar Mountain) — se delega esa lógica a Pathfinding leyendo
##   class_movement.json.  Esta función da el coste BASE.
static func get_movement_cost(terrain_id: String) -> float:
	return float(get_terrain_data(terrain_id).get("mov", 1.0))


## ¿El terreno bloquea línea de visión en Fog of War?
static func is_opaque(terrain_id: String) -> bool:
	return bool(get_terrain_data(terrain_id).get("opaque", false))


# ══════════════════════════════════════════════════════════════════════════════
# REGENERACIÓN AL INICIO DEL TURNO
# ══════════════════════════════════════════════════════════════════════════════

## Aplica curación a todas las unidades del bando que comienza turno y que
## se encuentran sobre un terreno con regen activa.
##
## Reglas:
##   • Solo cura a unidades cuyo team coincide (controlled_team) — Forts/Gates
##     enemigos no curan al jugador y viceversa.  En FE4/FE5 los castillos
##     se reclaman al pisarlos; aquí asumimos que el equipo de la unidad
##     parado en él lo controla durante ese turno.
##   • La curación es int(MaxHP * regen_pct), mínimo 1 si regen_pct > 0.
##   • Devuelve un Array con [{"unit":Unit, "amount":int, "terrain":String}, ...]
##     para que el GameManager pueda mostrar números flotantes/animaciones.
static func process_turn_regeneration(units: Array, grid: Grid) -> Array:
	var heals: Array = []
	for u in units:
		if u == null or u.current_hp <= 0:
			continue
		if u.current_hp >= u.max_hp:
			continue
		var terrain_id := get_terrain_at(grid, u.grid_position)
		var data := get_terrain_data(terrain_id)
		var pct: float = data.get("regen", 0.0)
		# Regeneración por skill (Life/Recover/Regeneration/Circlet). No apila con
		# el terreno: se toma la mayor de ambas.
		if u.has_method("get_regen_fraction"):
			pct = max(pct, u.get_regen_fraction())
		if pct <= 0.0:
			continue
		var heal: int = max(1, int(u.max_hp * pct))
		var new_hp: int = min(u.max_hp, u.current_hp + heal)
		var actual: int = new_hp - u.current_hp
		if actual <= 0:
			continue
		u.current_hp = new_hp
		if u.has_signal("hp_changed"):
			u.hp_changed.emit(u.current_hp, u.max_hp)
		heals.append({ "unit": u, "amount": actual, "terrain": terrain_id })
	return heals


## ¿Un terreno permite reclamarlo (es Fort/Gate/Throne)?  Útil para Seize.
static func is_fortress(terrain_id: String) -> bool:
	return terrain_id in FORTRESS_TERRAIN


# ══════════════════════════════════════════════════════════════════════════════
# UTILIDADES DE INSPECCIÓN — para UI y debug
# ══════════════════════════════════════════════════════════════════════════════

## Texto descriptivo para mostrar al hover sobre un tile.
static func describe(terrain_id: String) -> String:
	var d := get_terrain_data(terrain_id)
	var parts: Array[String] = [terrain_id.capitalize()]
	if d["def"]  != 0: parts.append("DEF +%d" % d["def"])
	if d["avo"]  != 0: parts.append("AVO +%d" % d["avo"])
	if d["regen"] > 0: parts.append("Regen %d%%" % int(d["regen"] * 100.0))
	if d["mov"]  == -1.0: parts.append("Impassable")
	elif d["mov"] != 1.0:  parts.append("Mov cost %.1f" % d["mov"])
	return "  ".join(parts)
