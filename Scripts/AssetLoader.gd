# AssetLoader.gd
# Singleton centralizado para cargar assets gráficos y de audio del LT-maker.
#
# Configurar como autoload en project.godot:
#   AssetLoader="*res://Scripts/AssetLoader.gd"
#
# === ESTRUCTURA DE ASSETS (post-reestructuración) ===
#
#   res://assets/
#   ├── animations/                  ← efectos de mapa (AOE_Fireball, etc.)
#   ├── autotiles/                   ← tiles animados (agua, lava)
#   ├── combat_displays/             ← UI de combate (HP gems, panels)
#   ├── combat_effects/              ← efectos de combate (Aether, magias)
#   ├── damage_numbers/              ← números flotantes de daño
#   ├── displays/                    ← UI displays variados
#   ├── exp_displays/                ← UI de barra de EXP
#   ├── fonts/                       ← sprite fonts (.png + .idx)
#   ├── highlights/                  ← cursors / highlights de selección
#   ├── icons16/                     ← iconos 16px
#   ├── icons32/                     ← iconos 32px
#   ├── icons6/                      ← iconos 6px (custom)
#   ├── info_menu/                   ← UI del info menu
#   ├── map_icons/                   ← iconos del mapa (city, fort, throne)
#   ├── map_sprites/                 ← sprites de unidades en el mapa
#   ├── markers/                     ← markers (objetivos, eventos)
#   ├── menus/                       ← UI de menús
#   ├── minimap/                     ← assets del minimap
#   ├── panoramas/                   ← fondos (cinemáticas, title)
#   ├── particles/                   ← partículas
#   ├── platforms/                   ← fondos de combate cinematográfico
#   ├── portraits/
#   │   ├── characters/              ← retratos de personajes (Sigurd, Leif…)
#   │   ├── extra/                   ← NPCs, secundarios
#   │   └── generic/                 ← Generic_Portrait_{Class}.png
#   ├── sprites/                     ← UI engine (cursor, banners…)
#   ├── tilesets/
#   │   ├── FE4/                     ← mapas FE4 pre-renderizados
#   │   ├── FE5/                     ← mapas FE5 pre-renderizados
#   │   ├── BaseFloor.png            ← compartidos
#   │   ├── LayerTiles.png
#   │   └── tileset.json
#   ├── tilemaps/
#   │   ├── FE4/{tilemap.json, tilemap_data/}
#   │   └── FE5/{tilemap.json, tilemap_data/}
#   ├── music/                       ← música (.ogg/.mp3)
#   ├── sfx/                         ← efectos de sonido
#   └── (combat_anims, combat_palettes — los añadirá el usuario después)

extends Node


# ══════════════════════════════════════════════════════════════════════════════
# Configuración de paths
# ══════════════════════════════════════════════════════════════════════════════

# COMPARTIDOS — un solo path, sin distinción FE4/FE5.
const PATH_MAP_SPRITES   := "res://assets/map_sprites/"
const PATH_ANIMATIONS    := "res://assets/animations/"
const PATH_AUTOTILES     := "res://assets/autotiles/"
const PATH_COMBAT_FX     := "res://assets/combat_effects/"
const PATH_COMBAT_DISPLAYS := "res://assets/combat_displays/"
const PATH_DAMAGE_NUMBERS := "res://assets/damage_numbers/"
const PATH_DISPLAYS      := "res://assets/displays/"
const PATH_EXP_DISPLAYS  := "res://assets/exp_displays/"
const PATH_FONTS         := "res://assets/fonts/"
const PATH_HIGHLIGHTS    := "res://assets/highlights/"
const PATH_ICONS_16      := "res://assets/icons16/"
const PATH_ICONS_32      := "res://assets/icons32/"
const PATH_ICONS_6       := "res://assets/icons6/"
const PATH_INFO_MENU     := "res://assets/info_menu/"
const PATH_MAP_ICONS     := "res://assets/map_icons/"
const PATH_MARKERS       := "res://assets/markers/"
const PATH_MENUS         := "res://assets/menus/"
const PATH_MINIMAP       := "res://assets/minimap/"
const PATH_PANORAMAS     := "res://assets/panoramas/"
const PATH_PARTICLES     := "res://assets/particles/"
const PATH_PLATFORMS     := "res://assets/platforms/"
const PATH_SPRITES       := "res://assets/sprites/"
const PATH_MUSIC         := "res://assets/music/"
const PATH_SFX           := "res://assets/sfx/"

