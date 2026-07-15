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
## Experiencia acumulada hacia el próximo nivel (0-99). Al llegar a 100 sube de
## nivel (ver gain_exp). Se nombra 'experience' para no colisionar con exp().
@export var experience:    int    = 0
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
# EXPERIENCIA Y NIVEL
# ══════════════════════════════════════════════════════════════════════════════

## Nivel máximo alcanzable escalando EXP (cubre FE4 hasta 30; en FE5 la
## promoción reinicia el nivel antes de llegar aquí).
const MAX_LEVEL := 30

signal leveled_up(new_level: int, gains: Dictionary)

## Tasas de crecimiento base (personales) de la unidad, en claves MINÚSCULAS
## (hp/str/…), como espera LevelUpScreen.calculate_stat_gains. Se leen del
## UnitDef de GameDB; si no está, se usan las de la clase; si tampoco, {}.
func get_growth_rates() -> Dictionary:
	var up := {}
	var db = _gamedb()
	if db != null:
		var ud = db.get_unit(unit_name)
		if ud != null and ud.growths is Dictionary and not ud.growths.is_empty():
			up = ud.growths
		else:
			var cd = db.get_class_data(unit_class)
			if cd != null and "growths" in cd and cd.growths is Dictionary:
				up = cd.growths
	var out := {}
	for k in up:
		out[str(k).to_lower()] = int(up[k])
	return out

## Otorga EXP y sube de nivel tantas veces como corresponda (100 EXP = 1 nivel).
## Cada subida tira ganancias vía LevelUpScreen.calculate_stat_gains (que ya
## suma los growth_change de skills/scrolls) y las aplica. Devuelve la lista de
## diccionarios de ganancias, una por nivel subido (vacía si no subió). Al tope
## de nivel la EXP se descarta.
func gain_exp(amount: int) -> Array:
	var results: Array = []
	if amount <= 0:
		return results
	if level >= MAX_LEVEL:
		experience = 0
		return results
	experience += amount
	var rates := get_growth_rates()
	while experience >= 100 and level < MAX_LEVEL:
		experience -= 100
		var gains: Dictionary = LevelUpScreen.calculate_stat_gains(self, rates)
		LevelUpScreen.apply_stat_gains(self, gains)
		level += 1
		results.append(gains)
		leveled_up.emit(level, gains)
	if level >= MAX_LEVEL:
		experience = 0
	return results

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

## Resuelve el autoload GameDB de forma robusta: funciona tanto si la unidad
## está en el árbol (get_node) como si es un nodo suelto (roster reconstruido en
## el castillo) — en ese caso se accede vía el SceneTree raíz.
func _gamedb():
	var n := get_node_or_null("/root/GameDB")
	if n != null:
		return n
	var loop := Engine.get_main_loop()
	if loop is SceneTree and loop.root != null:
		return loop.root.get_node_or_null("GameDB")
	return null

# ── Efectos de equipo (status_on_hold / status_on_equip) ──────────────────────
# Recalcula las skills temporales y los modificadores de stats derivados del
# EQUIPO de la unidad (no de status ni de captura):
#   · Cada item del inventario con `status_on_hold` (anillos pasivos, scrolls,
#     Circlet…) concede su skill mientras se porta.
#   · El arma equipada con `status_on_equip` (Holy/Darkness Sword…) concede su
#     skill mientras está equipada.
# Además, si la skill concedida lleva un componente `stat_change`, se aplica
# como modificador de status (p.ej. Power Ring → +STR). Es IDEMPOTENTE: limpia
# lo derivado antes de reconstruir, así que puede llamarse tras spawnear, tras
# equipar/desequipar, tras usar un item o tras mover objetos entre unidades y el
# convoy. NO toca los modificadores de captura ("Carrying") ni los de status.
func refresh_item_effects() -> void:
	# 1) Limpiar skills temporales y modificadores derivados de items/equipo.
	remove_temporary_skills_by_source("item")
	for mod_id in _stat_modifiers.keys():
		var key := str(mod_id)
		if key.begins_with("hold:") or key.begins_with("equip:"):
			_stat_modifiers.erase(mod_id)
	# 2) status_on_hold de cada item del inventario.
	for it in inventory:
		var sid := _equipment_skill_field(it, "status_on_hold")
		if sid != "":
			_grant_equipment_skill(sid, "hold:" + sid)
	# 3) status_on_equip del arma equipada.
	if weapon != null and weapon.has_method("get_component"):
		var wsid = weapon.get_component("status_on_equip")
		if wsid != null and str(wsid) != "":
			_grant_equipment_skill(str(wsid), "equip:" + str(wsid))

## Lee un campo de skill (status_on_hold/status_on_equip) de un item, tolerando
## tanto ConsumableData/ItemData (propiedad tipada) como Dictionary.
func _equipment_skill_field(it, field: String) -> String:
	if it == null:
		return ""
	if it is Object and field in it:
		return str(it.get(field))
	if it is Dictionary:
		return str(it.get(field, ""))
	return ""

