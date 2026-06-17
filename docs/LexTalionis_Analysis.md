# Lex Talionis — Análisis Completo para Importación a Godot
> Investigación exhaustiva del motor de Fire Emblem para recrearlo en Godot 4

---

## 1. ARQUITECTURA GENERAL

### Stack técnico original
- **Lenguaje:** Python 3.7+
- **Framework visual:** Pygame 1.9.4+
- **Módulos C compilados:** LOS (Line of Sight), fast_pathfinding, manhattan_sphere (optimizaciones de rendimiento en Cython/pyd)
- **Editor de niveles:** Tiled (.tmx) + herramientas propias (Editor/)
- **Licencia:** MIT — completamente open source, uso libre

### Estructura de carpetas del proyecto
```
lex-talionis/
├── main.py                  ← Entrada del juego
├── Code/                    ← Todo el código Python (motor)
├── Data/                    ← Datos del juego (Lion Throne)
├── DataSacredStones/        ← Datos del juego (Sacred Stones demo)
├── Sprites/                 ← Assets UI universales del motor
├── Editor/                  ← Editor de niveles
├── Saves/                   ← Sistema de guardado
├── Tests/                   ← Tests unitarios
└── Utilities/               ← Herramientas auxiliares
```

---

## 2. MÓDULOS DE CÓDIGO (Code/)

### 74 archivos Python — descripción por sistema

#### NÚCLEO DEL MOTOR
| Archivo | Función |
|---|---|
| `Engine.py` | Abstracción de Pygame (render, tiempo, input) |
| `GlobalConstants.py` | Constantes globales, carga de todos los assets al inicio |
| `StateMachine.py` | Máquina de estados principal del juego |
| `GameStateObj.py` | Objeto de estado global (toda la partida) |
| `GeneralStates.py` | Todos los estados de gameplay (free, move, attack, combat...) |
| `InputManager.py` | Gestión de input (teclado, gamepad) |
| `Transitions.py` | Transiciones entre escenas/estados |
| `SaveLoad.py` | Sistema de serialización y guardado |
| `configuration.py` | Carga de config.ini y constants.ini |
| `static_random.py` | RNG determinístico (importante para turnwheel/rewind) |

#### COMBATE
| Archivo | Función |
|---|---|
| `Solver.py` | Motor de combate — SolverStateMachine con estados: PreInit, Init, Attacker, AttackerBrave, Defender, DefenderBrave, Splash, SplashBrave, Summon, Done |
| `Interaction.py` | Orquesta el combate completo (setup, animación, resultado) |
| `Action.py` | Sistema de acciones reversibles (para Turnwheel) |
| `BattleAnimation.py` | Sistema de animaciones de combate |
| `AnimationManager.py` | Gestor de animaciones activas |
| `Equations.py` | Parser de ecuaciones de combate (HIT, AVOID, DAMAGE...) |
| `Counters.py` | Contadores de combate |

#### UNIDADES Y DATOS
| Archivo | Función |
|---|---|
| `UnitObject.py` | Clase principal Unit — stats, inventory, status effects |
| `StatObject.py` | Sistema de estadísticas |
| `ClassData.py` | Datos de clases (parser de class_info.xml) |
| `Weapons.py` | Sistema de armas y weapon triangle |
| `ItemMethods.py` | Métodos de items — efectos, usos, condiciones |
| `StatusCatalog.py` | Sistema de habilidades/estados por componentes |
| `ActiveSkill.py` | Habilidades activas con carga (combat arts, activated skills) |
| `Aura.py` | Sistema de auras (skills de zona) |
| `Support.py` | Sistema de supports entre unidades |

#### MAPA Y MOVIMIENTO
| Archivo | Función |
|---|---|
| `Grid.py` (implícito en TileObject) | Grid del mapa |
| `TileObject.py` | Tiles del mapa — terreno, eventos tile |
| `AStar.py` | Pathfinding A* |
| `fast_pathfinding.pyx` | Pathfinding optimizado en C (Cython) |
| `manhattan_sphere.pyx` | Cálculo de rango en forma de diamante en C |
| `LOS.pyx` | Line of Sight en C |
| `Boundary.py` | Gestión de límites del mapa |
| `Highlight.py` | Resaltado de celdas (movimiento, ataque, etc.) |
| `Minimap.py` | Minimapa |

