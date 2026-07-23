# Handoff — Deadlords (魔将): nombres distintos FE4 vs FE5

Cómo está implementado que un mismo Deadlord muestre **nombre latino en FE4** y
**número alemán en FE5**, con **stats distintos** por juego. Referencia para las
sesiones de datos y de traducción.

## Concepto

Los 魔将 ("Deadlords") tienen como **nombre original japonés un número alemán**
(アインス = Eins, ツヴァイ = Zwei, ドライ = Drei, フュンフ = Fünf, エルフ = Elf,
ツヴェルフ = Zwölf). Sus localizaciones difieren por juego:

- **FE4** los renombró a **animales en latín** (Mus, Bovis, Tigris, Draco, Canis, Porcus).
- **FE5** conservó los **números alemanes** (Eins, Zwei, Drei, Fünf, Elf, Zwölf).

Son la **misma entidad** (misma katakana), pero el proyecto necesita mostrar
distinto nombre **y** distintos stats según el juego.

## Implementación: dirigida por datos, no por condicionales

No hay lógica tipo `if game == "FE4": name = "Mus"`. En su lugar, **cada Deadlord
existe como dos registros separados** en `data/general/units.json`: uno con
`games: ["FE4"]` y otro con `games: ["FE5"]`. El nombre mostrado y los stats van
**horneados** en cada registro.

El motor elige el registro correcto filtrando por el campo `games`:

```gdscript
# Scripts/GameDatabase.gd
func units_for_game(game: String) -> Array:
    var r := []
    for u in units.values():
        if game in u.games:      # "FE4" o "FE5"
            r.append(u)
    return r
```

Es decir: en un capítulo de FE4 se instancia el registro `games:["FE4"]`
(→ muestra *Mus, Bovis…*) y en uno de FE5 el `games:["FE5"]` (→ *Eins, Zwei…*).

## Tabla de correspondencia

| Katakana (原名) | nid FE4 | name FE4 | clase/nivel FE4 | nid FE5 | name FE5 | clase/nivel FE5 |
|---|---|---|---|---|---|---|
| アインス | `Eins`  | **Mus**    | Baron lv30          | `Ein`      | **Eins**  | Baron lv20     |
| ツヴァイ | `Zwei`  | **Bovis**  | Hero lv30           | `ZweiFE5`  | **Zwei**  | Mercenary lv20 |
| ドライ   | `Drei`  | **Tigris** | Warrior lv30        | `DreiFE5`  | **Drei**  | Warrior lv20   |
| フュンフ | `Funf`  | **Draco**  | Sniper lv30         | `FunfFE5`  | **Fünf**  | Sniper lv20    |
| エルフ   | `Elf`   | **Canis**  | LightPriestess lv30 | `ElfFE5`   | **Elf**   | Sage lv20      |
| ツヴェルフ| `Zwolf` | **Porcus** | Rogue lv30          | `ZwolfFE5` | **Zwölf** | Rogue lv20     |

Notas de nomenclatura de `nid` (deben ser únicos en todo el roster):
- **FE4** usa el número alemán tal cual: `Eins, Zwei, Drei, Funf, Elf, Zwolf`
  (ASCII, sin diéresis: `Funf`, `Zwolf`).
- **FE5** añade sufijo `FE5` (`ZweiFE5, DreiFE5, FunfFE5, ElfFE5, ZwolfFE5`),
  **salvo el #1**, donde FE4 ocupa `Eins` y FE5 usa `Ein` para no chocar.

## Katakana en `docs/name_charts/name_jp.json`

Dos categorías paralelas (misma katakana, distinta clave localizada):
- `FE4 → "Deadlords 魔将 — nombre FE4 (autor)"`: Bovis=ツヴァイ, Canis=エルフ,
  Draco=フュンフ, Mus=アインス, Porcus=ツヴェルフ, Tigris=ドライ.
- `FE5 → "Deadlords 魔将 — nombre FE5 (autor)"`: Drei=ドライ, Eins=アインス,
  Elf=エルフ, Fünf=フュンフ, Zwei=ツヴァイ, Zwölf=ツヴェルフ.

## ⚠️ Pendiente: retrato compartido

Hoy **no existe ningún asset de retrato** para los Deadlords (renderizan en
blanco, sin crash). El campo `portrait_nid` está puesto igual en ambos registros
(el número alemán: `Eins/Zwei/Drei/Funf/Elf/Zwolf`) como *intención* de que
compartan cara, **pero `portrait_nid` es vestigial**: `AssetLoader.get_portrait()`
resuelve por **nid** (`characters/{nid}.png`). Por tanto, cuando se añada el
retrato, el registro FE4 (`nid=Eins`) buscaría `Eins.png` y el FE5 (`nid=Ein`)
buscaría `Ein.png` — **archivos distintos**.

Para que **una sola cara** sirva a ambos, la vía establecida es la tabla
`PORTRAIT_ALIASES` de `AssetLoader.gd` (precedente: `"Robert": "RobertFE5"`,
personaje que también aparece en FE4 y FE5). Habría que añadir, p. ej.:

```gdscript
"Ein":      "Eins",     # FE5 #1  → cara de Eins
"ZweiFE5":  "Zwei",
"DreiFE5":  "Drei",
"FunfFE5":  "Funf",
"ElfFE5":   "Elf",
"ZwolfFE5": "Zwolf",
```

(o duplicar el PNG por cada nid). Mientras no exista el asset, es indiferente.

## Para la sesión de traducción

En `Translations FE45 - Characters.csv`, cada Deadlord necesita **dos claves**
(una por juego) porque el nombre mostrado difiere: FE4 = latín, FE5 = alemán.
La katakana (columna `ja`) es la **misma** para el par.