## Concede una skill de equipo (temporal, source="item") y aplica su stat_change
## como modificador de status si lo tiene.
func _grant_equipment_skill(skill_id: String, mod_id: String) -> void:
	if skill_id == "":
		return
	add_temporary_skill(skill_id, "item")
	var deltas := _skill_stat_change(skill_id)
	if not deltas.is_empty():
		add_status_modifier(mod_id, deltas)

## Extrae el componente stat_change de una skill de GameDB → {stat: delta}.
func _skill_stat_change(skill_id: String) -> Dictionary:
	var out := {}
	if not (_gamedb() != null):
		return out
	var sk = _gamedb().get_skill(skill_id)
	if sk == null:
		return out
	var raw = sk.component_value("stat_change")
	if raw is Array:
		for pair in raw:
			if pair is Array and pair.size() >= 2:
				var stat := str(pair[0])
				var val := int(pair[1])
				# Convención LT: el MOV se almacena ×10 (LT no aceptaba decimales),
				# igual que las bases de clase — ver LevelLoader (mov_raw/10). Sólo
				# se decodifican magnitudes ≥10 (los bonuses reales son 1-5 → 10-50);
				# valores pequeños ya están en unidades reales.
				if stat == "MOV" and abs(val) >= 10:
					val = int(round(val / 10.0))
				out[stat] = val
	return out

## Todas las skills activas de la unidad: permanentes + temporales (items).
func _all_skill_ids() -> Array:
	var ids: Array = []
	ids.append_array(skills)
	for k in _temp_skills:
		if not k in ids:
			ids.append(k)
	return ids

## Mayor fracción de regeneración por turno entre las skills activas
## (Life 0.2, Recover 1.0, Regeneration/Circlet 0.25…). 0.0 si ninguna regenera.
func get_regen_fraction() -> float:
	var best := 0.0
	if not (_gamedb() != null):
		return best
	var db = _gamedb()
	for sid in _all_skill_ids():
		var sk = db.get_skill(sid)
		if sk == null:
			continue
		var v = sk.component_value("regeneration")
		if v != null:
			best = max(best, float(v))
	return best

## Bonos de crecimiento (growth_change) sumados de todas las skills activas,
## en puntos de % por stat (Elite +10 todos, scrolls de sangre…). Claves en
## mayúsculas (HP/STR/MAG/SKL/SPD/LCK/DEF/RES). Usado por LevelUpScreen.
func get_growth_bonuses() -> Dictionary:
	var out := {}
	if not (_gamedb() != null):
		return out
	var db = _gamedb()
	for sid in _all_skill_ids():
		var sk = db.get_skill(sid)
		if sk == null:
			continue
		var gc = sk.component_value("growth_change")
		if gc is Array:
			for pair in gc:
				if pair is Array and pair.size() >= 2:
					var stat := str(pair[0])
					out[stat] = int(out.get(stat, 0)) + int(pair[1])
	return out

## Nivel de Canto de la unidad según sus skills activas:
##   0 = sin Canto; 1 = Canto (re-mover con el movimiento RESTANTE);
##   2 = Canto+ (re-mover con el movimiento COMPLETO).
func canto_level() -> int:
	if not (_gamedb() != null):
		# Fallback por nid conocido si GameDB no está disponible.
		if has_skill("Canto_Plus"): return 2
		if has_skill("Canto"): return 1
		return 0
	var db = _gamedb()
	var lvl := 0
	for sid in _all_skill_ids():
		var sk = db.get_skill(sid)
		if sk == null:
			continue
		if sk.has_component("canto_plus"):
			lvl = max(lvl, 2)
		elif sk.has_component("canto"):
			lvl = max(lvl, 1)
	return lvl



# ══════════════════════════════════════════════════════════════════════════════
# WEAPON RANK & HOLY BLOOD   (fiel a LT-maker + reglas FE4 LOCKED del brief §4)
# ══════════════════════════════════════════════════════════════════════════════
#
# Thresholds de wexp:
#   D=1  C=51  B=126  A=226  S=1023  Holy=1023
# S es el rango tope NATURAL: CUALQUIER unidad puede alcanzarlo escalando wexp.
# Holy es un S ESPECIAL que sólo tienen las unidades con Major Blood de un
# cruzado, y lo tienen AUTOMÁTICAMENTE desde el inicio (no se gana por wexp; se
# concede por la sangre). A wexp>=1023 una unidad normal muestra "S" y una con
# Major Blood muestra "Holy". Las armas sagradas se restringen por prf_tags
# (XxxHeir = heredero de ESE cruzado), así que el heredero las usa desde el
# principio sin importar su wexp.

const WEAPON_RANK_THRESHOLDS := {
	"D": 1, "C": 51, "B": 126, "A": 226, "S": 1023, "Holy": 1023
}
const WEAPON_RANK_ORDER := ["D", "C", "B", "A", "S", "Holy"]

