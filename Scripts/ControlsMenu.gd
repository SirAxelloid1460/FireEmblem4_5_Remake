extends Control
class_name ControlsMenu

# ============================================================
# ControlsMenu — remapeo de controles estilo Game Boy Advance
# ============================================================
# Overlay a pantalla completa (mismo fondo y panel de título que OptionsMenu).
# Muestra la imagen de una GBA (assets/menus/GBA_Controls.png) con una línea
# negra que sale de cada botón hacia arriba; sobre esas líneas se colocan los
# recuadros de remapeo, cada uno con la tecla asignada actualmente. En la
# pantalla de la consola se muestra el NOMBRE de la acción del botón enfocado.
#
# Navegación: ←→ / ↑↓ mueven el foco entre botones · A (accept) empieza a
# reasignar (pulsa una tecla) · B (cancel) vuelve / cancela la reasignación.
# La lógica de teclas vive en el autoload InputConfig.
#
# NOTA GDScript: Dictionary por corchetes (box["x"]); Godot 4 no tiene dot-access.
# ============================================================

signal controls_closed

const TEXT_FONT := "res://assets/fonts/bmp/text.fnt"
const BG_IMAGE  := "res://assets/panoramas/default_background.png"
const TITLE_BG  := "res://assets/menus/menu_bg_white.png"
const IMG       := "res://assets/menus/GBA_Controls.png"

const PATCH := 8
const TITLE_ALPHA := 0.8

const COLOR_GOLD     := Color(1.00, 0.84, 0.36, 1.0)
const COLOR_TEXT     := Color(0.92, 0.93, 0.88, 1.0)
const COLOR_DIM      := Color(0.62, 0.64, 0.70, 1.0)
const COLOR_OUTLINE  := Color(0.0, 0.0, 0.0, 1.0)
const COLOR_BOX_BG   := Color(0.05, 0.06, 0.11, 0.94)

# Anclas (px en la imagen 720×480) de cada recuadro, en ORDEN de navegación
# (izq→der; las dos del centro son el D-Pad arriba/abajo). Cada botón ↔ acción.
const BOXES := [
	{ "action": "ui_select",     "x": 46,  "y": 155 },   # Select
	{ "action": "ui_start",      "x": 121, "y": 155 },   # Start
	{ "action": "ui_page_left",  "x": 205, "y": 155 },   # L
	{ "action": "ui_left",       "x": 304, "y": 155 },   # D-Pad ←
	{ "action": "ui_up",         "x": 360, "y": 118 },   # D-Pad ↑ (barra superior)
	{ "action": "ui_down",       "x": 360, "y": 190 },   # D-Pad ↓ (barra inferior)
	{ "action": "ui_right",      "x": 414, "y": 155 },   # D-Pad →
	{ "action": "ui_page_right", "x": 519, "y": 155 },   # R
	{ "action": "ui_accept",     "x": 603, "y": 155 },   # A
	{ "action": "ui_cancel",     "x": 678, "y": 155 },   # B
]

# Zona de pantalla de la GBA (px imagen) donde se muestra el nombre de la acción.
const SCREEN := Rect2(279, 285, 163, 125)

# Tamaño de cada recuadro en px de imagen (se escala con la imagen).
const BOX_W := 70.0
const BOX_H := 30.0

var _font = null
var _sel: int = 0
var _rebinding: bool = false
var _scale: float = 1.0
var _boxes_ui: Array = []          # [{panel, style, label}]
var _screen_lbl: Label = null
var _hint: Label = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_font = load(AssetSet.p(TEXT_FONT))
	_build_ui()
	_refresh()


# ── Construcción de la UI ─────────────────────────────────────────────────────
func _build_ui() -> void:
	_build_background()

	var vp: Vector2 = get_viewport_rect().size
	var title_y: float = 24.0
	var title_h: float = 150.0
	var gap: float = 18.0
	var hint_h: float = 54.0
	var img_y: float = title_y + title_h + gap
	var avail_h: float = vp.y - img_y - hint_h - 12.0
	_scale = minf((vp.x * 0.9) / 720.0, avail_h / 480.0)

	var panel_w: float = vp.x * 0.9
	var left_x: float = (vp.x - panel_w) / 2.0
	var title := _build_title_panel()
	title.position = Vector2(left_x, title_y)
	add_child(title)

	var img_w: float = 720.0 * _scale
	var img_h: float = 480.0 * _scale
	var holder := Control.new()
	holder.position = Vector2((vp.x - img_w) / 2.0, img_y)
	holder.custom_minimum_size = Vector2(img_w, img_h)
	holder.size = Vector2(img_w, img_h)
	add_child(holder)

	var pic := TextureRect.new()
	pic.texture = load(AssetSet.p(IMG))
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.add_child(pic)

	# Nombre de la acción enfocada, dentro de la pantalla de la GBA.
	_screen_lbl = Label.new()
	_screen_lbl.position = Vector2(SCREEN.position.x * _scale, SCREEN.position.y * _scale)
	_screen_lbl.custom_minimum_size = Vector2(SCREEN.size.x * _scale, SCREEN.size.y * _scale)
	_screen_lbl.size = _screen_lbl.custom_minimum_size
	_screen_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_screen_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_screen_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_font_it(_screen_lbl, 30, COLOR_GOLD, 3)
	holder.add_child(_screen_lbl)

	# Recuadros de remapeo sobre las líneas horizontales.
	var bw: float = BOX_W * _scale
	var bh: float = BOX_H * _scale
	for box in BOXES:
		var panel := Panel.new()
		var st := StyleBoxFlat.new()
		st.bg_color = COLOR_BOX_BG
		st.set_border_width_all(2)
		st.set_corner_radius_all(3)
		panel.add_theme_stylebox_override("panel", st)
		panel.position = Vector2(box["x"] * _scale - bw / 2.0, box["y"] * _scale - bh / 2.0)
		panel.custom_minimum_size = Vector2(bw, bh)
		panel.size = Vector2(bw, bh)
		holder.add_child(panel)
		var kl := Label.new()
		kl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		kl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		kl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_font_it(kl, 20, COLOR_TEXT, 2)
		panel.add_child(kl)
		_boxes_ui.append({ "panel": panel, "style": st, "label": kl })

	add_child(_build_hint_bar(vp.x, hint_h))
	_sel = 0


