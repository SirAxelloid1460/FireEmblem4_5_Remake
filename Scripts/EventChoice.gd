# EventChoice.gd
# ============================================================
# Caja de DECISIÓN para el comando `choice`, estilo FE, por código.
# ============================================================
# Modal autocontenido (sobre el CanvasLayer de presentación del EventSystem).
# `ask(prompt, options)` es corrutina: construye la caja, espera la elección del
# jugador (ratón o teclado/mando) y devuelve el texto elegido. B/cancel elige la
# última opción (convención FE: la salida "No").

extends Control
class_name EventChoice

signal chosen(text: String)

const SERIF_FONT := "res://assets/fonts/IMFellFrenchCanonSC-Regular.ttf"
const COLOR_GOLD_DIM := Color(0.70, 0.60, 0.30, 1.0)
const COLOR_TEXT     := Color(0.96, 0.95, 0.90, 1.0)

var _options: Array = []
var _emitted := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP   # bloquea clics al mapa detrás


## Muestra la caja y espera la elección. Devuelve el texto de la opción elegida.
func ask(prompt: String, options: Array) -> String:
	_options = options
	_build(prompt, options)
	var r = await chosen
	queue_free()
	return str(r)


func _build(prompt: String, options: Array) -> void:
	var font = load(SERIF_FONT)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.13, 0.97)
	sb.set_border_width_all(3)
	sb.border_color = COLOR_GOLD_DIM
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 26
	sb.content_margin_right = 26
	sb.content_margin_top = 18
	sb.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel", sb)
	var vp := get_viewport_rect().size
	panel.custom_minimum_size = Vector2(420, 0)
	panel.position = Vector2((vp.x - 420) * 0.5, vp.y * 0.32)
	add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	panel.add_child(vb)

	if prompt != "":
		var lbl := Label.new()
		lbl.text = prompt
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if font != null:
			lbl.add_theme_font_override("font", font)
		lbl.add_theme_font_size_override("font_size", 26)
		lbl.add_theme_color_override("font_color", COLOR_TEXT)
		vb.add_child(lbl)

	var first: Button = null
	for opt in options:
		var text := str(opt).strip_edges()
		if text == "" or text.contains("{eval"):
			continue   # opciones dinámicas LT ({eval:...}) — no soportadas aún
		var b := Button.new()
		b.text = text
		b.custom_minimum_size = Vector2(360, 44)
		b.focus_mode = Control.FOCUS_ALL
		if font != null:
			b.add_theme_font_override("font", font)
		b.add_theme_font_size_override("font_size", 24)
		b.add_theme_color_override("font_color", COLOR_TEXT)
		b.add_theme_color_override("font_focus_color", Color.WHITE)
		b.pressed.connect(_pick.bind(text))
		b.mouse_entered.connect(b.grab_focus)
		vb.add_child(b)
		if first == null:
			first = b
	if first != null:
		first.grab_focus()
	else:
		_pick("")   # sin opciones válidas → resuelve vacío (no bloquea el evento)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not _options.is_empty():
		_pick(str(_options[_options.size() - 1]).strip_edges())   # última = salida
		get_viewport().set_input_as_handled()


func _pick(text: String) -> void:
	if _emitted:
		return
	_emitted = true
	chosen.emit(text)
