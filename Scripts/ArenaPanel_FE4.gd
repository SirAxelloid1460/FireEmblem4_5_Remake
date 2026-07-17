extends Panel
class_name ArenaPanel

# Panel de la ARENA del Castillo Base — modelo HÍBRIDO (ver ArenaSystem.gd).
# UI fina sobre ArenaSystem: muestra el rival actual (fijo en orden, luego
# genéricos), pelea reutilizando las fórmulas reales de CombatSystem, y aplica el
# resultado (victoria = +1/recompensa; derrota = restaura HP y vuelve, SIN muerte).
# Ya NO hay stats inventadas, ni apuesta, ni campeón, ni permadeath.

# Referencias UI (mismos nodos de castle_base.tscn, repurposados).
@onready var opponent_list: ItemList = $VBoxContainer/OpponentList          # hoja de ruta (7 fijos)
@onready var opponent_details: RichTextLabel = $VBoxContainer/OpponentDetails
@onready var battle_preview: RichTextLabel = $VBoxContainer/BattlePreview
@onready var status_label: Label = $VBoxContainer/BetLabel                  # progreso victorias/fase
@onready var fight_button: Button = $VBoxContainer/ButtonContainer/FightButton
@onready var leave_button: Button = $VBoxContainer/ButtonContainer/LeaveButton
@onready var note_label: Label = $VBoxContainer/ChampionIndicator           # nota de recluta (Chulainn)

var current_unit: Unit = null
var player_gold: int = 0
var chapter_label: String = ""
var _challenge: Dictionary = {}     # {opponent, is_generic, position}

signal arena_finished(victory: bool, gold_earned: int, exp_gained: int)
signal arena_closed

func _ready():
	fight_button.pressed.connect(_on_fight_pressed)
	leave_button.pressed.connect(_on_leave_pressed)
	hide()

# ── Entrada ───────────────────────────────────────────────────────────────────

func start_arena(unit: Unit, gold: int, chapter: String = ""):
	current_unit = unit
	player_gold = gold
	chapter_label = chapter if chapter != "" else ArenaSystem.current_chapter_label()
	_refresh()
	show()

# ── Refresco del reto actual ──────────────────────────────────────────────────

func _refresh():
	_build_roadmap()
	if current_unit == null:
		return
	if not ArenaSystem.chapter_has_arena(chapter_label):
		_set_state("Este capítulo no tiene arena.", false)
		return
	if current_unit.weapon == null:
		_set_state("Equipa un arma antes de entrar a la arena.", false)
		return
	_challenge = ArenaSystem.next_challenge(current_unit, chapter_label)
	if _challenge.is_empty():
		_set_state("Sin más combates este capítulo (%d/%d victorias)."
				% [current_unit.arena_wins, ArenaSystem.MAX_WINS], false)
		return
	_show_opponent(_challenge)
	_set_state(_progress_text(), true)

func _progress_text() -> String:
	var phase := "Rival fijo %d/%d" % [min(current_unit.arena_fixed_index + 1, ArenaSystem.FIXED_COUNT), ArenaSystem.FIXED_COUNT]
	if bool(_challenge.get("is_generic", false)):
		phase = "Genéricos"
	return "Victorias: %d/%d  ·  %s" % [current_unit.arena_wins, ArenaSystem.MAX_WINS, phase]

func _set_state(msg: String, can_fight: bool):
	status_label.text = msg
	fight_button.disabled = not can_fight
	if not can_fight:
		battle_preview.text = ""
		opponent_details.text = ""

# ── Presentación del rival ────────────────────────────────────────────────────

