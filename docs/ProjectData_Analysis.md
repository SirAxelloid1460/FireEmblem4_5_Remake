# Análisis de Archivos del Proyecto LT
## game_data_fe4 + game_data_fe5 + app + utilities

---

## 1. ESTRUCTURA GENERAL

Esto es un proyecto **LT-maker** (versión 1.2.2.2, engine 2023.04.11) con dos proyectos separados:
- `GotHW` — Fire Emblem IV Remake: Genealogy of the Holy War (última modificación: 2023-09-24)
- `Thracia776` — Fire Emblem V Remake: Thracia 776 (última modificación: 2024-07-12)

Ambos proyectos comparten el mismo engine LT-maker. Los datos están en JSON (formato LT-maker moderno, no los XMLs/TXTs del legacy que analizamos antes). El importador de Godot que creamos lee el formato legacy — **necesitaremos un segundo parser para el formato JSON de LT-maker**.

---

## 2. ECUACIONES DE COMBATE (identicas en FE4 y FE5)

```
ATTACK_SPEED  = SPD                          ← Sin penalización por peso (simplificado)
DEFENSE_SPEED = SPD
HIT           = SKL*2 + LCK//2
AVOID         = SPD*2 + LCK
CRIT_HIT      = SKL//2
CRIT_AVOID    = LCK
DAMAGE        = STR
DEFENSE       = DEF
MAGIC_DAMAGE  = MAG
MAGIC_DEFENSE = RES
MAGIC_RANGE   = max(5, MAG//2)
CRIT_MULT     = 3                            ← Crítico = ×3 (estilo GBA)
SPEED_TO_DOUBLE = 4                          ← AS ≥ rival+4 para doblar
CRITSKL       = SKL*1.5                      ← Fórmula de crit para la skill Critical
HIT_WRATH     = 66 + SKL + LCK              ← Fórmula de hit cuando Wrath activa
WRATH         = 50                           ← Threshold de HP para Wrath (50%)
```

**Observación importante:** `ATTACK_SPEED = SPD` sin restar peso. El sistema de peso/CON que discutimos NO está implementado en el proyecto LT actual. El ATTACK_SPEED es directamente el SPD. Decisión a tomar: ¿mantener esto o añadir la penalización por peso que diseñamos?

---

## 3. WEAPON RANKS

```
D    → requiere 1 punto
C    → requiere 51 puntos
B    → requiere 126 puntos
A    → requiere 226 puntos
Holy → requiere 1023 puntos   ← Rango especial para Armas Sagradas
```

El rango `Holy` (★) es el equivalente al rango `*` del spreadsheet. Solo accesible con Major Holy Blood.

---

## 4. STATS

```
HP   cap: 60 (base) / 80 (promovidos) / 90 (tier 3) — según clase
STR  cap: 30
MAG  cap: 30
SKL  cap: 30
SPD  cap: 30
LCK  cap: 30
DEF  cap: 30
RES  cap: 30
CON  cap: 25
MOV  cap: 15
```

---

## 5. CONSTANTES — DIFERENCIAS FE4 vs FE5

Solo hay 8 diferencias entre ambos proyectos:

| Constante | FE4 | FE5 | Significado |
|---|---|---|---|
| `promote_skill_inheritance` | True | False | FE4: las skills se heredan al promover; FE5: no |
| `generic_feats` | True | False | FE4 tiene sistema de "feats" genéricos; FE5 no |
| `sound_room_in_codex` | True | False | FE4 tiene sala de sonido; FE5 no |
| `double_splash` | True | False | FE4 tiene daño splash doble; FE5 no |
| `exp_curve` | 0.102 | 0.1 | Curva de EXP ligeramente diferente |
| `heal_min` | 5 | 10 | HP mínimo curado por staves: FE5 cura más de mínimo |

El resto de las ~50 constantes son idénticas entre ambos proyectos.

---

## 6. SKILLS — INVENTARIO COMPLETO