#### IA
| Archivo | Función |
|---|---|
| `AI_fsm.py` | Sistema de IA completo con FSM propia |
| `Objective.py` | Objetivos del mapa (Seize, Escape, Kill Boss...) |

#### UI Y MENUS
| Archivo | Función |
|---|---|
| `Cursor.py` | Cursor del mapa |
| `UnitMenu.py` | Menú de acciones de unidad |
| `InfoMenu.py` | Pantalla de información de unidad |
| `HelpMenu.py` | Tooltips de ayuda |
| `MenuFunctions.py` | Funciones comunes de menú |
| `GUIObjects.py` | Widgets de UI reutilizables |
| `HealthBar.py` | Barra de vida (mapa y combate) |
| `UnitPortrait.py` | Retratos animados (parpadeo, boca) |
| `UnitSprite.py` | Map sprites de unidades |
| `GenericMapSprite.py` | Map sprites genéricos |
| `BaseMenuSurf.py` | Base del sistema de menús |
| `Banner.py` | Banners de fase (Player/Enemy/Other Turn) |
| `Background.py` | Fondos y panoramas |

#### SISTEMAS ESPECIALES
| Archivo | Función |
|---|---|
| `Dialogue.py` | Sistema completo de diálogos/scripting |
| `WorldMap.py` | Mapa del mundo (overworld) |
| `Overworld.py` | Estado de overworld |
| `PrepBase.py` | Menú de preparación (Base menu estilo Tellius) |
| `LevelUp.py` | Pantalla de subida de nivel |
| `Promotion.py` | Sistema de promoción de clases |
| `Turnwheel.py` | Sistema de Turnwheel (rewind) |
| `Weather.py` | Sistema de clima visual |
| `bmpfont.py` | Sistema de fuentes bitmap |
| `TextChunk.py` | Renderizado de texto |
| `Image_Modification.py` | Modificación de imágenes en runtime (tintado de paletas) |
| `Triggers.py` | Sistema de triggers de eventos |
| `Commands.py` | Comandos de scripting de eventos |
| `CustomObjects.py` | Objetos custom del juego |
| `imagesDict.py` | Diccionario global de imágenes cargadas |

---

## 3. SISTEMA DE DATOS (Formato de archivos)

### Archivos de datos raíz por proyecto

```
Data/ (o DataSacredStones/)
├── class_info.xml          ← Definición de todas las clases
├── units.xml               ← Catálogo de personajes
├── items.xml               ← Catálogo de armas/items (122 items)
├── status.xml              ← Skills, estados, habilidades (1610 líneas)
├── terrain.xml             ← Tipos de terreno
├── affinity.txt            ← Afinidades (8 tipos)
├── ai_presets.txt          ← Presets de IA nombrados
├── weapon_triangle.txt     ← Triángulo de armas
├── weapon_advantage.txt    ← Bonificaciones por ventaja
├── weapon_exp.txt          ← Experiencia de armas
├── equations.txt           ← Fórmulas de combate configurables
├── mcost.txt               ← Costes de movimiento por terreno y grupo
├── support_nodes.txt       ← Afinidades de personajes
├── support_edges.txt       ← Pares de soporte y umbrales de puntos
├── portrait_coords.xml     ← Coordenadas de boca/ojos para animación
├── constants.ini           ← Constantes del juego (max_items, exp_curve, etc.)
├── config.ini              ← Configuración de pantalla/audio
├── words.txt               ← Vocabulario del juego
├── lore.xml                ← Lore/enciclopedia
├── difficulty_modes.xml    ← Modos de dificultad
├── credits.txt             ← Créditos
└── overworld_data.txt      ← Datos del overworld (DataSacredStones)
```

### Estructura de un nivel (Data/LevelN/)

```
LevelN/
├── Map.tmx                 ← Mapa en formato Tiled
├── MapSprite.png           ← Imagen visual del mapa
├── TileData.png            ← Mapa de tipos de terreno (píxel = tile)
├── TileSet.png             ← Tileset gráfico
├── UnitLevel.txt           ← Unidades del nivel y posiciones
├── overview.txt            ← Metadata del nivel (nombre, música, condiciones)
├── tileInfo.txt            ← Tiles especiales (escape, chest, door, etc.)
├── introScript.txt         ← Script cinemático de introducción
├── outroScript.txt         ← Script cinemático de final
├── interactScript.txt      ← Script de interacciones
├── attackScript.txt        ← Triggers de combate
├── fightScript.txt         ← Script de peleas cinemáticas
├── moveScript.txt          ← Triggers de movimiento
├── menuScript.txt          ← Scripts de menú/base
└── turnChangeScript.txt    ← Scripts de cambio de turno
```

