# Sistema de Cinemáticas del Mapa Mundial - Fire Emblem Remake

Sistema completo de mapa del mundo con cinemáticas, diálogos y transiciones estilo Fire Emblem GBA/SNES.

## 📁 Archivos Incluidos

```
WorldMap.gd                    - Sistema del mapa del mundo con cinemáticas
DialogueBox.gd                 - Sistema de diálogos con retratos
CinematicTransitions.gd        - Transiciones cinemáticas avanzadas
world_map.tscn                 - Escena del mapa del mundo
```

## 🎮 Características del Sistema

### Mapa del Mundo
- ✅ Sistema de ubicaciones/capítulos con progresión
- ✅ Marcadores visuales (bloqueado/desbloqueado/completado)
- ✅ Cinemáticas de viaje entre ubicaciones
- ✅ Animaciones de cámara (zoom, pan, seguimiento)
- ✅ Líneas de ruta dinámicas
- ✅ Sistema de desbloqueo progresivo

### Sistema de Diálogos
- ✅ Caja de diálogo estilo Fire Emblem
- ✅ Retratos de personajes (izquierda/derecha)
- ✅ Efecto de escritura gradual
- ✅ Indicador de "continuar" animado
- ✅ Secuencias de múltiples diálogos
- ✅ Efectos especiales (shake, flash, zoom en retratos)
- ✅ Soporte para BBCode en texto

### Transiciones Cinemáticas
- ✅ Fade in/out
- ✅ Wipe (barrido) en 4 direcciones
- ✅ Circle transition (iris in/out)
- ✅ Transición de batalla con efectos
- ✅ Flash de pantalla
- ✅ Shake de pantalla
- ✅ Transiciones combinadas dramáticas

## 🚀 Configuración en Godot 4

### Paso 1: Estructura de Directorios

```
res://
├── scenes/
│   ├── world_map.tscn
│   ├── main_menu.tscn
│   └── battle.tscn
├── scripts/
│   ├── WorldMap.gd
│   ├── DialogueBox.gd
│   └── CinematicTransitions.gd
└── assets/
    ├── portraits/           (Retratos de personajes)
    │   ├── eirika.png
    │   ├── seth.png
    │   └── ...
    ├── maps/
    │   └── world_map.png    (Imagen del mapa del mundo)
    └── audio/
        ├── dialogue_beep.wav
        └── world_map_theme.ogg
```

### Paso 2: Crear la Escena del Mapa

1. Usa `world_map.tscn` como base
2. Asigna una imagen de fondo para el mapa:

```gdscript
# En world_map.tscn, reemplaza MapSprite
[node name="MapSprite" type="Sprite2D" parent="."]
texture = preload("res://assets/maps/world_map.png")
```

### Paso 3: Crear Retratos de Personajes

Los retratos deben ser imágenes PNG de aproximadamente 200x400 píxeles:

```
assets/portraits/
├── eirika.png       (Protagonista)
├── ephraim.png      (Protagonista)
├── seth.png         (Aliado)
├── valter.png       (Enemigo)
└── ...
```

**Tip**: Los retratos de jugadores van a la izquierda, enemigos a la derecha.

### Paso 4: Configurar Autoloads (Opcional)

Para usar las transiciones globalmente:

1. Project > Project Settings > Autoload
2. Añadir `CinematicTransitions.gd` como autoload
   - Nombre: "Transitions"
   - Path: `res://scripts/CinematicTransitions.gd`

### Paso 5: Configurar Input Actions

Añade estas acciones en Project > Project Settings > Input Map:

```
ui_accept         (Enter, Space, Gamepad A)
ui_select         (Enter, Gamepad A)
ui_cancel         (Escape, Gamepad B)
skip_cinematic    (Ctrl, Gamepad Start)
```

## 📝 Uso del Sistema

### Configurar Ubicaciones del Mapa

En `WorldMap.gd`, en la función `setup_world_map()`:

```gdscript
func setup_world_map():
	# Registrar ubicaciones (id, nombre, posición, capítulo)
	register_location("prologue", "Prólogo", Vector2(200, 400), 0)
	register_location("ch1", "Capítulo 1", Vector2(350, 350), 1)
	register_location("ch2", "Capítulo 2", Vector2(500, 280), 2)
	
	# Desbloquear el prólogo
	unlock_location("prologue")
	
	create_location_markers()
```

### Crear Diálogos para Capítulos

En `WorldMap.gd`, en la clase `ChapterDialogues`:

```gdscript
static var dialogues = {
	"prologue": [
		{
			"character": "Narrador",
			"text": "Hace mucho tiempo...",
			"portrait": ""
		},
		{
			"character": "Eirika",
			"text": "¡Debemos defender el reino!",
			"portrait": "res://assets/portraits/eirika.png"
		}
	],
	"ch1": [
		{
			"character": "Seth",
			"text": "Mi señora, los enemigos se acercan.",
			"portrait": "res://assets/portraits/seth.png"
		}
	]
}
```

