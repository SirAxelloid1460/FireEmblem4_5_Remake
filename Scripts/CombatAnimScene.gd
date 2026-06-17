# CombatAnimScene.gd
# Escena visual de pelea de combate.  Orquesta los CombatAnimPlayers de
# ambos combatientes (atacante + defensor), reproduce los AttackResults
# devueltos por CombatSystem.calculate_combat() y aplica los efectos
# visuales (flashes, shakes, sounds).
#
# === RESPONSABILIDADES ===
#
#   - Cargar las animaciones del atacante y del defensor según sus units
#     y armas equipadas (vía CombatAnimResolver).
#   - Reproducir la secuencia de attacks del CombatResult, con los
#     poses correctos (Attack/Critical/Miss) y la pose Dodge en el otro
#     combatiente.
#   - Conectar las señales de los players (sound_requested, hit_frame,
#     screen_flash_requested, etc.) con la respuesta visual/sonora.
#   - Aplicar el daño en el momento exacto de hit_frame.
#   - Esperar la pose Stand entre attacks.
#   - Emitir combat_finished cuando termine toda la secuencia.
#
# === USO BÁSICO ===
#
#   var scene := preload("res://Scenes/CombatAnimScene.tscn").instantiate()
#   add_child(scene)
#   var combat_result := CombatSystem.calculate_combat(atk, def, distance, ...)
#   await scene.play_combat(combat_result)
#   scene.queue_free()
#
# === ARQUITECTURA DE LA ESCENA (TSCN sugerido) ===
#
#   CombatAnimScene (Node2D)
#   ├── Background       (TextureRect)        ← imagen de terreno
#   ├── Platforms (Node2D)
#   │   ├── AttackerPlatform (Sprite2D)
#   │   └── DefenderPlatform (Sprite2D)
#   ├── AttackerAnchor (Node2D)               ← posición del atacante
#   │   └── AttackerPlayer (CombatAnimPlayer) ← creado en runtime
#   ├── DefenderAnchor (Node2D, flipped)      ← posición del defensor
#   │   └── DefenderPlayer (CombatAnimPlayer)
#   ├── ScreenFlash (ColorRect, hidden)
#   └── HUD (CanvasLayer)
#       ├── AttackerHPBar
#       └── DefenderHPBar

class_name CombatAnimScene
extends Node2D


# ══════════════════════════════════════════════════════════════════════════════
# SEÑALES
# ══════════════════════════════════════════════════════════════════════════════

signal combat_finished(result)
signal hp_changed(unit, new_hp)


# ══════════════════════════════════════════════════════════════════════════════
# CONFIG
# ══════════════════════════════════════════════════════════════════════════════

## Posiciones canónicas del atacante y defensor en la pantalla (canon LT).
@export var attacker_position: Vector2 = Vector2(40, 80)
@export var defender_position: Vector2 = Vector2(200, 80)

## Si true, espeja al defensor para que mire al atacante.
@export var auto_flip_defender: bool = true

## Pausa entre attacks consecutivos (segundos).
@export var inter_attack_delay: float = 0.4

## Intensidad del screen shake (en píxeles).
@export var shake_intensity: float = 4.0
@export var shake_duration_seconds: float = 0.25


# ══════════════════════════════════════════════════════════════════════════════
# REFERENCIAS A NODOS HIJOS
# ══════════════════════════════════════════════════════════════════════════════

@export var attacker_anchor: Node2D
@export var defender_anchor: Node2D
@export var screen_flash: CanvasItem        # ColorRect que cubre la pantalla
@export var background: CanvasItem


# ══════════════════════════════════════════════════════════════════════════════
# ESTADO INTERNO
# ══════════════════════════════════════════════════════════════════════════════

var _attacker_player: CombatAnimPlayer = null
var _defender_player: CombatAnimPlayer = null

var _attacker: Unit = null
var _defender: Unit = null

# HP en vivo (decrementan según se aplican daños).
var _atk_hp: int = 0
var _def_hp: int = 0

# Flags durante un attack en curso.
var _waiting_for_hit: bool = false
var _pending_damage: int = 0
var _pending_target: Unit = null


