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
#   FE4 / SAGA → assets/videos/fe4_{idioma}.ogv   (SAGA arranca con FE4)
#   FE5        → assets/videos/fe5_{idioma}.ogv   (intro de Thracia 776)
# El sufijo de idioma sale del locale (ja → jp); si no existe el del idioma
# actual se cae a _en (ver VideoResolver). Si no hay ninguno, se salta directo
# al menú (sin romper).
# ============================================================

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


## Resuelve el vídeo de intro por modo (fe4 para FE4/SAGA, fe5 para FE5), con
## sufijo de idioma y fallback a _en (ver VideoResolver); "" si no hay.
func _resolve_video() -> String:
	var gm := get_node_or_null("/root/GameMode")
	var mode := int(gm.current_mode) if gm != null and "current_mode" in gm else 0
	var base := "fe5" if mode == 1 else "fe4"   # FE5_ONLY=1; FE4/SAGA arrancan con FE4
	return VideoResolver.localized(base)


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
