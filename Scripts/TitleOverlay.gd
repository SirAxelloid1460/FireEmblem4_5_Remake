class_name TitleOverlay
extends TextureRect

# ============================================================
# TitleOverlay — niebla/nubes animada decorativa (title_background).
# ============================================================
# Overlay TRANSPARENTE a pantalla completa que se reproduce ENCIMA del fondo de
# los menús de arranque y del menú principal (mismo elemento en los tres, para
# dar continuidad visual). No captura ratón.
#
# title_background.png es una hoja 1440×960 = grid 6×6, 33 frames de 240×160,
# reproducidos a 8 fps en bucle. Las zonas negras del PNG son transparentes.
#
# Uso: add_child(TitleOverlay.new()) justo DESPUÉS del fondo y ANTES de la UI,
# para que la niebla flote sobre el fondo sin tapar botones/paneles.
# ============================================================

const SHEET := "res://assets/panoramas/title_background.png"
const COLS := 6
const FW := 240
const FH := 160
const FRAME_COUNT := 33
const FPS := 8.0

var _frames: Array = []
var _i: int = 0
var _accum: float = 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not ResourceLoader.exists(SHEET):
		return
	var sheet: Texture2D = load(SHEET)
	for n in FRAME_COUNT:
		var at := AtlasTexture.new()
		at.atlas = sheet
		at.region = Rect2((n % COLS) * FW, (n / COLS) * FH, FW, FH)
		_frames.append(at)
	if _frames.size() > 0:
		texture = _frames[0]


func _process(delta: float) -> void:
	if _frames.size() <= 1:
		return
	_accum += delta
	var frame_time := 1.0 / FPS
	while _accum >= frame_time:
		_accum -= frame_time
		_i = (_i + 1) % _frames.size()
		texture = _frames[_i]
