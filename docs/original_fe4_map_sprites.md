# Map sprites — set Original, FE4 (estado)

Ripeo de map sprites originales (SNES) para el set **Original**, en
`assets/Original/fe4/map_sprites/`. El juego busca por `map_sprite_nid`
(`data/general/classes.json`), orden en `Unit._resolve_map_sprite_nid`:
`{Clase}_{Personaje}` → `{Clase}{Género}` (`Female`/`Male`) → `{Clase}`.
Cada entrada necesita **`-stand.png` + `-move.png`**.

## ✅ Clases completas (47 / 60)

Archer · ArcherKnight · Armour · AxeKnight · Bard · Baron · BowKnight · Cavalier ·
Citizen · DarkBishop · DarkPrince · DragonKnight · DragonMaster · DukeKnight ·
Emperor · FalconKnight · Fighter · FreeKnight · General · GreatKnight · Hero ·
HighPriest · HighPriestFemale · LanceKnight · LightPriestFemale · LordKnight ·
LordLeaf · LordSeliph · Mage · MageFighter · MageKnight · MasterKnight · Paladin (F+M) ·
PegasusKnight · Priest · PriestFemale · Princess · Queen · Ranger · Rogue · Sage ·
Sniper · Swordfighter · Swordmaster · Thief · Troubadour · Warrior

## ✅ Personaje-específicos

- `LordKnight_Seliph` · `Mage_Amid` · `Mage_Tailtiu`

## ⚠️ A corregir

- **Dancer** — solo `-stand`, falta **`Dancer-move.png`** (re-ripear el walk; el
  origen estaba roto).

## ⏳ Pendientes (12 clases)

- [ ] Ballistician  *(clase Ballistae)*
- [ ] Bandit
- [ ] Barbarian
- [ ] Berserker
- [ ] Bishop
- [ ] DarkMage
- [ ] DragonRider
- [ ] LoptoMage
- [ ] Mercenary
- [ ] PegasusRider
- [ ] Pirate
- [ ] Soldier

## Notas

- Renombrados aplicados: Priestess→`PriestFemale`, HighPriestess→`HighPriestFemale`,
  LightPriestess→`LightPriestFemale`, Lord→`LordSeliph`, Prince→`LordLeaf`, y se
  quitó un espacio de `LordKnight_ Seliph-move`.
- NIDs que no coinciden con el nombre de clase: Ballistae→`Ballistician`,
  Tester→`Citizen`.
- Tras añadir/renombrar PNGs, abrir el proyecto en Godot para reimportar.
