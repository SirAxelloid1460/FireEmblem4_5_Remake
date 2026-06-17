# CombatPaletteSystem.gd
# Aplica paletas a las imágenes "negras" de combat_anims y combat_effects.
#
# === CÓMO FUNCIONA EL FORMATO LT ===
#
# Las imágenes de combat_anims están guardadas en PNG normal (modo RGB),
# pero NO almacenan colores reales — almacenan ÍNDICES a una paleta.
# Cada pixel se codifica como:
#
#     (R, G, B) = (0, palette_x, palette_y)
#
# Donde palette_x ∈ [0..7] y palette_y ∈ [0..1] indexan una paleta de
# 8×2 = 16 colores guardada aparte (combat_palettes/palette_data/{nid}.json).
#
# Esto significa que las imágenes RAW se ven prácticamente NEGRAS (porque
# R siempre es 0 y G,B son números muy pequeños que en RGB normal son casi
# negro absoluto).  Para visualizarlas hay que aplicar la paleta correspondiente.
#
# === ESTRUCTURA DE UN ARCHIVO PALETTE ===
#
# combat_palettes/palette_data/Cavalier0_GenericBlue.json:
# [
#   ["Cavalier0_GenericBlue", [
#     [[0, 0], [128, 160, 128]],      ← color key (transparente)
#     [[1, 0], [40, 40, 40]],         ← negros y sombras
#     [[2, 0], [176, 136, 96]],       ← marrón cuero
#     ...
#     [[4, 0], [112, 224, 248]],      ← azul claro armadura (player)
#     [[5, 0], [64, 112, 248]],       ← azul medio armadura
#     ...
#   ]]
# ]
#
# Para variantes Red/Green/Purple, se sustituyen los slots de team color.
#
# === CACHE ===
#
# Las texturas resultantes se cachean por (img_path, palette_nid).  Las
# paletas también se cachean por nid.  No reproceses lo mismo varias veces.

class_name CombatPaletteSystem
extends RefCounted


## Color key del LT — el primer slot de cada paleta apunta aquí, y también
## es el fondo de las imágenes raw.  Convertir a alpha 0 (transparente).
const COLOR_KEY := Color8(128, 160, 128)

## Tamaño canónico de paleta: 8 columnas × 2 filas = 16 colores.
const PALETTE_W := 8
const PALETTE_H := 2

## Ubicaciones donde buscar archivos JSON de paleta.  En orden de búsqueda:
##   1. combat_palettes/palette_data/{nid}.json  (paletas canónicas de clases)
##   2. combat_effects/{nid}.json                (paletas inline de efectos)
##   3. combat_anims/{nid}.json                  (paletas inline de unidades)
##
## Esto permite que tanto las paletas de unidad (compartidas por la
## carpeta combat_palettes) como las de efectos (almacenadas junto al
## PNG en combat_effects) funcionen sin configuración adicional.
const PALETTE_SEARCH_PATHS: Array = [
	"res://assets/combat_palettes/palette_data/",
	"res://assets/combat_effects/",
	"res://assets/combat_anims/",
]

## Path por defecto (legacy, mantenido por compatibilidad).
const PALETTE_DATA_PATH := "res://assets/combat_palettes/palette_data/"


# Cache de paletas (nid → Array de 16 Color).
static var _palette_cache: Dictionary = {}

# Cache de imágenes coloreadas ("img_path::palette_nid" → ImageTexture).
static var _texture_cache: Dictionary = {}


# ══════════════════════════════════════════════════════════════════════════════
# CARGAR PALETA
# ══════════════════════════════════════════════════════════════════════════════

## Carga una paleta del JSON y devuelve un Array[16] de Color.
## Índice = `palette_x + palette_y * PALETTE_W`.
##   palette_nid: ej. "Cavalier0_GenericBlue" o "AetherFlash1_Image"
##
## Devuelve [] si no existe.  El primer slot tiene alpha 0 (color key).
##
## Búsqueda: prueba PALETTE_SEARCH_PATHS en orden hasta encontrar el JSON.
static func load_palette(palette_nid: String) -> Array:
	if _palette_cache.has(palette_nid):
		return _palette_cache[palette_nid]
	var path := ""
	for base in PALETTE_SEARCH_PATHS:
		var candidate: String = base + palette_nid + ".json"
		if FileAccess.file_exists(candidate):
			path = candidate
			break
	if path == "":
		push_warning("CombatPaletteSystem: paleta no encontrada: %s" % palette_nid)
		_palette_cache[palette_nid] = []
		return []
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		_palette_cache[palette_nid] = []
		return []
	var raw := f.get_as_text()
	f.close()
	var data = JSON.parse_string(raw)
	# Estructura: [[nid, [[[x,y],[r,g,b]], ...]]]
	if not (data is Array) or data.size() == 0:
		_palette_cache[palette_nid] = []
		return []
	var entry = data[0]
	if not (entry is Array) or entry.size() < 2:
		_palette_cache[palette_nid] = []
		return []
	var pixels = entry[1]
	# 16 slots iniciales todos transparentes.
	var palette: Array = []
	palette.resize(PALETTE_W * PALETTE_H)
	for i in range(palette.size()):
		palette[i] = Color(0, 0, 0, 0)
	for entry_pair in pixels:
		if not (entry_pair is Array) or entry_pair.size() < 2:
			continue
		var coord = entry_pair[0]
		var rgb = entry_pair[1]
		var px = int(coord[0])
		var py = int(coord[1])
		var idx: int = px + py * PALETTE_W
		if idx < 0 or idx >= palette.size():
			continue
		var col := Color8(int(rgb[0]), int(rgb[1]), int(rgb[2]))
		# Slot [0,0] = color key — transparente.
		if px == 0 and py == 0:
			col.a = 0.0
		palette[idx] = col
	_palette_cache[palette_nid] = palette
	return palette


