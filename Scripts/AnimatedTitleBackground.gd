# AnimatedTitleBackground.gd
# Reproduce un panorama multi-frame del LT (compuesto en spritesheet) como
# fondo animado.  Diseñado para el title_background del menú principal.
#
# === USO ===
#
# 1. Procesar los frames con build_panorama_sheet.py para obtener:
#    res://assets/panoramas/title_background.png  (sheet en grid 6×6)
#    res://assets/panoramas/title_background.json (metadata: fps, frames, etc.)
#
# 2. En el MainMenu reemplazar el TextureRect "Background" por un Sprite2D
#    con este script adjunto.  Tamaño y posición se ajustan automáticamente
#    para llenar la pantalla.
#
# 3. Configurar `panorama_nid` por inspector si quieres usar un panorama
#    distinto (ej. "BaseBackground").  Default: "title_background".
#
# === FUNCIONAMIENTO ===
#
# Carga el JSON, lee frame_count + grid + fps, y va cambiando el region
# del AtlasTexture cada 1/fps segundos sin recargar la textura subyacente.
# Esto evita texture swaps y es prácticamente gratis a nivel de GPU.

class_name AnimatedTitleBackground
extends Sprite2D


## NID del panorama a reproducir (sin extensión).  El sheet y JSON deben
## existir en `panoramas_root` con ese nombre.
@export var panorama_nid: String = "title_background"

## Carpeta donde están los sheets de panoramas.
@export var panoramas_root: String = "res://assets/panoramas/"

## Si true, escala el sprite para llenar la viewport.  Si false, mantiene
## el tamaño nativo del frame (240×160 canon GBA).
@export var fill_viewport: bool = true

## Override del FPS del JSON.  Si es 0, se usa el del JSON (default 8).
@export var fps_override: int = 0

## Si true, reproduce en bucle.  Si false, se queda fijo en el último
## frame al terminar.  Override del JSON.
@export_enum("Use JSON", "Force loop", "Force no-loop")
var loop_mode: int = 0


# Estado interno.
var _sheet_data: Dictionary = {}
var _atlas: AtlasTexture = null
var _frame_w: int = 0
var _frame_h: int = 0
var _grid_cols: int = 1
var _grid_rows: int = 1
var _frame_count: int = 0
var _fps: int = 8
var _loop: bool = true

var _current_frame: int = 0
var _timer: float = 0.0
var _is_playing: bool = false


func _ready() -> void:
	# Pixel-perfect, sin filtro suavizado.
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	centered = false
	if not _load_panorama():
		push_warning("AnimatedTitleBackground: no se pudo cargar '%s'" % panorama_nid)
		return
	if fill_viewport:
		_update_scale_to_viewport()
		# Reescalar si la ventana cambia de tamaño.
		get_tree().root.size_changed.connect(_update_scale_to_viewport)
	_is_playing = true
	_apply_current_frame()


func _process(delta: float) -> void:
	if not _is_playing or _frame_count <= 1 or _fps <= 0:
		return
	_timer += delta
	var frame_duration: float = 1.0 / float(_fps)
	while _timer >= frame_duration:
		_timer -= frame_duration
		_advance_frame()


# ══════════════════════════════════════════════════════════════════════════════
# CARGA Y LAYOUT
# ══════════════════════════════════════════════════════════════════════════════

