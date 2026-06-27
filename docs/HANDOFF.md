# FE4/FE5 Remake — Guía de continuación (handoff)

> Punto de partida para la **próxima sesión**. Estado a fecha 2026‑06‑06.
> Idioma de trabajo: **español** (comunicación/docs), **inglés** (código).
> Motor: **Godot 4.6.3** (el proyecto declara feature "4.3" pero corre en 4.6.3).

---

## 0) TL;DR — dónde estamos
- **Migración LT → nativo COMPLETA y jugable.** Data nativa (JSON en `res://data/`) cargada por el autoload **`GameDB`**.
- **Arranque**: escena principal = **`intro.tscn`** → vídeo de intro → (corte sin fade) → **MainMenu** (título FE4 + tema de FE) → New Game → Prólogo FE4 jugable.
- **Fase gráfica avanzada**: mapa real renderizado, **map sprites de unidades con palette‑swap por equipo** (LUT), y **menú principal vestido estilo FE** (placas, espada‑cursor, fondo del ejército, logo, Press Start animado). Ver §7 (sesión 2026‑06‑06).
- **Sin git** → nunca dejar el proyecto roto. **Validación headless disponible** (ver §3) — el asistente puede compilar/chequear shaders sin el editor.

---

## 1) Cómo arrancar la próxima sesión
1. Abrir el proyecto en Godot 4.6.3 (1ª apertura reimporta assets, tarda).
2. Ejecutar (F5) → **Intro (vídeo, saltable con accept/clic) → corte → MainMenu**. Press Start → placas con espada‑cursor → New Game → Normal/Elite → Prólogo.
3. Escenas sueltas con **F6**: `Scenes/main_menu.tscn`, `intro.tscn`, `main_game.tscn` (Prólogo directo), `options_menu.tscn`, `language.tscn`.
4. Si algo falla, pegar el log; se arregla y se re‑valida (headless + en editor).

---

## 2) Arquitectura actual

### Autoloads (`project.godot` → `[autoload]`)
`AssetLoader · GameMode · Convoy(ConvoySystem) · GameDB(GameDatabase) · GameManager · FadeCanvas`

### Datos nativos (`res://data/`)
- `data/general/`: `classes.json`(64) `weapons.json`(134, incl. magia/báculos) `items.json`(79) `skills.json`(97) `units.json`(64) — generados de los `.ltproj` (componentes LT crudos conservados en `components`).
- `data/fe4|fe5/levels/`: capítulos **LT crudos** (Array[1]) + `_index.json`. **Real: FE4 = caps 0,1,2 jugables + placeholders (998/999/DEBUG); FE5 = cap 1**.
- `data/fe4|fe5/tables/`: `weapon_ranks/terrain/mcost/ai/equations/constants/stats/weapons.json` (verbatim).
- `data/fe4|fe5/tilemaps/`: terreno por mapa (slim) leído por `TilemapLoader`.

### `GameDB` (Scripts/GameDatabase.gd) — API clave
- Carga classes/weapons/skills/items/units (por **nid**), levels, terrains.
- `get_class_data(nid)` (¡NO `get_class`, choca con Object!), `get_weapon/get_skill/get_item/get_unit/get_level`.
- `build_project_data(game)` → arma el `project_data` que consumen `LevelLoader`/`AIController`/`EventSystem`.
- `get_tilemap(game,nid)` / `get_terrain` / `terrain_name`.

### Render / cámara
- `project.godot [display]`: viewport base **1344×896** = FOV **336×224 nativo (21×14 tiles)**; `stretch=canvas_items`, `aspect=keep` (3:2). Modelo: tile=64px (16 nativo ×4), zoom de cámara = 1, así que **viewport = FOV × 4**. Para cambiar el FOV se edita el viewport (no el zoom). Histórico: 960×640 = GBA (240×160), 1344×896 = elegido para PC.

