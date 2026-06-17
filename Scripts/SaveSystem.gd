# SaveSystem.gd — extraído de MainMenu.gd
# (multi class_name no compila en Godot 4).
# ============================================
# SAVE SYSTEM (BÁSICO)
# ============================================
extends Node
class_name SaveSystem

const SAVE_FILE_PATH = "user://savegame.save"

static func has_save_file() -> bool:
	"""Verifica si existe un archivo de guardado"""
	return FileAccess.file_exists(SAVE_FILE_PATH)

static func save_game(game_data: Dictionary) -> bool:
	"""Guarda los datos del juego"""
	var save_file = FileAccess.open(SAVE_FILE_PATH, FileAccess.WRITE)
	if not save_file:
		return false

	var json_string = JSON.stringify(game_data)
	save_file.store_line(json_string)
	save_file.close()
	return true

static func load_game() -> bool:
	"""Carga los datos del juego guardado"""
	if not has_save_file():
		return false

	var save_file = FileAccess.open(SAVE_FILE_PATH, FileAccess.READ)
	if not save_file:
		return false

	var json_string = save_file.get_line()
	save_file.close()

	var json = JSON.new()
	var parse_result = json.parse(json_string)

	if parse_result != OK:
		return false

	var game_data = json.data
	# Aquí aplicarías los datos al juego
	# Por ahora solo retornamos true si se pudo leer

	return true

static func delete_save_file():
	"""Elimina el archivo de guardado"""
	if has_save_file():
		DirAccess.remove_absolute(SAVE_FILE_PATH)
