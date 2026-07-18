extends Control
class_name IntroScreen

# ============================================================
# Intro — cinemática inicial (recreada desde cero)
# ============================================================
# Reproduce el vídeo de intro por MODO e idioma, saltable con accept/clic, y al
# terminar/saltar CORTA directo al menú principal SIN fade. El menú tiene su
# propio fondo y reproduce el tema de Fire Emblem como música.
#
# Vídeos por modo (GameMode: FE4_ONLY=0, FE5_ONLY=1, SAGA=2):
#   FE4 / SAGA → assets/videos/fe4_{en,jp}.ogv   (SAGA arranca con FE4)
#   FE5        → assets/videos/fe5_{en,jp}.ogv   (intro de Thracia 776)
# Fallback a los nombres viejos (eng/jap.ogv) por si aún no se renombran, y si
# no existe ningún vídeo del modo, se salta directo al menú (sin romper).
# ============================================================

const VIDEO_DIR := "res://assets/videos/"
const NEXT_SCENE := "res://Scenes/main_menu.tscn"

var _vp: VideoStreamPlayer
var _finished := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_vp = VideoStreamPlayer.new()
	_vp.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vp.expand = true
	_vp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_vp)

	var path := _resolve_video()
	if path != "":
		_vp.stream = load(path)
		_vp.finished.connect(_go_next)
		_vp.play()
	else:
		_go_next()


## Resuelve el vídeo de intro por modo + idioma, con fallbacks; "" si no hay.
func _resolve_video() -> String:
	var gm := get_node_or_null("/root/GameMode")
	var mode := int(gm.current_mode) if gm != null and "current_mode" in gm else 0
	var prefix := "fe5" if mode == 1 else "fe4"   # FE5_ONLY=1; FE4/SAGA arrancan con FE4
	var lang := "jp" if TranslationServer.get_locale().begins_with("ja") else "en"
	var candidates := [
		VIDEO_DIR + "%s_%s.ogv" % [prefix, lang],
		VIDEO_DIR + "%s_en.ogv" % prefix,             # inglés del mismo modo
	]
	if prefix == "fe4":
		# Compat con los nombres antiguos de FE4 (aún sin renombrar).
		candidates.append(VIDEO_DIR + ("jap.ogv" if lang == "jp" else "eng.ogv"))
		candidates.append(VIDEO_DIR + "eng.ogv")
	for p in candidates:
		if ResourceLoader.exists(p):
			return p
	return ""


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel") \
			or (event is InputEventMouseButton and event.pressed):
		_go_next()


func _go_next() -> void:
	if _finished:
		return
	_finished = true
	if _vp != null and _vp.is_playing():
		_vp.stop()
	# Corte directo SIN fade (el menú retoma el vídeo en bucle de fondo).
	get_tree().change_scene_to_file(NEXT_SCENE)
