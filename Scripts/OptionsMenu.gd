extends Control
class_name OptionsMenu

# ============================================================
# OptionsMenu — panel de configuración estilo Fire Emblem (FE4 "Configuration")
# ============================================================
# Autocontenido (construido por código). Overlay a PANTALLA COMPLETA con fondo
# propio OPACO que cubre el menú de debajo.
#
# Estructura (dos paneles):
#   · Panel de TÍTULO (menu_bg_white, sprite-font LT, TODO a opacidad 0.8).
#   · Panel de OPCIONES (menu_bg_base; SOLO el fondo a 0.7, el contenido a 1.0).
#     Cada fila tiene 3 columnas: [icono] [texto] [opciones]. El cursor es una
#     mano (menu_hand) que apunta a la fila enfocada con un leve bob lateral.
#
# Navegación: ↑↓ fila · ←→ valor · Cancel vuelve. Barra de descripción abajo.
# Persiste en user://settings.cfg (mismas claves de antes). Audio a buses
# Music/SFX. "Graphics Set" se guarda con AssetSet.save (aplica al reiniciar).
#
# NOTA GDScript: Dictionary por corchetes (spec["k"]), Godot 4 no tiene dot-access.
# ============================================================

signal options_closed

const CFG := "user://settings.cfg"
const TEXT_FONT := "res://assets/fonts/bmp/text.fnt"   # sprite-font LT (BMFont)
const BG_IMAGE := "res://assets/panoramas/default_background.png"
const TITLE_BG := "res://assets/menus/menu_bg_white.png"
const PANEL_BG := "res://assets/menus/menu_bg_base.png"
const HAND     := "res://assets/menus/menu_hand.png"
const SETTINGS_ICONS := "res://assets/sprites/settings_icons.png"   # tira vertical 16×16
const ICON_SRC := 16
const FLAGS := "res://assets/languages/Flags/"

# Idiomas del carrusel (los que tienen columna en la tabla de traducción). El
# nombre de ja se muestra en latín porque la sprite-font no trae kana.
const LANGS := [
	{ "id": "en", "name": "English" },
	{ "id": "es", "name": "Español" },
	{ "id": "de", "name": "Deutsch" },
	{ "id": "fr", "name": "Français" },
	{ "id": "ja", "name": "Japanese" },
]
# Resoluciones (aspecto 3:2, nativo del juego). Se aplican al reiniciar.
const RESOLUTIONS := ["720x480", "960x640", "1200x800", "1440x960", "1920x1280"]
# Modos de ventana (claves de traducción). Se aplican en vivo.
const WINDOW_MODES := ["WMWINDOW", "WMBORDER", "WMFULL"]
const FLAG_W := 66
const FLAG_H := 44

const PATCH := 8              # margen 9-slice de las texturas de panel (24×24)
const HAND_W := 15
const HAND_H := 12
const HAND_SCALE := 4
const ROW_H := 90
const ICON_W := 76
const HAND_SLOT_W := 64
const TEXT_W := 470
const TITLE_ALPHA := 0.8
const PANEL_ALPHA := 0.7

const COLOR_GOLD     := Color(1.00, 0.84, 0.36, 1.0)
const COLOR_GOLD_DIM := Color(0.72, 0.62, 0.32, 1.0)
const COLOR_TEXT     := Color(0.92, 0.93, 0.88, 1.0)
const COLOR_DIM      := Color(0.55, 0.57, 0.62, 1.0)
const COLOR_OUTLINE  := Color(0.0, 0.0, 0.0, 1.0)
const SEG_ON         := Color(1.00, 0.84, 0.36, 1.0)
const SEG_OFF        := Color(0.22, 0.24, 0.30, 1.0)

# SFX de navegación (mismos assets que el menú principal).
const SFX_NAV    := "Select 5"
const SFX_CHANGE := "Select 4"

