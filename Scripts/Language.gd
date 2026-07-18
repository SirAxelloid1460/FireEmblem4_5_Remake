class_name LanguageScreen
extends SelectMenu

# ============================================================
# LANGUAGE — Menú 1 del arranque: selección de idioma.
# ============================================================
# Recrea la pantalla de idioma de referencia sobre SelectMenu: lista de idiomas
# en el panel derecho, bandera del idioma enfocado en el panel-preview izquierdo.
# Al elegir: guarda el locale (FadeCanvas.save_locale) y pasa al Menú 2 (modo).
#
# Idiomas y orden = la referencia. El locale "it" (Italiano) queda seleccionable;
# sus traducciones aún no existen (recae en el idioma por defecto hasta añadirlas).
# ============================================================

const FLAGS := "res://assets/languages/Flags/"
const NEXT_SCENE := "res://Scenes/mode_select.tscn"   # Idioma → Modo → Intro → MainMenu

# Fondo: base de runas de Jugdral (parallax). La niebla animada encima la pone
# SelectMenu con TitleOverlay (común a todos los menús).
const BG_BASE := "res://assets/panoramas/default_background.png"

const LANGS := [
	{ "id": "en", "text": "English" },
	{ "id": "de", "text": "Deutsch" },
	{ "id": "fr", "text": "Français" },
	{ "id": "es", "text": "Español" },
	{ "id": "it", "text": "Italiano" },
]


func _menu_items() -> Array:
	return LANGS


func _option_font_size() -> int:
	return 56


# Sube los botones dentro del panel (el panel sigue centrado).
func _content_lift() -> int:
	return 16


# La bandera no se sube (a 1200x800 se salía un poco por arriba).
func _preview_lift() -> int:
	return 30


func _preview_hshift() -> int:
	return 8


func _preview_texture(id: String) -> Texture2D:
	var p := FLAGS + id + ".png"
	return load(p) if ResourceLoader.exists(p) else null


func _bg_base_texture() -> Texture2D:
	return load(BG_BASE) if ResourceLoader.exists(BG_BASE) else null


func _bg_parallax() -> bool:
	return true


func _on_choose(id: String) -> void:
	FadeCanvas.save_locale(id)
	FadeCanvas.change_scene_to_file(NEXT_SCENE)
