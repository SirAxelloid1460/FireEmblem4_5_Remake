# SoundRoom.gd
# ============================================================
# SOUND ROOM — reproductor de la banda sonora, estilo FE.
# ============================================================
# Pantalla autocontenida (construida por código, como el resto de la UI).
# Lista las pistas de res://assets/music/, permite desplazarse y reproducir/
# parar la pista seleccionada. La abre MainMenu como overlay (señal `closed`).
#
# Controles:
#   ↑ / ↓   navegar       (ui_up / ui_down)
#   Accept  reproducir / parar la pista resaltada (toggle)
#   Cancel  volver al menú (emite `closed`)
#
# La música suena en el bus "Music" si existe (para que Options la controle).

extends Control
class_name SoundRoom

signal closed

const MUSIC_DIR  := "res://assets/music/"
const SERIF_FONT := "res://assets/fonts/IMFellFrenchCanonSC-Regular.ttf"
const SFX_NAV    := "res://assets/sfx/Select 5.ogg"
const WINDOW     := 12          # filas visibles a la vez

const COLOR_GOLD     := Color(1.00, 0.84, 0.36, 1.0)
const COLOR_GOLD_DIM := Color(0.70, 0.60, 0.30, 1.0)
const COLOR_TEXT     := Color(0.86, 0.88, 0.94, 1.0)
const COLOR_OUTLINE  := Color(0.0, 0.0, 0.0, 1.0)

var _tracks: Array[String] = []     # nombres de pista (sin extensión)
var _cursor: int = 0                 # índice seleccionado dentro de _tracks
var _scroll: int = 0                 # primer índice visible
var _playing: int = -1               # índice en reproducción (-1 = nada)

var _rows: Array[Label] = []
var _now_label: Label
var _player: AudioStreamPlayer
var _sfx: AudioStreamPlayer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scan_tracks()
	_build_ui()
	_build_audio()
	_refresh()


# ── Datos ────────────────────────────────────────────────────────────────────
## Escanea la carpeta de música y recoge los .ogg (ordenados por nombre).
func _scan_tracks() -> void:
	var dir := DirAccess.open(MUSIC_DIR)
	if dir == null:
		return
	var names: Array[String] = []
	dir.list_dir_begin()
	var fn := dir.get_next()
	while fn != "":
		if not dir.current_is_dir() and fn.to_lower().ends_with(".ogg"):
			names.append(fn.get_basename())
		fn = dir.get_next()
	dir.list_dir_end()
	names.sort()
	_tracks = names


# ── UI ───────────────────────────────────────────────────────────────────────
func _build_ui() -> void:
	# Fondo oscuro a pantalla completa.
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.04, 0.09, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# Panel central con borde dorado.
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.13, 0.96)
	sb.set_border_width_all(3)
	sb.border_color = COLOR_GOLD_DIM
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 36
	sb.content_margin_right = 36
	sb.content_margin_top = 28
	sb.content_margin_bottom = 24
	panel.add_theme_stylebox_override("panel", sb)
	panel.custom_minimum_size = Vector2(760, 660)
	panel.size = panel.custom_minimum_size
	panel.position = (get_viewport_rect().size - panel.custom_minimum_size) * 0.5
	add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	panel.add_child(vb)

	var font := load(SERIF_FONT)

	# Título.
	var title := Label.new()
	title.text = "Sound Room"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if font != null:
		title.add_theme_font_override("font", font)
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", COLOR_GOLD)
	title.add_theme_color_override("font_outline_color", COLOR_OUTLINE)
	title.add_theme_constant_override("outline_size", 5)
	vb.add_child(title)

	var sep := HSeparator.new()
	vb.add_child(sep)

	# Filas de la lista (se reutilizan; el texto/realce se actualiza en _refresh).
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 4)
	vb.add_child(list)
	for i in range(WINDOW):
		var row := Label.new()
		if font != null:
			row.add_theme_font_override("font", font)
		row.add_theme_font_size_override("font_size", 30)
		row.add_theme_color_override("font_color", COLOR_TEXT)
		row.add_theme_color_override("font_outline_color", COLOR_OUTLINE)
		row.add_theme_constant_override("outline_size", 3)
		row.clip_text = true
		list.add_child(row)
		_rows.append(row)

	# "Now playing".
	var sep2 := HSeparator.new()
	vb.add_child(sep2)
	_now_label = Label.new()
	_now_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if font != null:
		_now_label.add_theme_font_override("font", font)
	_now_label.add_theme_font_size_override("font_size", 24)
	_now_label.add_theme_color_override("font_color", COLOR_GOLD)
	_now_label.add_theme_color_override("font_outline_color", COLOR_OUTLINE)
	_now_label.add_theme_constant_override("outline_size", 3)
	vb.add_child(_now_label)

	# Pie de ayuda.
	var hint := Label.new()
	hint.text = "↑↓  Select        Accept  Play / Stop        Cancel  Back"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 18)
	hint.add_theme_color_override("font_color", COLOR_GOLD_DIM)
	vb.add_child(hint)