### Formato overview.txt (metadata del nivel)
```
name;Prologue
prep_flag;0           ← ¿Tiene pantalla de prep?
pick_flag;0           ← ¿Permite selección de unidades?
base_flag;0           ← ¿Tiene menú de base?
market_flag;0         ← ¿Tiene mercado en base?
display_name;Escape!
win_condition;Escape the monastery
loss_condition;Ophie dies,OR,Prim dies
player_phase_music;Flight over Venice
enemy_phase_music;Brave Story 12
other_phase_music;Brave Story 12
weather;Light
```

### Formato UnitLevel.txt (spawn de unidades)
```
# Unidad guardada del roster del jugador
player;0;[event_id];[unit_id];[x,y];[ai_preset]

# Unidad nueva (no está en units.xml)
team;0;[event_id];[class];[level];[items];[x,y];[ai];[faction]

# Unidad creada genérica
team;2;[event_id];[class];[items];[x,y];[ai];[faction]
```

---

## 4. SISTEMA DE CLASES (class_info.xml)

### Estructura de una clase
```xml
<class id="Myrmidon">
    <short_name>Myrm.</short_name>
    <long_name>Myrmidon</long_name>
    <tier>1</tier>
    <wexp_gain>1,0,0,0,0,0,0</wexp_gain>  <!-- Sword,Lance,Axe,Bow,Light,Anima,Dark -->
    <promotes_from></promotes_from>
    <turns_into>Swordmaster</turns_into>
    <movement_group>0</movement_group>      <!-- 0=Light Foot, 1=Armored, 2=Heavy Cav... -->
    <tags></tags>
    <skills>1,Riposte;5,Vantage;8,Feat</skills>  <!-- nivel,habilidad -->
    <growths>95,45,35,65,60,60,20,35</growths>   <!-- HP,STR,MAG,SKL,SPD,LCK,DEF,RES -->
    <bases>11,3,1,6,7,0,1,1,5,5</bases>          <!-- HP,STR,MAG,SKL,SPD,LCK,DEF,RES,CON,MOV -->
    <max>40,15,15,15,15,20,15,15,20</max>
    <desc>...</desc>
</class>
```

### Grupos de movimiento (mcost.txt)
```
0 = Light Foot     (Infantería ágil)
1 = Armors         (Armadura pesada)
2 = Heavy Cav      (Caballería pesada)
3 = Light Cav      (Caballería ligera)
4 = Regular        (Estándar)
5 = Mages          (Magos)
6 = Fliers         (Voladores)
7 = Fleet          (Pies ligeros)
8 = Water          (Anfibio)
```

### Clases incluidas (Lion Throne)
Myrmidon, Swordmaster, Mercenary, Vanguard, Thief, Assassin, Fighter, Warrior, Brigand, Berserker, Knight, General, Cavalier, Paladin, Archer, Sniper, Cleric, Bishop, Mage, Sage, Shaman, Warlock, Lord, Halberdier, Soldier, Journeyman, Skirmisher, Tactician, Strategist, Dragoon, Dracoknight, Dracolord, Duke, Raider, Manakete, Sentinel

---

## 5. SISTEMA DE HABILIDADES/STATUS (status.xml)

### Arquitectura de componentes
El sistema usa composición pura. Cada skill/status es una combinación de componentes:

#### Componentes de efecto estadístico
| Componente | Efecto |
|---|---|
| `stat_change` | Modifica stats (HP,STR,MAG,SKL,SPD,LCK,DEF,RES,CON,MOV) |
| `upkeep_stat_change` | Cambia stats cada turno (degenerativo) |
| `stat_halve` | Divide stats a la mitad |
| `hp_percentage` | Regenera/daña X% HP por turno |
| `upkeep_damage` | Daño fijo cada turno |

#### Componentes de combate
| Componente | Efecto |
|---|---|
| `hit` / `conditional_hit` | Bonus/penalización a precisión |
| `mt` / `conditional_mt` | Bonus de daño |
| `crit` | Bonus de crítico |
| `avoid` / `conditional_avoid` | Bonus de esquiva |
| `attackspeed` | Modificador de velocidad de ataque |
| `attack_proc` / `defense_proc` | Procs de combate (probabilísticos) |
| `adept_proc` | Proc de doble ataque |
| `vantage` | Contraataca primero |
| `distant_counter` | Contraataca a rango |
| `nihil` | Niega procs del enemigo |
| `miracle` | Sobrevive con 1 HP |
| `def_double` | Puede doblar en defensa |
| `deflect_damage` | Absorbe daño |
| `resist_multiplier` | Multiplica resistencia al daño |

