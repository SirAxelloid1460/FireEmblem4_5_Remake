extends Resource
class_name UnitClassData

## Datos nativos de una CLASE (de data/general/classes.json), generados desde
## game_data/classes/*.json de LT (GotHW+Thracia776, unificados por nid).
## Stats por clave LT en MAYÚSCULAS: HP/STR/MAG/SKL/SPD/LCK/DEF/RES/CON/MOV.
## OJO: en estos proyectos MOV viene ×10 en los datos LT (p.ej. Paladin MOV=90,
## Armour=50) — se conserva verbatim; el runtime debe dividir si necesita casillas.
## Reemplaza a LTData.ClassData.

@export var id: String = ""               # nid LT
@export var name: String = ""
@export var desc: String = ""
@export var tier: int = 1
@export var movement_group: String = ""
@export var promotes_from: String = ""
@export var turns_into: Array = []
@export var tags: Array = []
@export var max_level: int = 19
@export var bases: Dictionary = {}        # HP..MOV -> int
@export var growths: Dictionary = {}      # HP..MOV -> %
@export var promotion: Dictionary = {}    # bonus al promover
@export var caps: Dictionary = {}         # = max_stats LT
@export var wexp_gain: Dictionary = {}    # weapon_type -> wexp inicial (sólo usables)
@export var learned_skills: Array = []    # [[level, skill_nid], ...]
@export var map_sprite_nid: String = ""
@export var combat_anim_nid: String = ""

static func from_dict(d: Dictionary) -> UnitClassData:
	var c := UnitClassData.new()
	c.id = d.get("id", "")
	c.name = d.get("name", "")
	c.desc = d.get("desc", "")
	c.tier = int(d.get("tier", 1))
	c.movement_group = d.get("movement_group", "")
	c.promotes_from = d.get("promotes_from", "")
	c.turns_into = d.get("turns_into", [])
	c.tags = d.get("tags", [])
	c.max_level = int(d.get("max_level", 19))
	c.bases = d.get("bases", {})
	c.growths = d.get("growths", {})
	c.promotion = d.get("promotion", {})
	c.caps = d.get("caps", {})
	c.wexp_gain = d.get("wexp_gain", {})
	c.learned_skills = d.get("learned_skills", [])
	c.map_sprite_nid = d.get("map_sprite_nid", "")
	c.combat_anim_nid = d.get("combat_anim_nid", "")
	return c
