# Name Charts (FE4 / FE5) — referencia de localización

Tablas de nombres oficiales aportadas por el usuario desde la Fire Emblem Wiki.
Cubren **personajes, lugares, títulos/facciones e ítems**, con su forma en
japonés y las distintas romanizaciones/localizaciones.

- `fe4_genealogy.md` — Genealogy of the Holy War (personajes/enemigos).
- `fe5_thracia.md` — Thracia 776 (personajes/enemigos + jefes menores y
  Deadlords confirmados por el autor).
- `fe4_genealogy_full.md` — FE4 **multi-idioma** (Kana·Romaji·NoJ·Fan·NoA·NoE·
  FR·DE·ES·IT): Lugares, Ítems (armas, armas sagradas), Habilidades,
  potenciadores de stats y Clases.
- `fe5_thracia_full.md` — FE5 **multi-idioma** (mismas columnas): Lugares,
  Ítems (armas y objetos), Habilidades y Clases.
- `community_votes.md` — resultados de las votaciones de nombres de la comunidad.
- `name_jp.json` — versión parseada `{ localizado: japonés }` por juego y
  categoría (generada desde los .md; para uso en el juego, p. ej. mostrar el
  nombre original japonés). Regenerar con el script de abajo si se editan los .md.

Los `*_full.md` traen las columnas **FR/DE/ES/IT**, muy útiles para la sesión de
traducción (localización de ítems/clases/lugares).

La columna **Localizado** es la que usa el proyecto (`data/general/units.json` →
`name`). Pendiente: completar los jefes/genéricos menores que aún no están en
estas charts (secciones "Enemies (minor)" de la wiki).
