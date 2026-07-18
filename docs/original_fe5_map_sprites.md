# Map sprites — set Original, FE5 (estado)

Ripeo de map sprites originales (SNES, Thracia 776) para el set **Original**, en
`assets/Original/fe5/map_sprites/`. Misma resolución que FE4
(`Unit._resolve_map_sprite_nid`): `{Clase}_{Personaje}` → `{Clase}{Género}` →
`{Clase}`. Cada entrada necesita **`-stand.png` + `-move.png`**.

## ✅ Clases completas (39 / 60)

Archer · ArcherKnight · Armour · AxeKnight · Bandit · Baron · BowKnight · Cavalier ·
DarkBishop · DarkMage · DragonKnight · DragonMaster · DukeKnight · FalconKnight ·
Fighter · FreeKnight · General · GreatKnight · Hero · HighPriest · HighPriestFemale ·
LanceKnight · LightPriestFemale · LoptoMage · LordLeaf · Mage · MageKnight · Paladin ·
Priest · PriestFemale · Ranger · Rogue · Sage · Sniper · Swordfighter · Swordmaster ·
Thief · Troubadour · Warrior

Nota: `LordLeaf` = clase de **Leif** (nid `LordLeaf` → MasterKnight; en este remake
Leif es "Prince"/lord de partida que promociona a MasterKnight como en FE4).

## ✅ Personaje-específicos

- `Mage_Homer`

## ❓ A confirmar

- `Prince` (subido) — **no es una clase** en los datos, y Leif ya queda cubierto por
  `LordLeaf`. ¿A quién es este sprite (¿Seliph en el endgame de FE5?) o se descarta?

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
