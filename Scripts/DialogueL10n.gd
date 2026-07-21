extends Node
# ============================================================
# DialogueL10n — localización de diálogos en runtime (autoload)
# ============================================================
# Los eventos guardan el texto inline en INGLÉS (fuente de verdad y fallback).
# Aparte, un documento por (juego, capítulo, idioma) trae las líneas traducidas
# agrupadas por ESCENA (= el `name` del evento), en el mismo orden que los
# comandos `speak`:
#
#   res://data/<game>/events/lang/<chapter>/dialogue.<locale>.json
#   {
#     "<SCENE_KEY>": [ { "SPEAKER": "línea{w}..." }, ... ],
#     ...
#   }
#
# El EventSystem, al ejecutar un `speak`, pide aquí la línea por
# (escena, índice-dentro-de-la-escena); si no existe en el idioma activo se cae
# al idioma de respaldo (inglés), y si tampoco, al texto inline del propio evento.
#
# CLAVES JAPONESAS: el documento japonés usa una descripción en japonés con el
# equivalente latino anotado entre ⟦ ... ⟧ (ver docs/dialogue_localization_handoff.md);
# aquí se normaliza a esa clave latina al cargar. Además, el proyecto usa el
# locale "ja" mientras la extracción nombra los archivos ".jp." → se prueban ambos.
#
# NOTA GDScript: Dictionary por corchetes; Godot 4 no tiene dot-access.
# ============================================================

const DIR := "res://data/%s/events/lang/%s"        # game, chapter
const FALLBACK_LOCALE := "en"
# Alias de sufijo de archivo por locale (proyecto "ja" ↔ extracción "jp").
const LOCALE_ALIASES := { "ja": ["ja", "jp"], "jp": ["jp", "ja"] }

# "game|chapter|locale" -> Dictionary(scene_key -> Array de {speaker:línea}).
# Se cachea también el vacío (no hay documento) para no reintentar el disco.
var _cache: Dictionary = {}


## Línea localizada de un `speak`. `fallback_line` = el texto inline del evento
## (inglés). Devuelve la traducción del locale activo, o del inglés, o el inline.
func line(game: String, chapter: String, scene_key: String, index: int, fallback_line: String) -> String:
	if chapter == "" or scene_key == "":
		return fallback_line
	var loc := _short_locale(TranslationServer.get_locale())
	var got = _lookup(game, chapter, loc, scene_key, index)
	if got != null:
		return str(got)
	if loc != FALLBACK_LOCALE:
		got = _lookup(game, chapter, FALLBACK_LOCALE, scene_key, index)
		if got != null:
			return str(got)
	return fallback_line


## Vacía la caché (al cambiar de idioma o de capítulo, si se quiere forzar).
func clear_cache() -> void:
	_cache.clear()


# ── Interno ───────────────────────────────────────────────────────────────────
func _short_locale(loc: String) -> String:
	return loc.substr(0, 2).to_lower()


func _lookup(game: String, chapter: String, loc: String, scene_key: String, index: int):
	var doc: Dictionary = _load(game, chapter, loc)
	if not doc.has(scene_key):
		return null
	var arr = doc[scene_key]
	if not (arr is Array) or index < 0 or index >= arr.size():
		return null
	var entry = arr[index]
	if not (entry is Dictionary) or entry.is_empty():
		return null
	# El texto es el valor; la etiqueta de hablante del documento es metadato (el
	# hablante y el retrato reales los pone el evento, no el documento).
	var speaker = entry.keys()[0]
	return str(entry[speaker])


func _load(game: String, chapter: String, loc: String) -> Dictionary:
	var key := "%s|%s|%s" % [game, chapter, loc]
	if _cache.has(key):
		return _cache[key]
	var doc: Dictionary = {}
	for suffix in _suffixes(loc):
		var path: String = (DIR % [game, chapter]) + "/dialogue.%s.json" % suffix
		if not FileAccess.file_exists(path):
			continue
		var f := FileAccess.open(path, FileAccess.READ)
		if f == null:
			continue
		var parsed = JSON.parse_string(f.get_as_text())
		f.close()
		if parsed is Dictionary:
			for raw in parsed.keys():
				doc[_latin_key(str(raw))] = parsed[raw]
		break
	_cache[key] = doc
	return doc


func _suffixes(loc: String) -> Array:
	return LOCALE_ALIASES.get(loc, [loc])


## Clave latina de una clave de escena: contenido de ⟦...⟧ si lo hay (japonés),
## o la clave tal cual (idiomas de alfabeto latino).
func _latin_key(raw: String) -> String:
	var a := raw.find("⟦")
	var b := raw.rfind("⟧")
	if a != -1 and b != -1 and b > a:
		return raw.substr(a + 1, b - a - 1).strip_edges()
	return raw.strip_edges()
