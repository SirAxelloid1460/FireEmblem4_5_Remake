# Fire Emblem: Genealogy + Thracia — Remake híbrido (Godot 4)

Remake fan de **Fire Emblem: Genealogy of the Holy War (FE4)** y **Thracia 776 (FE5)**
en **Godot 4**, con un pipeline de datos **nativo** derivado de un proyecto de
**Lex Talionis (LT‑maker)**.

> ⚠️ **Work in progress.** Proyecto fan, sin ánimo de lucro y **no afiliado** a
> Nintendo / Intelligent Systems. Ver [Créditos y licencia](#-créditos-y-licencia).

---

## 🎮 Qué es

Un tactical‑RPG estilo Fire Emblem que recrea el continente de **Jugdral** (FE4 + FE5),
construido sobre datos auténticos exportados de Lex Talionis y **migrados a un modelo de
datos propio de Godot** (sin depender del runtime de LT). Las escenas, la UI y el render
se **recrean desde cero** en Godot; LT y la versión SNES/GBA se usan solo como referencia
de valores y estética (regla de oro: nada de datos/fórmulas inventados).

## ✅ Estado actual (jugable)

Arranca y se juega de extremo a extremo:

**Intro (vídeo) → Menú principal (título de FE4 + tema de Fire Emblem) → New Game →
Prólogo de FE4** con mapa real, ~63 unidades, movimiento por casillas y cámara limitada al mapa.

## 🧩 Características implementadas

- **Datos nativos (`res://data/`)** generados desde los `game_data` de los `.ltproj`:
  clases (64), armas (134, con magia y báculos), ítems (79), skills (97), unidades (64) y
  capítulos. Cargados por el autoload **`GameDB`**.
- **Mapas reales**: render del tileset pre‑renderizado por capítulo + rejilla de terreno.
- **Map sprites de unidades con _palette‑swap_ por equipo** vía shader LUT de 16 colores:
  Player (azul) / Enemy (rojo) / Ally (verde) / Other (dorado) + estado **Used** (gris) al actuar.
  Anclaje por pies y orden por fila (y‑sort).
- **Menú principal estilo FE4**: fondo del ejército + logo + "Press Start" animado, **tema de
  Fire Emblem** en bucle, botones‑placa ornamentados con fuente serif y **cursor‑espada** animado.
- **Mecánicas fieles a FE/LT**: rangos de arma (D=1 · C=51 · B=126 · A=226 · Holy=1023),
  **sangre sagrada** (Major/Minor) y tope `NotHoly`, triángulo de armas, etc.
- **Sistemas base**: combate, IA enemiga, turnos, pathfinding A*, terreno, convoy, FoW.

## ▶️ Cómo ejecutar

1. Instala **Godot 4.6.x** (probado en 4.6.3).
2. Abre `project.godot` (la **primera** apertura reimporta los assets — tarda).
3. Pulsa **F5**. (Escenas sueltas con **F6**: `Scenes/main_menu.tscn`, `intro.tscn`,
   `main_game.tscn` para ir directo al Prólogo.)

## 📁 Estructura

```
Scripts/   Lógica del juego (GDScript)
Scenes/    Escenas (.tscn)
Shaders/   Shaders (p.ej. palette‑swap por equipo)
assets/    Gráficos, audio, fuentes, tilesets/tilemaps, vídeos, traducciones
data/      Datos nativos (JSON) generados desde LT (general/ + fe4|fe5/)
tools/     Generadores en Python que regeneran `data/` desde los .ltproj
docs/      Documentación (HANDOFF.md = estado/arquitectura/convenciones)
```

## 🔧 Pipeline de datos

Los archivos de `data/` se generan **offline** desde los proyectos LT con los scripts de
`tools/` (`build_from_lt.py`, `build_levels.py`, `build_tilemaps.py`). El runtime no usa LT:
solo lee el JSON nativo. Así se puede regenerar todo desde la fuente sin tocar el código.

## 📖 Documentación para desarrollo

- **[`docs/HANDOFF.md`](docs/HANDOFF.md)** — estado completo, arquitectura, convenciones de
  Godot 4.6, trampas conocidas y lista de pendientes priorizada. **Empezar por aquí.**

## 👤 Créditos y licencia

- **Desarrollo:** SirAxelloid1460, con asistencia de **Claude (Anthropic)**.
- Basado en *Fire Emblem: Genealogy of the Holy War* y *Thracia 776*,
  © **Nintendo / Intelligent Systems**.
- Datos y referencias del motor **Lex Talionis (LT‑maker)** y su comunidad; sprites y gráficos
  procedentes de FE4/FE5.

**Licencia:** el **código original** se libera al **dominio público — [The Unlicense](LICENSE)**
(uso, copia, modificación y distribución totalmente libres, sin restricciones). Los gráficos,
sonidos, música y nombres de *Fire Emblem* pertenecen a Nintendo / Intelligent Systems y **NO**
están cubiertos por esa licencia; se usan aquí únicamente con fines educativos y no comerciales
dentro de este proyecto fan. No se distribuyen ROMs ni material con copyright fuera de ese marco.