# PORTRAITS — subcarpetas por categoría.
const PATH_PORTRAITS_CHARS   := "res://assets/portraits/characters/"
const PATH_PORTRAITS_GENERIC := "res://assets/portraits/generic/"
const PATH_PORTRAITS_EXTRA   := "res://assets/portraits/extra/"

# ESPECÍFICOS POR JUEGO — subcarpetas FE4/FE5 dentro de tilesets/ y tilemaps/.
const PATH_TILESETS_BASE := "res://assets/tilesets/"
const PATH_TILESETS_FE4  := "res://assets/tilesets/FE4/"
const PATH_TILESETS_FE5  := "res://assets/tilesets/FE5/"
const PATH_TILEMAPS_FE4  := "res://assets/tilemaps/FE4/tilemap_data/"
const PATH_TILEMAPS_FE5  := "res://assets/tilemaps/FE5/tilemap_data/"

# COMBAT ANIMS Y PALETTES — los añadirá el usuario más tarde.
const PATH_COMBAT_ANIMS    := "res://assets/combat_anims/"
const PATH_COMBAT_PALETTES := "res://assets/combat_palettes/palette_data/"


## Orden de búsqueda para tilesets/tilemaps según juego activo.
var _tileset_search_order: Array = [PATH_TILESETS_FE4, PATH_TILESETS_FE5,
		PATH_TILESETS_BASE]
var _tilemap_search_order: Array = [PATH_TILEMAPS_FE4, PATH_TILEMAPS_FE5]


## Cambia el orden de búsqueda según el juego activo.
##   game: "fe4" o "fe5"
func set_active_game(game: String) -> void:
	match game.to_lower():
		"fe4":
			_tileset_search_order = [PATH_TILESETS_FE4, PATH_TILESETS_FE5,
					PATH_TILESETS_BASE]
			_tilemap_search_order = [PATH_TILEMAPS_FE4, PATH_TILEMAPS_FE5]
		"fe5":
			_tileset_search_order = [PATH_TILESETS_FE5, PATH_TILESETS_FE4,
					PATH_TILESETS_BASE]
			_tilemap_search_order = [PATH_TILEMAPS_FE5, PATH_TILEMAPS_FE4]
		_:
			push_warning("AssetLoader: juego desconocido '%s' — usando FE4" % game)


## Resuelve un path de tileset probando primero FE4, luego FE5, luego raíz.
##   filename: nombre del archivo con extensión (ej. "Prologue.png")
func resolve_tileset_path(filename: String) -> String:
	for base in _tileset_search_order:
		var path: String = AssetSet.p(base + filename)
		if ResourceLoader.exists(path):
			return path
	return ""


## Idem para tilemap data JSONs.
func resolve_tilemap_path(filename: String) -> String:
	for base in _tilemap_search_order:
		var path: String = AssetSet.p(base + filename)
		if ResourceLoader.exists(path):
			return path
	return ""


# ══════════════════════════════════════════════════════════════════════════════
# Caches
# ══════════════════════════════════════════════════════════════════════════════

var _portrait_cache: Dictionary = {}      # nid → Texture2D
var _tileset_cache: Dictionary = {}       # nid → Texture2D
var _icon_cache: Dictionary = {}          # "size:nid" → Texture2D
var _map_sprite_cache: Dictionary = {}    # "nid:variant" → Texture2D


# ══════════════════════════════════════════════════════════════════════════════
# PORTRAITS
# ══════════════════════════════════════════════════════════════════════════════