#### Componentes de movimiento/posición
| Componente | Efecto |
|---|---|
| `canto` | Puede moverse después de acción |
| `canto_plus` | Movimiento total después de acción |
| `pass_through` | Atraviesa unidades enemigas |
| `fleet_of_foot` | Usa columna de movimiento especial |
| `flying` | Unidad voladora |
| `grounded` | No puede ser rescatada |
| `affects_movement` | Afecta el cálculo de movimiento |

#### Componentes de ítems/skills activas
| Componente | Efecto |
|---|---|
| `activated_item` | Skill activa que usa un item |
| `combat_art` | Arte de combate con carga |
| `automatic_combat_art` | Arte de combate automático |
| `charge` | Sistema de carga para activación |
| `count` | Contador de usos |
| `aura` | Emite efecto en área |
| `aura_child` | Recibe efecto de aura cercana |

#### Componentes de duración/persistencia
| Componente | Efecto |
|---|---|
| `time` | Duración en turnos |
| `momentary` | Solo un instante |
| `lost_on_attack` | Se pierde al atacar |
| `lost_on_interact` | Se pierde al interactuar |
| `lost_on_endstep` | Se pierde al final del paso |
| `lost_on_endchapter` | Se pierde al final del capítulo |
| `class_skill` | Skill de clase (permanente) |

#### Componentes de estado/control
| Componente | Efecto |
|---|---|
| `no_weapons` | No puede usar armas |
| `no_magic_weapons` | No puede usar magia |
| `un_selectable` | No puede ser seleccionado |
| `immune` | Inmune a ciertos efectos |
| `negative` | Estado negativo (UI indicator) |
| `hidden` | No visible en UI |
| `ephemeral` | La unidad desaparece al expirar |

#### Componentes especiales
| Componente | Efecto |
|---|---|
| `locktouch` | Puede abrir cerraduras |
| `steal` | Puede robar items |
| `savior` | Puede rescatar sin penalización de stats |
| `refresh` | Puede reiniciar acción de unidad aliada |
| `live_to_serve` | Cura al curar |
| `caretaker` | Modificador especial de cura |
| `gain_status_after_kill` | Gana status al matar |
| `gain_status_after_attack` | Gana status al atacar |
| `mind_control` | Control de unidades enemigas |
| `reflect` | Refleja estados negativos |
| `tether` | Liga unidades entre sí |
| `unit_tint` | Tinte visual de la unidad |
| `unit_translucent` | Unidad semi-transparente |
| `exp_multiplier` | Multiplica experiencia ganada |
| `shrug_off` | Ignora estados negativos |
| `buy_value_mod` | Modifica precio de compra |

---

## 6. SISTEMA DE ÍTEMS (items.xml)

### Estructura de un ítem
```xml
<item name="Iron Sword">
    <id>Iron Sword</id>
    <spritetype>Sword</spritetype>
    <spriteid>0</spriteid>
    <components>weapon,uses,weight</components>
    <weapontype>Sword</weapontype>
    <uses>45</uses>
    <value>10</value>
    <RNG>1</RNG>          <!-- Puede ser "1-2" para rango variable -->
    <weight>3</weight>
    <MT>3</MT>
    <HIT>90</HIT>
    <LVL>D</LVL>          <!-- Rango de arma: D,C,B,A,S -->
</item>
```

### Todos los componentes de ítems
**Armas:** `weapon`, `spell`, `magic`, `magic_at_range`, `brave`, `reverse`, `cannot_be_countered`, `ignore_weapon_advantage`, `aoe`, `alternate_defense`

**Consumibles:** `usable`, `uses`, `c_uses`, `heal`, `damage`, `booster`, `exp`, `status`, `movement`, `self_movement`, `permanent_stat_increase`, `promotion`, `repair`

**Especiales:** `key`, `unlock`, `summon`, `transform`, `call_item_script`, `activated_item`

**Modificadores:** `weight`, `hit`, `crit`, `effective`, `half_on_miss`, `combat_effect`, `other_anim`, `aoe_anim`, `map_hit_color`, `sfx_on_cast`, `sfx_on_hit`, `status_on_equip`, `status_on_hold`

