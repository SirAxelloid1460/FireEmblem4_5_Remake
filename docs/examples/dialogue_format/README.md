# Formato de localización de diálogos (según tu idea)

`prologue_fe5.en.json` = **Prólogo entero de FE5** (escenas Intro + Narration +
DagdarSpawn, 54 líneas) extraído de `events.json`, para que lo revises/corrijas.

## Estructura

```json
{
  "INTRO": [
    { "RAYDRIK": "Have you found the prince?{w}" },
    { "WEISSMAN": "No, my lord.{w}{br}..." },
    { "RAYDRIK": "..." }
  ],
  "NARRATION": [ ... ],
  "DAGDARSPAWN": [ ... ]
}
```

- **Escena** (`INTRO`, `NARRATION`, `DAGDARSPAWN`) = un evento del capítulo.
- Cada escena es una **lista ORDENADA**; cada elemento es `{ "HABLANTE": "línea" }`.
- Los tokens de control (`{w}` espera, `{br}` salto) se conservan tal cual.

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
