# Sistema de Menús - Fire Emblem Remake

Sistema completo de menú principal con opciones, créditos y sistema de guardado para tu remake de Fire Emblem.

## 📁 Archivos Incluidos

```
MainMenu.gd           - Menú principal con navegación y transiciones
main_menu.tscn        - Escena del menú principal
OptionsMenu.gd        - Menú de opciones con configuración completa
options_menu.tscn     - Escena del menú de opciones
```

## 🎮 Características del Menú Principal

### Botones Principales
- **Nueva Partida** - Inicia una nueva partida
- **Continuar** - Carga la partida guardada (se deshabilita si no hay guardado)
- **Opciones** - Abre el menú de configuración
- **Créditos** - Muestra pantalla de créditos con scroll
- **Salir** - Sale del juego (con confirmación)

### Características Adicionales
- ✅ Navegación con mouse y teclado (flechas + Enter)
- ✅ Efectos de hover con sonido
- ✅ Animaciones de entrada y salida
- ✅ Transiciones suaves entre escenas
- ✅ Música de fondo del menú
- ✅ Sistema de guardado integrado
- ✅ Confirmación antes de salir

## ⚙️ Menú de Opciones

### Sección Audio
- **Volumen Master** - Controla el volumen general
- **Volumen Música** - Controla solo la música
- **Volumen SFX** - Controla efectos de sonido

### Sección Pantalla
- **Pantalla Completa** - Toggle fullscreen
- **VSync** - Activar/desactivar sincronización vertical
- **Resolución** - Cambiar resolución (5 opciones predefinidas)

### Sección Gameplay
- **Velocidad Animaciones** - Ajustar velocidad de animaciones (0.5x a 2x)
- **Mostrar Cuadrícula** - Toggle para mostrar/ocultar grid
- **Fin de Turno Automático** - Finalizar turno cuando todas las unidades actúan

### Botones
- **Volver** - Cierra sin guardar cambios
- **Por Defecto** - Restaura valores por defecto
- **Aplicar** - Guarda y aplica la configuración

## 🚀 Configuración en Godot 4

### Paso 1: Crear Autoloads (Project Settings)

1. Ve a **Project > Project Settings > Autoload**
2. Añade estos scripts como autoloads:

```
GameSettings → res://OptionsMenu.gd (habilitar solo la clase GameSettings)
SaveSystem → res://MainMenu.gd (habilitar solo la clase SaveSystem)
```

### Paso 2: Configurar Buses de Audio

1. Ve a la pestaña **Audio** en Godot
2. Crea estos buses:
   - **Master** (ya existe por defecto)
   - **Music** (hijo de Master)
   - **SFX** (hijo de Master)

Estructura:
```
Master
├── Music
└── SFX
```

### Paso 3: Configurar el Proyecto

1. **Establecer el menú como escena principal:**
   - Ve a Project > Project Settings > Application > Run
   - Establece `Main Scene` como `res://main_menu.tscn`

2. **Configurar acciones de input:**
   - Ve a Project > Project Settings > Input Map
   - Añade estas acciones si no existen:
     - `ui_accept` (Enter/Space)
     - `ui_cancel` (Escape)
     - `ui_up` (Flecha arriba)
     - `ui_down` (Flecha abajo)

### Paso 4: Estructura de Directorios

Organiza tu proyecto así:

```
res://
├── scenes/
│   ├── main_menu.tscn
│   ├── options_menu.tscn
│   ├── main_game.tscn          (tu escena de juego)
│   └── ...
├── scripts/
│   ├── MainMenu.gd
│   ├── OptionsMenu.gd
│   ├── GameManager.gd
│   └── ...
├── assets/
│   ├── audio/
│   │   ├── music/
│   │   │   └── menu_theme.ogg  (música del menú)
│   │   └── sfx/
│   │       ├── hover.wav       (sonido de hover)
│   │       └── select.wav      (sonido de selección)
│   └── ui/
│       └── background.png      (fondo del menú)
└── ...
```

### Paso 5: Añadir Assets de Audio (Opcional)

Si tienes archivos de audio, añádelos a los nodos correspondientes:

1. **MenuMusic** node → Asigna tu archivo de música (.ogg, .mp3)
2. **HoverSound** node → Sonido corto de hover
3. **SelectSound** node → Sonido de selección/clic

## 🎨 Personalización

### Cambiar Colores del Menú

En `MainMenu.gd`, modifica estas constantes:

```gdscript
# Color de fondo
$Background.color = Color(0.1, 0.1, 0.15, 1)  # Azul oscuro

# Color del título
$MarginContainer/VBoxContainer/TitleLabel.theme_override_colors/font_color = Color(0.9, 0.85, 0.7, 1)
```

### Personalizar Botones

En `main_menu.tscn`, edita los StyleBox de los botones:

