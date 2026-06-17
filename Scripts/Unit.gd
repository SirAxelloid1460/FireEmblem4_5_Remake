# Unit.gd
# Clase base para todas las unidades del juego.
# Contiene stats, inventario, skills, estado y todos los métodos
# requeridos por CombatSystem, CaptureSystem e ItemSystem.

extends Node2D
class_name Unit

# ── Información básica ────────────────────────────────────────────────────────

@export var unit_name:     String = "Soldier"
@export var unit_class:    String = "Fighter"
@export var class_tier:    int    = 1       # 0=trainee, 1=base, 2=promoted, 3=elite
@export var level:         int    = 1
@export var is_player_unit: bool  = true
## Equipo: "player" | "enemy" | "other" | "ally". Lo fija LevelLoader.build_unit.
## Determina la paleta del map sprite (ver team_palette_index).
@export var team: String = "player"
@export var affinity:      String = ""      # Fire, Water, Wind, Earth, Light, Dark

## Género de la unidad — se usa para resolver variantes de clase
## (Paladin masculino vs femenino) y para retratos/diálogos.
##   "M" = masculino
##   "F" = femenino
##   "U" = universal (genéricos sin género definido — los enemigos comunes)
@export_enum("M", "F", "U") var gender: String = "M"

# Tags (Mounted, Flying, Armor, Lord, BaldrHeir, etc.)
@export var tags: Array[String] = []

# ── Stats base ────────────────────────────────────────────────────────────────

@export_group("Stats")
@export var max_hp:       int = 20
@export var current_hp:   int = 20
@export var strength:     int = 5
@export var magic:        int = 0
@export var skill:        int = 5
@export var speed:        int = 5
@export var luck:         int = 3
@export var defense:      int = 3
@export var resistance:   int = 0
@export var constitution: int = 5
@export var movement:     int = 5

# ── Estado de turno ───────────────────────────────────────────────────────────

var grid_position: Vector2i
var has_moved:   bool = false
var has_acted:   bool = false
var is_selected: bool = false

# ── Render de mapa ──────────────────────────────────────────────────────────
# Sprite real de la unidad en el mapa (ver UnitMapSprite.gd). Si la clase no
# tiene sprite, _has_map_sprite queda false y se dibuja el marcador de color.
var _map_sprite: UnitMapSprite = null
var _has_map_sprite: bool = false
# Y local de los pies (línea de suelo) para alinear anillo de selección y HP bar
# con el sprite. Se fija en setup_map_sprite desde cell_size (= cell_size*0.375).
var _feet_y: float = 30.0

# ── Equipo e inventario ───────────────────────────────────────────────────────

var weapon:    Weapon = null
var inventory: Array  = []      # Array de ItemData (max 5)

# ── Skills ────────────────────────────────────────────────────────────────────

# Skills permanentes (de clase, sangre sagrada, manuales)
var skills: Array[String] = []
# Skills temporales otorgadas por items on_hold (key = skill_id, value = source_item_id)
var _temp_skills: Dictionary = {}

# ── Weapon EXP / rangos (fiel a LT-maker) ──────────────────────────────────────
# wexp por tipo de arma (Sword/Lance/Axe/Bow/Anima/Light/Dark/Staff...).
# El rango efectivo se deriva del wexp vía WEAPON_RANK_THRESHOLDS.
# CombatSystem._gain_wexp() ya llama a gain_weapon_exp() tras cada golpe.
var wexp: Dictionary = {}

# Sangre sagrada (FE4). blood_nid → "Major" | "Minor".
# Ej. {"Baldr": "Major", "Naga": "Minor"}. La carga la hace el importador LT
# desde el proyecto GotHW (o se setea por tag *Heir al construir la unidad).
var holy_blood: Dictionary = {}
# Modificadores de stats por items on_hold (key = stat, value = total bonus)
var _item_bonuses: Dictionary = {}

# ── Status activos ────────────────────────────────────────────────────────────

# Cada status: {"id": String, "data": Dictionary, "turns_remaining": int}
var _statuses: Array = []
# Modificadores de stats por status/carrying (key = modifier_id, value = {stat: delta})
var _stat_modifiers: Dictionary = {}

# ── Señales ───────────────────────────────────────────────────────────────────

