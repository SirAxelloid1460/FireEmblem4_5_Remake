# Fire Emblem Remake - Godot 4

Un sistema base completo para crear un juego estilo Fire Emblem en Godot 4.

## 🎮 Características Implementadas

### Sistema de Grid
- Grid táctico configurable
- Sistema de coordenadas grid/mundo
- Detección de casillas caminables
- Gestión de unidades en el mapa

### Sistema de Unidades
- Stats completos estilo Fire Emblem (HP, Str, Mag, Skill, Speed, Luck, Def, Res)
- Sistema de clases
- Sistema de armas con durabilidad
- Sistema de inventario básico
- Cálculo de stats derivados (Hit rate, Avoid, Critical)
- Doble ataque cuando Speed >= Enemy Speed + 4

### Sistema de Combate
- Combate automático completo
- Triángulo de armas (Sword > Axe > Lance > Sword)
- Sistema de críticos
- Contraataques
- Doble ataque
- Preview de combate (para mostrar en UI)

### Sistema de Movimiento
- Pathfinding con algoritmo A*
- Cálculo de casillas alcanzables (flood-fill)
- Rango de ataque
- Combinación de movimiento + ataque

### Sistema de Turnos
- Turnos de jugador y enemigo
- IA enemiga básica (buscar objetivo más cercano)
- Sistema de fases del jugador
- Control de fin de turno

## 📁 Estructura de Archivos

```
Grid.gd           - Sistema de grid/mapa
Unit.gd           - Clase de unidad con stats
Items.gd          - Armas e items (Weapon, Item, Vulnerary)
Pathfinding.gd    - A* y cálculo de rangos
CombatSystem.gd   - Sistema de combate completo
GameManager.gd    - Controlador principal del juego
```

## 🚀 Configuración en Godot 4

### Paso 1: Crear la Escena Principal

1. Abre Godot 4
2. Crea una nueva escena 2D
3. Estructura de nodos:

```
Main (Node2D)
├── GameManager (Node) [Script: GameManager.gd]
└── Grid (Node2D) [Script: Grid.gd]
```

### Paso 2: Configurar los Scripts

1. **Crear los scripts como Autoloads (opcional pero recomendado para algunos):**
   - Ve a Project > Project Settings > Autoload
   - Añade `Pathfinding.gd` como Autoload (nombre: "Pathfinding")
   - Añade `CombatSystem.gd` como Autoload (nombre: "CombatSystem")

2. **Asignar scripts a nodos:**
   - GameManager node → `GameManager.gd`
   - Grid node → `Grid.gd`

### Paso 3: Configurar el Grid

En el nodo Grid, configura las propiedades exportadas:
- `grid_width`: 15
- `grid_height`: 10
- `cell_size`: 64

### Paso 4: Crear Resources para Armas

1. Crea una carpeta `resources/weapons/` en tu proyecto
2. Crea archivos .tres para diferentes armas:

**iron_sword.tres:**
```gdscript
[gd_resource type="Resource" script_class="Weapon" load_steps=2 format=3]

[ext_resource type="Script" path="res://Items.gd" id="1"]

[resource]
script = ExtResource("1")
weapon_name = "Iron Sword"
weapon_type = "Sword"
might = 5
accuracy = 90
critical = 0
weight = 5
max_durability = 45
current_durability = 45
is_magic = false
range_min = 1
range_max = 1
```

### Paso 5: Crear Sprites para las Unidades (Opcional)

Si quieres usar sprites en lugar de círculos:

1. En `Unit.gd`, añade un nodo Sprite2D como hijo
2. Modifica la función `update_visual()` para cambiar sprites

```gdscript
# En Unit.gd, añadir:
@onready var sprite: Sprite2D = $Sprite2D

func update_visual():
	if has_acted:
		sprite.modulate = Color(0.6, 0.6, 0.6, 1.0)
	elif is_selected:
		sprite.modulate = Color(1.2, 1.2, 1.0, 1.0)
	else:
		sprite.modulate = Color.WHITE
```