var _specs: Array = []
var _ui: Array = []
var _sel: int = 0
var _cfg := ConfigFile.new()
var _desc: Label = null
var _rows_box: VBoxContainer = null
var _scroll: ScrollContainer = null
var _font = null
var _bob_t: float = 0.0
var _icon_sheet: Texture2D = null       # tira de iconos de settings (16×16 cada uno)
var _icon_i: int = 0                     # índice de icono para la siguiente fila
# Botón "Controls" (abre el submenú de remapeo). Vive arriba, a la altura del
# panel de título; se enfoca con _sel == CTRL_SEL (arriba de la primera fila).
const CTRL_SEL := -1
var _ctrl_root: Control = null
var _ctrl_hand: TextureRect = null
var _ctrl_lbl: Label = null
var _title_lbl: Label = null            # rótulo "Configuration" (para re-traducir)
var _sections: Array = []               # [{spec, lbl}] de las secciones (re-traducir)
var _sfx: AudioStreamPlayer = null      # reproductor de SFX de navegación


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Filtro NEAREST heredado por los hijos → la sprite-font se ve nítida (sin
	# suavizado) al escalarse.
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_cfg.load(CFG)
	_font = load(AssetSet.p(TEXT_FONT))
	_build_specs()
	_build_ui()
	_apply_bus("Music", int(_cfg_get("audio", "music_volume", 70)))
	_apply_bus("SFX", int(_cfg_get("audio", "sfx_volume", 80)))
	_refresh()


# ── Definición de opciones ────────────────────────────────────────────────────
# Los rótulos y descripciones se pasan como CLAVES de la tabla de traducción
# (MainMenu.csv); _row_* las resuelve con tr() al construir, según el idioma
# activo. Las secciones (AUDIO/GRAPHICS/GAMEPLAY) se dejan literales.
func _build_specs() -> void:
	_row_section("SECLANGUAGE")
	_row_language()

	_row_section("SECAUDIO")
	_row_range("audio", "music_volume", "MUSICLEVEL", 70, "MUSICLEVELDESC")
	_row_range("audio", "sfx_volume", "SOUNDLEVEL", 80, "SOUNDLEVELDESC")
	_row_toggle("audio", "talk_sound", "TALKSOUND", true, "TALKSOUNDDESC")

	_row_section("SECGRAPHICS")
	_row_set("QSET", "QSETDESC")

	_row_section("SECDISPLAY")
	_row_enum("display", "window_mode", "WINDOWMODE", WINDOW_MODES, 0, "WINDOWMODEDESC")
	_row_enum("display", "resolution", "RESOLUTION", RESOLUTIONS, 2, "RESOLUTIONDESC")

	_row_section("SECGAMEPLAY")
	_row_enum("gameplay", "animations", "ANIMATION", ["OPTON", "ANIMMAP", "OPTOFF"], 0, "ANIMATIONDESC")
	_row_range("gameplay", "unit_speed", "UNITSPEED", 50, "UNITSPEEDDESC")
	_row_range("gameplay", "text_speed", "TEXTSPEED", 50, "TEXTSPEEDDESC")
	_row_range("gameplay", "grid_opacity", "GRIDOPAC", 50, "GRIDOPACDESC")
	_row_toggle("gameplay", "battle_bg", "BATTLEBG", true, "BATTLEBGDESC")
	_row_enum("gameplay", "hpbar_team", "HPBARTEAM",
			["HPBARTEAMOPTION0", "HPBARTEAMOPTION1", "HPBARTEAMOPTION2", "HPBARTEAMOPTION3", "HPBARTEAMOPTION4"], 1, "HPBARTEAMDESC")
	_row_enum("gameplay", "hpbar_kind", "HPBARKIND", ["HPBARKINDOPTION1", "HPBARKINDOPTION2"], 0, "HPBARKINDDESC")
	_row_toggle("gameplay", "terrain_info", "TERRAININFO", true, "TERRAININFODESC")
	_row_toggle("gameplay", "goal_info", "GOALINFO", true, "GOALINFODESC")
	_row_toggle("gameplay", "autocursor", "AUTOCURSOR", false, "AUTOCURSORDESC")
	_row_toggle("gameplay", "auto_end", "AUTOEND", false, "AUTOENDDESC")
	_row_toggle("gameplay", "confirm_end", "CONFIRMEND", true, "CONFIRMENDDESC")
	_row_toggle("gameplay", "tutorials", "HINTS", true, "HINTSDESC")
	_row_toggle("input", "mouse", "MOUSE", false, "MOUSEDESC")


# Cada fila guarda sus CLAVES (lkey/dkey/ckeys) además del texto ya traducido,
# para poder re-traducir en vivo al cambiar de idioma (_relocalize).
func _row_section(title_key: String) -> void:
	_specs.append({ "kind": "section", "label": tr(title_key), "skey": title_key })

func _row_range(section: String, key: String, label: String, default: int, desc: String) -> void:
	var val: int = int(_cfg_get(section, key, default))
	_specs.append({ "kind": "range", "section": section, "key": key, "label": tr(label), "lkey": label,
			"value": clampi(int(round(val / 10.0)) * 10, 0, 100), "desc": tr(desc), "dkey": desc, "icon": "" })

func _row_enum(section: String, key: String, label: String, choice_keys: Array, default: int, desc: String) -> void:
	var idx: int = clampi(int(_cfg_get(section, key, default)), 0, choice_keys.size() - 1)
	_specs.append({ "kind": "enum", "section": section, "key": key, "label": tr(label), "lkey": label,
			"choices": _tr_all(choice_keys), "ckeys": choice_keys, "idx": idx, "desc": tr(desc), "dkey": desc, "icon": "" })

func _row_toggle(section: String, key: String, label: String, default: bool, desc: String) -> void:
	var on: bool = bool(_cfg_get(section, key, default))
	_specs.append({ "kind": "toggle", "section": section, "key": key, "label": tr(label), "lkey": label,
			"choices": [tr("OPTON"), tr("OPTOFF")], "ckeys": ["OPTON", "OPTOFF"], "idx": (0 if on else 1),
			"desc": tr(desc), "dkey": desc, "icon": "" })

## Traduce cada clave de una lista de opciones (mantiene el orden/índice).
func _tr_all(keys: Array) -> Array:
	var out: Array = []
	for k in keys:
		out.append(tr(str(k)))
	return out

func _row_set(label: String, desc: String) -> void:
	var cur: String = AssetSet.current()
	var idx: int = AssetSet.SETS.find(cur)
	if idx < 0:
		idx = AssetSet.SETS.find(AssetSet.DEFAULT)
	_specs.append({ "kind": "set", "label": tr(label), "lkey": label, "choices": AssetSet.SETS, "idx": idx,
			"applied": cur, "desc": tr(desc), "dkey": desc, "icon": "" })

## Fila de idioma: carrusel con bandera + nombre; ←→ cambia el idioma EN VIVO.
func _row_language() -> void:
	var cur: String = TranslationServer.get_locale().substr(0, 2)
	var idx: int = 0
	for i in range(LANGS.size()):
		if str(LANGS[i]["id"]) == cur:
			idx = i
			break
	_specs.append({ "kind": "language", "label": tr("LANGUAGE"), "lkey": "LANGUAGE",
			"idx": idx, "desc": tr("LANGUAGEDESC"), "dkey": "LANGUAGEDESC", "icon": "" })


# ── Construcción de la UI ─────────────────────────────────────────────────────
func _build_ui() -> void:
	# Fondo OPACO a pantalla completa (cubre el menú de debajo).
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

	# Layout con posiciones explícitas:
	#   · Título a la IZQUIERDA, encima del panel (bien separado).
	#   · Panel de opciones al 90% del ancho, centrado horizontal.
	#   · Descripción = barra negra a pantalla completa, pegada al fondo.
	var vp: Vector2 = get_viewport_rect().size
	var panel_w: float = vp.x * 0.9
	var left_x: float = (vp.x - panel_w) / 2.0
	var title_h: float = 150.0
	var title_y: float = 26.0
	var gap: float = 26.0                       # separación título ↔ opciones (panel un poco más arriba)
	var desc_h: float = 66.0                    # barra de descripción un poco más alta
	var opts_y: float = title_y + title_h + gap
	var opts_h: float = vp.y - opts_y - desc_h - 18.0

	var title := _build_title_panel()
	title.position = Vector2(left_x, title_y)
	add_child(title)

	# Botón "Controls" a la DERECHA del título, a su misma altura.
	add_child(_build_ctrl_button(left_x, title_y, title_h, panel_w))

	var opts := _build_options_panel(Vector2(panel_w, opts_h))
	opts.position = Vector2(left_x, opts_y)
	add_child(opts)

	add_child(_build_desc_bar(vp.x, desc_h))

	_sel = _first_selectable()


## Panel de título separado (menu_bg_white). TODO el panel (fondo + texto) a 0.8.
func _build_title_panel() -> Control:
	var root := Control.new()
	root.size = Vector2(780, 150)
	root.modulate.a = TITLE_ALPHA

	var np := _nine_patch(TITLE_BG)
	np.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(np)

	var lbl := Label.new()
	lbl.text = tr("CONFIG")
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_font_it(lbl, 96, COLOR_GOLD, 4)
	root.add_child(lbl)
	_title_lbl = lbl
	return root


## Botón "Controls" a la derecha del título (misma altura). Abre ControlsMenu al
## pulsar A cuando está enfocado (_sel == CTRL_SEL). Fondo menu_bg_base como el
## panel de opciones; mano + rótulo dorado al enfocarse.
func _build_ctrl_button(left_x: float, title_y: float, title_h: float, panel_w: float) -> Control:
	const TITLE_W := 780.0
	const GAPX := 24.0
	var x: float = left_x + TITLE_W + GAPX
	var w: float = panel_w - TITLE_W - GAPX
	var root := Control.new()
	root.position = Vector2(x, title_y)
	root.size = Vector2(w, title_h)

	var np := _nine_patch(PANEL_BG)
	np.self_modulate.a = PANEL_ALPHA
	np.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(np)

	var hand := TextureRect.new()
	hand.texture = load(AssetSet.p(HAND))
	hand.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	hand.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hand.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hand.size = Vector2(HAND_W * HAND_SCALE, HAND_H * HAND_SCALE)
	hand.position = Vector2(14, (title_h - HAND_H * HAND_SCALE) / 2.0)
	hand.visible = false
	root.add_child(hand)

	var lbl := Label.new()
	lbl.text = tr("CTRLBTN")
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_font_it(lbl, 56, COLOR_TEXT, 3)
	root.add_child(lbl)

	_ctrl_root = root
	_ctrl_hand = hand
	_ctrl_lbl = lbl
	return root


## Panel de opciones (menu_bg_base). SOLO el fondo a 0.7; el contenido a 1.0.
func _build_options_panel(panel_size: Vector2) -> Control:
	var root := Control.new()
	root.size = panel_size

	var np := _nine_patch(PANEL_BG)
	np.self_modulate.a = PANEL_ALPHA           # transparencia SOLO del fondo
	np.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(np)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for m in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(m, 28)
	root.add_child(margin)

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(_scroll)
	_rows_box = VBoxContainer.new()
	_rows_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows_box.add_theme_constant_override("separation", 5)
	_scroll.add_child(_rows_box)

	# Tira de iconos de settings (se asigna uno por opción, en orden).
	var isheet := AssetSet.p(SETTINGS_ICONS)
	if ResourceLoader.exists(isheet):
		_icon_sheet = load(isheet)
	_icon_i = 0
	for spec in _specs:
		_ui.append(_build_row(spec))
	return root


## Barra de descripción: panel negro (0.5) a pantalla completa, pegado al fondo.
func _build_desc_bar(full_w: float, h: float) -> Control:
	var bar := Control.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_top = -h
	bar.offset_bottom = 0
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.5)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bar.add_child(bg)
	_desc = Label.new()
	_desc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_desc.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_font_it(_desc, 32, COLOR_GOLD, 3)
	bar.add_child(_desc)
	return bar


