# MapBackground.gd
# Renderiza el mapa de un capítulo usando el PNG pre-renderizado del LT.
#
# Uso:
#   var bg := MapBackground.new()
#   bg.tilemap_nid = "Prologue"
#   bg.cell_size = 32  # tamaño de cada celda en tu Grid
#   add_child(bg)
#
# El PNG fuente está en res://assets/GBA/tilesets/FE4/{tilemap_nid}.png (o FE5/)
# y tiene los tiles a 16px.  Se escala al cell_size del Grid (típicamente
# 32 o 48 en Godot).

class_name MapBackground
extends Node2D

## NID del tilemap a renderizar.  Debe coincidir con el nombre del archivo
## en res://assets/GBA/tilesets/FE4/ o /FE5/ (ej. "Prologue" → "Prologue.png").
@export var tilemap_nid: String = ""

## Tamaño de cada celda de tu Grid en píxeles (típicamente 32, 48, 64).
@export var cell_size: int = 32

## Tamaño nativo del tile en el PNG fuente (canon LT = 16).
@export var native_tile_size: int = 16

## Z-index — negativo para que las unidades aparezcan encima.
@export var background_z: int = -10


@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")


func _ready() -> void:
	if sprite == null:
		sprite = Sprite2D.new()
		sprite.name = "Sprite2D"
		add_child(sprite)
	z_index = background_z
	if tilemap_nid != "":
		load_tilemap(tilemap_nid)


## Carga la imagen del tilemap y la escala al cell_size del Grid.
##
## Busca primero usando AssetLoader (que prueba FE4/FE5/raíz automáticamente).
## Si AssetLoader no está como autoload, hace fallback probando ambos paths.
func load_tilemap(nid: String) -> bool:
	tilemap_nid = nid
	var tex: Texture2D = null
	if has_node("/root/AssetLoader"):
		var loader = get_node("/root/AssetLoader")
		tex = loader.get_tilemap_image(nid)
	else:
		# Fallback: probar FE4, FE5 y raíz.
		for base in ["res://assets/GBA/tilesets/FE4/",
				"res://assets/GBA/tilesets/FE5/",
				"res://assets/GBA/tilesets/"]:
			var path: String = "%s%s.png" % [base, nid]
			if ResourceLoader.exists(path):
				tex = load(path) as Texture2D
				break
	if tex == null:
		push_warning("MapBackground: tilemap '%s' no encontrado en FE4 ni FE5" % nid)
		return false
	sprite.texture = tex
	sprite.centered = false
	sprite.position = Vector2.ZERO
	var scale_factor: float = float(cell_size) / float(native_tile_size)
	sprite.scale = Vector2(scale_factor, scale_factor)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return true
