# SoundRoom.gd
# ============================================================
# SOUND ROOM — reproductor de la banda sonora, estilo FE (GBA).
# ============================================================
# Pantalla autocontenida (construida por código). Layout inspirado en la Sound
# Room de FE8: barra de título con el NOMBRE de la pista, panel de controles a la
# izquierda (Play/Stop/Random) + preview, y un GRID NUMERADO de pistas a la
# derecha con cursor-mano. PESTAÑAS FE4/FE5 para separar la música de cada juego
# (se leen de res://assets/music/fe4 y .../fe5, re-enraizadas por AssetSet).
#
# Controles:
#   ↑↓←→   navegar el grid
#   L / R  (ui_page_left/right)  cambiar de pestaña FE4/FE5
#   Accept reproducir / parar la pista resaltada (toggle)   [Ⓐ Play]
#   Start  parar                                            [START Stop]
#   Select pista aleatoria                                  [SELECT Random]
#   Cancel volver al menú (emite `closed`)
#
# La música suena en el bus "Music" (para que Options la controle).

extends Control
class_name SoundRoom

signal closed

const TABS := [
	{ "id": "fe4", "label": "FE4", "dir": "res://assets/music/fe4/" },
	{ "id": "fe5", "label": "FE5", "dir": "res://assets/music/fe5/" },
]

const UI_FONT   := "res://assets/fonts/bmp/text.fnt"
const BG_BASE   := "res://assets/panoramas/default_background.png"
const PANEL     := "res://assets/menus/menu_box_6x.png"       # panel ornamentado
const TITLE_BG  := "res://assets/menus/menu_bg_white.png"     # placa clara (título)
const HAND      := "res://assets/menus/menu_hand.png"         # cursor-mano
const SFX_NAV   := "res://assets/sfx/Select 5.ogg"
const SFX_OK    := "res://assets/sfx/Select 4.ogg"

const COLS := 4                      # columnas del grid
const ROWS := 5                      # filas visibles del grid (ventana)
const CELL_W := 132.0
const CELL_H := 68.0
const CELL_HSEP := 14.0
const CELL_VSEP := 12.0

const COLOR_GOLD     := Color(1.00, 0.84, 0.36, 1.0)
const COLOR_GOLD_DIM := Color(0.62, 0.54, 0.30, 1.0)
const COLOR_TEXT     := Color(0.88, 0.90, 0.94, 1.0)
const COLOR_DIM      := Color(0.55, 0.58, 0.66, 1.0)
const COLOR_OUTLINE  := Color(0.05, 0.05, 0.10, 1.0)

var _tab: int = 0                    # pestaña activa (índice en TABS)
var _tracks: Array[String] = []      # pistas de la pestaña activa (sin extensión)
var _cursor: int = 0                 # índice seleccionado dentro de _tracks
var _row_scroll: int = 0             # primera FILA visible del grid
var _playing: int = -1               # índice en reproducción (-1 = nada)
var _playing_tab: int = -1           # pestaña de la pista en reproducción

var _font: Font
var _title_lbl: Label                # nombre de la pista seleccionada (barra sup.)
var _num_lbl: Label                  # número de la pista seleccionada
var _tab_lbls: Array[Label] = []     # rótulos de pestañas FE4/FE5
var _cells: Array = []               # celdas del grid: { root, num, hi }
var _hand: TextureRect               # cursor-mano
var _grid_root: Control              # contenedor del grid (para posicionar la mano)
var _player: AudioStreamPlayer
var _sfx: AudioStreamPlayer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_font = load(AssetSet.p(UI_FONT))
	_build_bg()
	_build_audio()
	_build_ui()
	_load_tab(0)


# ── Datos ────────────────────────────────────────────────────────────────────
## Escanea la carpeta de la pestaña `t` y carga sus pistas (ordenadas).
func _scan(t: int) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(AssetSet.p(str(TABS[t]["dir"])))
	if dir == null:
		return out
	dir.list_dir_begin()
	var fn := dir.get_next()
	while fn != "":
		if not dir.current_is_dir() and fn.to_lower().ends_with(".mp3"):
			out.append(fn.get_basename())
		fn = dir.get_next()
	dir.list_dir_end()
	out.sort()
	return out


func _load_tab(t: int) -> void:
	_tab = t
	_tracks = _scan(t)
	_cursor = 0
	_row_scroll = 0
	for i in range(_tab_lbls.size()):
		_tab_lbls[i].add_theme_color_override("font_color", COLOR_GOLD if i == t else COLOR_DIM)
	_refresh()


# ── UI ───────────────────────────────────────────────────────────────────────
func _build_bg() -> void:
	var base := ColorRect.new()
	base.color = Color(0.04, 0.05, 0.09, 1.0)
	base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(base)
	var img := TextureRect.new()
	img.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	img.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	img.modulate = Color(1, 1, 1, 0.5)
	var bp := AssetSet.p(BG_BASE)
	if ResourceLoader.exists(bp):
		img.texture = load(bp)
	add_child(img)


