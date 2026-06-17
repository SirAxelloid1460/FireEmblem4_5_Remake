# Sistema de Cinemáticas Automáticas - Fire Emblem Remake

Sistema de cinemáticas que se reproducen automáticamente sin interacción del usuario, estilo Fire Emblem GBA/SNES.

## 📁 Archivos Incluidos

```
CinematicScene.gd          - Sistema base de cinemáticas automáticas
CinematicExamples.gd       - Ejemplos de cinemáticas específicas
DialogueBox.gd             - Sistema de diálogos (sin cambios)
CinematicTransitions.gd    - Transiciones cinemáticas (sin cambios)
cinematic_scene.tscn       - Escena base de cinemática
```

## 🎬 Características Principales

### Reproducción Automática
- ✅ **Sin interacción del usuario** - Las cinemáticas se reproducen solas
- ✅ **Secuencias programables** - Define cada paso con diccionarios simples
- ✅ **Transición automática** - Va a la siguiente escena al finalizar
- ✅ **Sistema de skip** - Permite saltar con ESC o botón configurado

### Tipos de Pasos Cinemáticos
- ✅ **fade_in / fade_out** - Transiciones de fade
- ✅ **show_title** - Muestra títulos en pantalla
- ✅ **camera_move** - Mueve cámara con zoom
- ✅ **camera_pan** - Paneo por múltiples puntos
- ✅ **camera_zoom** - Zoom independiente
- ✅ **dialogue_sequence** - Secuencias de diálogos
- ✅ **flash** - Flash de pantalla
- ✅ **shake** - Shake de cámara
- ✅ **wait** - Pausa simple
- ✅ **play_animation** - Reproduce animación del AnimationPlayer

## 🚀 Uso Básico

### Crear una Cinemática Simple

```gdscript
extends CinematicScene

func build_cinematic_sequence() -> Array[Dictionary]:
	var sequence: Array[Dictionary] = []
	
	# Fade in
	sequence.append({
		"type": "fade_in",
		"duration": 2.0
	})
	
	# Mostrar título
	sequence.append({
		"type": "show_title",
		"text": "CAPÍTULO 1",
		"duration": 3.0
	})
	
	# Mover cámara
	sequence.append({
		"type": "camera_move",
		"target": Vector2(800, 600),
		"duration": 3.0,
		"zoom": Vector2(1.5, 1.5)
	})
	
	# Diálogos
	sequence.append({
		"type": "dialogue_sequence",
		"dialogues": [
			{
				"character": "Eirika",
				"text": "¡Adelante!",
				"portrait": "res://assets/portraits/eirika.png"
			}
		]
	})
	
	# Fade out
	sequence.append({
		"type": "fade_out",
		"duration": 1.5
	})
	
	return sequence

func transition_to_next_scene():
	get_tree().change_scene_to_file("res://scenes/battle.tscn")
```

## 📝 Configuración Paso a Paso

### Paso 1: Crear tu Escena de Cinemática

1. **Opción A - Usar la escena base:**
   - Duplica `cinematic_scene.tscn`
   - Renómbrala (ej: `chapter1_opening.tscn`)
   - Cambia el script a tu script personalizado

2. **Opción B - Crear desde cero:**
   ```
   Node2D (script: tu_cinematica.gd que extiende CinematicScene)
   ├── Background (ColorRect)
   ├── MapSprite (Sprite2D) - Tu mapa de fondo
   ├── Camera2D
   ├── AnimationPlayer (opcional)
   └── CanvasLayer
       └── DialogueBox (Control con DialogueBox.gd)
   ```

### Paso 2: Crear tu Script de Cinemática

```gdscript
extends CinematicScene

# Configuración
@export var next_scene_path: String = "res://scenes/battle.tscn"

func build_cinematic_sequence() -> Array[Dictionary]:
	var sequence: Array[Dictionary] = []
	
	# Añade tus pasos aquí...
	
	return sequence

func transition_to_next_scene():
	get_tree().change_scene_to_file(next_scene_path)
```

