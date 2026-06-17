# CombatAnimPlayer.gd
# Reproductor de animaciones de combate.  Funciona como un AnimatedSprite
# pero ejecuta el "script" (lista de comandos) generado por
# build_combat_sheet.py — frames, sonidos, flashes, screen shakes, etc.
#
# === USO ===
#
#   var player := CombatAnimPlayer.new()
#   add_child(player)
#   var anim := CombatAnimDatabase.load_anim("Cavalier_Alec_Sword")
#   player.set_anim(anim)
#   player.play("Attack")
#   await player.pose_finished
#
# === SEÑALES ===
#
#   pose_started(pose_name)            ← al empezar una pose
#   pose_finished(pose_name)           ← al terminar (no loop)
#   hit_frame                          ← cuando aparece comando "wait_for_hit"
#                                         o el último frame antes de un hit
#                                         (señal para que el target reciba daño)
#   sound_requested(sound_id)          ← C19, C1B, etc — el caller reproduce
#   spell_requested(spell_args)        ← C05 — invoca proyectil/efecto
#   screen_flash_requested(ticks, rgb) ← efecto de flash de pantalla
#   screen_shake_requested             ← C14
#   platform_shake_requested           ← C15
#
# === TICKS ===
#
# El LT canónico usa 60 ticks/segundo.  Todos los "ticks" en los comandos
# se interpretan a esta tasa.  Configurable con tick_rate.

class_name CombatAnimPlayer
extends Node2D


# ══════════════════════════════════════════════════════════════════════════════
# SEÑALES
# ══════════════════════════════════════════════════════════════════════════════

signal pose_started(pose_name: String)
signal pose_finished(pose_name: String)
signal hit_frame
signal sound_requested(sound_id: String)
signal spell_requested(args: Array)
signal effect_requested(effect_id: String)
signal screen_flash_requested(ticks: int, rgb: Array)
signal enemy_flash_requested(ticks: int)
signal self_flash_requested(ticks: int)
signal screen_shake_requested
signal platform_shake_requested


# ══════════════════════════════════════════════════════════════════════════════
# CONFIG
# ══════════════════════════════════════════════════════════════════════════════

## Ticks por segundo del motor de animación (canon LT = 60).
@export var tick_rate: int = 60

## Si true, espeja la animación horizontalmente (para enemigos vistos
## desde la derecha apuntando a la izquierda).
@export var flipped: bool = false


# ══════════════════════════════════════════════════════════════════════════════
# ESTADO
# ══════════════════════════════════════════════════════════════════════════════

var _anim: Dictionary = {}                # devuelto por CombatAnimDatabase
var _current_pose: String = ""            # ej. "Attack"
var _commands: Array = []                 # cmds de la pose actual
var _cmd_index: int = 0                   # comando actual
var _ticks_remaining: float = 0.0         # ticks pendientes del frame actual
var _is_playing: bool = false

# Loop control (start_loop / end_loop).  El loop interno itera un número fijo
# de veces (4 en el LT por defecto, derivado del flujo del parser).
const LOOP_ITERATIONS: int = 4
var _loop_stack: Array = []   # [(start_index, iterations_left)]

# Frame actualmente mostrado.
var _sprite_top: Sprite2D = null
var _sprite_bottom: Sprite2D = null  # para dual_frame ("_under")


# ══════════════════════════════════════════════════════════════════════════════
# CICLO DE VIDA
# ══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	# Crear los sprites internos (top + bottom para dual_frame).
	_sprite_bottom = Sprite2D.new()
	_sprite_bottom.name = "FrameBottom"
	_sprite_bottom.centered = false
	_sprite_bottom.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite_bottom)

	_sprite_top = Sprite2D.new()
	_sprite_top.name = "FrameTop"
	_sprite_top.centered = false
	_sprite_top.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite_top)

	_apply_flip()


func _process(delta: float) -> void:
	if not _is_playing:
		return
	# Avance de ticks: tick_rate ticks por segundo.
	_ticks_remaining -= delta * float(tick_rate)
	while _ticks_remaining <= 0.0 and _is_playing:
		_advance_command()


# ══════════════════════════════════════════════════════════════════════════════
# API PÚBLICA
# ══════════════════════════════════════════════════════════════════════════════

## Asigna la animación cargada (por CombatAnimDatabase.load_anim).
func set_anim(anim: Dictionary) -> void:
	_anim = anim
	_clear_sprites()


## Reproduce una pose (Attack/Critical/Dodge/Stand/Miss).
## Si no existe la pose, no hace nada.
func play(pose_name: String) -> void:
	if not _anim.get("ok", false):
		push_warning("CombatAnimPlayer: anim no cargada")
		return
	var poses: Dictionary = _anim["data"].get("poses", {})
	if not poses.has(pose_name):
		push_warning("CombatAnimPlayer: pose '%s' no existe" % pose_name)
		return
	_current_pose = pose_name
	_commands = poses[pose_name]
	_cmd_index = 0
	_ticks_remaining = 0.0
	_loop_stack.clear()
	_is_playing = true
	emit_signal("pose_started", pose_name)
	# Procesar los primeros comandos hasta llegar al primer frame con ticks > 0.
	_advance_command()


## Pausa la reproducción.
func pause() -> void:
	_is_playing = false


## Reanuda.
func resume() -> void:
	if _commands.size() > 0 and _cmd_index < _commands.size():
		_is_playing = true


## Detiene y vuelve al frame "Stand" si existe.
func stop() -> void:
	_is_playing = false
	_current_pose = ""
	_commands = []
	_cmd_index = 0


## Pose actualmente en reproducción ("" si no hay).
func current_pose() -> String:
	return _current_pose


