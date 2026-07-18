class_name AssetSet
extends RefCounted

# ============================================================
# AssetSet — set gráfico activo (Original / GBA / HD).
# ============================================================
# Los assets viven en subcarpetas por set:
#   res://assets/{Original,GBA,HD}/<misma estructura de siempre>
# El código sigue usando rutas LÓGICAS "res://assets/X"; AssetSet.p() las
# re-enraíza al set activo, con FALLBACK a GBA si el asset no existe en el set
# elegido. Así, Original/HD pueden estar incompletos y todo sigue funcionando.
#
# Clase ESTÁTICA (como VideoResolver): sin autoload, accesible desde cualquier
# contexto. El set se lee UNA vez de user://settings.cfg y se cachea. El cambio
# de set NO se aplica en caliente: se guarda y surte efecto al reiniciar el
# juego (ver OptionsMenu / AssetSet.save).
# ============================================================

const ROOT := "res://assets/"
const SETS := ["Original", "GBA", "HD"]
const DEFAULT := "GBA"
const FALLBACK := "GBA"
const CFG := "user://settings.cfg"

static var _set_cached := ""


## Set activo de esta sesión (cacheado; leído de settings.cfg la 1ª vez).
static func current() -> String:
	if _set_cached == "":
		_set_cached = DEFAULT
		var cfg := ConfigFile.new()
		if cfg.load(CFG) == OK:
			var s := str(cfg.get_value("graphics", "set", DEFAULT))
			if s in SETS:
				_set_cached = s
	return _set_cached


## Re-enraíza "res://assets/X" al set activo → "res://assets/{set}/X".
## Si el asset no existe en el set elegido, cae a GBA. Rutas que no empiezan por
## "res://assets/" se devuelven tal cual (no son assets de set).
static func p(path: String) -> String:
	if not path.begins_with(ROOT):
		return path
	var rel := path.substr(ROOT.length())          # "menus/foo.png" o "GBA/menus/foo.png"
	# Si la ruta ya viene enraizada en un set, quitar ese prefijo para re-enraizar.
	for known in SETS:
		if rel.begins_with(known + "/"):
			rel = rel.substr(known.length() + 1)
			break
	var s := current()
	var candidate := ROOT + s + "/" + rel
	if s != FALLBACK and not _exists(candidate):
		return ROOT + FALLBACK + "/" + rel
	return candidate


## Existe el recurso (imported), el archivo crudo (.idx/.json) o el directorio
## (para paths de carpeta como music/ que se escanean con DirAccess).
static func _exists(path: String) -> bool:
	return ResourceLoader.exists(path) or FileAccess.file_exists(path) \
		or DirAccess.dir_exists_absolute(path)


## Guarda el set elegido (aplica al REINICIAR; no cambia la sesión actual).
static func save(s: String) -> void:
	if s not in SETS:
		return
	var cfg := ConfigFile.new()
	cfg.load(CFG)   # puede no existir aún; se ignora el error
	cfg.set_value("graphics", "set", s)
	cfg.save(CFG)