### Runtime de juego
- `PrologueTest.gd` es el bootstrap de gameplay (lo usa `Scenes/main_game.tscn`): `GameDB.build_project_data("fe4")` + `GameDB.get_tilemap` + `GameManager.load_chapter(...)`.
- `LevelLoader.gd` y `TilemapLoader.gd` se **conservan** (guiados por formato, no por LT). `LevelLoader._instantiate_item` usa `Weapon.from_lt` sobre los `components`. `Weapon.from_data(WeaponData)` también disponible.
- `Unit.gd`: rangos de arma reales (D=1·C=51·B=126·A=226·Holy=1023) + skill `NotHoly` (tapa a no‑Major‑Blood en A). HP bar dibujada **debajo** de la unidad.
- `GameManager`: `_input` solo con clic IZQUIERDO y solo con batalla activa; el escenario de prueba solo corre si se ejecuta su escena directamente (F6).

### UI recreada desde cero (toda por código, patrón fiable sin editor)
| Escena/Comp | Archivos |
|---|---|
| MainMenu (FE: Press Start→columnas deslizantes→New Game Normal/Elite→Extras) | `Scripts/MainMenu.gd` + `Scenes/main_menu.tscn` |
| Language (selector de banderas → fija/guarda locale → Intro) | `Scripts/Language.gd` + `Scenes/language.tscn` |
| Intro (vídeo `eng/jap.ogv` por locale, saltable → MainMenu) | `Scripts/Intro.gd` + `Scenes/intro.tscn` |
| OptionsMenu/Settings (audio+gameplay, persiste `user://settings.cfg`) | `Scripts/OptionsMenu.gd` + `Scenes/options_menu.tscn` |
| CreditsScreen (scroll FE, grids/tabla) | `Scripts/CreditsScreen.gd` |
| FadeCanvas (autoload: transiciones + carga locale guardado) | `Scripts/FadeCanvas.gd` |
| LabelAnimText (texto máquina de escribir) | `Scripts/LabelAnimText.gd` + `Scenes/label_anim_text.tscn` |
| BattleHPBar (barra FE de blips, `set_hp`/`animate_to`) | `Scripts/BattleHPBar.gd` + `Scenes/battle_hp_bar.tscn` |
| FEButton (botón reutilizable; consolida MenuButton/ActionButton/DataButton/SettingsButton) | `Scripts/FEButton.gd` + `Scenes/fe_button.tscn` |

Flujo actual: **Intro → (corte SIN fade) → MainMenu** (escena principal = `intro.tscn`).
`Language` ya NO está en la cadena de arranque (el locale lo carga `FadeCanvas` de
`user://settings.cfg`); reubicar en Options si se quiere. Pendiente del flujo:
**MainMenu → Overworld Cinematic → Map Cinematic** (cinemáticas aún por crear).

### Herramientas offline (`tools/`, Python)
- `build_from_lt.py` — genera `data/general/*` desde `<.ltproj>/game_data/*`.
- `build_levels.py` — copia niveles LT crudos + `NID_REMAP` (FakeMidir→Midir, Chagall1/2→Chagall, Eldigan*→Eldigan, Leaf→Leif).
- `build_tilemaps.py` — terreno slim por mapa.
- Fuentes LT: `D:\FEHW\lt-maker-moded\GotHW.ltproj` (FE4) y `Thracia776.ltproj` (FE5).

---

## 3) Convenciones y trampas (Godot 4.6) — IMPORTANTES
- **`.tscn`/`.import` deben ser UTF‑8 SIN BOM.** PowerShell escribe UTF‑16/BOM por defecto → usar la herramienta Write, o `[System.IO.File]::WriteAllText(path, txt, (New-Object System.Text.UTF8Encoding($false)))`. Un BOM rompe el parser ("Expected '['").
- **No nombrar métodos como virtuales de `Object`**: `_get`, `_set`, `_init`, `_notification`… (usar `_cfg_get`, etc.). `get_class()` choca con Object → `get_class_data()`.
- `project.godot` tiene `[debug] gdscript/warnings/treat_warnings_as_errors=false` (Godot 4.6 con warnings‑as‑error tumbaba autoloads → todas las escenas).
- **UI por código** (como CreditsScreen/MainMenu): evita .tscn frágiles y funciona sin abrir el editor.
- **Assets `.import`**: el `source_file` debe apuntar a la ruta real (`res://assets/...`). Los `.translation` son **productos de importación** de los `.csv` (`importer="csv_translation"`); no se copian sueltos sin su `.csv`/`.import` con rutas correctas.
- **Sin git**: cambios irreversibles.
- **Validación headless (¡importante!)**: el asistente PUEDE validar sin abrir el editor con
  `"C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"`:
  - `--headless --path . --import` → importa assets nuevos (PNG/fuentes/etc.).
  - `--headless --path . res://Scenes/<x>.tscn --quit-after N` → corre la escena; los
    errores de **shader** y de **script** salen en stderr (grep `SHADER ERROR`/`SCRIPT ERROR`).
  Así se cazan errores de compilación/shader antes de pasárselos al autor.
