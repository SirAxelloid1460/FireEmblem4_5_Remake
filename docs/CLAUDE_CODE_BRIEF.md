# Brief de Arranque — Remake FE4 + FE5 en Godot 4

> Documento de contexto para Claude Code. Lee esto **primero**, luego `PortPlan.md` y `GameDesign_MechanicsDoc.md`.

---

## 1. Qué es este proyecto

Remake fan híbrido de **Fire Emblem 4 (Genealogy of the Holy War)** y **Fire Emblem 5 (Thracia 776)**, hecho en **Godot 4 / GDScript**. Es un port desde el motor **LT-maker (Lex Talionis)** de rainlash, originalmente en Python/Pygame.

Meta: remake fiel que preserva mecánicas de ambos títulos, usando los datos reales de los proyectos LT como fuente canónica.

**Idioma de trabajo:** español (docs y comunicación); código y nombres de archivo en inglés.

---

## 2. Fuentes de verdad (ground truth)

Estos recursos NO están en el zip — se suben aparte al iniciar el trabajo de Fase 2+:

- **`app.rar`** → motor LT-maker completo (Python). Es la **referencia autoritativa** del comportamiento del engine. Montar en `/tmp/app/`. Archivos clave:
  - `engine/combat_calcs.py` (fórmulas reales)
  - `engine/exp_calculator.py` (curva EXP exponencial)
  - `engine/combat/solver.py`
  - `engine/skill_system.py`, `engine/item_system.py`
  - `engine/skill_components/`, `engine/item_components/`
- **Proyecto LT FE4 (GotHW)** → montar en `/tmp/fe4/`
- **Proyecto LT FE5 (Thracia776)** → montar en `/tmp/fe5/`
- **Spreadsheet "Genealogy + Thracia Data"** → datos de unidades/clases/items

**Formato de datos LT:** JSON exclusivamente (no XML/legacy). Capítulos en `levels/N.json`.

**Regla de oro:** antes de implementar cualquier fórmula, cruzar con `combat_calcs.py` / `exp_calculator.py` / `solver.py`. No inventar fórmulas independientes.

---

## 3. Convenciones (LOCKED — no cambiar)

- Scripts: `res://Scripts/` · Escenas: `res://Scenes/` (S mayúscula en ambos)
- Datos compartidos unificados en `res://data/general/` (units, classes, items, terrain, skills, AI presets, holy blood, supports). Las carpetas por juego solo contienen levels, events y tilemaps.
- **Godot 4 prohíbe múltiples `class_name` por archivo** → cada clase en su propio `.gd`.
- Stats internos en `float` (movement, costos de terreno: road 0.7, plain 1.0). La **UI siempre muestra `int`** con `%d` / `int()` — nunca floats al jugador.
- Género de unidad: `@export_enum("M", "F", "U")` (U = Universal para enemigos genéricos).
- Naming de animación de combate: `{NID}_{Variant}_{Weapon}` con underscores; la distancia (Lance/Javelin, Axe/HandAxe) se resuelve en código, no en el nombre.
- Tooling Python va en `tools/` en la raíz; archivos generados a `/mnt/user-data/outputs/`.
- Gold: pool global GBA-style `party_gold`. El modelo de oro individual de FE4 está **abandonado**.

---

## 4. Mecánicas implementadas y bloqueadas

**Leveling/growth:** `gain_experience()`, `level_up()` con growths personales + clase + Holy Blood + Elite; stat caps por clase; cap nivel 30; promoción desde nivel 20; nivel resetea a 1 al promover.

**Weapon EXP & Holy Blood:** thresholds E→Holy★; almacenamiento Holy Blood con grados Major/Minor; skill NotHoly auto-aplicada en cap rango A sin Major Blood; `can_equip()`; Holy★ exclusivo de Major Blood.

**Combate:** AS = SPD − max(0, WT − CON) (MAG en armas mágicas); doblado simétrico con AS ≥ rival+4; multiplicador kill ×3.0; Wrath con HP ≤ 1/3; bonus Charisma +15; Pavise = ((DEF+LVL)/2)% físico / ((RES+LVL)/2)% mágico; daño efectivo = ceil(MightTotal × 2.5) + 5 con defensas a la mitad; terrain DEF/AVO integrado; bonus EXP de boss = 55.

**Rangos de arma:** S como máximo universal; Holy★ solo Major Blood.

**Skills:** Nihil (niega todos los procs) ≠ Awareness (niega solo crit/skills de espada/efectividad). Continue = Desperation (misma skill confirmado). **Pursuit es mecánica pasiva universal, no skill** → afecta diseño de anillos/items (Pursuit Ring reconvertido a VelocityRing, +5 SPD pasivo).

**Captura (solo caps FE5):** melee intenta capturar; BUILD suficiente → captura vivo con penalización de carga, loot libre, luego Release (rescate: tier×150 + nivel×25 oro) o Dispatch (matar, sin EXP). Bosses no capturables. BUILD insuficiente → loot+kill normal.

