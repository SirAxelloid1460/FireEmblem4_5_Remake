# Paletas de equipo (16 colores) — fuente para el palette-swap

Nuestros map sprites usan la paleta **GBA Player** (16 colores). El recolor por
equipo mapea, índice a índice, `Player[i] → Equipo[i]`.

**Convención de equipos del proyecto: `player / enemy / other / ally`**
(en `Unit.team_palette_index()`):

| team | paleta | color |
|---|---|---|
| `player` | 0 Player | azul |
| `enemy` | 1 Enemy | rojo |
| `ally` | 2 Ally | verde (aliados NPC) |
| `other` | 3 Other | dorado (neutrales, p.ej. `MackilyNeutral`/`AnphonyNeutral` en FE4 cap 2) |

> **LT → proyecto** (remapeado en `tools/build_levels.py` `TEAM_REMAP` y ya aplicado
> a los `data/*/levels/*.json`): LT `other` → `ally`, LT `enemy2` → `other`.
> (`player`/`enemy` sin cambio.) Las claves de música LT (`other_phase`,
> `enemy2_phase`…) se dejan tal cual: son metadata del nivel, no se leen por nombre.

Estado **Used** (gris) = `team` uniform 4, se aplica cuando la unidad ya actuó
(no es un equipo, es un estado sobre cualquier paleta).

- **Player/Enemy/Ally/Used**: exactos de `gba_team_palettes.png` (GBA).
- **Other**: GBA lo tenía vacío → derivado del dorado SNES de FE4
  (`fe4_mapsprites_*.png`), mapeando la rampa azul de Player a dorado por
  luminancia, sólo en los índices de equipo.

Índices de color de equipo (los que cambian): **[1, 2, 3, 7, 8, 9, 10, 11]**.
El resto (0,4,5,6,12,13,14,15 = piel/cuero/grises de arma/blancos/contorno) NO
se recolorea (salvo Ally/Used, que tiñen algunos grises levemente — ver tabla).

| idx | Player | Enemy | Ally | Other | Used | equipo |
|----:|--------|-------|------|-------|------|:------:|
| 0 | `80A080` | `80A080` | `80A080` | `80A080` | `80A080` | (transp.) |
| 1 | `584878` | `684860` | `385038` | `625A00` | `404040` | ★ |
| 2 | `90B8E8` | `C0A8B8` | `98C880` | `D1B548` | `787878` | ★ |
| 3 | `D8E8F0` | `E0E0E0` | `D8F8B8` | `FBE193` | `B8B8B8` | ★ |
| 4 | `706060` | `706060` | `585850` | `706060` | `505050` | |
| 5 | `B09058` | `B09058` | `A08840` | `B09058` | `808080` | |
| 6 | `F8F8D0` | `F8F8D0` | `F8F8C0` | `F8F8D0` | `C8C8C8` | |
| 7 | `383890` | `602820` | `205010` | `534600` | `484848` | ★ |
| 8 | `3850E0` | `A83028` | `089000` | `686300` | `585858` | ★ |
| 9 | `28A0F8` | `E01010` | `18D010` | `9B901C` | `989898` | ★ |
| 10 | `18F0F8` | `F85048` | `50F838` | `D0B447` | `B8B8B8` | ★ |
| 11 | `E81018` | `38D030` | `0078C8` | `615900` | `707070` | ★ |
| 12 | `F8F840` | `F8F840` | `E0F828` | `F8F840` | `C8C8C8` | |
| 13 | `808870` | `808870` | `808870` | `808870` | `808870` | |
| 14 | `F8F8F8` | `F8F8F8` | `F8F8F8` | `F8F8F8` | `D0D0D0` | |
| 15 | `403838` | `403838` | `384038` | `403838` | `403838` | |

## Referencia SNES FE4 (extraída por correspondencia de píxel)
Rampa azul principal SNES Player → equipos:
- `4048F8` → Other `787800` · Enemy `A83818` · Ally `389848`
- `101850` → Other `382000` · Enemy `481018` · Ally `083010`
- `B0D0F8` → Other `F8D068` · Enemy `E8B8B0` · Ally `A8E0B8`

Anclas de la rampa dorada (Other) usadas para derivar: `1C1000 / 382000 / 787800 / F8D068 / FFF0B8` por luminancia.

> Mockup visual: `palette_mockup.png`.
