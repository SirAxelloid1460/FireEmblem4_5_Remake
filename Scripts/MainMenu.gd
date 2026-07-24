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

# UI de botones estilo FE: placa ornamentada individual + cursor-espada.
const PLATE      := "res://assets/menus/title_menu_dark.png"           # placa normal
const PLATE_HL   := "res://assets/menus/title_menu_dark_highlight.png" # placa enfocada
const SWORD      := "res://assets/menus/cursor_dragon.png"             # cursor-espada
const UI_FONT := "res://assets/fonts/bmp/text.fnt"   # sprite-font LT

# SFX del menú (ver assets/sfx/). Navegación al cambiar de foco, confirmación al
# avanzar, cancelación al retroceder, error en acciones no disponibles.
const SFX_NAV     := "Select 5"
const SFX_CONFIRM := "Select 4"
const SFX_CANCEL  := "Select 4"   # retroceder usa el MISMO sonido que avanzar
const SFX_ERROR   := "Error"
const SOUNDROOM_SCRIPT := "res://Scripts/SoundRoom.gd"
const BTN_W := 620
const BTN_H := 110
const BTN_FONT := 56   # sprite-font LT un poco más grande (cabe de sobra en BTN_W)
const SWORD_SCALE := 4
const COLOR_BTN := Color(0.95, 0.93, 0.85, 1.0)   # crema (texto de botón)
# Bobeo del cursor estilo GBA: ESCALONADO (no fluido), pero con escalones más
# pequeños (8px) para que sea un pelo más fluido. ±24 px de recorrido.
const CURSOR_BOB_SEQ := [0, 8, 16, 24, 16, 8, 0, -8, -16, -24, -16, -8]
const CURSOR_STEP_TIME := 0.086   # s por escalón (bobeo ~10% más lento)

const COL_WIDTH := 380.0
const SLIDE_TIME := 0.28
const FADE_TIME  := 0.30

# ── Dificultad (NEWGAME) ──────────────────────────────────────────────────────
# Placa tintada por dificultad + panel de descripción a la derecha (estilo imagen
# de referencia). Normal = tono calmado, Elite = tono duro.
const DIFF_BTN_W := 470
const DIFF_TINT := { "normal": Color(0.52, 0.86, 0.58), "elite": Color(0.92, 0.50, 0.52) }
const BOX_ORNATE := "res://assets/menus/menu_box_6x.png"   # panel ornamentado (desc / slots)
const SAVE_PANEL_BG := "res://assets/menus/menu_bg_white.png"  # panel de título/playtime del submenú

# ── Submenú de guardado (Continue / Load → "Resume Chapter") ──────────────────
const SAVE_SLOTS := 3
const SLOT_W := 740
const SLOT_H := 92
const SLOT_TINT_EMPTY := Color(0.48, 0.82, 0.56)   # verde: ranura vacía (-- NO DATA --)
const SLOT_TINT_DATA  := Color(0.90, 0.48, 0.54)   # rojo: ranura con partida

# ----------------------- ESTADO -----------------------------
enum St { PRESS_START, MAIN, NEWGAME, EXTRAS, SAVES }
var _state: int = St.PRESS_START
# Modo del submenú de guardado: "load" (con copiar/borrar) o "continue" (sin).
var _saves_mode: String = "load"
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
# Tamaño de frame REAL de la tira press_start, derivado de la textura (rejilla
# lógica: 1 col × PRESS_FRAMES filas). En GBA da 96×16; una tira HD 2× (192×32)
# se recorta bien sin tocar constantes.
var _press_fw: int = 96
var _press_fh: int = 16
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
var _desc_panel: Control          # panel de descripción (derecha) en NEWGAME
# Submenú de guardado ("Resume Chapter").
var _saves_root: Control          # raíz que se desliza (título + ranuras + chrome)
var _saves_col: VBoxContainer     # columna de ranuras de guardado
var _icon_copy: Control           # icono placeholder "copiar" (solo modo "load")
var _icon_erase: Control          # icono placeholder "borrar" (solo modo "load")

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

	# Si el ratón se (des)activa en Opciones (overlay), actualizar en vivo el
	# mouse_filter de los botones para que dejen/vuelvan a reaccionar al hover.
	InputConfig.mouse_toggled.connect(_on_mouse_toggled)

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
	p = AssetSet.p(p)   # re-enraíza al set gráfico activo (fallback GBA)
	if not ResourceLoader.exists(p):
		p = AssetSet.p(TITLE_BG)
	return p


