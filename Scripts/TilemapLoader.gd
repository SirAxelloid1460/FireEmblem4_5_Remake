# TilemapLoader.gd
# Carga tilemaps reales desde el formato LT-maker:
#   tilemaps_root/
#     ├── tilemap.json                ← índice maestro (nid + tilesets)
#     └── tilemap_data/
#         └── <Prologue>.json         ← datos por tilemap (size, layers, terrain_grid)
#
# FORMATO:
#   tilemap.json es un Array de Dicts con { nid, autotile_fps, tilesets, ... }.
#   tilemap_data/<nid>.json es un Array[1] con un Dict que contiene:
#     • size: [width, height]
#     • layers: [{ nid:"base", visible:true, terrain_grid:{...}, sprite_grid:{...} }, ...]
#
#   terrain_grid es un Dictionary { "x,y": "<terrain_nid_string>" }.
#
# Devuelve el formato que LevelLoader._apply_tilemap espera:
#   { "width":int, "height":int, "terrain": {Vector2i(x,y) → terrain_nid:String} }
#
# El mapping nid→name se realiza más tarde en LevelLoader._resolve_terrain_id
# leyendo el terrain_db del project_data.

class_name TilemapLoader
extends RefCounted


## Carga un tilemap por nid.
##   tilemaps_root : ruta raíz de los tilemaps (con tilemap.json + tilemap_data/).
##   nid           : id del tilemap (ej. "Prologue", "Chapter1").
##
## Devuelve un Dictionary listo para LevelLoader.load_chapter.
##   Si el archivo no existe o es inválido, devuelve {} (LevelLoader hará
##   fallback a tilemap plano).
static func load_tilemap(tilemaps_root: String, nid: String) -> Dictionary:
	var dir := tilemaps_root if tilemaps_root.ends_with("/") else tilemaps_root + "/"
	var path := dir + "tilemap_data/" + nid + ".json"
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_warning("[TilemapLoader] No se encontró %s — usando tilemap plano." % path)
		return {}
	var raw := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(raw)
	if not (parsed is Array) or parsed.is_empty():
		push_error("[TilemapLoader] JSON inválido en %s" % path)
		return {}
	return _build_tilemap_data(parsed[0])


## Variante para datos en memoria (testing).
static func load_from_dict(data: Dictionary) -> Dictionary:
	return _build_tilemap_data(data)


# ══════════════════════════════════════════════════════════════════════════════
# CONSTRUCCIÓN INTERNA
# ══════════════════════════════════════════════════════════════════════════════

static func _build_tilemap_data(tm: Dictionary) -> Dictionary:
	var size = tm.get("size", [0, 0])
	var width: int  = int(size[0]) if size is Array and size.size() >= 1 else 0
	var height: int = int(size[1]) if size is Array and size.size() >= 2 else 0
	if width == 0 or height == 0:
		push_error("[TilemapLoader] tilemap %s no tiene size válido" % tm.get("nid", "?"))
		return {}

	# Combinar terrain_grids de TODAS las layers visibles (la última gana,
	# como hace LT: get_terrain itera reversed y devuelve el primer hit).
	# En la práctica casi siempre solo la layer "base" tiene terrain_grid
	# rellenado; las demás tienen sprite-only.
	var combined: Dictionary = {}
	for layer in tm.get("layers", []):
		if not bool(layer.get("visible", true)):
			continue
		var tg: Dictionary = layer.get("terrain_grid", {})
		for key in tg:
			combined[_parse_coord(key)] = str(tg[key])

	return {
		"width":   width,
		"height":  height,
		"terrain": combined,
	}


## Convierte la clave del terrain_grid ("x,y" como String) a Vector2i.
static func _parse_coord(key) -> Vector2i:
	if key is Vector2i:
		return key
	if key is Array and key.size() >= 2:
		return Vector2i(int(key[0]), int(key[1]))
	var s := str(key)
	var parts := s.split(",")
	if parts.size() >= 2:
		return Vector2i(int(parts[0]), int(parts[1]))
	return Vector2i.ZERO


# ══════════════════════════════════════════════════════════════════════════════
# UTILIDADES
# ══════════════════════════════════════════════════════════════════════════════

## Lista todos los nids de tilemaps disponibles en un proyecto.  Útil para
## menús de selección de mapa (DEBUG, world map editor, etc.).
static func list_available(tilemaps_root: String) -> Array:
	var dir := tilemaps_root if tilemaps_root.ends_with("/") else tilemaps_root + "/"
	var path := dir + "tilemap.json"
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return []
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if not (parsed is Array):
		return []
	var out: Array = []
	for entry in parsed:
		if entry is Dictionary and entry.has("nid"):
			out.append(str(entry["nid"]))
	return out
