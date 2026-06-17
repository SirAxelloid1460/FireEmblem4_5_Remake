# Port Plan — Lex Talionis → Godot 4
## Hoja de ruta completa por fases

---

## ESTADO ACTUAL — Sistemas ya implementados

### Código funcional:
- `CombatSystem.gd` — fórmulas completas, todas las skills, terrain, captura
- `CaptureSystem.gd` — sistema captura FE5 completo
- `Unit.gd` — clase base con skills, status, carrying, tier
- `Items.gd` — base de datos items + ItemSystem
- `LTImporter.gd` — importador dual JSON/XML de proyectos LT
- `LTDataResources.gd` + `LTDatabase.gd` — estructuras de datos
- `Grid.gd`, `Pathfinding.gd` — grid y pathfinding
- `GameManager.gd` — gestor principal (parcial)
- `WorldMap.gd` — mapa del mundo
- `CastleBase.gd`, `CastleFacilities.gd`, `ShopPanel.gd` — sistema de castillo
- `ArenaPanel.gd`, `ArenaPanel_FE4.gd`, `ArenaEventManager.gd` — arena FE4
- `LevelUpScreen.gd`, `PromotionScreen.gd` — subida de nivel y promoción
- `CinematicScene.gd`, `CinematicTransitions.gd`, `DialogueBox.gd` — cinemáticas
- `MainMenu.gd`, `OptionsMenu.gd` — menús

### Documentación:
- `GameDesign_MechanicsDoc.md` — documento maestro de diseño
- `PendingMechanics_Review.md` — lista de pendientes
- `Format_Differences.md` — diferencias técnicas resueltas

---

## FASE 1 — Completar sistemas de juego pendientes

**Objetivo:** Todos los sistemas de mecánicas jugables implementados.
**Referencia principal:** `PendingMechanics_Review.md`

### 1.1 — Terrain system
- `TerrainSystem.gd` — DEF/AVO/regeneración por terreno
- Conectar con `CombatSystem` (ya recibe terrain_atk/terrain_def)
- Fort/Gate/Throne regeneran HP al inicio del turno
- El `GameManager` pasa los valores de terrain antes de cada combate

### 1.2 — Fog of War system
- `FogOfWarSystem.gd` — visión por radio, actualización por turno
- Radio base: 3 tiles (FE5), Torch sube a 10 decreciente
- Voladores ven +1, Thieves/Rogues ven +1
- Solo activo en capítulos con `fow_enabled: true`
- Conectar con `TorchVision` status del ItemSystem

### 1.3 — Elite skill growth bonus
- Combatiente físico: +10% STR, SPD, SKL, DEF
- Combatiente mágico: +10% MAG, RES, SKL, SPD
- Se aplica al calcular los growths en `LevelUpScreen.gd`
- Verificar si la unidad tiene Elite en el momento de subir nivel

### 1.4 — NotHoly weapon rank cap
- Unidades sin sangre sagrada: techo en rango A (no pueden llegar a Holy/S)
- Minor Blood: progresión normal hasta A, luego más rápido hacia Holy
- Major Blood: desbloquea Holy directamente desde el inicio
- Implementar en el sistema de weapon XP de `Unit.gd`

### 1.5 — Devil weapons
- Al atacar con un Devil weapon: X% de redirigir el daño al usuario
- El % puede ser fijo (30%) o basado en stats
- Implementar como componente en el ItemSystem

### 1.6 — Substitute characters (gen 2 FE4)
- Si una madre potencial muere o no se casa antes del cap 5 → aparece sustituto
- Añadir los personajes sustitutos al roster con sus stats
- Lógica de trigger en el `GameManager` al inicio de la gen 2

### 1.7 — Ballista en mapa
- Clase Tier 0, MOV=0, solo Bow C, Enemy Only
- Unidad fija en el mapa (no se mueve nunca)
- Puede atacar a rango largo (según stats del arma)
- Tratable como unidad normal con MOV=0

### 1.8 — Convoy / item exchange
- Intercambio libre entre unidades adyacentes (GBA style)
- Acceso al convoy compartido desde prep screen y castillo
- `ConvoySystem.gd`

### 1.9 — Refresh (Dancer)
- Acción de mapa: el Dancer refresca a TODAS las unidades adyacentes ya movidas
- Distinto de GBA (que refresca solo una)
- Implementar como acción especial en el menú de acción de mapa

### 1.10 — Steal (acción de mapa)
- Acción de mapa disponible a unidades con skill Steal o Thief Ring
- Condición: SPD del ladrón > SPD del objetivo
- Solo roba items NO equipados
- Muestra lista de items robables del inventario enemigo