## Fila 3-columnas: [mano+icono] [texto] [opciones]. null si es sección.
func _build_row(spec: Dictionary) -> Variant:
	if spec["kind"] == "section":
		var sec := Label.new()
		sec.text = str(spec["label"])
		_font_it(sec, 64, COLOR_GOLD_DIM, 3)
		var m := MarginContainer.new()
		m.add_theme_constant_override("margin_top", 6)
		m.add_child(sec)
		_rows_box.add_child(m)
		_sections.append({ "spec": spec, "lbl": sec })
		return null

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 4)
	hb.custom_minimum_size = Vector2(0, ROW_H)

	# Columna 0 (cursor): slot fijo con la mano, posicionada libremente (bob).
	var hand_slot := Control.new()
	hand_slot.custom_minimum_size = Vector2(HAND_SLOT_W, ROW_H)
	var hand := TextureRect.new()
	hand.texture = load(AssetSet.p(HAND))
	hand.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	hand.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hand.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hand.size = Vector2(HAND_W * HAND_SCALE, HAND_H * HAND_SCALE)
	hand.position = Vector2(0, (ROW_H - HAND_H * HAND_SCALE) / 2.0)
	hand.visible = false
	hand_slot.add_child(hand)
	hb.add_child(hand_slot)

	# Columna 1 (icono): recorte 16×16 de la tira settings_icons, en orden.
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(ICON_W, ROW_H)
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if _icon_sheet != null:
		var at := AtlasTexture.new()
		at.atlas = _icon_sheet
		at.region = Rect2(0, _icon_i * ICON_SRC, ICON_SRC, ICON_SRC)
		icon.texture = at
	_icon_i += 1
	hb.add_child(icon)

	# Columna 2 (texto).
	var lbl := Label.new()
	lbl.text = str(spec["label"])
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.custom_minimum_size = Vector2(TEXT_W, ROW_H)
	_font_it(lbl, 64, COLOR_TEXT, 3)
	hb.add_child(lbl)

	# Columna 3 (opciones).
	var value_box := HBoxContainer.new()
	# Barras de volumen (range): segmentos juntos (6). Palabras de opción
	# (enum/toggle/set): más separación para que no se peguen entre sí (24).
	value_box.add_theme_constant_override("separation", 6 if spec["kind"] == "range" else 24)
	value_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	hb.add_child(value_box)

	var row: Dictionary = { "spec": spec, "node": hb, "hand": hand, "label": lbl,
			"choices": [], "segments": [] }

	if spec["kind"] == "range":
		for i in range(10):
			var seg := ColorRect.new()
			seg.custom_minimum_size = Vector2(30, 22)
			var wrap := CenterContainer.new()
			wrap.custom_minimum_size = Vector2(30, ROW_H)
			wrap.add_child(seg)
			value_box.add_child(wrap)
			row["segments"].append(seg)
	elif spec["kind"] == "language":
		# Carrusel de idioma: [◄] bandera nombre [►] (las flechas son rótulos).
		var la := Label.new()
		la.text = "<"
		la.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		la.custom_minimum_size = Vector2(0, ROW_H)
		_font_it(la, 64, COLOR_GOLD, 3)
		value_box.add_child(la)
		var flag := TextureRect.new()
		flag.custom_minimum_size = Vector2(FLAG_W, ROW_H)
		flag.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		flag.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		flag.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		value_box.add_child(flag)
		var nm := Label.new()
		nm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		nm.custom_minimum_size = Vector2(0, ROW_H)
		_font_it(nm, 64, COLOR_TEXT, 3)
		value_box.add_child(nm)
		var ra := Label.new()
		ra.text = ">"
		ra.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		ra.custom_minimum_size = Vector2(0, ROW_H)
		_font_it(ra, 64, COLOR_GOLD, 3)
		value_box.add_child(ra)
		row["flag"] = flag
		row["lang_lbl"] = nm
	else:
		# Carrusel genérico (enum/toggle/set): [◄] valor [►]. Solo se muestra UNA
		# opción a la vez → nunca desborda aunque haya muchas o muy largas.
		var la := Label.new()
		la.text = "<"
		la.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		la.custom_minimum_size = Vector2(0, ROW_H)
		_font_it(la, 64, COLOR_GOLD, 3)
		value_box.add_child(la)
		var vl := Label.new()
		vl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		vl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vl.custom_minimum_size = Vector2(300, ROW_H)
		_font_it(vl, 64, COLOR_DIM, 3)
		value_box.add_child(vl)
		var ra := Label.new()
		ra.text = ">"
		ra.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		ra.custom_minimum_size = Vector2(0, ROW_H)
		_font_it(ra, 64, COLOR_GOLD, 3)
		value_box.add_child(ra)
		row["value_lbl"] = vl

	_rows_box.add_child(hb)
	return row


