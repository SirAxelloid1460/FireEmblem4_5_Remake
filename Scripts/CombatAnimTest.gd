# CombatAnimTest.gd
# Test visual mínimo para verificar que las combat anims se cargan y
# reproducen correctamente.  Usa la nueva API (CombatAnimDatabase /
# CombatAnimResolver / CombatAnimPlayer).
#
# === USO ===
#
# 1. Scene → New Scene → 2D Scene
# 2. Renombra el root a "CombatAnimTest" (Node2D)
# 3. Adjunta este script al root
# 4. Guarda como res://CombatAnimTest.tscn
# 5. F6 — debería mostrar la animación reproduciéndose en loop
#
# === CONTROLES ===
#   SPACE        → reinicia la pose
#   1 / 2 / 3 / 4 / 5  →  Attack / Critical / Dodge / Stand / Miss
#   F            → flip horizontal

extends Node2D


# ══════════════════════════════════════════════════════════════════════════════
# CONFIGURACIÓN — ajustable desde el inspector.
# ══════════════════════════════════════════════════════════════════════════════

## Nombre canónico de la animación a cargar (sin extensión).
##   Cavalier_Alec_Sword
##   Cavalier_Male_Lance
##   Sage_Generic_MagicAnima
@export var anim_name: String = "Cavalier_Alec_Sword"

## Pose inicial al arrancar.
@export_enum("Attack", "Critical", "Dodge", "Stand", "Miss") \
		var initial_pose: String = "Attack"

## Zoom visual.
@export var zoom: float = 2.0


# ══════════════════════════════════════════════════════════════════════════════
# REFERENCIAS
# ══════════════════════════════════════════════════════════════════════════════

var _player: CombatAnimPlayer = null
var _info_label: Label = null


func _ready() -> void:
	# Anchor con zoom.
	var anchor := Node2D.new()
	anchor.name = "AnchorPlayer"
	anchor.position = Vector2(80, 100)
	anchor.scale = Vector2(zoom, zoom)
	add_child(anchor)

	# Crear el player.
	_player = CombatAnimPlayer.new()
	_player.name = "CombatAnimPlayer"
	anchor.add_child(_player)

	# Info label.
	_info_label = Label.new()
	_info_label.position = Vector2(10, 10)
	_info_label.add_theme_color_override("font_color", Color.WHITE)
	_info_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_info_label.add_theme_constant_override("outline_size", 4)
	add_child(_info_label)

	# Cargar y arrancar.
	var anim := CombatAnimDatabase.load_anim(anim_name)
	if not anim.get("ok", false):
		var _folder := anim_name.substr(0, anim_name.rfind("_")) if anim_name.rfind("_") > 0 else anim_name
		_info_label.text = "ERROR: anim '%s' no encontrada\n" % anim_name + \
				"Esperaba res://assets/GBA/combat_anims/%s/%s.png + .json" % [_folder, anim_name]
		_info_label.add_theme_color_override("font_color", Color.RED)
		push_error("[CombatAnimTest] anim '%s' no encontrada" % anim_name)
		return

	_player.set_anim(anim)
	_player.play(initial_pose)

	# Auto-loop: al terminar la pose, la reinicia.
	_player.pose_finished.connect(_on_pose_finished)

	# Conectar señales informativas (opcional — solo para debug).
	_player.sound_requested.connect(
			func(sid): print("[anim] sound: ", sid))
	_player.spell_requested.connect(
			func(args): print("[anim] spell: ", args))
	_player.hit_frame.connect(
			func(): print("[anim] HIT FRAME"))

	_update_info_label()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_SPACE:
				_player.play(_player.current_pose())
			KEY_1: _try_play("Attack")
			KEY_2: _try_play("Critical")
			KEY_3: _try_play("Dodge")
			KEY_4: _try_play("Stand")
			KEY_5: _try_play("Miss")
			KEY_F:
				_player.set_flipped(not _player.flipped)
				_update_info_label()
		_update_info_label()


func _on_pose_finished(pose_name: String) -> void:
	# Reinicia la pose para verla en loop (excepto Stand, que es estática).
	if pose_name != "Stand":
		_player.play(pose_name)


func _try_play(pose: String) -> void:
	var poses := CombatAnimDatabase.list_poses(
			CombatAnimDatabase.load_anim(anim_name))
	if pose in poses:
		_player.play(pose)
	else:
		print("[CombatAnimTest] pose '%s' no existe — disponibles: %s" %
				[pose, poses])


func _update_info_label() -> void:
	if _info_label == null or _player == null:
		return
	var poses := CombatAnimDatabase.list_poses(
			CombatAnimDatabase.load_anim(anim_name))
	_info_label.text = (
		"anim: %s\n" +
		"pose: %s   flipped: %s\n" +
		"poses disponibles: %s\n" +
		"[1-5] cambiar pose  [F] flip  [SPACE] reiniciar"
	) % [anim_name, _player.current_pose(),
		"yes" if _player.flipped else "no",
		", ".join(poses)]