func _build_ui() -> void:
	var vp: Vector2 = get_viewport_rect().size

	# ── Barra de título: nombre de la pista seleccionada (grande, arriba) ──
	var title_w: float = vp.x - 24 * 2
	var title_root := _nine(TITLE_BG, 8)
	title_root.position = Vector2(24, 16)
	title_root.size = Vector2(title_w, 96)
	title_root.modulate.a = 0.9
	add_child(title_root)
	_title_lbl = _label("", 60, COLOR_GOLD, 4)
	_title_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title_root.add_child(_title_lbl)

	var top: float = 16 + 96 + 14
	var left_w: float = 340.0
	var content_h: float = vp.y - top - 24

	# ── Panel IZQUIERDO: preview + leyenda de controles ──
	var lpanel := _nine(PANEL, 24, 30, true)
	lpanel.position = Vector2(24, top)
	lpanel.size = Vector2(left_w, content_h)
	add_child(lpanel)
	# Recuadro de "preview" (placeholder azul).
	var preview := ColorRect.new()
	preview.color = Color(0.30, 0.45, 0.62, 1.0)
	preview.position = Vector2(40, 40)
	preview.size = Vector2(left_w - 80, 120)
	lpanel.add_child(preview)
	# Leyenda de controles (tecla vinculada + acción).
	var legend := [
		["ui_accept", "Play"], ["ui_start", "Stop"], ["ui_select", "Random"],
		["ui_page_left", "< FE"], ["ui_page_right", "FE >"],
	]
	var ly: float = 190.0
	for entry in legend:
		var k := _label(InputConfig.key_label(str(entry[0])), 34, COLOR_GOLD, 4)
		k.position = Vector2(40, ly)
		k.size = Vector2(120, 46)
		k.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		lpanel.add_child(k)
		var a := _label(str(entry[1]), 34, COLOR_TEXT, 4)
		a.position = Vector2(168, ly)
		a.size = Vector2(left_w - 200, 46)
		a.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		lpanel.add_child(a)
		ly += 58.0

	# ── Panel DERECHO: sub-cabecera (nombre + número) + pestañas + grid ──
	var rx: float = 24 + left_w + 16
	var rw: float = vp.x - rx - 24
	var rpanel := _nine(PANEL, 24, 30, true)
	rpanel.position = Vector2(rx, top)
	rpanel.size = Vector2(rw, content_h)
	add_child(rpanel)

	# Pestañas FE4 / FE5 (arriba del panel derecho).
	var tx: float = 40.0
	for i in range(TABS.size()):
		var tl := _label(str(TABS[i]["label"]), 40, COLOR_DIM, 4)
		tl.position = Vector2(tx, 24)
		tl.size = Vector2(120, 52)
		tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rpanel.add_child(tl)
		_tab_lbls.append(tl)
		tx += 140.0
	# Nombre + número de la pista seleccionada (a la derecha de las pestañas).
	_num_lbl = _label("", 40, COLOR_GOLD, 4)
	_num_lbl.position = Vector2(rw - 120, 24)
	_num_lbl.size = Vector2(80, 52)
	_num_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rpanel.add_child(_num_lbl)

	# Grid numerado (ventana COLS×ROWS).
	_grid_root = Control.new()
	var grid_w: float = COLS * CELL_W + (COLS - 1) * CELL_HSEP
	_grid_root.position = Vector2((rw - grid_w) / 2.0, 96)
	rpanel.add_child(_grid_root)
	for r in range(ROWS):
		for c in range(COLS):
			var cell := _make_cell(c, r)
			_grid_root.add_child(cell["root"])
			_cells.append(cell)

	# Cursor-mano.
	_hand = TextureRect.new()
	_hand.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_hand.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_hand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hp := AssetSet.p(HAND)
	if ResourceLoader.exists(hp):
		_hand.texture = load(hp)
	_hand.size = Vector2(60, 48)
	_grid_root.add_child(_hand)


## Celda del grid: placa con el número de pista. Devuelve { root, num, hi }.
func _make_cell(c: int, r: int) -> Dictionary:
	var root := Control.new()
	root.position = Vector2(c * (CELL_W + CELL_HSEP), r * (CELL_H + CELL_VSEP))
	root.size = Vector2(CELL_W, CELL_H)
	var hi := ColorRect.new()      # realce de fondo (celda seleccionada)
	hi.color = Color(0.30, 0.45, 0.62, 0.0)
	hi.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hi.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hi)
	var num := _label("", 40, COLOR_TEXT, 4)
	num.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(num)
	return { "root": root, "num": num, "hi": hi }


