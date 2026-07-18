class_name VideoResolver
extends RefCounted

# ============================================================
# VideoResolver — resolución de vídeos localizados (intro y demo).
# ============================================================
# Estructura de carpetas en assets/videos/ (la carpeta codifica modo y tipo; el
# NOMBRE de archivo repite el modo, tal como están nombrados los vídeos):
#   · Intro: {mode}/intros/{mode}_{idioma}.ogv       ej: fe4/intros/fe4_en.ogv
#   · Demo:  {mode}/demos/{mode}_demo_{idioma}.ogv    ej: fe5/demos/fe5_demo_jp.ogv
# donde {mode} = "fe4" | "fe5". El sufijo de idioma sale del locale (ja → "jp").
# Si no existe el vídeo del idioma actual, se cae por defecto al _en de la misma
# carpeta. Devuelve "" si no hay ninguno (el caller decide: saltar la intro / no
# lanzar la demo).
#
# NOTA: los vídeos NO pasan por el sistema de sets gráficos (AssetSet). Un vídeo
# localizado de intro/demo es el mismo con cualquier set (Original/GBA/HD), así
# que vive en assets/videos/ (nivel superior) y se referencia literal.
# ============================================================

const DIR := "res://assets/videos/"


## Sufijo de idioma del locale actual (p.ej. "en", "es", "de"; japonés → "jp").
static func lang_suffix() -> String:
	var loc := TranslationServer.get_locale().substr(0, 2).to_lower()
	return "jp" if loc == "ja" else loc


## Ruta del vídeo, con fallback al _en de la misma carpeta; "" si no hay.
##   mode: "fe4" | "fe5"      kind: "intros" | "demos"
## Nombre: intros → "{mode}_{lang}.ogv"; demos → "{mode}_demo_{lang}.ogv".
static func localized(mode: String, kind: String) -> String:
	var dir := "%s%s/%s/" % [DIR, mode, kind]
	# El stem del archivo repite el modo (y añade "_demo" en las demos).
	var stem: String = mode if kind == "intros" else mode + "_demo"
	var lang := lang_suffix()
	var candidates: Array = [dir + "%s_%s.ogv" % [stem, lang]]
	if lang != "en":
		candidates.append(dir + "%s_en.ogv" % stem)
	for p in candidates:
		if ResourceLoader.exists(p):
			return p
	return ""
