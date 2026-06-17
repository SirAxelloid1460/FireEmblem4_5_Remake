extends Control
class_name BattleHPBar

# ============================================================
# BattleHPBar — barra de vida estilo FE (blips), recreada desde cero
# ============================================================
# Dibujada por código (segmentos de 1 HP) para no depender de recortes de
# textura concretos; el color cambia con el % de vida y la animación de daño/
# cura "drena" HP a HP. set_hp() fija al instante; animate_to() anima.
#
# Uso:
#   bar.set_hp(28, 30)         # current, max
#   await bar.animate_to(12)   # animación de daño
# ============================================================

signal hp_depleted

@export var max_hp: int = 30
@export var current_hp: int = 30
@export var px_per_hp: int = 3        # ancho por punto de vida
@export var bar_height: int = 10
@export var tick_seconds: float = 0.04
@export var tick_sfx: String = ""     # ruta opcional a un .ogg para el "tick"

const COLOR_BG      := Color(0.10, 0.10, 0.13, 1.0)
const COLOR_OUTLINE := Color(0.0, 0.0, 0.0, 1.0)
const COLOR_SEP     := Color(0.0, 0.0, 0.0, 0.35)
const COLOR_HP      := Color(0.32, 0.86, 0.38, 1.0)
const COLOR_HP_LOW  := Color(0.93, 0.78, 0.22, 1.0)
const COLOR_HP_CRIT := Color(0.92, 0.26, 0.26, 1.0)

var _sfx: AudioStreamPlayer


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sfx = AudioStreamPlayer.new()
	add_child(_sfx)
	if tick_sfx != "" and ResourceLoader.exists(tick_sfx):
		_sfx.stream = load(tick_sfx)
	_refresh_size()


func set_hp(cur: int, mx: int) -> void:
	max_hp = max(1, mx)
	current_hp = clampi(cur, 0, max_hp)
	_refresh_size()
	queue_redraw()


## Anima el HP actual hacia `target` (HP a HP), con tick opcional.
func animate_to(target: int) -> void:
	target = clampi(target, 0, max_hp)
	while current_hp != target:
		current_hp += 1 if target > current_hp else -1
		if _sfx != null and _sfx.stream != null:
			_sfx.play()
		queue_redraw()
		await get_tree().create_timer(tick_seconds).timeout
	if current_hp <= 0:
		hp_depleted.emit()


func _refresh_size() -> void:
	custom_minimum_size = Vector2(max_hp * px_per_hp + 4, bar_height + 4)


func _draw() -> void:
	var w := max_hp * px_per_hp
	var h := bar_height
	# Marco + fondo
	draw_rect(Rect2(0, 0, w + 4, h + 4), COLOR_OUTLINE)
	draw_rect(Rect2(2, 2, w, h), COLOR_BG)
	# Relleno según %
	var pct := float(current_hp) / float(max_hp)
	var col := COLOR_HP
	if pct <= 0.25:
		col = COLOR_HP_CRIT
	elif pct <= 0.5:
		col = COLOR_HP_LOW
	if current_hp > 0:
		draw_rect(Rect2(2, 2, current_hp * px_per_hp, h), col)
	# Separadores de "blip" cada punto de vida
	for i in range(1, max_hp):
		var x := 2 + i * px_per_hp
		draw_line(Vector2(x, 2), Vector2(x, 2 + h), COLOR_SEP, 1.0)