```gdscript
# En StyleBoxFlat_button_normal:
bg_color = Color(0.2, 0.2, 0.3, 0.8)  # Color normal
corner_radius = 8  # Bordes redondeados

# En StyleBoxFlat_button_hover:
bg_color = Color(0.3, 0.4, 0.6, 0.9)  # Color al hacer hover
```

### Añadir Imagen de Fondo

1. Añade tu imagen en `assets/ui/background.png`
2. En `main_menu.tscn`, cambia el nodo Background de ColorRect a TextureRect:

```gdscript
[node name="Background" type="TextureRect" parent="."]
texture = preload("res://assets/ui/background.png")
stretch_mode = TextureRect.STRETCH_SCALE
```

### Modificar el Texto de Créditos

En `MainMenu.gd`, edita la variable `credits_text`:

```gdscript
var credits_text: String = """
[center][b]TU JUEGO[/b]

Hecho por: Tu Nombre

[b]EQUIPO[/b]
Programador: Tu Nombre
Artista: ...
Músico: ...

Gracias por jugar!
[/center]
"""
```

## 💾 Sistema de Guardado

### Cómo Funciona

El sistema guarda la configuración en `user://settings.cfg` y las partidas en `user://savegame.save`.

En Windows: `%APPDATA%\Godot\app_userdata\[ProjectName]/`
En Linux: `~/.local/share/godot/app_userdata/[ProjectName]/`
En Mac: `~/Library/Application Support/Godot/app_userdata/[ProjectName]/`

### Usar el Sistema de Guardado

Para guardar una partida desde tu GameManager:

```gdscript
# En GameManager.gd
func save_game():
	var save_data = {
		"turn": current_turn,
		"player_units": serialize_units(player_units),
		"enemy_units": serialize_units(enemy_units),
		"map_state": get_map_state()
	}
	
	SaveSystem.save_game(save_data)

func serialize_units(units: Array[Unit]) -> Array:
	var data = []
	for unit in units:
		data.append({
			"name": unit.unit_name,
			"position": var_to_str(unit.grid_position),
			"hp": unit.current_hp,
			# ... más datos
		})
	return data
```

Para cargar una partida:

```gdscript
func load_game() -> bool:
	if not SaveSystem.has_save_file():
		return false
	
	var save_data = SaveSystem.load_game_data()
	
	# Restaurar estado del juego
	current_turn = save_data["turn"]
	restore_units(save_data["player_units"], true)
	restore_units(save_data["enemy_units"], false)
	
	return true
```

## 🎯 Conectar con tu Juego

### Transición al Juego

En `MainMenu.gd`, actualiza la ruta de tu escena de juego:

```gdscript
const GAME_SCENE_PATH = "res://scenes/main_game.tscn"
```

### Desde el Juego al Menú

Para volver al menú desde el juego, añade un botón de pausa:

```gdscript
# En tu GameManager.gd o PauseMenu.gd
func return_to_main_menu():
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
```

## 🎮 Controles

### Navegación con Teclado
- **↑/↓** - Navegar entre opciones
- **Enter/Space** - Seleccionar opción
- **Escape** - Volver/Cancelar

### Navegación con Mouse
- **Click** - Seleccionar opción
- **Hover** - Resaltar botón

## 🐛 Solución de Problemas

### El botón "Continuar" siempre está deshabilitado
- Verifica que `SaveSystem.has_save_file()` funcione correctamente
- Asegúrate de que tu juego guarde los datos al salir

### No se escucha el audio
1. Verifica que los buses de audio estén configurados correctamente
2. Asegura que los archivos de audio estén asignados a los nodos
3. Revisa que el volumen no esté en 0

### Las animaciones no funcionan
- Verifica que el `AnimationPlayer` tenga las animaciones "intro" y "fade_out" creadas
- Puedes crear animaciones simples de fade modificando la propiedad `modulate:a`

### La resolución no cambia
- Asegúrate de que el juego no esté forzado a fullscreen en Project Settings
- Verifica que las resoluciones en el diccionario `RESOLUTIONS` sean válidas

## 📝 Próximas Mejoras

Ideas para expandir el sistema de menús:

- [ ] Menú de pausa in-game
- [ ] Múltiples slots de guardado
- [ ] Galería de personajes desbloqueados
- [ ] Sistema de logros
- [ ] Tutoriales interactivos
- [ ] Configuración de controles personalizable
- [ ] Perfiles de jugador
- [ ] Estadísticas de partida
- [ ] Selector de dificultad
- [ ] Modo de práctica/skirmish

## 🎨 Tips de Diseño

1. **Consistencia Visual:** Usa la misma paleta de colores en todo el menú
2. **Jerarquía:** El título debe ser lo más prominente, seguido por los botones principales
3. **Espaciado:** Deja suficiente espacio entre elementos para facilitar la navegación
4. **Feedback:** Siempre da feedback visual/audio cuando el usuario interactúa
5. **Accesibilidad:** Asegura que los textos tengan buen contraste con el fondo

¡Ya tienes un sistema de menús completo y profesional para tu juego!
