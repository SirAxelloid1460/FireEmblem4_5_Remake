class_name VideoResolver
extends RefCounted

# ============================================================
# VideoResolver — resolución de vídeos localizados (intro y demo).
# ============================================================
# Convención de nombres en assets/videos/:
#   · Intro: fe4_{idioma}.ogv / fe5_{idioma}.ogv
#   · Demo:  fe4_demo_{idioma}.ogv / fe5_demo_{idioma}.ogv
# El sufijo de idioma sale del locale actual (ja → "jp"). Si no existe el vídeo
# del idioma actual, se cae por defecto a la versión _en. Devuelve "" si no hay
# ninguno (el caller decide: saltar la intro / no lanzar la demo).
# ============================================================

const DIR := "res://assets/videos/"


## Sufijo de idioma del locale actual (p.ej. "en", "es", "de"; japonés → "jp").
static func lang_suffix() -> String:
	var loc := TranslationServer.get_locale().substr(0, 2).to_lower()
	return "jp" if loc == "ja" else loc


## Ruta de "{base}_{idioma}.ogv", con fallback a "{base}_en.ogv"; "" si no hay.
static func localized(base: String) -> String:
	var lang := lang_suffix()
	var candidates: Array = [DIR + "%s_%s.ogv" % [base, lang]]
	if lang != "en":
		candidates.append(DIR + "%s_en.ogv" % base)
	for p in candidates:
		if ResourceLoader.exists(p):
			return p
	return ""
