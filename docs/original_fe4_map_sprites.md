# Map sprites — set Original, FE4 (estado)

Estado del ripeo de map sprites originales (SNES) para el set gráfico **Original**,
en `assets/Original/fe4/map_sprites/`. El juego busca por `map_sprite_nid` (ver
`data/general/classes.json`), con orden de resolución en `Unit._resolve_map_sprite_nid`:
`{Clase}_{Personaje}` → `{Clase}{Género}` (`Female`/`Male`) → `{Clase}` (universal).

Cada entrada necesita **`-stand.png` + `-move.png`**.

## ✅ Clases completas (45 / 60)

Archer · ArcherKnight · Armour · AxeKnight · Bard · Baron · BowKnight · Cavalier ·
Citizen · DarkBishop · DarkPrince · DragonKnight · DragonMaster · DukeKnight ·
Emperor · FalconKnight · Fighter · FreeKnight · General · GreatKnight · Hero ·
HighPriest · **HighPriestFemale** · LanceKnight · **LightPriestFemale** · LordKnight ·
Mage · MageFighter · MageKnight · MasterKnight · Paladin (F+M) · PegasusKnight ·
Priest · **PriestFemale** · Princess · Queen · Ranger · Rogue · Sage · Sniper ·
Swordfighter · Swordmaster · Thief · Troubadour · Warrior

## ✅ Personaje-específicos presentes

- `LordKnight_Seliph`
- `Mage_Amid`
- `Mage_Tailtiu`

## ⚠️ A corregir

- **Dancer** — solo tiene `-stand.png`, **falta `Dancer-move.png`** (re-ripear el walk).
- **`Lord` y `Prince`** — subidos pero **no casan con ningún `map_sprite_nid`** de clase.
  Probablemente son para `LordSeliph` / `LordLeaf` (ambos pendientes). Confirmar a qué
  clase van y renombrar al NID correcto.

## ⏳ Pendientes (14 clases)

- [ ] Ballistician  *(clase Ballistae)*
- [ ] Bandit
- [ ] Barbarian
- [ ] Berserker
- [ ] Bishop
- [ ] DarkMage
- [ ] DragonRider
- [ ] LoptoMage
- [ ] LordLeaf
- [ ] LordSeliph
- [ ] Mercenary
- [ ] PegasusRider
- [ ] Pirate
- [ ] Soldier

## Notas

- NIDs que **no** coinciden con el nombre de clase (usar el NID en el archivo):
  Priestess→`PriestFemale`, HighPriestess→`HighPriestFemale`,
  LightPriestess→`LightPriestFemale`, Ballistae→`Ballistician`, Tester→`Citizen`.
- Tras añadir/renombrar PNGs hay que **abrir el proyecto en Godot** una vez para
  reimportarlos.
