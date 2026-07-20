# ActionMenu.gd
# ============================================================
# MENÚ DE ACCIONES de unidad (tras mover), estilo FE, por código.
# ============================================================
# Panel flotante en espacio de pantalla (CanvasLayer) con las acciones
# disponibles para la unidad que acaba de moverse: Attack (si hay objetivos),
# Item/Staff (si aplica) y Wait. Lo instancia GameManager.show_action_menu y
# escucha la señal `action_selected`. Cancelar (B) equivale a "wait".
#
# Navegable con ratón (clic/hover) y teclado/mando (foco + accept/cancel), en
# línea con el modelo de input del juego (clic) y el del menú principal.

extends Control
class_name ActionMenu

signal action_selected(id: String)

const UI_FONT := "res://assets/fonts/bmp/text.fnt"   # sprite-font LT
const COLOR_GOLD_DIM := Color(0.70, 0.60, 0.30, 1.0)
const COLOR_TEXT     := Color(0.95, 0.93, 0.85, 1.0)
const COLOR_OUTLINE  := Color(0.0, 0.0, 0.0, 1.0)

var _vbox: VBoxContainer
var _emitted: bool = false   # una sola acción por menú


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE   # sólo los botones capturan


## Construye el menú con una lista de opciones [{ "id":..., "text":... }].
## anchor_screen: posición de pantalla sugerida (px) para la esquina del panel.
func setup(options: Array, anchor_screen: Vector2 = Vector2(-1, -1)) -> void:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.13, 0.95)
	sb.set_border_width_all(2)
	sb.border_color = COLOR_GOLD_DIM
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", sb)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)

	_vbox = VBoxContainer.new()
	_vbox.add_theme_constant_override("separation", 6)
	panel.add_child(_vbox)

	var first: Button = null
	for opt in options:
		var b := _make_button(str(opt.get("text", "?")), str(opt.get("id", "")))
		_vbox.add_child(b)
		if first == null:
			first = b

	# Posición: por defecto centro-derecha de la pantalla; si se pasa anchor,
	# se coloca ahí (recortado a la vista para no salirse).
	var vp := get_viewport_rect().size
	var pos := anchor_screen
	if pos.x < 0.0:
		pos = Vector2(vp.x - 260, vp.y * 0.35)
	panel.position = pos
	panel.reset_size()
	# Recorte defensivo a los bordes de la pantalla.
	panel.position.x = clampf(panel.position.x, 8, vp.x - panel.size.x - 8)
	panel.position.y = clampf(panel.position.y, 8, vp.y - panel.size.y - 8)

	if first != null:
		first.grab_focus()


func _make_button(text: String, id: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(200, 48)
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	var f = load(AssetSet.p(UI_FONT))
	if f != null:
		b.add_theme_font_override("font", f)
	b.add_theme_font_size_override("font_size", 26)
	b.add_theme_color_override("font_color", COLOR_TEXT)
	b.add_theme_color_override("font_focus_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_outline_color", COLOR_OUTLINE)
	b.add_theme_constant_override("outline_size", 4)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.10, 0.11, 0.20, 0.0)
	normal.set_corner_radius_all(4)
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.20, 0.24, 0.42, 0.95)
	hover.set_corner_radius_all(4)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("focus", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.pressed.connect(_emit.bind(id))
	b.mouse_entered.connect(b.grab_focus)
	return b


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_emit("wait")
		get_viewport().set_input_as_handled()


## Emite la acción elegida (una sola vez) y se auto-elimina.
func _emit(id: String) -> void:
	if _emitted:
		return
	_emitted = true
	action_selected.emit(id)
	queue_free()
