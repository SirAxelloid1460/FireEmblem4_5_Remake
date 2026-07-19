extends Control
class_name OptionsMenu

# ============================================================
# OptionsMenu — panel de configuración estilo Fire Emblem (FE4 "Configuration")
# ============================================================
# Autocontenido (construido por código). Overlay a PANTALLA COMPLETA con fondo
# propio OPACO, así cubre por completo el menú de debajo (antes el fondo era 72%
# translúcido y se transparentaban las placas/cursor → aspecto amontonado).
#
# Estilo FE: cada fila es [etiqueta] + [opciones en fila / barra], con la opción
# activa resaltada en dorado, y una BARRA DE DESCRIPCIÓN abajo que explica la
# fila enfocada. Navegación con mando/teclado:
#   ↑ / ↓   cambiar de fila
#   ← / →   cambiar el valor de la fila
#   Cancel  volver (emite options_closed; o cambia de escena si es standalone)
#
# Persiste en user://settings.cfg conservando las MISMAS claves/semántica de
# antes (para no romper a quien las lea). Aplica audio a los buses Music/SFX.
# El "Graphics Set" se guarda con AssetSet.save (aplica al REINICIAR).
#
# NOTA GDScript: los Dictionary se acceden por corchetes (spec["value"]), NO por
# punto (Godot 4 no soporta dot-access en Dictionary).
# ============================================================

signal options_closed

const CFG := "user://settings.cfg"
const SERIF_FONT := "res://assets/fonts/IMFellFrenchCanonSC-Regular.ttf"
const BG_IMAGE := "res://assets/panoramas/default_background.png"

const COLOR_GOLD     := Color(1.00, 0.84, 0.36, 1.0)
const COLOR_GOLD_DIM := Color(0.66, 0.56, 0.28, 1.0)
const COLOR_TEXT     := Color(0.90, 0.91, 0.86, 1.0)
const COLOR_DIM      := Color(0.55, 0.57, 0.62, 1.0)
const COLOR_OUTLINE  := Color(0.0, 0.0, 0.0, 1.0)
const SEG_EMPTY      := Color(0.22, 0.24, 0.30, 1.0)

var _specs: Array = []          # specs de fila (dicts)
var _ui: Array = []             # nodos visuales por fila (paralelo a _specs; null = sección)
var _sel: int = 0               # índice de fila enfocada
var _cfg := ConfigFile.new()
var _desc: Label = null
var _rows_box: VBoxContainer = null
var _scroll: ScrollContainer = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cfg.load(CFG)
	_build_specs()
	_build_ui()
	_apply_bus("Music", int(_cfg_get("audio", "music_volume", 70)))
	_apply_bus("SFX", int(_cfg_get("audio", "sfx_volume", 80)))
	_refresh()


# ── Definición de opciones ────────────────────────────────────────────────────
func _build_specs() -> void:
	_row_section("AUDIO")
	_row_range("audio", "music_volume", "Music Volume", 70, "Volumen de la música del juego.")
	_row_range("audio", "sfx_volume", "SFX Volume", 80, "Volumen de los efectos de sonido.")
	_row_toggle("audio", "talk_sound", "Talk Sound", true, "Sonido de voz al avanzar los diálogos.")

	_row_section("GRAPHICS")
	_row_set("Graphics Set", "Conjunto de gráficos: Original / GBA / HD. Se aplica al reiniciar el juego.")

	_row_section("GAMEPLAY")
	_row_enum("gameplay", "animations", "Battle Animations", ["On", "Map Only", "Off"], 0,
			"Animaciones de combate: completas, solo en el mapa, o desactivadas.")
	_row_range("gameplay", "unit_speed", "Unit Speed", 50, "Velocidad de movimiento de las unidades en el mapa.")
	_row_range("gameplay", "text_speed", "Text Speed", 50, "Velocidad con la que aparece el texto de los diálogos.")
	_row_range("gameplay", "grid_opacity", "Grid Opacity", 50, "Opacidad de la rejilla del mapa táctico.")
	_row_toggle("gameplay", "terrain_info", "Show Terrain Info", true, "Mostrar el panel de información del terreno.")
	_row_toggle("gameplay", "goal_info", "Show Goal Info", true, "Mostrar el objetivo del capítulo.")
	_row_toggle("gameplay", "autocursor", "Auto Cursor", false, "Situar el cursor sobre la siguiente unidad automáticamente.")
	_row_toggle("gameplay", "auto_end", "Auto End Turn", false, "Terminar el turno automáticamente al mover todas las unidades.")
	_row_toggle("gameplay", "confirm_end", "Confirm End Turn", true, "Pedir confirmación antes de terminar el turno.")
	_row_toggle("gameplay", "tutorials", "Tutorials", true, "Mostrar los mensajes de tutorial.")