**Control:** `locked`, `unrepairable`, `no_ai`, `extra_select`, `target_restrict`, `custom_ai`, `custom_ai_value`, `warning`, `half_lifelink`, `wexp`, `item_mod`, `beneficial`, `detrimental`, `ai_speed_up`

### Tipos de armas y triángulo
```
Sword   → vence a Axe       → pierde con Lance
Lance   → vence a Sword     → pierde con Axe
Axe     → vence a Lance     → pierde con Sword
Bow     → sin triángulo físico
Light   → vence a Dark      → pierde con Anima  (M = magic triangle)
Anima   → vence a Light     → pierde con Dark
Dark    → vence a Anima     → pierde con Light
```

---

## 7. SISTEMA DE ANIMACIONES

### Tres archivos por animación
```
{Clase}{variante}-{TipoArma}-{Personaje}.png    ← Spritesheet
{Clase}{variante}-{TipoArma}-Index.txt          ← Mapa de frames
{Clase}{variante}-{TipoArma}-Script.txt         ← Lógica de animación
```

### Formato Index.txt
```
NombreFrame ; X,Y_en_PNG ; Ancho,Alto ; OffsetX,OffsetY_pantalla
Lance_007   ; 425,37     ; 58,56      ; 88,48
```

### Formato Script.txt — Comandos
```
pose;[Attack|Dodge|Critical|Miss|Stand]    ← Define el inicio de una pose
f;[duración_ticks];[frame_id]              ← Muestra frame durante N ticks
f;[dur];[frame_id];[frame_under_id]       ← Frame con capa inferior

sound;[nombre_sonido]                      ← Reproduce SFX
platform_shake                             ← Sacude la plataforma
enemy_flash_white;[ticks]                  ← Destello blanco al enemigo
screen_flash_white;[ticks]                 ← Flash de pantalla
foreground_blend;[dur];[R,G,B]            ← Mezcla de fondo (críticos)
start_hit                                  ← Marca momento del golpe
wait_for_hit;[frame];[frame_under]        ← Sincroniza con impacto
hit_spark                                  ← Chispa de impacto
crit_spark                                 ← Chispa de crítico
miss                                       ← Marca fallo
blend                                      ← Mezcla alpha (efectos)
wait;[ticks]                              ← Espera sin frame
```

### Poses definidas
- **Stand** — idle en mapa de combate
- **Attack** — ataque normal
- **Critical** — animación de crítico (más elaborada)
- **Miss** — ataque fallado
- **Dodge** — esquiva recibida

### Variantes de personaje
- `GenericBlue` — genérico aliado
- `GenericRed` — genérico enemigo
- `GenericGreen` — genérico neutral
- `[NombrePersonaje]` — sprite personalizado para personaje named

### Efectos de spell (diferente a animaciones de unidad)
Los spells tienen su propio Image + Script + Index y se reproducen como overlay sobre el combate. El script usa `blend` para transparencia y no tiene poses, solo una secuencia lineal de frames.

---

## 8. SISTEMA DE COMBATE (Solver.py)

### Máquina de estados del combate
```
PreInit → Init → [Attacker / Defender] → Done
                      ↓ (brave)
              AttackerBrave / DefenderBrave
                      ↓ (splash)
                Splash / SplashBrave
                      ↓ (summon)
                    Summon
```

### Objeto Result (por cada intercambio)
```python
result.outcome        # 0=Miss, 1=Hit, 2=Crit
result.atk_damage     # Daño al atacante
result.def_damage     # Daño al defensor
result.atk_status     # Estados aplicados al atacante
result.def_status     # Estados aplicados al defensor
result.attacker_proc_used   # Proc skill del atacante
result.defender_proc_used   # Proc skill del defensor
result.adept_proc     # Proc de doble ataque
result.new_round      # ¿Es inicio de nueva ronda?
```

### Lógica de doble ataque
```python
# El atacante dobla si outspeed al defensor
# outspeed = AS_atacante >= AS_defensor + 4 (configurable)
# AS = SPD - max(0, WEIGHT - CON)
```

