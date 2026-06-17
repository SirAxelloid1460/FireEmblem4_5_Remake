extends Control
class_name LabelAnimText

# ============================================================
# LabelAnimText — texto "máquina de escribir" (recreado desde cero)
# ============================================================
# Componente reutilizable: muestra texto letra a letra con pausas según el
# signo de puntuación (estilo diálogo FE). Emite `displayed` al terminar.
#
# Uso:
#   var t = preload("res://Scenes/label_anim_text.tscn").instantiate()
#   add_child(t); t.display_text("Hola, mundo!")
#   await t.displayed
#   t.skip()   # completa de golpe
# ============================================================

signal displayed

@export var letter_time: float = 0.04
@export var font_size: int = 22
@export var font_color: Color = Color(0.96, 0.96, 0.92, 1.0)
@export var align_center: bool = true

var _label: Label
var _timer: Timer
var _full: String = ""
var _i: int = 0
var _done: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label = Label.new()
	_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	if align_center:
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", font_size)
	_label.add_theme_color_override("font_color", font_color)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 4)
	add_child(_label)

	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(_step)
	add_child(_timer)


func display_text(text_to_display: String) -> void:
	_full = text_to_display
	_i = 0
	_done = false
	if _label == null:
		await ready
	_label.text = ""
	_step()


func _step() -> void:
	if _i >= _full.length():
		if not _done:
			_done = true
			displayed.emit()
		return
	var c := _full[_i]
	_label.text += c
	_i += 1
	var d := letter_time
	match c:
		"!", ".", ",", "?", ";", ":", "¡", "¿", "-", "—":
			d = letter_time * 8.0
		" ", "\t", "\n":
			d = letter_time * 2.0
	_timer.start(d)


## Completa el texto de golpe.
func skip() -> void:
	if _label != null:
		_label.text = _full
	_i = _full.length()
	if not _done:
		_done = true
		displayed.emit()


func is_done() -> bool:
	return _done