# ── Helpers de estilo ─────────────────────────────────────────────────────────
func _nine_patch(path: String) -> NinePatchRect:
	var np := NinePatchRect.new()
	np.texture = load(AssetSet.p(path))
	np.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	np.patch_margin_left = PATCH
	np.patch_margin_right = PATCH
	np.patch_margin_top = PATCH
	np.patch_margin_bottom = PATCH
	return np


func _font_it(lbl: Label, size: int, color: Color, outline: int) -> void:
	if _font != null:
		lbl.add_theme_font_override("font", _font)
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", COLOR_OUTLINE)
	lbl.add_theme_constant_override("outline_size", outline)


# ── Bob lateral del cursor ────────────────────────────────────────────────────
func _process(delta: float) -> void:
	_bob_t += delta
	if _sel == CTRL_SEL:
		if _ctrl_hand != null:
			_ctrl_hand.position.x = 14.0 + sin(_bob_t * 7.0) * 4.0
	elif _sel >= 0 and _sel < _ui.size() and _ui[_sel] != null:
		var hand = _ui[_sel]["hand"]
		hand.position.x = 4.0 + sin(_bob_t * 7.0) * 4.0


# ── Refresco visual ───────────────────────────────────────────────────────────
func _refresh() -> void:
	# Botón "Controls" (arriba): enfocado con _sel == CTRL_SEL.
	var ctrl_focused: bool = (_sel == CTRL_SEL)
	if _ctrl_hand != null:
		_ctrl_hand.visible = ctrl_focused
	if _ctrl_lbl != null:
		_ctrl_lbl.add_theme_color_override("font_color", COLOR_GOLD if ctrl_focused else COLOR_TEXT)
	if ctrl_focused:
		_desc.text = tr("CTRLBTNDESC")
		if _scroll != null:
			_scroll.scroll_vertical = 0
	for i in range(_specs.size()):
		var row = _ui[i]
		if row == null:
			continue
		var focused: bool = (i == _sel)
		row["hand"].visible = focused
		row["label"].add_theme_color_override("font_color", COLOR_GOLD if focused else COLOR_TEXT)
		var spec: Dictionary = row["spec"]
		if spec["kind"] == "range":
			var filled: int = int(spec["value"]) / 10
			var segs: Array = row["segments"]
			for s in range(segs.size()):
				segs[s].color = SEG_ON if s < filled else SEG_OFF
		elif spec["kind"] == "language":
			var lang: Dictionary = LANGS[int(spec["idx"])]
			row["lang_lbl"].text = str(lang["name"])
			row["lang_lbl"].add_theme_color_override("font_color", COLOR_GOLD if focused else COLOR_TEXT)
			var fp := AssetSet.p(FLAGS + str(lang["id"]) + ".png")
			if ResourceLoader.exists(fp):
				row["flag"].texture = load(fp)
		else:
			# Carrusel: solo el valor activo, resaltado si la fila está enfocada.
			var vl = row.get("value_lbl", null)
			if vl != null:
				var chs: Array = spec["choices"]
				var ci: int = clampi(int(spec["idx"]), 0, chs.size() - 1)
				vl.text = str(chs[ci])
				vl.add_theme_color_override("font_color", COLOR_GOLD if focused else COLOR_TEXT)
	if _sel >= 0 and _sel < _specs.size():
		_desc.text = str(_specs[_sel].get("desc", ""))
		# En la fila más alta, resetear el scroll al tope para que se vea el
		# título de la sección (si no, quedaría irremediablemente oculto).
		if _sel == _first_selectable():
			_scroll.scroll_vertical = 0
		elif _ui[_sel] != null and _scroll != null:
			_scroll.ensure_control_visible(_ui[_sel]["node"])