### Skills compartidas (FE4 y FE5 idénticas):
`Ambush, Ambush_proc, Astra, Astra_proc, Avoid10, Awareness, Bargain, Barrier_Ring, Barrier_Sword, Berserk, Canto, Canto_Plus, Charge, Charisma, Charisma_child, Circlet, Critical, Devil, Elite_Skill, FakeCharge, Flying, Forest, Fort, Gate, Hel, Holy_Ring, Leg_Ring, Life, Locktouch, Loptyr_negative, Loptyr_positive, Luna, Luna_proc, Magic_Ring, Magic_Up, Miracle, Mountain, Pavise, Pavise_proc, Peak, Petrify, Poisoned, Power_Ring, Prayer, Recover, Refresh, Regeneration, Rescue, Return, Shield_Ring, Silence, Skill_Ring, Sleep, Sol, Sol_proc, Speed_Ring, Steal, Stunned, Throne, Torch, Wrath`

### Skills de Armas Sagradas (ambos proyectos):
`Balmung, Blaggi_Sword, Bragi_Sword, Darkness_Sword, Forseti, Gae_Bolg, Gungnir, Helswath, Holy_Sword, Ichival, Loptyr_Sword, Mjolnir, Mystletainn, Naga, Tyrfing, Valflame`

### Scrolls de Cruzada (ambos proyectos):
`Baldr_Scroll, Blaggi_Scroll, Dainn_Scroll, Fjalar_Scroll, Heim_Scroll, Hezul_Scroll, Neir_Scroll, Njorun_Scroll, Od_Scroll, Sety_Scroll, Thrud_Scroll, Ulir_Scroll`

### Solo FE5:
- `ChangeSniper` — skill de cambio de clase a Sniper (Fergus/Dalsin)
- `ChangeSwordmaster` — skill de cambio de clase a Swordmaster (Mareeta)

### Solo FE4:
- `StealAway` — variante especial de robo de FE4
- `Inmortal` — skill de invulnerabilidad (bosses finales)
- `LuckilyLight` — skill especial de Julia/Naga
- `No_BigShields` — niega Big Shield del enemigo
- `NotHoly` — marca unidades que no pueden usar armas sagradas

---

## 7. ITEMS — DIFERENCIAS FE4 vs FE5

### Solo en FE5 (9 items nuevos):
```
Ankle_Bracelet    → Variante de booster de stat
Bridge_Key        → Llave específica de puente
ChangeSniper      → Item que cambia clase a Sniper
ChangeSwordmaster → Item que cambia clase a Swordmaster
Chest_Key         → Llave de cofre separada de Door_Key
Door_Key          → Llave de puerta separada
Life_Earring      → Pendiente con efecto Life
Power_Earring     → Pendiente con bono de STR
Return1/Return2   → Dos versiones del Return staff
ReturnRing1/2     → Anillos de retorno
Shield_Earring    → Pendiente con bono de DEF
Torch_item        → Antorcha como item (no staff)
Torch_staff       → Antorcha como staff (separados en FE5)
```

### Solo en FE4 (6 items):
```
Defense_Earring   → Pendiente de DEF (FE5 usa Shield_Earring)
HP_Earring        → Pendiente de HP
Key               → Llave genérica (FE5 las separa en Door/Chest/Bridge)
StealAway         → Item de robo especial
Strength_Earring  → Pendiente de STR (FE5 usa Power_Earring)
Torch             → En FE4 es un solo item; FE5 lo separa en item + staff
```

**Total items:** FE4 tiene 193, FE5 tiene 202.

---

## 8. CLASES

### Solo en FE5 (no en FE4):
- `BThief_Lara` — variante especial de Thief para Lara
- `Dancer_Lara` — variante especial de Dancer para Lara

Lara tiene su propia rama de clase única en FE5 porque puede ser tanto Thief como Dancer dependiendo de cómo se le reclute.

