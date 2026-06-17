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

# Shader de palette-swap por equipo (LUT de 16 colores, ver team_palettes.md).
const TEAM_SHADER := preload("res://Shaders/team_palette_swap.gdshader")
# Materiales compartidos por valor de 'team' (1=Enemy 2=Ally 3=Other 4=Used).
# team 0 (Player) no usa material (identidad).
static var _team_materials: Dictionary = {}

var _seq_idx := 0
var _accum := 0.0
var _frames := IDLE_SEQUENCE

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
	var tex: Texture2D = _load_stand(map_sprite_nid)
	if tex == null:
		hide()
		return false

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
	# Anclaje: centro horizontal en x=0; los pies (nativo y=39) caen en la línea
	# de suelo (ver feet_local_for). El cuerpo se extiende hacia arriba y sobresale
	# un poco — look FE correcto.
	var feet_local := feet_local_for(cell_size)
	position = Vector2(-(CELL_W / 2.0) * s, feet_local - FEET_NATIVE * s)

	_seq_idx = 0
	_accum = 0.0
	_apply_frame()
	show()
	set_process(true)
	return true


func _load_stand(map_sprite_nid: String) -> Texture2D:
	if map_sprite_nid == "":
		return null
	# Vía autoload AssetLoader (con caché); fallback a carga directa.
	if has_node("/root/AssetLoader"):
		return get_node("/root/AssetLoader").get_map_sprite(map_sprite_nid, "stand")
	var path := "res://assets/map_sprites/" + map_sprite_nid + "-stand.png"
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null


func _process(delta: float) -> void:
	_accum += delta
	if _accum < FRAME_TIME:
		return
	_accum -= FRAME_TIME
	_seq_idx = (_seq_idx + 1) % _frames.size()
	_apply_frame()


func _apply_frame() -> void:
	var col: int = _frames[_seq_idx]
	region_rect = Rect2(col * CELL_W, IDLE_ROW * CELL_H, CELL_W, CELL_H)
