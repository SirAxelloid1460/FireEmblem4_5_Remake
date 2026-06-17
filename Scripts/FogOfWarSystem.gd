# FogOfWarSystem.gd
# Sistema de Fog of War estilo Fire Emblem GBA (FE6/7/8) y FE5 (Thracia).
#
# REGLAS (lock):
#   • Rango base de visión: 3 tiles en distancia Manhattan (radio).
#   • Thieves / Rogues / Assassins: +5 tiles (canon GBA — vision = 8).
#       En FE5 los thieves NO ganaban bonus; el flag está expuesto vía
#       constructor para poder modelar ambos juegos.
#   • Voladores: SIN bonus (canon GBA — los voladores no veían más lejos).
#   • Item Torch: añade un bonus de visión que decrece -1/turno hasta 0.
#       Se modela como skill temporal "TorchVision" con turnos restantes.
#       El skill_components/decreasing_sight_range_bonus de LT define un
#       bonus inicial (FE5: +4) que decrece en cada upkeep.
#   • Lo "visible" para el jugador es la unión de los radios de TODAS sus
#     unidades vivas; si está en al menos uno, el tile se considera visto.
#   • Las unidades enemigas dentro de tile visible son reveladas; fuera de
#     él no se ven en absoluto.
#   • Los terrenos opaque (forest/peak/mountain/wall) bloquean la visión
#     más allá si DB.constants.fog_los está activado.  Por defecto FE GBA
#     no usaba LoS (visión circular libre); se deja como flag.
#   • Solo activo si chapter.fow_enabled = true.
#
# REFERENCIA LT-maker:  engine/game_board.py — funciones update_fow,
# in_vision, get_fog_of_war_radius. Engine line_of_sight.py para el LoS.
#
# Conexión con otros sistemas:
#   • Unit — lee tags ("Flying"), unit_class, skills (para Torch).
#   • Grid  — lee terrain_type (para opacidad).
#   • TerrainSystem.is_opaque() — fuente de verdad de qué bloquea visión.
#   • GameManager.start_player_turn() / start_enemy_turn() — invocan
#       update_team_vision() al inicio de cada fase y on_unit_moved() tras
#       cada movimiento.

class_name FogOfWarSystem
extends RefCounted

# ── Configuración (estilo GBA) ────────────────────────────────────────────────

const VISION_BASE        := 3   # FE6/7/8 — todas las unidades.
const VISION_THIEF_BONUS := 5   # +5 ⇒ 8 tiles.  FE5 = 0 (configurable).
const VISION_FLYING_BONUS := 0  # GBA canon — sin bonus.

# Clases que se consideran "thief tier".  Cubre los nids reales de los
# proyectos GotHW (FE4) y Thracia776 (FE5).
const THIEF_CLASSES := ["Thief", "AThief", "BThief", "Rogue",
		"ThiefFighter", "Assassin", "Dancer"]


# ── Estado por capítulo (instancia) ──────────────────────────────────────────

var enabled: bool = false
var grid: Grid = null
var use_line_of_sight: bool = false   # True ⇒ los terrenos opaque bloquean.
var thief_bonus: int = VISION_THIEF_BONUS  # 5 en GBA, 0 si se quiere FE5 puro.

# Set de Vector2i visibles para el jugador este turno.
var player_vision: Dictionary = {}
# Set de Vector2i visibles para el enemigo (solo se usa si AI también
# respeta FoW; LT lo controla con DB.constants.ai_fog_of_war).
var enemy_vision: Dictionary = {}

# Bonus temporal por unidad — clave = unit, valor = turnos restantes.
# Se actualiza cada turno con tick_torches().
var torch_bonus: Dictionary = {}

# Si _base_override >= 0, sobrescribe VISION_BASE en get_vision_range.
var _base_override: int = -1


# ══════════════════════════════════════════════════════════════════════════════
# INICIALIZACIÓN
# ══════════════════════════════════════════════════════════════════════════════

func _init(p_grid: Grid = null, p_enabled: bool = false,
		p_los: bool = false, p_thief_bonus: int = VISION_THIEF_BONUS):
	grid = p_grid
	enabled = p_enabled
	use_line_of_sight = p_los
	thief_bonus = p_thief_bonus


# ══════════════════════════════════════════════════════════════════════════════
# CÁLCULO DE RANGO DE VISIÓN POR UNIDAD
# ══════════════════════════════════════════════════════════════════════════════

## Devuelve el rango efectivo de una unidad sumando base + bonus de clase
## + bonus por torch activo + bonus volador.
func get_vision_range(unit: Unit) -> int:
	if unit == null or unit.current_hp <= 0:
		return 0
	var r: int = _base_override if _base_override >= 0 else VISION_BASE
	if unit.unit_class in THIEF_CLASSES:
		r += thief_bonus
	if "Flying" in unit.tags:
		r += VISION_FLYING_BONUS
	# Bonus por Torch activo (turnos restantes ≥ 1).
	if unit in torch_bonus:
		var remaining: int = torch_bonus[unit].get("turns", 0)
		if remaining > 0:
			# El bonus que muestra Torch en FE5 es +4 inicial decreciente.
			# Aquí el "valor inicial" se almacena al activarlo y "turns"
			# hace de countdown — se aplica el min entre los dos.
			var initial: int = torch_bonus[unit].get("bonus", 0)
			r += min(remaining, initial)
	return r


## Activa el efecto Torch sobre una unidad.
##   bonus  : tiles iniciales (FE5 Torch = 4, Torch staff = mayor).
##   turns  : turnos que dura.  Si turns == bonus, decrece naturalmente.
func apply_torch(unit: Unit, bonus: int = 4, turns: int = 4) -> void:
	if unit == null:
		return
	torch_bonus[unit] = { "bonus": bonus, "turns": turns }


