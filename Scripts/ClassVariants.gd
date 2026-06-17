# ClassVariants.gd
# Sistema de variantes de clase para clases unificadas que tenían múltiples
# versiones en el LT original (Paladin masculino/femenino, Thief con ruta de
# Lara, etc).
#
# Aplica overrides a la data canónica de la clase según condiciones del unit
# (género, identidad del personaje, contexto del cap).
#
# === USO ===
#
#   var data := LTDatabase.get_class_data("Paladin")        # data canónica
#   data = ClassVariants.apply_variants(data, unit)         # con overrides
#   # Ahora data tiene wexp_gain, growths, etc. ajustados al unit concreto
#
# === DISEÑO ===
#
# Los overrides son ESTÁTICOS (un dict por nid de clase).  La data canónica
# del LT NO se toca — se mantiene como base neutra.  Las variantes se
# aplican únicamente cuando se consulta la clase para un unit específico.
#
# Esto permite que:
#  - El JSON canónico siga sirviendo como fuente única de verdad.
#  - Las diferencias por género/personaje vivan en código (versionado).
#  - Sea trivial añadir nuevas variantes (Manaketes infantiles, etc).

class_name ClassVariants
extends RefCounted


# ══════════════════════════════════════════════════════════════════════════════
# DEFINICIÓN DE VARIANTES
# ══════════════════════════════════════════════════════════════════════════════
#
# Estructura: VARIANTS[class_nid] = Array de reglas.
# Cada regla es un Dict con:
#   "predicate":  Callable(unit) -> bool      ← cuándo aplicar
#   "overrides":  Dictionary                  ← qué cambiar en la data
#
# Las "overrides" se aplican como merge profundo sobre la data canónica.
# Para campos escalares (int, string), reemplazan.
# Para diccionarios (wexp_gain, growths, etc.), se hace merge clave a clave.
#
# Las reglas se evalúan en orden; la primera que matchea se aplica.  Si
# ninguna matchea, la data canónica se devuelve sin cambios.

const VARIANTS: Dictionary = {

	# ──────────────────────────────────────────────────────────────────────
	# Paladin: masculinos físicos con lanza, femeninas mágicas con bastón.
	#
	# La data canónica del JSON corresponde al masculino (Sword + Lance,
	# growths físicos).  Las femeninas overridan a Sword + Staff y growths
	# mágicos.
	# ──────────────────────────────────────────────────────────────────────
	"Paladin": [
		{
			"id":        "Paladin_Female",
			"predicate": "_is_female",
			"overrides": {
				# Pierde Lance, gana Staff (Sword se mantiene).
				"wexp_gain": {
					"Lance": [false, 0],
					"Staff": [true, 126],
				},
				# Reorienta growths hacia magia/resistencia.
				#   STR 30 → 15  (menos físico)
				#   MAG 10 → 35  (más mágica)
				#   DEF 30 → 20  (menos defensa)
				#   RES 10 → 30  (más resistencia)
				#   SKL 30 → 35  (un poco más hábil)
				#   SPD 30 → 35  (un poco más rápida)
				"growths": {
					"STR": 15,
					"MAG": 35,
					"SKL": 35,
					"SPD": 35,
					"DEF": 20,
					"RES": 30,
				},
			},
		},
	],

	# ──────────────────────────────────────────────────────────────────────
	# Thief: por defecto promociona a Rogue para cualquier género.
	# La excepción de Lara se maneja en LaraPromotion.gd, no aquí
	# (porque su caso es flujo de evento, no diferencia estática).
	# ──────────────────────────────────────────────────────────────────────
	"Thief": [
		# (Sin variantes activas — todos promocionan a Rogue por defecto.)
	],
}


