# Diferencias y Discrepancias entre Formatos
## LT-maker JSON vs LT Legacy XML vs FE4/FE5 vs GBA vs Godot

---

## 1. WEXP — FORMATO EN LT-MAKER JSON

En el formato LT-maker, el `wexp_gain` en **clases** y **unidades** usa `[bool, int]`:

```json
"wexp_gain": {
  "Sword": [true, 126],   ← [puede_usar_este_tipo, wexp_actual_o_requerido]
  "Lance": [true, 126],
  "Axe":   [false, 0],    ← false = clase no puede usar Axe
  "Holy":  [false, 0]
}
```

- `true` = la clase/unidad puede usar ese tipo de arma
- El número es el **wexp actual** para unidades, o el **wexp de inicio** para clases
- Sigurd tiene `"Sword": [true, 1023]` → puede usar Sword, wexp = 1023 = rango Holy (★)

En el **importador actual** leemos esto mal — extrae solo el primer elemento del array como string. **Hay que corregirlo** para distinguir `puede_usar` y `wexp_valor` por separado.

---

## 2. PRF_TAGS — RESTRICCIÓN DE ARMAS SAGRADAS

En LT-maker las Armas Sagradas usan `prf_tags` para restringir quién las puede equipar:

```json
["prf_tags", ["BaldrHeir"]]   ← Solo unidades con tag "BaldrHeir" pueden equipar Tyrfing
["prf_tags", ["OdHeir"]]      ← Balmung solo para OdHeir
["prf_tags", ["DainnHeir"]]   ← Gungnir para DainnHeir
```

En Godot, los tags de sangre sagrada en las unidades son:
`BaldrHeir, OdHeir, HezulHeir, NeirHeir, SetyHeir, HeimHeir, FjalarHeir, BragiHeir, NjörunHeir, UlirHeir, DainnHeir, ThrudHeir`

El tag determina tanto **qué arma sagrada puede equipar** como **qué Holy Blood tiene**. Son la misma cosa. El importador debe leer estos tags para construir el sistema de Holy Blood en Godot.

---

## 3. MAX_LEVEL EN CLASES — DISTINTO A LO ESPERADO

Todas las clases del proyecto tienen `max_level: 19`, **no 30**. Esto significa:

- En LT, nivel 19 = cap antes de necesitar promover (rango 1–19 para T1, etc.)
- El cap "30" que acordamos es el cap **global del juego**, no el cap por clase
- En Godot tendremos: cap de clase = configurable (actualmente 19 en los datos), cap global = 30

**Implicación:** El cap global de 30 que diseñamos es una decisión propia de este proyecto. LT no lo implementa así — en LT el cap por clase es el único límite real.

---

## 4. MCOST.JSON — FORMATO MATRIZ, NO TABLA

El `mcost.json` en LT-maker **NO** es una tabla nombre→costes como en el legacy. Es una **matriz 3D**:

```
mcost[terreno_idx][grupo_mov_idx] = coste
99 = infranqueable
10 = coste 1 (×10 internamente en LT)
20 = coste 2, etc.
```

Los valores están multiplicados por 10 en LT (para evitar decimales). El coste real = valor / 10.

Hay **18 columnas** de movimiento (más grupos que los 9 del legacy):
`LightFoot, Armors, HeavyCav, LightCav, Regular, Mages, Fliers, Bandits, Pirates + variantes`

El importador LT-maker actual **no parsea mcost.json correctamente** — necesita leer la matriz e indexarla por terrain nid ordenado.

---

## 5. AI.JSON — FORMATO COMPLETAMENTE DISTINTO

El formato de IA en LT-maker es radicalmente diferente al legacy:

**Legacy:** `Pursue 3 1 - - 2 20` (ai1, ai2, rangos simples)

**LT-maker:**
```json
{
  "nid": "Pursue",
  "behaviours": [
    {
      "action": "Attack",
      "target": "Enemy",
      "target_spec": ["Team", "player"],
      "view_range": -4,
      "condition": ""
    },
    ...
  ]
}
```