## Logo del menú según el modo (Thracia en FE5; Genealogy en FE4/SAGA).
func _logo_path() -> String:
	var p := AssetSet.p(LOGO_FE5 if _mode() == 1 else LOGO_FE4)
	return p if ResourceLoader.exists(p) else AssetSet.p(LOGO)


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
	var music_path := AssetSet.p(THEME_MUSIC)
	if not ResourceLoader.exists(music_path):
		return
	_music = AudioStreamPlayer.new()
	var stream = load(music_path)
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
	var press_path := AssetSet.p(PRESS_START_IMG)
	if ResourceLoader.exists(press_path):
		var sheet: Texture2D = load(press_path)
		# Frame = ancho completo × (alto / PRESS_FRAMES). GBA: 96×16.
		if sheet.get_width() > 0:
			_press_fw = sheet.get_width()
			_press_fh = int(sheet.get_height() / float(PRESS_FRAMES))
		var at := AtlasTexture.new()
		at.atlas = sheet
		at.region = Rect2(0, 0, _press_fw, _press_fh)
		_press.texture = at
	# Tamaño en pantalla derivado del frame nativo GBA de referencia (96×16),
	# no del real: así una tira HD 2× se ve al MISMO tamaño (más nítida, no mayor).
	var k := float(_press_fw) / 96.0
	var w: float = (_press_fw / k) * PRESS_SCALE
	var h: float = (_press_fh / k) * PRESS_SCALE
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
	if _busy or _is_demo_active():
		return
	# La demo/attract SOLO arranca en Press Start o en el menú principal (donde se
	# elige New Game). En los submenús (New Game / Extras / Resume Chapter) no se
	# dispara: se resetea el contador.
	if _state != St.PRESS_START and _state != St.MAIN:
		_idle_time = 0.0
		return
	_idle_time += delta
	if _idle_time >= AFK_SECONDS:
		_start_demo()


## Cualquier actividad reinicia el contador; si la demo está activa (transición
## o reproducción), la corta (consumiendo el input para que no active un botón).
func _input(event: InputEvent) -> void:
	# Sólo cuenta como actividad una PULSACIÓN discreta (tecla, click o botón de
	# mando) con el juego en primer plano. El MOVIMIENTO del ratón (o del stick)
	# NO cuenta: no reinicia la inactividad ni corta la demo.
	# El click SOLO cuenta si el ratón está habilitado (con el ratón OFF no debe
	# cortar la demo ni contar como actividad).
	var active: bool = (event is InputEventKey and event.pressed and not event.echo) \
		or (InputConfig.mouse_enabled and event is InputEventMouseButton and event.pressed) \
		or (event is InputEventJoypadButton and event.pressed)
	if not active:
		return
	_idle_time = 0.0
	if _is_demo_active():
		_stop_demo()
		get_viewport().set_input_as_handled()


## Actualiza el mouse_filter de TODOS los botones al (des)activar el ratón.
func _on_mouse_toggled(on: bool) -> void:
	_set_buttons_mouse(self, on)

func _set_buttons_mouse(node: Node, on: bool) -> void:
	for c in node.get_children():
		if c is Button:
			(c as Button).mouse_filter = Control.MOUSE_FILTER_STOP if on else Control.MOUSE_FILTER_IGNORE
		_set_buttons_mouse(c, on)


func _is_demo_active() -> bool:
	return _demo_layer != null and is_instance_valid(_demo_layer)


