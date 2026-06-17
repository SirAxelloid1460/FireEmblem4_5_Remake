extends Button
class_name FEButton

# ============================================================
# FEButton — botón de menú estilo FE, reutilizable
# ============================================================
# Consolida los botones-componente del proyecto viejo (MenuButton, ActionButton,
# DataButton, SettingsButton): fondo transparente, texto que se vuelve dorado al
# foco/hover, y el ratón al pasar por encima toma el foco (navegación mixta).
# Úsalo en cualquier escena; ajusta `text`, `custom_minimum_size`, etc.
# ============================================================

const COLOR_TEXT := Color(0.95, 0.95, 0.90, 1.0)
const COLOR_GOLD := Color(1.00, 0.84, 0.36, 1.0)

@export var font_px: int = 26


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_font_size_override("font_size", font_px)
	add_theme_color_override("font_color", COLOR_TEXT)
	add_theme_color_override("font_focus_color", COLOR_GOLD)
	add_theme_color_override("font_hover_color", COLOR_GOLD)
	add_theme_color_override("font_pressed_color", COLOR_GOLD)
	add_theme_color_override("font_outline_color", Color.BLACK)
	add_theme_constant_override("outline_size", 4)
	var empty := StyleBoxEmpty.new()
	for s in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(s, empty)
	if not mouse_entered.is_connected(grab_focus):
		mouse_entered.connect(grab_focus)