# ── Input ─────────────────────────────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_close()
		_handled()
	elif event.is_action_pressed("ui_up"):
		# Desde la primera fila, ↑ sube al botón "Controls" (arriba del todo).
		var prev_up: int = _sel
		if _sel != CTRL_SEL and _sel == _first_selectable():
			_sel = CTRL_SEL
		elif _sel != CTRL_SEL:
			_sel = _step_selectable(_sel, -1)
		if _sel != prev_up:
			_play_sfx(SFX_NAV)
		_refresh()
		_handled()
	elif event.is_action_pressed("ui_down"):
		var prev_dn: int = _sel
		if _sel == CTRL_SEL:
			_sel = _first_selectable()
		else:
			_sel = _step_selectable(_sel, 1)
		if _sel != prev_dn:
			_play_sfx(SFX_NAV)
		_refresh()
		_handled()
	elif event.is_action_pressed("ui_left"):
		if _sel != CTRL_SEL:
			_play_sfx(SFX_CHANGE)
			_change(-1)
		_handled()
	elif event.is_action_pressed("ui_right"):
		if _sel != CTRL_SEL:
			_play_sfx(SFX_CHANGE)
			_change(1)
		_handled()
	elif event.is_action_pressed("ui_accept"):
		if _sel == CTRL_SEL:
			_open_controls()
		_handled()


