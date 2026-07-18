# UnitSprite.gd
# Sprite animado de unidad sobre el mapa táctico, con el formato canónico
# LT-maker:
#
#   {class}-stand.png  →  3 estados × 3 frames (192×144 con celdas 64×48):
#       fila 0 (y=0..47):    passive  (idle normal)
#       fila 1 (y=48..95):   gray     (unidad ya actuada)
#       fila 2 (y=96..143):  active   (seleccionada / parpadeando)
#
#   {class}-move.png   →  4 direcciones × 4 frames (192×160 con celdas 48×40):
#       fila 0 (y=0..39):    down
#       fila 1 (y=40..79):   left
#       fila 2 (y=80..119):  right
#       fila 3 (y=120..159): up
#
# El color (129, 160, 128) es el "color key" del LT — debe ser transparente.
# Esta clase carga las hojas de sprites, aplica la transparencia y expone
# AnimatedSprite2D con animaciones nombradas.

class_name UnitSprite
extends Node2D

## Color key del LT-maker: cualquier pixel exactamente este color se vuelve
## transparente al cargar.  Usado tanto en stand como en move sheets.
const COLOR_KEY := Color8(129, 160, 128)

## Tolerancia para el color key (algunas imágenes tienen variaciones por
## compresión).  0 = match exacto, 5 = pequeñas variaciones aceptadas.
const COLOR_KEY_TOLERANCE := 2

## Tamaños canónicos LT.
const STAND_FRAME_SIZE := Vector2i(64, 48)   # 3×3 grid en 192×144
const MOVE_FRAME_SIZE  := Vector2i(48, 40)   # 4×4 grid en 192×160

## Velocidad de los frames (FPS).
const STAND_FPS := 4.0
const MOVE_FPS  := 8.0
const ACTIVE_FPS := 6.0

## Cache global de SpriteFrames por clase para no procesar dos veces la
## misma hoja.  Key: "<class_nid>:<team>" → SpriteFrames.
static var _frames_cache: Dictionary = {}

## Conversiones de paleta por team (convención player/enemy/other/ally).
##   player → sin cambios (azul base).
##   enemy  → rojo.
##   ally   → verde (NPC aliado).
##   other  → morado/neutral.
## El LT usa diccionarios palette → palette.  En Godot lo simplificamos
## como un tinte (modulate) sobre el sprite base.
static var TEAM_TINTS: Dictionary = {
	"player": Color(1.0, 1.0, 1.0),         # sin cambio
	"enemy":  Color(1.4, 0.6, 0.6),         # tinte rojizo
	"ally":   Color(0.6, 1.4, 0.6),         # tinte verdoso (NPC)
	"other":  Color(1.2, 0.6, 1.4),         # tinte morado (neutral)
}


@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	if animated_sprite == null:
		animated_sprite = AnimatedSprite2D.new()
		add_child(animated_sprite)


## Carga los sprites de una clase y aplica el tinte de team.
##   class_nid: "Cavalier", "Lord", "Paladin", etc.
##   team: "player" / "enemy" / "other" / "ally"
##   asset_root: ruta base donde están los archivos PNG (estructura plana
##               sin subcarpetas, como en el LT-maker original).
##
## La estructura esperada es:
##   {asset_root}{class_nid}-stand.png
##   {asset_root}{class_nid}-move.png
##
## Si los archivos no existen, queda sin sprite (puedes detectar con
## has_sprite()).
func load_class(class_nid: String, team: String = "player",
		asset_root: String = "res://assets/map_sprites/") -> bool:
	var cache_key := "%s:%s" % [class_nid, team]
	var frames: SpriteFrames
	if _frames_cache.has(cache_key):
		frames = _frames_cache[cache_key]
	else:
		frames = _build_sprite_frames(class_nid, asset_root)
		if frames == null:
			push_warning("UnitSprite: no se encontró %s en %s" % [class_nid, asset_root])
			return false
		_frames_cache[cache_key] = frames
	animated_sprite.sprite_frames = frames
	# Tinte por team.
	if TEAM_TINTS.has(team):
		animated_sprite.modulate = TEAM_TINTS[team]
	# Animación inicial.
	play_state("passive")
	return true