### Reproducir Cinemáticas

```gdscript
# Cinemática de introducción al capítulo
await world_map.play_chapter_intro_cinematic("prologue")

# Cinemática de viaje entre ubicaciones
await world_map.play_travel_cinematic("prologue", "ch1")

# Desbloquear nueva ubicación con cinemática
await world_map.play_unlock_cinematic("ch2")
```

### Usar Diálogos Manualmente

```gdscript
# Diálogo individual
await dialogue_box.show_dialogue(
	"Eirika",
	"¡Nunca me rendiré!",
	"res://assets/portraits/eirika.png"
)

# Secuencia de diálogos
var dialogues = [
	{
		"character": "Eirika",
		"text": "¿Qué debemos hacer?",
		"portrait": "res://assets/portraits/eirika.png"
	},
	{
		"character": "Seth",
		"text": "Seguiremos adelante, mi señora.",
		"portrait": "res://assets/portraits/seth.png"
	}
]

await dialogue_box.show_dialogue_sequence(dialogues)
```

### Usar Transiciones

```gdscript
# Fade simple
await Transitions.fade_out(1.0)
get_tree().change_scene_to_file("res://scenes/battle.tscn")
await Transitions.fade_in(1.0)

# O todo junto
await Transitions.fade_to_scene("res://scenes/battle.tscn", 1.0, 1.0)

# Transición de batalla
await Transitions.battle_start_transition("res://scenes/battle.tscn")

# Transición circular (iris)
await Transitions.circle_transition(true, 1.0)  # Cerrar
await Transitions.circle_transition(false, 1.0) # Abrir

# Wipe (barrido)
await Transitions.wipe_transition(Transitions.TransitionType.WIPE_LEFT, 1.0)

# Flash dramático
await Transitions.flash_screen(Color.WHITE, 0.3, 1.0)

# Shake de pantalla
await Transitions.shake_screen(20.0, 0.5)

# Transición dramática completa
await Transitions.dramatic_scene_transition("res://scenes/important_scene.tscn")
```

## 🎨 Personalización

### Cambiar Colores de Diálogo

En `DialogueBox.gd`:

```gdscript
# Color del panel
style_box.bg_color = Color(0.1, 0.1, 0.15, 0.95)  # Azul oscuro

# Color del borde
style_box.border_color = Color(0.8, 0.7, 0.5, 1.0)  # Dorado

# Color del nombre
character_name_label.add_theme_color_override("font_color", Color(1, 0.9, 0.7, 1))
```

### Ajustar Velocidad de Texto

```gdscript
# En DialogueBox.gd
@export var text_speed: float = 0.05  # Segundos por carácter (más bajo = más rápido)
```

### Cambiar Estilo de Marcadores

En `WorldMap.gd`, en la clase `LocationMarker`, función `_draw()`:

```gdscript
func _draw():
	var color = Color.GRAY
	
	if is_completed:
		color = Color.GREEN  # Cambiar color de completado
	elif is_unlocked:
		color = Color.GOLD   # Cambiar color desbloqueado
	
	# Cambiar tamaño del círculo
	draw_circle(Vector2.ZERO, 25, color)  # Radio de 25
```

### Añadir Efectos de Sonido

```gdscript
# En DialogueBox.gd
func play_text_sound():
	var audio_player = AudioStreamPlayer.new()
	audio_player.stream = preload("res://assets/audio/dialogue_beep.wav")
	audio_player.volume_db = -10
	add_child(audio_player)
	audio_player.play()
	audio_player.finished.connect(audio_player.queue_free)
```

## 🎬 Crear Secuencias Cinemáticas Complejas

### Ejemplo: Secuencia de Apertura Completa

```gdscript
func play_opening_sequence():
	# 1. Fade in desde negro
	await Transitions.fade_in(2.0)
	
	# 2. Mostrar título del juego
	await world_map.show_location_title("FIRE EMBLEM: TU TÍTULO")
	
	# 3. Zoom hacia el mapa
	await world_map.camera_zoom_in(Vector2(1.0, 1.0), 2.0)
	
	# 4. Mover a la primera ubicación
	await world_map.camera_move_to_location(Vector2(200, 400), 2.0)
	
	# 5. Diálogo de introducción
	var intro_dialogues = [
		{
			"character": "Narrador",
			"text": "En un tiempo de guerra y caos...",
			"portrait": ""
		},
		{
			"character": "Narrador",
			"text": "Un joven héroe se alzará...",
			"portrait": ""
		}
	]
	await dialogue_box.show_dialogue_sequence(intro_dialogues)
	
	# 6. Desbloquear primer capítulo con efecto
	await world_map.play_unlock_cinematic("prologue")
	
	# 7. Zoom out para mostrar todo el mapa
	await world_map.camera_zoom_out(Vector2(0.5, 0.5), 2.0)
```

### Ejemplo: Transición Entre Capítulos