func _show_opponent(challenge: Dictionary):
	var opp: Dictionary = challenge.get("opponent", {})
	var b: Dictionary = opp.get("bases", {})
	var d := "[center][b]%s[/b][/center]\n" % str(opp.get("name", "Rival"))
	d += "[center]Lv %d %s%s[/center]\n\n" % [int(opp.get("level", 1)), str(opp.get("klass", "")),
			"  (genérico)" if bool(challenge.get("is_generic", false)) else ""]
	for k in ["HP", "STR", "MAG", "SKL", "SPD", "LCK", "DEF", "RES"]:
		d += "%s: %d\n" % [k, int(b.get(k, 0))]
	var wnid := str(opp.get("weapon", ""))
	if wnid != "":
		d += "\n[b]Arma:[/b] %s" % wnid
	opponent_details.text = d

	# Nota de recluta (p.ej. Chulainn en Cap.2).
	var note = opp.get("note")
	if note != null and str(note) != "":
		note_label.text = "★ %s" % str(note)
		note_label.show()
	else:
		note_label.hide()

	_show_preview(opp, bool(challenge.get("is_generic", false)))

func _show_preview(opp: Dictionary, _is_generic: bool):
	if current_unit == null or current_unit.weapon == null:
		battle_preview.text = ""
		return
	var opp_unit = ArenaSystem.build_opponent_unit(opp)
	var ranged := ArenaSystem.unit_is_ranged(current_unit)
	var dist := 2 if ranged else 1
	var p_hit := CombatSystem.calculate_hit(current_unit, opp_unit, dist)
	var p_crit := CombatSystem.calculate_crit(current_unit, opp_unit)
	var p_dbl := CombatSystem._can_double(current_unit, opp_unit, current_unit.weapon)
	var p_dmg := CombatSystem._calc_dmg(current_unit, opp_unit, false,
			CombatSystem._is_effective(current_unit.weapon, opp_unit), "", {}, {"dist": dist})

	var can_counter := opp_unit.weapon != null and opp_unit.weapon.can_attack_at_range(dist)
	var t := "[b]%s[/b]  Dmg %d · Hit %d · Crit %d%s\n" % [
			current_unit.unit_name, p_dmg, p_hit, p_crit, "  x2" if p_dbl else ""]
	t += "vs [b]%s[/b]  " % str(opp.get("name", "Rival"))
	if can_counter:
		var e_hit := CombatSystem.calculate_hit(opp_unit, current_unit, dist)
		var e_dmg := CombatSystem._calc_dmg(opp_unit, current_unit, false,
				CombatSystem._is_effective(opp_unit.weapon, current_unit), "", {}, {"dist": dist})
		var e_dbl := CombatSystem._can_double(opp_unit, current_unit, opp_unit.weapon)
		t += "Dmg %d · Hit %d%s" % [e_dmg, e_hit, "  x2" if e_dbl else ""]
	else:
		t += "no contraataca (a distancia %d)" % dist
	battle_preview.text = t

## Hoja de ruta: los 7 rivales fijos, con ✓ los ya vencidos por este personaje.
func _build_roadmap():
	opponent_list.clear()
	if current_unit == null:
		return
	var positions := ArenaSystem.chapter_positions(chapter_label)
	for i in range(positions.size()):
		var slot: Dictionary = positions[i]
		var a = slot.get("A")
		var nm := str(a.get("name", "?")) if a is Dictionary else "?"
		var mark := "✓ " if i < current_unit.arena_fixed_index else ("▶ " if i == current_unit.arena_fixed_index else "· ")
		opponent_list.add_item("%s%d. %s" % [mark, i + 1, nm])
		opponent_list.set_item_disabled(opponent_list.item_count - 1, true)

# ── Combate ───────────────────────────────────────────────────────────────────

func _on_fight_pressed():
	if _challenge.is_empty() or current_unit == null or current_unit.weapon == null:
		return
	var opp_unit = ArenaSystem.build_opponent_unit(_challenge["opponent"])
	var ranged := ArenaSystem.unit_is_ranged(current_unit)
	var result: Dictionary = ArenaSystem.resolve_duel(current_unit, opp_unit, ranged)
	var victory := bool(result.get("victory", false))
	var reward: Dictionary = ArenaSystem.apply_result(current_unit, _challenge, victory)
	if victory:
		player_gold += int(reward.get("gold", 0))
	arena_finished.emit(victory, int(reward.get("gold", 0)), int(reward.get("exp", 0)))
	_refresh()   # siguiente rival (o fin); en derrota el HP ya se restauró

func _on_leave_pressed():
	arena_closed.emit()
	hide()