## Decrementa los turnos restantes de los Torch activos.  Llamar al inicio
## de cada turno del jugador (FE5 los descuenta así).
func tick_torches() -> void:
	for u in torch_bonus.keys():
		torch_bonus[u]["turns"] = int(torch_bonus[u]["turns"]) - 1
		if torch_bonus[u]["turns"] <= 0:
			torch_bonus.erase(u)


# ══════════════════════════════════════════════════════════════════════════════
# CÁLCULO DE VISIBILIDAD POR EQUIPO
# ══════════════════════════════════════════════════════════════════════════════

## Recalcula el set de tiles visibles para un bando dado a partir de las
## posiciones actuales de sus unidades.  El resultado se guarda en
## player_vision o enemy_vision según el team.
func update_team_vision(team: String, units: Array) -> void:
	var visible: Dictionary = {}
	if not enabled:
		# FoW desactivado ⇒ todo visible.  Se rellena al primer is_visible().
		_set_team_visible(team, visible, true)
		return
	for u in units:
		if u == null or u.current_hp <= 0:
			continue
		var r := get_vision_range(u)
		var origin: Vector2i = u.grid_position
		_paint_vision(visible, origin, r)
	_set_team_visible(team, visible, false)


func _set_team_visible(team: String, visible: Dictionary, all_visible: bool) -> void:
	if team == "player":
		player_vision = visible
		if all_visible:
			player_vision = {}  # vacío + enabled=false ⇒ is_visible() devuelve true
	else:
		enemy_vision = visible
		if all_visible:
			enemy_vision = {}


## Pinta todos los tiles dentro de un radio Manhattan desde un origen,
## opcionalmente respetando opacidad (LoS).
func _paint_vision(visible: Dictionary, origin: Vector2i, radius: int) -> void:
	if grid == null:
		return
	for dx in range(-radius, radius + 1):
		var max_dy: int = radius - abs(int(dx))
		for dy in range(-max_dy, max_dy + 1):
			var p := origin + Vector2i(dx, dy)
			if not grid.is_valid_position(p):
				continue
			if use_line_of_sight and not _has_line_of_sight(origin, p):
				continue
			visible[p] = true


## Implementación simple de Bresenham para LoS — bloquea si encuentra un
## terreno opaque entre origen y destino (sin contar los extremos).
##
## Tomado del patrón de engine/line_of_sight.py de LT-maker, simplificado.
func _has_line_of_sight(a: Vector2i, b: Vector2i) -> bool:
	if a == b:
		return true
	var x0 := a.x; var y0 := a.y
	var x1 := b.x; var y1 := b.y
	var dx: int = abs(x1 - x0)
	var dy: int = abs(y1 - y0)
	var sx := 1 if x0 < x1 else -1
	var sy := 1 if y0 < y1 else -1
	var err := dx - dy
	# El primer y último tile no bloquean su propio LoS.
	while true:
		var e2 := 2 * err
		if e2 > -dy:
			err -= dy; x0 += sx
		if e2 < dx:
			err += dx; y0 += sy
		if x0 == x1 and y0 == y1:
			break
		var p := Vector2i(x0, y0)
		var t := TerrainSystem.get_terrain_at(grid, p)
		if TerrainSystem.is_opaque(t):
			return false
	return true


# ══════════════════════════════════════════════════════════════════════════════
# CONSULTAS PÚBLICAS
# ══════════════════════════════════════════════════════════════════════════════

## ¿Una posición es visible para un equipo?
##   Si FoW está desactivado, todo es visible.
func is_visible(pos: Vector2i, team: String = "player") -> bool:
	if not enabled:
		return true
	if team == "player":
		return player_vision.has(pos)
	return enemy_vision.has(pos)


## ¿Una unidad es visible para un equipo?  Las unidades del propio bando
## siempre se ven; los enemigos sólo si están en un tile visible.
func is_unit_visible(unit: Unit, viewer_team: String = "player") -> bool:
	if not enabled or unit == null:
		return true
	var unit_team := "player" if unit.is_player_unit else "enemy"
	if unit_team == viewer_team:
		return true
	return is_visible(unit.grid_position, viewer_team)


## Filtra una lista de unidades dejando solo las visibles para el equipo
## dado.  Útil para que el target picker / preview solo muestre lo que el
## jugador ve.
func filter_visible_units(units: Array, viewer_team: String = "player") -> Array:
	if not enabled:
		return units.duplicate()
	var out: Array = []
	for u in units:
		if is_unit_visible(u, viewer_team):
			out.append(u)
	return out


# ══════════════════════════════════════════════════════════════════════════════
# CONFIGURACIÓN POR CAPÍTULO
# ══════════════════════════════════════════════════════════════════════════════

## Lee los flags de un capítulo cargado (campos del JSON LT-maker o equiv.):
##   level_vars._fog_of_war          : bool — activa FoW
##   level_vars._fog_of_war_radius   : int  — overrides VISION_BASE
##   constants.fog_los               : bool — usa Line of Sight
func configure_from_chapter(chapter_data: Dictionary) -> void:
	enabled = bool(chapter_data.get("fow_enabled",
			chapter_data.get("_fog_of_war", false)))
	use_line_of_sight = bool(chapter_data.get("fog_los", false))
	# Si el capítulo define un radio override, se aplica desde el constructor
	# del sistema o vía set_base_vision (no muta la constante global).
	if chapter_data.has("_fog_of_war_radius"):
		_base_override = int(chapter_data["_fog_of_war_radius"])
	else:
		_base_override = -1
