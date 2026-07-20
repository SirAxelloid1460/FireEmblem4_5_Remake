# Formato de escena (fuente de verdad — plan "B", alcance completo)

`prologue_fe5.scene.json` = **Prólogo entero de FE5** (escenas INTRO, NARRATION,
DAGDARSPAWN, VENDOR) en el formato de escena nuevo, generado desde
`data/fe5/events/events.json` con `tools/build_dialogue_scenes.py`.

Este es el formato **B**: **fuente de verdad** de la escena (el motor lo
reproducirá) y **lossless** (round-trip exacto con los comandos de LT, ver
abajo). Incluye **todos** los comandos (retratos, presentación y mapa/unidad).

## Estructura

```json
{
  "INTRO": {
    "name": "Intro", "trigger": "level_start", "level_nid": "1",
    "condition": "True", "only_once": true, "priority": 21,
    "steps": [
      {"@music": ["117 Base A"]},
      {"@add_unit": ["Weissman", "17,5", "", "stack"]},
      {"@add_portrait": ["Raydrik", "Left"]},
      {"Raydrik": "Have you found the prince?{w}"},
      {"Weissman": "No, my lord.{w}{br}..."},
      {"@remove_portrait": ["Raydrik"]}
    ]
  }
}
```

- Cada **escena** = un evento (con sus metadatos: trigger, level_nid, condición,
  only_once, priority).
- `steps` = **lista ORDENADA** de pasos. Un paso es:
  - **Línea hablada**: `{ "<SpeakerNid>": "texto" }`.
    - El nombre del hablante va con su **case exacto** (`Raydrik`, no `RAYDRIK`)
      porque es el nid del retrato — así el mapeo es reversible.
    - Si el `speak` trae extras (estilo/posición del bocadillo), se guardan en
      `"@opts"`: `{ "Raydrik": "...", "@opts": ["", "", "noir"] }`.
  - **Acotación/comando**: `{ "@<comando>": <args> }` con el nombre real del
    comando LT: `@add_portrait`, `@remove_portrait`, `@expression`,
    `@move_portrait`, `@transition`, `@music`, `@wait`, `@add_unit`,
    `@move_unit`, `@center_cursor`, `@change_tilemap`, … (todos).
    - Comandos con elementos extra (raro) usan `"@rest"`.
- Tokens de control del texto (`{w}` espera, `{br}` salto) se conservan.

## Losslessness (probado)

`tools/build_dialogue_scenes.py --game fe5 --verify` → round-trip de los 229
comandos EXACTO. Y `--from-scenes` reconstruye los eventos con comandos
**idénticos** a `events.json`. Por eso puede ser fuente de verdad.

## Tool

```
python tools/build_dialogue_scenes.py --game fe5 --verify        # comprobar lossless
python tools/build_dialogue_scenes.py --game fe5 --level 1       # eventos -> escenas (data/fe5/events/scenes/1.json)
python tools/build_dialogue_scenes.py --from-scenes <scenes.json> # escenas -> comandos (stdout)
```

## Siguientes pasos

1. **B (runtime):** un cargador que reproduzca las escenas desde estos `.json`
   (reutilizando el ejecutor de comandos de `EventSystem`), y migrar los eventos
   a este formato como fuente.
2. **A (traducción):** capa por idioma que superpone el texto traducido a los
   pasos hablados (emparejando por escena + índice de línea hablada), cayendo al
   texto inglés inline si falta. Después irá la app de traductores.