signal unit_selected(unit: Unit)
signal unit_deselected(unit: Unit)
signal unit_died(unit: Unit)
signal hp_changed(new_hp: int, max_hp: int)

# ══════════════════════════════════════════════════════════════════════════════
# CLASE Y TIER
# ══════════════════════════════════════════════════════════════════════════════

func get_class_tier() -> int:
	return class_tier

func has_tag(tag: String) -> bool:
	return tag in tags

# ══════════════════════════════════════════════════════════════════════════════
# SKILLS
# ══════════════════════════════════════════════════════════════════════════════

func has_skill(skill_id: String) -> bool:
	if skill_id in skills: return true
	if skill_id in _temp_skills: return true
	return false

func learn_skill(skill_id: String) -> void:
	if not skill_id in skills:
		skills.append(skill_id)

func remove_skill(skill_id: String) -> void:
	skills.erase(skill_id)

## Añade una skill temporal otorgada por un item (on_hold)
func add_temporary_skill(skill_id: String, source_item_id: String) -> void:
	_temp_skills[skill_id] = source_item_id

## Elimina todas las skills temporales de una fuente concreta
func remove_temporary_skills_by_source(source: String) -> void:
	var to_remove: Array[String] = []
	for skill_id in _temp_skills:
		if _temp_skills[skill_id] == source or source == "item":
			to_remove.append(skill_id)
	for skill_id in to_remove:
		_temp_skills.erase(skill_id)

# ══════════════════════════════════════════════════════════════════════════════
# WEAPON RANK & HOLY BLOOD   (fiel a LT-maker + reglas FE4 LOCKED del brief §4)
# ══════════════════════════════════════════════════════════════════════════════
#
# Thresholds de wexp AUTORITATIVOS de LT (game_data/weapon_ranks.json, idéntico
# en GotHW.ltproj y Thracia776.ltproj):
#   D=1  C=51  B=126  A=226  Holy=1023
# NO existen rangos "E" ni "S". El techo normal es A (226). "Holy" (1023) es un
# rango especial que SÓLO alcanzan las unidades con Major Blood de un cruzado:
# el resto lleva la habilidad NotHoly, que tapa el wexp en 226 (=A). Las armas
# sagradas se restringen además por prf_tags (XxxHeir) en LT.

const WEAPON_RANK_THRESHOLDS := {
	"D": 1, "C": 51, "B": 126, "A": 226, "Holy": 1023
}
const WEAPON_RANK_ORDER := ["D", "C", "B", "A", "Holy"]
const NOT_HOLY_CAP := 226  # wexp máximo (=A) para unidades con NotHoly

## Gana wexp en un tipo de arma. Replica action.GainWexp + el componente NotHoly
## de LT (wexp_multiplier 0 con condition wexp[type] >= 226). Las unidades sin
## Major Blood llevan NotHoly y topan en A (226); las que tienen Major Blood
## siguen subiendo hasta Holy (1023).
func gain_weapon_exp(weapon_type: String, amount: int) -> void:
	if weapon_type == "":
		return
	var current := int(wexp.get(weapon_type, 0))
	if has_skill("NotHoly") and current >= NOT_HOLY_CAP:
		return
	wexp[weapon_type] = current + max(0, amount)

## Rango (letra) que la unidad tiene en un tipo de arma según su wexp.
## Pura búsqueda por umbral: "Holy" sólo a wexp>=1023, inalcanzable con NotHoly.
func get_weapon_rank(weapon_type: String) -> String:
	var w: int = int(wexp.get(weapon_type, 0))
	var result := ""
	for r in WEAPON_RANK_ORDER:
		if w >= int(WEAPON_RANK_THRESHOLDS[r]):
			result = r
	return result

## Requirement numérico de un rango (para comparar can_equip).
static func rank_requirement(rank: String) -> int:
	return int(WEAPON_RANK_THRESHOLDS.get(rank, 1))