- Para **previsualizar** UI/sprites sin el motor: componer con **Pillow** (Python) leyendo los
  PNG reales (lo usamos para mockups de paletas, título, placas del menú).

---

## 4) Pendiente / siguientes pasos (sugerido por prioridad)
1. **Verificar traducciones** (recién arregladas: 15 `.translation` restaurados + rutas `.import` corregidas). Si siguen fallando, revisar `.godot/imported` o reimportar los 3 CSV en el editor.
2. **Render visual del mapa — YA CABLEADO** ✅. `MapBackground.gd` pinta el PNG pre-renderizado del mapa (`assets/tilesets/FE4/<nid>.png`, p.ej. `Prologue.png`=1024×512=64×32 tiles) escalado a `cell_size/16`. Los PNG ya están importados → al correr el Prólogo se ve el mapa real. *Refinamientos pendientes:* autotiles animados (`<nid>_autotiles.png` + `tileset.json` con coords), y FE5 (T1…) ya tiene sus PNG.
3. **Map sprites de unidades — IMPLEMENTADO (2026-06-05)** ✅. Las unidades muestran su sprite real (antes círculos). `AssetLoader.get_map_sprite(map_sprite_nid, variant)` + `UnitMapSprite.gd` (idle fila 0, 3 frames, celda 64×48, escala `cell_size/16`, anclado por pies). `Unit.gd` lo instancia en `_ready` (resuelve `map_sprite_nid` vía `GameDB.get_class_data(unit_class).map_sprite_nid`, `cell_size` vía grupo `"grid"`). Anclado por pies (nativo y=39), y‑sort por fila (UnitLayer), **recolor por equipo con palette‑swap LUT** (ver §7). *Pendiente:* animación de paso con `move.png` (4 dir × 4 frames, celda 48×40); aliados verdes en combate; refinar anclaje en clases altas si hace falta.
4. **Arte en el menú — HECHO en gran parte (2026‑06‑06)** ✅ (ver §7). *Pendiente:* SFX de menú, gemas de adorno en placas, cablear Continue/SoundRoom/Load, fuente CJK/acentos para el selector de idioma.
5. **Combate del Prólogo**: validar IA enemiga, condiciones victoria/derrota, báculos como sistema (hoy quedan en inventario como dict), retratos en combate.
6. **Escenas no recreadas** (si se quieren): `BattleScene`, `GameOver`, `PreCredits`, reproductores de música. Referencia: proyecto viejo extraído.
7. **OptionsMenu**: añadir resolución/fullscreen/keybindings y **aplicar** los settings al gameplay (hoy persisten pero no todos se aplican). Buses de audio "Music"/"SFX" si se crean.
8. **Refinamientos de data**: separar "Magic" en Anima/Light/Dark por tomo; gatear armas Holy por `prf_tags`/tipo de sangre concreto.
9. (Opcional) Poner `language.tscn` como escena principal para el arranque FE completo (Language→Intro→Menu) en vez de `main_menu`.

---

## 5) Rutas de referencia (máquina del autor)
- Proyecto: `C:\Users\SirAxelloid1460\Downloads\CLAUDE APPS\FE4_FE5_Godot`
- LT fuentes: `D:\FEHW\lt-maker-moded\GotHW.ltproj` y `Thracia776.ltproj`
- Proyecto Godot viejo (referencia de escenas/UI a recrear): `C:\Users\SirAxelloid1460\Downloads\_godotfe_old`
- Zips importados extraídos: `C:\Users\SirAxelloid1460\Downloads\_imported\{assets,languages}`

