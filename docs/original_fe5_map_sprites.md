# Map sprites — set Original, FE5 (estado)

Ripeo de map sprites originales (SNES, Thracia 776) para el set **Original**, en
`assets/Original/fe5/map_sprites/`. Misma resolución que FE4
(`Unit._resolve_map_sprite_nid`): `{Clase}_{Personaje}` → `{Clase}{Género}` →
`{Clase}`. Cada entrada necesita **`-stand.png` + `-move.png`**.

## ✅ Clases completas (40 / 60)

Archer · ArcherKnight · Armour · AxeKnight · Bandit · Baron · BowKnight · Cavalier ·
DarkBishop · DarkMage · DragonKnight · DragonMaster · DukeKnight · FalconKnight ·
Fighter · FreeKnight · General · GreatKnight · Hero · HighPriest · HighPriestFemale ·
LanceKnight · LightPriestFemale · LoptoMage · LordLeaf · LordSeliph · Mage · MageKnight ·
Paladin · Priest · PriestFemale · Ranger · Rogue · Sage · Sniper · Swordfighter ·
Swordmaster · Thief · Troubadour · Warrior

Renombrados: `Lord`→`LordSeliph` (Seliph), `Prince`→`LordLeaf` (Leif),
`LoptrianMage`→`LoptoMage`. `LordLeaf` = clase de Leif (nid `LordLeaf` →
MasterKnight; en este remake Leif es el "Prince"/lord de partida que promociona a
MasterKnight, como en FE4).

## ✅ Personaje-específicos

- `Mage_Homer`

## ⚠️ A corregir

- **Dancer** — solo `-stand`, falta **`Dancer-move.png`**.

## ⏳ Pendientes (confirmadas faltantes)

- [ ] Ballistician *(clase Ballistae)*
- [ ] Barbarian
- [ ] Bard
- [ ] Berserker
- [ ] Bishop
- [ ] Citizen *(clase Tester)*
- [ ] DarkPrince
- [ ] DragonRider
- [ ] Emperor
- [ ] LordKnight
- [ ] MageFighter
- [ ] MasterKnight
- [ ] Mercenary
- [ ] PegasusKnight
- [ ] PegasusRider
- [ ] Pirate
- [ ] Princess
- [ ] Queen
- [ ] Soldier

## Notas

- Renombrados aplicados: Priestess→`PriestFemale`, HighPriestess→`HighPriestFemale`,
  LightPriestess→`LightPriestFemale`.
- Tras añadir/renombrar PNGs, abrir el proyecto en Godot para reimportar.
