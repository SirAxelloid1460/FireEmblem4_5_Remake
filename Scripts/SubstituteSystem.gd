# SubstituteSystem.gd
# Sistema de personajes sustitutos para la Generación 2 (FE4 Genealogy).
#
# CONCEPTO:
#   Si una madre potencial muere o no se empareja antes del final del cap 5,
#   en lugar de su hijo canónico aparece un sustituto.  Los sustitutos
#   canónicos del juego original son personajes fijos con stats fijos, pero
#   en este remake los stats se CALCULAN dinámicamente combinando:
#     1) Datos canónicos de la madre (clase, growths, holy blood)
#     2) Datos del padre (si lo hubo) — sub-óptimo para sustituto, pero
#        si la madre murió tras casarse el sustituto hereda parcialmente.
#     3) Plantilla de la clase inicial del sustituto.
#     4) "Personality bias" basado en la descripción del personaje.
#
# CANÓNICO FE4 — emparejamientos madre/hijo y sustituto:
#
#   Madre        Hijo canon (M)   Hija canon (F)   Sub. (M)     Sub. (F)
#   ─────────────────────────────────────────────────────────────────────
#   Aideen       Lester (Bow)     Lana (Staff)     Dimna        Muirne
#   Ayra         Ulster (Sword)   Larcei (Sword)   Roddlevan    Radney
#   Lachesis     Diarmuid (Sword) Nanna (Staff)    Tristan      Jeanne
#   Sylvia       Coirpre (Staff)  Lene (Refresh)   Charlot      Laylea
#   Erinys       Ced (Wind)       Fee (Lance/Fly)  Hawk         Femina
#   Brigid       Faval (Bow)      Patty (Sword)    Asaello      Daisy
#   Tailtiu      Arthur (Wind)    Tinny (Thunder)  Amid         Linda
#
# IMPLEMENTACIÓN:
#   • SUBSTITUTE_DEFS contiene las plantillas canónicas de cada sustituto:
#     clase inicial, descripción, growths base, item inicial, holy blood
#     residual (los sustitutos suelen NO tener Major Blood, pero algunos
#     pueden tener Minor para acceder a armas Holy básicas).
#   • Si la madre murió emparejada → el sustituto hereda 50 % del bonus de
#     padre que el hijo canónico habría heredado (parametrizable).
#   • Si la madre nunca se emparejó → stats puros de la plantilla.
#
# CONEXIÓN CON GameManager:
#   Al iniciar gen 2 (transición cap 5 → cap 6), el GameManager itera
#   sobre todas las madres y para cada una llama:
#       SubstituteSystem.resolve_gen2_units(mother_id, mother_state)
#   que devuelve { "male": Unit, "female": Unit }.

class_name SubstituteSystem
extends RefCounted


# ── Definiciones canónicas de sustitutos ─────────────────────────────────────
#
# Cada entrada incluye los stats base del sustituto (level 1 de su tier) y
# growths.  Los valores se basan en los stats reales del FE4 original,
# pero parametrizados para permitir herencia.  La estructura de cada
# sustituto sigue el mismo formato que UnitData de LTDataResources.gd
# para integrarse fluidamente.
#
# Tier inicial: 1 (no promovido) salvo nota.