## Cambia el flipping en runtime.
func set_flipped(value: bool) -> void:
	flipped = value
	_apply_flip()


# ══════════════════════════════════════════════════════════════════════════════
# EJECUCIÓN DE COMANDOS
# ══════════════════════════════════════════════════════════════════════════════

func _advance_command() -> void:
	while _cmd_index < _commands.size():
		var cmd: Dictionary = _commands[_cmd_index]
		_cmd_index += 1
		var cmd_name: String = str(cmd.get("cmd", ""))

		match cmd_name:
			"frame":
				_show_frame_single(str(cmd.get("frame", "")))
				_ticks_remaining = float(int(cmd.get("ticks", 1)))
				return  # esperar a que pasen los ticks
			"dual_frame":
				_show_frame_dual(str(cmd.get("frame_top", "")),
								  str(cmd.get("frame_bottom", "")))
				_ticks_remaining = float(int(cmd.get("ticks", 1)))
				return
			"over_frame":
				_show_frame_over(str(cmd.get("frame", "")))
				_ticks_remaining = float(int(cmd.get("ticks", 1)))
				return
			"under_frame":
				_show_frame_single(str(cmd.get("frame", "")))
				_ticks_remaining = float(int(cmd.get("ticks", 1)))
				return
			"wait":
				_ticks_remaining = float(int(cmd.get("ticks", 1)))
				return

			"sound":
				emit_signal("sound_requested", str(cmd.get("id", "")))
			"spell":
				emit_signal("spell_requested", cmd.get("args", []))
			"effect":
				var args: Array = cmd.get("args", [])
				if args.size() > 0:
					emit_signal("effect_requested", str(args[0]))

			"enemy_flash_white":
				emit_signal("enemy_flash_requested", int(cmd.get("ticks", 4)))
			"self_flash_white":
				emit_signal("self_flash_requested", int(cmd.get("ticks", 4)))
			"screen_flash_white":
				emit_signal("screen_flash_requested",
						int(cmd.get("ticks", 4)), [255, 255, 255])
			"foreground_blend", "screen_blend", "enemy_tint":
				emit_signal("screen_flash_requested",
						int(cmd.get("ticks", 4)),
						cmd.get("rgb", [255, 255, 255]))

			"screen_shake":
				emit_signal("screen_shake_requested")
			"platform_shake":
				emit_signal("platform_shake_requested")

			"wait_for_hit":
				# El caller resolverá el daño y luego llamará resume().
				# Mostramos el último frame y disparamos hit_frame.
				var frames: Array = cmd.get("frames", [])
				if frames.size() == 1:
					_show_frame_single(str(frames[0]))
				elif frames.size() >= 2:
					_show_frame_dual(str(frames[0]), str(frames[1]))
				emit_signal("hit_frame")
				_ticks_remaining = 1.0  # 1 tick mínimo de espera
				return

			"start_loop":
				_loop_stack.push_back([_cmd_index, LOOP_ITERATIONS - 1])
			"end_loop":
				if _loop_stack.size() > 0:
					var top: Array = _loop_stack[_loop_stack.size() - 1]
					if int(top[1]) > 0:
						top[1] = int(top[1]) - 1
						_cmd_index = int(top[0])
					else:
						_loop_stack.pop_back()
			"end_child_loop":
				# Derivado del LT — no afecta a este player a menos que
				# tengamos un loop separado para children, que no es el
				# caso actualmente.
				pass

			"miss", "hit_spark", "miss_spark", "crit_spark", "start_hit", \
			"darken", "lighten", "stop_sound", "blend", "raw":
				# Comandos sin efecto inmediato (o ya cubiertos arriba).
				pass

			_:
				# Comando desconocido — ignorar silenciosamente.
				pass

	# Llegamos al final de la pose.
	_is_playing = false
	emit_signal("pose_finished", _current_pose)


# ══════════════════════════════════════════════════════════════════════════════
# RENDERIZADO DE FRAMES
# ══════════════════════════════════════════════════════════════════════════════

func _show_frame_single(frame_name: String) -> void:
	var atlas := CombatAnimDatabase.get_frame_atlas(_anim, frame_name)
	if atlas == null:
		return
	_sprite_top.texture = atlas
	_sprite_top.visible = true
	_sprite_bottom.visible = false


func _show_frame_dual(top_name: String, bottom_name: String) -> void:
	var atlas_top := CombatAnimDatabase.get_frame_atlas(_anim, top_name)
	var atlas_bot := CombatAnimDatabase.get_frame_atlas(_anim, bottom_name)
	if atlas_top != null:
		_sprite_top.texture = atlas_top
		_sprite_top.visible = true
	if atlas_bot != null:
		_sprite_bottom.texture = atlas_bot
		_sprite_bottom.visible = true
	# El bottom se posiciona JUSTO debajo del top (frame_size.y de offset).
	var fsize: Array = _anim["data"].get("frame_size", [240, 160])
	_sprite_bottom.position = Vector2(0, int(fsize[1]))


func _show_frame_over(frame_name: String) -> void:
	# over_frame se renderiza encima del fondo del platform (en la práctica
	# es como single, pero el caller puede tratarlo distinto si quiere).
	_show_frame_single(frame_name)


func _clear_sprites() -> void:
	if _sprite_top:
		_sprite_top.texture = null
		_sprite_top.visible = false
	if _sprite_bottom:
		_sprite_bottom.texture = null
		_sprite_bottom.visible = false


func _apply_flip() -> void:
	# El flipping se hace mediante scale.x = -1 en el contenedor.
	# Necesita posicionarse después en el caller para compensar.
	scale.x = -1.0 if flipped else 1.0
