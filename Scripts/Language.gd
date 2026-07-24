class_name LanguageScreen
extends SelectMenu

# ============================================================
# LANGUAGE — Menú 1 del arranque: selección de idioma.
# ============================================================
# Rediseño: UN SOLO panel con
#   · Título "Idioma" arriba (estilo panel de opciones) que se RE-TRADUCE EN VIVO
#     al idioma de la bandera enfocada (English→"Language", Español→"Idioma", …).
#   · Un GRID de BANDERAS (sin palabras): la identidad del idioma la da el título
#     y la propia bandera.
#
# Reutiliza la maquinaria de SelectMenu (fondo con parallax de runas + niebla,
# cursor-mano, SFX, fuentes) pero sobreescribe `_ready`/`_process` para montar el
# layout de panel único en vez de la lista + preview por defecto.
#
# Idiomas: en, es (listos) y de, fr, it, ja, pt (W.I.P). Los W.I.P salen con la
# bandera atenuada + etiqueta "W.I.P" y NO son enfocables (el cursor los salta);
# sus traducciones incompletas caen a inglés (locale/fallback = "en"). "ja" se
# mostraría en latín en otros sitios porque la sprite-font LT no trae kana.
# ============================================================

const FLAGS := "res://assets/languages/Flags/"
const NEXT_SCENE := "res://Scenes/mode_select.tscn"   # Idioma → Modo → Intro → MainMenu

# Fondo: base de runas de Jugdral (parallax). La niebla la pone SelectMenu.
const BG_BASE := "res://assets/panoramas/default_background.png"
const PANEL_TITLE_BG := "res://assets/menus/menu_bg_white.png"

# Idiomas y si su traducción está lista para jugar. Los no-listos = W.I.P.
const LANGS := [
	{ "id": "en", "ready": true },
	{ "id": "es", "ready": true },
	{ "id": "de", "ready": false },
	{ "id": "fr", "ready": false },
	{ "id": "it", "ready": false },
	{ "id": "ja", "ready": false },
	{ "id": "pt", "ready": false },
]

const GRID_COLS := 3
const GRID_HSEP := 26
const GRID_VSEP := 22
const FLAG_W := 208
const FLAG_H := 128
const FLAG_PAD := 6                 # margen bandera↔borde del botón
const FLAG_DIM_WIP := 0.32          # opacidad de las banderas W.I.P
const FLAG_DIM_IDLE := 0.80         # banderas listas sin foco
const TITLE_FS := 72

# Palabra "Idioma" por locale — respaldo si TranslationServer no resuelve la clave
# LANGUAGE para ese locale. Deriva del CSV de menús (celdas vacías → inglés).
const TITLE_KEY := "LANGUAGE"
const TITLE_FALLBACK := {
	"en": "Language", "es": "Idioma", "de": "Sprache",
	"fr": "Langue", "it": "Language", "ja": "Language", "pt": "Language",
}

var _title_lbl: Label = null
var _flag_btns: Array = []               # solo banderas enfocables (ready)
var _flag_tex: Dictionary = {}           # Button -> TextureRect de su bandera


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_bg()                          # fondo runas + parallax + niebla (base)
	_build_panel()
	_build_cursor()                      # cursor-mano de la base
	# Enfocar la primera bandera lista sin sonar como navegación manual.
	if not _flag_btns.is_empty():
		_skip_next_nav = true
		_flag_btns[0].call_deferred("grab_focus")


# ── Layout: panel único (título + grid de banderas) ─────────────────────────
func _build_panel() -> void:
	var vp: Vector2 = get_viewport_rect().size

	var rows: int = int(ceil(float(LANGS.size()) / float(GRID_COLS)))
	var grid_w: float = GRID_COLS * FLAG_W + (GRID_COLS - 1) * GRID_HSEP
	var grid_h: float = rows * FLAG_H + (rows - 1) * GRID_VSEP

	var title_y: float = 44.0
	var title_h: float = 92.0
	var gap: float = 22.0
	var grid_y: float = title_y + title_h + gap
	var pad_x: float = 56.0
	var pw: float = grid_w + pad_x * 2.0
	var ph: float = grid_y + grid_h + 48.0

	var panel := NinePatchRect.new()
	panel.texture = load(AssetSet.p(PANEL))
	panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	panel.patch_margin_left = 14
	panel.patch_margin_right = 14
	panel.patch_margin_top = 22
	panel.patch_margin_bottom = 22
	panel.position = Vector2(round((vp.x - pw) / 2.0), round((vp.y - ph) / 2.0))
	panel.size = Vector2(pw, ph)
	add_child(panel)

	# Título re-traducible (arranca en el idioma de la primera bandera lista).
	_title_lbl = Label.new()
	_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_lbl.auto_translate_mode = Control.AUTO_TRANSLATE_MODE_DISABLED
	_title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_lbl.position = Vector2(0, title_y)
	_title_lbl.size = Vector2(pw, title_h)
	_apply_font(_title_lbl, TITLE_FS, COLOR_GOLD, 4)
	var first_id: String = str(LANGS[0]["id"])
	_title_lbl.text = _title_for_locale(first_id)
	panel.add_child(_title_lbl)

	# Grid de banderas, centrado en el panel.
	var grid := GridContainer.new()
	grid.columns = GRID_COLS
	grid.add_theme_constant_override("h_separation", GRID_HSEP)
	grid.add_theme_constant_override("v_separation", GRID_VSEP)
	grid.position = Vector2(round((pw - grid_w) / 2.0), grid_y)
	grid.size = Vector2(grid_w, grid_h)
	panel.add_child(grid)
	for lang in LANGS:
		grid.add_child(_make_flag(lang))