## Carga la sheet y el JSON.  Devuelve true si todo OK.
func _load_panorama() -> bool:
	var sheet_path := AssetSet.p("%s%s.png" % [panoramas_root, panorama_nid])
	var json_path := AssetSet.p("%s%s.json" % [panoramas_root, panorama_nid])

	if not ResourceLoader.exists(sheet_path):
		push_warning("Sheet no encontrada: %s" % sheet_path)
		return false
	var sheet: Texture2D = load(sheet_path) as Texture2D
	if sheet == null:
		return false

	# JSON puede no existir si es un panorama de 1 frame (singleton estático).
	# En ese caso usamos defaults y mostramos la imagen completa fija.
	if FileAccess.file_exists(json_path):
		var raw := FileAccess.get_file_as_string(json_path)
		var parsed = JSON.parse_string(raw)
		if parsed is Dictionary:
			_sheet_data = parsed
	if _sheet_data.is_empty():
		# Fallback: imagen completa, 1 frame, sin animación.
		_sheet_data = {
			"frame_count": 1,
			"frame_size": [sheet.get_width(), sheet.get_height()],
			"grid": [1, 1],
			"fps": 1,
			"loop": false,
		}

	_frame_count = int(_sheet_data.get("frame_count", 1))
	var fsize: Array = _sheet_data.get("frame_size", [sheet.get_width(), sheet.get_height()])
	_frame_w = int(fsize[0])
	_frame_h = int(fsize[1])
	var grid: Array = _sheet_data.get("grid", [_frame_count, 1])
	_grid_cols = int(grid[0])
	_grid_rows = int(grid[1])
	_fps = fps_override if fps_override > 0 else int(_sheet_data.get("fps", 8))
	# Loop según preferencia exportada.
	match loop_mode:
		1: _loop = true
		2: _loop = false
		_: _loop = bool(_sheet_data.get("loop", true))

	# Crear AtlasTexture y asignarlo como textura del sprite.
	_atlas = AtlasTexture.new()
	_atlas.atlas = sheet
	_atlas.region = Rect2(0, 0, _frame_w, _frame_h)
	texture = _atlas
	return true


## Avanza al siguiente frame respetando el modo loop.
func _advance_frame() -> void:
	_current_frame += 1
	if _current_frame >= _frame_count:
		if _loop:
			_current_frame = 0
		else:
			_current_frame = _frame_count - 1
			_is_playing = false
	_apply_current_frame()


## Aplica el frame actual al region del AtlasTexture.
func _apply_current_frame() -> void:
	if _atlas == null:
		return
	var col: int = _current_frame % _grid_cols
	var row: int = _current_frame / _grid_cols
	_atlas.region = Rect2(col * _frame_w, row * _frame_h, _frame_w, _frame_h)


## Escala el sprite para que llene la viewport manteniendo el aspect ratio
## del frame.  Si la viewport es más ancha que el frame, hay padding lateral
## (el frame se centra horizontal/verticalmente).
func _update_scale_to_viewport() -> void:
	if _frame_w <= 0 or _frame_h <= 0:
		return
	var vp_size: Vector2 = get_viewport_rect().size
	var sx: float = vp_size.x / float(_frame_w)
	var sy: float = vp_size.y / float(_frame_h)
	# Usar la escala MAYOR para llenar (cropping aceptable en menús).
	# Si prefieres letterbox, cambia max() por min().
	var s: float = max(sx, sy)
	scale = Vector2(s, s)
	# Centrar el sprite en la viewport.
	position = (vp_size - Vector2(_frame_w, _frame_h) * s) * 0.5


# ══════════════════════════════════════════════════════════════════════════════
# API PÚBLICA
# ══════════════════════════════════════════════════════════════════════════════

## Pausa la animación en el frame actual.
func pause() -> void:
	_is_playing = false


## Reanuda la animación.
func play() -> void:
	_is_playing = true


## Salta a un frame específico (útil para testing o efectos).
func goto_frame(frame_idx: int) -> void:
	_current_frame = clamp(frame_idx, 0, _frame_count - 1)
	_timer = 0.0
	_apply_current_frame()


## Cambia el panorama en runtime sin recrear el nodo.
func switch_panorama(new_nid: String) -> void:
	panorama_nid = new_nid
	_current_frame = 0
	_timer = 0.0
	_load_panorama()
	if fill_viewport:
		_update_scale_to_viewport()
	_apply_current_frame()
	_is_playing = true
