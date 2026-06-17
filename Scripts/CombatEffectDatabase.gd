# CombatEffectDatabase.gd
# Catálogo de efectos visuales de combate (chispazos, magias, auras).
#
# Mismo formato que combat_anims pero contiene efectos en vez de personajes
# (TurnwheelFlash, AetherWave, ArcthunderMagic, FireRune, etc.).
#
# Estructura idéntica a combat_anims.json: cada entry tiene nid, poses,
# frames y palettes.  La diferencia es que las paletas suelen ser una sola
# llamada "{Effect}_Image" (mientras que las clases tienen Blue/Red/Green).
#
# === USO ===
#
#   # Cargar efecto "TurnwheelFlash" con su paleta default:
#   var tex := CombatEffectDatabase.load_effect_sheet("TurnwheelFlash")
#
#   # Recorrer sus comandos:
#   var commands := CombatEffectDatabase.get_pose_commands("TurnwheelFlash")
#   var frames := CombatEffectDatabase.get_frames_dict("TurnwheelFlash")
#
#   # Listar todos los efectos disponibles:
#   var fx := CombatEffectDatabase.list_all_effects()

class_name CombatEffectDatabase
extends RefCounted


const EFFECTS_JSON_PATH := "res://assets/combat_effects/combat_effects.json"
const EFFECTS_IMAGES_PATH := "res://assets/combat_effects/"


static var _effects_cache: Dictionary = {}
static var _loaded: bool = false


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(EFFECTS_JSON_PATH):
		push_warning("CombatEffectDatabase: %s no encontrado" % EFFECTS_JSON_PATH)
		return
	var f := FileAccess.open(EFFECTS_JSON_PATH, FileAccess.READ)
	if f == null:
		return
	var raw := f.get_as_text()
	f.close()
	var data = JSON.parse_string(raw)
	if not (data is Array):
		return
	for entry in data:
		if entry is Dictionary and entry.has("nid"):
			_effects_cache[str(entry["nid"])] = entry
	print("[CombatEffectDatabase] %d efectos cargados" % _effects_cache.size())


static func has_effect(effect_nid: String) -> bool:
	_ensure_loaded()
	return _effects_cache.has(effect_nid)


static func get_effect(effect_nid: String) -> Dictionary:
	_ensure_loaded()
	return _effects_cache.get(effect_nid, {})


static func list_all_effects() -> Array:
	_ensure_loaded()
	return _effects_cache.keys()


## Devuelve los comandos de la pose principal del efecto (los efectos
## suelen tener solo una pose, llamada "Attack").  Si no encuentra esa
## pose por nombre exacto, devuelve la primera pose disponible.
static func get_pose_commands(effect_nid: String,
		pose_name: String = "Attack") -> Array:
	var fx := get_effect(effect_nid)
	if fx.is_empty():
		return []
	for p in fx.get("poses", []):
		if p is Array and p.size() >= 2 and str(p[0]) == pose_name:
			return p[1] if p[1] is Array else []
	# Fallback: primera pose.
	for p in fx.get("poses", []):
		if p is Array and p.size() >= 2:
			return p[1] if p[1] is Array else []
	return []


## Frames indexados por nombre (mismo formato que CombatAnimDatabase).
static func get_frames_dict(effect_nid: String) -> Dictionary:
	var fx := get_effect(effect_nid)
	if fx.is_empty():
		return {}
	var out: Dictionary = {}
	for f in fx.get("frames", []):
		if not (f is Array) or f.size() < 3:
			continue
		var name := str(f[0])
		var region = f[1]
		var offset = f[2]
		if not (region is Array) or region.size() < 4:
			continue
		if not (offset is Array) or offset.size() < 2:
			continue
		out[name] = {
			"region": Rect2(int(region[0]), int(region[1]),
					int(region[2]), int(region[3])),
			"offset": Vector2(int(offset[0]), int(offset[1])),
		}
	return out


## Paleta por defecto del efecto.  Los efectos suelen tener una paleta
## "{Effect}_Image".  Lo busca primero en el JSON, luego cae al patrón.
static func default_palette_nid(effect_nid: String) -> String:
	var fx := get_effect(effect_nid)
	if not fx.is_empty():
		var palettes = fx.get("palettes", [])
		if palettes is Array and palettes.size() > 0:
			var first = palettes[0]
			if first is Array and first.size() >= 2:
				return str(first[1])
	return effect_nid + "_Image"


static func get_image_path(effect_nid: String) -> String:
	return EFFECTS_IMAGES_PATH + effect_nid + ".png"


## Carga la sheet del efecto con paleta aplicada, lista para AtlasTextures.
static func load_effect_sheet(effect_nid: String,
		palette_override: String = "") -> Texture2D:
	var img_path := get_image_path(effect_nid)
	var palette_nid: String = palette_override
	if palette_nid == "":
		palette_nid = default_palette_nid(effect_nid)
	return CombatPaletteSystem.load_palettized_image(img_path, palette_nid)


static func clear_cache() -> void:
	_effects_cache.clear()
	_loaded = false