# ══════════════════════════════════════════════════════════════════════════════
# CICLO DE VIDA
# ══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	if attacker_anchor == null:
		attacker_anchor = _ensure_anchor("AttackerAnchor", attacker_position)
	if defender_anchor == null:
		defender_anchor = _ensure_anchor("DefenderAnchor", defender_position)


# ══════════════════════════════════════════════════════════════════════════════
# API PRINCIPAL
# ══════════════════════════════════════════════════════════════════════════════

## Reproduce un combate completo desde un CombatResult.
## Devuelve el mismo CombatResult cuando la secuencia visual termina.
func play_combat(result) -> Variant:
	if result == null:
		emit_signal("combat_finished", null)
		return null

	_attacker = result.attacker
	_defender = result.defender
	_atk_hp = _read_hp(_attacker)
	_def_hp = _read_hp(_defender)

	# Setup de ambos players con la animación correcta.
	_attacker_player = _setup_player(attacker_anchor, _attacker,
			result.attacker_attacks.size() > 0,
			false)
	_defender_player = _setup_player(defender_anchor, _defender,
			result.defender_attacks.size() > 0,
			auto_flip_defender)

	# Pose inicial: Stand (idle).
	if _attacker_player != null:
		_attacker_player.play("Stand")
	if _defender_player != null:
		_defender_player.play("Stand")
	await _wait_seconds(0.3)

	# Reproducir cada attack en orden.  El orden canónico FE es:
	# atacante, defensor, segunda atacante (si dobla), segunda defensor.
	# CombatSystem ya devuelve los attacks en el orden correcto en sendos
	# arrays, pero los AttackResult NO incluyen orden cruzado — así que
	# los intercalamos manualmente.
	var sequence: Array = _build_attack_sequence(result)
	for attack_event in sequence:
		await _play_single_attack(attack_event["attacker_is_player"],
				attack_event["result"])
		# Comprobar muerte.
		if _attacker_died_check() or _defender_died_check():
			break
		if inter_attack_delay > 0.0:
			await _wait_seconds(inter_attack_delay)

	emit_signal("combat_finished", result)
	return result


# ══════════════════════════════════════════════════════════════════════════════
# CONSTRUCCIÓN DE LA SECUENCIA
# ══════════════════════════════════════════════════════════════════════════════

## Convierte attacker_attacks + defender_attacks en una secuencia
## intercalada del estilo:  atk, def, atk, def, ...  (con doblamiento).
func _build_attack_sequence(result) -> Array:
	var seq: Array = []
	var atk_arr: Array = result.attacker_attacks
	var def_arr: Array = result.defender_attacks
	# Patrón canónico FE: el atacante siempre golpea primero; si el
	# defensor puede contraatacar va segundo; los doblajes ocurren al
	# final pero pueden ser interrumpidos por la muerte del rival.
	# CombatSystem maneja la lógica de desperation/vantage al construir
	# los arrays, así que nosotros solo intercalamos.
	var i_atk := 0
	var i_def := 0
	# Primera ronda: atk -> def (si tiene)
	if i_atk < atk_arr.size():
		seq.append({"attacker_is_player": true, "result": atk_arr[i_atk]})
		i_atk += 1
	if i_def < def_arr.size():
		seq.append({"attacker_is_player": false, "result": def_arr[i_def]})
		i_def += 1
	# Doblajes: drenar lo que quede.
	while i_atk < atk_arr.size():
		seq.append({"attacker_is_player": true, "result": atk_arr[i_atk]})
		i_atk += 1
	while i_def < def_arr.size():
		seq.append({"attacker_is_player": false, "result": def_arr[i_def]})
		i_def += 1
	return seq


# ══════════════════════════════════════════════════════════════════════════════
# UN SOLO ATTACK
# ══════════════════════════════════════════════════════════════════════════════

