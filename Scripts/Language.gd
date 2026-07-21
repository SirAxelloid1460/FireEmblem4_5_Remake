class_name LanguageScreen
extends SelectMenu

# ============================================================
# LANGUAGE — Menú 1 del arranque: selección de idioma.
# ============================================================
# Recrea la pantalla de idioma de referencia sobre SelectMenu: lista de idiomas
# en el panel derecho, bandera del idioma enfocado en el panel-preview izquierdo.
# Al elegir: guarda el locale (FadeCanvas.save_locale) y pasa al Menú 2 (modo).
#
# Idiomas seleccionables: en, es, de, fr, it, ja. Los que aún no tienen (o tienen
# incompletas) sus traducciones caen automáticamente a inglés (locale/fallback
# = "en"; las celdas vacías del CSV se omiten al importar). Las traducciones de
# "it" se están completando en otra sesión. El nombre de "ja" se muestra en
# latín ("Japanese") porque la sprite-font LT no trae kana/kanji (fuente JP
# pendiente).
# ============================================================

const FLAGS := "res://assets/languages/Flags/"
const NEXT_SCENE := "res://Scenes/mode_select.tscn"   # Idioma → Modo → Intro → MainMenu

# Fondo: base de runas de Jugdral (parallax). La niebla animada encima la pone
# SelectMenu con TitleOverlay (común a todos los menús).
const BG_BASE := "res://assets/panoramas/default_background.png"

const LANGS := [
	{ "id": "en", "text": "English" },
	{ "id": "es", "text": "Español" },
	{ "id": "de", "text": "Deutsch" },
	{ "id": "fr", "text": "Français" },
	{ "id": "it", "text": "Italiano" },
	{ "id": "ja", "text": "Japanese" },
]


func _menu_items() -> Array:
	return LANGS


func _option_font_size() -> int:
	# Agrandada respecto a la ronda anterior (48). No sube a 64 porque con 6
	# idiomas (al reintegrar Italiano) la lista desbordaría el panel a lo alto.
	return 56


# Sube los botones dentro del panel (el panel sigue centrado).
func _content_lift() -> int:
	return 16


# La bandera sube 30px dentro del panel y se desplaza 8px a la izquierda.
func _preview_lift() -> int:
	return 30


func _preview_hshift() -> int:
	return 8


func _preview_texture(id: String) -> Texture2D:
	var p := AssetSet.p(FLAGS + id + ".png")
	return load(p) if ResourceLoader.exists(p) else null


func _bg_base_texture() -> Texture2D:
	var p := AssetSet.p(BG_BASE)
	return load(p) if ResourceLoader.exists(p) else null


func _bg_parallax() -> bool:
	return true


func _on_choose(id: String) -> void:
	FadeCanvas.save_locale(id)
	FadeCanvas.change_scene_to_file(NEXT_SCENE)