func _handled() -> void:
	get_viewport().set_input_as_handled()


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


## Abre el submenú de remapeo de controles como overlay hijo. Mientras está
## abierto, este menú ignora la entrada (la maneja el submenú).
func _open_controls() -> void:
	var cm := ControlsMenu.new()
	add_child(cm)
	set_process_input(false)
	cm.controls_closed.connect(func(): set_process_input(true))


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
			# Carrusel circular.
			var n_enum: int = spec["choices"].size()
			spec["idx"] = (int(spec["idx"]) + delta + n_enum) % n_enum
			_store(spec["section"], spec["key"], int(spec["idx"]))
			# Pantalla EN VIVO: modo de ventana y resolución se aplican al instante.
			if spec["key"] == "window_mode":
				_apply_window_mode(int(spec["idx"]))
			elif spec["key"] == "resolution":
				_apply_resolution(int(spec["idx"]))
		"toggle":
			# Carrusel circular (On/Off).
			var n_tog: int = spec["choices"].size()
			spec["idx"] = (int(spec["idx"]) + delta + n_tog) % n_tog
			_store(spec["section"], spec["key"], int(spec["idx"]) == 0)
			if spec["key"] == "mouse":
				InputConfig.set_mouse_enabled(int(spec["idx"]) == 0)
		"language":
			# Carrusel circular; aplica y persiste el idioma EN VIVO.
			var n: int = LANGS.size()
			spec["idx"] = (int(spec["idx"]) + delta + n) % n
			FadeCanvas.save_locale(str(LANGS[int(spec["idx"])]["id"]))
			_relocalize()
		"set":
			# Carrusel circular; el set gráfico se aplica al reiniciar (avisa).
			var n_set: int = spec["choices"].size()
			var new_idx: int = (int(spec["idx"]) + delta + n_set) % n_set
			if new_idx != int(spec["idx"]):
				spec["idx"] = new_idx
				var chosen: String = str(spec["choices"][new_idx])
				AssetSet.save(chosen)
				if chosen != str(spec["applied"]):
					_show_restart_notice(tr("QSETNOTICE") % chosen)
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