## Alias de retrato para personajes con MÚLTIPLES apariciones cuyo arte está
## diferenciado por edad/juego (no existe un "{nid}.png" plano).  Los eventos
## los referencian por el token base (p.ej. "Lewyn"), así que aquí se mapea al
## archivo diferenciado por defecto.  Se usa la forma de la 1ª generación de
## FE4 (Young), que es el contenido construido actualmente.
##   TODO: selección por juego (FE4→Young, FE5→Old) para cross-game como Finn.
const PORTRAIT_ALIASES: Dictionary = {
	"Arvis":  "ArvisYoung",
	"Finn":   "FinnYoung",
	"Lewyn":  "LewynYoung",
	"Oifaye": "OifayeYoung",
	"Oifey":  "OifayeYoung",
	"Robert": "RobertFE5",   # Robert aparece en FE4 y FE5 (RobertFE4/RobertFE5)
}

## Carga el retrato de un personaje.  Busca en este orden:
##   1. alias de personaje multi-aparición (PORTRAIT_ALIASES)
##   2. portraits/characters/{nid}.png       (personajes principales)
##   3. portraits/extra/{nid}.png            (NPCs y secundarios)
##   4. portraits/{nid}Portrait.png          (compatibilidad legacy)
##   5. portraits/{nid}.png                  (compatibilidad legacy)
func get_portrait(character_nid: String) -> Texture2D:
	if _portrait_cache.has(character_nid):
		return _portrait_cache[character_nid]
	var candidates := [
		PATH_PORTRAITS_CHARS + character_nid + ".png",
		PATH_PORTRAITS_EXTRA + character_nid + ".png",
		# Fallbacks legacy (por si quedan archivos viejos):
		"res://assets/portraits/" + character_nid + "Portrait.png",
		"res://assets/portraits/" + character_nid + ".png",
	]
	# Si el token base no tiene archivo propio pero es un personaje
	# multi-aparición, resolver por su alias diferenciado.
	if PORTRAIT_ALIASES.has(character_nid):
		candidates.push_front(PATH_PORTRAITS_CHARS + PORTRAIT_ALIASES[character_nid] + ".png")
	var tex: Texture2D = null
	for path in candidates:
		var rp := AssetSet.p(path)   # re-enraíza al set gráfico activo (fallback GBA)
		if ResourceLoader.exists(rp):
			tex = load(rp) as Texture2D
			break
	_portrait_cache[character_nid] = tex
	return tex


## Carga el retrato genérico de una clase.  Path canónico:
##   portraits/generic/Generic_Portrait_{Class}.png
func get_generic_portrait(class_nid: String) -> Texture2D:
	var key := "_generic:" + class_nid
	if _portrait_cache.has(key):
		return _portrait_cache[key]
	var path := AssetSet.p(PATH_PORTRAITS_GENERIC + "Generic_Portrait_" + class_nid + ".png")
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	_portrait_cache[key] = tex
	return tex


# ══════════════════════════════════════════════════════════════════════════════
# MAP SPRITES (unidades en el mapa)
# ══════════════════════════════════════════════════════════════════════════════

## Carga la hoja de map sprite de una clase.
##   map_sprite_nid : el nid del sprite (campo `map_sprite_nid` de la clase en
##                    classes.json — ya resuelve casos como Ballistae→Ballistician).
##   variant        : "stand" (idle/gris/activo, 192×144, celdas 64×48) o
##                    "move"  (4 direcciones, 192×160, celdas 48×40).
## Devuelve null si no existe (el caller hace fallback al marcador de color).
func get_map_sprite(map_sprite_nid: String, variant: String = "stand") -> Texture2D:
	var key := map_sprite_nid + ":" + variant
	if _map_sprite_cache.has(key):
		return _map_sprite_cache[key]
	var path := AssetSet.p(PATH_MAP_SPRITES + map_sprite_nid + "-" + variant + ".png")
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	_map_sprite_cache[key] = tex
	return tex


