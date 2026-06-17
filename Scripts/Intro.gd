extends Control
class_name IntroScreen

# ============================================================
# Intro — cinemática inicial (recreada desde cero)
# ============================================================
# Reproduce el vídeo de intro (eng/jap según locale), saltable con accept/clic,
# y al terminar/saltar CORTA directo al menú principal SIN fade. El menú tiene su
# propio fondo (gradiente) y reproduce el tema de Fire Emblem como música.
# ============================================================

const VIDEO_ENG := "res://assets/videos/eng.ogv"
const VIDEO_JAP := "res://assets/videos/jap.ogv"
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

	var path := VIDEO_JAP if TranslationServer.get_locale() == "ja" else VIDEO_ENG
	if ResourceLoader.exists(path):
		_vp.stream = load(path)
		_vp.finished.connect(_go_next)
		_vp.play()
	else:
		_go_next()


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