## Reproduce un SFX (bus "SFX" si existe). name = nombre sin extensión.
func _play_sfx(sfx_name: String) -> void:
	if _sfx == null:
		_sfx = AudioStreamPlayer.new()
		if AudioServer.get_bus_index("SFX") >= 0:
			_sfx.bus = "SFX"
		add_child(_sfx)
	var path := AssetSet.p("res://assets/sfx/%s.ogg" % sfx_name)
	if not ResourceLoader.exists(path):
		return
	_sfx.stream = load(path)
	_sfx.play()


## Índice de resolución activo (para reaplicar el tamaño al cambiar de modo).
func _res_idx() -> int:
	for s in _specs:
		if str(s.get("key", "")) == "resolution":
			return int(s["idx"])
	return 2


## Modo de ventana EN VIVO: 0 Windowed · 1 Borderless · 2 Fullscreen. Al volver a
## modo ventana se reaplica el tamaño de la resolución activa (para no quedar con
## el tamaño de pantalla completa).
func _apply_window_mode(idx: int) -> void:
	match idx:
		1:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
			_apply_resolution(_res_idx())
		2:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		_:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			_apply_resolution(_res_idx())


## Resolución EN VIVO: redimensiona y recentra la ventana. En pantalla completa
## no tiene efecto visible (se guarda igual y se aplicará al salir de fullscreen).
func _apply_resolution(idx: int) -> void:
	if idx < 0 or idx >= RESOLUTIONS.size():
		return
	var parts := str(RESOLUTIONS[idx]).split("x")
	if parts.size() != 2:
		return
	var w := int(parts[0])
	var h := int(parts[1])
	if w <= 0 or h <= 0:
		return
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		return
	DisplayServer.window_set_size(Vector2i(w, h))
	var scr := DisplayServer.window_get_current_screen()
	var scr_pos := DisplayServer.screen_get_position(scr)
	var scr_size := DisplayServer.screen_get_size(scr)
	DisplayServer.window_set_position(scr_pos + (scr_size - Vector2i(w, h)) / 2)