### Fórmulas configurables (equations.txt)
```
AS    = SPD - max(0, WEIGHT - CON)
HIT   = SKL*3 + LCK
AVOID = AS*3 + LCK
CRIT  = SKL
CRIT_AVOID = LCK*2
DAMAGE = STR
DEFENSE = DEF
MAGIC_DAMAGE = MAG
MAGIC_DEFENSE = RES
RATING = (HP-10)//2 + max(STR,MAG) + SKL + SPD + LCK//2 + DEF + RES
RESCUE_AID = max(0,15-CON) if Mounted else max(0,CON-1)
STEAL_ATK = SPD
HEAL = MAG
MAX_FATIGUE = HP
```

---

## 9. SISTEMA DE IA (AI_fsm.py)

### AI State 1 (acción)
```
1   = Move
2   = Attack
4   = Steal
8   = Attack Tiles (villages)
16  = Destructible Tiles
32  = Unlock (chests/doors)
64  = Thief Escape tiles
128 = Regular Escape tiles
256 = Enemy Seize tiles
→ Se pueden combinar con suma (e.g. 3 = Move+Attack)
```

### AI State 2 (movimiento)
```
0  = No moverse
1  = Hacia enemigos
2  = Hacia aliados
3  = Hacia objetos saqueables o HP tiles
4  = Hacia cofres/puertas sin abrir
5  = Hacia tiles de escape
6  = Hacia tiles de escape de ladrón
7  = Hacia unidad boss
8  = Hacia tiles de seize enemigo
9  = Hacia cualquier unidad
10 = Hacia objetos sin HP
11 = Hacia tiles con HP
String = Hacia unidad con ese nombre/event_id
```

### Presets de IA
```
None / DoNothing     → 0,0 — No hace nada
Attack               → 3,1 — Ataca y persigue
Pursue               → 3,1 con view_range=2 — Persigue en todo el mapa
SoftGuard            → 3,0 — Ataca si en rango, no se mueve
HardGuard            → 2,0 — Solo ataca, no se mueve
Unlock               → 37,4 — Abre puertas y persigue
Escape               → 129,5 — Escapa
ThiefEscape          → 65,6 — Ladrón que escapa
Dancer               → 3,2 — Soporte aliado
Berserk              → 3,9 — Ataca todo (incluidos aliados)
```

---

## 10. SISTEMA DE DIÁLOGOS/SCRIPTING

### Comandos del script de eventos (introScript, etc.)
```
gold;[cantidad];[flag]          ← Da oro (no_banner para silencioso)
m;[nombre_mapa]                 ← Muestra nombre del mapa
add_unit;[event_id]            ← Añade unidad al campo
t;[turno]                      ← Cambia turno
set_camera_pan;[0/1]           ← Activa/desactiva pan de cámara
set_cursor;[event_id]          ← Mueve cursor a unidad
disp_cursor;[0/1]              ← Muestra/oculta cursor
wait;[ms]                      ← Espera
u;[portrait_id];[posición]     ← Muestra retrato (FarLeft/MidLeft/Left/Right/MidRight/FarRight)
r;[portrait_ids...]            ← Retira retrato(s)
s;[portrait_id];[texto];auto   ← Diálogo (auto = avance automático)
move_unit;[event_id];[x,y]    ← Mueve unidad a posición
start_move                     ← Ejecuta movimientos pendientes
interact_unit;[id];[x,y];[tipo] ← Interacción scripted (Hit, etc.)
qmove_sprite;[id];[x,y]       ← Mover sprite sin animación
set_game_constant;[key]        ← Activa constante de juego
```

---

## 11. SISTEMA DE SOPORTE

### support_nodes.txt — Afinidades
```
[unit_id];[affinity]
Ophie;Fire
Prim;Water
```

### support_edges.txt — Pares de soporte
```
[unit1];[unit2];[puntos_nivel1];[puntos_nivel2];[puntos_nivel3]
Joel;Ophie;6;10;10
```

### Cálculo de soporte
- Puntos se ganan en combate cercano, fin de turno en rango, conversaciones
- Los niveles (C, B, A, S) desbloquean conversaciones y bonus de stats
- Los bonus dependen de la afinidad usando support_bonus mode

---

## 12. CONSTANTES CONFIGURABLES (constants.ini)