func _row_section(title_text: String) -> void:
	_specs.append({ "kind": "section", "label": title_text })

func _row_range(section: String, key: String, label: String, default: int, desc: String) -> void:
	var val: int = int(_cfg_get(section, key, default))
	_specs.append({ "kind": "range", "section": section, "key": key, "label": label,
			"value": clampi(int(round(val / 10.0)) * 10, 0, 100), "desc": desc })

func _row_enum(section: String, key: String, label: String, choices: Array, default: int, desc: String) -> void:
	var idx: int = clampi(int(_cfg_get(section, key, default)), 0, choices.size() - 1)
	_specs.append({ "kind": "enum", "section": section, "key": key, "label": label,
			"choices": choices, "idx": idx, "desc": desc })

func _row_toggle(section: String, key: String, label: String, default: bool, desc: String) -> void:
	var on: bool = bool(_cfg_get(section, key, default))
	_specs.append({ "kind": "toggle", "section": section, "key": key, "label": label,
			"choices": ["On", "Off"], "idx": (0 if on else 1), "desc": desc })

func _row_set(label: String, desc: String) -> void:
	var cur: String = AssetSet.current()
	var idx: int = AssetSet.SETS.find(cur)
	if idx < 0:
		idx = AssetSet.SETS.find(AssetSet.DEFAULT)
	_specs.append({ "kind": "set", "label": label, "choices": AssetSet.SETS, "idx": idx,
			"applied": cur, "desc": desc })


# ── Construcción de la UI ─────────────────────────────────────────────────────
func _build_ui() -> void:
	var font := load(AssetSet.p(SERIF_FONT))

	# Fondo OPACO a pantalla completa (cubre el menú de debajo). Base opaca de
	# seguridad + ilustración + tinte oscuro para legibilidad.
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
	tint.color = Color(0.03, 0.04, 0.09, 0.86)
	tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(tint)

	# CenterContainer a pantalla completa → centra el panel sea cual sea su tamaño
	# (PRESET_CENTER sobre el PanelContainer fallaba: calculaba el offset con
	# tamaño 0 aún sin dimensionar y lo mandaba abajo-derecha).
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.13, 0.94)
	sb.set_border_width_all(3)
	sb.border_color = COLOR_GOLD_DIM
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 40
	sb.content_margin_right = 40
	sb.content_margin_top = 24
	sb.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", sb)
	panel.custom_minimum_size = Vector2(860, 660)
	center.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)

	var title := Label.new()
	title.text = "Configuration"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if font != null:
		title.add_theme_font_override("font", font)
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", COLOR_GOLD)
	title.add_theme_color_override("font_outline_color", COLOR_OUTLINE)
	title.add_theme_constant_override("outline_size", 5)
	col.add_child(title)
	col.add_child(HSeparator.new())

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_scroll)
	_rows_box = VBoxContainer.new()
	_rows_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows_box.add_theme_constant_override("separation", 6)
	_scroll.add_child(_rows_box)

	for spec in _specs:
		_ui.append(_build_row(spec, font))

	col.add_child(HSeparator.new())
	_desc = Label.new()
	_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.custom_minimum_size = Vector2(0, 44)
	if font != null:
		_desc.add_theme_font_override("font", font)
	_desc.add_theme_font_size_override("font_size", 20)
	_desc.add_theme_color_override("font_color", COLOR_GOLD)
	_desc.add_theme_color_override("font_outline_color", COLOR_OUTLINE)
	_desc.add_theme_constant_override("outline_size", 3)
	col.add_child(_desc)

	_sel = _first_selectable()


