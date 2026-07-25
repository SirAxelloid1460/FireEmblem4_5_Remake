# SoundRoom.gd
# ============================================================
# SOUND ROOM — reproductor de la banda sonora, estilo FE (GBA).
# ============================================================
# Pantalla autocontenida (construida por código). Layout inspirado en la Sound
# Room de FE8: barra de título con el NOMBRE de la pista, a la izquierda el asset
# "reproductor" (sound_player.png) con leyenda de controles sobre su cuerpo BLANCO
# y un VISUALIZADOR de onda pixelado (reactivo al audio) sobre su PANTALLA AZUL, y
# un GRID NUMERADO de pistas a la derecha con cursor-mano. PESTAÑAS FE4/FE5
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

# Panel izquierdo = asset "reproductor". Regiones en px del PNG (73×112):
#   pantalla azul (onda) arriba; cuerpo blanco (controles) debajo.
const SP_IMG   := "res://assets/menus/sound_player.png"
const SP_SCALE := 4
const SP_BLUE  := Rect2(2, 4, 65, 16)      # pantalla (visualizador de onda)
const SP_WHITE := Rect2(4, 25, 63, 74)     # cuerpo (leyenda de controles)
# Texto sobre fondo BLANCO del asset → colores OSCUROS.
const COLOR_KEY_DARK := Color(0.55, 0.40, 0.08, 1.0)   # tecla (dorado oscuro)
const COLOR_ACT_DARK := Color(0.16, 0.16, 0.22, 1.0)   # acción (casi negro)
# Visualizador de onda pixelado (reacciona al audio del bus Music).
const WAVE_BARS  := 26
const WAVE_COLOR := Color(0.314, 0.157, 0.0, 1.0)   # marrón del borde del panel
const WAVE_MIN_F := 45.0
const WAVE_MAX_F := 11000.0

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
# Dimensiones de celda (se APRIETAN al ancho del panel derecho en _build_ui).
var _cw: float = CELL_W
var _ch: float = CELL_H
var _chs: float = CELL_HSEP
var _cvs: float = CELL_VSEP
var _num_fs: int = 40
var _player: AudioStreamPlayer
var _sfx: AudioStreamPlayer

# Visualizador de onda.
var _bars: Array = []                # ColorRect por barra
var _bar_h: Array = []               # altura suavizada por barra
var _wave_bx: float = 0.0            # x inicial de las barras
var _wave_cy: float = 0.0            # línea central (vertical)
var _wave_bar_w: float = 0.0
var _wave_gap: float = 2.0
var _wave_max_h: float = 0.0         # altura máxima (pico → bordes de la pantalla)
var _spectrum: AudioEffectSpectrumAnalyzerInstance = null
var _fx_bus: int = -1
var _fx_added: bool = false          # si añadimos el analizador (para quitarlo al salir)


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
	var content_h: float = vp.y - top - 24

	# ── Panel IZQUIERDO: asset "reproductor" a ALTURA COMPLETA, escala UNIFORME
	# (proporcional, sin deformar). Su ancho define la columna izquierda; el panel
	# de la lista (derecha) se aprieta con el espacio restante. ──
	var f: float = content_h / 112.0
	var sp_x: float = 24.0
	var sp_y: float = top
	var sp_w: float = 73.0 * f
	var sp_h: float = content_h
	var left_w: float = sp_w
	var player_img := TextureRect.new()
	player_img.texture = load(AssetSet.p(SP_IMG))
	player_img.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	player_img.stretch_mode = TextureRect.STRETCH_SCALE
	player_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	player_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player_img.position = Vector2(sp_x, sp_y)
	player_img.size = Vector2(sp_w, sp_h)
	add_child(player_img)
	var fx: float = f
	var fy: float = f

	# Visualizador de onda sobre la PANTALLA AZUL (barras pixeladas, reactivas).
	var bx: float = sp_x + SP_BLUE.position.x * fx
	var by: float = sp_y + SP_BLUE.position.y * fy
	var bw: float = SP_BLUE.size.x * fx
	var bh: float = SP_BLUE.size.y * fy
	_wave_bar_w = (bw - (WAVE_BARS - 1) * _wave_gap) / WAVE_BARS
	_wave_bx = bx
	_wave_cy = by + bh / 2.0
	_wave_max_h = bh
	for i in range(WAVE_BARS):
		var bar := ColorRect.new()
		bar.color = WAVE_COLOR
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.position = Vector2(bx + i * (_wave_bar_w + _wave_gap), _wave_cy - 1)
		bar.size = Vector2(_wave_bar_w, 2)
		add_child(bar)
		_bars.append(bar)
		_bar_h.append(2.0)

	# Leyenda de controles sobre el CUERPO BLANCO (texto oscuro), repartida en alto.
	var wx: float = sp_x + SP_WHITE.position.x * fx
	var wy: float = sp_y + SP_WHITE.position.y * fy
	var ww: float = SP_WHITE.size.x * fx
	var wh: float = SP_WHITE.size.y * fy
	var legend := [
		["ui_accept", "Play"], ["ui_start", "Stop"], ["ui_select", "Random"],
		["ui_page_left", "< FE"], ["ui_page_right", "FE >"],
	]
	var fs: int = 34
	var row_h: float = wh / legend.size()
	for i in range(legend.size()):
		var entry: Array = legend[i]
		var ry: float = wy + i * row_h + (row_h - fs) / 2.0
		var k := _label(InputConfig.key_label(str(entry[0])), fs, COLOR_KEY_DARK, 2)
		k.position = Vector2(wx + 12, ry)
		k.size = Vector2(ww * 0.55, fs + 10)
		k.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		add_child(k)
		var a := _label(str(entry[1]), fs, COLOR_ACT_DARK, 2)
		a.position = Vector2(wx + 12 + ww * 0.55, ry)
		a.size = Vector2(ww * 0.45 - 12, fs + 10)
		a.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		add_child(a)

	# ── Panel DERECHO (lista): se APRIETA con el espacio que deja el panel izq. ──
	var rx: float = 24 + left_w + 16
	var rw: float = vp.x - rx - 24
	var rpanel := _nine(PANEL, 24, 30, true)
	rpanel.position = Vector2(rx, top)
	rpanel.size = Vector2(rw, content_h)
	add_child(rpanel)

	# Escala del grid para que quepa apretado en el ancho disponible (nunca amplía).
	var nat_gw: float = COLS * CELL_W + (COLS - 1) * CELL_HSEP
	var gs: float = clampf((rw - 96.0) / nat_gw, 0.5, 1.0)
	_cw = CELL_W * gs
	_ch = CELL_H * gs
	_chs = CELL_HSEP * gs
	_cvs = CELL_VSEP * gs
	_num_fs = maxi(26, int(40 * gs))

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

	# Grid numerado (ventana COLS×ROWS), apretado y centrado en el panel.
	_grid_root = Control.new()
	var grid_w: float = COLS * _cw + (COLS - 1) * _chs
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
	root.position = Vector2(c * (_cw + _chs), r * (_ch + _cvs))
	root.size = Vector2(_cw, _ch)
	var hi := ColorRect.new()      # realce de fondo (celda seleccionada)
	hi.color = Color(0.30, 0.45, 0.62, 0.0)
	hi.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hi.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hi)
	var num := _label("", _num_fs, COLOR_TEXT, 4)
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
			vc * (_cw + _chs) - 56,
			vr * (_ch + _cvs) + (_ch - 48) / 2.0)
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
	# Copia propia: el mismo recurso lo cachea load() y el MENÚ le pone loop_offset
	# (30.5/13.5). Duplicando + loop_offset 0, el SoundRoom loopea desde el principio.
	var stream = load(path)
	if stream != null:
		stream = stream.duplicate()
	if "loop" in stream:
		stream.loop = true
	if "loop_offset" in stream:
		stream.loop_offset = 0.0
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
	_setup_spectrum()


