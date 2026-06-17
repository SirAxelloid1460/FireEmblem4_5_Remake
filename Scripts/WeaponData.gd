extends Resource
class_name WeaponData

## Datos nativos de un ARMA o BÁCULO (de data/general/weapons.json), generados
## offline desde los componentes reales de los items LT (game_data/items/*.json
## de GotHW+Thracia776). Cualquier item con weapon_type entra aquí; el resto va
## a ConsumableData. Reemplaza la parte de armas de LTData.ItemData.

@export var nid: String = ""
@export var name: String = ""
@export var desc: String = ""
@export var weapon_type: String = ""      # Sword/Lance/Axe/Bow/Staff/Light/Anima/Dark
@export var might: int = 0                 # componente "damage"
@export var hit: int = 0
@export var weight: int = 0
@export var crit: int = 0
@export var rng_min: int = 1
@export var rng_max: int = 1
@export var rng_equation: String = ""      # p.ej. "MAGIC_RANGE" (max_equation_range)
@export var rank: String = ""              # weapon_rank D/C/B/A; "" = sin requisito (prf)
@export var uses: int = 0
@export var worth: int = -1                # componente "value"; -1 = no comprable
@export var magic: bool = false
@export var brave: bool = false
@export var reaver: bool = false
@export var is_staff: bool = false
@export var heal: int = 0                  # báculos de cura (heal / magic_heal)
@export var effective_tags: Array = []
@export var effective_multiplier: int = 1
@export var effective_bonus: int = 0       # componente "effective" (daño extra)
@export var prf_tags: Array = []           # XxxHeir → sólo Major Blood de ese cruzado
@export var prf_units: Array = []          # restringida a estos nids
@export var status_on_equip: String = ""   # skill mientras equipada (armas sagradas)
@export var status_on_hit: String = ""     # status infligido al golpear
@export var personal: bool = false         # derivado: tiene prf_tags o prf_units
@export var components: Array = []          # componentes LT crudos (báculos/efectos)

static func from_dict(d: Dictionary) -> WeaponData:
	var w := WeaponData.new()
	w.nid = d.get("nid", "")
	w.name = d.get("name", "")
	w.desc = d.get("desc", "")
	w.weapon_type = d.get("weapon_type", "")
	w.might = int(d.get("might", 0))
	w.hit = int(d.get("hit", 0))
	w.weight = int(d.get("weight", 0))
	w.crit = int(d.get("crit", 0))
	w.rng_min = int(d.get("rng_min", 1))
	w.rng_max = int(d.get("rng_max", 1))
	w.rng_equation = d.get("rng_equation", "")
	w.rank = d.get("rank", "")
	w.uses = int(d.get("uses", 0))
	w.worth = int(d.get("worth", -1))
	w.magic = bool(d.get("magic", false))
	w.brave = bool(d.get("brave", false))
	w.reaver = bool(d.get("reaver", false))
	w.is_staff = bool(d.get("is_staff", false))
	w.heal = int(d.get("heal", 0))
	w.effective_tags = d.get("effective_tags", [])
	w.effective_multiplier = int(d.get("effective_multiplier", 1))
	w.effective_bonus = int(d.get("effective_bonus", 0))
	w.prf_tags = d.get("prf_tags", [])
	w.prf_units = d.get("prf_units", [])
	w.status_on_equip = d.get("status_on_equip", "")
	w.status_on_hit = d.get("status_on_hit", "")
	w.personal = bool(d.get("personal", not (w.prf_tags.is_empty() and w.prf_units.is_empty())))
	w.components = d.get("components", [])
	return w
