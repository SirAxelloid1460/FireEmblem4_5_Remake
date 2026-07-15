# Items.gd
# Base de datos de items personalizados del proyecto.
#
# IMPORTANTE — relación con Weapon.gd:
#   Las ARMAS están definidas en Weapon.gd (class_name Weapon).  Este
#   archivo NO define armas: solo consumibles, anillos, manuales y items
#   especiales que el motor LT no provee directamente.
#
#   La definición vieja de Weapon que estaba aquí se ha eliminado porque
#   colisionaba con el class_name del nuevo Weapon.gd.  Si tienes código
#   antiguo que usa weapon_name, current_durability, max_durability —
#   sigue funcionando porque Weapon.gd expone esos atributos como aliases.
#
# CONEXIÓN CON LevelLoader:
#   LevelLoader._instantiate_item busca primero la factory inyectada
#   (ItemDatabase.get_item) y si no encuentra el item, cae a Weapon.from_lt
#   con los datos del JSON canónico LT.  Para conectar tu base de datos
#   personal:
#
#     LevelLoader.set_item_factory(func(nid: String, lt_data: Dictionary):
#         return ItemDatabase.get_item(nid)  # null si no es custom
#     )
#
#   Hazlo en GameManager._ready() o donde inicialices project_data.

class_name ItemDatabase
extends RefCounted


# ══════════════════════════════════════════════════════════════════════════════
# REGISTRO ESTÁTICO
# ══════════════════════════════════════════════════════════════════════════════

# id → factory Callable que crea una instancia nueva del Item.
# Las factories son Callables porque cada uso del item produce una
# instancia independiente con sus propios usos.
static var _factories: Dictionary = {}


## Registra todos los items predefinidos.  Llamar una vez al arrancar el
## juego (en GameManager._ready o autoload).
static func register_defaults() -> void:
	if not _factories.is_empty():
		return  # ya registrados
	# Fuente única de datos: ItemCatalog (Items.gd). Cada ItemData se convierte
	# a una instancia Item con sus efectos en metadata. Así ItemDatabase es la
	# puerta de entrada (la usa LevelLoader.set_item_factory) sin duplicar datos.
	for d in ItemCatalog.get_all():
		var data = d
		register_factory(data.id, func(): return _item_from_data(data))


# ══════════════════════════════════════════════════════════════════════════════
# CONSTRUCTORES PARA CADA ITEM ESPECÍFICO
# ══════════════════════════════════════════════════════════════════════════════
#
# Cada función devuelve una instancia nueva del Item global (Item.gd) con
# sus propiedades configuradas.  La lógica específica (heal, status, etc.)
# se aplica al usarse mediante metadata en el item — el GameManager
# inspecciona estas metas al invocar use_on.

static func _item_from_data(d) -> Item:
	# Convierte un ItemCatalog.ItemData en un Item global con efectos en metadata.
	var it := Item.new(d.id, d.name, _category_to_type(d.category), d.uses, d.value, d.description)
	it.set_meta("category", d.category)
	it.set_meta("hold_type", d.hold_type)
	it.set_meta("usable_in_base", d.usable_in_base)
	it.set_meta("lose_on_miss", d.lose_on_miss)
	if not d.stat_bonus.is_empty():     it.set_meta("stat_bonus", d.stat_bonus)
	if not d.stat_permanent.is_empty(): it.set_meta("stat_permanent", d.stat_permanent)
	if d.skill_granted != "":           it.set_meta("skill_granted", d.skill_granted)
	if d.heal_percent > 0.0:            it.set_meta("heal_percent", d.heal_percent)
	if d.heal_flat > 0:                 it.set_meta("heal_flat", d.heal_flat)
	if d.status_applied != "":          it.set_meta("status_applied", d.status_applied)
	if d.status_on_hit != "":           it.set_meta("status_on_hit", d.status_on_hit)
	if d.event_on_use != "":            it.set_meta("event_on_use", d.event_on_use)
	return it


static func _category_to_type(category: String) -> String:
	match category:
		"ring":       return "Ring"
		"consumable": return "Consumable"
		"booster":    return "Booster"
		"manual":     return "Manual"
		"special":    return "Special"
		"key":        return "Key"
		_:            return "Consumable"


## Registra una factory custom.  Útil para añadir items desde mods o
## escenas de test.
static func register_factory(item_id: String, factory: Callable) -> void:
	_factories[item_id] = factory


## Construye una instancia nueva de un item por id.  Devuelve null si el
## item no existe en la base de datos.
static func get_item(item_id: String):
	if not _factories.has(item_id):
		return null
	var factory: Callable = _factories[item_id]
	if not factory.is_valid():
		return null
	return factory.call()


## ¿Existe un item con ese id?
static func has_item(item_id: String) -> bool:
	return _factories.has(item_id)


## Lista todos los ids registrados.
static func get_all_ids() -> Array:
	return _factories.keys()