## Analizador de espectro en el bus Music (para el visualizador de onda). Si no
## existe, lo añade (y lo marca para quitarlo al salir).
func _setup_spectrum() -> void:
	_fx_bus = AudioServer.get_bus_index("Music")
	if _fx_bus < 0:
		return
	var idx: int = -1
	for i in range(AudioServer.get_bus_effect_count(_fx_bus)):
		if AudioServer.get_bus_effect(_fx_bus, i) is AudioEffectSpectrumAnalyzer:
			idx = i
			break
	if idx < 0:
		AudioServer.add_bus_effect(_fx_bus, AudioEffectSpectrumAnalyzer.new())
		idx = AudioServer.get_bus_effect_count(_fx_bus) - 1
		_fx_added = true
	var inst := AudioServer.get_bus_effect_instance(_fx_bus, idx)
	if inst is AudioEffectSpectrumAnalyzerInstance:
		_spectrum = inst


## Quita el analizador del bus si lo añadimos nosotros (no dejar efectos sueltos).
func _exit_tree() -> void:
	if _fx_added and _fx_bus >= 0:
		for i in range(AudioServer.get_bus_effect_count(_fx_bus) - 1, -1, -1):
			if AudioServer.get_bus_effect(_fx_bus, i) is AudioEffectSpectrumAnalyzer:
				AudioServer.remove_bus_effect(_fx_bus, i)
				break


## Actualiza las barras del visualizador desde el espectro (cada frame).
func _process(_delta: float) -> void:
	if _spectrum == null or _bars.is_empty():
		return
	for i in range(WAVE_BARS):
		var lo: float = WAVE_MIN_F * pow(WAVE_MAX_F / WAVE_MIN_F, float(i) / WAVE_BARS)
		var hi: float = WAVE_MIN_F * pow(WAVE_MAX_F / WAVE_MIN_F, float(i + 1) / WAVE_BARS)
		var mag: float = _spectrum.get_magnitude_for_frequency_range(lo, hi).length()
		# -65 dB..0 dB → 0..1; escalado a la altura de la pantalla.
		var energy: float = clampf((65.0 + linear_to_db(maxf(mag, 0.0000001))) / 65.0, 0.0, 1.0)
		var target: float = maxf(2.0, energy * _wave_max_h)
		_bar_h[i] = lerpf(float(_bar_h[i]), target, 0.35)   # suavizado
		var bar: ColorRect = _bars[i]
		var h: float = _bar_h[i]
		bar.size.y = h
		bar.position.y = _wave_cy - h / 2.0    # simétrica respecto al centro


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
