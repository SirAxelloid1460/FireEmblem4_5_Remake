# Map sprites — set Original, FE5 (estado)

Ripeo de map sprites originales (SNES, Thracia 776) para el set **Original**, en
`assets/Original/fe5/map_sprites/`. Misma resolución que FE4
(`Unit._resolve_map_sprite_nid`): `{Clase}_{Personaje}` → `{Clase}{Género}` →
`{Clase}`. Cada entrada necesita **`-stand.png` + `-move.png`**.

## ✅ Clases completas (37 / 60)

Archer · ArcherKnight · Armour · AxeKnight · Bandit · Baron · BowKnight · Cavalier ·
DarkBishop · DarkMage · DragonKnight · DragonMaster · DukeKnight · FalconKnight ·
Fighter · FreeKnight · General · GreatKnight · Hero · HighPriest · HighPriestFemale ·
LanceKnight · LightPriestFemale · Mage · MageKnight · Paladin · Priest · PriestFemale ·
Ranger · Rogue · Sage · Sniper · Swordfighter · Swordmaster · Thief · Troubadour · Warrior

## ✅ Personaje-específicos

- `Mage_Homer`

## ❓ A confirmar (subidos, sin NID de clase que case)

En FE5 el protagonista es **Leif**, así que el mapeo NO es necesariamente el de FE4.
Confirmar a qué clase van y renombro:
- `Lord` → ¿`LordLeaf` (Leif) o `LordSeliph`?
- `Prince` → ¿`LordLeaf` / otro?
- `LoptrianMage` → ¿`LoptoMage`? (parece el mismo, "Loptrian" = de Loptous)

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
- [ ] (LoptoMage / LordSeliph / LordLeaf → resueltos si se confirma «A confirmar» arriba)

## Notas

- Renombrados aplicados: Priestess→`PriestFemale`, HighPriestess→`HighPriestFemale`,
  LightPriestess→`LightPriestFemale`.
- Tras añadir/renombrar PNGs, abrir el proyecto en Godot para reimportar.