func _build_audio() -> void:
	_player = AudioStreamPlayer.new()
	if AudioServer.get_bus_index("Music") >= 0:
		_player.bus = "Music"
	add_child(_player)
	_sfx = AudioStreamPlayer.new()
	if AudioServer.get_bus_index("SFX") >= 0:
		_sfx.bus = "SFX"
	add_child(_sfx)


# ── Refresco ─────────────────────────────────────────────────────────────────
func _refresh() -> void:
	if _tracks.is_empty():
		_rows[0].text = "(no music found)"
		for i in range(1, _rows.size()):
			_rows[i].text = ""
		_now_label.text = ""
		return
	# Mantén el cursor dentro de la ventana visible.
	if _cursor < _scroll:
		_scroll = _cursor
	elif _cursor >= _scroll + WINDOW:
		_scroll = _cursor - WINDOW + 1
	for i in range(_rows.size()):
		var idx := _scroll + i
		var row := _rows[i]
		if idx >= _tracks.size():
			row.text = ""
			continue
		var marker := "  "
		if idx == _playing:
			marker = "♪ "
		var line := marker + _tracks[idx]
		if idx == _cursor:
			row.text = "► " + line
			row.add_theme_color_override("font_color", COLOR_GOLD)
		else:
			row.text = "   " + line
			row.add_theme_color_override("font_color", COLOR_TEXT)
	_now_label.text = ("Now Playing:  " + _tracks[_playing]) if _playing >= 0 else "— stopped —"


# ── Input ────────────────────────────────────────────────────────────────────
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_stop()
		closed.emit()
		get_viewport().set_input_as_handled()
		return
	if _tracks.is_empty():
		return
	if event.is_action_pressed("ui_up"):
		_move_cursor(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down"):
		_move_cursor(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		_toggle_play()
		get_viewport().set_input_as_handled()


func _move_cursor(step: int) -> void:
	_cursor = wrapi(_cursor + step, 0, _tracks.size())
	_play_nav_sfx()
	_refresh()


## Reproduce la pista resaltada; si ya sonaba, la para (toggle).
func _toggle_play() -> void:
	if _cursor == _playing:
		_stop()
		_refresh()
		return
	var path := MUSIC_DIR + _tracks[_cursor] + ".ogg"
	if not ResourceLoader.exists(path):
		return
	var stream = load(path)
	if "loop" in stream:
		stream.loop = true
	_player.stream = stream
	_player.play()
	_playing = _cursor
	_refresh()


func _stop() -> void:
	if _player != null:
		_player.stop()
	_playing = -1


func _play_nav_sfx() -> void:
	if _sfx == null or not ResourceLoader.exists(SFX_NAV):
		return
	_sfx.stream = load(SFX_NAV)
	_sfx.play()
