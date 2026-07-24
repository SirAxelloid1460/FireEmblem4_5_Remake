# SettingsBoot — aplica los ajustes persistidos (user://settings.cfg) al ARRANCAR
# el juego, no solo al abrir el menú de opciones.
#
# Antes, el volumen de audio solo se aplicaba en OptionsMenu._ready y la
# ventana/resolución solo al cambiarlas → al cargar el juego los ajustes guardados
# no tenían efecto hasta entrar en Opciones. Este autoload los aplica en el boot.
#
# (El ratón lo aplica InputConfig en su propio _ready; el set gráfico lo resuelve
# AssetSet en vivo, así que no requieren acción aquí.)
extends Node

const CFG := "user://settings.cfg"
# Debe coincidir con OptionsMenu.RESOLUTIONS (mismo orden/índices).
const RESOLUTIONS := ["720x480", "960x640", "1200x800", "1440x960", "1920x1280"]


func _ready() -> void:
	var cfg := ConfigFile.new()
	cfg.load(CFG)   # si no existe, get_value devuelve los defaults (mismos que Opciones)

	# ── Audio: volumen de los buses Music/SFX ──
	_apply_bus("Music", int(cfg.get_value("audio", "music_volume", 70)))
	_apply_bus("SFX", int(cfg.get_value("audio", "sfx_volume", 80)))

	# ── Pantalla: modo de ventana + resolución ──
	var res_idx: int = int(cfg.get_value("display", "resolution", 2))
	var win_mode: int = int(cfg.get_value("display", "window_mode", 0))
	_apply_window_mode(win_mode, res_idx)


func _apply_bus(bus_name: String, value_0_100: int) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(clampf(value_0_100 / 100.0, 0.0001, 1.0)))


## 0 Windowed · 1 Borderless · 2 Fullscreen (mismo mapeo que OptionsMenu).
func _apply_window_mode(idx: int, res_idx: int) -> void:
	match idx:
		1:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
			_apply_resolution(res_idx)
		2:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		_:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			_apply_resolution(res_idx)


func _apply_resolution(idx: int) -> void:
	if idx < 0 or idx >= RESOLUTIONS.size():
		return
	var parts := str(RESOLUTIONS[idx]).split("x")
	if parts.size() != 2:
		return
	var w := int(parts[0])
	var h := int(parts[1])
	if w <= 0 or h <= 0:
		return
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		return
	DisplayServer.window_set_size(Vector2i(w, h))
	var scr := DisplayServer.window_get_current_screen()
	var scr_pos := DisplayServer.screen_get_position(scr)
	var scr_size := DisplayServer.screen_get_size(scr)
	DisplayServer.window_set_position(scr_pos + (scr_size - Vector2i(w, h)) / 2)