### Estructura de clases Paladin (ejemplo real del JSON):
```
APaladin (masculino):
  tier: 2, promotes_from: Cavalier
  bases: HP46, STR10, MAG5, SKL11, SPD11, DEF12, RES7, CON11
  growths: HP100%, STR30%, MAG10%, SKL30%, SPD30%, DEF30%, RES10%
  promotion_gains: STR+2, MAG+3, SKL+3, SPD+3, DEF+3, RES+5

BPaladin (femenino):
  Misma estructura pero con stats base diferentes
```

### MOV = 90 en los datos
El `MOV: 90` en los JSONs es el movimiento del montado (movimiento real de juego). Los non-mounted tienen valores bajos (5-8). Es un valor interno de LT, no literal.

---

## 9. UNIDADES FE4

### Personajes de gen 1 implementados:
`Sigurd, Noish, Alec, Arden, Finn, Midir, Erinys, Lewyn, Holyn, Azel, Jamke, Claude, Beowulf, Lex, Dew, Aideen, Ayra, Brigid, Tailtiu, Sylvia, Deirdre, Quan, Ethlyn`

### Bosses/NPCs implementados:
`Arvis, Chagall1/2, Clement, DiMaggio, Elliot, Eva, Eve, Gandolf, Gerrard, Genoaguard, Kinbois, Macbeth, Nordion Guard, Phillip, Sandima, Voltz, Zain, Boldor, AlvaFE4`

### Unidades genéricas: `0, 1` (genéricos)

### Sigurd — stats reales del proyecto:
```
Nivel 1, clase LordKnight, tags: [Lord, BaldrHeir]
HP:35 STR:14 MAG:0 SKL:11 SPD:12 LCK:7 DEF:9 RES:3 CON:7
Growths: HP110%, STR50%, MAG5%, SKL50%, SPD30%, LCK40%, DEF40%, RES5%
Inventario: Steel Lance, Steel Sword
```

---

## 10. SISTEMA DE SOPORTES — FE4

Configuración real del proyecto:

```
combat_convos:         true   ← Conversaciones en combate activadas
base_convos:           0      ← Sin base convos (FE4 no tiene base)
bonus_range:           1      ← El rango del bonus de soporte es 1 tile (adyacente)
growth_range:          99     ← Puntos crecen en todo el mapa (distancia máxima)
chapter_points:        30     ← 30 puntos por capítulo terminado juntos
end_turn_points:       4      ← 4 puntos por turno finalizando adyacentes
combat_points:         0      ← No se ganan puntos en combate
interact_points:       0      ← No se ganan puntos por interacción
rank_limit_per_chapter: 1     ← Máximo 1 nivel de soporte por capítulo
break_supports_on_death: true ← El soporte se rompe si uno muere
bonus_method: "Use Average of Affinity Bonuses"
```

### Rangos de soporte FE4:
Solo dos rangos: `Lover` y `Married`

```
Lover:   requiere 200 puntos — Da bonus de combate
Married: requiere 250 puntos — Relación completa, herencia, gold sharing
```

Los bonuses reales de las afinidades en el proyecto están todos a 0 en las affinidades (se calculan via el sistema de amor, no via afinidades estilo GBA). El sistema de amor FE4 funciona diferente.

---

## 11. NIVELES IMPLEMENTADOS

```
FE4: 0.json, 1.json, 2.json, 3.json, 998.json, 999.json, DEBUG.json
```

Solo los primeros 4 capítulos (Prólogo + caps 1-3) más capítulos especiales/debug. Es un proyecto en desarrollo, no completo.

FE5 tiene una estructura similar pero con más capítulos implementados (la data de FE5 es más reciente, 2024 vs 2023).

---

## 12. FORMATO JSON vs XML — IMPLICACIONES PARA EL IMPORTADOR

El importador de Godot que creamos lee el **formato legacy LT** (XML + TXT). Estos proyectos usan el **formato LT-maker** (JSON). Son distintos.