## Predicados disponibles para las reglas.  Se referencian por nombre como
## string en VARIANTS["overrides"]["predicate"].
##
## Cualquier predicate aquí debe aceptar un Unit y devolver bool.
##
## NOTA SOBRE GÉNERO "U" (UNIVERSAL):
## El género "U" se usa para genéricos (enemigos sin identidad).  Por
## convención, los U usan la variante MASCULINA / canónica.  Si en
## algún cap quieres genéricas femeninas con la variante mágica del
## Paladin, asígnales explícitamente gender="F" en lugar de "U".
static func _eval_predicate(predicate_name: String, unit) -> bool:
	if predicate_name == "_is_female":
		return _is_female(unit)
	if predicate_name == "_is_male":
		return _is_male(unit)
	if predicate_name == "_is_universal":
		return _is_universal(unit)
	push_warning("ClassVariants: predicado desconocido '%s'" % predicate_name)
	return false


## Solo true para gender="F".  Genéricos (U) NO matchean — usan canon.
static func _is_female(unit) -> bool:
	if unit == null:
		return false
	if not "gender" in unit:
		return false
	return str(unit.gender).to_upper() == "F"


## True para gender="M" o "U" (universal cae en variante canónica masculina).
## Si no hay campo gender, asume masculino por defecto.
static func _is_male(unit) -> bool:
	if unit == null:
		return false
	if not "gender" in unit:
		return true  # default masculino si no se ha definido
	var g: String = str(unit.gender).to_upper()
	return g == "M" or g == "U"


## True solo para genéricos (gender="U").
static func _is_universal(unit) -> bool:
	if unit == null:
		return false
	if not "gender" in unit:
		return false
	return str(unit.gender).to_upper() == "U"


# ══════════════════════════════════════════════════════════════════════════════
# API PÚBLICA
# ══════════════════════════════════════════════════════════════════════════════

## Aplica las variantes pertinentes a la data canónica de una clase, según
## el unit que la usa.  Devuelve un nuevo Dict — NO modifica el original.
##
##   class_data: dict canónico cargado del JSON (ej. via LTDatabase).
##   unit:       Unit (o cualquier objeto con .gender, .unit_name, etc).
static func apply_variants(class_data: Dictionary, unit) -> Dictionary:
	if class_data.is_empty():
		return class_data
	var class_nid: String = str(class_data.get("nid", ""))
	if not VARIANTS.has(class_nid):
		return class_data.duplicate(true)
	var rules: Array = VARIANTS[class_nid]
	if rules.is_empty():
		return class_data.duplicate(true)

	# Primera regla cuyo predicado matchee gana.
	var matched_overrides: Dictionary = {}
	for rule in rules:
		var pred_name: String = rule.get("predicate", "")
		if pred_name == "":
			continue
		if _eval_predicate(pred_name, unit):
			matched_overrides = rule.get("overrides", {})
			break

	if matched_overrides.is_empty():
		return class_data.duplicate(true)

	# Deep merge.
	var result: Dictionary = class_data.duplicate(true)
	_deep_merge(result, matched_overrides)
	return result


## Devuelve true si la clase tiene variantes definidas (sin importar si
## alguna aplica al unit).  Útil para debug/UI.
static func has_variants(class_nid: String) -> bool:
	return VARIANTS.has(class_nid) and not (VARIANTS[class_nid] as Array).is_empty()


## Devuelve la lista de IDs de variantes de una clase.  Útil para mostrar
## en debug "esta unidad usa la variante X".
static func get_active_variant_id(class_nid: String, unit) -> String:
	if not VARIANTS.has(class_nid):
		return ""
	for rule in VARIANTS[class_nid]:
		var pred_name: String = rule.get("predicate", "")
		if pred_name == "":
			continue
		if _eval_predicate(pred_name, unit):
			return str(rule.get("id", ""))
	return ""


# ══════════════════════════════════════════════════════════════════════════════
# UTILIDADES
# ══════════════════════════════════════════════════════════════════════════════

## Merge profundo: target se modifica en sitio, sobreescribiendo con valores
## de source.  Para Dictionaries hace merge recursivo; para Arrays y
## escalares reemplaza.
static func _deep_merge(target: Dictionary, source: Dictionary) -> void:
	for key in source.keys():
		var src_val = source[key]
		if target.has(key) and target[key] is Dictionary and src_val is Dictionary:
			_deep_merge(target[key], src_val)
		else:
			target[key] = src_val