const SUBSTITUTE_DEFS: Dictionary = {
	# === Aideen / Edain ===
	"Dimna": {
		"replaces": "Lester", "mother_id": "Aideen", "gender": "M",
		"klass": "BowFighter", "tier": 1, "level": 5,
		"desc": "Wandering archer who joined the resistance after losing his family. Works hard but lacks innate gift.",
		"bases":   { "HP":24,"STR":7,"MAG":0,"SKL":7,"SPD":6,"LCK":3,"DEF":5,"RES":0,"CON":8 },
		"growths": { "HP":80,"STR":40,"MAG":0,"SKL":30,"SPD":40,"LCK":30,"DEF":20,"RES":10 },
		"holy_blood": {},
		"start_items": ["IronBow"],
		"skills": [],
	},
	"Muirne": {
		"replaces": "Lana", "mother_id": "Aideen", "gender": "F",
		"klass": "Priest", "tier": 1, "level": 1,
		"desc": "Civilian girl from Isaach raised by Seliph; trained in staves but no Holy Blood.",
		"bases":   { "HP":18,"STR":1,"MAG":4,"SKL":3,"SPD":5,"LCK":5,"DEF":2,"RES":6,"CON":5 },
		"growths": { "HP":60,"STR":10,"MAG":50,"SKL":30,"SPD":40,"LCK":40,"DEF":10,"RES":50 },
		"holy_blood": {},
		"start_items": ["Heal"],
		"skills": [],
	},
	# === Ayra ===
	"Roddlevan": {
		"replaces": "Ulster", "mother_id": "Ayra", "gender": "M",
		"klass": "SwordFighter", "tier": 1, "level": 5,
		"desc": "Quiet swordman from Isaach who lost his parents in the early war.",
		"bases":   { "HP":26,"STR":8,"MAG":0,"SKL":10,"SPD":11,"LCK":3,"DEF":6,"RES":0,"CON":9 },
		"growths": { "HP":80,"STR":50,"MAG":0,"SKL":50,"SPD":60,"LCK":20,"DEF":20,"RES":10 },
		"holy_blood": {},
		"start_items": ["IronSword"],
		"skills": ["Pursuit"],
	},
	"Radney": {
		"replaces": "Larcei", "mother_id": "Ayra", "gender": "F",
		"klass": "SwordFighter", "tier": 1, "level": 5,
		"desc": "Hot-blooded swordswoman who hates men due to Isaachian cruelty.",
		"bases":   { "HP":24,"STR":7,"MAG":0,"SKL":11,"SPD":12,"LCK":4,"DEF":5,"RES":0,"CON":7 },
		"growths": { "HP":80,"STR":40,"MAG":0,"SKL":60,"SPD":70,"LCK":30,"DEF":15,"RES":10 },
		"holy_blood": {},
		"start_items": ["IronSword"],
		"skills": ["Pursuit"],
	},
	# === Lachesis ===
	"Tristan": {
		"replaces": "Diarmuid", "mother_id": "Lachesis", "gender": "M",
		"klass": "SwordFighter", "tier": 1, "level": 3,
		"desc": "Son of a fallen Cross Knight, separated from his sister Jeanne in childhood.",
		"bases":   { "HP":22,"STR":6,"MAG":0,"SKL":8,"SPD":9,"LCK":4,"DEF":5,"RES":0,"CON":7 },
		"growths": { "HP":70,"STR":40,"MAG":0,"SKL":40,"SPD":50,"LCK":30,"DEF":20,"RES":10 },
		"holy_blood": {},
		"start_items": ["IronSword"],
		"skills": [],
	},
	"Jeanne": {
		"replaces": "Nanna", "mother_id": "Lachesis", "gender": "F",
		"klass": "Priest", "tier": 1, "level": 1,
		"desc": "Adopted by a merchant after her Cross Knight father died; raised separately from Tristan.",
		"bases":   { "HP":18,"STR":1,"MAG":3,"SKL":3,"SPD":5,"LCK":4,"DEF":3,"RES":5,"CON":5 },
		"growths": { "HP":50,"STR":10,"MAG":40,"SKL":30,"SPD":40,"LCK":40,"DEF":10,"RES":40 },
		"holy_blood": {},
		"start_items": ["Heal"],
		"skills": [],
	},
	# === Sylvia ===
	"Charlot": {
		"replaces": "Coirpre", "mother_id": "Sylvia", "gender": "M",
		"klass": "Priest", "tier": 1, "level": 1,
		"desc": "Self-taught preacher with no formal lineage; staves are his calling.",
		"bases":   { "HP":17,"STR":1,"MAG":2,"SKL":2,"SPD":4,"LCK":2,"DEF":2,"RES":3,"CON":5 },
		"growths": { "HP":50,"STR":10,"MAG":30,"SKL":20,"SPD":30,"LCK":30,"DEF":10,"RES":30 },
		"holy_blood": {},
		"start_items": ["Heal"],
		"skills": [],
	},
	"Laylea": {
		"replaces": "Lene", "mother_id": "Sylvia", "gender": "F",
		"klass": "Dancer", "tier": 1, "level": 1,
		"desc": "Wandering dancer trained by the same troupe as Sylvia.",
		"bases":   { "HP":17,"STR":2,"MAG":1,"SKL":7,"SPD":13,"LCK":7,"DEF":3,"RES":3,"CON":4 },
		"growths": { "HP":50,"STR":10,"MAG":20,"SKL":50,"SPD":80,"LCK":60,"DEF":15,"RES":30 },
		"holy_blood": {},
		"start_items": [],
		"skills": ["Refresh"],
	},
	# === Erinys ===
	"Hawk": {
		"replaces": "Ced", "mother_id": "Erinys", "gender": "M",
		"klass": "Mage", "tier": 1, "level": 5,
		"desc": "Talented self-made mage with Chronic Hero Syndrome; admires Sigurd's army.",
		"bases":   { "HP":21,"STR":3,"MAG":9,"SKL":7,"SPD":8,"LCK":4,"DEF":3,"RES":7,"CON":6 },
		"growths": { "HP":60,"STR":15,"MAG":60,"SKL":40,"SPD":50,"LCK":30,"DEF":15,"RES":50 },
		"holy_blood": {},
		"start_items": ["Wind"],
		"skills": [],
	},
	"Femina": {
		"replaces": "Fee", "mother_id": "Erinys", "gender": "F",
		"klass": "PegasusKnight", "tier": 1, "level": 5,
		"desc": "Pegasus Knight fangirl of Sigurd and Erinys; achieved her dream by joining Seliph.",
		"bases":   { "HP":22,"STR":6,"MAG":2,"SKL":7,"SPD":11,"LCK":6,"DEF":5,"RES":6,"CON":6 },
		"growths": { "HP":70,"STR":35,"MAG":15,"SKL":40,"SPD":60,"LCK":40,"DEF":15,"RES":40 },
		"holy_blood": {},
		"start_items": ["IronLance"],
		"skills": [],
	},
	# === Brigid ===
	"Asaello": {
		"replaces": "Faval", "mother_id": "Brigid", "gender": "M",
		"klass": "BowFighter", "tier": 1, "level": 5,
		"desc": "Pirate-turned-archer from Orgahil who feels inadequate without Holy Blood.",
		"bases":   { "HP":24,"STR":8,"MAG":0,"SKL":8,"SPD":7,"LCK":2,"DEF":4,"RES":0,"CON":8 },
		"growths": { "HP":75,"STR":45,"MAG":0,"SKL":35,"SPD":40,"LCK":15,"DEF":20,"RES":10 },
		"holy_blood": {},
		"start_items": ["IronBow"],
		"skills": [],
	},
	"Daisy": {
		"replaces": "Patty", "mother_id": "Brigid", "gender": "F",
		"klass": "Thief", "tier": 1, "level": 3,
		"desc": "Cheerful young thief and Shannan superfan.",
		"bases":   { "HP":19,"STR":3,"MAG":0,"SKL":7,"SPD":12,"LCK":8,"DEF":3,"RES":0,"CON":5 },
		"growths": { "HP":60,"STR":20,"MAG":0,"SKL":40,"SPD":70,"LCK":50,"DEF":15,"RES":20 },
		"holy_blood": {},
		"start_items": ["IronSword"],
		"skills": ["Steal"],
	},
	# === Tailtiu ===
	"Amid": {
		"replaces": "Arthur", "mother_id": "Tailtiu", "gender": "M",
		"klass": "Mage", "tier": 1, "level": 3,
		"desc": "Wandering mage from Silesia bearing a grudge against the Frieges.",
		"bases":   { "HP":20,"STR":2,"MAG":8,"SKL":6,"SPD":9,"LCK":4,"DEF":2,"RES":6,"CON":5 },
		"growths": { "HP":55,"STR":10,"MAG":55,"SKL":35,"SPD":50,"LCK":30,"DEF":10,"RES":50 },
		"holy_blood": {},
		"start_items": ["Wind"],
		"skills": [],
	},
	"Linda": {
		"replaces": "Tinny", "mother_id": "Tailtiu", "gender": "F",
		"klass": "Mage", "tier": 1, "level": 5,
		"desc": "Mage with the Elite skill, capable of using Thoron unusually early.",
		"bases":   { "HP":20,"STR":2,"MAG":10,"SKL":7,"SPD":9,"LCK":3,"DEF":3,"RES":7,"CON":5 },
		"growths": { "HP":55,"STR":10,"MAG":60,"SKL":35,"SPD":40,"LCK":25,"DEF":10,"RES":50 },
		"holy_blood": {},
		"start_items": ["Thunder"],
		"skills": ["Elite_Skill"],
	},
}


