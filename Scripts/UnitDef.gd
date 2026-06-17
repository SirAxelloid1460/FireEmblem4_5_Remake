extends Resource
class_name UnitDef

## Definición nativa de un PERSONAJE del roster (de data/general/units.json,
## unificado de GotHW+Thracia776). Distinto de la Unit de runtime (Unit.gd):
## UnitDef son los datos base; Unit es la instancia jugable.
## Reemplaza a LTData.UnitData.

@export var nid: String = ""
@export var name: String = ""
@export var desc: String = ""
@export var klass: String = ""
@export var level: int = 1
@export var gender: String = "M"
@export var bases: Dictionary = {}            # HP/STR/MAG/SKL/SPD/LCK/DEF/RES/CON/MOV
@export var growths: Dictionary = {}
@export var starting_items: Array = []        # nombres de item/arma
@export var learned_skills: Array = []         # [[level, skill_id], ...]
@export var wexp_gain: Dictionary = {}         # weapon_type -> wexp inicial
@export var holy_blood: Dictionary = {}        # crusader -> "Major"/"Minor"
@export var tags: Array = []
@export var affinity: String = ""
@export var portrait_nid: String = ""
@export var games: Array = []                  # ["FE4"], ["FE5"], o ambos

static func from_dict(d: Dictionary) -> UnitDef:
	var u := UnitDef.new()
	u.nid = d.get("nid", "")
	u.name = d.get("name", "")
	u.desc = d.get("desc", "")
	u.klass = d.get("klass", "")
	u.level = int(d.get("level", 1))
	u.gender = d.get("gender", "M")
	u.bases = d.get("bases", {})
	u.growths = d.get("growths", {})
	u.starting_items = d.get("starting_items", [])
	u.learned_skills = d.get("learned_skills", [])
	u.wexp_gain = d.get("wexp_gain", {})
	u.holy_blood = d.get("holy_blood", {})
	u.tags = d.get("tags", [])
	u.affinity = d.get("affinity", "")
	u.portrait_nid = d.get("portrait_nid", "")
	u.games = d.get("games", [])
	return u