## Fila visual de un spec. Devuelve un dict con referencias, o null si es sección.
func _build_row(spec: Dictionary, font) -> Variant:
	if spec["kind"] == "section":
		var sec := Label.new()
		sec.text = str(spec["label"])
		if font != null:
			sec.add_theme_font_override("font", font)
		sec.add_theme_font_size_override("font_size", 24)
		sec.add_theme_color_override("font_color", COLOR_GOLD_DIM)
		sec.add_theme_color_override("font_outline_color", COLOR_OUTLINE)
		sec.add_theme_constant_override("outline_size", 3)
		var m := MarginContainer.new()
		m.add_theme_constant_override("margin_top", 8)
		m.add_child(sec)
		_rows_box.add_child(m)
		return null

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)

	var marker := Label.new()
	marker.text = "▶"
	marker.custom_minimum_size = Vector2(26, 0)
	if font != null:
		marker.add_theme_font_override("font", font)
	marker.add_theme_font_size_override("font_size", 22)
	marker.add_theme_color_override("font_color", COLOR_GOLD)
	hb.add_child(marker)

	var lbl := Label.new()
	lbl.text = str(spec["label"])
	lbl.custom_minimum_size = Vector2(300, 0)
	if font != null:
		lbl.add_theme_font_override("font", font)
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_color", COLOR_TEXT)
	lbl.add_theme_color_override("font_outline_color", COLOR_OUTLINE)
	lbl.add_theme_constant_override("outline_size", 3)
	hb.add_child(lbl)

	var value_box := HBoxContainer.new()
	value_box.add_theme_constant_override("separation", 14)
	value_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(value_box)

	var row: Dictionary = { "spec": spec, "node": hb, "marker": marker, "label": lbl,
			"choices": [], "segments": [] }

	if spec["kind"] == "range":
		for i in range(10):
			var seg := ColorRect.new()
			seg.custom_minimum_size = Vector2(22, 16)
			value_box.add_child(seg)
			row["segments"].append(seg)
	else:
		for choice in spec["choices"]:
			var c := Label.new()
			c.text = str(choice)
			if font != null:
				c.add_theme_font_override("font", font)
			c.add_theme_font_size_override("font_size", 22)
			c.add_theme_color_override("font_outline_color", COLOR_OUTLINE)
			c.add_theme_constant_override("outline_size", 3)
			value_box.add_child(c)
			row["choices"].append(c)

	_rows_box.add_child(hb)
	return row


# ── Refresco visual ───────────────────────────────────────────────────────────
func _refresh() -> void:
	for i in range(_specs.size()):
		var row = _ui[i]
		if row == null:
			continue
		var focused: bool = (i == _sel)
		row["marker"].visible = focused
		row["label"].add_theme_color_override("font_color", COLOR_GOLD if focused else COLOR_TEXT)
		var spec: Dictionary = row["spec"]
		if spec["kind"] == "range":
			var filled: int = int(spec["value"]) / 10
			var segs: Array = row["segments"]
			for s in range(segs.size()):
				segs[s].color = COLOR_GOLD if s < filled else SEG_EMPTY
		else:
			var chs: Array = row["choices"]
			for c in range(chs.size()):
				chs[c].add_theme_color_override("font_color", COLOR_GOLD if c == int(spec["idx"]) else COLOR_DIM)
	if _sel >= 0 and _sel < _specs.size():
		_desc.text = str(_specs[_sel].get("desc", ""))
		if _ui[_sel] != null and _scroll != null:
			_scroll.ensure_control_visible(_ui[_sel]["node"])


# ── Input ─────────────────────────────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_close()
		_handled()
	elif event.is_action_pressed("ui_up"):
		_sel = _step_selectable(_sel, -1)
		_refresh()
		_handled()
	elif event.is_action_pressed("ui_down"):
		_sel = _step_selectable(_sel, 1)
		_refresh()
		_handled()
	elif event.is_action_pressed("ui_left"):
		_change(-1)
		_handled()
	elif event.is_action_pressed("ui_right"):
		_change(1)
		_handled()