Los `AIPreset` del importador actual no funcionan para LT-maker — están mapeados al formato legacy. Para LT-maker hay que parsear la lista de `behaviours`. El importador retorna `{}` para AI en modo LT-maker, lo cual es correcto provisionalmente.

---

## 6. SKILLS — COMPONENTES REALES VS NUESTRA ESTRUCTURA

Los skills en LT-maker usan componentes Python-evaluables. Algunos ejemplos reales:

| Skill | Componentes reales |
|---|---|
| Wrath | `condition: "unit.get_hp() <= unit.get_max_hp()/3"` + `alternate_crit_accuracy_formula: "WRATH"` |
| Sol | `proc_rate: "SKILL"` + `attack_proc: "Sol_proc"` |
| Ambush | `condition: "unit.get_hp() < unit.stats['HP']//2"` + `defense_pre_proc: "Ambush_proc"` |
| Prayer | `dynamic_avoid: "(11-self.get_hp())*10 if self.get_hp() <= 10"` |
| Charisma | `aura: "Charisma_child"` + `aura_range: 3` + `aura_target: "Ally"` |
| Life | `regeneration: 0.2` (20% HP por turno) |
| Critical | `alternate_crit_accuracy_formula: "CRITSKL"` (usa SKL×1.5) |
| Luna | `proc_rate: "SKILL"` + `attack_proc: "Luna_proc"` + `class_skill: null` |
| Tyrfing (skill de arma) | `stat_change: [["SKL",10],["SPD",10],["RES",20]]` |

**Wrath** activa con HP ≤ 1/3 del máximo (no 50% como en los datos del spreadsheet — hay una discrepancia). En el proyecto LT está codificado como `max_hp / 3`. Hay que decidir cuál usar.

**Armas Sagradas** como Tyrfing son skills que se aplican `on_equip` — le dan bonus de stats mientras se llevan equipadas. No son el arma en sí, sino la skill que activa el arma.

---

## 7. SKILL CHARGE — OCULTA EN EL PROYECTO

Charge tiene `components: [["hidden", null]]` — está implementada como skill oculta, no visible al jugador en el UI. Esto es coherente con FE4/5 donde Charge era una skill que simplemente funcionaba sin que el jugador pudiera verla directamente.

---

## 8. SOPORTES — DOS SISTEMAS PARALELOS QUE CONVIVEN

En LT-maker el proyecto FE4 usa:
- `support_ranks: ["Lover", "Married"]` — solo dos rangos
- `bonus_range: 1` — el bonus SOLO aplica adyacente (1 tile), no en rango 3 como GBA
- `growth_range: 99` — los puntos crecen en todo el mapa (sin límite de distancia)
- `chapter_points: 30` + `end_turn_points: 4` — fuente principal de puntos

Esto es distinto al sistema GBA donde el bonus aplica en rango 3 tiles. En FE4 el bonus de soporte es **solo adyacente**. Para Godot hay que decidir si usar el rango 1 de FE4 o el rango 3 de GBA para los soportes Lover/Married.

---

## 9. ITEMS — `LoseUsesOnMiss` ES CONFIGURABLE POR ARMA

En LT-maker, cada arma tiene una opción explícita:
```json
["uses_options", [["LoseUsesOnMiss (T/F)", "F", "descripción"]]]
```

`"F"` = el arma NO pierde usos al fallar (comportamiento de FE4/5).
`"T"` = el arma SÍ pierde usos al fallar (comportamiento GBA).

En nuestro diseño decidimos que los staves no gastan uso al fallar (FE5). Esto se puede controlar por arma individualmente en Godot, lo cual es mejor que una regla global.

---

## 10. `weapon_rank` EN ITEMS — "Holy" NO ES "S"

En los ítems del proyecto, las armas sagradas no tienen `weapon_rank: "S"`. Tienen `weapon_rank` que no está definido explícitamente (o es `null`/vacío) porque el acceso se controla por `prf_tags`, no por rango de arma.