## 🎯 Cómo Usar

### Controles Básicos (Mouse)

1. **Click en unidad aliada** → Selecciona la unidad
2. **Click en casilla azul** → Mueve la unidad
3. **Click en enemigo en rango** → Ataca al enemigo

### Flujo del Juego

1. Turno del jugador:
   - Selecciona unidad
   - Mueve la unidad
   - Si hay enemigos en rango, entra en modo targeting
   - Click en enemigo para atacar
   - La unidad se marca como usada

2. Cuando todas las unidades actúan → Turno enemigo
3. Los enemigos mueven y atacan automáticamente
4. Vuelve al turno del jugador

## 🔧 Personalización

### Añadir Nuevas Unidades

```gdscript
func create_custom_unit(pos: Vector2i, is_player: bool):
	var unit = Unit.new()
	unit.unit_name = "Hero"
	unit.unit_class = "Mercenary"
	unit.is_player_unit = is_player
	unit.max_hp = 30
	unit.current_hp = 30
	unit.strength = 10
	unit.skill = 12
	unit.speed = 13
	unit.defense = 7
	
	# Crear arma
	var weapon = Weapon.new()
	weapon.weapon_name = "Steel Sword"
	weapon.might = 8
	unit.weapon = weapon
	
	add_child(unit)
	grid.place_unit(unit, pos)
	
	if is_player:
		player_units.append(unit)
	else:
		enemy_units.append(unit)
```

### Modificar Tipos de Terreno

En `Grid.gd`:

```gdscript
# Añadir diferentes tipos de terreno
tiles[pos] = {
	"walkable": true,
	"terrain_type": "forest",  # plain, forest, mountain, etc.
	"defense_bonus": 1,         # Bonus de defensa
	"avoid_bonus": 20,          # Bonus de evasión
	"movement_cost": 2          # Costo de movimiento
}
```

### Crear Nuevas Clases de Armas

En `Items.gd`:

```gdscript
# Ejemplo: Arco
var bow = Weapon.new()
bow.weapon_name = "Iron Bow"
bow.weapon_type = "Bow"
bow.might = 6
bow.accuracy = 85
bow.range_min = 2  # No puede atacar en rango 1
bow.range_max = 2
```

## 📊 Siguiente Paso: UI

Para completar el sistema, necesitarás crear:

1. **Panel de información de unidad** - Mostrar stats
2. **Preview de combate** - Mostrar damage/hit/crit antes de atacar
3. **Menú de acciones** - Attack, Items, Wait
4. **Barra de HP visual** - Mejorar la visualización
5. **Animaciones de combate** - Hacer el combate más visual

¿Quieres que te ayude con alguno de estos componentes de UI?

## 🐛 Debugging

Para ver mensajes de debug, abre la consola de Godot mientras juegas.

Verás mensajes como:
- "Unit selected: [nombre]"
- "Can reach X tiles"
- Resumen de combates
- Información de turnos

## 📝 Notas

- El sistema usa `class_name` para hacer las clases globales
- Los archivos deben estar en la raíz del proyecto o ajustar las rutas
- El sistema es modular - puedes extender cada componente independientemente
- La IA enemiga es básica - puedes mejorarla con comportamientos más complejos

## 🎨 Mejoras Futuras Sugeridas

- [ ] Sistema de experiencia y level up
- [ ] Más tipos de terreno
- [ ] Habilidades especiales
- [ ] Sistema de soporte entre unidades
- [ ] Fog of War
- [ ] Objetivos de misión (Rout, Seize, Defend, etc.)
- [ ] Guardar/Cargar partida
- [ ] Animaciones de combate
- [ ] Sistema de diálogos
- [ ] Editor de mapas

¡Buena suerte con tu remake de Fire Emblem!