### Paso 3: Añadir el Mapa de Fondo

En tu escena `.tscn`, asigna una textura al `MapSprite`:

```gdscript
# O en el inspector:
# MapSprite > Texture = res://assets/maps/chapter1_map.png
```

### Paso 4: Configurar la Transición

Desde el menú principal o cualquier escena:

```gdscript
# Ir a la cinemática
get_tree().change_scene_to_file("res://scenes/cinematics/chapter1_opening.tscn")

# O con transición
await Transitions.fade_out(1.0)
get_tree().change_scene_to_file("res://scenes/cinematics/chapter1_opening.tscn")
```

## 🎯 Ejemplos de Cinemáticas

### Ejemplo 1: Apertura de Capítulo

```gdscript
func build_cinematic_sequence() -> Array[Dictionary]:
	return [
		# Fade in lento
		{"type": "fade_in", "duration": 2.0},
		
		# Vista general del mapa
		{"type": "camera_move", "target": Vector2(960, 540), 
		 "duration": 0.5, "zoom": Vector2(0.6, 0.6)},
		
		# Título del capítulo
		{"type": "show_title", "text": "CAPÍTULO 1", "duration": 2.5},
		{"type": "show_title", "text": "La Fortaleza Perdida", "duration": 3.0},
		
		# Paneo por el escenario
		{"type": "camera_pan", 
		 "waypoints": [
			 Vector2(400, 300),   # Inicio
			 Vector2(700, 400),   # Medio
			 Vector2(1000, 350)   # Final
		 ], 
		 "duration": 5.0},
		
		# Zoom al objetivo
		{"type": "camera_move", "target": Vector2(1000, 350),
		 "duration": 2.0, "zoom": Vector2(1.5, 1.5)},
		
		# Diálogos
		{"type": "dialogue_sequence", "dialogues": [
			{
				"character": "Eirika",
				"text": "Debemos recuperar la fortaleza.",
				"portrait": "res://assets/portraits/eirika.png"
			},
			{
				"character": "Seth",
				"text": "Estamos listos, mi señora.",
				"portrait": "res://assets/portraits/seth.png"
			}
		]},
		
		# Transición a batalla
		{"type": "fade_out", "duration": 1.5}
	]
```

### Ejemplo 2: Prólogo Narrativo

```gdscript
func build_cinematic_sequence() -> Array[Dictionary]:
	return [
		# Apertura dramática
		{"type": "fade_in", "duration": 3.0},
		
		# Título del juego
		{"type": "show_title", "text": "FIRE EMBLEM", "duration": 4.0},
		
		# Transición
		{"type": "fade_out", "duration": 1.5},
		{"type": "fade_in", "duration": 2.0},
		
		# Narración con vistas del mapa
		{"type": "camera_move", "target": Vector2(640, 360),
		 "duration": 1.0, "zoom": Vector2(1.0, 1.0)},
		
		{"type": "dialogue_sequence", "dialogues": [
			{
				"character": "Narrador",
				"text": "Hace mucho tiempo, en el continente de Magvel...",
				"portrait": ""
			},
			{
				"character": "Narrador",
				"text": "Una era de paz llegó a su fin.",
				"portrait": ""
			}
		]},
		
		# Paneo dramático largo
		{"type": "camera_pan", 
		 "waypoints": [
			 Vector2(300, 300),
			 Vector2(600, 400),
			 Vector2(900, 350),
			 Vector2(1200, 400)
		 ], 
		 "duration": 10.0},
		
		# Más narración
		{"type": "dialogue_sequence", "dialogues": [
			{
				"character": "Narrador",
				"text": "La princesa Eirika debe huir...",
				"portrait": ""
			}
		]},
		
		# Título del prólogo
		{"type": "show_title", "text": "PRÓLOGO: La Huida", "duration": 3.0},
		
		{"type": "fade_out", "duration": 2.0}
	]
```

### Ejemplo 3: Evento Especial In-Game