func _play_single_attack(attacker_is_player: bool, ar) -> void:
	var attacker_player: CombatAnimPlayer = \
			_attacker_player if attacker_is_player else _defender_player
	var defender_player: CombatAnimPlayer = \
			_defender_player if attacker_is_player else _attacker_player
	var defender_unit: Unit = _defender if attacker_is_player else _attacker

	if attacker_player == null:
		return  # sin animación → asumimos hit instantáneo
	if ar == null:
		return

	# Decidir pose según resultado.
	var pose: String = "Attack"
	if not bool(ar.hit):
		pose = "Miss"
	elif bool(ar.critical):
		pose = "Critical"

	# Preparar pendientes para hit_frame.
	_pending_damage = int(ar.damage) if bool(ar.hit) else 0
	_pending_target = defender_unit
	_waiting_for_hit = true

	# Si pega y no es Miss, el defensor entra en Dodge animation.
	# (La pose Dodge se reproduce en paralelo con el ataque.)
	if defender_player != null and not bool(ar.hit):
		defender_player.play("Dodge")

	attacker_player.play(pose)

	# Esperar a pose_finished.
	await attacker_player.pose_finished

	# Tras el ataque, el defensor vuelve a Stand.
	if defender_player != null:
		defender_player.play("Stand")
	# El atacante también vuelve a Stand.
	attacker_player.play("Stand")


# ══════════════════════════════════════════════════════════════════════════════
# SETUP DE PLAYER PARA UNA UNIT
# ══════════════════════════════════════════════════════════════════════════════

func _setup_player(anchor: Node2D, unit: Unit, will_attack: bool,
		flipped: bool) -> CombatAnimPlayer:
	if anchor == null or unit == null:
		return null
	# Limpiar anchor si tenía algún player previo.
	for child in anchor.get_children():
		if child is CombatAnimPlayer:
			child.queue_free()

	var player := CombatAnimPlayer.new()
	player.name = "CombatAnimPlayer"
	player.flipped = flipped
	anchor.add_child(player)

	# Resolver y cargar la animación según unit + arma.
	var weapon = unit.weapon if "weapon" in unit else null
	var weapon_type: String = ""
	var ranged: bool = false
	if weapon != null:
		if "weapon_type" in weapon:
			weapon_type = str(weapon.weapon_type)
		# Determinar si la pelea está siendo a distancia.  Heurística:
		# si el arma tiene min_range > 1, es ranged.
		if "min_range" in weapon:
			ranged = int(weapon.min_range) > 1
		elif "max_range" in weapon and "min_range" not in weapon:
			# Solo max_range — asume melee si max_range == 1.
			ranged = int(weapon.max_range) > 1
	if weapon_type == "":
		weapon_type = "Unarmed"

	var anim_name := CombatAnimResolver.resolve(unit, weapon_type, ranged)
	var anim := CombatAnimDatabase.load_anim(anim_name)
	if not anim.get("ok", false):
		push_warning("CombatAnimScene: anim '%s' no se encontró" % anim_name)
		return player  # devolvemos el player aunque sin anim, para no romper

	player.set_anim(anim)

	# Conectar señales para procesar efectos.
	player.hit_frame.connect(_on_hit_frame)
	player.sound_requested.connect(_on_sound_requested)
	player.spell_requested.connect(_on_spell_requested)
	player.effect_requested.connect(_on_effect_requested)
	player.screen_flash_requested.connect(_on_screen_flash_requested)
	player.enemy_flash_requested.connect(
			func(ticks): _on_enemy_flash_requested(ticks, player))
	player.self_flash_requested.connect(
			func(ticks): _on_self_flash_requested(ticks, player))
	player.screen_shake_requested.connect(_on_screen_shake_requested)
	player.platform_shake_requested.connect(_on_platform_shake_requested)
	return player


# ══════════════════════════════════════════════════════════════════════════════
# RESPUESTAS A SEÑALES DE LOS PLAYERS
# ══════════════════════════════════════════════════════════════════════════════

func _on_hit_frame() -> void:
	# Aplica el daño pendiente al target — momento del impacto visual.
	if not _waiting_for_hit:
		return
	_waiting_for_hit = false
	if _pending_damage <= 0 or _pending_target == null:
		return
	var target: Unit = _pending_target
	if target == _attacker:
		_atk_hp = max(0, _atk_hp - _pending_damage)
		if "current_hp" in _attacker:
			_attacker.current_hp = _atk_hp
		emit_signal("hp_changed", _attacker, _atk_hp)
	elif target == _defender:
		_def_hp = max(0, _def_hp - _pending_damage)
		if "current_hp" in _defender:
			_defender.current_hp = _def_hp
		emit_signal("hp_changed", _defender, _def_hp)


