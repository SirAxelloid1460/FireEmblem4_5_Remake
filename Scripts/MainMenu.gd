extends Control
class_name MainMenu

# ============================================================
# MAIN MENU — estilo Fire Emblem, recreado desde cero
# ============================================================
# Flujo (dirigido por foco; soporta teclado/mando Y ratón):
#   PRESS START  → (accept/click) →  MAIN
#   MAIN:  New Game · Continue · Extras
#       New Game → NEWGAME (Normal / Elite + descripción) → inicia Prólogo
#       Extras   → EXTRAS  (Options · Credits · Sound Room)
#   B/cancel retrocede en cada nivel.
#
# Animaciones: columnas que se DESLIZAN al entrar, fundidos (fade rect),
# cursor (►) que sigue al botón con foco, "PRESS START" parpadeante.
# Autocontenido: no depende de autoloads externos. Construido por código,
# así que la escena .tscn solo necesita el nodo raíz con este script.
#
# Ganchos pendientes (cuando haya arte/audio): logo, fondo animado, SFX.
# ============================================================

# ----------------------- PALETA / ESTILO --------------------
const COLOR_BG_TOP   := Color(0.04, 0.05, 0.12, 1.0)
const COLOR_BG_BOT   := Color(0.10, 0.08, 0.20, 1.0)
const COLOR_GOLD     := Color(1.00, 0.84, 0.36, 1.0)
const COLOR_GOLD_DIM := Color(0.70, 0.60, 0.30, 1.0)
const COLOR_TEXT     := Color(0.95, 0.95, 0.90, 1.0)
const COLOR_DIM      := Color(0.62, 0.64, 0.74, 1.0)
const COLOR_OUTLINE  := Color(0.0, 0.0, 0.0, 1.0)
const COLOR_PANEL    := Color(0.07, 0.08, 0.17, 0.90)

const SIZE_TITLE := 64
const SIZE_SUB   := 22
const SIZE_BTN   := 26
const SIZE_DESC  := 18
const OUTLINE_PX := 5

const TITLE_MAIN := "FIRE EMBLEM"
const TITLE_SUB  := "Genealogy of the Holy War   ·   Thracia 776"
const GAME_SCENE := "res://Scenes/main_game.tscn"
const CREDITS_SCRIPT := "res://Scripts/CreditsScreen.gd"

# Música de fondo del menú: el tema principal de Fire Emblem, en bucle.
const THEME_MUSIC := "res://assets/music/102 - Fire Emblem Theme.ogg"

# Arte del título por MODO (GameMode autoload: FE4_ONLY=0, FE5_ONLY=1, SAGA=2).
# El fondo y el logo cambian según la versión elegida en el menú de modo.
const TITLE_BG       := "res://assets/title/title1_background.png"   # fallback FE4
const LOGO           := "res://assets/title/logo1.png"               # fallback FE4
const BG_FE4  := "res://assets/panoramas/title_background_FE4.png"
const BG_FE5  := "res://assets/panoramas/title_background_FE5.png"
const BG_SAGA := "res://assets/panoramas/title_background_SAGA.png"
const LOGO_FE4 := "res://assets/title/logo1.png"    # Genealogy of the Holy War
const LOGO_FE5 := "res://assets/title/logo2.png"    # Thracia 776
const PRESS_START_IMG := "res://assets/sprites/press_start.png"
const PRESS_FRAMES   := 8
const PRESS_SCALE    := 5

# Modo DEMO / attract: tras AFK_SECONDS sin input en el menú, reproduce el vídeo
# de demo ENCIMA de todo (sin parar la música); cualquier input lo corta.
const AFK_SECONDS := 15.0
const DEMO_DIR    := "res://assets/videos/"

# UI de botones estilo FE: placa ornamentada individual + cursor-espada.
const PLATE      := "res://assets/menus/title_menu_dark.png"           # placa normal
const PLATE_HL   := "res://assets/menus/title_menu_dark_highlight.png" # placa enfocada
const SWORD      := "res://assets/menus/cursor_dragon.png"             # cursor-espada
const SERIF_FONT := "res://assets/fonts/IMFellFrenchCanonSC-Regular.ttf"