---

## FASE 2 — Level Loader (LT → Godot)

**Objetivo:** Cargar capítulos del proyecto LT directamente en Godot.
**Input:** `levels/*.json` de los proyectos FE4/FE5
**Output:** Mapa jugable con unidades, objetivos y eventos

### 2.1 — LevelLoader.gd
Leer `levels/N.json` de LT y construir:
- Mapa de tiles desde `map` data
- Colocar unidades (player + enemy + NPC) en sus posiciones
- Aplicar AI presets a unidades enemigas
- Cargar objetivo del capítulo (Seize, Rout, Escape, Survive)
- Cargar eventos de capítulo (reinforcements, triggers)

### 2.2 — Estructura de un capítulo LT (formato real):
```json
{
  "nid": "1",
  "name": "Chapter 1",
  "tilemap": "...",
  "objective": {"win": "Seize", "loss": "Lord dies"},
  "units": [...],
  "events": [...]
}
```

### 2.3 — TileMap connector
- Convertir el tilemap de LT a TileMap de Godot
- Mapear terrain nids de LT a tiles de Godot
- Asignar propiedades de terrain (DEF/AVO/MOV cost) por tile

### 2.4 — Objective system
- `ChapterObjective.gd`
- Tipos: Seize (capturar trono), Rout (eliminar todos), Escape (Leif llega al punto), Survive (aguantar N turnos)
- Condiciones de derrota: Lord muere, N turnos sin cumplir objetivo

---

## FASE 3 — AI System

**Objetivo:** Portar el sistema de IA de LT a Godot.
**Referencia:** `app/engine/ai_controller.py` (en app.rar)

### 3.1 — AIController.gd
Portar el sistema de `behaviours` de LT:
```
Attack   → atacar al enemigo más cercano/débil según target_spec
Move     → moverse hacia el objetivo
Steal    → intentar robar
Escape   → moverse al borde del mapa
Guard    → quedarse quieto defendiendo posición
```

### 3.2 — AI priorities
- Cada unidad enemiga tiene un preset de AI (Pursue, Guard, Heal, etc.)
- El AIController evalúa cada unidad en el turno enemigo
- Pathfinding ya implementado en `Pathfinding.gd`

### 3.3 — Reinforcements
- Trigger por turno o por evento (unidad muere, tile capturado)
- Nuevas unidades aparecen en puntos de spawn definidos en el capítulo

---

## FASE 4 — Contenido y pulido

**Objetivo:** Todos los capítulos de LT funcionando en Godot.

### 4.1 — Importar capítulos FE4 (caps 0–3 implementados en LT)
Con el LevelLoader funcionando, cargar los capítulos del proyecto GotHW automáticamente.

### 4.2 — Importar capítulos FE5
Cargar los capítulos del proyecto Thracia776.

### 4.3 — Diálogos y eventos
- Portar el sistema de eventos de LT a Godot
- Conectar con `DialogueBox.gd` y `CinematicScene.gd` ya implementados
- Triggers de conversación por proximidad, captura de castillo, etc.

### 4.4 — Support/Love system
- Sistema de Love FE4: valores base + modificador por turno + adyacencia
- Sistema de Support GBA: rangos C/B/A/S con bonus de combate
- Conversaciones de soporte integradas con DialogueBox

### 4.5 — Sound y música
- Conectar BGM de capítulos
- SFX de combate

---

## NOTAS PARA EL PRÓXIMO CHAT

### Archivos que hay que subir al inicio:
- `app.rar` — motor LT (necesario para Fase 2+)
- `game_data_fe4.rar` + `game_data_fe5.rar` — datos del proyecto
- Los .gd y .md generados en este chat (outputs)

### Prioridad inmediata (empezar por aquí):
1. `TerrainSystem.gd` — es el más urgente porque CombatSystem ya lo espera
2. `FogOfWarSystem.gd` — necesario para capítulos FE5
3. Elite growth bonus en `LevelUpScreen.gd`
4. NotHoly weapon rank cap en `Unit.gd`

### Decisiones aún pendientes del PendingMechanics_Review.md:
- Fog of War: ¿rango base 3 tiles (FE5) o configurable por capítulo?
- Convoy: ¿accesible solo en castillo o también en prep screen?
- Substitutes gen 2: ¿stats fijos o calculados según madre faltante?
- Ballista: ¿puede ser capturada? ¿da EXP al destruirla?