# ── Tabla inversa: madre → sustitutos por género ─────────────────────────────

const MOTHER_TO_SUBSTITUTES: Dictionary = {
	"Aideen":   { "M": "Dimna",      "F": "Muirne" },
	"Ayra":     { "M": "Roddlevan",  "F": "Radney" },
	"Lachesis": { "M": "Tristan",    "F": "Jeanne" },
	"Sylvia":   { "M": "Charlot",    "F": "Laylea" },
	"Erinys":   { "M": "Hawk",       "F": "Femina" },
	"Brigid":   { "M": "Asaello",    "F": "Daisy" },
	"Tailtiu":  { "M": "Amid",       "F": "Linda" },
}


# ══════════════════════════════════════════════════════════════════════════════
# RESOLUCIÓN GEN 2
# ══════════════════════════════════════════════════════════════════════════════

## Estado de una madre al final de la gen 1.
##   alive       : bool
##   married_to  : String  (nid del padre, "" si no se casó)
##   father_data : Dictionary  (datos del padre, vacío si no hubo)
##
## Devuelve un Dictionary con:
##   { "male":   {nid, def_dict}|null,  ← el hijo masculino o sustituto
##     "female": {nid, def_dict}|null }
## El caller (GameManager) instancia las Unit a partir de def_dict.
static func resolve_gen2_units(mother_id: String, state: Dictionary) -> Dictionary:
	var alive: bool       = state.get("alive", true)
	var married_to: String = state.get("married_to", "")
	var father: Dictionary = state.get("father_data", {})
	var out := { "male": null, "female": null }

	# Si la madre está viva Y casada → hijos canónicos (no sustitutos).
	if alive and married_to != "":
		var canon_m: Dictionary = _build_canonical_child(mother_id, "M", father)
		var canon_f: Dictionary = _build_canonical_child(mother_id, "F", father)
		if not canon_m.is_empty():
			out["male"] = canon_m
		if not canon_f.is_empty():
			out["female"] = canon_f
		return out

	# Si murió o no se casó → sustitutos.
	if not MOTHER_TO_SUBSTITUTES.has(mother_id):
		return out  # madre sin sustitutos definidos (ej. madres de gen 2 ajenas)
	var subs: Dictionary = MOTHER_TO_SUBSTITUTES[mother_id]

	# Caso 1: la madre murió tras casarse → sustituto hereda parcialmente
	# del padre (50 %), porque "narrativamente" pudo dejar descendencia.
	# Si en Cap 5 sólo se mata a la madre tras tener hijos, esto modela
	# el caso de los hijos huérfanos sin madre que crió un substituto.
	# Esta es una libertad tomada respecto al canon (en FE4 morir = sustituto
	# puro), pero está dentro del espíritu pedido (calculados según madre/
	# padre/clase).
	var apply_paternal: bool = (not alive) and married_to != ""
	var paternal_factor: float = 0.5 if apply_paternal else 0.0

	for gender in ["M", "F"]:
		var sub_id: String = subs.get(gender, "")
		if sub_id == "" or not SUBSTITUTE_DEFS.has(sub_id):
			continue
		var def: Dictionary = _build_substitute_def(sub_id, father, paternal_factor)
		var key: String = "male" if gender == "M" else "female"
		out[key] = { "nid": sub_id, "data": def }
	return out


