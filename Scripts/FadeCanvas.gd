extends CanvasLayer
# ============================================================
# FadeCanvas — Autoload de transiciones (fundido a negro)
# ============================================================
# Recreado desde cero (sustituye al FadeCanvas viejo basado en AnimationPlayer).
# Capa por encima de todo; un ColorRect negro animado por tween.
#
# API:
#   await FadeCanvas.transition()                 # negro → (señal) → transparente
#   FadeCanvas.on_transition_finished             # se emite en el punto más oscuro
#   await FadeCanvas.change_scene_to_file(path)   # negro → cambia escena → transparente
#   FadeCanvas.save_locale("es")                  # fija + persiste el idioma
#
# También carga el idioma guardado (user://settings.cfg) al arrancar.
# ============================================================

signal on_transition_finished

const FADE_TIME := 0.4
const CFG_PATH := "user://settings.cfg"

var _rect: ColorRect
var _busy := false


func _ready() -> void:
	layer = 128                                   # por encima de cualquier escena/UI
	_rect = ColorRect.new()
	_rect.color = Color.BLACK
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.modulate.a = 0.0
	_rect.visible = false
	add_child(_rect)
	_load_saved_locale()
	_apply_display()


func _load_saved_locale() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CFG_PATH) == OK:
		var loc := str(cfg.get_value("general", "language", ""))
		if loc != "":
			TranslationServer.set_locale(loc)


## Aplica al arrancar el modo de ventana y la resolución guardados (Opciones).
func _apply_display() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CFG_PATH) != OK:
		return
	match int(cfg.get_value("display", "window_mode", 0)):
		1:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
		2:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		_:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
	var ridx := int(cfg.get_value("display", "resolution", 2))
	var reslist: Array = OptionsMenu.RESOLUTIONS
	if ridx >= 0 and ridx < reslist.size():
		var parts := str(reslist[ridx]).split("x")
		if parts.size() == 2:
			var w := int(parts[0])
			var h := int(parts[1])
			if w > 0 and h > 0:
				DisplayServer.window_set_size(Vector2i(w, h))


## Fija el idioma y lo persiste (reemplaza a ConfigHandler.save_language).
func save_locale(loc: String) -> void:
	TranslationServer.set_locale(loc)
	var cfg := ConfigFile.new()
	cfg.load(CFG_PATH)                            # ignora error si no existe
	cfg.set_value("general", "language", loc)
	cfg.save(CFG_PATH)


## Fundido a negro y de vuelta. Emite on_transition_finished en el punto oscuro.
func transition() -> void:
	if _busy:
		return
	_busy = true
	_rect.visible = true
	var t := create_tween()
	t.tween_property(_rect, "modulate:a", 1.0, FADE_TIME)
	await t.finished
	on_transition_finished.emit()
	var t2 := create_tween()
	t2.tween_property(_rect, "modulate:a", 0.0, FADE_TIME)
	await t2.finished
	_rect.visible = false
	_busy = false


## Fundido a negro, cambia de escena y vuelve.
func change_scene_to_file(target: String) -> void:
	_rect.visible = true
	var t := create_tween()
	t.tween_property(_rect, "modulate:a", 1.0, FADE_TIME)
	await t.finished
	if ResourceLoader.exists(target):
		get_tree().change_scene_to_file(target)
	var t2 := create_tween()
	t2.tween_property(_rect, "modulate:a", 0.0, FADE_TIME)
	await t2.finished
	_rect.visible = false
