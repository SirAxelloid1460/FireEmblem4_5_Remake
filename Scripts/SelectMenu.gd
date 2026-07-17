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
# Parallax de la base: scroll HORIZONTAL constante hacia la izquierda (fracción
# de textura por segundo). Shader que desplaza la UV y hace wrap (tile).
const PARALLAX_SPEED := 0.03
const SCROLL_SHADER := """
shader_type canvas_item;
uniform float speed;
void fragment() {
	vec2 uv = UV;
	uv.x += TIME * speed;
	COLOR = texture(TEXTURE, fract(uv));
}
"""

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


## Tamaño de fuente de las opciones (px). Sobreescribir por menú.
func _option_font_size() -> int:
	return BTN_FONT


## Alineación horizontal del texto de las opciones. Sobreescribir por menú.
func _option_align() -> int:
	return HORIZONTAL_ALIGNMENT_LEFT


## Píxeles que se SUBE el CONTENIDO (bandera / botones) dentro de su panel, sin
## mover el panel. Sobreescribir por menú (0 = contenido centrado en el panel).
func _content_lift() -> int:
	return 0


## Geometría del panel-lista en fracciones del viewport [izq, arriba, der, abajo].
## Centrado en pantalla por defecto.
func _list_panel_rect() -> Array:
	return [0.55, 0.18, 0.93, 0.82]


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
	# Capa base (imagen), a pantalla completa. Con parallax: scroll horizontal
	# constante hacia la izquierda vía shader (UV + wrap), textura en modo tile.
	_bg_base = TextureRect.new()
	_bg_base.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_bg_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg_base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if _parallax:
		_bg_base.stretch_mode = TextureRect.STRETCH_SCALE
		_bg_base.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		var sh := Shader.new()
		sh.code = SCROLL_SHADER
		var mat := ShaderMaterial.new()
		mat.shader = sh
		mat.set_shader_parameter("speed", PARALLAX_SPEED)
		_bg_base.material = mat
	else:
		_bg_base.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
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
	# Panel centrado en pantalla; la bandera se sube DENTRO con _content_lift.
	var panel := _nine_panel(0.07, 0.31, 0.38, 0.67)
	var lift := _content_lift()
	_preview = TextureRect.new()
	# STRETCH_SCALE + más margen arriba/abajo: reduce SÓLO el alto de la bandera
	# (el ancho sigue llenando el recuadro). Los offsets se desplazan por `lift`
	# (misma altura, posición más arriba) sin mover el panel.
	_preview.stretch_mode = TextureRect.STRETCH_SCALE
	_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_preview.offset_left = 26
	_preview.offset_top = 52 - lift
	_preview.offset_right = -26
	_preview.offset_bottom = -56 - lift
	panel.add_child(_preview)


func _build_list_panel() -> void:
	var r := _list_panel_rect()
	var panel := _nine_panel(float(r[0]), float(r[1]), float(r[2]), float(r[3]))
	_list = VBoxContainer.new()
	_list.alignment = BoxContainer.ALIGNMENT_CENTER
	# Separación proporcional a la fuente (fuentes grandes → menos hueco relativo).
	_list.add_theme_constant_override("separation", maxi(6, int(_option_font_size() * 0.18)))
	# Contenido centrado en el panel y subido `lift` px (sin mover el panel):
	# ambos offsets verticales se desplazan hacia arriba lo mismo.
	var lift := _content_lift()
	_list.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_list.offset_left = 62
	_list.offset_top = 18 - lift
	_list.offset_right = -28
	_list.offset_bottom = -18 - lift
	panel.add_child(_list)
	for it in _menu_items():
		_list.add_child(_make_option(str(it.get("text", "")), str(it.get("id", ""))))


func _make_option(text: String, id: String) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = _option_align()
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	var fs := _option_font_size()
	b.custom_minimum_size = Vector2(0, fs + 12)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var f := load(SERIF_FONT)
	if f != null:
		b.add_theme_font_override("font", f)
	b.add_theme_font_size_override("font_size", fs)
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
	# El parallax lo anima el shader (TIME); aquí sólo el cursor.
	_animate_cursor(delta)


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
	# Punto de referencia = inicio del texto. Con texto centrado, se calcula el
	# comienzo del texto (centro del botón − mitad del ancho del texto) para que
	# la mano quede pegada a la palabra, no al borde del panel.
	var x_ref := b.global_position.x
	if _option_align() == HORIZONTAL_ALIGNMENT_CENTER:
		var font := b.get_theme_font("font")
		var fs := b.get_theme_font_size("font_size")
		if font != null:
			var tw: float = font.get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			x_ref = b.global_position.x + (b.size.x - tw) * 0.5
	_cursor.global_position = Vector2(
		x_ref - hw - 6 + BOB_SEQ[_bob_i],
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