func _on_sound_requested(sound_id: String) -> void:
	# Aquí enchufas tu SoundManager.  Por defecto solo log.
	# print("[Combat] sound: ", sound_id)
	pass


func _on_spell_requested(args: Array) -> void:
	# args[0] suele ser el spell name (Javelin, Arrow, ThrowingAxe).
	# Aquí instanciarías un proyectil que viaje al target.
	pass


func _on_effect_requested(effect_id: String) -> void:
	# DirtKick, ShieldToss, Cape Animation, etc.
	pass


func _on_screen_flash_requested(ticks: int, rgb: Array) -> void:
	if screen_flash == null:
		return
	var color := Color8(int(rgb[0]) if rgb.size() > 0 else 255,
			int(rgb[1]) if rgb.size() > 1 else 255,
			int(rgb[2]) if rgb.size() > 2 else 255)
	color.a = 0.7
	if screen_flash is ColorRect:
		(screen_flash as ColorRect).color = color
	screen_flash.visible = true
	# Fade out.
	var dur: float = float(ticks) / 60.0
	if dur < 0.05: dur = 0.05
	var tween := create_tween()
	tween.tween_property(screen_flash, "modulate:a", 0.0, dur)
	tween.tween_callback(func(): screen_flash.visible = false)


func _on_enemy_flash_requested(ticks: int, source_player: CombatAnimPlayer) -> void:
	# El "enemy" desde la perspectiva del player que disparó la señal:
	# si el atacante hace flash → flashear el defensor, y viceversa.
	var target_player: CombatAnimPlayer = \
			_defender_player if source_player == _attacker_player \
			else _attacker_player
	_flash_player(target_player, ticks, Color.WHITE)


func _on_self_flash_requested(ticks: int, source_player: CombatAnimPlayer) -> void:
	_flash_player(source_player, ticks, Color.WHITE)


func _on_screen_shake_requested() -> void:
	_shake_node(self, shake_intensity, shake_duration_seconds)


func _on_platform_shake_requested() -> void:
	# Si tienes platforms identificables, aquí los sacudirías.
	# Por ahora, mismo efecto que screen shake pero más leve.
	_shake_node(self, shake_intensity * 0.5, shake_duration_seconds * 0.5)


# ══════════════════════════════════════════════════════════════════════════════
# UTILIDADES
# ══════════════════════════════════════════════════════════════════════════════

func _ensure_anchor(node_name: String, pos: Vector2) -> Node2D:
	var existing := get_node_or_null(node_name)
	if existing is Node2D:
		return existing
	var anchor := Node2D.new()
	anchor.name = node_name
	anchor.position = pos
	add_child(anchor)
	return anchor


func _read_hp(unit: Unit) -> int:
	if unit == null:
		return 0
	if "current_hp" in unit:
		return int(unit.current_hp)
	if "hp" in unit:
		return int(unit.hp)
	return 1


func _attacker_died_check() -> bool:
	return _atk_hp <= 0


func _defender_died_check() -> bool:
	return _def_hp <= 0


func _flash_player(player: CombatAnimPlayer, ticks: int, color: Color) -> void:
	if player == null:
		return
	var dur: float = float(ticks) / 60.0
	if dur < 0.05: dur = 0.05
	var tween := create_tween()
	tween.tween_property(player, "modulate", color, dur * 0.3)
	tween.tween_property(player, "modulate", Color.WHITE, dur * 0.7)


func _shake_node(node: Node2D, intensity: float, duration: float) -> void:
	if node == null:
		return
	var original := node.position
	var tween := create_tween()
	var steps := 6
	for i in range(steps):
		var off := Vector2(
				randf_range(-intensity, intensity),
				randf_range(-intensity, intensity))
		tween.tween_property(node, "position", original + off, duration / steps)
	tween.tween_property(node, "position", original, duration / steps)


func _wait_seconds(secs: float) -> void:
	if secs <= 0.0:
		return
	await get_tree().create_timer(secs).timeout
