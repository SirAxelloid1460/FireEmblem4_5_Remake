# Localización de diálogos — reajustes acordados (app traductora + proyecto)

Estado: **spec acordado.** Los ejemplos canónicos del formato viven en
`docs/examples/dialogue_format/Chapter01.{en,es,it,jp}.json` (Cap. 1 de FE5,
extraídos de ROMs/parches en otra sesión). La app traductora está en
`tools/translator_app/`. La utilidad de casado/normalización es
`tools/dialogue_l10n.py`.

Este documento recoge los tres reajustes pedidos para que "se detecte todo bien".

---

## Formato de los documentos por idioma

Un documento por **capítulo × idioma**:

```json
{
  "<CLAVE_DE_ESCENA>": [
    { "SPEAKER": "línea de diálogo{w}..." },
    ...
  ],
  ...
}
```

- La clave de nivel superior es la **escena** (un bloque de diálogo disparado por
  un evento: `OPENING1`, `DAGDARARRIVE`, `OSIANHOUSEOSIAN`, ...).
- El valor es la lista ordenada de intervenciones `{ "SPEAKER": "texto" }`.
- Los tokens `{w}` / `{br}` y demás directivas van **inline** en el texto (ver
  `docs/dialogue_localization_design.md` para el modelo de la caja de diálogo).

---

## Reajuste 1 — la app debe reconocer también los eventos LT directamente

Documentación LT completa: <https://lt-maker.readthedocs.io/en/latest/source/home.html>

Hoy la app importa el **scene `_en.json`** (formato de `build_dialogue_scenes.py`).
Debe además aceptar los **`events.json` crudos de LT** (los de
`data/<game>/events/events.json` y los `.ltproj/.../events.json`), extrayendo de
ellos las líneas mostrables:

- `speak` → `arg[1]` es la línea (formato LT: `["speak", ["Speaker", "texto", ...]]`).
- Elecciones (`choice`), narrador / títulos de capítulo, y cualquier otro comando
  con texto visible (la app debe **listar** los comandos con texto, no asumir solo
  `speak` — ver la referencia de comandos de LT en el enlace).
- Las acotaciones (`@…` / comandos sin texto) son **contexto**: se muestran para
  situar al traductor, pero no se traducen.

Resultado: el traductor puede abrir un capítulo de LT sin pre-convertirlo.

---

## Reajuste 2 — claves japonesas: usar el comentario latino `⟦...⟧`

Los idiomas de **alfabeto latino** (en, es, it, de, fr) comparten la MISMA clave
de escena. El **japonés** usa una descripción en japonés con el equivalente
latino **anotado entre `⟦ ... ⟧`**. Hay que usar ese comentario como clave, no el
japonés:

```
"民家（下）  ⟦OSIANHOUSEOSIAN⟧"        ->  OSIANHOUSEOSIAN
"ワールドマップ  ⟦WORLDMAP1-6⟧"         ->  WORLDMAP1-6            (rango)
"オープニング  ⟦OPENING1 · OPENING3⟧"  ->  OPENING1 · OPENING3    (fusión)
"ワイズマン初戦時  ⟦... (sin equiv.)⟧"  ->  contenido solo-ROM
```

El token `⟦...⟧` puede referenciar:
- una sola escena (`OSIANHOUSEOSIAN`),
- un **rango** (`WORLDMAP1-6` = WORLDMAP1..WORLDMAP6),
- una **fusión** (`OPENING1 · OPENING3`, `DAGDARARRIVE · MARTYARRIVE`), porque la
  estructura de la ROM japonesa agrupa escenas que en LT van separadas,
- contenido **solo-ROM** (`(sin equiv.)`): existe en la ROM pero no en los eventos
  LT (p. ej. las frases de batalla de Weissman).

Regla de implementación (app **y** proyecto): al leer un documento, normalizar la
clave con la función `latin_key()` de `tools/dialogue_l10n.py`
(`re.search(r"⟦(.+?)⟧", clave)`), cayendo a la clave tal cual si no hay `⟦...⟧`.
Resolver rangos/fusiones a escenas concretas es una fase aparte (la ROM no casa
1:1 con LT); `dialogue_l10n.py` ya lo hace y **reporta** los desajustes:

```
python tools/dialogue_l10n.py check docs/examples/dialogue_format/Chapter01
python tools/dialogue_l10n.py normalize <cap>.jp.json -o <cap>.jp.norm.json
```

> Nota de datos: en el ejemplo actual, varias casas japonesas están marcadas
> `(sin equiv.)` cuando en realidad SÍ tienen escena latina
> (`LIFERINGHOUSE`, `VULNERARYHOUSE`, `IRONSWORDHOUSE`, `HALVANHOUSE*`). Eso es un
> `⟦...⟧` por afinar en la sesión de extracción — el `check` lo lista para que se
> corrija.

---

## Reajuste 3 — separar diálogo (por idioma) de la lógica (general)

Para cada capítulo, dividir los eventos en **dos documentos**:

1. **Documento por idioma** (`dialogue.<locale>.json`, uno por idioma): SOLO los
   diálogos **y los eventos que ocurren entre líneas** (cambios de retrato,
   expresiones, pausas/`{w}`, sonidos ligados a la conversación). Es lo que ve y
   edita el traductor, y lo único que cambia por idioma. Formato = el de arriba.

2. **Documento general, independiente de la localización** (uno solo, no por
   idioma): el RESTO de eventos intermedios (spawns, movimientos, condiciones,
   objetivos, cambios de mapa...) **con las claves que llaman a los diálogos**
   (p. ej. una referencia a la escena `OPENING1` donde antes iba el texto inline).

En runtime: el documento general dirige la lógica; al llegar a una llamada de
diálogo, se resuelve la escena por su clave en el `dialogue.<locale>.json` del
idioma activo, **cayendo a inglés** si falta (mismo criterio que el resto del
proyecto). Esto continúa el diseño de "intercalar eventos y cambios de retrato
durante los diálogos" ya acordado (ver `docs/dialogue_localization_design.md`).

Corrección asociada en la app: al leer el `_en.json`, aplicar esta misma
separación (mostrar diálogo + eventos inter-línea; ocultar la lógica general),
para que el traductor solo vea lo traducible.

---

## Pendiente de implementar (proyecto)

- `tools/` de extracción LT → (dialogue por idioma) + (general con claves), sobre
  `build_dialogue_scenes.py` como base lossless.
- Autoload `DialogueL10n` + hook en `EventSystem` (resuelve escena por clave y
  locale, fallback a en) — ver el bloque "Runtime" del design doc.
- Aplicar `latin_key()` al cargar documentos japoneses (Reajuste 2).
