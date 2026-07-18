# UnitMapSprite.gd
# ============================================================
# Sprite de mapa de una unidad (idle animado), recreado para el render nativo.
# ============================================================
# Muestra el map sprite real de la clase (de assets/map_sprites/<nid>-stand.png)
# en lugar del círculo de color.  Formato LT verificado:
#   stand.png = 192×144 → rejilla 3 cols × 3 filas, celda 64×48.
#     · Fila 0 = idle a color (3 frames)   ← lo que animamos aquí
#     · Fila 1 = idle en gris (unidad que ya actuó)
#     · Fila 2 = poses activas (unidad seleccionada)
#   move.png  = 192×160 → 4 dir × 4 frames, celda 48×40 (animación de paso, futuro).
#
# El sprite nativo (~16px) se escala a cell_size/16 para coincidir con el mapa
# (MapBackground usa la misma escala).  Se ancla por los pies sobre el centro
# de la celda del Grid.  Si la clase no tiene sprite, setup() devuelve false y
# Unit.gd cae al marcador de color.
#
# El estado (acted/selected) lo transmite el `modulate` del Unit padre, que se
# propaga a este hijo — no hace falta cambiar de fila aquí.

class_name UnitMapSprite
extends Sprite2D

const NATIVE_TILE := 16
const CELL_W := 64          # ancho de celda del stand sheet
const CELL_H := 48          # alto de celda del stand sheet
# Los pies de TODAS las clases están en la fila nativa y=39 (LT las normaliza);
# anclamos por ahí, NO por el fondo de la celda (que tiene ~9px de padding).
const FEET_NATIVE := 39.0
# Línea de suelo (Y local donde caen los pies), relativa al centro de la celda:
#   FEET_FRACTION del alto + un nudge de N px nativos (ajuste fino de altura).
const FEET_FRACTION := 0.375
const FEET_NUDGE_NATIVE := 1.0
const IDLE_ROW := 0
const IDLE_SEQUENCE := [0, 1, 2, 1]   # ping-pong suave
const FRAME_TIME := 0.20

# --- Hoja de movimiento (move.png) ---
# 192×160 → 4 columnas (frames) × 4 filas (direcciones), celda 48×40.
# Orden de filas LT/GBA: 0=abajo, 1=izquierda, 2=derecha, 3=arriba.
const MOVE_CELL_W := 48
const MOVE_CELL_H := 40
const MOVE_FRAMES := 4
const DIR_DOWN := 0
const DIR_LEFT := 1
const DIR_RIGHT := 2
const DIR_UP := 3
const MOVE_FRAME_TIME := 0.09
const MOVE_WALK_SEQ := [0, 1, 2, 3]   # ciclo de paso (loop)
# Línea de pies dentro de la celda de movimiento (nativo y). La celda mide 40px
# y los pies caen cerca del borde inferior; ajuste fino con FEET_NUDGE compartido.
const MOVE_FEET_NATIVE := 36.0

# Shader de palette-swap por equipo (LUT de 16 colores, ver team_palettes.md).
const TEAM_SHADER := preload("res://Shaders/team_palette_swap.gdshader")
# Materiales compartidos por valor de 'team' (1=Enemy 2=Ally 3=Other 4=Used).
# team 0 (Player) no usa material (identidad).
static var _team_materials: Dictionary = {}

var _seq_idx := 0
var _accum := 0.0
var _frames := IDLE_SEQUENCE

# Estado de animación de paso (move.png). _moving=true → dibuja la hoja de
# movimiento en la dirección _move_dir; al terminar vuelve al idle (stand).
var _stand_tex: Texture2D = null
var _move_tex: Texture2D = null
var _cell_size: int = 64
var _moving := false
var _move_dir := DIR_DOWN
var _move_idx := 0
var _move_accum := 0.0

# Estado de paleta de esta unidad.
var _base_team: int = 0   # 0=Player 1=Enemy 2=Ally 3=Other
var _used: bool = false   # true => paleta "Used" (ya actuó)


## Material compartido para un valor de team (1..4). No usa uniforms por instancia.
static func _team_material(team: int) -> ShaderMaterial:
	if not _team_materials.has(team):
		var m := ShaderMaterial.new()
		m.shader = TEAM_SHADER
		m.set_shader_parameter("team", team)
		_team_materials[team] = m
	return _team_materials[team]


## Y local de la línea de suelo (pies) para un cell_size dado. Lo usan tanto
## este sprite como Unit (anillo de selección / HP bar) para quedar alineados.
static func feet_local_for(cell_size: int) -> float:
	return cell_size * FEET_FRACTION + FEET_NUDGE_NATIVE * (cell_size / 16.0)


## Cambia el equipo base (0=Player 1=Enemy 2=Ally 3=Other).
func set_team(team_index: int) -> void:
	_base_team = team_index
	_refresh_material()


