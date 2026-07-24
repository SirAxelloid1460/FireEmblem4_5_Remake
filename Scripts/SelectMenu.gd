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
const UI_FONT := "res://assets/fonts/bmp/text.fnt"   # sprite-font LT

const COLOR_TEXT    := Color(0.82, 0.84, 0.82, 1.0)   # crema tenue (opción normal)
const COLOR_GOLD    := Color(1.00, 0.90, 0.55, 1.0)   # dorado (opción enfocada)
const COLOR_DISABLED := Color(0.45, 0.46, 0.48, 1.0)  # gris (opción deshabilitada / W.I.P)
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
var _fit_fs: int = 0            # tamaño de fuente auto-ajustado (0 = aún sin calcular)

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


## Tamaño de fuente de las opciones (px). Es el TOPE MÁXIMO: el tamaño real se
## auto-ajusta hacia abajo (_fit_option_font_size) para que el idioma con textos
## más largos / más opciones quepa en el panel. Sobreescribir por menú.
func _option_font_size() -> int:
	return BTN_FONT


## Tamaño mínimo al que puede encoger la auto-adaptación. Sobreescribir por menú.
func _min_option_font_size() -> int:
	return 24


## Elige el mayor tamaño (≤ _option_font_size, ≥ _min_option_font_size) al que TODAS
## las opciones caben en el panel: por ANCHO y por ALTO (todas las filas +
## separaciones). Así el tamaño es proporcional a la longitud de la traducción y,
## por ende, al idioma activo.
## IMPORTANTE: el ancho se mide en PÍXELES con Font.get_string_size (suma el
## avance real de cada glifo: una "i" ocupa menos que una "W"), NO por nº de
## caracteres; y se toma el máximo sobre todas las opciones (el más ANCHO, no el
## de más letras).
func _fit_option_font_size(items: Array) -> int:
	var maxfs: int = _option_font_size()
	var minfs: int = _min_option_font_size()
	if items.is_empty():
		return maxfs
	var vp: Vector2 = get_viewport_rect().size
	var r := _list_panel_rect()
	var panel_w: float = (float(r[2]) - float(r[0])) * vp.x
	var panel_h: float = (float(r[3]) - float(r[1])) * vp.y
	# Márgenes internos del VBox de opciones (ver _build_list_panel): 62+28 en X,
	# 18+18 en Y (el lift solo desplaza, no reduce el alto disponible).
	var avail_w: float = panel_w - 90.0
	var avail_h: float = panel_h - 36.0
	var f := load(AssetSet.p(UI_FONT))
	var n: int = items.size()
	var fs: int = maxfs
	while fs > minfs:
		var sep: int = maxi(6, int(fs * 0.18))
		var total_h: float = n * (fs + 12) + (n - 1) * sep
		var widest: float = 0.0
		if f != null:
			for it in items:
				var shown: String = _option_display_text(it)
				widest = maxf(widest, f.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
		if total_h <= avail_h and widest <= avail_w:
			return fs
		fs -= 2
	return minfs


## ¿Es seleccionable esta opción? Las deshabilitadas se ven en gris, con el botón
## inaccesible (el cursor las salta). Sobreescribir por menú.
func _option_enabled(_id: String) -> bool:
	return true


## Sufijo añadido al rótulo de la opción (p. ej. " (W.I.P)"). Sobreescribir.
func _option_label_suffix(_id: String) -> String:
	return ""


## Texto FINAL mostrado de una opción: base traducida + sufijo. Los nombres de
## idioma son literales (tr los devuelve tal cual); las claves de otros menús se
## traducen. Se usa tanto al construir como al medir el auto-ajuste de fuente.
func _option_display_text(it: Dictionary) -> String:
	return tr(str(it.get("text", ""))) + _option_label_suffix(str(it.get("id", "")))


## Alineación horizontal del texto de las opciones. Sobreescribir por menú.
func _option_align() -> int:
	return HORIZONTAL_ALIGNMENT_LEFT


## Píxeles que se SUBE el CONTENIDO (botones) dentro de su panel, sin mover el
## panel. Sobreescribir por menú (0 = contenido centrado en el panel).
func _content_lift() -> int:
	return 0


## Lift del panel-preview (bandera), independiente del de los botones. Por
## defecto usa el mismo; sobreescribir para subir la imagen menos/más.
func _preview_lift() -> int:
	return _content_lift()


## Desplazamiento horizontal del panel-preview (bandera) dentro del panel, en px
## hacia la IZQUIERDA (positivo = izquierda). Sobreescribir por menú.
func _preview_hshift() -> int:
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
	# Enfocar la primera opción HABILITADA (salta las W.I.P), sin sonar como
	# navegación manual.
	if _list != null:
		for child in _list.get_children():
			var b := child as Button
			if b != null and not b.disabled:
				_skip_next_nav = true
				b.call_deferred("grab_focus")
				break


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
	n.texture = load(AssetSet.p(PANEL))
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
	# Panel centrado en pantalla; la bandera se sube DENTRO con _preview_lift.
	var panel := _nine_panel(0.07, 0.31, 0.38, 0.67)
	var lift := _preview_lift()
	var hshift := _preview_hshift()
	_preview = TextureRect.new()
	# STRETCH_SCALE + más margen arriba/abajo: reduce SÓLO el alto de la bandera
	# (el ancho sigue llenando el recuadro). Los offsets se desplazan por `lift`
	# (misma altura, posición más arriba) sin mover el panel.
	_preview.stretch_mode = TextureRect.STRETCH_SCALE
	_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Márgenes con holgura para que la bandera NO toque el marco ornamentado.
	# `hshift` desplaza la bandera a la izquierda (ambos offsets X por igual).
	_preview.offset_left = 30 - hshift
	_preview.offset_top = 58 - lift
	_preview.offset_right = -30 - hshift
	_preview.offset_bottom = -58 - lift
	panel.add_child(_preview)


func _build_list_panel() -> void:
	var r := _list_panel_rect()
	var panel := _nine_panel(float(r[0]), float(r[1]), float(r[2]), float(r[3]))
	# Tamaño de fuente auto-ajustado al idioma/traducción activos (una vez, para
	# todas las opciones → tamaño uniforme y consistente por menú).
	_fit_fs = _fit_option_font_size(_menu_items())
	_list = VBoxContainer.new()
	_list.alignment = BoxContainer.ALIGNMENT_CENTER
	# Separación proporcional a la fuente (fuentes grandes → menos hueco relativo).
	_list.add_theme_constant_override("separation", maxi(6, int(_fit_fs * 0.18)))
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
		_list.add_child(_make_option(it))


func _make_option(it: Dictionary) -> Button:
	var id := str(it.get("id", ""))
	var enabled := _option_enabled(id)
	var b := Button.new()
	b.text = str(it.get("text", "")) + _option_label_suffix(id)
	b.alignment = _option_align()
	# Deshabilitada (W.I.P): botón inaccesible (el cursor la salta) y texto gris.
	b.focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE
	b.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	b.disabled = not enabled
	var fs := _fit_fs if _fit_fs > 0 else _option_font_size()
	b.custom_minimum_size = Vector2(0, fs + 12)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var f := load(AssetSet.p(UI_FONT))
	if f != null:
		b.add_theme_font_override("font", f)
	b.add_theme_font_size_override("font_size", fs)
	var base_col := COLOR_TEXT if enabled else COLOR_DISABLED
	b.add_theme_color_override("font_color", base_col)
	b.add_theme_color_override("font_focus_color", COLOR_GOLD if enabled else COLOR_DISABLED)
	b.add_theme_color_override("font_hover_color", COLOR_GOLD if enabled else COLOR_DISABLED)
	b.add_theme_color_override("font_pressed_color", COLOR_GOLD if enabled else COLOR_DISABLED)
	b.add_theme_color_override("font_disabled_color", COLOR_DISABLED)
	b.add_theme_color_override("font_outline_color", COLOR_OUTLINE)
	b.add_theme_constant_override("outline_size", 5)
	var empty := StyleBoxEmpty.new()
	for s in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(s, empty)
	b.set_meta("id", id)
	# Solo las opciones habilitadas reaccionan al foco / ratón / confirmación.
	if enabled:
		b.focus_entered.connect(_on_option_focus.bind(b, id))
		# Hover solo enfoca si el ratón está habilitado (el consumo global de
		# InputConfig no bloquea el mouse_entered, que va por posición del viewport).
		b.mouse_entered.connect(func(): if InputConfig.mouse_enabled: b.grab_focus())
		b.pressed.connect(_on_option_pressed.bind(id))
	return b


func _build_cursor() -> void:
	_cursor = TextureRect.new()
	_cursor.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_cursor.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hand_path := AssetSet.p(HAND)
	if ResourceLoader.exists(hand_path):
		_cursor.texture = load(hand_path)
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
			# Medir el texto YA TRADUCIDO (b.text guarda la CLAVE, no lo que se ve;
			# medir la clave subestima el ancho y mete la mano dentro de la palabra).
			var shown: String = tr(b.text)
			var tw: float = font.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
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
	var path := AssetSet.p("res://assets/sfx/%s.ogg" % sfx_name)
	if not ResourceLoader.exists(path):
		return
	_sfx.stream = load(path)
	_sfx.play()