## Entra a la demo con FUNDIDO, en este orden exacto:
##   Menú → fade-out (todo negro) → aparece el vídeo PAUSADO (1er frame) →
##   fade-in (se ve todo otra vez) → al COMPLETARSE el fade-in, arranca el vídeo.
## Va por encima de todo y no toca la música del menú.
func _start_demo() -> void:
	var path := _resolve_demo_video()
	if path == "":
		_idle_time = 0.0   # sin vídeo de demo: no reintentar en bucle cerrado
		return
	_demo_layer = CanvasLayer.new()
	_demo_layer.layer = 128            # por encima de toda la UI del menú
	add_child(_demo_layer)
	# Vídeo (oculto hasta el fade-in).
	_demo_vp = VideoStreamPlayer.new()
	_demo_vp.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_demo_vp.expand = true
	_demo_vp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Muteado: la música del menú (que NO se detiene) sigue siendo el audio.
	_demo_vp.volume_db = -80.0
	_demo_vp.stream = load(path)
	_demo_vp.visible = false
	_demo_vp.finished.connect(_stop_demo)
	_demo_layer.add_child(_demo_vp)
	# Cubierta negra para el fundido (empieza transparente, ENCIMA del vídeo).
	var cover := ColorRect.new()
	cover.color = Color(0, 0, 0, 0)
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_demo_layer.add_child(cover)
	# 1) Fade-out del menú: la cubierta se vuelve opaca.
	var t := create_tween()
	t.tween_property(cover, "color:a", 1.0, FADE_TIME)
	await t.finished
	if not _is_demo_active():
		return   # cortada por input durante el fundido
	# Pantalla en negro: fondo negro permanente DETRÁS del vídeo.
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_demo_layer.add_child(black)
	_demo_layer.move_child(black, 0)   # detrás del vídeo y de la cubierta
	# 2) El vídeo APARECE pero PAUSADO (congelado en el 1er frame), aún en negro.
	_demo_vp.visible = true
	_demo_vp.play()
	_demo_vp.paused = true
	# 3) Fade-in: se vuelve a ver todo (con el vídeo quieto en el 1er frame).
	var t2 := create_tween()
	t2.tween_property(cover, "color:a", 0.0, FADE_TIME)
	await t2.finished
	if not _is_demo_active():
		return   # cortada por input durante el fade-in
	if is_instance_valid(cover):
		cover.queue_free()
	# 4) Fade-in COMPLETADO: ahora sí arranca el vídeo.
	if _demo_vp != null and is_instance_valid(_demo_vp):
		_demo_vp.paused = false


## Corta la demo y vuelve al menú; reinicia la cuenta de inactividad.
func _stop_demo() -> void:
	if _demo_layer != null and is_instance_valid(_demo_layer):
		_demo_layer.queue_free()
	_demo_layer = null
	_demo_vp = null
	_idle_time = 0.0
	# Tras la demo (termine o se corte), volver a la pantalla de PRESS START.
	_goto(St.PRESS_START)


## Vídeo de demo en {mode}/demos/{mode}_demo_{idioma}.ogv (fe4 para FE4/SAGA,
## fe5 para FE5), con fallback al _en (ver VideoResolver).
func _resolve_demo_video() -> String:
	var m := "fe5" if _mode() == 1 else "fe4"
	return VideoResolver.localized(m, "demos")


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
	at.region = Rect2(0, _press_frame * _press_fh, _press_fw, _press_fh)


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
	# Menú principal: New Game · Continue · Load · Restart · Extras. El texto es la
	# CLAVE de traducción (los Button se auto-traducen con el locale activo).
	# NOTA: el sistema de guardado real aún NO existe; Continue/Load/Restart son de
	# momento solo la UI (deslizan al submenú o muestran aviso).
	_main_col = _make_column([
		{ "id": "newgame",  "text": "NEWGAME" },
		{ "id": "continue", "text": "CONTINUE" },
		{ "id": "load",     "text": "LOAD" },
		{ "id": "restart",  "text": "RESTART" },
		{ "id": "extras",   "text": "EXTRAS" },
	])
	# Dificultad: placas TINTADAS por dificultad y más estrechas (columna izquierda);
	# la descripción va en un panel a la derecha (_build_desc). Ver imagen de ref.
	_newgame_col = VBoxContainer.new()
	_newgame_col.add_theme_constant_override("separation", 16)
	_newgame_col.visible = false
	add_child(_newgame_col)
	_newgame_col.add_child(_make_button("NORMAL", "normal", DIFF_BTN_W, DIFF_TINT["normal"]))
	_newgame_col.add_child(_make_button("ELITE",  "elite",  DIFF_BTN_W, DIFF_TINT["elite"]))
	_extras_col = _make_column([
		{ "id": "options",   "text": "OPTIONS" },
		{ "id": "credits",   "text": "CREDITS" },
		{ "id": "soundroom", "text": "SOUNDROOM" },
	])
	_build_saves()


