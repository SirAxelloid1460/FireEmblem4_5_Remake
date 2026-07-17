class_name SelectMenu
extends Control

# ============================================================
# SelectMenu — menú de selección estilo FE4 (referencia: pantalla de idioma).
# ============================================================
# Estructura común reutilizable por los menús de arranque:
#   · Fondo por capas a pantalla completa:
#       - base (_bg_base_texture): imagen de fondo, con parallax opcional
#         (deriva lenta) — p. ej. default_background (las runas de Jugdral).
#       - o bien base que cambia EN VIVO por opción (_bg_for_option), sin
#         parallax — p. ej. title_background_FE4/FE5/SAGA.
#       - TitleOverlay: niebla/nubes animada TRANSPARENTE, común a todos los
#         menús (idioma, modo, principal), encima de la base y debajo de la UI.
#   · Panel-preview OPCIONAL a la izquierda (_has_preview_panel) con una imagen
#     por opción (p. ej. la bandera del idioma).
#   · Panel-lista a la derecha (skin ornamentado menu_box_6x) con las opciones
#     en fuente serif; la opción con foco se resalta en dorado.
#   · Cursor-mano FE a la izquierda de la opción enfocada, con bobeo sutil.
#   Navegable con teclado/mando Y ratón. SIN música (depende de la versión;
#   empieza más adelante). Sólo SFX de navegación.
#
# Las SUBCLASES sólo sobreescriben la configuración (no _ready):
#   _menu_items()          -> Array de { "id": String, "text": String }
#   _has_preview_panel()   -> bool (por defecto true)
#   _preview_texture(id)   -> Texture2D del panel-preview de esa opción
#   _bg_base_texture()     -> Texture2D de la capa base, o null
#   _bg_parallax()         -> bool: deriva lenta de la base (por defecto false)
#   _bg_for_option(id)     -> Texture2D de base fija por opción, o null
#   _on_choose(id)         -> acción al confirmar
#   _on_cancel()           -> acción al cancelar (por defecto: nada)
#
# Placeholder pendiente: cursor-pájaro (hoy menu_hand.png, la mano FE clásica).
# ============================================================

const PANEL      := "res://assets/menus/menu_box_6x.png"
const HAND       := "res://assets/menus/menu_hand.png"
const SERIF_FONT := "res://assets/fonts/IMFellFrenchCanonSC-Regular.ttf"

const COLOR_TEXT    := Color(0.82, 0.84, 0.82, 1.0)   # crema tenue (opción normal)
const COLOR_GOLD    := Color(1.00, 0.90, 0.55, 1.0)   # dorado (opción enfocada)
const COLOR_OUTLINE := Color(0.05, 0.05, 0.10, 1.0)
const COLOR_BG      := Color(0.04, 0.04, 0.07, 1.0)

const BTN_FONT   := 32
const HAND_SCALE := 4
const BOB_SEQ  := [0, 3, 6, 3]
const BOB_TIME := 0.12
# Parallax de la base: sobre-tamaño y amplitud de la deriva (px).
const PARALLAX_MARGIN := 24.0
const PARALLAX_AMP    := 12.0

const SFX_NAV     := "Select 5"
const SFX_CONFIRM := "Select 4"
const SFX_CANCEL  := "Step Back 1"

var _cursor: TextureRect
var _cursor_target: Button = null
var _preview: TextureRect
var _list: VBoxContainer
var _sfx: AudioStreamPlayer
var _bob_i: int = 0
var _bob_accum: float = 0.0
var _busy: bool = false
var _skip_next_nav: bool = false

# Fondo.
var _bg_base: TextureRect       # capa base (default_background / bg por opción)
var _parallax: bool = false
var _bg_t: float = 0.0


# ── Configuración (sobreescribir en subclases) ──────────────────────────────
func _menu_items() -> Array:
	return []


func _has_preview_panel() -> bool:
	return true


func _preview_texture(_id: String) -> Texture2D:
	return null


func _bg_base_texture() -> Texture2D:
	return null


func _bg_parallax() -> bool:
	return false


func _bg_for_option(_id: String) -> Texture2D:
	return null


func _on_choose(_id: String) -> void:
	pass


func _on_cancel() -> void:
	pass


# ── Construcción ────────────────────────────────────────────────────────────
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_bg()
	if _has_preview_panel():
		_build_preview_panel()
	_build_list_panel()
	_build_cursor()
	# Enfocar la primera opción (sin sonar como navegación manual).
	if _list != null and _list.get_child_count() > 0:
		_skip_next_nav = true
		(_list.get_child(0) as Button).call_deferred("grab_focus")


func _build_bg() -> void:
	_parallax = _bg_parallax()
	var base := ColorRect.new()
	base.color = COLOR_BG
	base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(base)
	# Capa base (imagen). Con parallax se posiciona a mano en _process (sobre-
	# tamaño + deriva); sin parallax cubre el rect completo.
	_bg_base = TextureRect.new()
	_bg_base.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_bg_base.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_bg_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not _parallax:
		_bg_base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_bg_base)
	var base_tex := _bg_base_texture()
	if base_tex == null:
		# Menú con fondo por opción: sembrar con el de la primera opción.
		var items := _menu_items()
		if items.size() > 0:
			base_tex = _bg_for_option(str(items[0].get("id", "")))
	if base_tex != null:
		_bg_base.texture = base_tex
	# Overlay de niebla/nubes animado (común a todos los menús), encima de la base.
	add_child(TitleOverlay.new())