## Activa/desactiva la paleta "Used" (gris) cuando la unidad ya actuó.
func set_used(used: bool) -> void:
	_used = used
	_refresh_material()


## Aplica el material según el estado: Used tiene prioridad sobre el equipo.
func _refresh_material() -> void:
	var t: int = 4 if _used else _base_team
	material = null if t == 0 else _team_material(t)


## Configura el sprite para una clase.  Devuelve true si cargó el sprite.
##   map_sprite_nid : campo `map_sprite_nid` de la clase (ver AssetLoader).
##   cell_size      : tamaño de celda del Grid (px); escala = cell_size/16.
##   team_index     : 0=Player 1=Enemy 2=Ally 3=Other (paleta de equipo).
func setup(map_sprite_nid: String, cell_size: int, team_index: int = 0) -> bool:
	var tex: Texture2D = _load_variant(map_sprite_nid, "stand")
	if tex == null:
		hide()
		return false

	_stand_tex = tex
	_move_tex = _load_variant(map_sprite_nid, "move")   # puede ser null → se desliza sin animar piernas
	_cell_size = cell_size
	texture = tex
	region_enabled = true
	centered = false
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Sin z_index propio: el sprite (hijo) ya se dibuja sobre el _draw del Unit
	# (anillo/HP), y dejar todo en z=0 hace que el Y-sort del UnitLayer ordene
	# las unidades entre sí correctamente por fila.
	_base_team = team_index
	_refresh_material()

	var s := float(cell_size) / float(NATIVE_TILE)
	scale = Vector2(s, s)

	_moving = false
	_seq_idx = 0
	_accum = 0.0
	_apply_idle_anchor()
	_apply_frame()
	show()
	set_process(true)
	return true


## Anclaje del idle (celda stand 64×48): centro horizontal en x=0; los pies
## (nativo y=39) caen en la línea de suelo (ver feet_local_for).
func _apply_idle_anchor() -> void:
	var s := float(_cell_size) / float(NATIVE_TILE)
	var feet_local := feet_local_for(_cell_size)
	position = Vector2(-(CELL_W / 2.0) * s, feet_local - FEET_NATIVE * s)


## Anclaje del movimiento (celda move 48×40): mismo centro/línea de suelo, con
## la métrica de la celda de paso (más estrecha y baja que la de stand).
func _apply_move_anchor() -> void:
	var s := float(_cell_size) / float(NATIVE_TILE)
	var feet_local := feet_local_for(_cell_size)
	position = Vector2(-(MOVE_CELL_W / 2.0) * s, feet_local - MOVE_FEET_NATIVE * s)


func _load_variant(map_sprite_nid: String, variant: String) -> Texture2D:
	if map_sprite_nid == "":
		return null
	# Vía autoload AssetLoader (con caché); fallback a carga directa.
	if has_node("/root/AssetLoader"):
		return get_node("/root/AssetLoader").get_map_sprite(map_sprite_nid, variant)
	var path := "res://assets/GBA/map_sprites/" + map_sprite_nid + "-" + variant + ".png"
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null


# ── Animación de paso (la dispara Unit.animate_move_along) ───────────────────

## Empieza a animar el paso. Si la clase no tiene move.png, no cambia nada
## (la unidad simplemente se desliza con el idle, sin animación de piernas).
func start_move() -> void:
	if _move_tex == null:
		return
	_moving = true
	_move_idx = 0
	_move_accum = 0.0
	texture = _move_tex
	_apply_move_anchor()
	_apply_move_frame()


## Fija la dirección de marcha (DIR_DOWN/LEFT/RIGHT/UP) y refresca el frame.
func set_move_dir(dir: int) -> void:
	_move_dir = dir
	if _moving:
		_apply_move_frame()


## Termina la animación de paso y vuelve al idle (stand).
func end_move() -> void:
	if not _moving:
		return
	_moving = false
	texture = _stand_tex
	_apply_idle_anchor()
	_seq_idx = 0
	_accum = 0.0
	_apply_frame()


func _process(delta: float) -> void:
	if _moving:
		_move_accum += delta
		if _move_accum < MOVE_FRAME_TIME:
			return
		_move_accum -= MOVE_FRAME_TIME
		_move_idx = (_move_idx + 1) % MOVE_WALK_SEQ.size()
		_apply_move_frame()
		return
	_accum += delta
	if _accum < FRAME_TIME:
		return
	_accum -= FRAME_TIME
	_seq_idx = (_seq_idx + 1) % _frames.size()
	_apply_frame()


func _apply_frame() -> void:
	var col: int = _frames[_seq_idx]
	region_rect = Rect2(col * CELL_W, IDLE_ROW * CELL_H, CELL_W, CELL_H)


func _apply_move_frame() -> void:
	var col: int = MOVE_WALK_SEQ[_move_idx]
	region_rect = Rect2(col * MOVE_CELL_W, _move_dir * MOVE_CELL_H,
			MOVE_CELL_W, MOVE_CELL_H)