## Carga las texturas de un class_nid y construye un SpriteFrames con
## todas las animaciones (passive/gray/active/down/left/right/up).
##
## Estructura plana (canon LT-maker):
##   {asset_root}{class_nid}-stand.png
##   {asset_root}{class_nid}-move.png
##
## Se aplica color key transparente al PNG bruto antes de generar atlases.
static func _build_sprite_frames(class_nid: String, asset_root: String) -> SpriteFrames:
	# Rutas LÓGICAS re-enraizadas al set gráfico activo (fallback a GBA).
	var stand_path := AssetSet.p("%s%s-stand.png" % [asset_root, class_nid])
	var move_path  := AssetSet.p("%s%s-move.png"  % [asset_root, class_nid])
	var stand_tex := _load_with_colorkey(stand_path)
	var move_tex  := _load_with_colorkey(move_path)
	if stand_tex == null and move_tex == null:
		return null

	# Tamaño de celda DERIVADO de la hoja real (rejilla lógica 3×3 / 4×4). En GBA
	# da 64×48 y 48×40 (idéntico a STAND/MOVE_FRAME_SIZE); una hoja HD 2× se
	# recorta correctamente sin tocar constantes.
	var stand_fs := STAND_FRAME_SIZE
	if stand_tex != null and stand_tex.get_width() > 0:
		stand_fs = Vector2i(stand_tex.get_width() / 3, stand_tex.get_height() / 3)
	var move_fs := MOVE_FRAME_SIZE
	if move_tex != null and move_tex.get_width() > 0:
		move_fs = Vector2i(move_tex.get_width() / 4, move_tex.get_height() / 4)

	var sf := SpriteFrames.new()

	# Stand: 3 filas × 3 cols.
	if stand_tex != null:
		_add_strip(sf, "passive", stand_tex, 0, 3, stand_fs, STAND_FPS, true)
		_add_strip(sf, "gray",    stand_tex, 1, 3, stand_fs, STAND_FPS, true)
		_add_strip(sf, "active",  stand_tex, 2, 3, stand_fs, ACTIVE_FPS, true)
	# Move: 4 filas × 4 cols.
	if move_tex != null:
		_add_strip(sf, "down",  move_tex, 0, 4, move_fs, MOVE_FPS, true)
		_add_strip(sf, "left",  move_tex, 1, 4, move_fs, MOVE_FPS, true)
		_add_strip(sf, "right", move_tex, 2, 4, move_fs, MOVE_FPS, true)
		_add_strip(sf, "up",    move_tex, 3, 4, move_fs, MOVE_FPS, true)
	return sf


## Carga un PNG y le aplica color key (= COLOR_KEY → transparente).
##   Devuelve un ImageTexture con alpha procesada, o null si el archivo
##   no existe.
static func _load_with_colorkey(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	var img := Image.load_from_file(path)
	if img == null:
		# Fallback: usar load() del resource manager (procesa los .import).
		var tex_resource = load(path)
		if tex_resource is Texture2D:
			img = tex_resource.get_image()
	if img == null:
		return null
	# Asegurar que tiene canal alpha.
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	# Aplicar color key: cualquier pixel ≈ COLOR_KEY se vuelve transparente.
	var w := img.get_width()
	var h := img.get_height()
	for y in range(h):
		for x in range(w):
			var px := img.get_pixel(x, y)
			if _color_matches(px, COLOR_KEY):
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	return ImageTexture.create_from_image(img)


## ¿El color es el COLOR_KEY canónico LT (con tolerancia)?
static func _color_matches(c: Color, key: Color) -> bool:
	var dr: float = abs(c.r - key.r) * 255.0
	var dg: float = abs(c.g - key.g) * 255.0
	var db: float = abs(c.b - key.b) * 255.0
	return dr <= COLOR_KEY_TOLERANCE and dg <= COLOR_KEY_TOLERANCE and db <= COLOR_KEY_TOLERANCE


## Añade una tira horizontal de N frames como una animación a SpriteFrames.
##   anim_name: nombre de la animación.
##   sheet:     textura completa.
##   row:       índice de fila (0-based).
##   count:     número de frames.
##   frame_size: tamaño de cada celda.
##   fps:       velocidad.
##   loop:      si la animación hace loop.
static func _add_strip(sf: SpriteFrames, anim_name: String, sheet: Texture2D,
		row: int, count: int, frame_size: Vector2i,
		fps: float, loop: bool) -> void:
	sf.add_animation(anim_name)
	sf.set_animation_speed(anim_name, fps)
	sf.set_animation_loop(anim_name, loop)
	for i in range(count):
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(
			i * frame_size.x,
			row * frame_size.y,
			frame_size.x,
			frame_size.y
		)
		sf.add_frame(anim_name, atlas)


## Cambia la animación al estado pasado.
##   "passive", "gray", "active": idle, ya-actuada, seleccionada.
##   "down", "left", "right", "up": caminando en cada dirección.
func play_state(state: String) -> void:
	if animated_sprite == null or animated_sprite.sprite_frames == null:
		return
	if not animated_sprite.sprite_frames.has_animation(state):
		return
	animated_sprite.animation = state
	animated_sprite.play()


## ¿Tiene sprites cargados?
func has_sprite() -> bool:
	return animated_sprite != null and animated_sprite.sprite_frames != null


## Limpiar el cache (útil en hot-reload o cambios de tema).
static func clear_cache() -> void:
	_frames_cache.clear()
