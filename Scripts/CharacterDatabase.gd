class_name CharacterDatabase
extends Node

# Base de datos simple de personajes
static var player_characters = [
	"Eirika", "Ephraim", "Seth", "Franz", "Gilliam", "Vanessa",
	"Moulder", "Garcia", "Ross", "Neimi", "Colm", "Artur"
]

static var enemy_characters = [
	"Valter", "Selena", "Glen", "Riev", "Lyon",
	"Soldado", "Caballero", "Arquero", "Mago"
]

static func is_player_character(name: String) -> bool:
	return name in player_characters

static func is_enemy_character(name: String) -> bool:
	return name in enemy_characters
