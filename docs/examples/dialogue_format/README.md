# Ejemplo del formato de localización de diálogos

Muestra generada desde **FE5, capítulo 1** (`level_nid = "1"`) para revisar el
formato propuesto en `docs/dialogue_localization_design.md`. **No es el sistema
real todavía** — solo archivos de ejemplo.

## Archivos

- **`dialogue.en.json`** — índice base (referencia): `hash → texto inglés`.
  El hash = SHA1 del texto inglés exacto (con tokens `{w}`/`{br}`), 12 hex.
- **`dialogue.es.json`** — mapa de traducción de un idioma: `hash → texto`.
  Solo trae las líneas ya traducidas (2 de demo); las que falten caen a inglés
  en runtime.
- **`dialogue_1.xlsx`** — hoja del capítulo para traductores: columnas
  `id · speaker · en · es · de · fr · ja`. El `speaker` es solo contexto (no se
  guarda en el JSON). La tool haría el round-trip xlsx ⇄ json.

## Notas

- La ruta real sería `data/fe5/events/lang/1/dialogue.es.json` (por capítulo,
  carpetas fe4/fe5 separadas).
- Editar el inglés en `events.json` cambia el hash → esa línea vuelve a inglés y
  la tool la marca como pendiente (huérfana la vieja, faltante la nueva).
- El runtime solo necesita `hash → texto`; el `en.json` y el `speaker` del xlsx
  son ayudas para traducir.
