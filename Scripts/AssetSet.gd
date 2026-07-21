class_name AssetSet
extends RefCounted

# ============================================================
# AssetSet — set gráfico activo (Original / GBA / HD).
# ============================================================
# Los assets viven en subcarpetas por set:
#   res://assets/{GBA,HD}/<misma estructura de siempre>       (unificados)
#   res://assets/Original/{fe4,fe5}/<misma estructura>        (separados por juego)
# El set Original usa arte de los juegos ORIGINALES, que colisiona entre FE4 y
# FE5, así que va separado por juego; el juego activo se intercala en vivo.
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

# Carpetas GENERALES del proyecto: NO dependen del set gráfico, así que viven en
# res://assets/<dir>/ (no en assets/{GBA,HD,Original}/). p() las devuelve tal cual.
# Las traducciones y banderas de idioma son del proyecto, no de la calidad gráfica.
const SHARED := ["languages"]

# Sets cuyos recursos van SEPARADOS por juego (subcarpeta fe4/fe5). El set
# "Original" usa el arte de los juegos originales, que colisionaría entre FE4 y
# FE5 (mismos nombres, arte distinto), así que vive en Original/{fe4,fe5}/…. GBA
# y HD son unificados (un solo estilo para ambos juegos) y NO se separan.
const GAME_SPLIT_SETS := ["Original"]

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
	# Carpetas generales (languages/…): son del proyecto, no del set → sin re-enraizar.
	for shared in SHARED:
		if rel == shared or rel.begins_with(shared + "/"):
			return path
	# Si la ruta ya viene enraizada en un set, quitar ese prefijo para re-enraizar.
	for known in SETS:
		if rel.begins_with(known + "/"):
			rel = rel.substr(known.length() + 1)
			break
	# Y si tras ello queda un prefijo de juego (fe4/ o fe5/), quitarlo también,
	# para volver a intercalar el juego activo sin duplicar (p. ej. si llega ya
	# como "Original/fe4/menus/x.png").
	for g in ["fe4/", "fe5/"]:
		if rel.begins_with(g):
			rel = rel.substr(g.length())
			break
	var s := current()
	# El set "Original" intercala el juego activo (fe4/fe5) para no pisar arte
	# entre juegos. El juego se consulta EN VIVO (no se cachea) porque en SAGA
	# cambia por capítulo. GBA/HD son unificados: sin subcarpeta de juego.
	var sub := ""
	if s in GAME_SPLIT_SETS:
		sub = _current_game() + "/"
	var candidate := ROOT + s + "/" + sub + rel
	if s != FALLBACK and not _exists(candidate):
		return ROOT + FALLBACK + "/" + rel   # fallback unificado a GBA
	return candidate


## Juego activo ("fe4"/"fe5") para el set Original, leído EN VIVO de GameMode
## (autoload). En SAGA cambia por capítulo. Fuera del árbol de escena (tests,
## herramientas) o sin GameMode, default "fe4".
static func _current_game() -> String:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		var gm = (loop as SceneTree).root.get_node_or_null("/root/GameMode")
		if gm != null and gm.has_method("get_current_game"):
			return str(gm.get_current_game())
	return "fe4"


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
