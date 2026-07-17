class_name ModeSelect
extends SelectMenu

# ============================================================
# MODE — Menú 2 del arranque: selección de versión del remake.
# ============================================================
# Misma estructura que el menú de idioma, con 3 opciones que fijan el modo de
# GameMode (autoload):
#   Genealogy of the Holy War → FE4_ONLY
#   Thracia 776               → FE5_ONLY
#   Both Together             → SAGA_MODE
# Preview = logo del juego (o escudo de Grandbell para la saga completa).
# Al elegir: guarda el modo y pasa a la intro (vídeos) → MainMenu.
# Cancelar: vuelve al menú de idioma.
#
# GameMode no tiene class_name (es autoload), así que el modo se fija por su
# valor entero: FE4_ONLY=0, FE5_ONLY=1, SAGA_MODE=2 (orden del enum Mode).
# ============================================================

const NEXT_SCENE := "res://Scenes/intro.tscn"       # Modo → Intro (vídeos) → MainMenu
const PREV_SCENE := "res://Scenes/language.tscn"     # cancelar → volver a idioma

const LOGO_FE4 := "res://assets/title/logo1.png"        # Genealogy of the Holy War
const LOGO_FE5 := "res://assets/title/logo2.png"        # Thracia 776
const CREST    := "res://assets/title/title2_background.png"  # escudo Grandbell (saga)

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


func _preview_texture(id: String) -> Texture2D:
	var p := CREST
	match id:
		"fe4": p = LOGO_FE4
		"fe5": p = LOGO_FE5
		"saga": p = CREST
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