# ══════════════════════════════════════════════════════════════════════════════
# TILESETS / TILEMAPS PRE-RENDERIZADOS
# ══════════════════════════════════════════════════════════════════════════════

## Carga el PNG pre-renderizado del mapa de un capítulo.  Busca en
## tilesets/FE4/, luego tilesets/FE5/, luego tilesets/ raíz.
func get_tilemap_image(tilemap_nid: String) -> Texture2D:
	if _tileset_cache.has(tilemap_nid):
		return _tileset_cache[tilemap_nid]
	var path := resolve_tileset_path(tilemap_nid + ".png")
	var tex: Texture2D = null
	if path != "":
		tex = load(path) as Texture2D
	_tileset_cache[tilemap_nid] = tex
	return tex


## Carga los autotiles animados específicos de un cap.
##   tilemap_nid: "Prologue" → carga tilesets/FE4/Prologue_autotiles.png
func get_tilemap_autotiles(tilemap_nid: String) -> Texture2D:
	var key := tilemap_nid + ":autotiles"
	if _tileset_cache.has(key):
		return _tileset_cache[key]
	var path := resolve_tileset_path(tilemap_nid + "_autotiles.png")
	var tex: Texture2D = null
	if path != "":
		tex = load(path) as Texture2D
	_tileset_cache[key] = tex
	return tex


# ══════════════════════════════════════════════════════════════════════════════
# ICONOS
# ══════════════════════════════════════════════════════════════════════════════

func get_icon_sheet_16(sheet_name: String) -> Texture2D:
	return _get_icon_sheet(PATH_ICONS_16, sheet_name, 16)


func get_icon_sheet_32(sheet_name: String) -> Texture2D:
	return _get_icon_sheet(PATH_ICONS_32, sheet_name, 32)


func get_icon_sheet_6(sheet_name: String) -> Texture2D:
	return _get_icon_sheet(PATH_ICONS_6, sheet_name, 6)


func _get_icon_sheet(base_path: String, sheet_name: String, size: int) -> Texture2D:
	var key := "%d:%s" % [size, sheet_name]
	if _icon_cache.has(key):
		return _icon_cache[key]
	var path := AssetSet.p(base_path + sheet_name + ".png")
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	_icon_cache[key] = tex
	return tex


## Crea un AtlasTexture para un icono individual de una sheet.
##   sheet_name: nombre del archivo (sin ext).
##   coord:      coordenada del icono dentro de la sheet (en celdas).
##   size:       tamaño del icono (16, 32, 6).
func get_icon_atlas(sheet_name: String, coord: Vector2i,
		size: int = 16) -> AtlasTexture:
	var sheet: Texture2D
	match size:
		16:  sheet = get_icon_sheet_16(sheet_name)
		32:  sheet = get_icon_sheet_32(sheet_name)
		6:   sheet = get_icon_sheet_6(sheet_name)
		_:   sheet = get_icon_sheet_16(sheet_name)
	if sheet == null:
		return null
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = Rect2(coord.x * size, coord.y * size, size, size)
	return atlas


# ══════════════════════════════════════════════════════════════════════════════
# PANORAMAS
# ══════════════════════════════════════════════════════════════════════════════

## Carga un panorama estático.  Para panoramas animados (multi-frame
## procesados en spritesheet), usa el nodo AnimatedTitleBackground.
func get_panorama(panorama_nid: String) -> Texture2D:
	var path := AssetSet.p(PATH_PANORAMAS + panorama_nid + ".png")
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


# ══════════════════════════════════════════════════════════════════════════════
# UI DEL ENGINE LT (sprites/, menus/, displays/, etc.)
# ══════════════════════════════════════════════════════════════════════════════