func _build_background() -> void:
	var base := ColorRect.new()
	base.color = Color(0.03, 0.04, 0.09, 1.0)
	base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(base)
	var bg_path := AssetSet.p(BG_IMAGE)
	if ResourceLoader.exists(bg_path):
		var tex := TextureRect.new()
		tex.texture = load(bg_path)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(tex)
	var tint := ColorRect.new()
	tint.color = Color(0.03, 0.04, 0.09, 0.82)
	tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(tint)


func _build_title_panel() -> Control:
	var root := Control.new()
	root.size = Vector2(780, 150)
	root.modulate.a = TITLE_ALPHA
	var np := NinePatchRect.new()
	np.texture = load(AssetSet.p(TITLE_BG))
	np.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	np.patch_margin_left = PATCH
	np.patch_margin_right = PATCH
	np.patch_margin_top = PATCH
	np.patch_margin_bottom = PATCH
	np.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(np)
	var lbl := Label.new()
	lbl.text = "Controls"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_font_it(lbl, 96, COLOR_GOLD, 4)
	root.add_child(lbl)
	return root


func _build_hint_bar(full_w: float, h: float) -> Control:
	var bar := Control.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_top = -h
	bar.offset_bottom = 0
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.5)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bar.add_child(bg)
	_hint = Label.new()
	_hint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_font_it(_hint, 28, COLOR_GOLD, 3)
	bar.add_child(_hint)
	return bar


func _font_it(lbl: Label, size: int, color: Color, outline: int) -> void:
	if _font != null:
		lbl.add_theme_font_override("font", _font)
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", COLOR_OUTLINE)
	lbl.add_theme_constant_override("outline_size", outline)


# ── Refresco visual ───────────────────────────────────────────────────────────
func _refresh() -> void:
	for i in range(BOXES.size()):
		var ui: Dictionary = _boxes_ui[i]
		var focused: bool = (i == _sel)
		var st: StyleBoxFlat = ui["style"]
		st.border_color = COLOR_GOLD if focused else COLOR_DIM
		st.bg_color = Color(0.16, 0.13, 0.05, 0.96) if focused else COLOR_BOX_BG
		var lbl: Label = ui["label"]
		lbl.text = "..." if (focused and _rebinding) else _key_short(str(BOXES[i]["action"]))
		lbl.add_theme_color_override("font_color", COLOR_GOLD if focused else COLOR_TEXT)
	# Nombre de la acción enfocada en la pantalla de la GBA.
	var act_name := _action_name(str(BOXES[_sel]["action"]))
	if _rebinding:
		_screen_lbl.text = "%s\nPress a key\n(Esc: cancel)" % act_name
	else:
		_screen_lbl.text = act_name
	_hint.text = "<-/->  Select      A: Rebind      B: Back      Start: Reset"


func _key_short(action: String) -> String:
	var s := InputConfig.key_label(action)
	match s:
		"Escape": return "Esc"
		"Backspace": return "Bksp"
		"Delete": return "Del"
		"PageUp": return "PgUp"
		"PageDown": return "PgDn"
		"Insert": return "Ins"
		"CapsLock": return "Caps"
		_: return s


func _action_name(action: String) -> String:
	for spec in InputConfig.ACTIONS:
		if str(spec["action"]) == action:
			return str(spec["name"])
	return action


# ── Input ─────────────────────────────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	# Modo reasignación: capturamos la SIGUIENTE tecla cruda.
	if _rebinding:
		if event is InputEventKey and event.pressed and not event.echo:
			var kc: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
			if kc == KEY_ESCAPE:
				_rebinding = false            # cancelar
			else:
				InputConfig.rebind(str(BOXES[_sel]["action"]), kc)
				_rebinding = false
			_refresh()
			_handled()
		return

	if event.is_action_pressed("ui_cancel"):
		_close()
		_handled()
	elif event.is_action_pressed("ui_accept"):
		_rebinding = true
		_refresh()
		_handled()
	elif event.is_action_pressed("ui_start"):
		InputConfig.reset_defaults()
		_refresh()
		_handled()
	elif event.is_action_pressed("ui_left") or event.is_action_pressed("ui_up"):
		_sel = (_sel - 1 + BOXES.size()) % BOXES.size()
		_refresh()
		_handled()
	elif event.is_action_pressed("ui_right") or event.is_action_pressed("ui_down"):
		_sel = (_sel + 1) % BOXES.size()
		_refresh()
		_handled()


func _handled() -> void:
	get_viewport().set_input_as_handled()


func _close() -> void:
	if get_tree().current_scene == self:
		FadeCanvas.change_scene_to_file("res://Scenes/main_menu.tscn")
	else:
		controls_closed.emit()
		queue_free()
