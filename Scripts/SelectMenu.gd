class_name SelectMenu
extends Control

# ============================================================
# SelectMenu — menú de selección estilo FE4 (referencia: pantalla de idioma).
# ============================================================
# Estructura común reutilizable por los menús de arranque:
#   · Panel-lista a la derecha (skin ornamentado menu_box_6x, 9-patch) con las
#     opciones en fuente serif; la opción con foco se resalta en dorado.
#   · Panel-preview a la izquierda (mismo skin) que muestra una imagen por opción
#     (bandera del idioma / logo del juego), actualizada al cambiar el foco.
#   · Cursor-mano FE a la izquierda de la opción enfocada, con bobeo sutil.
#   Navegable con teclado/mando Y ratón.
#
# Las SUBCLASES sólo sobreescriben la configuración (no _ready):
#   _menu_items()          -> Array de { "id": String, "text": String }
#   _preview_texture(id)   -> Texture2D para el panel-preview de esa opción
#   _on_choose(id)         -> acción al confirmar una opción
#   _on_cancel()           -> acción al pulsar cancelar (por defecto: nada)
#
# Assets pendientes para clavar la referencia (placeholders por ahora):
#   · fondo de runas de Jugdral (hoy: color liso COLOR_BG).
#   · cursor-pájaro (hoy: menu_hand.png, la mano FE clásica).
# ============================================================

const PANEL       := "res://assets/menus/menu_box_6x.png"
const HAND        := "res://assets/menus/menu_hand.png"
const SERIF_FONT  := "res://assets/fonts/IMFellFrenchCanonSC-Regular.ttf"
const THEME_MUSIC := "res://assets/music/102 - Fire Emblem Theme.ogg"

const COLOR_TEXT    := Color(0.82, 0.84, 0.82, 1.0)   # crema tenue (opción normal)
const COLOR_GOLD    := Color(1.00, 0.90, 0.55, 1.0)   # dorado (opción enfocada)
const COLOR_OUTLINE := Color(0.05, 0.05, 0.10, 1.0)
const COLOR_BG      := Color(0.09, 0.10, 0.15, 1.0)

const BTN_FONT   := 34
const HAND_SCALE := 4
# Bobeo escalonado del cursor (look GBA).
const BOB_SEQ  := [0, 3, 6, 3]
const BOB_TIME := 0.12

const SFX_NAV     := "Select 5"
const SFX_CONFIRM := "Select 4"
const SFX_CANCEL  := "Step Back 1"

var _cursor: TextureRect
var _cursor_target: Button = null
var _preview: TextureRect
var _list: VBoxContainer
var _music: AudioStreamPlayer
var _sfx: AudioStreamPlayer
var _bob_i: int = 0
var _bob_accum: float = 0.0
var _busy: bool = false
var _skip_next_nav: bool = false


# ── Configuración (sobreescribir en subclases) ──────────────────────────────
func _menu_items() -> Array:
	return []


func _preview_texture(_id: String) -> Texture2D:
	return null


func _on_choose(_id: String) -> void:
	pass


func _on_cancel() -> void:
	pass


# ── Construcción ────────────────────────────────────────────────────────────
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_bg()
	_build_music()
	_build_preview_panel()
	_build_list_panel()
	_build_cursor()
	# Enfocar la primera opción (sin sonar como navegación manual).
	if _list != null and _list.get_child_count() > 0:
		_skip_next_nav = true
		(_list.get_child(0) as Button).call_deferred("grab_focus")


func _build_bg() -> void:
	var bg := ColorRect.new()
	bg.color = COLOR_BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	# Gancho: cuando exista el fondo de runas de Jugdral, pintarlo aquí como
	# TextureRect a pantalla completa (STRETCH_KEEP_ASPECT_COVERED, nearest).


func _build_music() -> void:
	if not ResourceLoader.exists(THEME_MUSIC):
		return
	_music = AudioStreamPlayer.new()
	var stream = load(THEME_MUSIC)
	if "loop" in stream:
		stream.loop = true
	_music.stream = stream
	if AudioServer.get_bus_index("Music") >= 0:
		_music.bus = "Music"
	add_child(_music)
	_music.play()


## NinePatchRect con el skin ornamentado, anclado por fracciones del viewport.
func _nine_panel(al: float, at: float, ar: float, ab: float) -> NinePatchRect:
	var n := NinePatchRect.new()
	n.texture = load(PANEL)
	n.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Márgenes 9-patch del skin (144×144): barras doradas arriba/abajo, borde lateral.
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
	var panel := _nine_panel(0.06, 0.28, 0.40, 0.66)
	_preview = TextureRect.new()
	_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Márgenes internos para que la imagen no toque el marco ornamentado.
	_preview.offset_left = 28
	_preview.offset_top = 30
	_preview.offset_right = -28
	_preview.offset_bottom = -34
	panel.add_child(_preview)


func _build_list_panel() -> void:
	var panel := _nine_panel(0.50, 0.10, 0.95, 0.90)
	_list = VBoxContainer.new()
	_list.alignment = BoxContainer.ALIGNMENT_CENTER
	_list.add_theme_constant_override("separation", 22)
	_list.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_list.offset_left = 70
	_list.offset_top = 36
	_list.offset_right = -36
	_list.offset_bottom = -36
	panel.add_child(_list)
	for it in _menu_items():
		_list.add_child(_make_option(str(it.get("text", "")), str(it.get("id", ""))))


func _make_option(text: String, id: String) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.custom_minimum_size = Vector2(0, 48)
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
	var tex := _preview_texture(id)
	if _preview != null and tex != null:
		_preview.texture = tex
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
	var pos := Vector2(
		b.global_position.x - hw - 6 + BOB_SEQ[_bob_i],
		b.global_position.y + (b.size.y - 12 * HAND_SCALE) * 0.5)
	_cursor.global_position = pos


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
