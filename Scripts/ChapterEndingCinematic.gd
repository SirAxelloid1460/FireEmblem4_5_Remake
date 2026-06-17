class_name ChapterEndingCinematic
extends CinematicScene

@export var chapter_number: int = 1
@export var victory: bool = true
@export var next_scene_path: String = "res://Scenes/world_map.tscn"

func build_cinematic_sequence() -> Array[Dictionary]:
	var sequence: Array[Dictionary] = []
	
	if victory:
		# === VICTORIA ===
		sequence.append({
			"type": "fade_in",
			"duration": 1.5
		})
		
		sequence.append({
			"type": "flash",
			"color": Color(1, 1, 0.8, 0.8),
			"duration": 0.5
		})
		
		sequence.append({
			"type": "show_title",
			"text": "¡VICTORIA!",
			"duration": 3.0
		})
		
		sequence.append({
			"type": "dialogue_sequence",
			"dialogues": [
				{
					"character": "Eirika",
					"text": "Lo hemos logrado. La fortaleza es nuestra.",
					"portrait": "res://assets/portraits/eirika.png"
				},
				{
					"character": "Seth",
					"text": "Una gran victoria, mi señora. Pero el camino aún es largo.",
					"portrait": "res://assets/portraits/seth.png"
				},
				{
					"character": "Eirika",
					"text": "Lo sé. Debemos continuar hacia el norte.",
					"portrait": "res://assets/portraits/eirika.png"
				}
			]
		})
	else:
		# === DERROTA ===
		sequence.append({
			"type": "fade_in",
			"duration": 2.0
		})
		
		sequence.append({
			"type": "shake",
			"intensity": 30.0,
			"duration": 1.0
		})
		
		sequence.append({
			"type": "show_title",
			"text": "Derrota...",
			"duration": 3.0
		})
	
	# === ESTADÍSTICAS (opcional) ===
	sequence.append({
		"type": "show_title",
		"text": "Capítulo %d Completado" % chapter_number,
		"duration": 2.5
	})
	
	sequence.append({
		"type": "fade_out",
		"duration": 2.0
	})
	
	return sequence

func transition_to_next_scene():
	get_tree().change_scene_to_file(next_scene_path)
