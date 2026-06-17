extends Resource
class_name ConsumableData

## Datos nativos de un ITEM no-arma (de data/general/items.json): pociones,
## anillos (status_on_hold), manuales de skill (status_on_hit), boosters
## (permanent_stat_change), llaves, ganzúas, scrolls, promotion items…
## Generado desde los componentes reales de los items LT sin weapon_type.
## Distinto de WeaponData (armas/báculos) y de la clase de runtime Item.gd.

@export var nid: String = ""
@export var name: String = ""
@export var desc: String = ""
@export var category: String = ""             # icon_nid LT (Consumable/Boosters/…)
@export var worth: int = -1                    # componente "value"; -1 = no vendible
@export var uses: int = -1                     # -1 = ilimitado / pasivo
@export var heal: int = 0
@export var permanent_stat_change: Dictionary = {}   # stat -> +amt
@export var status_on_hold: String = ""        # skill mientras se porta (anillos)
@export var status_on_hit: String = ""         # skill enseñada (manuales)
@export var promote: bool = false              # objeto de promoción (Knight Proof)
@export var restore: bool = false              # cura estados (Rest/Kia)
@export var restore_specific: String = ""      # estado concreto que cura (Kia→Petrify)
@export var components: Array = []             # componentes LT crudos (efectos)

static func from_dict(d: Dictionary) -> ConsumableData:
	var it := ConsumableData.new()
	it.nid = d.get("nid", "")
	it.name = d.get("name", "")
	it.desc = d.get("desc", "")
	it.category = d.get("category", "")
	it.worth = int(d.get("worth", -1))
	it.uses = int(d.get("uses", -1))
	it.heal = int(d.get("heal", 0))
	it.permanent_stat_change = d.get("permanent_stat_change", {})
	it.status_on_hold = d.get("status_on_hold", "")
	it.status_on_hit = d.get("status_on_hit", "")
	it.promote = bool(d.get("promote", false))
	it.restore = bool(d.get("restore", false))
	it.restore_specific = d.get("restore_specific", "")
	it.components = d.get("components", [])
	return it
