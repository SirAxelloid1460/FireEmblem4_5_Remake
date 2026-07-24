class_name LanguageScreen
extends SelectMenu

# ============================================================
# LANGUAGE — Menú 1 del arranque: selección de idioma.
# ============================================================
# Rediseño (estilo pantalla de opciones):
#   · PLACA de TÍTULO separada arriba (fondo claro), con "Idioma" que se
#     RE-TRADUCE EN VIVO al idioma de la bandera enfocada (English→"Language",
#     Español→"Idioma", …).
#   · PANEL de contenido debajo con un GRID de BANDERAS (sin palabras). El grid
#     tiene CAPACIDAD RESERVADA (filas/huecos libres) para añadir más idiomas a
#     futuro sin rehacer el layout: no se llena entero con las banderas actuales.
#
# Reutiliza la maquinaria de SelectMenu (fondo con parallax de runas + niebla,
# cursor-mano, SFX, fuentes) pero sobreescribe `_ready`/`_process`.
#
# Idiomas: en, es (listos) y de, fr, it, ja, pt (W.I.P). Los W.I.P salen con la
# bandera atenuada + etiqueta "W.I.P" y NO son enfocables (el cursor los salta);
# sus traducciones incompletas caen a inglés (locale/fallback = "en").
# ============================================================

const FLAGS := "res://assets/languages/Flags/"
const NEXT_SCENE := "res://Scenes/mode_select.tscn"   # Idioma → Modo → Intro → MainMenu

# Fondo: base de runas de Jugdral (parallax). La niebla la pone SelectMenu.
const BG_BASE := "res://assets/panoramas/default_background.png"
const TITLE_BG := "res://assets/menus/menu_bg_white.png"   # placa clara del título (como Opciones)

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

# Grid con HUECO RESERVADO: se dimensiona para GRID_COLS × GRID_CAP_ROWS ranuras
# (capacidad), pero solo se rellenan las de LANGS. Así queda espacio visible para
# futuras banderas sin tocar el layout.
const GRID_COLS := 4
const GRID_CAP_ROWS := 3            # capacidad de filas (>= filas usadas ahora)
const GRID_HSEP := 30
const GRID_VSEP := 26
const FLAG_W := 150
const FLAG_H := 92
const FLAG_PAD := 8                 # margen bandera↔borde de su celda
const FLAG_DIM_WIP := 0.34          # opacidad de las banderas W.I.P (las listas van opacas)

const TITLE_FS := 84

# Palabra "Idioma" por locale — respaldo si TranslationServer no resuelve la clave
# LANGUAGE para ese locale. Deriva del CSV de menús (celdas vacías → inglés).
const TITLE_KEY := "LANGUAGE"
const TITLE_FALLBACK := {
	"en": "Language", "es": "Idioma", "de": "Sprache",
	"fr": "Langue", "it": "Language", "ja": "Language", "pt": "Language",
}

var _title_lbl: Label = null
var _content_panel: Control = null
var _focus_frame: Panel = null           # marco dorado sobre la bandera enfocada
var _flag_btns: Array = []               # solo banderas enfocables (ready)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_bg()                          # fondo runas + parallax + niebla (base)
	_build_layout()
	_build_cursor()                      # cursor-mano de la base
	if not _flag_btns.is_empty():
		_skip_next_nav = true
		_flag_btns[0].call_deferred("grab_focus")


