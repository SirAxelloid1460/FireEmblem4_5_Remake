class_name ModeSelect
extends SelectMenu

# ============================================================
# MODE — Menú 2 del arranque: selección de versión del remake.
# ============================================================
# Misma estructura que el menú de idioma, pero SIN panel-preview: en su lugar el
# FONDO cambia en vivo según la opción enfocada (fijo, sin parallax), usando
# title_background_FE4/FE5/SAGA. La niebla animada (TitleOverlay) va encima igual.
# Las 3 opciones fijan el modo de GameMode (autoload):
#   Genealogy of the Holy War → FE4_ONLY   (title_background_FE4)
#   Thracia 776               → FE5_ONLY   (title_background_FE5)
#   Both Together             → SAGA_MODE  (title_background_SAGA)
# Al elegir: guarda el modo y pasa a la intro (vídeos) → MainMenu.
# Cancelar: vuelve al menú de idioma.
#
# GameMode no tiene class_name (es autoload), así que el modo se fija por su
# valor entero: FE4_ONLY=0, FE5_ONLY=1, SAGA_MODE=2 (orden del enum Mode).
# ============================================================

const NEXT_SCENE := "res://Scenes/intro.tscn"       # Modo → Intro (vídeos) → MainMenu
const PREV_SCENE := "res://Scenes/language.tscn"     # cancelar → volver a idioma

const BG_FE4  := "res://assets/panoramas/title_background_FE4.png"   # ejército (FE4)
const BG_FE5  := "res://assets/panoramas/title_background_FE5.png"   # escudo (FE5)
const BG_SAGA := "res://assets/panoramas/title_background_SAGA.png"  # saga completa

const MODE_FE4 := 0   # GameMode.Mode.FE4_ONLY
const MODE_FE5 := 1   # GameMode.Mode.FE5_ONLY
const MODE_SAGA := 2  # GameMode.Mode.SAGA_MODE

const MODES := [
	{ "id": "fe4",  "text": "Genealogy of the Holy War" },
	{ "id": "fe5",  "text": "Thracia 776" },
	{ "id": "saga", "text": "Both Together" },
]


func _menu_items() -> Array:
	return MODES


func _has_preview_panel() -> bool:
	return false


# Recuadro centrado, ANCHO (la opción larga "Genealogy of the Holy War" no cabe
# si no) y de poco alto (sólo 3 opciones), subido un poco para centrarse mejor.
func _list_panel_rect() -> Array:
	return [0.13, 0.27, 0.87, 0.63]


func _option_font_size() -> int:
	return 56


func _option_align() -> int:
	return HORIZONTAL_ALIGNMENT_CENTER


func _bg_for_option(id: String) -> Texture2D:
	var p := BG_SAGA
	match id:
		"fe4": p = BG_FE4
		"fe5": p = BG_FE5
		"saga": p = BG_SAGA
	return load(p) if ResourceLoader.exists(p) else null


func _on_choose(id: String) -> void:
	var gm := get_node_or_null("/root/GameMode")
	if gm != null:
		match id:
			"fe4":  gm.current_mode = MODE_FE4
			"fe5":  gm.current_mode = MODE_FE5
			"saga": gm.current_mode = MODE_SAGA
	FadeCanvas.change_scene_to_file(NEXT_SCENE)


func _on_cancel() -> void:
	FadeCanvas.change_scene_to_file(PREV_SCENE)