El rango Holy (★) en **weapon_ranks.json** tiene `requirement: 1023`. Pero las armas sagradas en la práctica no se usan con ese sistema — usan `prf_tags`. Son dos mecanismos distintos que coexisten.

**Para Godot:** el sistema Holy debería funcionar así:
1. El arma sagrada tiene `prf_tags: ["BaldrHeir"]`
2. La unidad tiene `tags: ["BaldrHeir"]` en sus datos
3. Al intentar equipar, se verifica que la unidad tenga el tag
4. El rango `Holy` en `weapon_ranks` es más bien un marcador para mostrar en UI que para control real de acceso

---

## 11. FORMATO MCOST — 99 vs -1

- **Legacy mcost.txt:** `-` = infranqueable
- **LT-maker mcost.json:** `99` = infranqueable (coste real = 9.9, redondeado a "no puede pasar")
- **Nuestro LTDataResources:** usa `-1` para infranqueable

El importador LT-maker necesita convertir `99` a `-1` al leer el mcost.

---

## 12. DIFERENCIA FE4 vs FE5 EN SKILL WRATH

En el proyecto:
- `condition: "unit.get_hp() <= unit.get_max_hp() / 3"` → activa con HP ≤ **33%**

En el spreadsheet de diseño:
- "Siempre crítico cuando HP < (MaxHP/2)+1" → activa con HP ≤ **50%**

El proyecto LT usa 1/3, el spreadsheet dice 1/2. Hay que elegir uno:
- **1/3** = más fiel al FE4 original (el proyecto LT lo implementó así)
- **1/2** = más generoso, más impactante en gameplay

---

## 13. RESUMEN DE CORRECCIONES AL IMPORTADOR

El `LTImporter.gd` necesita estas correcciones para el parser LT-maker:

| # | Problema | Corrección |
|---|---|---|
| 1 | `wexp_gain` lee el array mal | Leer `[bool, int]` → extraer `puede_usar` y `wexp_valor` por separado |
| 2 | `mcost.json` no se parsea | Implementar lectura de matriz 3D con conversión de valores (÷10, 99→-1) |
| 3 | `ai_presets` devuelve `{}` | Parsear formato `behaviours` de LT-maker |
| 4 | `prf_tags` ignorados | Leer y guardar en `ItemData.extra["prf_tags"]` |
| 5 | `uses_options` ignorado | Leer `LoseUsesOnMiss` por arma → `ItemData.loses_uses_on_miss: bool` |

---

## 14. DECISIONES TOMADAS

| # | Discrepancia | Decisión |
|---|---|---|
| 1 | Wrath threshold | **HP ≤ 1/3** — fiel al proyecto LT (más exigente, mayor recompensa) |
| 2 | Rango bonus soporte | **3 tiles** — sistema GBA, más legible para el jugador |
| 3 | Cap de nivel | **max_level: 19 por clase** (LT permite llegar a 20) + **gexp_max: 30** global. Tier 0 especial: Child/Citizen cap en 9 (llegan a 10). El cap 30 es el techo global del juego, no el de cada clase |
| 4 | LoseUsesOnMiss | **Por tipo de arma:** Espadas/Lanzas/Hachas → NO pierden usos al fallar. Arcos → SÍ (se gastan las flechas). Bastones/Magia → SÍ (se gasta la carga mágica) |

---

## 15. RONDA FINAL — HALLAZGOS ADICIONALES

### A. KILL_MULTIPLIER = 3.0, NO 2.5 — CORRECCIÓN NECESARIA
El proyecto LT usa `kill_multiplier: 3.0` (idéntico en FE4 y FE5). El documento de diseño decía ×2.5. **Hay que corregirlo.**

### B. EXP — VALORES REALES COMPLETOS
```
exp_curve       = 0.102 (FE4) / 0.1 (FE5)
exp_magnitude   = 15.0 (ambos)
kill_multiplier = 3.0 (ambos)      ← corregir desde 2.5
boss_bonus      = 55               ← EXP bonus extra al matar un boss (no documentado antes)
min_exp         = 1
miss_wexp       = True             ← weapon XP también al fallar
double_wexp     = True             ← weapon XP doble al doblar
kill_wexp       = True
heal_min        = 5 (FE4) / 10 (FE5)
```