## Una celda del grid: Button con la bandera de fondo. W.I.P → atenuada + etiqueta,
## no enfocable (el cursor la salta).
func _make_flag(lang: Dictionary) -> Control:
	var id := str(lang.get("id", ""))
	var ready: bool = bool(lang.get("ready", false))

	var b := Button.new()
	b.custom_minimum_size = Vector2(FLAG_W, FLAG_H)
	b.focus_mode = Control.FOCUS_ALL if ready else Control.FOCUS_NONE
	b.mouse_filter = Control.MOUSE_FILTER_STOP if ready else Control.MOUSE_FILTER_IGNORE
	b.disabled = not ready
	b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var empty := StyleBoxEmpty.new()
	for s in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(s, empty)
	b.set_meta("id", id)

	var flag := TextureRect.new()
	flag.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	flag.stretch_mode = TextureRect.STRETCH_SCALE
	flag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flag.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flag.offset_left = FLAG_PAD
	flag.offset_top = FLAG_PAD
	flag.offset_right = -FLAG_PAD
	flag.offset_bottom = -FLAG_PAD
	var fp := AssetSet.p(FLAGS + id + ".png")
	if ResourceLoader.exists(fp):
		flag.texture = load(fp)
	flag.modulate = Color(1, 1, 1, FLAG_DIM_WIP if not ready else FLAG_DIM_IDLE)
	b.add_child(flag)

	if not ready:
		var tag := Label.new()
		tag.text = "W.I.P"
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tag.auto_translate_mode = Control.AUTO_TRANSLATE_MODE_DISABLED
		tag.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_apply_font(tag, 30, COLOR_GOLD, 4)
		b.add_child(tag)
	else:
		_flag_tex[b] = flag
		_flag_btns.append(b)
		b.focus_entered.connect(_on_flag_focus.bind(b, id))
		b.mouse_entered.connect(b.grab_focus)
		b.pressed.connect(_on_flag_pressed.bind(id))
	return b


# ── Interacción ─────────────────────────────────────────────────────────────
func _on_flag_focus(b: Button, id: String) -> void:
	_move_cursor_to(b)                   # base: fija _cursor_target y lo hace visible
	# Realce: la bandera enfocada a plena opacidad, el resto (listas) atenuadas.
	for other in _flag_tex.keys():
		var t: TextureRect = _flag_tex[other]
		if t != null:
			t.modulate = Color(1, 1, 1, 1.0 if other == b else FLAG_DIM_IDLE)
	# Título en el idioma enfocado.
	if _title_lbl != null:
		_title_lbl.text = _title_for_locale(id)
	if _skip_next_nav:
		_skip_next_nav = false
	else:
		_play_sfx(SFX_NAV)


func _on_flag_pressed(id: String) -> void:
	if _busy:
		return
	_busy = true
	_play_sfx(SFX_CONFIRM)
	_on_choose(id)


# Cursor-mano a la IZQUIERDA de la bandera enfocada (el bobeo lo reusa de la base).
func _process(delta: float) -> void:
	if _cursor == null or not _cursor.visible:
		return
	if _cursor_target == null or not is_instance_valid(_cursor_target):
		return
	_bob_accum += delta
	if _bob_accum >= BOB_TIME:
		_bob_accum -= BOB_TIME
		_bob_i = (_bob_i + 1) % BOB_SEQ.size()
	var b := _cursor_target
	var hw := 15 * HAND_SCALE
	_cursor.global_position = Vector2(
		b.global_position.x - hw - 4 + BOB_SEQ[_bob_i],
		b.global_position.y + (b.size.y - 12 * HAND_SCALE) * 0.5)


## Palabra "Idioma" traducida al `loc` dado (para el título en vivo). Intenta el
## TranslationServer y cae al mapa de respaldo (derivado del CSV) / inglés.
func _title_for_locale(loc: String) -> String:
	var t := TranslationServer.get_translation_object(loc)
	if t != null:
		var m := String(t.get_message(TITLE_KEY))
		if m != "":
			return m
	return str(TITLE_FALLBACK.get(loc, "Language"))


func _apply_font(l: Label, fs: int, col: Color, outline: int) -> void:
	l.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var f := load(AssetSet.p(UI_FONT))
	if f != null:
		l.add_theme_font_override("font", f)
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", COLOR_OUTLINE)
	l.add_theme_constant_override("outline_size", outline)


# ── Fondo (virtuales de SelectMenu que sí seguimos usando) ──────────────────
func _bg_base_texture() -> Texture2D:
	var p := AssetSet.p(BG_BASE)
	return load(p) if ResourceLoader.exists(p) else null


func _bg_parallax() -> bool:
	return true


func _on_choose(id: String) -> void:
	FadeCanvas.save_locale(id)
	FadeCanvas.change_scene_to_file(NEXT_SCENE)