# SFX del menú (ver assets/sfx/). Navegación al cambiar de foco, confirmación al
# avanzar, cancelación al retroceder, error en acciones no disponibles.
const SFX_NAV     := "Select 5"
const SFX_CONFIRM := "Select 4"
const SFX_CANCEL  := "Step Back 1"
const SFX_ERROR   := "Error"
const SOUNDROOM_SCRIPT := "res://Scripts/SoundRoom.gd"
const BTN_W := 620
const BTN_H := 110
const BTN_FONT := 54
const SWORD_SCALE := 4
const COLOR_BTN := Color(0.95, 0.93, 0.85, 1.0)   # crema (texto de botón)
# Bobeo del cursor estilo GBA: ESCALONADO (no fluido), pero con escalones más
# pequeños (8px) para que sea un pelo más fluido. ±24 px de recorrido.
const CURSOR_BOB_SEQ := [0, 8, 16, 24, 16, 8, 0, -8, -16, -24, -16, -8]
const CURSOR_STEP_TIME := 0.086   # s por escalón (bobeo ~10% más lento)

const COL_WIDTH := 380.0
const SLIDE_TIME := 0.28
const FADE_TIME  := 0.30

# Descripciones de dificultad (de translations.json de los .ltproj)
const DESC_NORMAL := "Base SNES difficulty + balance fixes due to GBA mechanics."
const DESC_ELITE  := "Base SNES difficulty without balance fixes. For veterans."

# ----------------------- ESTADO -----------------------------
enum St { PRESS_START, MAIN, NEWGAME, EXTRAS }
var _state: int = St.PRESS_START
var _busy: bool = false                       # bloquea input durante transiciones

var _music: AudioStreamPlayer
var _bg: ColorRect            # gradiente (fallback si falta la imagen de fondo)
var _bg_img: TextureRect      # fondo del título (ilustración del ejército)
var _title: TextureRect       # logo del juego
var _subtitle: Label          # ya no se usa (el logo trae subtítulo); inerte
var _press: TextureRect       # "Press Start" animado
var _press_frame: int = 0
var _press_dir: int = 1
var _press_accum: float = 0.0
var _fade: ColorRect
var _cursor: TextureRect          # cursor-espada FE (cursor_dragon)
var _cursor_target: Control = null         # botón enfocado al que sigue el cursor
var _cursor_base: Vector2 = Vector2.ZERO   # posición centrada (sin bobeo)
var _cursor_step: int = 0
var _cursor_step_accum: float = 0.0
var _desc: Label
var _toast_lbl: Label

var _main_col: VBoxContainer      # columna de placas (botones individuales)
var _newgame_col: VBoxContainer
var _extras_col: VBoxContainer

var _difficulty: String = "Normal"

var _sfx: AudioStreamPlayer                # reproductor de SFX del menú
var _skip_next_nav_sfx: bool = false       # evita el tick de navegación en el auto-foco al entrar a un panel

# Modo DEMO / attract.
var _idle_time: float = 0.0
var _demo_layer: CanvasLayer = null
var _demo_vp: VideoStreamPlayer = null


# ============================================================
# CONSTRUCCIÓN
# ============================================================
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_bg()
	_build_music()
	_build_title()
	# Niebla/nubes animada (misma que en los menús de arranque): va ENCIMA del
	# fondo y del logo, pero DEBAJO del "Press Start" y de los botones/cursor.
	# Su transparencia sutil (por luminancia) deja ver el logo y el fondo.
	add_child(TitleOverlay.new())
	_build_press_start()
	_build_columns()
	_build_cursor()
	_build_desc()
	_build_toast()
	_build_fade()

	_show_only(null)            # oculta columnas
	_press.visible = true       # el shimmer lo anima _process()

	# Sin fundido de entrada: el corte desde Intro es directo (sin fade). El _fade
	# sólo se usa en las transiciones internas del menú.
	_fade.modulate.a = 0.0


## Modo actual (GameMode autoload): FE4_ONLY=0, FE5_ONLY=1, SAGA_MODE=2.
func _mode() -> int:
	var gm := get_node_or_null("/root/GameMode")
	return int(gm.current_mode) if gm != null and "current_mode" in gm else 0


## Fondo del menú según el modo (con fallback a la ilustración FE4).
func _bg_path() -> String:
	var p := BG_FE4
	match _mode():
		1: p = BG_FE5
		2: p = BG_SAGA
	if not ResourceLoader.exists(p):
		p = TITLE_BG
	return p