## ¿Puede equipar/usar esta arma? Fiel a LT (wexp del tipo >= requirement del
## rango exigido) + reglas Holy del proyecto.
## NOTA: en LT las armas sagradas se restringen por prf_tags (XxxHeir = Major
## Blood de ESE cruzado); por ahora Holy exige cualquier Major Blood.
func can_equip(w: Weapon) -> bool:
	if w == null:
		return false
	var required: String = str(w.weapon_rank)
	if required == "Holy" and (not has_major_blood() or has_skill("NotHoly")):
		return false
	return int(wexp.get(str(w.weapon_type), 0)) >= rank_requirement(required)

# ── Holy Blood ──────────────────────────────────────────────────────────────

## ¿Tiene Major Blood (de cualquier tipo, o de uno concreto)?
func has_major_blood(blood: String = "") -> bool:
	if blood != "":
		return holy_blood.get(blood, "") == "Major"
	return "Major" in holy_blood.values()

## ¿Tiene Minor Blood (de cualquier tipo, o de uno concreto)?
func has_minor_blood(blood: String = "") -> bool:
	if blood != "":
		return holy_blood.get(blood, "") == "Minor"
	return "Minor" in holy_blood.values()

## NotHoly = la unidad NO puede usar armas Holy★. La tienen automáticamente
## todas las unidades SIN Major Blood (Minor o sin sangre). Llamar tras fijar
## holy_blood (lo hace el importador LT al construir la unidad).
func refresh_holy_status() -> void:
	if has_major_blood():
		remove_skill("NotHoly")
	elif not has_skill("NotHoly"):
		learn_skill("NotHoly")

# ══════════════════════════════════════════════════════════════════════════════
# STATS CON MODIFICADORES
# ══════════════════════════════════════════════════════════════════════════════

## Stats efectivos incluyendo todos los modificadores activos
func get_effective_stat(stat: String) -> int:
	var base := _get_base_stat(stat)
	var bonus: int = _item_bonuses.get(stat, 0)
	var mod_total := 0
	for mod_id in _stat_modifiers:
		mod_total += _stat_modifiers[mod_id].get(stat, 0)
	return max(0, base + bonus + mod_total)

func _get_base_stat(stat: String) -> int:
	match stat:
		"HP":  return max_hp
		"STR": return strength
		"MAG": return magic
		"SKL": return skill
		"SPD": return speed
		"LCK": return luck
		"DEF": return defense
		"RES": return resistance
		"CON": return constitution
		"MOV": return movement
	return 0

## Bonuses de items on_hold
func add_item_bonus(stat: String, value: int) -> void:
	_item_bonuses[stat] = _item_bonuses.get(stat, 0) + value

func clear_item_bonuses() -> void:
	_item_bonuses.clear()

## Modificadores de status/carrying (usados por CaptureSystem y status effects)
func add_status_modifier(modifier_id: String, deltas: Dictionary) -> void:
	_stat_modifiers[modifier_id] = deltas

func remove_status_modifier(modifier_id: String) -> void:
	_stat_modifiers.erase(modifier_id)

## Mejora permanente de un stat (stat boosters)
func increase_stat_permanently(stat: String, amount: int) -> void:
	match stat:
		"HP":  max_hp       += amount; current_hp = min(current_hp + amount, max_hp)
		"STR": strength     += amount
		"MAG": magic        += amount
		"SKL": skill        += amount
		"SPD": speed        += amount
		"LCK": luck         += amount
		"DEF": defense      += amount
		"RES": resistance   += amount
		"CON": constitution += amount
		"MOV": movement     += amount

# ══════════════════════════════════════════════════════════════════════════════
# STATUS EFFECTS
# ══════════════════════════════════════════════════════════════════════════════

func apply_status(status_id: String, data: Dictionary = {}) -> void:
	# Evitar duplicados
	for s in _statuses:
		if s["id"] == status_id:
			s["data"] = data  # Refrescar
			return
	_statuses.append({"id": status_id, "data": data, "turns_remaining": data.get("duration", -1)})

func remove_status(status_id: String) -> void:
	_statuses = _statuses.filter(func(s): return s["id"] != status_id)

func has_status(status_id: String) -> bool:
	for s in _statuses:
		if s["id"] == status_id: return true
	return false

func tick_statuses() -> void:
	"""Llamar al inicio del turno de la unidad. Aplica efectos y reduce contadores."""
	var to_remove: Array[String] = []
	for s in _statuses:
		_apply_status_upkeep(s)
		if s["turns_remaining"] > 0:
			s["turns_remaining"] -= 1
			if s["turns_remaining"] == 0:
				to_remove.append(s["id"])
	for sid in to_remove:
		remove_status(sid)

