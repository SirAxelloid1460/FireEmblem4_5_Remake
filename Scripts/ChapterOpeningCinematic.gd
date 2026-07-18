extends CinematicScene
class_name ChapterOpeningCinematic

# Esta es una cinemática de ejemplo para la apertura de un capítulo
# Hereda de CinematicScene y sobrescribe build_cinematic_sequence()

@export var chapter_number: int = 1
@export var chapter_title: String = "El Inicio"
@export var next_scene_path: String = "res://Scenes/battle.tscn"

func build_cinematic_sequence() -> Array[Dictionary]:
	"""Construye la secuencia específica para este capítulo"""
	var sequence: Array[Dictionary] = []
	
	# === APERTURA ===
	sequence.append({
		"type": "fade_in",
		"duration": 2.0
	})
	
	# === VISTA DEL MAPA ===
	# Empieza mostrando una vista general del mapa
	sequence.append({
		"type": "camera_move",
		"target": Vector2(500, 400),
		"duration": 0.5,
		"zoom": Vector2(0.5, 0.5)
	})
	
	# === TÍTULO DEL CAPÍTULO ===
	sequence.append({
		"type": "show_title",
		"text": "Capítulo %d" % chapter_number,
		"duration": 2.5
	})
	
	sequence.append({
		"type": "wait",
		"duration": 0.5
	})
	
	sequence.append({
		"type": "show_title",
		"text": chapter_title,
		"duration": 3.0
	})
	
	# === PANEO POR EL MAPA ===
	# Hace un recorrido visual por el escenario de batalla
	sequence.append({
		"type": "camera_pan",
		"waypoints": [
			Vector2(400, 300),   # Castillo del jugador
			Vector2(600, 350),   # Camino
			Vector2(800, 400),   # Bosque
			Vector2(1000, 350)   # Fortaleza enemiga
		],
		"duration": 6.0
	})
	
	# === ZOOM A UBICACIÓN ESPECÍFICA ===
	# Hace zoom en la fortaleza enemiga
	sequence.append({
		"type": "camera_move",
		"target": Vector2(1000, 350),
		"duration": 2.0,
		"zoom": Vector2(1.5, 1.5)
	})
	
	# === DIÁLOGOS INTRODUCTORIOS ===
	sequence.append({
		"type": "dialogue_sequence",
		"dialogues": [
			{
				"character": "Narrador",
				"text": "Las fuerzas enemigas han tomado la fortaleza.",
				"portrait": ""
			},
			{
				"character": "Narrador",
				"text": "Nuestros héroes deben reconquistarla antes del anochecer.",
				"portrait": ""
			},
			{
				"character": "Eirika",
				"text": "¡Adelante! ¡No permitiremos que mantengan esta posición!",
				"portrait": "res://assets/GBA/portraits/eirika.png"
			},
			{
				"character": "Seth",
				"text": "Estaremos a su lado, mi señora. ¡A la batalla!",
				"portrait": "res://assets/GBA/portraits/seth.png"
			}
		]
	})
	
	# === TRANSICIÓN A LA BATALLA ===
	sequence.append({
		"type": "fade_out",
		"duration": 1.5
	})
	
	return sequence

func transition_to_next_scene():
	"""Transiciona a la escena de batalla"""
	get_tree().change_scene_to_file(next_scene_path)
