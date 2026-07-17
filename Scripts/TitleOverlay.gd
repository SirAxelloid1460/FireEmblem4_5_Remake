class_name TitleOverlay
extends TextureRect

# ============================================================
# TitleOverlay — niebla/nubes animada decorativa (title_background).
# ============================================================
# Overlay a pantalla completa que se reproduce ENCIMA del fondo de los menús de
# arranque y del menú principal (mismo elemento en los tres, para continuidad).
# No captura ratón.
#
# title_background.png es una hoja 1440×960 = grid 6×6, 33 frames de 240×160,
# a 16 fps en bucle.
#
# TRANSPARENCIA: el PNG NO trae alpha útil (sus zonas oscuras son azul-gris
# OPACO, no transparentes). Un shader deriva el alpha de la LUMINANCIA: lo
# oscuro se vuelve transparente y sólo la niebla clara queda visible, con un
# tope de opacidad para que el fondo/parallax se sigan viendo por debajo.
# ============================================================

const SHEET := "res://assets/panoramas/title_background.png"
const COLS := 6
const FW := 240
const FH := 160
const FRAME_COUNT := 33
const FPS := 24.0

# Umbrales del keying por luminancia (ajustables si hace falta).
const DARK_CUT    := 0.10   # luminancia por debajo de esto → totalmente transparente
const BRIGHT_FULL := 0.55   # luminancia por encima de esto → opacidad máxima
const MAX_ALPHA   := 0.32   # tope de opacidad: efecto SUTIL, no tapa el fondo/logo

const SHADER_CODE := """
shader_type canvas_item;
uniform float dark_cut;
uniform float bright_full;
uniform float max_alpha;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float lum = max(c.r, max(c.g, c.b));
	float a = smoothstep(dark_cut, bright_full, lum) * max_alpha * c.a;
	COLOR = vec4(c.rgb, a);
}
"""

var _frames: Array = []
var _i: int = 0
var _dir: int = 1
var _accum: float = 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Shader: alpha por luminancia (oscuro→transparente).
	var sh := Shader.new()
	sh.code = SHADER_CODE
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("dark_cut", DARK_CUT)
	mat.set_shader_parameter("bright_full", BRIGHT_FULL)
	mat.set_shader_parameter("max_alpha", MAX_ALPHA)
	material = mat
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
	# Reproducción PING-PONG (0→N→0): evita el salto del corte de bucle, que se
	# notaba como un "tirón/estático" al reiniciar.
	while _accum >= frame_time:
		_accum -= frame_time
		_i += _dir
		if _i >= _frames.size() - 1:
			_i = _frames.size() - 1
			_dir = -1
		elif _i <= 0:
			_i = 0
			_dir = 1
		texture = _frames[_i]