# ══════════════════════════════════════════════════════════════════════════════
# CONSTRUCCIÓN INTERNA
# ══════════════════════════════════════════════════════════════════════════════

## Construye los datos de un sustituto aplicando herencia paterna parcial.
##   sub_id          : nid del sustituto en SUBSTITUTE_DEFS
##   father          : Dictionary con los datos del padre (puede estar vacío)
##   paternal_factor : 0.0–1.0  fracción del bonus paterno que se hereda
static func _build_substitute_def(sub_id: String, father: Dictionary,
		paternal_factor: float) -> Dictionary:
	var base: Dictionary = SUBSTITUTE_DEFS[sub_id].duplicate(true)
	if paternal_factor <= 0.0 or father.is_empty():
		return base

	# Aplicar herencia paterna: en FE4 los hijos heredan growths como
	# (madre + padre) / 2.  Aquí, al ser sustituto, no hay "growths
	# maternales" útiles (la madre murió); aproximamos con
	# bases  += int(stat_padre * factor / 2)
	# growths += int(growth_padre * factor / 2)
	var f_bases: Dictionary = father.get("bases", {})
	var f_growths: Dictionary = father.get("growths", {})

	for stat in base["bases"].keys():
		if f_bases.has(stat):
			var bonus: int = int(f_bases[stat] * paternal_factor / 2.0)
			base["bases"][stat] = int(base["bases"][stat]) + bonus
	for stat in base["growths"].keys():
		if f_growths.has(stat):
			var bonus: int = int(f_growths[stat] * paternal_factor / 2.0)
			base["growths"][stat] = int(base["growths"][stat]) + bonus

	# Holy Blood paterno: si el padre tenía Major Blood, el sustituto
	# recibe Minor de esa misma sangre.  Esto no es canónico FE4, pero
	# refleja la "herencia parcial" pedida y abre el techo de A → S.
	if father.has("holy_blood"):
		for blood in father["holy_blood"].keys():
			var grade: String = str(father["holy_blood"][blood]).to_lower()
			if grade == "major":
				base["holy_blood"][blood] = "Minor"
	return base