## Re-traduce en vivo todos los textos ya construidos (al cambiar de idioma).
func _relocalize() -> void:
	if _title_lbl != null:
		_title_lbl.text = tr("CONFIG")
	if _ctrl_lbl != null:
		_ctrl_lbl.text = tr("CTRLBTN")
	for s in _sections:
		s["lbl"].text = tr(str(s["spec"]["skey"]))
	for i in range(_specs.size()):
		var spec: Dictionary = _specs[i]
		var row = _ui[i]
		if row == null:
			continue
		if spec.has("lkey"):
			spec["label"] = tr(str(spec["lkey"]))
			row["label"].text = str(spec["label"])
		if spec.has("dkey"):
			spec["desc"] = tr(str(spec["dkey"]))
		if spec.has("ckeys"):
			# Solo re-traduce el modelo; el carrusel repinta su valor en _refresh.
			spec["choices"] = _tr_all(spec["ckeys"])
	_refresh()


## Panel modal genérico de "se aplicará al reiniciar" con el mensaje dado.
## Mientras está abierto, este menú DEJA de procesar input (si no, _input
## consumiría todo y el botón OK nunca recibiría el foco/confirmación).
func _show_restart_notice(msg_text: String) -> void:
	set_process_input(false)
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
	msg.text = msg_text
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_font_it(msg, 22, COLOR_TEXT, 3)
	box.add_child(msg)
	var ok := Button.new()
	ok.text = "OK"
	ok.add_theme_font_size_override("font_size", 22)
	ok.add_theme_color_override("font_color", COLOR_TEXT)
	ok.add_theme_color_override("font_focus_color", COLOR_GOLD)
	# Al cerrar: libera el modal y DEVUELVE el input a este menú.
	ok.pressed.connect(func() -> void:
		layer.queue_free()
		set_process_input(true))
	box.add_child(ok)
	# grab_focus diferido: el botón debe estar ya en el árbol para recibir foco.
	ok.grab_focus.call_deferred()


func _close() -> void:
	if get_tree().current_scene == self:
		FadeCanvas.change_scene_to_file("res://Scenes/main_menu.tscn")
	else:
		options_closed.emit()
		queue_free()
