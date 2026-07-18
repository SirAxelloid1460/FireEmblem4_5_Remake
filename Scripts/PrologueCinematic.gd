class_name PrologueCinematic
extends CinematicScene

@export var next_scene_path: String = "res://Scenes/battle.tscn"

func build_cinematic_sequence() -> Array[Dictionary]:
	"""Cinemática del prólogo - Historia de fondo"""
	var sequence: Array[Dictionary] = []
	
	# === APERTURA DRAMÁTICA ===
	sequence.append({
		"type": "fade_in",
		"duration": 3.0
	})
	
	# === TÍTULO DEL JUEGO ===
	sequence.append({
		"type": "show_title",
		"text": "FIRE EMBLEM",
		"duration": 4.0
	})
	
	sequence.append({
		"type": "fade_out",
		"duration": 1.5
	})
	
	sequence.append({
		"type": "fade_in",
		"duration": 2.0
	})
	
	# === HISTORIA DE FONDO ===
	sequence.append({
		"type": "camera_move",
		"target": Vector2(640, 360),
		"duration": 1.0,
		"zoom": Vector2(1.0, 1.0)
	})
	
	sequence.append({
		"type": "dialogue_sequence",
		"dialogues": [
			{
				"character": "Narrador",
				"text": "Hace muchos años, el continente de Magvel vivió una era de paz...",
				"portrait": ""
			},
			{
				"character": "Narrador",
				"text": "Pero la oscuridad comenzó a extenderse desde las tierras del norte.",
				"portrait": ""
			},
			{
				"character": "Narrador",
				"text": "El Reino de Renais fue atacado sin previo aviso.",
				"portrait": ""
			},
			{
				"character": "Narrador",
				"text": "La Princesa Eirika debe huir para sobrevivir...",
				"portrait": ""
			}
		]
	})
	
	# === PANEO DRAMÁTICO ===
	sequence.append({
		"type": "camera_pan",
		"waypoints": [
			Vector2(400, 300),
			Vector2(600, 400),
			Vector2(800, 350),
			Vector2(1000, 400)
		],
		"duration": 8.0
	})
	
	# === MÁS NARRACIÓN ===
	sequence.append({
		"type": "dialogue_sequence",
		"dialogues": [
			{
				"character": "Eirika",
				"text": "Hermano... ¿dónde estás?",
				"portrait": "res://assets/GBA/portraits/eirika.png"
			},
			{
				"character": "Seth",
				"text": "Mi señora, debemos continuar. El enemigo no tardará en encontrarnos.",
				"portrait": "res://assets/GBA/portraits/seth.png"
			},
			{
				"character": "Eirika",
				"text": "Tienes razón, Seth. Debemos ser fuertes.",
				"portrait": "res://assets/GBA/portraits/eirika.png"
			}
		]
	})
	
	# === TRANSICIÓN ===
	sequence.append({
		"type": "show_title",
		"text": "PRÓLOGO: La Huida",
		"duration": 3.0
	})
	
	sequence.append({
		"type": "fade_out",
		"duration": 2.0
	})
	
	return sequence

func transition_to_next_scene():
	get_tree().change_scene_to_file(next_scene_path)
