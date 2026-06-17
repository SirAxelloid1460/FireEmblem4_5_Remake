extends Resource
class_name LevelData

## Datos nativos de un CAPÍTULO (de data/<game>/levels/<nid>.json, convertidos
## de los levels.json de LT por tools/build_levels.py). Reemplaza el formato de
## nivel LT que parseaba LevelLoader. Las unidades referencian nids de GameDB.

@export var nid: String = ""
@export var name: String = ""
@export var game: String = ""             # "fe4" / "fe5"
@export var tilemap: String = ""          # nombre del tilemap del capítulo
@export var party: String = ""
@export var music: Dictionary = {}        # phase -> track
@export var objective: Dictionary = {}    # {simple, win, loss}
@export var units: Array = []             # placements: {nid, team, ai, ai_group, position, generic, traveler}
@export var regions: Array = []           # {nid, type, position, size, sub_nid, condition, only_once}
@export var unit_groups: Array = []       # grupos de refuerzos

static func from_dict(d: Dictionary) -> LevelData:
	var l := LevelData.new()
	l.nid = d.get("nid", "")
	l.name = d.get("name", "")
	l.game = d.get("game", "")
	l.tilemap = d.get("tilemap", "")
	l.party = d.get("party", "")
	l.music = d.get("music", {})
	l.objective = d.get("objective", {})
	l.units = d.get("units", [])
	l.regions = d.get("regions", [])
	l.unit_groups = d.get("unit_groups", [])
	return l
