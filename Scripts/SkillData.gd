extends Resource
class_name SkillData

## Datos nativos de una SKILL/STATUS (de data/general/skills.json), generados
## desde game_data/skills/*.json de LT. `components` conserva la lista cruda de
## componentes LT ([nombre, valor]) para fidelidad; los accesores ayudan a
## consultarlos sin reparsear. Reemplaza a LTData.StatusData.

@export var nid: String = ""
@export var name: String = ""
@export var desc: String = ""
@export var icon_nid: String = ""
@export var components: Array = []   # [[name, value], ...] tal cual en LT

static func from_dict(d: Dictionary) -> SkillData:
	var s := SkillData.new()
	s.nid = d.get("nid", "")
	s.name = d.get("name", "")
	s.desc = d.get("desc", "")
	s.icon_nid = d.get("icon_nid", "")
	s.components = d.get("components", [])
	return s

## ¿Tiene el componente con este nombre?
func has_component(comp_name: String) -> bool:
	for c in components:
		if c is Array and c.size() > 0 and str(c[0]) == comp_name:
			return true
	return false

## Valor del componente (null si no está).
func component_value(comp_name: String):
	for c in components:
		if c is Array and c.size() > 1 and str(c[0]) == comp_name:
			return c[1]
	return null

func is_hidden() -> bool:
	return has_component("hidden")