# ── Tabla madre → hijos CANÓNICOS por género ─────────────────────────────────
const MOTHER_TO_CHILDREN: Dictionary = {
	"Aideen":   { "M": "Lester",  "F": "Lana" },
	"Ayra":     { "M": "Ulster",  "F": "Larcei" },
	"Lachesis": { "M": "Delmud",  "F": "Nanna" },
	"Sylvia":   { "M": "Coirpre", "F": "Lene" },
	"Erinys":   { "M": "Ced",     "F": "Fee" },
	"Brigid":   { "M": "Faval",   "F": "Patty" },
	"Tailtiu":  { "M": "Arthur",  "F": "Tine" },
}

## Tope de growth tras sumar padre+madre (evita crecimientos absurdos).
const GROWTH_CAP := 85

# ── Herencia gen 2: BASE + MODIFICADORES por padre ───────────────────────────
# Datos en data/general/gen2_children.json (generado por tools/build_gen2_children.py
# desde la cosecha de fireemblemwod).  Modelo:
#   final_base[s]   = clamp(base_stats[s]   + father_mods[father].base[s],   0, max_stats[s])
#   final_growth[s] =        base_growths[s] + father_mods[father].growth[s]
const GEN2_CHILDREN_PATH := "res://data/general/gen2_children.json"
static var _gen2_defs: Dictionary = {}
static var _gen2_loaded: bool = false

const GEN2_STATS := ["HP", "STR", "MAG", "SKL", "SPD", "LCK", "DEF", "RES"]

## Skills de la fuente FE4 → set actual (tras las consolidaciones de skills).
## "" = descartar (p.ej. Pursuit/Continue: el doblaje ahora es por Δ SPD).
const SKILL_ALIAS := {
	"Ambush": "Vantage", "Desperation": "Vantage",
	"Paragon": "Elite", "Elite": "Elite_Skill",
	"Shooting Star Sword": "Astra",
	"Moonlight Sword": "Luna",
	"Sun Sword": "Sol",
	"Pursuit": "", "Continue": "", "Adept": "",
}

static func _load_gen2_defs() -> Dictionary:
	if _gen2_loaded:
		return _gen2_defs
	_gen2_loaded = true
	if FileAccess.file_exists(GEN2_CHILDREN_PATH):
		var f := FileAccess.open(GEN2_CHILDREN_PATH, FileAccess.READ)
		if f != null:
			var parsed = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				_gen2_defs = parsed
	return _gen2_defs