```ini
max_items=5                    ← Items por unidad
max_stat=20                    ← Stat máximo no-HP
crit=0                         ← Modo de críticos (0-3)
turnwheel=1                    ← Sistema de rewind
overworld=0                    ← Mapa del mundo
fatigue=0                      ← Sistema de fatiga
exp_curve=0.22                 ← Curvatura de la curva de EXP
exp_magnitude=11.7             ← Magnitud de EXP ganada
kill_multiplier=2.5            ← Multiplicador de EXP por kill
line_of_sight=1                ← Line of sight para armas
spell_line_of_sight=0          ← Line of sight para spells
def_double=0                   ← El defensor puede doblar
max_level=0,10,10              ← Max nivel por tier
promoted_level=9               ← Nivel por defecto al promover
auto_promote=1                 ← Promoción automática al max level
enemy_leveling=3               ← Modo de subida de nivel enemiga
num_skills=5                   ← Skills de clase por unidad
convoy_on_death=1              ← Items al convoy al morir
fatal_wexp=0                   ← Wexp doble en kills
double_wexp=0                  ← Wexp por cada golpe
miss_wexp=1                    ← Wexp aunque falle
steal=1                        ← Sistema de robo
save_slots=3                   ← Slots de guardado
support=2                      ← Modo de soporte (0/1/2)
support_bonus=2                ← Cálculo de bonus de soporte
```

---

## 13. PLAN DE IMPLEMENTACIÓN EN GODOT

### Prioridad 1 — Parser de datos (importador)

El importador de proyectos LT en Godot necesita:

1. **Parser XML** para: `class_info.xml`, `units.xml`, `items.xml`, `status.xml`, `terrain.xml`, `portrait_coords.xml`
2. **Parser de texto** para: `equations.txt`, `mcost.txt`, `weapon_triangle.txt`, `weapon_advantage.txt`, `affinity.txt`, `support_nodes.txt`, `support_edges.txt`, `constants.ini`, `ai_presets.txt`
3. **Parser de nivel** para: `overview.txt`, `UnitLevel.txt`, `tileInfo.txt`
4. **Parser de scripts** para: `introScript.txt`, `outroScript.txt`, y todos los `*Script.txt`
5. **Parser de animaciones** para: `Index.txt`, `Script.txt` + carga de spritesheets

### Prioridad 2 — Sistemas de Godot equivalentes

| Sistema LT | Equivalente Godot |
|---|---|
| Solver SolverStateMachine | Clase `CombatSolver` con enum de estados |
| StatusCatalog componentes | Sistema de componentes con Resources |
| AI_fsm | Árbol de comportamiento o FSM propia |
| AnimationManager + BattleAnimation | AnimationPlayer + sistema de parser de scripts |
| Dialogue/Commands | Autoload con cola de comandos |
| equations.txt parser | Expression evaluator de Godot |
| Static random | Clase `LTRandom` con seed determinístico |
| Action (reversible) | Command Pattern para Turnwheel |
| AStar + manhattansphere | Godot AStar2D + función custom de rango |

### Prioridad 3 — Assets

Los assets de LT son directamente usables en Godot:
- PNGs → `Image` / `Texture2D` nativo
- Index.txt → `AtlasTexture` con región y margen
- Mapas TMX → Plugin de Tiled para Godot (TileMap)
- Fuentes bitmap (.idx + .png) → `BitmapFont`

### Estructura de Resources sugerida para Godot
```
LTProject (Resource)
├── classes: Dictionary[String, ClassData]
├── units: Dictionary[String, UnitData]
├── items: Dictionary[String, ItemData]
├── statuses: Dictionary[String, StatusData]
├── terrain: Dictionary[String, TerrainData]
├── equations: EquationSet
├── constants: GameConstants
└── levels: Array[LevelData]

LevelData (Resource)
├── name, display_name, music
├── units: Array[UnitSpawnData]
├── tiles: Array[TileEventData]
├── scripts: Dictionary[String, Array[ScriptCommand]]
└── map_path: String
```

---

## 14. NOTAS PARA FE4/FE5

Lex Talionis está diseñado principalmente para FE GBA/Tellius. Para adaptar a FE4/FE5 usando el importador necesitarás:

- **FE4**: Añadir sistema de Gold heredado, capítulos gigantes, Holy Blood (como un tipo especial de status), sistema de amor (variante de soporte), Castillos (como PrepBase extendido)
- **FE5**: Añadir Fatiga (ya soportada via `fatigue=1`), sistema de captura (variante de robo), FatP, Scrolls (booster especial), sistema de rescate (ya existe `savior`)
- **Comunes**: Weapon rank S existente, triángulo de magia ya implementado, afinidades ya implementadas

Las ecuaciones de FE4/FE5 son diferentes — el archivo `equations.txt` permite reconfigurarlas completamente sin tocar código.