func _apply_status_upkeep(status: Dictionary) -> void:
	var sid: String = status["id"]
	var data: Dictionary = status["data"]
	match sid:
		"HolyWater":
			# MAG decay: reduce el bonus 1 por turno hasta 0
			if _stat_modifiers.has("HolyWater"):
				_stat_modifiers["HolyWater"]["MAG"] -= 1
				if _stat_modifiers["HolyWater"]["MAG"] <= 0:
					remove_status_modifier("HolyWater")
					remove_status("HolyWater")
		"TorchVision":
			# El radio de visión decrece 1 por turno (manejado por FogOfWarSystem)
			pass
		"Poison":
			# Daño por turno
			take_damage(max(1, max_hp / 10))

# ══════════════════════════════════════════════════════════════════════════════
# CARRYING (rescate y captura)
# ══════════════════════════════════════════════════════════════════════════════

func is_carrying() -> bool:
	return has_meta("is_carrying_captive") and get_meta("is_carrying_captive") or \
		   has_meta("is_rescuing") and get_meta("is_rescuing")

func is_captured() -> bool:
	return has_meta("is_captured") and get_meta("is_captured")

## AID para el sistema de rescate (no captura)
## Infantería: CON - 1 | Montados: 25 - CON (pueden cargar más)
func get_aid() -> int:
	if "Mounted" in tags:
		return max(0, 25 - constitution)
	return max(0, constitution - 1)

# ══════════════════════════════════════════════════════════════════════════════
# CHARISMA (para CombatSystem)
# ══════════════════════════════════════════════════════════════════════════════

## CombatSystem llama esto para saber si hay una unidad con Charisma
## en radio 3. El GameManager debe actualizar este flag antes del combate.
var _charisma_in_range: bool = false

func is_in_charisma_range() -> bool:
	return _charisma_in_range

func set_charisma_range(value: bool) -> void:
	_charisma_in_range = value

# ══════════════════════════════════════════════════════════════════════════════
# COMBATE Y HP
# ══════════════════════════════════════════════════════════════════════════════

func take_damage(damage: int) -> void:
	current_hp = max(0, current_hp - damage)
	hp_changed.emit(current_hp, max_hp)
	update_visual()
	if current_hp <= 0:
		die()

func heal(amount: int) -> void:
	current_hp = min(max_hp, current_hp + amount)
	hp_changed.emit(current_hp, max_hp)
	update_visual()

func die() -> void:
	unit_died.emit(self)
	queue_free()

# ══════════════════════════════════════════════════════════════════════════════
# TURNO
# ══════════════════════════════════════════════════════════════════════════════

func reset_turn() -> void:
	has_moved = false
	has_acted = false
	modulate = Color.WHITE
	tick_statuses()

func end_turn() -> void:
	has_moved = true
	has_acted = true
	modulate = Color(0.6, 0.6, 0.6, 1.0)

# ══════════════════════════════════════════════════════════════════════════════
# SELECCIÓN VISUAL
# ══════════════════════════════════════════════════════════════════════════════

func select() -> void:
	is_selected = true
	unit_selected.emit(self)
	update_visual()

func deselect() -> void:
	is_selected = false
	unit_deselected.emit(self)
	update_visual()

func update_visual() -> void:
	if _has_map_sprite and _map_sprite != null:
		# "Ya actuó" => paleta Used (gris) en el shader; brillo al seleccionar via modulate.
		_map_sprite.set_used(has_acted)
		modulate = Color(1.15, 1.15, 1.0, 1.0) if is_selected else Color.WHITE
	else:
		# Fallback (marcador de color): grisado/brillo via modulate.
		if has_acted:
			modulate = Color(0.6, 0.6, 0.6, 1.0)
		elif is_selected:
			modulate = Color(1.2, 1.2, 1.0, 1.0)
		else:
			modulate = Color.WHITE
	queue_redraw()

func _ready() -> void:
	setup_map_sprite()
	update_visual()