---

## 6) Regla de oro del proyecto
No inventar datos/fórmulas: **cruzar siempre con LT** (engine `app.rar` → spreadsheet → JSON de los `.ltproj`). Las escenas/UI se **recrean desde cero** (no se portan), usando el proyecto viejo solo como referencia de comportamiento/estética.

---

## 7) Sesión 2026‑06‑06 — palettes de equipo, rename, flujo de escenas, interfaz del menú

### Palette‑swap por equipo (map sprites) ✅
- `Shaders/team_palette_swap.gdshader` — **LUT de 16 colores** con `uniform int team`
  (0=Player identidad, 1=Enemy, 2=Ally, 3=Other, 4=Used/gris). Detecta cada color de la
  paleta GBA "Player" del sprite y lo cambia por el del equipo. Generado desde
  `docs/palettes/team_palettes.md` (extraído de `gba_team_palettes.png` + hojas SNES FE4).
- `UnitMapSprite.gd`: materiales compartidos por equipo (`set_team`/`set_used`), `team 0` sin material.
- `Unit.gd`: campo `team` + `team_palette_index()`; `update_visual()` aplica paleta **Used** al actuar.
- Paletas/mockups: `docs/palettes/` (`team_palettes.md`, `palette_mockup.png`, fuentes PNG).

### Rename de equipos → **player / enemy / other / ally** ✅
- LT usa `player/enemy/enemy2/other`; remapeado a `player/enemy/other/ally`:
  **LT `other`→`ally`** (verde NPC), **LT `enemy2`→`other`** (dorado neutral, p.ej. guarniciones
  `MackilyNeutral`/`AnphonyNeutral` de FE4 cap 2). Aplicado en `data/*/levels/*.json` + `ai.json`,
  con remap reproducible en `tools/build_levels.py` (`TEAM_REMAP`) y `tools/build_from_lt.py`
  (`_remap_ai_teams`). Claves de música LT (`enemy2_phase`…) se dejaron (metadata, no se leen).

### Flujo de escenas ✅
- Escena principal = `intro.tscn`. Intro → **corte SIN fade** → MainMenu.
- Menú: navegación entre paneles **sin fade** (solo deslizan las columnas); **fade reservado a
  acciones terminales** (New Game→start, Credits; Continue/SoundRoom/Load harán fade al cablearse).
- DEBUG: `PrologueTest.DEBUG_PALETTES = true` spawnea una rejilla de prueba de paletas en el
  Prólogo (ponerlo en `false` cuando moleste).

### Interfaz del MainMenu (estilo FE4) ✅
- **Título** (Press Start): fondo `assets/title/title1_background.png` (ejército) + logo
  `assets/title/logo1.png` (41% transparente) + "Press Start" animado `assets/sprites/press_start.png`
  (8 frames). Música de fondo = `102 - Fire Emblem Theme.ogg` (loop, bus "Music" si existe).
  **Tras pulsar Start el logo se oculta** (solo fondo + botones).
- **Botones = placas individuales** `assets/menus/title_menu_dark.png` (+`_highlight` al enfocar)
  como stylebox del Button; fuente serif `assets/fonts/IMFellFrenchCanonSC-Regular.ttf`.
- **Cursor = espada** `assets/menus/cursor_dragon.png`: centrada en el botón, **bob vertical
  ESCALONADO** (look GBA, `CURSOR_BOB_SEQ`/`CURSOR_STEP_TIME`), y **sigue al botón en vivo**
  durante el slide (`_cursor_target`).
- **Descripción Normal/Elite** en recuadro FE (panel oscuro + borde dorado), `_build_desc`.
- Assets de título copiados de `_godotfe_old`; caja vieja `menu_box_6x.png` quedó huérfana (borrable).

