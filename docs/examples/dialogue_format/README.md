# Formato de localización de diálogos (según tu idea)

`prologue_fe5.en.json` = **Prólogo entero de FE5** (escenas Intro + Narration +
DagdarSpawn, 54 líneas) extraído de `events.json`, para que lo revises/corrijas.

## Estructura

Cada escena es una **lista ORDENADA** de pasos. Un paso es o una **línea hablada**
`{ "HABLANTE": "texto" }`, o una **acotación** `{ "@dir": ... }` (evento/retrato
que ocurre en ese punto). Así el flujo de la escena queda intercalado tal cual:

```json
{
  "INTRO": [
    {"@music": "117 Base A"},
    {"@transition": "open"},
    {"@enter": ["Raydrik", "Left"]},
    {"@enter": ["Weissman", "Right"]},
    {"RAYDRIK": "Have you found the prince?{w}"},
    {"WEISSMAN": "No, my lord.{w}{br}..."},
    {"@exit": "Raydrik"},
    {"WEISSMAN": "Someone! Bring the girls here.{w}"}
  ]
}
```

- Tokens de control (`{w}` espera, `{br}` salto) se conservan tal cual.
- El **traductor solo edita el texto** de las líneas habladas; las acotaciones son
  estructura/contexto (read-only).

### Acotaciones incluidas (retratos + presentación)

| Acotación | Comando de `events.json` | Ejemplo |
|---|---|---|
| `@enter` | add_portrait / multi_add_portrait | `{"@enter":["Raydrik","Left"]}` |
| `@exit` | remove_portrait / multi_remove_portrait | `{"@exit":"Raydrik"}` |
| `@expr` | expression | `{"@expr":["Mareeta","Smug"]}` |
| `@move` | move_portrait | `{"@move":["Nanna","Right"]}` |
| `@swap` | change_portrait | `{"@swap":["Eyvel","EyvelHurt"]}` |
| `@transition` | transition | `{"@transition":"open"}` |
| `@title` | chapter_title | `{"@title":""}` |
| `@music` | music / music_clear | `{"@music":"117 Base A"}` |
| `@bg` | change_background | `{"@bg":"BlackBackground"}` |
| `@wait` | wait (ms) | `{"@wait":1500}` |

**Omitidos** (por ahora): comandos de mapa/unidad (`add_unit`, `move_unit`,
`center_cursor`, `change_tilemap`, `spawn_group`…) — son puesta en escena del
mapa, no del diálogo. Se pueden incluir si los quieres.

## Por qué lista (y no `HABLANTE: línea` suelto)

Tu borrador tenía `HABLANTE: "..."` directo dentro de la escena, pero en JSON un
objeto **no admite claves repetidas** y un mismo personaje habla varias veces
(RAYDRIK aparece 5+ veces). La **lista de objetos de una sola clave** conserva tu
estética (hablante: línea) y además: mantiene el ORDEN y permite REPETIR
hablante. (También corrige: faltaba el `:` tras la escena y las comillas del
hablante.)

## Cómo mapearía en runtime

El sistema reproduce el evento `INTRO`, línea N → busca
`dialogue.<locale>.json["INTRO"][N]` → usa esa línea traducida; si falta, cae al
inglés inline de `events.json`. El **hablante** es para el traductor (legibilidad
y para poder avisar si no cuadra con el evento); el emparejamiento real es por
**escena + índice**.

## App de traductores (pendiente)

En vez de xlsx: una web que importe este `_en.json`, muestre cada línea (escena ·
hablante · inglés) con su traducción editable al lado, y exporte
`dialogue.<locale>.json` con la MISMA estructura. Se hará cuando cierres el
formato.