## Logo del menú según el modo (Thracia en FE5; Genealogy en FE4/SAGA).
func _logo_path() -> String:
	var p := LOGO_FE5 if _mode() == 1 else LOGO_FE4
	return p if ResourceLoader.exists(p) else LOGO


func _build_bg() -> void:
	# Fondo del título por modo (ilustración escalada a pantalla, nearest).
	var bg_path := _bg_path()
	if ResourceLoader.exists(bg_path):
		_bg_img = TextureRect.new()
		_bg_img.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_bg_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		_bg_img.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_bg_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_bg_img.texture = load(bg_path)
		add_child(_bg_img)
		return
	# Fallback: gradiente procedural (si falta la imagen).
	_bg = ColorRect.new()
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = """
	shader_type canvas_item;
	uniform vec4 ctop : source_color;
	uniform vec4 cbot : source_color;
	void fragment() {
		vec4 base = mix(ctop, cbot, UV.y);
		float d = distance(UV, vec2(0.5));
		base.rgb = mix(base.rgb, vec3(0.0), smoothstep(0.5, 1.05, d) * 0.6);
		COLOR = base;
	}
	"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("ctop", COLOR_BG_TOP)
	mat.set_shader_parameter("cbot", COLOR_BG_BOT)
	_bg.material = mat
	add_child(_bg)


## Música de fondo: el tema de Fire Emblem en bucle (en el bus "Music" si existe,
## para que el volumen de Options lo controle).
func _build_music() -> void:
	if not ResourceLoader.exists(THEME_MUSIC):
		return
	_music = AudioStreamPlayer.new()
	var stream = load(THEME_MUSIC)
	if "loop" in stream:
		stream.loop = true        # bucle sin cortes (Ogg Vorbis)
	_music.stream = stream
	if AudioServer.get_bus_index("Music") >= 0:
		_music.bus = "Music"
	add_child(_music)
	_music.play()


func _build_title() -> void:
	# Logo del juego, superpuesto a pantalla completa (transparente deja ver el fondo).
	_title = TextureRect.new()
	_title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_title.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_title.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var logo_path := _logo_path()
	if ResourceLoader.exists(logo_path):
		_title.texture = load(logo_path)
	add_child(_title)
	# _subtitle ya no se usa (el logo incluye el subtítulo); label inerte oculto.
	_subtitle = Label.new()
	_subtitle.visible = false
	_subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_subtitle)


func _build_press_start() -> void:
	# "Press Start" animado (8 frames de 96×16 apilados; shimmer ping-pong).
	_press = TextureRect.new()
	_press.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_press.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_press.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if ResourceLoader.exists(PRESS_START_IMG):
		var at := AtlasTexture.new()
		at.atlas = load(PRESS_START_IMG)
		at.region = Rect2(0, 0, 96, 16)
		_press.texture = at
	var w := 96 * PRESS_SCALE
	var h := 16 * PRESS_SCALE
	_press.custom_minimum_size = Vector2(w, h)
	_press.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_press.offset_left = -w / 2.0
	_press.offset_right = w / 2.0
	_press.offset_top = -160 - h
	_press.offset_bottom = -160
	add_child(_press)


func _process(delta: float) -> void:
	_animate_press(delta)
	_animate_cursor(delta)
	_update_idle(delta)


## Cuenta la inactividad y lanza la demo tras AFK_SECONDS (salvo en submenús o
## si la demo ya está en marcha).
func _update_idle(delta: float) -> void:
	if _busy or _is_demo_playing():
		return
	_idle_time += delta
	if _idle_time >= AFK_SECONDS:
		_start_demo()


## Cualquier actividad reinicia el contador; si la demo está sonando, la corta
## (consumiendo el input para que no active además un botón del menú).
func _input(event: InputEvent) -> void:
	var active: bool = event is InputEventMouseMotion \
		or (event is InputEventKey and event.pressed and not event.echo) \
		or (event is InputEventMouseButton and event.pressed) \
		or (event is InputEventJoypadButton and event.pressed) \
		or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.5)
	if not active:
		return
	_idle_time = 0.0
	if _is_demo_playing():
		_stop_demo()
		get_viewport().set_input_as_handled()


func _is_demo_playing() -> bool:
	return _demo_vp != null and is_instance_valid(_demo_vp)


## Reproduce el vídeo de demo por ENCIMA de todo, SIN tocar la música del menú.
func _start_demo() -> void:
	var path := _resolve_demo_video()
	if path == "":
		_idle_time = 0.0   # sin vídeo de demo: no reintentar en bucle cerrado
		return
	_demo_layer = CanvasLayer.new()
	_demo_layer.layer = 128            # por encima de toda la UI del menú
	add_child(_demo_layer)
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_demo_layer.add_child(black)
	_demo_vp = VideoStreamPlayer.new()
	_demo_vp.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_demo_vp.expand = true
	_demo_vp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Muteado: la música del menú (que NO se detiene) sigue siendo el audio.
	_demo_vp.volume_db = -80.0
	_demo_vp.stream = load(path)
	_demo_vp.finished.connect(_stop_demo)
	_demo_layer.add_child(_demo_vp)
	_demo_vp.play()


## Corta la demo y vuelve al menú; reinicia la cuenta de inactividad.
func _stop_demo() -> void:
	if _demo_layer != null and is_instance_valid(_demo_layer):
		_demo_layer.queue_free()
	_demo_layer = null
	_demo_vp = null
	_idle_time = 0.0
	# Tras la demo (termine o se corte), volver a la pantalla de PRESS START.
	_goto(St.PRESS_START)


## Vídeo de demo por modo: FE4/SAGA usan fe4_demo (sin idioma); FE5 usa
## fe5_demo_{en,jp} (con idioma). Fallback a demo.ogv genérico.
func _resolve_demo_video() -> String:
	var candidates: Array = []
	if _mode() == 1:
		var lang := "jp" if TranslationServer.get_locale().begins_with("ja") else "en"
		candidates.append(DEMO_DIR + "fe5_demo_%s.ogv" % lang)
		candidates.append(DEMO_DIR + "fe5_demo_en.ogv")
	else:
		candidates.append(DEMO_DIR + "fe4_demo.ogv")
	candidates.append(DEMO_DIR + "demo.ogv")
	for p in candidates:
		if ResourceLoader.exists(p):
			return p
	return ""


## Anima el shimmer del "Press Start" (sólo cuando está visible).
func _animate_press(delta: float) -> void:
	if _press == null or not _press.visible:
		return
	var at := _press.texture as AtlasTexture
	if at == null:
		return
	_press_accum += delta
	if _press_accum < 0.07:          # ~14 fps, como el original
		return
	_press_accum = 0.0
	_press_frame += _press_dir
	if _press_frame >= PRESS_FRAMES - 1:
		_press_frame = PRESS_FRAMES - 1
		_press_dir = -1
	elif _press_frame <= 0:
		_press_frame = 0
		_press_dir = 1
	at.region = Rect2(0, _press_frame * 16, 96, 16)


## Bobeo vertical ESCALONADO (look GBA) + seguimiento del botón enfocado (para que
## la espada acompañe a la columna mientras se desliza, sin quedarse fuera de pantalla).
func _animate_cursor(delta: float) -> void:
	if _cursor == null or not _cursor.visible:
		return
	if _cursor_target != null and is_instance_valid(_cursor_target):
		_cursor_base = _cursor_base_for(_cursor_target)   # sigue al botón en vivo
	_cursor_step_accum += delta
	if _cursor_step_accum >= CURSOR_STEP_TIME:
		_cursor_step_accum -= CURSOR_STEP_TIME
		_cursor_step = (_cursor_step + 1) % CURSOR_BOB_SEQ.size()
	_cursor.global_position = _cursor_base + Vector2(0, CURSOR_BOB_SEQ[_cursor_step])


# --- Columnas de botones ---
func _build_columns() -> void:
	# "Continue" solo aparece si hay partida guardada (sin saves es ilógico).
	var main_items: Array = [{ "id": "newgame", "text": "New Game" }]
	if SaveSystem.has_save_file():
		main_items.append({ "id": "continue", "text": "Continue" })
	main_items.append({ "id": "extras", "text": "Extras" })
	_main_col = _make_column(main_items)
	_newgame_col = _make_column([
		{ "id": "normal", "text": "Normal" },
		{ "id": "elite",  "text": "Elite" },
	])
	_extras_col = _make_column([
		{ "id": "options",   "text": "Options" },
		{ "id": "credits",   "text": "Credits" },
		{ "id": "soundroom", "text": "Sound Room" },
	])


## Stylebox de placa FE (title_menu_dark, 136×24): se estira entera al tamaño del
## botón (sin 9-patch), que es el look deseado. content_margin sitúa el texto.
func _plate_sb(path: String) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = load(path)
	# La placa (title_menu_dark, 136×24) se estira entera al tamaño del botón:
	# es el look que se quería (sin 9-patch). content_margin sitúa el texto.
	sb.content_margin_left = 40
	sb.content_margin_right = 40
	sb.content_margin_top = 12
	sb.content_margin_bottom = 16
	return sb


func _make_column(items: Array) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	col.visible = false
	add_child(col)
	for it in items:
		col.add_child(_make_button(str(it["text"]), str(it["id"])))
	return col


func _make_button(text: String, id: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(BTN_W, BTN_H)
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Fuente serif estilo logo (small-caps).
	var f := load(SERIF_FONT)
	if f != null:
		b.add_theme_font_override("font", f)
	b.add_theme_font_size_override("font_size", BTN_FONT)
	b.add_theme_color_override("font_color", COLOR_BTN)
	b.add_theme_color_override("font_focus_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_outline_color", COLOR_OUTLINE)
	b.add_theme_constant_override("outline_size", OUTLINE_PX + 1)
	# Fondo = placa ornamentada; enfocada/hover => versión highlight.
	b.add_theme_stylebox_override("normal", _plate_sb(PLATE))
	b.add_theme_stylebox_override("hover", _plate_sb(PLATE_HL))
	b.add_theme_stylebox_override("focus", _plate_sb(PLATE_HL))
	b.add_theme_stylebox_override("pressed", _plate_sb(PLATE_HL))
	b.set_meta("id", id)
	b.pressed.connect(_on_button_pressed.bind(id))
	b.focus_entered.connect(_on_button_focus.bind(b, id))
	b.mouse_entered.connect(b.grab_focus)
	return b


func _build_cursor() -> void:
	_cursor = TextureRect.new()
	_cursor.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_cursor.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(SWORD):
		_cursor.texture = load(SWORD)
	_cursor.size = Vector2(32 * SWORD_SCALE, 28 * SWORD_SCALE)
	_cursor.visible = false
	add_child(_cursor)


func _build_desc() -> void:
	# Descripción de dificultad (solo en NEWGAME), en un recuadro FE para legibilidad.
	_desc = Label.new()
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_desc.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_desc.add_theme_font_size_override("font_size", 24)
	_desc.add_theme_color_override("font_color", COLOR_TEXT)
	_desc.add_theme_color_override("font_outline_color", COLOR_OUTLINE)
	_desc.add_theme_constant_override("outline_size", OUTLINE_PX - 1)
	# Recuadro de fondo: panel oscuro semitransparente con borde dorado tenue.
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.06, 0.11, 0.85)
	sb.set_border_width_all(2)
	sb.border_color = COLOR_GOLD_DIM
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	_desc.add_theme_stylebox_override("normal", sb)
	_desc.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_desc.offset_left = 180
	_desc.offset_right = -180
	_desc.offset_top = -132
	_desc.offset_bottom = -48
	_desc.visible = false
	add_child(_desc)


func _build_toast() -> void:
	_toast_lbl = Label.new()
	_toast_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_lbl.add_theme_font_size_override("font_size", SIZE_DESC)
	_toast_lbl.add_theme_color_override("font_color", COLOR_GOLD)
	_toast_lbl.add_theme_color_override("font_outline_color", COLOR_OUTLINE)
	_toast_lbl.add_theme_constant_override("outline_size", OUTLINE_PX - 1)
	_toast_lbl.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_toast_lbl.offset_top = -44
	_toast_lbl.offset_bottom = -16
	_toast_lbl.modulate.a = 0.0
	add_child(_toast_lbl)


func _build_fade() -> void:
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)


# ============================================================
# NAVEGACIÓN / INPUT
# ============================================================
func _unhandled_input(event: InputEvent) -> void:
	if _busy:
		return
	if _state == St.PRESS_START:
		if event.is_action_pressed("ui_accept") or _is_confirm_click(event):
			_play_sfx(SFX_CONFIRM)
			_goto(St.MAIN)
		return
	if event.is_action_pressed("ui_cancel"):
		_on_cancel()


func _is_confirm_click(event: InputEvent) -> bool:
	return event is InputEventMouseButton and event.pressed \
		and event.button_index == MOUSE_BUTTON_LEFT


func _on_cancel() -> void:
	match _state:
		St.MAIN:
			_play_sfx(SFX_CANCEL)
			_goto(St.PRESS_START)
		St.NEWGAME, St.EXTRAS:
			_play_sfx(SFX_CANCEL)
			_goto(St.MAIN)


func _on_button_pressed(id: String) -> void:
	if _busy:
		return
	match id:
		"newgame":   _play_sfx(SFX_CONFIRM); _goto(St.NEWGAME)
		"extras":    _play_sfx(SFX_CONFIRM); _goto(St.EXTRAS)
		"continue":  _play_sfx(SFX_ERROR);   _toast("Continue — coming soon")
		"options":   _play_sfx(SFX_CONFIRM); _open_options()
		"soundroom": _play_sfx(SFX_CONFIRM); _open_soundroom()
		"credits":   _play_sfx(SFX_CONFIRM); _open_credits()
		"normal":    _play_sfx(SFX_CONFIRM); _start_game("Normal")
		"elite":     _play_sfx(SFX_CONFIRM); _start_game("Elite")


func _on_button_focus(b: Button, id: String) -> void:
	_move_cursor_to(b)
	# Tick de navegación, salvo el auto-foco al entrar a un panel (evita el doble
	# sonido con el de confirmación que disparó la transición).
	if _skip_next_nav_sfx:
		_skip_next_nav_sfx = false
	else:
		_play_sfx(SFX_NAV)
	if _state == St.NEWGAME:
		_desc.text = DESC_NORMAL if id == "normal" else DESC_ELITE


## Reproduce un SFX del menú (en el bus "SFX" si existe). name = nombre sin ext.
func _play_sfx(sfx_name: String) -> void:
	if _sfx == null:
		_sfx = AudioStreamPlayer.new()
		if AudioServer.get_bus_index("SFX") >= 0:
			_sfx.bus = "SFX"
		add_child(_sfx)
	var path := "res://assets/sfx/%s.ogg" % sfx_name
	if not ResourceLoader.exists(path):
		return
	_sfx.stream = load(path)
	_sfx.play()


## Posición base (centrada) del cursor para un botón, a su izquierda.
func _cursor_base_for(b: Control) -> Vector2:
	var sw := 32 * SWORD_SCALE
	var sh := 28 * SWORD_SCALE
	return Vector2(b.global_position.x - sw + 24, b.global_position.y + (b.size.y - sh) * 0.5)


func _move_cursor_to(b: Control) -> void:
	if b == null or not is_instance_valid(b):
		_cursor.visible = false
		_cursor_target = null
		return
	_cursor.visible = true
	_cursor_target = b           # _animate_cursor lo sigue en vivo (durante el slide)
	_cursor_step = 0
	_cursor_step_accum = 0.0
	_cursor_base = _cursor_base_for(b)
	_cursor.global_position = _cursor_base


# ============================================================
# TRANSICIONES DE ESTADO
# ============================================================
## Navegación entre paneles del menú: SIN fade (sólo deslizan las columnas).
## El fade se reserva para las acciones terminales (ver _fade_to / _start_game / créditos).
func _goto(new_state: int) -> void:
	if _busy:
		return
	_state = new_state
	_apply_state()


## Fade del _fade rect a un alpha dado (await-able). Para acciones terminales.
func _fade_to(a: float) -> void:
	var t := create_tween()
	t.tween_property(_fade, "modulate:a", a, FADE_TIME)
	await t.finished


func _apply_state() -> void:
	var vw := get_viewport_rect().size.x
	var center_x := (vw - BTN_W) * 0.5
	match _state:
		St.PRESS_START:
			_show_only(null)
			_title.visible = true        # logo visible
			_press.visible = true
			_cursor.visible = false
		St.MAIN:
			_press.visible = false
			_title.visible = false       # tras Start el logo desaparece (sólo fondo)
			_show_only(_main_col)
			_slide_in(_main_col, -BTN_W - 240, center_x, 240)
			_focus_first(_main_col)
		St.NEWGAME:
			_show_only(_newgame_col)
			_desc.visible = true
			_slide_in(_newgame_col, vw + 80, center_x, 280)
			_focus_first(_newgame_col)
		St.EXTRAS:
			_show_only(_extras_col)
			_slide_in(_extras_col, vw + 80, center_x, 240)
			_focus_first(_extras_col)


func _show_only(keep: Control) -> void:
	for c in [_main_col, _newgame_col, _extras_col]:
		if c != null:
			c.visible = (c == keep)
	if keep == null:
		_cursor.visible = false
		_desc.visible = false


## Devuelve el primer botón de una columna (VBoxContainer > [Button...]).
func _first_button(col: Control) -> Control:
	if col != null and col.get_child_count() > 0 and col.get_child(0) is Control:
		return col.get_child(0)
	return null


func _slide_in(col: Control, from_x: float, to_x: float, y: float) -> void:
	col.position = Vector2(from_x, y)
	var t := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(col, "position:x", to_x, SLIDE_TIME)
	# El cursor sigue al botón en vivo (_animate_cursor), no hace falta recolocarlo.


func _focus_first(col: Control) -> void:
	_skip_next_nav_sfx = true   # el auto-foco no debe sonar como navegación manual
	var fb := _first_button(col)
	if fb != null:
		fb.grab_focus()
		return
	if col.get_child_count() > 0:
		var first := col.get_child(0)
		if first is Control:
			(first as Control).grab_focus()


# ============================================================
# ACCIONES
# ============================================================
func _start_game(difficulty: String) -> void:
	_difficulty = difficulty
	# Guardamos la dificultad en el autoload GameMode (si existe) para que el
	# runtime la lea; no rompe si GameMode no la usa todavía.
	var gm := get_node_or_null("/root/GameMode")
	if gm != null:
		gm.set_meta("difficulty", difficulty)
	_busy = true
	var t := create_tween()
	t.tween_property(_fade, "modulate:a", 1.0, FADE_TIME)
	await t.finished
	if ResourceLoader.exists(GAME_SCENE):
		get_tree().change_scene_to_file(GAME_SCENE)
	else:
		_busy = false
		var t2 := create_tween()
		t2.tween_property(_fade, "modulate:a", 0.0, FADE_TIME)
		_toast("No se encontró %s" % GAME_SCENE)


func _open_options() -> void:
	var opt := OptionsMenu.new()
	add_child(opt)
	_busy = true   # bloquea el menú mientras está abierto
	opt.options_closed.connect(func(): _busy = false)


func _open_credits() -> void:
	var scr := load(CREDITS_SCRIPT)
	if scr == null:
		_toast("Credits no disponible")
		return
	_busy = true
	await _fade_to(1.0)                       # fade a negro (transición a créditos)
	var credits = scr.new()
	add_child(credits)
	move_child(credits, _fade.get_index())   # créditos justo debajo del _fade
	if credits.has_signal("credits_finished"):
		credits.credits_finished.connect(_on_credits_done.bind(credits))
	if credits.has_method("show_credits"):
		credits.show_credits()
	await _fade_to(0.0)                       # revela los créditos


## Abre el Sound Room (overlay con fade). Pausa el tema del menú mientras está
## abierto y lo reanuda al cerrar.
func _open_soundroom() -> void:
	var scr := load(SOUNDROOM_SCRIPT)
	if scr == null:
		_toast("Sound Room no disponible")
		return
	_busy = true
	await _fade_to(1.0)                       # fade a negro
	if _music != null and _music.playing:
		_music.stream_paused = true           # silencia el tema del menú
	var room = scr.new()
	add_child(room)
	move_child(room, _fade.get_index())       # el room queda justo debajo del _fade
	if room.has_signal("closed"):
		room.closed.connect(_on_soundroom_done.bind(room))
	await _fade_to(0.0)                        # revela el Sound Room


func _on_soundroom_done(room) -> void:
	await _fade_to(1.0)
	if is_instance_valid(room):
		room.queue_free()
	if _music != null:
		_music.stream_paused = false          # reanuda el tema del menú
	await _fade_to(0.0)
	_busy = false


## Al terminar los créditos: fade a negro, quitarlos y fade de vuelta al menú.
func _on_credits_done(credits) -> void:
	await _fade_to(1.0)
	if is_instance_valid(credits):
		credits.queue_free()
	await _fade_to(0.0)
	_busy = false


func _toast(text: String) -> void:
	_toast_lbl.text = text
	_toast_lbl.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(_toast_lbl, "modulate:a", 1.0, 0.18)
	t.tween_interval(1.4)
	t.tween_property(_toast_lbl, "modulate:a", 0.0, 0.4)
