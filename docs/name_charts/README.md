# Name Charts (FE4 / FE5) — referencia de localización

Tablas de nombres oficiales aportadas por el usuario desde la Fire Emblem Wiki.
Cubren **personajes, lugares, títulos/facciones e ítems**, con su forma en
japonés y las distintas romanizaciones/localizaciones.

- `fe4_genealogy.md` — Genealogy of the Holy War.
- `fe5_thracia.md` — Thracia 776.
- `name_jp.json` — versión parseada `{ localizado: japonés }` por juego y
  categoría (generada desde los .md; para uso en el juego, p. ej. mostrar el
  nombre original japonés). Regenerar con el script de abajo si se editan los .md.

La columna **Localizado** es la que usa el proyecto (`data/general/units.json` →
`name`). Pendiente: completar los jefes/genéricos menores que aún no están en
estas charts (secciones "Enemies (minor)" de la wiki).