```gdscript
func build_cinematic_sequence() -> Array[Dictionary]:
	return [
		# Impacto dramático
		{"type": "flash", "color": Color.WHITE, "duration": 0.3},
		{"type": "shake", "intensity": 30.0, "duration": 0.5},
		
		# Zoom dramático
		{"type": "camera_move", "target": Vector2(640, 360),
		 "duration": 1.5, "zoom": Vector2(2.5, 2.5)},
		
		# Revelación
		{"type": "show_title", "text": "¡Un Enemigo Poderoso Aparece!", 
		 "duration": 2.5},
		
		# Diálogo del evento
		{"type": "dialogue_sequence", "dialogues": [
			{
				"character": "???",
				"text": "Así que al fin nos encontramos...",
				"portrait": ""
			},
			{
				"character": "Eirika",
				"text": "¿Quién eres?",
				"portrait": "res://assets/portraits/eirika.png"
			}
		]},
		
		# Zoom out
		{"type": "camera_zoom", "zoom": Vector2(1.0, 1.0), "duration": 1.5}
	]
```

### Ejemplo 4: Final de Capítulo

```gdscript
func build_cinematic_sequence() -> Array[Dictionary]:
	return [
		{"type": "fade_in", "duration": 1.5},
		
		# Victoria
		{"type": "flash", "color": Color(1, 1, 0.8, 0.8), "duration": 0.5},
		{"type": "show_title", "text": "¡VICTORIA!", "duration": 3.0},
		
		# Diálogos post-batalla
		{"type": "dialogue_sequence", "dialogues": [
			{
				"character": "Eirika",
				"text": "Lo logramos. Pero el camino continúa.",
				"portrait": "res://assets/portraits/eirika.png"
			},
			{
				"character": "Seth",
				"text": "Sigamos adelante, mi señora.",
				"portrait": "res://assets/portraits/seth.png"
			}
		]},
		
		# Estadísticas
		{"type": "show_title", "text": "Capítulo 1 Completado", "duration": 2.5},
		
		{"type": "fade_out", "duration": 2.0}
	]
```

## 🎨 Personalización Avanzada

### Crear Tus Propios Tipos de Paso

Puedes extender `execute_cinematic_step()` para añadir nuevos tipos:

```gdscript
func execute_cinematic_step(step: Dictionary):
	match step["type"]:
		"tu_nuevo_tipo":
			await tu_nueva_funcion(step)
		_:
			await super.execute_cinematic_step(step)

func tu_nueva_funcion(step: Dictionary):
	# Tu lógica personalizada aquí
	await get_tree().create_timer(1.0).timeout
```

### Usar Animaciones del AnimationPlayer

```gdscript
# En tu secuencia:
{
	"type": "play_animation",
	"animation": "nombre_de_tu_animacion"
}

# Crea animaciones en el AnimationPlayer para efectos complejos
# como movimientos de personajes, efectos de partículas, etc.
```

### Efectos Combinados

```gdscript
# Paneo + Diálogos simultáneos
# (Requiere implementación custom)

func build_cinematic_sequence() -> Array[Dictionary]:
	return [
		{"type": "start_camera_pan", "waypoints": [...], "duration": 10.0},
		{"type": "dialogue_sequence", "dialogues": [...]},
		{"type": "wait_for_pan"}
	]
```

## 🎮 Sistema de Skip

### Configuración de Skip

```gdscript
# En tu escena de cinemática
@export var skip_enabled: bool = true

# El jugador puede saltar con:
# - ESC (ui_cancel)
# - Ctrl (skip_cinematic) - configurable en Input Map
```

### Deshabilitar Skip para Momentos Importantes

```gdscript
@export var skip_enabled: bool = false

# Útil para cinemáticas cruciales de la historia
```

### Skip Inteligente

```gdscript
func _input(event):
	if event.is_action_pressed("skip_cinematic") and skip_enabled:
		# Solo permitir skip después de los primeros 2 segundos
		if get_elapsed_time() > 2.0:
			skip_cinematic()
```

