extends Control
class_name LanguageScreen

# ============================================================
# LANGUAGE — selección de idioma (recreado desde cero)
# ============================================================
# Columna de idiomas + bandera que cambia con el foco. Al elegir:
# fija y guarda el locale (FadeCanvas.save_locale) y transiciona a la
# siguiente escena. Navegable con teclado/mando Y ratón.
#
# Usa las banderas importadas en res://assets/languages/Flags/.
# NOTA: la fuente FE puede no tener glifos CJK/acentos; "Japanese" va en latín
# y los endónimos con acento se verán bien cuando se añada una fuente con esos
# glifos (los textos se pueden cambiar en LANGS).
# ============================================================

const FLAGS := "res://assets/languages/Flags/"
const NEXT_SCENE := "res://Scenes/intro.tscn"   # Language → Intro → MainMenu

const COLOR_GOLD := Color(1.00, 0.84, 0.36, 1.0)
const COLOR_TEXT := Color(0.95, 0.95, 0.90, 1.0)
const COLOR_OUTLINE := Color(0.0, 0.0, 0.0, 1.0)
const COLOR_BG := Color(0.05, 0.06, 0.13, 1.0)

const LANGS := [
	{ "code": "en", "name": "English" },
	{ "code": "es", "name": "Español" },
	{ "code": "de", "name": "Deutsch" },
	{ "code": "fr", "name": "Français" },
	{ "code": "ja", "name": "Japanese" },
]

var _flag: TextureRect


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_bg()
	_build_title()
	_build_flag()
	_build_buttons()


func _build_bg() -> void:
	var bg := ColorRect.new()
	bg.color = COLOR_BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)


func _build_title() -> void:
	var t := Label.new()
	t.text = "LANGUAGE"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 40)
	t.add_theme_color_override("font_color", COLOR_GOLD)
	t.add_theme_color_override("font_outline_color", COLOR_OUTLINE)
	t.add_theme_constant_override("outline_size", 6)
	t.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	t.offset_top = 50
	t.offset_bottom = 100
	add_child(t)


func _build_flag() -> void:
	_flag = TextureRect.new()
	_flag.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_flag.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_flag.offset_left = -90
	_flag.offset_right = 90
	_flag.offset_top = 120
	_flag.offset_bottom = 230
	_flag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flag)
	_set_flag("en")


func _set_flag(code: String) -> void:
	var p := FLAGS + code + ".png"
	if ResourceLoader.exists(p):
		_flag.texture = load(p)


func _build_buttons() -> void:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	col.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	col.offset_left = -160
	col.offset_right = 160
	col.offset_top = 60
	col.offset_bottom = 60 + LANGS.size() * 54
	add_child(col)
	var first: Button = null
	for l in LANGS:
		var b := _make_button(str(l["name"]), str(l["code"]))
		col.add_child(b)
		if first == null:
			first = b
	if first != null:
		first.call_deferred("grab_focus")


func _make_button(text: String, code: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(320, 44)
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_size_override("font_size", 26)
	b.add_theme_color_override("font_color", COLOR_TEXT)
	b.add_theme_color_override("font_focus_color", COLOR_GOLD)
	b.add_theme_color_override("font_hover_color", COLOR_GOLD)
	b.add_theme_color_override("font_pressed_color", COLOR_GOLD)
	b.add_theme_color_override("font_outline_color", COLOR_OUTLINE)
	b.add_theme_constant_override("outline_size", 4)
	var empty := StyleBoxEmpty.new()
	for s in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(s, empty)
	b.focus_entered.connect(func(): _set_flag(code))
	b.mouse_entered.connect(b.grab_focus)
	b.pressed.connect(_select.bind(code))
	return b


func _select(code: String) -> void:
	FadeCanvas.save_locale(code)
	FadeCanvas.change_scene_to_file(NEXT_SCENE)