## Texto traducido con fallback legible: si la clave aún no está en el CSV
## (tr devuelve la propia clave), usa `fallback`. Para el submenú de guardado,
## cuyas claves las añadirá la sesión de traducción (ver docs/handoff/).
func _trd(key: String, fallback: String) -> String:
	var t: String = tr(key)
	return fallback if t == key else t


## Submenú "Resume Chapter" (Continue/Load). Se desliza como el resto del menú.
## Modo "load" muestra iconos de copiar/borrar; "continue" no. Sin sistema real
## de guardado todavía: las ranuras salen "-- NO DATA --".
func _build_saves() -> void:
	var vp: Vector2 = get_viewport_rect().size
	_saves_root = Control.new()
	# Tamaño = viewport, anclado arriba-izquierda: así se puede DESLIZAR en x
	# (los hijos van posicionados a mano dentro de esta raíz).
	_saves_root.size = vp
	_saves_root.visible = false
	add_child(_saves_root)

	# Título "Resume Chapter" (panel blanco, arriba centrado). Texto un poco más
	# grande, MISMO tamaño de panel (520×76).
	_saves_root.add_child(_titled_panel(_trd("RESUMECHAPTER", "Resume Chapter"),
			Vector2((vp.x - 520) / 2.0, 30), Vector2(520, 76), 50, COLOR_GOLD))
	# "R Info" arriba a la derecha: el glyph "R" se sustituye por la TECLA realmente
	# vinculada al botón R (acción ui_page_right), según el remapeo actual.
	var info_key: String = InputConfig.key_label("ui_page_right")
	var rinfo := _panel_label(info_key + "  " + _trd("INFO", "Info"), 40, COLOR_TEXT)
	rinfo.position = Vector2(vp.x - 340, 40)
	rinfo.size = Vector2(300, 56)
	rinfo.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_saves_root.add_child(rinfo)

	# Columna de ranuras (placas verdes "-- NO DATA --").
	_saves_col = VBoxContainer.new()
	_saves_col.add_theme_constant_override("separation", 14)
	_saves_col.position = Vector2((vp.x - SLOT_W) / 2.0, 150)
	_saves_root.add_child(_saves_col)
	for i in range(SAVE_SLOTS):
		_saves_col.add_child(_make_button(_trd("NODATA", "-- NO DATA --"),
				"slot%d" % i, SLOT_W, SLOT_TINT_EMPTY))

	# Panel PLAY TIME abajo-derecha (texto agrandado).
	_saves_root.add_child(_titled_panel(_trd("PLAYTIME", "PLAY TIME") + "   0:00.00",
			Vector2(vp.x - 420 - 40, vp.y - 96 - 40), Vector2(420, 96), 40, COLOR_GOLD))

	# Barra de INFO de acciones abajo-IZQUIERDA (lado opuesto al cursor-espada, que
	# apunta a la ranura enfocada): así los iconos copiar/borrar no quedan tapados
	# por el cursor. Solo visible en modo "load". Arte real pendiente.
	var iy: float = vp.y - 44 - 40
	_icon_copy = _action_info("C", _trd("COPY", "Copy"))
	_icon_copy.position = Vector2(40, iy)
	_icon_copy.visible = false
	_saves_root.add_child(_icon_copy)
	_icon_erase = _action_info("D", _trd("ERASE", "Erase"))
	_icon_erase.position = Vector2(40 + 250, iy)
	_icon_erase.visible = false
	_saves_root.add_child(_icon_erase)