# ══════════════════════════════════════════════════════════════════════════════
# APLICAR PALETA A UNA IMAGEN
# ══════════════════════════════════════════════════════════════════════════════

## Carga una imagen "indexada en RGB" (formato LT) y le aplica una paleta.
## Devuelve un Texture2D con los colores reales y transparencia.
##
##   image_path:  ej. "res://assets/combat_anims/Cavalier-Lance.png"
##   palette_nid: ej. "Cavalier0_GenericBlue"
##
## Devuelve null si alguno de los dos no existe.
static func load_palettized_image(image_path: String,
		palette_nid: String) -> Texture2D:
	var cache_key := "%s::%s" % [image_path, palette_nid]
	if _texture_cache.has(cache_key):
		return _texture_cache[cache_key]

	if not ResourceLoader.exists(image_path):
		push_warning("CombatPaletteSystem: imagen no encontrada: %s" % image_path)
		return null
	var palette := load_palette(palette_nid)
	if palette.is_empty():
		return null

	# Cargar imagen — primero load+get_image (respeta el import pipeline),
	# fallback a Image.load_from_file.
	var img: Image = null
	var tex_resource = load(image_path)
	if tex_resource is Texture2D:
		img = tex_resource.get_image()
	if img == null:
		img = Image.load_from_file(image_path)
	if img == null:
		push_warning("CombatPaletteSystem: no se pudo decodificar %s" % image_path)
		return null

	# RGBA8 para poder escribir alpha.
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)

	var w := img.get_width()
	var h := img.get_height()

	# Recorrer cada pixel:
	#   (r, g, b) = (0, palette_x, palette_y)  →  palette[g + b * PALETTE_W]
	# Si r != 0 (artefacto), tratamos como transparente.
	for y in range(h):
		for x in range(w):
			var px := img.get_pixel(x, y)
			var r := int(round(px.r * 255.0))
			var g := int(round(px.g * 255.0))
			var b := int(round(px.b * 255.0))
			if r != 0:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			if g < 0 or g >= PALETTE_W or b < 0 or b >= PALETTE_H:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var idx: int = g + b * PALETTE_W
			img.set_pixel(x, y, palette[idx])

	var tex := ImageTexture.create_from_image(img)
	_texture_cache[cache_key] = tex
	return tex


# ══════════════════════════════════════════════════════════════════════════════
# UTILIDADES
# ══════════════════════════════════════════════════════════════════════════════

## Limpia los caches.  Útil al cambiar de cap o tema.
static func clear_cache() -> void:
	_palette_cache.clear()
	_texture_cache.clear()


## Lista las paletas disponibles para una clase.
##   class_nid: ej. "Cavalier"
## Devuelve nids como ["Cavalier0_GenericBlue", "Cavalier0_GenericRed", ...].
## Recorre los PALETTE_SEARCH_PATHS para encontrar todas las variantes.
static func list_palettes_for_class(class_nid: String) -> Array:
	var out: Array = []
	for base in PALETTE_SEARCH_PATHS:
		var dir := DirAccess.open(base)
		if dir == null:
			continue
		dir.list_dir_begin()
		var entry := dir.get_next()
		while entry != "":
			if not dir.current_is_dir() and entry.ends_with(".json") \
					and entry.begins_with(class_nid + "0_"):
				var nid := entry.substr(0, entry.length() - 5)
				if nid not in out:
					out.append(nid)
			entry = dir.get_next()
		dir.list_dir_end()
	return out


## Devuelve el palette_nid por defecto para una clase y team.
## Convención de equipos: player / enemy / ally(verde NPC) / other(neutral).
##   ej. ("Cavalier", "player") → "Cavalier0_GenericBlue"
##       ("Cavalier", "enemy")  → "Cavalier0_GenericRed"
##       ("Cavalier", "ally")   → "Cavalier0_GenericGreen"
static func default_palette_nid(class_nid: String, team: String) -> String:
	var color := "GenericBlue"
	match team:
		"enemy":  color = "GenericRed"
		"ally":   color = "GenericGreen"
		"other":  color = "GenericPurple"
	return "%s0_%s" % [class_nid, color]