```gdscript
func transition_to_next_chapter(current_chapter: String, next_chapter: String):
	# 1. Fade out del gameplay
	await Transitions.fade_out(1.0)
	
	# 2. Volver al mapa del mundo
	get_tree().change_scene_to_file("res://scenes/world_map.tscn")
	await get_tree().process_frame
	
	# 3. Completar capítulo actual
	world_map.complete_location(current_chapter)
	
	# 4. Fade in al mapa
	await Transitions.fade_in(1.0)
	
	# 5. Desbloquear siguiente capítulo con cinemática
	await world_map.play_unlock_cinematic(next_chapter)
	
	# 6. Diálogo de transición
	var transition_dialogue = [
		{
			"character": "Eirika",
			"text": "Hemos vencido aquí, pero el camino continúa...",
			"portrait": "res://assets/portraits/eirika.png"
		}
	]
	await dialogue_box.show_dialogue_sequence(transition_dialogue)
```

## 🎯 Integración con el Sistema de Juego

### Conectar Mapa con Batallas

```gdscript
# En WorldMap.gd
func _on_location_clicked(location_id: String):
	# ... código existente ...
	
	# Iniciar batalla
	start_chapter_battle(location_id)

func start_chapter_battle(chapter_id: String):
	# Cinemática de inicio de batalla
	await play_chapter_intro_cinematic(chapter_id)
	
	# Transición dramática
	await Transitions.battle_start_transition("res://scenes/battle.tscn")
	
	# El GameManager cargará el mapa y unidades correspondientes
```

### Guardar Progreso del Mapa

```gdscript
# En WorldMap.gd
func save_world_map_progress():
	var save_data = {
		"unlocked_locations": unlocked_locations,
		"current_location": current_location_id,
		"campaign_progress": campaign_progress,
		"completed_locations": []
	}
	
	for loc_id in locations.keys():
		if locations[loc_id]["completed"]:
			save_data["completed_locations"].append(loc_id)
	
	return save_data

func load_world_map_progress(save_data: Dictionary):
	unlocked_locations = save_data["unlocked_locations"]
	current_location_id = save_data["current_location"]
	campaign_progress = save_data["campaign_progress"]
	
	for loc_id in save_data["completed_locations"]:
		complete_location(loc_id)
```

## 💡 Tips y Trucos

### 1. Optimizar Retratos
- Usa texturas comprimidas (WebP o PNG optimizados)
- Tamaño recomendado: 200x400 píxeles
- Mantén el estilo consistente entre todos los retratos

### 2. Timing de Cinemáticas
- Usa `await get_tree().create_timer(X).timeout` para pausas dramáticas
- Las transiciones largas (>2s) pueden aburrir; mantén ritmo dinámico
- Permite saltar cinemáticas con `skip_cinematic`

### 3. Feedback Visual
- Siempre da feedback cuando el jugador interactúa
- Usa efectos de hover en los marcadores
- Anima los cambios de estado (desbloqueo, completado)

### 4. Audio
- Añade música temática para el mapa del mundo
- Sonidos de "bip" sutiles durante diálogos
- SFX para transiciones y desbloqueos

### 5. Performance
- Usa `queue_redraw()` en lugar de `update()` en Godot 4
- Limita el número de tweens simultáneos
- Cachea texturas de retratos si se reutilizan

## 🐛 Solución de Problemas

### Los retratos no aparecen
- Verifica que las rutas en los diálogos sean correctas
- Asegúrate de que las imágenes existan en `res://assets/portraits/`
- Comprueba que sean PNG o JPG válidos

### Las transiciones se ven cortadas
- Verifica que el `TransitionRect` cubra toda la pantalla
- Asegúrate de que el `CanvasLayer` tenga el layer correcto

### La cámara no se mueve suavemente
- Ajusta la duración de los tweens
- Usa `Tween.TRANS_CUBIC` con `Tween.EASE_IN_OUT` para movimiento suave

### Los marcadores no responden a clicks
- Verifica que tengan un `Area2D` con `CollisionShape2D`
- Comprueba que `input_pickable` esté habilitado en el Area2D

## 📚 Recursos Adicionales

### Referencias de Fire Emblem
- Fire Emblem: The Sacred Stones (GBA)
- Fire Emblem: Path of Radiance (GC)
- Fire Emblem Awakening (3DS)

### Assets Recomendados
- [itch.io - Fire Emblem Assets](https://itch.io)
- [OpenGameArt - Strategy RPG](https://opengameart.org)
- Crear tus propios assets con Aseprite o GIMP

## 🎮 Próximos Pasos

Ideas para expandir el sistema:

- [ ] Sistema de "soporte" entre personajes
- [ ] Mapas del mundo múltiples (diferentes continentes)
- [ ] Eventos aleatorios en el mapa
- [ ] Tiendas y lugares opcionales
- [ ] Sistema de clima que afecta batallas
- [ ] Animaciones 3D para transiciones
- [ ] Cutscenes pre-renderizadas
- [ ] Sistema de logros desbloqueables

¡Tu mapa del mundo cinemático está listo! 🎬
