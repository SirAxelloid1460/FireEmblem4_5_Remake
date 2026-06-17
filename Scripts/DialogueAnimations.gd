class_name DialogueAnimations
extends Node

static func create_bounce_animation(node: Control) -> Tween:
	"""Crea animación de rebote"""
	var tween = node.create_tween()
	tween.tween_property(node, "position:y", node.position.y - 10, 0.2)
	tween.tween_property(node, "position:y", node.position.y, 0.2)
	return tween

static func create_slide_in_animation(node: Control, from_left: bool = true) -> Tween:
	"""Crea animación de deslizamiento"""
	var start_x = -node.size.x if from_left else node.size.x + node.size.x
	var target_x = node.position.x
	
	node.position.x = start_x
	
	var tween = node.create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "position:x", target_x, 0.5)
	
	return tween

static func create_fade_in_animation(node: Control, duration: float = 0.5) -> Tween:
	"""Crea animación de fade in"""
	node.modulate.a = 0
	
	var tween = node.create_tween()
	tween.tween_property(node, "modulate:a", 1.0, duration)
	
	return tween
