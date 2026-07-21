# Handoff — claves i18n del menú de guardado (para la sesión de traducción/CSV)

Contexto: se añadió al **menú principal** los botones Continue / Load / Restart y
un **submenú "Resume Chapter"** (ranuras de guardado) que abren Continue y Load.
El rediseño de la **dificultad** (Normal/Elite) NO necesita claves nuevas (reusa
`NORMAL`, `ELITE`, `NORMALDESC`, `ELITEDESC`).

`MainMenu.gd` consume estas claves con un helper `_trd(key, fallback)`: **mientras
la clave no exista en el CSV, muestra el fallback en inglés**, así que nada se
rompe; en cuanto se añadan, se localizan solas.

## Claves nuevas para `assets/languages/Menus/Translations FE45 - MainMenu.csv`

Columnas del CSV, en orden: `,en,es,de,ja,fr,it`. Relleno `en` (fuente) y sugiero
`es`; `de/ja/fr/it` quedan para la sesión de traducción.

| clave | en | es (sugerida) | de | ja | fr | it |
|---|---|---|---|---|---|---|
| `RESUMECHAPTER` | `Resume Chapter` | `Continuar Capítulo` | | | | |
| `NODATA` | `-- NO DATA --` | `-- SIN DATOS --` | | | | |
| `PLAYTIME` | `PLAY TIME` | `TIEMPO DE JUEGO` | | | | |
| `INFO` | `Info` | `Info` | | | | |
| `RESTARTNOGAME` | `No chapter in progress` | `No hay capítulo en curso` | | | | |

Notas:
- `LOAD`, `CONTINUE`, `RESTART` ya existen en el CSV (no hace falta tocarlas).
- Tras añadir las filas, reimportar el CSV en Godot (regenera los `.translation`)
  y — si aparece una nueva columna/locale — registrar en `project.godot`.

## Arte pendiente (no bloquea, pero conviene)

El submenú de guardado usa **placeholders** para tres iconos (recuadros con letra
"C"/"D"): **copiar**, **borrar** y **confirmar** partida. Cuando haya arte
GBA-style, sustituir los placeholders en `MainMenu.gd` (`_placeholder_icon`).
Sugerencia de ubicación: `assets/GBA/menus/` (p. ej. `icon_copy.png`,
`icon_erase.png`, `icon_confirm.png`).