# ── Layout: placa de título (arriba) + panel de banderas (debajo) ───────────
func _build_layout() -> void:
	var vp: Vector2 = get_viewport_rect().size

	var grid_w: float = GRID_COLS * FLAG_W + (GRID_COLS - 1) * GRID_HSEP
	var cap_grid_h: float = GRID_CAP_ROWS * FLAG_H + (GRID_CAP_ROWS - 1) * GRID_VSEP
	var pad: float = 46.0
	var content_w: float = grid_w + pad * 2.0
	var content_h: float = cap_grid_h + pad * 2.0

	var title_w: float = 600.0
	var title_h: float = 138.0
	var gap: float = 24.0

	var total_h: float = title_h + gap + content_h
	var top: float = round((vp.y - total_h) / 2.0)

	# ── Placa de título (separada, fondo claro estilo Opciones) ──
	var title_root := Control.new()
	title_root.position = Vector2(round((vp.x - title_w) / 2.0), top)
	title_root.size = Vector2(title_w, title_h)
	title_root.modulate.a = 0.85
	add_child(title_root)
	var tnp := _nine(TITLE_BG, 8)
	tnp.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title_root.add_child(tnp)
	_title_lbl = Label.new()
	_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_lbl.auto_translate_mode = Control.AUTO_TRANSLATE_MODE_DISABLED
	_title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_apply_font(_title_lbl, TITLE_FS, COLOR_GOLD, 4)
	_title_lbl.text = _title_for_locale(str(LANGS[0]["id"]))
	title_root.add_child(_title_lbl)

	# ── Panel de contenido (banderas) ──
	_content_panel = Control.new()
	_content_panel.position = Vector2(round((vp.x - content_w) / 2.0), top + title_h + gap)
	_content_panel.size = Vector2(content_w, content_h)
	add_child(_content_panel)
	var cnp := _nine(PANEL, 14, 22)
	cnp.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content_panel.add_child(cnp)

	# Grid TOP-alineado dentro del panel: las filas usadas arriba, capacidad libre
	# abajo (espacio reservado para futuras banderas).
	var grid := GridContainer.new()
	grid.columns = GRID_COLS
	grid.add_theme_constant_override("h_separation", GRID_HSEP)
	grid.add_theme_constant_override("v_separation", GRID_VSEP)
	grid.position = Vector2(round((content_w - grid_w) / 2.0), pad)
	_content_panel.add_child(grid)
	for lang in LANGS:
		grid.add_child(_make_flag(lang))

	# Marco de foco (dorado), encima de las banderas; se mueve al enfocar.
	_focus_frame = Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_color = COLOR_GOLD
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(3)
	_focus_frame.add_theme_stylebox_override("panel", sb)
	_focus_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_focus_frame.visible = false
	_content_panel.add_child(_focus_frame)


## Una celda del grid: Button con la bandera. Listas = opacas y enfocables; W.I.P
## = atenuada + etiqueta, no enfocable (el cursor la salta).
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
	if not ready:
		flag.modulate = Color(1, 1, 1, FLAG_DIM_WIP)
	b.add_child(flag)

	if not ready:
		var tag := Label.new()
		tag.text = "W.I.P"
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tag.auto_translate_mode = Control.AUTO_TRANSLATE_MODE_DISABLED
		tag.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_apply_font(tag, 26, COLOR_GOLD, 4)
		b.add_child(tag)
	else:
		_flag_btns.append(b)
		b.focus_entered.connect(_on_flag_focus.bind(b, id))
		b.mouse_entered.connect(b.grab_focus)
		b.pressed.connect(_on_flag_pressed.bind(id))
	return b


# ── Interacción ─────────────────────────────────────────────────────────────
func _on_flag_focus(b: Button, id: String) -> void:
	_move_cursor_to(b)                   # base: fija _cursor_target y lo hace visible
	# Marco dorado sobre la bandera enfocada.
	if _focus_frame != null and _content_panel != null:
		_focus_frame.position = b.global_position - _content_panel.global_position
		_focus_frame.size = b.size
		_focus_frame.visible = true
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
		b.global_position.x - hw - 6 + BOB_SEQ[_bob_i],
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


## NinePatchRect con el skin indicado (margen uniforme, o L/R = m, T/B = mv).
func _nine(tex_path: String, m: int, mv: int = -1) -> NinePatchRect:
	var n := NinePatchRect.new()
	n.texture = load(AssetSet.p(tex_path))
	n.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	n.patch_margin_left = m
	n.patch_margin_right = m
	n.patch_margin_top = m if mv < 0 else mv
	n.patch_margin_bottom = m if mv < 0 else mv
	return n


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
