# CombatAnimResolver.gd
# Decide qué animación de combate corresponde a un unit con un arma equipada
# y la distancia del objetivo (melee/ranged).
#
# Aplica esta jerarquía de búsqueda (devuelve el primer match):
#
#   1. {NID}_{CharacterName}_{Weapon}    ← variante PRF (Sigurd, Ishtar)
#   2. {NID}_{Male|Female}_{Weapon}      ← género específico
#   3. {NID}_Generic_{Weapon}            ← fallback universal
#
# El "Weapon" final depende del arma equipada y la distancia del objetivo:
#
#   weapon_type=Lance, ranged=false    →  "Lance"
#   weapon_type=Lance, ranged=true     →  "Javelin"
#   weapon_type=Axe,   ranged=true     →  "HandAxe"
#   weapon_type=Sword, ranged=true     →  "MagicSword"   (espadas mágicas)
#   weapon_type=Bow                    →  "Bow"
#   weapon_type=Magic, mag_kind=Anima  →  "MagicAnima"
#   weapon_type=Staff                  →  "MagicStaff"
#
# === USO ===
#
#   var anim_name = CombatAnimResolver.resolve(unit, weapon, ranged)
#   var anim = CombatAnimDatabase.load_anim(anim_name)
#   if anim["ok"]:
#       # arrancar el player...

class_name CombatAnimResolver
extends RefCounted


## Mapeo (weapon_type, ranged) → token de arma del archivo final.
## El weapon_type aquí es el tipo de arma del juego (Sword, Lance, Axe,
## Bow, MagicAnima, MagicLight, MagicDark, Staff, Refresh, Unarmed).
static func _resolve_weapon_token(weapon_type: String, ranged: bool) -> String:
	match weapon_type:
		"Sword":
			return "MagicSword" if ranged else "Sword"
		"Lance":
			return "Javelin" if ranged else "Lance"
		"Axe":
			return "HandAxe" if ranged else "Axe"
		"HandAxe":
			return "HandAxe"
		"Javelin":
			return "Javelin"
		"Bow":
			return "Bow"
		"Staff":
			return "MagicStaff"
		"MagicAnima", "Anima":
			return "MagicAnima"
		"MagicLight", "Light":
			return "MagicLight"
		"MagicDark", "Dark":
			return "MagicDark"
		"MagicSword":
			return "MagicSword"
		"Refresh":
			return "Refresh"
		"Dragonstone":
			return "Dragonstone"
		"Unarmed", "":
			return "Unarmed"
		_:
			# Tipo desconocido — devolver tal cual y dejar que falle
			# limpiamente con el fallback Generic.
			return weapon_type


## Resuelve el nombre canónico de la animación a usar.
##
##   unit:        Unit (necesita .unit_class, .unit_name, .gender).
##   weapon_type: Sword/Lance/Axe/Bow/Staff/Magic*/etc.
##   ranged:      true si el objetivo está fuera de melee.
##
## Devuelve el primer anim_name que exista, o el fallback Generic
## (aunque no exista) si no hay ninguno — para que el caller pueda
## decidir si mostrar placeholder o lanzar warning.
static func resolve(unit, weapon_type: String, ranged: bool) -> String:
	if unit == null:
		return ""
	var nid: String = str(unit.unit_class) if "unit_class" in unit else ""
	if nid == "":
		return ""

	var weapon_token: String = _resolve_weapon_token(weapon_type, ranged)

	# 1. Variante PRF — usar el unit_name como token de personaje.
	var char_name: String = ""
	if "unit_name" in unit:
		char_name = str(unit.unit_name)
	if char_name != "":
		var prf_name := "%s_%s_%s" % [nid, char_name, weapon_token]
		if CombatAnimDatabase.has_anim(prf_name):
			return prf_name

	# 2. Variante por género (solo M/F; U usa Generic).
	var gender: String = "M"
	if "gender" in unit:
		gender = str(unit.gender).to_upper()
	var gender_token: String = ""
	match gender:
		"M": gender_token = "Male"
		"F": gender_token = "Female"
		# "U" o cualquier otro → no hay variante específica
	if gender_token != "":
		var gendered_name := "%s_%s_%s" % [nid, gender_token, weapon_token]
		if CombatAnimDatabase.has_anim(gendered_name):
			return gendered_name

	# 3. Fallback Generic.  Devolver aunque no exista — el caller decide
	# qué hacer si CombatAnimDatabase.has_anim() devuelve false.
	return "%s_Generic_%s" % [nid, weapon_token]


## Versión de debug que devuelve TODOS los candidatos en orden, indicando
## cuál se usaría.  Útil para inspectores y logs.
##
## Devuelve un Array de Dicts: [{"name": String, "exists": bool}, ...].
static func resolve_debug(unit, weapon_type: String, ranged: bool) -> Array:
	var nid: String = str(unit.unit_class) if (unit and "unit_class" in unit) else ""
	var weapon_token: String = _resolve_weapon_token(weapon_type, ranged)
	var char_name: String = str(unit.unit_name) if (unit and "unit_name" in unit) else ""
	var gender: String = str(unit.gender).to_upper() if (unit and "gender" in unit) else "M"

	var candidates: Array = []
	if char_name != "":
		var n := "%s_%s_%s" % [nid, char_name, weapon_token]
		candidates.append({"name": n, "exists": CombatAnimDatabase.has_anim(n)})
	if gender == "M":
		var n2 := "%s_Male_%s" % [nid, weapon_token]
		candidates.append({"name": n2, "exists": CombatAnimDatabase.has_anim(n2)})
	elif gender == "F":
		var n3 := "%s_Female_%s" % [nid, weapon_token]
		candidates.append({"name": n3, "exists": CombatAnimDatabase.has_anim(n3)})
	var generic := "%s_Generic_%s" % [nid, weapon_token]
	candidates.append({"name": generic, "exists": CombatAnimDatabase.has_anim(generic)})
	return candidates