### Próximo (sugerido para mañana)
1. **Cinemáticas Overworld → Map** (recrear desde cero) entre MainMenu y el Prólogo.
2. Pulir menú: gemas en placas, SFX de navegación/confirmación, cablear Continue/SoundRoom.
3. Animación de **paso** de unidades (`move.png`) al moverse en el mapa.
4. Combate del Prólogo (IA, victoria/derrota, báculos, retratos).

---

## 8) Sesión 2026‑06‑27 — animación de paso + pulido de menú (Sound Room, gemas, SFX)

### Animación de paso de unidades (`move.png`) ✅  [pendiente #3 de §7]
- `UnitMapSprite.gd`: soporte de la hoja de movimiento (192×160 → 4 dir × 4 frames,
  celda **48×40**; filas LT/GBA **0=abajo 1=izq 2=der 3=arriba**). API nueva:
  `start_move()` / `set_move_dir(dir)` / `end_move()` (constantes `DIR_DOWN/LEFT/RIGHT/UP`).
  Anclaje de la celda de paso con `MOVE_FEET_NATIVE` (≈36) — *ajustable* si el roce con
  el suelo difiere en alguna clase alta. Si la clase no tiene `move.png`, la unidad se
  desliza con el idle (sin animar piernas) — degradación limpia.
- `Unit.gd`: corrutina `animate_move_along(world_points, step_time)` que camina casilla a
  casilla, orienta el sprite por el delta (`_dir_from_delta`) y reproduce **SFX de paso**
  según tipo (`_step_sfx_name`: Flier/Mounted3/Armor1/Infantry2) vía `AssetLoader.get_sfx`
  en el bus "SFX".
- `GameManager.gd`: `move_selected_unit` ahora **espera la animación** antes de cerrar el
  movimiento (guard `PlayerPhase.MOVING` para ignorar clics repetidos; limpia resaltados
  mientras camina). La IA también anima: `execute_enemy_decision` es `await` y reconstruye
  el path con `Pathfinding.find_path` antes de mover.

### Pulido del MainMenu ✅  [pendiente #2 de §7, parcial]
- **Gemas en placas**: `assets/menus/menu_gem_brown.png` (14×12, ×3) flanqueando el texto,
  visibles sólo en la placa con foco (`_add_gems` / `_set_button_gems`, toggle en
  focus_entered/exited).
- **SFX de menú** (bus "SFX"): navegación `Select 5` (al cambiar de foco; se omite el tick
  del auto‑foco al entrar a un panel vía `_skip_next_nav_sfx`), confirmación `Select 4`,
  cancelación `Step Back 1`, error `Error` (acciones no disponibles). Helper `_play_sfx`.
- **Sound Room** (`Scripts/SoundRoom.gd`, nuevo): pantalla por código (señal `closed`),
  abierta con fade desde Extras (`_open_soundroom`, pausa/reanuda el tema del menú). Escanea
  `assets/music/*.ogg`, lista con ventana de 12 + cursor (↑↓), Accept = play/stop (toggle,
  loop, bus "Music"), Cancel = volver. Panel FE con borde dorado y fuente serif.

### Continue — NO cableado (limitación real)
- `SaveSystem.load_game()` es un **stub**: lee el `.save` pero **no restaura estado** de
  juego (no hay pipeline de carga de capítulo/ejército). Cablear "Continue" de verdad
  requiere primero construir ese pipeline. Por ahora el botón sólo aparece si hay save y
  muestra "coming soon" con SFX de error. **Pendiente** para una sesión dedicada al guardado.

### Validación
- **Sin binario de Godot en el entorno remoto** → no se pudo compilar headless; revisión
  estática (sin BOM, indentación con tabs, sin refs rotas ni colisiones de nombres). Conviene
  re‑validar en el editor: F6 `main_game.tscn` (paso de unidades) y `main_menu.tscn`
  (gemas/SFX/Sound Room).

### Próximo
1. Verificar en editor el anclaje de la celda de paso (`MOVE_FEET_NATIVE`) en clases altas.
2. Cinemáticas Overworld → Map (sigue pendiente, #1 de §7).
3. Pipeline de guardado/carga real para habilitar Continue.
4. Combate del Prólogo (IA, victoria/derrota, báculos, retratos).