**FE4 Combination Crit Bonus:** +5 por amante/cónyuge y hermano adyacente.

**Otros bloqueados:** Fortune Teller (Augury fusionado), sistema multi-castillo intra-capítulo con recompensas one-shot, Hammerne, Fortress ownership API (`claim_fortress_on_step`), Fog of War Phase 1 (base 3 tiles, Thief +5→+8, voladores sin bonus, Torch +N decreciente −1/turno), Convoy solo en castillo, Substitutes (stats de madre/padre/clase inicial), Ballista capturable FE5-style.

**Clases/personajes:** Cavalier unifica SocialKnight de FE5; Mage usa sistema Anima/Light/Dark de FE5; línea Wyvern: DragonRider→DragonKnight→DragonMaster. Sigurd = LordKnight (Tier 2) directo; Seliph: Lord→LordKnight; Leif: Prince→MasterKnight. Paladin femenino: pierde Lance, gana Staff, growths mágicos. Lara: cadena única Thief↔Rogue↔Dancer con nivel compartido Rogue/Dancer.

---

## 5. Pendiente de implementar

- Devil weapons (% de redirigir daño al usuario)
- FoW: rangos de visión por unidad
- Detalles de implementación del Elite growth bonus
- Detalles de Convoy / item exchange
- Sistema de cálculo de stats de Substitutes (diseño locked, implementación pendiente)
- Edge cases restantes del LT importer

Prioridad inmediata sugerida (ver PortPlan §"NOTAS"): TerrainSystem → FogOfWarSystem → Elite growth en LevelUpScreen → NotHoly cap en Unit.

---

## 6. Mapa del código (~85 archivos)

**Core combate/unidad:** `CombatSystem.gd`, `Unit.gd`, `UnitSprite.gd`, `Weapon.gd`, `Item.gd`, `Items.gd`, `ItemDatabase.gd`, `CaptureSystem.gd`, `DevilWeaponSystem.gd`, `BallistaSystem.gd`

**Grid/movimiento/IA:** `Grid.gd`, `Pathfinding.gd`, `AIController.gd`, `MapActions.gd`, `TerrainSystem.gd`, `FogOfWarSystem.gd`

**Gestión:** `GameManager.gd` (autoload), `GameMode.gd`, `ChapterObjective.gd`, `WorldMap.gd`

**Datos/import LT:** `LTImporter.gd`, `LTDatabase.gd`, `LTDataResources.gd`, `LTProjectAdapter.gd`, `LevelLoader.gd`, `TilemapLoader.gd`

**Progresión:** `LevelUpScreen.gd`, `PromotionScreen.gd`, `LaraPromotion.gd`, `ClassVariants.gd`, `SubstituteSystem.gd`, `SupportSystem.gd`

**Castillo/tienda/arena:** `CastleBase.gd`, `CastleFacilities.gd`, `CastlePreparation.gd`, `CastleServices.gd`, `ShopMenu.gd`, `ShopPanel.gd`, `ConvoyMenu.gd`, `ConvoySystem.gd`, `ArenaMenu.gd`, `ArenaPanel.gd`, `ArenaPanel_FE4.gd`, `ArenaEventManager.gd`

**Animación/cinemática/UI:** `CombatAnim*.gd`, `CombatEffectDatabase.gd`, `CombatPaletteSystem.gd`, `CinematicScene.gd`, `CinematicTransitions.gd`, `CinematicExamples.gd`, `DialogueBox.gd`, `EventSystem.gd`, `MainMenu.gd`, `OptionsMenu.gd`, `CreditsScreen.gd`, `AnimatedTitleBackground.gd`, `MapBackground.gd`, `AssetLoader.gd`

**Escenas (.tscn):** `castle_base`, `cinematic_scene`, `level_promotion_screens`, `main_menu`, `options_menu`, `world_map`

**Docs (.md):** PortPlan, GameDesign_MechanicsDoc, PendingMechanics_Review, Format_Differences, FE_Mechanics_Comparison, FE_Mechanics_Uncovered, LexTalionis_Analysis, ProjectData_Analysis, Spreadsheet_Analysis, y READMEs por sistema (CASTLE, ARENA_FE4, CINEMATICS, AUTO_CINEMATICS, LEVEL_PROMOTION, MENU).

> Nota: el `README.md` raíz está **desactualizado** (describe un prototipo base inicial). El estado real es mucho más avanzado — usa PortPlan.md y los docs de mecánicas como referencia.

---

## 7. Estilo de trabajo del autor (Axel / SirAxelloid1460)

- Iterativo: las decisiones se bloquean en código **y** docs en la misma sesión.
- Correcciones a mitad de sesión cruzando datos LT contra docs de diseño.
- Confirmación incremental en trabajo batch grande; flaggear inconsistencias (capitalización, naming, duplicados) proactivamente.
- Spreadsheet + JSON de LT + `app.rar` son las referencias canónicas, en ese orden de detalle.