### Estructura de un item en JSON (LT-maker):
```json
{
  "nid": "Iron Sword",
  "name": "Iron Sword",
  "components": [
    ["weapon", null],
    ["target_enemy", null],
    ["damage", 6],
    ["hit", 75],
    ["weapon_type", "Sword"],
    ["weapon_rank", "D"],
    ["uses", 45],
    ["uses_options", [["LoseUsesOnMiss (T/F)", "F", "..."]]],
    ["weight", 5],
    ["crit", 0],
    ["value", 1620],
    ["min_range", 1],
    ["max_range", 1]
  ]
}
```

### Para importar proyectos LT-maker en Godot necesitamos:
Un segundo parser JSON que lea:
- `items/*.json` → ItemData
- `classes/*.json` → ClassData
- `units/*.json` → UnitData
- `skills/*.json` → StatusData
- `weapons.json` → WeaponTriangle
- `weapon_ranks.json` → WeaponRanks
- `equations.json` → Equations
- `constants.json` → GameConstants
- `terrain.json` → TerrainData
- `support_pairs.json` → SupportEdges
- `affinities.json` → AffinityData
- `levels/*.json` → LevelData

---

## 13. MOTOR LT (app.rar)

El `app.rar` contiene el **código fuente completo de LT-maker**. Archivos clave para referencia:

### Combate:
- `engine/combat/solver.py` — Motor de combate (equivalente al que diseñamos)
- `engine/combat_calcs.py` — Cálculos de combate
- `engine/exp_calculator.py` — Curva de EXP

### Skills:
- `engine/skill_system.py` — Sistema de skills
- `engine/skill_components/` — Todos los componentes de skills

### Items:
- `engine/item_system.py` — Sistema de items
- `engine/item_components/` — Todos los componentes de items

### IA:
- `engine/ai_controller.py` — Controlador de IA
- `engine/ai_state.py` — Estado de IA

### El `engine/combat_calcs.py` es especialmente útil porque contiene las fórmulas reales que se usan en los proyectos de Axel.

---

## 14. UTILITIES

El `utilities.rar` contiene notas de desarrollo internas relevantes:

- `archived_notes/skill_system_notes.txt` — Notas del sistema de skills
- `archived_notes/item_component_list.txt` — Lista de componentes de items
- `archived_notes/combat_animation_notes.txt` — Notas de animación de combate
- `bonus_exp_and_leadership_stars_notes.txt` — Notas sobre EXP bonus y leadership

---

## 15. RESUMEN — PUNTOS CLAVE PARA EL PROYECTO GODOT

### Lo que confirman los datos reales vs lo que diseñamos:

✅ **Confirmado:** Triángulo de armas: +1 ATK / +15 HIT (exactamente como diseñamos)
✅ **Confirmado:** Speed to double = 4 (exactamente como diseñamos)
✅ **Confirmado:** Crit = ×3 (exactamente como diseñamos)
✅ **Confirmado:** HIT = SKL×2 + LCK//2 (exactamente como diseñamos)
✅ **Confirmado:** AVOID = SPD×2 + LCK (exactamente como diseñamos)
✅ **Confirmado:** CRIT formula = SKL//2 (base) / SKL×1.5 (con Critical skill)
✅ **Confirmado:** Wrath threshold = 50% HP, fórmula de hit especial = 66+SKL+LCK

⚠️ **Diferencia:** ATTACK_SPEED = SPD (sin penalización por peso). El proyecto LT actual NO implementa la penalización SPD-max(0,Wt-CON). Decisión: ¿añadirla en Godot o mantener SPD=AS?

⚠️ **Diferencia:** Weapon ranks: D/C/B/A/Holy (no D/C/B/A/S como en GBA). El rango S de GBA no existe aquí — existe el rango Holy (★) solo para Major Blood.

⚠️ **Diferencia:** Solo dos rangos de soporte: Lover y Married. No el sistema C/B/A/S de GBA.

### El importador JSON que necesitamos:
El `LTImporter.gd` actual lee formato legacy (XML/TXT). Necesitamos `LTMakerImporter.gd` que lea el formato JSON de estos proyectos.