## Crea el UnitMapSprite y lo configura con el sprite real de la clase.
## Resuelve map_sprite_nid desde GameDB y cell_size desde el Grid (grupo "grid").
func setup_map_sprite() -> void:
	if _map_sprite != null:
		return
	var ms_nid := _resolve_map_sprite_nid()
	var cs := _resolve_cell_size()
	_feet_y = UnitMapSprite.feet_local_for(cs)   # misma línea de suelo que el sprite
	var spr := UnitMapSprite.new()
	spr.name = "MapSprite"
	add_child(spr)
	_has_map_sprite = spr.setup(ms_nid, cs, team_palette_index())
	if _has_map_sprite:
		_map_sprite = spr
	else:
		spr.queue_free()   # sin sprite → marcador de color en _draw
	queue_redraw()

## Mapea el equipo al índice de paleta del shader (convención player/enemy/other/ally):
##   0=Player(azul) 1=Enemy(rojo) 2=Ally(verde) 3=Other(dorado).
## (ally = aliados NPC verdes; other = neutrales dorados, p.ej. las guarniciones
##  MackilyNeutral/AnphonyNeutral del cap 2 de FE4.)
func team_palette_index() -> int:
	match team:
		"player": return 0
		"enemy": return 1
		"ally": return 2
		"other": return 3
		_: return 0 if is_player_unit else 1

## Fuerza la paleta de equipo del sprite (debug / casos especiales).
func set_team_palette(idx: int) -> void:
	if _map_sprite != null:
		_map_sprite.set_team(idx)

## Fuerza la paleta "Used" (gris) del sprite.
func set_used_palette(used: bool) -> void:
	if _map_sprite != null:
		_map_sprite.set_used(used)

func _resolve_map_sprite_nid() -> String:
	var ms := ""
	if has_node("/root/GameDB"):
		var cd = get_node("/root/GameDB").get_class_data(unit_class)  # UnitClassData o null
		if cd != null:
			ms = str(cd.map_sprite_nid)
	if ms == "":
		ms = unit_class   # fallback: el nid de clase suele coincidir (60/64)
	return ms

func _resolve_cell_size() -> int:
	var g = get_tree().get_first_node_in_group("grid")
	if g != null and "cell_size" in g:
		return int(g.cell_size)
	return 64

func _draw() -> void:
	if _has_map_sprite:
		# El bando se distingue por la paleta del sprite (azul jugador / rojo
		# enemigo vía shader). Sólo dibujamos el anillo de selección a los pies.
		if is_selected:
			draw_set_transform(Vector2(0, _feet_y), 0.0, Vector2(1.0, 0.45))
			draw_arc(Vector2.ZERO, 18, 0, TAU, 24, Color.YELLOW, 3.0)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		# Fallback: marcador de color (clase sin map sprite).
		var color := Color.BLUE if is_player_unit else Color.RED
		draw_circle(Vector2.ZERO, 24, color)
		if is_selected:
			draw_arc(Vector2.ZERO, 28, 0, TAU, 32, Color.YELLOW, 3.0)
	_draw_hp_bar()

func _draw_hp_bar() -> void:
	var bar_w  := 40
	var bar_h  := 4
	# Justo debajo de los pies del sprite (línea de suelo).
	var bar_pos := Vector2(-bar_w / 2.0, _feet_y + 6.0)
	draw_rect(Rect2(bar_pos, Vector2(bar_w, bar_h)), Color.BLACK)
	var pct   := float(current_hp) / float(max_hp)
	var color := Color.GREEN
	if pct < 0.3:   color = Color.RED
	elif pct < 0.6: color = Color.YELLOW
	draw_rect(Rect2(bar_pos, Vector2(bar_w * pct, bar_h)), color)

# ══════════════════════════════════════════════════════════════════════════════
# UI
# ══════════════════════════════════════════════════════════════════════════════

func get_stat_summary() -> String:
	return "%s Lv%d %s (Tier %d)\nHP:%d/%d  STR:%d  MAG:%d\nSKL:%d  SPD:%d  LCK:%d\nDEF:%d  RES:%d  CON:%d" % [
		unit_name, level, unit_class, class_tier,
		current_hp, max_hp, strength, magic,
		skill, speed, luck, defense, resistance, constitution
	]