## CON/MOV desde la clase (la fuente FE4 de gen 2 no los lista).  MOV en tiles
## (valor real, sin escalado).
static func _class_con_mov(klass: String) -> Vector2i:
	var loop := Engine.get_main_loop()
	if loop is SceneTree and loop.root != null:
		var db = loop.root.get_node_or_null("GameDB")
		if db != null and db.has_method("get_class_data"):
			var cd = db.get_class_data(klass)
			if cd != null:
				var b = cd.bases if "bases" in cd else {}
				if b is Dictionary:
					return Vector2i(int(b.get("CON", 0)), int(b.get("MOV", 0)))
	return Vector2i(0, 0)

## Conjunto de skill-nids válidos (para filtrar).  {} si GameDB no accesible
## → en ese caso no filtramos (dejamos pasar el alias).
static func _valid_skill_nids() -> Dictionary:
	var loop := Engine.get_main_loop()
	if loop is SceneTree and loop.root != null:
		var db = loop.root.get_node_or_null("GameDB")
		if db != null and "skills" in db and db.skills is Dictionary:
			return db.skills
	return {}

static func _map_skill(name: String, valid: Dictionary) -> String:
	var mapped := name
	if SKILL_ALIAS.has(name):
		mapped = SKILL_ALIAS[name]
	if mapped == "":
		return ""
	if valid.is_empty() or valid.has(mapped):
		return mapped
	return ""

## Construye los datos de un hijo CANÓNICO (madre viva y casada) con el modelo
## BASE + MODIFICADOR-POR-PADRE (data/general/gen2_children.json):
##   · bases   = base_stats + father_mods[padre].base   (tope max_stats de clase)
##   · growths = base_growths + father_mods[padre].growth
##   · CON/MOV = de la clase.  skills = personales + del padre (mapeadas al set
##     actual).  holy_blood = personal del hijo + Minor de la Major del padre.
## Si el padre no está en la tabla, se usa solo la base (modificador 0).
## Si el hijo no está en la tabla JSON, cae al método legacy (plantilla sub).
## Devuelve {} si no hay hijo mapeado (el caller lo ignora).
static func _build_canonical_child(mother_id: String, gender: String,
		father: Dictionary) -> Dictionary:
	if not MOTHER_TO_CHILDREN.has(mother_id):
		return {}
	var child_nid: String = MOTHER_TO_CHILDREN[mother_id].get(gender, "")
	if child_nid == "":
		return {}

	var defs := _load_gen2_defs()
	if not defs.has(child_nid):
		return _build_canonical_child_legacy(mother_id, gender, father)

	var d: Dictionary = defs[child_nid]
	var father_nid: String = str(father.get("nid", "")) if father is Dictionary else ""
	var mod: Dictionary = d.get("father_mods", {}).get(father_nid, {})
	var mb: Dictionary = mod.get("base", {})
	var mg: Dictionary = mod.get("growth", {})
	var maxs: Dictionary = d.get("max_stats", {})
	var base_s: Dictionary = d.get("base_stats", {})
	var base_g: Dictionary = d.get("base_growths", {})

	var bases := {}
	var growths := {}
	for s in GEN2_STATS:
		var bv: int = int(base_s.get(s, 0)) + int(mb.get(s, 0))
		if maxs.has(s):
			bv = mini(bv, int(maxs[s]))
		bases[s] = maxi(0, bv)
		growths[s] = maxi(0, int(base_g.get(s, 0)) + int(mg.get(s, 0)))
	# CON/MOV: horneados en el JSON desde la clase; fallback a GameDB si faltan.
	if d.has("con") and d.has("mov"):
		bases["CON"] = int(d["con"])
		bases["MOV"] = int(d["mov"])
	else:
		var cm := _class_con_mov(str(d.get("klass", "")))
		bases["CON"] = cm.x
		bases["MOV"] = cm.y

	# Skills: personales del hijo + las que aporta el padre, mapeadas.
	var valid := _valid_skill_nids()
	var skills := []
	for src in [d.get("personal_skills", []), mod.get("skills", [])]:
		if src is Array:
			for sk in src:
				var m := _map_skill(str(sk), valid)
				if m != "" and not (m in skills):
					skills.append(m)

	# Sangre: personal del hijo + Minor de la Major del padre.
	var blood := {}
	for c in d.get("holy_blood", {}):
		blood[str(c)] = str(d["holy_blood"][c])
	if father is Dictionary and father.get("holy_blood", {}) is Dictionary:
		for c in father["holy_blood"]:
			if str(father["holy_blood"][c]).to_lower() == "major" and not blood.has(c):
				blood[str(c)] = "Minor"

	var tmpl := {
		"klass": d.get("klass", "Mercenary"),
		"bases": bases,
		"growths": growths,
		"holy_blood": blood,
		"skills": skills,
		"start_items": d.get("starting_items", []),
	}
	return { "nid": child_nid, "data": tmpl }