## Gana wexp en un tipo de arma. Ya NO hay tope en A: toda unidad puede llegar
## a S (1023) escalando. (Holy no se gana por wexp — es el S nato por sangre.)
func gain_weapon_exp(weapon_type: String, amount: int) -> void:
	if weapon_type == "":
		return
	wexp[weapon_type] = int(wexp.get(weapon_type, 0)) + max(0, amount)

## Rango (letra) que la unidad tiene en un tipo de arma según su wexp.
## A wexp>=1023 el rango natural es S; las unidades con Major Blood lo muestran
## como Holy (su S nato).
func get_weapon_rank(weapon_type: String) -> String:
	var w: int = int(wexp.get(weapon_type, 0))
	var result := ""
	for r in WEAPON_RANK_ORDER:
		if r == "Holy":
			continue  # Holy no se obtiene por wexp; se concede por sangre
		if w >= int(WEAPON_RANK_THRESHOLDS[r]):
			result = r
	if result == "S" and has_major_blood():
		result = "Holy"
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
	# Armas Holy (S nato): sólo Major Blood, y las usan desde el inicio sin
	# exigir wexp (el rango se concede por la sangre). En LT esto se refuerza
	# además por prf_tags (XxxHeir).
	if required == "Holy":
		return has_major_blood()
	# Rango S y por debajo: cualquiera que tenga el wexp del tipo suficiente.
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


# ── Animación de paso por el mapa ────────────────────────────────────────────
const STEP_TIME := 0.13            # segundos por casilla recorrida
var _step_player: AudioStreamPlayer = null

## Camina la unidad a través de una lista de puntos de MUNDO (Vector2), casilla
## a casilla, orientando el map sprite y reproduciendo el SFX de paso. Corrutina:
## el llamador hace `await`. Si la clase no tiene map sprite, salta al destino.
func animate_move_along(world_points: Array, step_time: float = STEP_TIME) -> void:
	if world_points.is_empty():
		return
	if not _has_map_sprite or _map_sprite == null:
		global_position = world_points[world_points.size() - 1]
		return
	_map_sprite.start_move()
	var sfx_name := _step_sfx_name()
	for p in world_points:
		var to: Vector2 = p
		_map_sprite.set_move_dir(_dir_from_delta(to - global_position))
		_play_step_sfx(sfx_name)
		var t := create_tween()
		t.tween_property(self, "global_position", to, step_time)
		await t.finished
	_map_sprite.end_move()


## Dirección de marcha (constantes de UnitMapSprite) a partir del desplazamiento.
func _dir_from_delta(d: Vector2) -> int:
	if absf(d.x) >= absf(d.y):
		return UnitMapSprite.DIR_RIGHT if d.x > 0 else UnitMapSprite.DIR_LEFT
	return UnitMapSprite.DIR_DOWN if d.y > 0 else UnitMapSprite.DIR_UP


## SFX de paso según el tipo de unidad (tags Flying/Mounted/Armor).
func _step_sfx_name() -> String:
	if "Flying" in tags:
		return "Map_Step_Flier"
	if "Mounted" in tags:
		return "Map_Step_Mounted3"
	if "Armor" in tags:
		return "Map_Step_Armor1"
	return "Map_Step_Infantry2"


func _play_step_sfx(sfx_name: String) -> void:
	var stream: AudioStream = null
	if has_node("/root/AssetLoader"):
		stream = get_node("/root/AssetLoader").get_sfx(sfx_name)
	if stream == null:
		return
	if _step_player == null:
		_step_player = AudioStreamPlayer.new()
		if AudioServer.get_bus_index("SFX") >= 0:
			_step_player.bus = "SFX"
		add_child(_step_player)
	_step_player.stream = stream
	_step_player.play()

func _resolve_map_sprite_nid() -> String:
	var ms := ""
	if (_gamedb() != null):
		var cd = _gamedb().get_class_data(unit_class)  # UnitClassData o null
		if cd != null:
			ms = str(cd.map_sprite_nid)
	if ms == "":
		ms = unit_class   # fallback: el nid de clase suele coincidir (60/64)
	return ms

## nid base de la animación de combate de esta unidad.  El resolver construye
## los nombres como {combat_anim_nid}_{Variant}_{Weapon}, así que NO debe usar
## el nid de clase crudo (unit_class): p.ej. clase "CavalierA" -> anim "AxeKnight".
## Se lee de GameDB en cada llamada, de modo que una promoción (que cambia
## unit_class) actualiza la animación automáticamente.
func resolve_combat_anim_nid() -> String:
	if (_gamedb() != null):
		var cd = _gamedb().get_class_data(unit_class)  # UnitClassData o null
		if cd != null and str(cd.combat_anim_nid) != "":
			return str(cd.combat_anim_nid)
	return unit_class   # fallback: el nid de clase suele coincidir

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