# ── Refresco ─────────────────────────────────────────────────────────────────
func _refresh() -> void:
	# Cabecera: nombre y número de la pista seleccionada.
	if _tracks.is_empty():
		_title_lbl.text = "(no music in %s)" % str(TABS[_tab]["label"])
		_num_lbl.text = ""
	else:
		_title_lbl.text = _tracks[_cursor]
		_num_lbl.text = "%02d" % (_cursor + 1)

	# Mantén el cursor dentro de la ventana de filas visibles.
	var cur_row: int = _cursor / COLS
	if cur_row < _row_scroll:
		_row_scroll = cur_row
	elif cur_row >= _row_scroll + ROWS:
		_row_scroll = cur_row - ROWS + 1

	# Rellena las celdas visibles.
	for i in range(_cells.size()):
		var r: int = i / COLS
		var c: int = i % COLS
		var idx: int = (_row_scroll + r) * COLS + c
		var cell: Dictionary = _cells[i]
		var num: Label = cell["num"]
		var hi: ColorRect = cell["hi"]
		if idx >= _tracks.size():
			num.text = ""
			hi.color.a = 0.0
			continue
		num.text = "%02d" % (idx + 1)
		var is_cur: bool = (idx == _cursor)
		var is_play: bool = (idx == _playing and _tab == _playing_tab)
		hi.color.a = 0.55 if is_cur else 0.0
		num.add_theme_color_override("font_color",
			COLOR_GOLD if is_play else (Color.WHITE if is_cur else COLOR_TEXT))

	# Posiciona la mano a la izquierda de la celda seleccionada.
	if not _tracks.is_empty():
		var vr: int = (_cursor / COLS) - _row_scroll
		var vc: int = _cursor % COLS
		_hand.visible = true
		_hand.position = Vector2(
			vc * (CELL_W + CELL_HSEP) - 56,
			vr * (CELL_H + CELL_VSEP) + (CELL_H - 48) / 2.0)
	else:
		_hand.visible = false


# ── Input ────────────────────────────────────────────────────────────────────
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_stop()
		closed.emit()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_page_left"):
		_switch_tab(-1); get_viewport().set_input_as_handled(); return
	if event.is_action_pressed("ui_page_right"):
		_switch_tab(1); get_viewport().set_input_as_handled(); return
	if event.is_action_pressed("ui_start"):
		_stop(); _refresh(); get_viewport().set_input_as_handled(); return
	if event.is_action_pressed("ui_select"):
		_random(); get_viewport().set_input_as_handled(); return
	if _tracks.is_empty():
		return
	if event.is_action_pressed("ui_up"):
		_move(-COLS); get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down"):
		_move(COLS); get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_left"):
		_move(-1); get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right"):
		_move(1); get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		_toggle_play(); get_viewport().set_input_as_handled()


func _switch_tab(step: int) -> void:
	var n := TABS.size()
	_play_sfx(SFX_NAV)
	_load_tab((_tab + step + n) % n)


func _move(step: int) -> void:
	_cursor = wrapi(_cursor + step, 0, _tracks.size())
	_play_sfx(SFX_NAV)
	_refresh()


func _random() -> void:
	if _tracks.is_empty():
		return
	_cursor = randi() % _tracks.size()
	_play_sfx(SFX_OK)
	_play_current()
	_refresh()


func _toggle_play() -> void:
	if _cursor == _playing and _tab == _playing_tab:
		_stop()
		_refresh()
		return
	_play_sfx(SFX_OK)
	_play_current()
	_refresh()


func _play_current() -> void:
	var path := AssetSet.p(str(TABS[_tab]["dir"]) + _tracks[_cursor] + ".mp3")
	if not ResourceLoader.exists(path):
		return
	var stream = load(path)
	if "loop" in stream:
		stream.loop = true
	_player.stream = stream
	_player.play()
	_playing = _cursor
	_playing_tab = _tab


func _stop() -> void:
	if _player != null:
		_player.stop()
	_playing = -1
	_playing_tab = -1


# ── Audio / helpers ──────────────────────────────────────────────────────────
func _build_audio() -> void:
	_player = AudioStreamPlayer.new()
	if AudioServer.get_bus_index("Music") >= 0:
		_player.bus = "Music"
	add_child(_player)
	_sfx = AudioStreamPlayer.new()
	if AudioServer.get_bus_index("SFX") >= 0:
		_sfx.bus = "SFX"
	add_child(_sfx)


func _play_sfx(path: String) -> void:
	var p := AssetSet.p(path)
	if _sfx == null or not ResourceLoader.exists(p):
		return
	_sfx.stream = load(p)
	_sfx.play()


func _nine(tex_path: String, m: int, mv: int = -1, tile: bool = false) -> NinePatchRect:
	var n := NinePatchRect.new()
	n.texture = load(AssetSet.p(tex_path))
	n.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	n.patch_margin_left = m
	n.patch_margin_right = m
	n.patch_margin_top = m if mv < 0 else mv
	n.patch_margin_bottom = m if mv < 0 else mv
	if tile:
		n.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_TILE_FIT
		n.axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_TILE_FIT
	return n


func _label(text: String, fs: int, col: Color, outline: int) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	l.auto_translate_mode = Control.AUTO_TRANSLATE_MODE_DISABLED
	if _font != null:
		l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", COLOR_OUTLINE)
	l.add_theme_constant_override("outline_size", outline)
	return l
