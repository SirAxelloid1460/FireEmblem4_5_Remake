# CombatAnimDatabase.gd
# Carga y cachea spritesheets + JSONs de animaciones de combate generados por
# build_combat_sheet.py (formato {NID}_{Variant}_{Weapon}).
#
# Esta DB no decide qué animación corresponde a qué unit — eso lo hace
# CombatAnimResolver.  Aquí solo se carga por nombre canónico:
#
#   load_anim("Cavalier_Alec_Sword")
#       → { "sheet": Texture2D, "data": Dictionary, "ok": bool }
#
# Estructura del JSON (lo que entrega build_combat_sheet.py):
#   {
#     "class": "Cavalier",
#     "variant": "Alec",
#     "weapon": "Sword",
#     "tile_size":  [240, 160],
#     "frame_size": [240, 160],
#     "padding": 0,
#     "grid": [6, 6],
#     "sheet_size": [1440, 960],
#     "frame_count": 33,
#     "frames": {
#       "Sword_000": { "tile": [0, 0] },
#       ...
#     },
#     "poses": {
#       "Attack": [
#         { "cmd": "frame", "ticks": 6, "frame": "Sword_000" },
#         { "cmd": "sound", "id": "Weapon Pull" },
#         ...
#       ],
#       "Critical": [...],
#       "Dodge": [...],
#       "Stand": [...],
#       "Miss": [...]
#     }
#   }

class_name CombatAnimDatabase
extends RefCounted


## Carpeta donde viven los sheets generados por build_combat_sheet.py.
const ANIMS_ROOT: String = "res://assets/combat_anims/"

## Cache de animaciones cargadas.  Clave: "{NID}_{Variant}_{Weapon}".
## Valor: { "sheet": Texture2D, "data": Dictionary, "ok": bool, "name": String }.
static var _cache: Dictionary = {}


## Carga (o reutiliza de cache) la animación canónica con nombre dado.
##
##   anim_name: ej. "Cavalier_Alec_Sword"
##
## Devuelve un Dict con:
##   "sheet": Texture2D del spritesheet (null si no existe)
##   "data":  Dictionary con la metadata del JSON ({} si no existe)
##   "ok":    bool — true si todo cargó correctamente
##   "name":  el anim_name pasado
## Resuelve las rutas del sheet/JSON de una animación. Los assets se guardan en
## una subcarpeta por variante — combat_anims/{NID}_{Variant}/{anim_name}.png —
## (el folder = anim_name sin el último segmento _{Weapon}); con fallback al
## layout plano combat_anims/{anim_name}.png.
static func _resolve_paths(anim_name: String) -> Dictionary:
	var folder := anim_name
	var us := anim_name.rfind("_")
	if us > 0:
		folder = anim_name.substr(0, us)
	# Rutas LÓGICAS re-enraizadas al set gráfico activo (fallback a GBA).
	var sub_png := AssetSet.p(ANIMS_ROOT + folder + "/" + anim_name + ".png")
	if ResourceLoader.exists(sub_png):
		return { "png": sub_png, "json": AssetSet.p(ANIMS_ROOT + folder + "/" + anim_name + ".json") }
	return { "png": AssetSet.p(ANIMS_ROOT + anim_name + ".png"), "json": AssetSet.p(ANIMS_ROOT + anim_name + ".json") }


static func load_anim(anim_name: String) -> Dictionary:
	if _cache.has(anim_name):
		return _cache[anim_name]

	var paths := _resolve_paths(anim_name)
	var sheet_path: String = paths["png"]
	var json_path: String  = paths["json"]

	var result: Dictionary = {
		"sheet": null, "data": {}, "ok": false, "name": anim_name,
	}

	if not ResourceLoader.exists(sheet_path):
		_cache[anim_name] = result
		return result
	if not FileAccess.file_exists(json_path):
		_cache[anim_name] = result
		return result

	var sheet: Texture2D = load(sheet_path) as Texture2D
	if sheet == null:
		_cache[anim_name] = result
		return result

	var raw := FileAccess.get_file_as_string(json_path)
	var parsed = JSON.parse_string(raw)
	if not (parsed is Dictionary):
		_cache[anim_name] = result
		return result

	result["sheet"] = sheet
	result["data"] = parsed
	result["ok"] = true
	_cache[anim_name] = result
	return result


## Devuelve true si existe un sheet+JSON con ese nombre canónico (sin cargar).
static func has_anim(anim_name: String) -> bool:
	if _cache.has(anim_name):
		return _cache[anim_name].get("ok", false)
	var paths := _resolve_paths(anim_name)
	return ResourceLoader.exists(paths["png"]) and FileAccess.file_exists(paths["json"])


## Devuelve un AtlasTexture para un frame concreto de la animación.
##   anim:       Dict devuelto por load_anim()
##   frame_name: ej. "Sword_005"
##
## Devuelve null si la anim no es válida o el frame no existe.
static func get_frame_atlas(anim: Dictionary, frame_name: String) -> AtlasTexture:
	if not anim.get("ok", false):
		return null
	var data: Dictionary = anim["data"]
	var frames: Dictionary = data.get("frames", {})
	if not frames.has(frame_name):
		return null
	var fdata: Dictionary = frames[frame_name]
	var tile: Array = fdata.get("tile", [0, 0])
	var tile_size: Array = data.get("tile_size", [240, 160])
	var atlas := AtlasTexture.new()
	atlas.atlas = anim["sheet"]
	atlas.region = Rect2(
			int(tile[0]) * int(tile_size[0]),
			int(tile[1]) * int(tile_size[1]),
			int(tile_size[0]),
			int(tile_size[1]))
	return atlas


## Devuelve la lista de pose names disponibles ("Attack", "Critical", ...).
static func list_poses(anim: Dictionary) -> Array:
	if not anim.get("ok", false):
		return []
	return (anim["data"].get("poses", {}) as Dictionary).keys()


## Devuelve los comandos de una pose (ej. "Attack" → array de cmd dicts).
static func get_pose_commands(anim: Dictionary, pose_name: String) -> Array:
	if not anim.get("ok", false):
		return []
	var poses: Dictionary = anim["data"].get("poses", {})
	return poses.get(pose_name, [])


## Limpia toda la cache (útil para hot-reload en desarrollo).
static func clear_cache() -> void:
	_cache.clear()
