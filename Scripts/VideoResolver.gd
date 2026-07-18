class_name VideoResolver
extends RefCounted

# ============================================================
# VideoResolver — resolución de vídeos localizados (intro y demo).
# ============================================================
# Estructura de carpetas en assets/videos/ (la carpeta ya codifica modo y tipo,
# así que el archivo sólo lleva el idioma):
#   · Intro: {mode}/intros/{idioma}.ogv     ej: fe4/intros/en.ogv
#   · Demo:  {mode}/demos/{idioma}.ogv       ej: fe5/demos/jp.ogv
# donde {mode} = "fe4" | "fe5". El sufijo de idioma sale del locale (ja → "jp").
# Si no existe el vídeo del idioma actual, se cae por defecto a en.ogv de la
# misma carpeta. Devuelve "" si no hay ninguno (el caller decide: saltar la
# intro / no lanzar la demo).
# ============================================================

const DIR := "res://assets/videos/"


## Sufijo de idioma del locale actual (p.ej. "en", "es", "de"; japonés → "jp").
static func lang_suffix() -> String:
	var loc := TranslationServer.get_locale().substr(0, 2).to_lower()
	return "jp" if loc == "ja" else loc


## Ruta de "{mode}/{kind}/{idioma}.ogv", con fallback a ".../en.ogv"; "" si no hay.
##   mode: "fe4" | "fe5"      kind: "intros" | "demos"
static func localized(mode: String, kind: String) -> String:
	var dir := "%s%s/%s/" % [DIR, mode, kind]
	var lang := lang_suffix()
	var candidates: Array = [dir + "%s.ogv" % lang]
	if lang != "en":
		candidates.append(dir + "en.ogv")
	for p in candidates:
		if ResourceLoader.exists(p):
			return p
	return ""