## Panel ornamentado con un rótulo centrado (título/playtime del submenú).
func _titled_panel(text: String, pos: Vector2, sz: Vector2, fsize: int, color: Color) -> Control:
	var root := Control.new()
	root.position = pos
	root.size = sz
	var np := NinePatchRect.new()
	np.texture = load(AssetSet.p(SAVE_PANEL_BG))
	np.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for m in ["patch_margin_left", "patch_margin_right", "patch_margin_top", "patch_margin_bottom"]:
		np.set(m, 8)
	np.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(np)
	var lbl := _panel_label(text, fsize, color)
	lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(lbl)
	return root


## Rótulo con la sprite-font del menú (sin fondo). No intercepta el ratón.
func _panel_label(text: String, fsize: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var f := load(AssetSet.p(UI_FONT))
	if f != null:
		l.add_theme_font_override("font", f)
	l.add_theme_font_size_override("font_size", fsize)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", COLOR_OUTLINE)
	l.add_theme_constant_override("outline_size", OUTLINE_PX - 1)
	return l


## Icono placeholder 44×44 (recuadro + letra) hasta tener arte de copiar/borrar.
func _placeholder_icon(letter: String) -> Control:
	var c := Control.new()
	c.size = Vector2(44, 44)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := NinePatchRect.new()
	bg.texture = load(AssetSet.p("res://assets/menus/menu_bg_base.png"))
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for m in ["patch_margin_left", "patch_margin_right", "patch_margin_top", "patch_margin_bottom"]:
		bg.set(m, 8)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.add_child(bg)
	var l := _panel_label(letter, 26, COLOR_GOLD)
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.add_child(l)
	return c


## Muestra/oculta la barra de info de acciones (solo modo "load"). Su posición es
## fija (abajo-izquierda, ver _build_saves), no depende de la ranura enfocada.
func _position_slot_icons(_slot: Control) -> void:
	if _icon_copy == null:
		return
	var show: bool = (_state == St.SAVES and _saves_mode == "load")
	_icon_copy.visible = show
	_icon_erase.visible = show


## Info de acción: icono placeholder + rótulo (para la barra inferior del submenú
## de guardado). Devuelve un Control que agrupa ambos.
func _action_info(letter: String, text: String) -> Control:
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.size = Vector2(44 + 8 + 170, 44)
	var ic := _placeholder_icon(letter)
	root.add_child(ic)
	var l := _panel_label(text, 38, COLOR_TEXT)
	l.position = Vector2(44 + 8, 0)
	l.size = Vector2(170, 44)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	root.add_child(l)
	return root


## Stylebox de placa FE (title_menu_dark, 136×24): se estira entera al tamaño del
## botón (sin 9-patch), que es el look deseado. content_margin sitúa el texto.
func _plate_sb(path: String, tint: Color = Color.WHITE) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = load(AssetSet.p(path))
	# La placa (title_menu_dark, 136×24) se estira entera al tamaño del botón:
	# es el look que se quería (sin 9-patch). content_margin sitúa el texto.
	sb.content_margin_left = 40
	sb.content_margin_right = 40
	sb.content_margin_top = 12
	sb.content_margin_bottom = 16
	# Tinte de color de la placa (por dificultad / por ranura). Blanco = sin tinte.
	sb.modulate_color = tint
	return sb


func _make_column(items: Array) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	col.visible = false
	add_child(col)
	for it in items:
		col.add_child(_make_button(str(it["text"]), str(it["id"])))
	return col


func _make_button(text: String, id: String, width: float = BTN_W,
		tint: Color = Color.WHITE) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(width, BTN_H)
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.focus_mode = Control.FOCUS_ALL
	# Con el ratón OFF, IGNORE: el botón no reacciona al hover (ni cambia de placa)
	# ni al click. Se actualiza en vivo vía InputConfig.mouse_toggled (ver _ready).
	b.mouse_filter = Control.MOUSE_FILTER_STOP if InputConfig.mouse_enabled else Control.MOUSE_FILTER_IGNORE
	b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Fuente serif estilo logo (small-caps).
	var f := load(AssetSet.p(UI_FONT))
	if f != null:
		b.add_theme_font_override("font", f)
	b.add_theme_font_size_override("font_size", BTN_FONT)
	b.add_theme_color_override("font_color", COLOR_BTN)
	b.add_theme_color_override("font_focus_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_outline_color", COLOR_OUTLINE)
	b.add_theme_constant_override("outline_size", OUTLINE_PX + 1)
	# Fondo = placa ornamentada (tintada si `tint` != blanco); foco/hover => highlight.
	b.add_theme_stylebox_override("normal", _plate_sb(PLATE, tint))
	b.add_theme_stylebox_override("hover", _plate_sb(PLATE_HL, tint))
	b.add_theme_stylebox_override("focus", _plate_sb(PLATE_HL, tint))
	b.add_theme_stylebox_override("pressed", _plate_sb(PLATE_HL, tint))
	b.set_meta("id", id)
	b.pressed.connect(_on_button_pressed.bind(id))
	b.focus_entered.connect(_on_button_focus.bind(b, id))
	# Hover solo enfoca con el ratón habilitado (InputConfig no bloquea el
	# mouse_entered, que va por posición del viewport).
	b.mouse_entered.connect(func(): if InputConfig.mouse_enabled: b.grab_focus())
	return b


func _build_cursor() -> void:
	_cursor = TextureRect.new()
	_cursor.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_cursor.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sword_path := AssetSet.p(SWORD)
	if ResourceLoader.exists(sword_path):
		_cursor.texture = load(sword_path)
	_cursor.size = Vector2(32 * SWORD_SCALE, 28 * SWORD_SCALE)
	_cursor.visible = false
	add_child(_cursor)


func _build_desc() -> void:
	# Descripción de dificultad (solo en NEWGAME), en un panel ORNAMENTADO a la
	# DERECHA (la columna de dificultad va a la izquierda). Estilo imagen de ref.
	var vp: Vector2 = get_viewport_rect().size
	var pw: float = 540.0
	var ph: float = 330.0
	_desc_panel = Control.new()
	_desc_panel.size = Vector2(pw, ph)
	_desc_panel.position = Vector2(vp.x - pw - 80.0, (vp.y - ph) / 2.0)
	_desc_panel.visible = false
	add_child(_desc_panel)
	var np := NinePatchRect.new()
	np.texture = load(AssetSet.p(BOX_ORNATE))
	np.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	np.patch_margin_left = 14
	np.patch_margin_right = 14
	np.patch_margin_top = 22
	np.patch_margin_bottom = 22
	np.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_desc_panel.add_child(np)
	_desc = Label.new()
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Arranca arriba-izquierda del panel (no centrado) y con texto bastante mayor.
	_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_desc.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	var f := load(AssetSet.p(UI_FONT))
	if f != null:
		_desc.add_theme_font_override("font", f)
	_desc.add_theme_font_size_override("font_size", 48)
	_desc.add_theme_color_override("font_color", COLOR_TEXT)
	_desc.add_theme_color_override("font_outline_color", COLOR_OUTLINE)
	_desc.add_theme_constant_override("outline_size", OUTLINE_PX - 1)
	_desc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_desc.offset_left = 40
	_desc.offset_right = -40
	_desc.offset_top = 36
	_desc.offset_bottom = -36
	_desc_panel.add_child(_desc)


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
		St.NEWGAME, St.EXTRAS, St.SAVES:
			_play_sfx(SFX_CANCEL)
			_goto(St.MAIN)


func _on_button_pressed(id: String) -> void:
	if _busy:
		return
	# Ranuras del submenú de guardado (aún sin sistema real → aviso).
	if id.begins_with("slot"):
		_play_sfx(SFX_ERROR)
		_toast(_trd("NODATA", "-- NO DATA --"))
		return
	match id:
		"newgame":   _play_sfx(SFX_CONFIRM); _goto(St.NEWGAME)
		"extras":    _play_sfx(SFX_CONFIRM); _goto(St.EXTRAS)
		# Continue / Load abren el MISMO submenú; Load con copiar/borrar, Continue sin.
		"continue":  _play_sfx(SFX_CONFIRM); _open_saves("continue")
		"load":      _play_sfx(SFX_CONFIRM); _open_saves("load")
		# Restart (reiniciar capítulo): sin partida en curso desde el título → aviso.
		"restart":   _play_sfx(SFX_ERROR);   _toast(_trd("RESTARTNOGAME", "No chapter in progress"))
		"options":   _play_sfx(SFX_CONFIRM); _open_options()
		"soundroom": _play_sfx(SFX_CONFIRM); _open_soundroom()
		"credits":   _play_sfx(SFX_CONFIRM); _open_credits()
		"normal":    _play_sfx(SFX_CONFIRM); _start_game("Normal")
		"elite":     _play_sfx(SFX_CONFIRM); _start_game("Elite")


## Abre el submenú de guardado en el modo dado ("load" con copiar/borrar; "continue" sin).
func _open_saves(mode: String) -> void:
	_saves_mode = mode
	_goto(St.SAVES)


func _on_button_focus(b: Button, id: String) -> void:
	_move_cursor_to(b)
	# Tick de navegación, salvo el auto-foco al entrar a un panel (evita el doble
	# sonido con el de confirmación que disparó la transición).
	if _skip_next_nav_sfx:
		_skip_next_nav_sfx = false
	else:
		_play_sfx(SFX_NAV)
	if _state == St.NEWGAME:
		# Claves de la tabla de traducción (localizadas en los 5 idiomas).
		_desc.text = tr("NORMALDESC") if id == "normal" else tr("ELITEDESC")
	elif _state == St.SAVES:
		# Iconos copiar/borrar flanqueando la ranura enfocada (solo modo "load").
		_position_slot_icons(b)


## Reproduce un SFX del menú (en el bus "SFX" si existe). name = nombre sin ext.
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
	var vh := get_viewport_rect().size.y
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
			# 5 botones (New Game·Continue·Load·Restart·Extras): centrar en vertical.
			var main_h: float = 5 * BTN_H + 4 * 16
			_slide_in(_main_col, -BTN_W - 240, center_x, maxf(20.0, (vh - main_h) * 0.5))
			_focus_first(_main_col)
		St.NEWGAME:
			# Dificultad: columna a la IZQUIERDA (entra desde la izquierda) +
			# panel de descripción a la DERECHA.
			_show_only(_newgame_col)
			_desc_panel.visible = true
			_slide_in(_newgame_col, -DIFF_BTN_W - 120, 90, (vh - 236) * 0.5)
			_focus_first(_newgame_col)
		St.EXTRAS:
			_show_only(_extras_col)
			_slide_in(_extras_col, vw + 80, center_x, 240)
			_focus_first(_extras_col)
		St.SAVES:
			# Submenú de guardado: la raíz entera se desliza desde la derecha.
			_show_only(_saves_root)
			_slide_in(_saves_root, vw + 80, 0, 0)
			_focus_first(_saves_col)


func _show_only(keep: Control) -> void:
	for c in [_main_col, _newgame_col, _extras_col, _saves_root]:
		if c != null:
			c.visible = (c == keep)
	if _desc_panel != null:
		_desc_panel.visible = false
	if _icon_copy != null:
		_icon_copy.visible = false
	if _icon_erase != null:
		_icon_erase.visible = false
	if keep == null:
		_cursor.visible = false


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
		_toast(tr("SCENEMISSING") % GAME_SCENE)


func _open_options() -> void:
	var opt := OptionsMenu.new()
	add_child(opt)
	_busy = true   # bloquea el menú mientras está abierto
	opt.options_closed.connect(func(): _busy = false)


func _open_credits() -> void:
	var scr := load(CREDITS_SCRIPT)
	if scr == null:
		_toast(tr("CREDITSNA"))
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
		_toast(tr("SOUNDROOMNA"))
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