func _handled() -> void:
	get_viewport().set_input_as_handled()


## Siguiente fila seleccionable desde `from` en dirección `step` (con clamp).
func _step_selectable(from: int, step: int) -> int:
	var i: int = from + step
	while i >= 0 and i < _specs.size():
		if _ui[i] != null:
			return i
		i += step
	return from


func _first_selectable() -> int:
	for i in range(_specs.size()):
		if _ui[i] != null:
			return i
	return 0


## Cambia el valor de la fila enfocada (delta = -1 / +1).
func _change(delta: int) -> void:
	if _sel < 0 or _sel >= _specs.size() or _ui[_sel] == null:
		return
	var spec: Dictionary = _specs[_sel]
	match spec["kind"]:
		"range":
			spec["value"] = clampi(int(spec["value"]) + delta * 10, 0, 100)
			_store(spec["section"], spec["key"], int(spec["value"]))
			if spec["key"] == "music_volume":
				_apply_bus("Music", int(spec["value"]))
			elif spec["key"] == "sfx_volume":
				_apply_bus("SFX", int(spec["value"]))
		"enum":
			spec["idx"] = clampi(int(spec["idx"]) + delta, 0, spec["choices"].size() - 1)
			_store(spec["section"], spec["key"], int(spec["idx"]))
		"toggle":
			spec["idx"] = clampi(int(spec["idx"]) + delta, 0, spec["choices"].size() - 1)
			_store(spec["section"], spec["key"], int(spec["idx"]) == 0)
		"set":
			var new_idx: int = clampi(int(spec["idx"]) + delta, 0, spec["choices"].size() - 1)
			if new_idx != int(spec["idx"]):
				spec["idx"] = new_idx
				var chosen: String = str(spec["choices"][new_idx])
				AssetSet.save(chosen)
				if chosen != str(spec["applied"]):
					_show_restart_notice(chosen)
	_refresh()


# ── Persistencia / audio ──────────────────────────────────────────────────────
func _cfg_get(section: String, key: String, default):
	return _cfg.get_value(section, key, default)

func _store(section: String, key: String, val) -> void:
	_cfg.set_value(section, key, val)
	_cfg.save(CFG)

func _apply_bus(bus_name: String, value_0_100: int) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(clampf(value_0_100 / 100.0, 0.0001, 1.0)))


## Panel modal: el nuevo set gráfico se aplicará al reiniciar el juego.
func _show_restart_notice(set_name: String) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(center)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.13, 0.98)
	sb.set_border_width_all(3)
	sb.border_color = COLOR_GOLD
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 34
	sb.content_margin_right = 34
	sb.content_margin_top = 26
	sb.content_margin_bottom = 22
	panel.add_theme_stylebox_override("panel", sb)
	panel.custom_minimum_size = Vector2(560, 0)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	panel.add_child(box)
	var msg := Label.new()
	msg.text = "El set gráfico «%s» se aplicará\nal reiniciar el juego." % set_name
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.add_theme_font_size_override("font_size", 22)
	msg.add_theme_color_override("font_color", COLOR_TEXT)
	msg.add_theme_color_override("font_outline_color", COLOR_OUTLINE)
	msg.add_theme_constant_override("outline_size", 3)
	box.add_child(msg)
	var ok := Button.new()
	ok.text = "OK"
	ok.add_theme_font_size_override("font_size", 22)
	ok.add_theme_color_override("font_color", COLOR_TEXT)
	ok.add_theme_color_override("font_focus_color", COLOR_GOLD)
	ok.pressed.connect(layer.queue_free)
	box.add_child(ok)
	ok.grab_focus()


func _close() -> void:
	if get_tree().current_scene == self:
		FadeCanvas.change_scene_to_file("res://Scenes/main_menu.tscn")
	else:
		options_closed.emit()
		queue_free()