## 💡 Tips y Mejores Prácticas

### 1. Timing de Cinemáticas
- **Apertura**: 20-40 segundos
- **Entre capítulos**: 15-30 segundos
- **Eventos in-game**: 10-20 segundos
- **Final**: 30-60 segundos

### 2. Movimientos de Cámara
- Usa `ease: IN_OUT` para movimientos suaves
- No hagas pans muy rápidos (mínimo 3 segundos)
- Alterna entre zoom in y zoom out para variedad

### 3. Diálogos
- Máximo 3-4 líneas de diálogo seguidas
- Alterna con acción visual (movimientos de cámara)
- Usa retratos para personajes importantes

### 4. Ritmo
```
Buena secuencia:
Título → Paneo → Diálogo → Acción → Diálogo → Final

Mala secuencia:
Título → Diálogo → Diálogo → Diálogo → Final
```

### 5. Audio (Implementación futura)
```gdscript
# Añadir música de fondo
sequence.append({
	"type": "play_music",
	"track": "res://assets/audio/chapter_theme.ogg",
	"volume": 0.7
})
```

## 🔗 Integración con el Juego

### Flujo Completo: Menú → Cinemática → Batalla → Cinemática → Menú

```gdscript
# En MainMenu.gd
func _on_new_game_pressed():
	get_tree().change_scene_to_file("res://scenes/cinematics/prologue.tscn")

# En PrologueCinematic (prologue.tscn)
func transition_to_next_scene():
	get_tree().change_scene_to_file("res://scenes/battle.tscn")

# En GameManager.gd (después de ganar batalla)
func on_battle_won():
	get_tree().change_scene_to_file("res://scenes/cinematics/chapter1_ending.tscn")

# En ChapterEndingCinematic
func transition_to_next_scene():
	get_tree().change_scene_to_file("res://scenes/cinematics/chapter2_opening.tscn")
```

## 📊 Estructura de Proyecto Recomendada

```
res://
├── scenes/
│   ├── cinematics/
│   │   ├── prologue.tscn
│   │   ├── chapter1_opening.tscn
│   │   ├── chapter1_ending.tscn
│   │   ├── chapter2_opening.tscn
│   │   └── finale.tscn
│   ├── battle.tscn
│   └── main_menu.tscn
├── scripts/
│   ├── CinematicScene.gd
│   ├── CinematicExamples.gd
│   └── DialogueBox.gd
└── assets/
    ├── maps/
    │   ├── world_map.png
    │   ├── chapter1_map.png
    │   └── chapter2_map.png
    └── portraits/
        ├── eirika.png
        ├── seth.png
        └── ...
```

## 🐛 Troubleshooting

### Las cinemáticas no se reproducen automáticamente
- Verifica que `auto_play = true` en el script
- Asegúrate de que `build_cinematic_sequence()` retorna un array con pasos

### La cámara no se mueve
- Verifica que el nodo Camera2D exista
- Comprueba que las coordenadas sean correctas
- Asegúrate de que `target` esté en Vector2

### Los diálogos no aparecen
- Verifica que DialogueBox esté correctamente configurado
- Comprueba las rutas de los retratos
- Asegúrate de usar `await` en `play_dialogue_sequence()`

### El skip no funciona
- Verifica que `skip_enabled = true`
- Configura la acción `skip_cinematic` en Input Map
- Asegúrate de que `_input()` esté siendo llamado

## 🎯 Próximos Pasos

Ideas para expandir el sistema:

- [ ] Sistema de subtítulos
- [ ] Audio y efectos de sonido integrados
- [ ] Zoom suave en retratos durante diálogos
- [ ] Sistema de achievement/logro al ver cinemáticas
- [ ] Galería de cinemáticas desbloqueadas
- [ ] Voces para personajes (voice acting)
- [ ] Cinemáticas con sprites animados
- [ ] Sistema de choices durante cinemáticas

¡Tu sistema de cinemáticas automáticas está listo! 🎬