## Método antiguo (fallback): reusa la plantilla del sustituto del mismo rol
## para clase/bases y computa growths = madre+padre.  Se usa solo si el hijo no
## está en gen2_children.json (p.ej. fallo de carga del JSON).
static func _build_canonical_child_legacy(mother_id: String, gender: String,
		father: Dictionary) -> Dictionary:
	if not MOTHER_TO_CHILDREN.has(mother_id):
		return {}
	var child_nid: String = MOTHER_TO_CHILDREN[mother_id].get(gender, "")
	if child_nid == "":
		return {}
	# Plantilla de rol (clase/bases) = el sustituto del mismo género.
	var sub_map: Dictionary = MOTHER_TO_SUBSTITUTES.get(mother_id, {})
	var sub_id: String = sub_map.get(gender, "")
	if not SUBSTITUTE_DEFS.has(sub_id):
		return {}
	var tmpl: Dictionary = SUBSTITUTE_DEFS[sub_id].duplicate(true)

	var mother: Dictionary = _lookup_unit(mother_id)
	var m_g: Dictionary = mother.get("growths", {})
	var f_g: Dictionary = father.get("growths", {})

	# Growths canónicos: madre + padre por stat (tope). Si ambos son 0 para un
	# stat, se conserva el de la plantilla como fallback.
	var g := {}
	for stat in tmpl.get("growths", {}).keys():
		var sum: int = int(m_g.get(stat, 0)) + int(f_g.get(stat, 0))
		g[stat] = min(GROWTH_CAP, sum) if sum > 0 else int(tmpl["growths"].get(stat, 0))
	tmpl["growths"] = g

	# Holy blood: unión de ambos padres.
	var blood := {}
	for src in [mother.get("holy_blood", {}), father.get("holy_blood", {})]:
		if not (src is Dictionary):
			continue
		for b in src:
			var grade: String = str(src[b])
			if blood.has(b) and blood[b] == "Minor" and grade == "Minor":
				blood[b] = "Major"          # dos Minor de la misma sangre → Major
			elif not blood.has(b) or grade == "Major":
				blood[b] = grade
	tmpl["holy_blood"] = blood

	# Skills: base del rol + personales de madre y padre.
	var skills: Array = tmpl.get("skills", []).duplicate() if tmpl.get("skills") is Array else []
	for src in [mother, father]:
		for ls in src.get("learned_skills", []):
			if ls is Array and ls.size() >= 2 and not (ls[1] in skills):
				skills.append(str(ls[1]))
	tmpl["skills"] = skills
	return { "nid": child_nid, "data": tmpl }

## Lee growths/holy_blood/learned_skills de una unidad de GameDB (accesible aun
## siendo SubstituteSystem estático, vía la raíz del SceneTree).
static func _lookup_unit(nid: String) -> Dictionary:
	var loop := Engine.get_main_loop()
	if loop is SceneTree and loop.root != null:
		var db = loop.root.get_node_or_null("GameDB")
		if db != null and db.has_method("get_unit"):
			var ud = db.get_unit(nid)
			if ud != null:
				return {
					"growths": ud.growths if "growths" in ud else {},
					"holy_blood": ud.holy_blood if "holy_blood" in ud else {},
					"learned_skills": ud.learned_skills if "learned_skills" in ud else [],
				}
	return {}


# ══════════════════════════════════════════════════════════════════════════════
# UTILIDADES
# ══════════════════════════════════════════════════════════════════════════════

## ¿Existe un sustituto con ese nid?
static func is_substitute(nid: String) -> bool:
	return SUBSTITUTE_DEFS.has(nid)


## Devuelve la lista de todos los sustitutos definidos.
static func get_all_substitute_ids() -> Array:
	return SUBSTITUTE_DEFS.keys()
