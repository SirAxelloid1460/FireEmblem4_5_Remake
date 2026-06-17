class_name EventCinematic
extends CinematicScene

@export var event_title: String = "Encuentro Inesperado"
@export var return_to_game: bool = true

func build_cinematic_sequence() -> Array[Dictionary]:
	"""Cinemática para eventos especiales durante el juego"""
	var sequence: Array[Dictionary] = []
	
	# === INICIO DRAMÁTICO ===
	sequence.append({
		"type": "flash",
		"color": Color.WHITE,
		"duration": 0.3
	})
	
	sequence.append({
		"type": "shake",
		"intensity": 25.0,
		"duration": 0.6
	})
	
	# === ZOOM DRAMÁTICO ===
	sequence.append({
		"type": "camera_move",
		"target": Vector2(640, 360),
		"duration": 1.5,
		"zoom": Vector2(2.0, 2.0)
	})
	
	# === TÍTULO DEL EVENTO ===
	sequence.append({
		"type": "show_title",
		"text": event_title,
		"duration": 2.5
	})
	
	# === DIÁLOGO DEL EVENTO ===
	sequence.append({
		"type": "dialogue_sequence",
		"dialogues": [
			{
				"character": "???",
				"text": "Por fin nos encontramos...",
				"portrait": ""
			},
			{
				"character": "Eirika",
				"text": "¿Quién eres tú?",
				"portrait": "res://assets/portraits/eirika.png"
			},
			{
				"character": "Misterioso Caballero",
				"text": "Mi nombre no importa. He venido a advertirte...",
				"portrait": "res://assets/portraits/mysterious.png"
			}
		]
	})
	
	# === ZOOM OUT ===
	sequence.append({
		"type": "camera_zoom",
		"zoom": Vector2(1.0, 1.0),
		"duration": 1.5
	})
	
	if not return_to_game:
		sequence.append({
			"type": "fade_out",
			"duration": 1.5
		})
	
	return sequence

func transition_to_next_scene():
	if return_to_game:
		# Volver al juego sin cambiar de escena
		queue_free()
	else:
		# Ir a otra escena
		get_tree().change_scene_to_file("res://Scenes/battle.tscn")