### C. EFFECTIVE DAMAGE — FORMATO LEGADO EN LOS DATOS
Los items usan 3 campos separados (formato antiguo de LT):
- `effective` = bonus de daño fijo adicional (ej. Rapier=5, Hammer=10)
- `effective_tag` = tags objetivo (["Armor"], ["Flying"], ["Mounted"]...)
- `effective_multiplier` = siempre 1 — campo legado sin efecto real

El multiplicador real es **×3** hardcodeado en el engine. La fórmula correcta para Godot:
`effective_damage = (might × 3) + effective_bonus_field`

Arcos tienen `effective` contra ["Flying"] por defecto en el proyecto.

### D. CANTO vs CANTO_PLUS — DOS SKILLS DISTINTAS
- **Canto** — mueve el movimiento restante tras atacar (movimiento parcial post-acción)
- **Canto_Plus** — movimiento completo después de cualquier acción
Cavalier/Troubadour/MageKnight tienen Canto. Paladin/LordKnight/DukeKnight/etc. tienen Canto_Plus.
Son dos implementaciones distintas necesarias en Godot.

### E. STATUS_ON_HOLD vs STATUS_ON_EQUIP — DISTINCIÓN CRÍTICA
- **on_equip**: skill activa SOLO con el arma en el slot activo (armas sagradas, Thief Sword)
- **on_hold**: skill activa con el item en CUALQUIER slot del inventario
  → Todos los Rings (Life, Speed, Magic, Shield, Barrier, Leg, Thief, Prayer) usan `on_hold`
  → Todos los Crusader Scrolls usan `on_hold`
Importante: los Rings y Scrolls NO necesitan estar equipados como arma para funcionar.

### F. DEF_DOUBLE = TRUE
`def_double: True` en FE4 — el defensor puede doblar al atacante si su AS es suficientemente mayor (AS_def ≥ AS_atk + 4). Ya estaba en el solver de LT. Godot debe implementarlo.

### G. REAVER — SOLO MASTER AXE EN EL PROYECTO
Único item con componente `reaver` en todo el proyecto: **Master Axe**. Invierte el triángulo de armas.

### H. BOSS_BONUS = 55 EXP
Matar un boss da 55 EXP adicional sobre el cálculo normal. No estaba documentado anteriormente.

### I. BRAVE_ON_ATTACK — VARIANTE DE BRAVE
`brave_on_attack`: brave solo al atacar, no al contraatacar. El proyecto no la usa actualmente pero existe como componente y puede ser útil para diseño futuro.

### J. GLANCING_HIT = 0 → DESACTIVADO
Glancing hit (daño reducido en golpe rasante) está a 0 en el proyecto. No hay que implementarlo.

### K. MIRACLE — SKILL DE PERSONAJE, NO DE CLASE
Miracle (sobrevivir un golpe letal con 1 HP, una vez por combate) existe pero no está asignada a ninguna clase en el proyecto. Es una skill de personaje específico (Aideen en FE4).

### L. ONELOSSPERCOCOMBAT — OPCIÓN EXISTENTE PERO INUSADA
El componente `uses_options` tiene una segunda opción: `OneLossPerCombat`. Si activada, un arma brave solo pierde 1 uso por combate aunque ataque 2+ veces. Ningún item del proyecto la tiene activada actualmente. Puede ser útil en Godot para diseño futuro.

---

## 16. DECISIONES ADICIONALES A TOMAR

| # | Tema | Contexto |
|---|---|---|
| 1 | kill_multiplier | Corregir de ×2.5 a **×3.0** en GameDesign_MechanicsDoc |
| 2 | boss_bonus | ¿Añadir los 55 EXP de bonus al matar bosses? |
| 3 | Canto vs Canto_Plus | ¿Implementar las dos o solo una versión? |
| 4 | Effective damage | Confirmar fórmula: might×3 + bonus_field |
| 5 | on_hold items | Rings y Scrolls activan desde inventario sin equipar |