## Carga un sprite del engine LT desde una de las carpetas de UI.
##   category: "sprites", "menus", "displays", "info_menu",
##             "combat_displays", "damage_numbers", "exp_displays",
##             "highlights", "markers", "minimap", "particles".
##   filename: nombre con extensión (ej. "cursor.png")
func get_ui_sprite(category: String, filename: String) -> Texture2D:
	var base := ""
	match category:
		"sprites":          base = PATH_SPRITES
		"menus":            base = PATH_MENUS
		"displays":         base = PATH_DISPLAYS
		"info_menu":        base = PATH_INFO_MENU
		"combat_displays": base = PATH_COMBAT_DISPLAYS
		"damage_numbers":   base = PATH_DAMAGE_NUMBERS
		"exp_displays":     base = PATH_EXP_DISPLAYS
		"highlights":       base = PATH_HIGHLIGHTS
		"markers":          base = PATH_MARKERS
		"minimap":          base = PATH_MINIMAP
		"particles":        base = PATH_PARTICLES
		_:
			push_warning("AssetLoader: categoría UI desconocida '%s'" % category)
			return null
	var path := AssetSet.p(base + filename)
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


# ══════════════════════════════════════════════════════════════════════════════
# AUTOTILES, FONTS, PLATFORMS
# ══════════════════════════════════════════════════════════════════════════════

## Tile animado del fondo (agua, lava, etc.).
##   nid: "field_water1", "lava", "ship_water"...
func get_autotile(nid: String) -> Texture2D:
	var path := AssetSet.p(PATH_AUTOTILES + nid + ".png")
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


## PNG de un sprite font del LT.
##   nid: "convo-black", "chapter-yellow", "class-purple"...
func get_font_image(nid: String) -> Texture2D:
	var path := AssetSet.p(PATH_FONTS + nid + ".png")
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


## .idx de un sprite font (anchos de carácter).
func get_font_idx(nid: String) -> PackedByteArray:
	var path := AssetSet.p(PATH_FONTS + nid + ".idx")
	if not FileAccess.file_exists(path):
		return PackedByteArray()
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return PackedByteArray()
	var data := f.get_buffer(f.get_length())
	f.close()
	return data


## Platform de combate (fondo animado del combate cinematográfico).
##   nid: "Arena", "Bridge", "Forest"...
##   variant: "Melee" o "Ranged".
func get_combat_platform(nid: String, variant: String = "Melee") -> Texture2D:
	var path := AssetSet.p("%s%s-%s.png" % [PATH_PLATFORMS, nid, variant])
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


# ══════════════════════════════════════════════════════════════════════════════
# AUDIO
# ══════════════════════════════════════════════════════════════════════════════

## Carga música.  Auto-detecta extensión: .ogg, .mp3, .wav.
func get_music(nid: String) -> AudioStream:
	for ext in [".ogg", ".mp3", ".wav"]:
		var path: String = AssetSet.p(PATH_MUSIC + nid + ext)
		if ResourceLoader.exists(path):
			return load(path) as AudioStream
	return null


## Carga SFX.
func get_sfx(nid: String) -> AudioStream:
	for ext in [".ogg", ".mp3", ".wav"]:
		var path: String = AssetSet.p(PATH_SFX + nid + ext)
		if ResourceLoader.exists(path):
			return load(path) as AudioStream
	return null


# ══════════════════════════════════════════════════════════════════════════════
# UTILIDADES
# ══════════════════════════════════════════════════════════════════════════════

## Limpia todos los caches.
func clear_all_caches() -> void:
	_portrait_cache.clear()
	_tileset_cache.clear()
	_icon_cache.clear()
	UnitSprite.clear_cache()


## Devuelve {"ok": bool, "missing": Array} con los assets faltantes para
## un capítulo.  Útil para debug.
func validate_chapter_assets(tilemap_nid: String, character_nids: Array) -> Dictionary:
	var report := { "ok": true, "missing": [] }
	if get_tilemap_image(tilemap_nid) == null:
		report.ok = false
		report.missing.append("tilesets/FE4|FE5/" + tilemap_nid + ".png")
	for nid in character_nids:
		if get_portrait(str(nid)) == null:
			report.missing.append("portraits/characters|extra/" + str(nid) + ".png")
	return report
