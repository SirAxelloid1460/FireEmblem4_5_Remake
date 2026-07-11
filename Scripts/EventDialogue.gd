# EventDialogue.gd
# ============================================================
# Caja de diálogo para EVENTOS (comando `speak`), estilo FE, por código.
# ============================================================
# Presentador autocontenido (no depende de ninguna .tscn, en línea con el
# patrón fiable del proyecto). Lo instancia EventSystem sobre un CanvasLayer y
# lo maneja con `play_line()` (corrutina que espera input del jugador).
#
# Soporta retrato izquierda/derecha, efecto máquina de escribir con "skip", e
# indicador de continuar. Limpia los códigos de control LT del texto ({w}/{br}…).

extends Control
class_name EventDialogue

const SERIF_FONT := "res://assets/fonts/IMFellFrenchCanonSC-Regular.ttf"
const COLOR_GOLD_DIM := Color(0.70, 0.60, 0.30, 1.0)
const COLOR_TEXT     := Color(0.96, 0.95, 0.90, 1.0)
const COLOR_OUTLINE  := Color(0.0, 0.0, 0.0, 1.0)
const CHAR_TIME := 0.028   # s por carácter

var _panel: PanelContainer
var _name_label: Label
var _text_label: RichTextLabel
var _cont: Label
var _port_left: TextureRect
var _port_right: TextureRect

var _typing := false
var _waiting := false
var _skip := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()


func _build() -> void:
	var vp := get_viewport_rect().size
	var font = load(SERIF_FONT)

	# Retratos (a los lados, sobre la caja).
	_port_left = _make_portrait_rect()
	_port_left.position = Vector2(40, vp.y - 520)
	add_child(_port_left)
	_port_right = _make_portrait_rect()
	_port_right.position = Vector2(vp.x - 40 - 256, vp.y - 520)
	add_child(_port_right)

	# Caja inferior.
	_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.06, 0.12, 0.96)
	sb.set_border_width_all(3)
	sb.border_color = COLOR_GOLD_DIM
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 28
	sb.content_margin_right = 28
	sb.content_margin_top = 16
	sb.content_margin_bottom = 16
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_panel.offset_left = 60
	_panel.offset_right = -60
	_panel.offset_top = -220
	_panel.offset_bottom = -40
	add_child(_panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	_panel.add_child(vb)

	_name_label = Label.new()
	if font != null:
		_name_label.add_theme_font_override("font", font)
	_name_label.add_theme_font_size_override("font_size", 30)
	_name_label.add_theme_color_override("font_color", COLOR_GOLD_DIM)
	_name_label.add_theme_color_override("font_outline_color", COLOR_OUTLINE)
	_name_label.add_theme_constant_override("outline_size", 4)
	vb.add_child(_name_label)

	_text_label = RichTextLabel.new()
	_text_label.bbcode_enabled = false
	_text_label.fit_content = true
	_text_label.scroll_active = false
	_text_label.custom_minimum_size = Vector2(0, 96)
	if font != null:
		_text_label.add_theme_font_override("normal_font", font)
	_text_label.add_theme_font_size_override("normal_font_size", 28)
	_text_label.add_theme_color_override("default_color", COLOR_TEXT)
	vb.add_child(_text_label)

	_cont = Label.new()
	_cont.text = "▼"
	_cont.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_cont.add_theme_color_override("font_color", COLOR_GOLD_DIM)
	_cont.visible = false
	vb.add_child(_cont)

	visible = false


func _make_portrait_rect() -> TextureRect:
	var t := TextureRect.new()
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(256, 256)
	t.size = Vector2(256, 256)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.visible = false
	return t


## Muestra una línea y espera al jugador. side: "left"/"right".
func play_line(speaker_name: String, text: String, portrait: Texture2D,
		side: String = "left") -> void:
	visible = true
	_name_label.text = speaker_name
	# Retrato del hablante en el lado indicado; el otro se atenúa.
	_port_left.visible = false
	_port_right.visible = false
	if portrait != null:
		var pr := _port_right if side == "right" else _port_left
		pr.texture = portrait
		pr.visible = true

	var clean := _clean_text(text)
	await _type(clean)
	await _wait_for_input()
	_cont.visible = false


## Oculta la caja y los retratos (fin de la secuencia de un evento).
func finish() -> void:
	visible = false
	_port_left.visible = false
	_port_right.visible = false


func _type(txt: String) -> void:
	_typing = true
	_skip = false
	_cont.visible = false
	_text_label.text = ""
	for i in range(txt.length()):
		if _skip:
			_text_label.text = txt
			break
		_text_label.text += txt[i]
		await get_tree().create_timer(CHAR_TIME).timeout
	_typing = false
	_cont.visible = true


func _wait_for_input() -> void:
	_waiting = true
	while _waiting:
		await get_tree().process_frame


func _unhandled_input(event: InputEvent) -> void:
	var confirm := event.is_action_pressed("ui_accept") or (event is InputEventMouseButton \
			and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
	if not confirm:
		return
	if _typing:
		_skip = true          # primer input: completa el texto
		get_viewport().set_input_as_handled()
	elif _waiting:
		_waiting = false      # segundo input: avanza
		get_viewport().set_input_as_handled()


## Limpia los códigos de control LT: {br}/{sub_break} → salto de línea; el resto
## de tokens {..} (waits, colores, comandos de estilo) se eliminan.
func _clean_text(s: String) -> String:
	s = s.replace("{br}", "\n").replace("{sub_break}", "\n").replace("{clear}", "\n")
	var re := RegEx.new()
	re.compile("\\{[^}]*\\}")
	s = re.sub(s, "", true)
	return s.strip_edges()