## NinePatchRect con el skin ornamentado, anclado por fracciones del viewport.
func _nine_panel(al: float, at: float, ar: float, ab: float) -> NinePatchRect:
	var n := NinePatchRect.new()
	n.texture = load(PANEL)
	n.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	n.patch_margin_left = 14
	n.patch_margin_right = 14
	n.patch_margin_top = 22
	n.patch_margin_bottom = 22
	n.anchor_left = al
	n.anchor_top = at
	n.anchor_right = ar
	n.anchor_bottom = ab
	n.offset_left = 0
	n.offset_top = 0
	n.offset_right = 0
	n.offset_bottom = 0
	add_child(n)
	return n


func _build_preview_panel() -> void:
	var panel := _nine_panel(0.07, 0.30, 0.38, 0.66)
	_preview = TextureRect.new()
	_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_preview.offset_left = 26
	_preview.offset_top = 28
	_preview.offset_right = -26
	_preview.offset_bottom = -32
	panel.add_child(_preview)


func _build_list_panel() -> void:
	var panel := _nine_panel(0.55, 0.20, 0.93, 0.80)
	_list = VBoxContainer.new()
	_list.alignment = BoxContainer.ALIGNMENT_CENTER
	_list.add_theme_constant_override("separation", 16)
	_list.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_list.offset_left = 62
	_list.offset_top = 28
	_list.offset_right = -30
	_list.offset_bottom = -28
	panel.add_child(_list)
	for it in _menu_items():
		_list.add_child(_make_option(str(it.get("text", "")), str(it.get("id", ""))))


func _make_option(text: String, id: String) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.custom_minimum_size = Vector2(0, 44)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var f := load(SERIF_FONT)
	if f != null:
		b.add_theme_font_override("font", f)
	b.add_theme_font_size_override("font_size", BTN_FONT)
	b.add_theme_color_override("font_color", COLOR_TEXT)
	b.add_theme_color_override("font_focus_color", COLOR_GOLD)
	b.add_theme_color_override("font_hover_color", COLOR_GOLD)
	b.add_theme_color_override("font_pressed_color", COLOR_GOLD)
	b.add_theme_color_override("font_outline_color", COLOR_OUTLINE)
	b.add_theme_constant_override("outline_size", 5)
	var empty := StyleBoxEmpty.new()
	for s in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(s, empty)
	b.set_meta("id", id)
	b.focus_entered.connect(_on_option_focus.bind(b, id))
	b.mouse_entered.connect(b.grab_focus)
	b.pressed.connect(_on_option_pressed.bind(id))
	return b


func _build_cursor() -> void:
	_cursor = TextureRect.new()
	_cursor.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_cursor.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(HAND):
		_cursor.texture = load(HAND)
	_cursor.size = Vector2(15 * HAND_SCALE, 12 * HAND_SCALE)
	_cursor.visible = false
	add_child(_cursor)


# ── Interacción ─────────────────────────────────────────────────────────────
func _on_option_focus(b: Button, id: String) -> void:
	_move_cursor_to(b)
	# Panel-preview (si lo hay).
	if _preview != null:
		var tex := _preview_texture(id)
		if tex != null:
			_preview.texture = tex
	# Fondo base que cambia en vivo por opción (si aplica).
	var bg := _bg_for_option(id)
	if bg != null and _bg_base != null:
		_bg_base.texture = bg
	if _skip_next_nav:
		_skip_next_nav = false
	else:
		_play_sfx(SFX_NAV)


func _on_option_pressed(id: String) -> void:
	if _busy:
		return
	_busy = true
	_play_sfx(SFX_CONFIRM)
	_on_choose(id)


func _unhandled_input(event: InputEvent) -> void:
	if _busy:
		return
	if event.is_action_pressed("ui_cancel"):
		_play_sfx(SFX_CANCEL)
		_on_cancel()


func _move_cursor_to(b: Button) -> void:
	if b == null or not is_instance_valid(b):
		_cursor.visible = false
		_cursor_target = null
		return
	_cursor.visible = true
	_cursor_target = b
	_bob_i = 0
	_bob_accum = 0.0


func _process(delta: float) -> void:
	_animate_parallax(delta)
	_animate_cursor(delta)


## Deriva parallax lenta de la base (sobre-tamaño para no descubrir bordes).
func _animate_parallax(delta: float) -> void:
	if not _parallax or _bg_base == null:
		return
	_bg_t += delta
	var vp := get_viewport_rect().size
	_bg_base.size = vp + Vector2(PARALLAX_MARGIN * 2.0, PARALLAX_MARGIN * 2.0)
	_bg_base.position = Vector2(
		-PARALLAX_MARGIN + sin(_bg_t * 0.35) * PARALLAX_AMP,
		-PARALLAX_MARGIN + sin(_bg_t * 0.27) * PARALLAX_AMP)


func _animate_cursor(delta: float) -> void:
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


## Reproduce un SFX del menú (bus "SFX" si existe).
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
