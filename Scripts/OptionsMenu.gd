extends Control
class_name OptionsMenu

# ============================================================
# OptionsMenu / SettingsMenu — recreado desde cero (limpio)
# ============================================================
# Menú de opciones construido por código, autocontenido. Persiste en
# user://settings.cfg y aplica el audio a los buses "Music"/"SFX" si existen.
# Se puede usar como overlay (instanciado por MainMenu → emite options_closed)
# o como escena suelta (Back → vuelve al menú principal).
#
# Capta la esencia del SettingsMenu viejo (Audio + Gameplay) sin la complejidad
# de resolución/keybindings/pergamine, que se pueden añadir luego.
# ============================================================

signal options_closed

const CFG := "user://settings.cfg"
const COLOR_GOLD := Color(1.00, 0.84, 0.36, 1.0)
const COLOR_TEXT := Color(0.95, 0.95, 0.90, 1.0)
const COLOR_OUTLINE := Color(0.0, 0.0, 0.0, 1.0)

var _cfg := ConfigFile.new()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cfg.load(CFG)
	_build()
	# Aplicar audio guardado al abrir
	_apply_bus("Music", _cfg_get("audio", "music_volume", 70))
	_apply_bus("SFX", _cfg_get("audio", "sfx_volume", 80))


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.72)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var title := Label.new()
	title.text = "OPTIONS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", COLOR_GOLD)
	title.add_theme_color_override("font_outline_color", COLOR_OUTLINE)
	title.add_theme_constant_override("outline_size", 6)
	title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 30
	title.offset_bottom = 78
	add_child(title)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_top = 90
	scroll.offset_bottom = -70
	scroll.offset_left = 120
	scroll.offset_right = -120
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 8)
	scroll.add_child(vb)

	# --- AUDIO ---
	_section(vb, "AUDIO")
	_slider(vb, "audio", "music_volume", "Music Volume", 70, func(v): _apply_bus("Music", v))
	_slider(vb, "audio", "sfx_volume", "SFX Volume", 80, func(v): _apply_bus("SFX", v))
	_toggle(vb, "audio", "talk_sound", "Talk Sound", true)

	# --- GAMEPLAY ---
	_section(vb, "GAMEPLAY")
	_option(vb, "gameplay", "animations", "Battle Animations", ["On", "Map Only", "Off"], 0)
	_slider(vb, "gameplay", "unit_speed", "Unit Speed", 50)
	_slider(vb, "gameplay", "text_speed", "Text Speed", 50)
	_slider(vb, "gameplay", "grid_opacity", "Grid Opacity", 50)
	_toggle(vb, "gameplay", "terrain_info", "Show Terrain Info", true)
	_toggle(vb, "gameplay", "goal_info", "Show Goal Info", true)
	_toggle(vb, "gameplay", "autocursor", "Auto Cursor", false)
	_toggle(vb, "gameplay", "auto_end", "Auto End Turn", false)
	_toggle(vb, "gameplay", "confirm_end", "Confirm End Turn", true)
	_toggle(vb, "gameplay", "tutorials", "Tutorials", true)

	# --- Back ---
	var back := Button.new()
	back.text = "Back"
	back.add_theme_font_size_override("font_size", 24)
	back.add_theme_color_override("font_color", COLOR_TEXT)
	back.add_theme_color_override("font_focus_color", COLOR_GOLD)
	back.add_theme_color_override("font_hover_color", COLOR_GOLD)
	back.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	back.offset_top = -56
	back.offset_bottom = -16
	back.pressed.connect(_close)
	add_child(back)


# --- Helpers de UI ---
func _section(vb: VBoxContainer, title_text: String) -> void:
	var l := Label.new()
	l.text = title_text
	l.add_theme_font_size_override("font_size", 26)
	l.add_theme_color_override("font_color", COLOR_GOLD)
	l.add_theme_color_override("font_outline_color", COLOR_OUTLINE)
	l.add_theme_constant_override("outline_size", 4)
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_top", 10)
	m.add_child(l)
	vb.add_child(m)


func _row(vb: VBoxContainer, label_text: String) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(300, 0)
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", COLOR_TEXT)
	lbl.add_theme_color_override("font_outline_color", COLOR_OUTLINE)
	lbl.add_theme_constant_override("outline_size", 3)
	hb.add_child(lbl)
	vb.add_child(hb)
	return hb


func _slider(vb: VBoxContainer, section: String, key: String, label_text: String, default: int, on_change: Callable = Callable()) -> void:
	var hb := _row(vb, label_text)
	var s := HSlider.new()
	s.min_value = 0
	s.max_value = 100
	s.step = 1
	s.custom_minimum_size = Vector2(240, 24)
	s.value = float(_cfg_get(section, key, default))
	s.value_changed.connect(func(v):
		_store(section, key, int(v))
		if on_change.is_valid():
			on_change.call(int(v)))
	hb.add_child(s)


func _toggle(vb: VBoxContainer, section: String, key: String, label_text: String, default: bool) -> void:
	var hb := _row(vb, label_text)
	var c := CheckButton.new()
	c.button_pressed = bool(_cfg_get(section, key, default))
	c.toggled.connect(func(p): _store(section, key, p))
	hb.add_child(c)


func _option(vb: VBoxContainer, section: String, key: String, label_text: String, items: Array, default: int) -> void:
	var hb := _row(vb, label_text)
	var o := OptionButton.new()
	o.custom_minimum_size = Vector2(180, 0)
	for it in items:
		o.add_item(str(it))
	o.selected = int(_cfg_get(section, key, default))
	o.item_selected.connect(func(idx): _store(section, key, idx))
	hb.add_child(o)


# --- Config ---
func _cfg_get(section: String, key: String, default):
	return _cfg.get_value(section, key, default)

func _store(section: String, key: String, val) -> void:
	_cfg.set_value(section, key, val)
	_cfg.save(CFG)

func _apply_bus(bus_name: String, value_0_100: int) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(clampf(value_0_100 / 100.0, 0.0001, 1.0)))


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_close()


func _close() -> void:
	if get_tree().current_scene == self:
		FadeCanvas.change_scene_to_file("res://Scenes/main_menu.tscn")
	else:
		options_closed.emit()
		queue_free()
