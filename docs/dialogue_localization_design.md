# Localización de diálogos — diseño (proceso paralelo a Godot)

Estado: **DISEÑO ACORDADO, sin implementar todavía.**

## Problema

Los diálogos guardan el texto **inline en inglés** dentro de `events.json`
(p. ej. `["speak", ["Weissman", "No, my lord.{w}{br}...", "", "", "noir"]]`).
Meter esto en la tabla de traducción de Godot (una clave por línea) daría
**miles** de claves a mano — inmanejable. (El intento previo, la tabla
`FE5CHAP1.csv` con 97 claves, quedó 100% sin usar.)

## Solución: capa paralela por hash

`events.json` sigue siendo la **fuente de verdad** (inglés inline). Aparte, una
capa de traducción **independiente del TranslationServer de Godot**:

- A cada línea se le asigna un **ID estable = hash del texto inglés**
  (SHA1 del string exacto tal como está en `events.json`, incluidos los tokens
  `{w}`/`{br}`; se usan los primeros 12 hex).
- Los traductores rellenan mapas `hash → texto` por idioma.
- En runtime, al mostrar una línea: `hash(inglés)` → busca en el mapa del locale
  activo → si existe la usa, si no **cae al inglés inline**.

Ventajas del hash: inmune a reordenar líneas; si se edita el inglés, el hash
cambia y esa línea **vuelve a inglés** automáticamente (y la tool la marca como
"pendiente de re-traducir"). Los traductores nunca tocan `events.json` ni el
motor. Líneas inglesas idénticas comparten traducción (aceptable).

## Estructura de archivos (por capítulo, carpetas fe4/fe5 separadas)

```
data/fe4/events/lang/<chapter>/dialogue.<locale>.json
data/fe5/events/lang/<chapter>/dialogue.<locale>.json
```

- `<chapter>` = el mismo agrupador que ya usan los eventos (p. ej. fe4:
  `0`,`1`,`2`,`998`,`global`…; fe5: por capítulo).
- Un archivo por **capítulo × idioma**. Locales: `es`, `de`, `fr`, `ja`
  (en = el inline, no necesita archivo salvo el índice base de referencia).
- Formato de cada archivo:
  ```json
  { "<hash12>": "texto traducido de la línea", ... }
  ```
- Índice base opcional `dialogue.en.json` por capítulo (`hash → inglés`) para
  referencia y detección de huérfanas.

## Workflow de traductores: JSON + xlsx con round-trip

- `tools/build_dialogue_lang.py`:
  - Recorre los `events.json`, extrae **todo texto mostrable** (ver comandos
    abajo), calcula el hash, y **fusiona** con las traducciones existentes
    (preserva lo ya traducido).
  - Emite/actualiza los `dialogue.<locale>.json` por capítulo.
  - Genera un **.xlsx** por capítulo (columnas `id · english · es · de · fr · ja`)
    para editar cómodo.
  - Reporta **huérfanas** (hash en el JSON del idioma pero ya no en events =
    inglés cambiado/borrado) y **faltantes** (en events pero sin traducir).
  - Flags previstos: `--game fe4|fe5`, `--chapter <id>`, `--xlsx`, `--prune`
    (elimina huérfanas), `--dry-run`.
- `import`: re-importa el .xlsx editado de vuelta a los `.json` (mismo script con
  `--import <xlsx>` o script hermano).

## Runtime

- Autoload nuevo `DialogueL10n`:
  - `localize(game, chapter, english_line) -> String`: `hash` → mapa del locale
    activo → traducción o `english_line` (fallback).
  - Carga perezosa del mapa por `(game, chapter, locale)`; recarga al cambiar de
    capítulo o de idioma.
- Hook en `EventSystem`: antes de mostrar, envolver el texto de los comandos con
  texto visible por `DialogueL10n.localize(_current_game, _current_chapter, ...)`.

## Comandos que llevan texto (a cubrir por la tool y el hook)

- `speak` (arg[1] = línea).
- Elecciones/`choice` (opciones de menú de diálogo).
- Narrador / `chapter_title` (títulos y narración).
- Cualquier otro comando con texto mostrable que aparezca al inventariar los
  `events.json` (la tool debe listarlos, no asumir solo `speak`).

## Notas de integración

- El "juego activo" y el "capítulo activo" se leen como ya se hace (GameMode /
  contexto del EventSystem).
- Mantener `tools/COMMANDS.txt` actualizado al implementar la tool.
- No usa el TranslationServer de Godot → no hay reimport de CSV ni claves.

## Pendiente (cuando se implemente)

1. `tools/build_dialogue_lang.py` (extractor + xlsx + import + reportes).
2. Autoload `DialogueL10n` + registro en `project.godot`.
3. Hook en `EventSystem` (speak + choice + narrador/título).
4. Prueba con **FE5 Cap. 1** (el que ya tiene texto) generando `es`.
