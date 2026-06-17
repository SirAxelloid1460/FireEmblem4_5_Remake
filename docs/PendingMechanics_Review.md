# Revisión Final — Gaps, Inconsistencias y Pendientes
## Lo que falta implementar, está mal, o nunca se discutió

---

## 1. SKILLS MENCIONADAS EN EL DOCUMENTO PERO NO EN EL COMBATSYSTEM

Estas skills aparecen en el documento de diseño pero tienen **0 referencias** en `CombatSystem.gd`:

| Skill | Estado | Qué hace | Dónde va |
|---|---|---|---|
| **Adept** | ❌ Sin implementar | Chance SKL% de un segundo ataque inmediato antes del contraataque | CombatSystem — durante attacker phase |
| **Accost** | ❌ Sin implementar | Si puedes doblar, en vez del segundo ataque normal hace una secuencia adicional | CombatSystem — double phase |
| **Pavise** | ❌ Sin implementar | Chance LVL% de anular completamente un golpe físico | CombatSystem — en execute_attack del defensor |
| **Nihil** | ❌ Sin implementar | Niega todas las skills proc del enemigo durante ese combate | CombatSystem — pre-combat check |
| **Paragon** | ❌ Sin implementar | Doble EXP (igual que Elite — son la misma cosa con distinto nombre) | _finalize_exp |
| **Refresh** | ❌ Sin implementar | El Dancer refresca a unidades adyacentes ya movidas | GameManager / TurnSystem |
| **Steal** | ❌ Sin implementar | Puede robar items no equipados de enemigos más lentos | Acción de mapa, no combate |
| **Desperation** | ❌ Sin implementar | Si HP ≤ 50%, el segundo ataque sale ANTES del contraataque del enemigo | CombatSystem — orden de combate |

**Notas:**
- **Paragon y Elite** son exactamente lo mismo. El LT tiene `Elite_Skill` con `exp_multiplier: 2.0`. Paragon es el nombre GBA del mismo efecto. Unificar como "Elite/Paragon" o elegir uno.
- **Adept** en el documento está descrito como "segundo ataque inmediato" — en el LT no existe como skill, pero Astra hace exactamente eso (5 ataques). Adept sería la versión de 1 ataque extra.
- **Accost** no existe en LT. Es una skill inventada para el proyecto — hay que definir exactamente cómo difiere del doble ataque normal.

---

## 2. TERRAIN BONUSES — NO IMPLEMENTADOS EN COMBATSYSTEM

El documento menciona `TerrainDEF` en la fórmula de daño pero **el CombatSystem no lo calcula ni lo pasa**. Los terrenos en LT sí tienen bonuses reales:

| Terreno | DEF bonus | AVO bonus | Regeneración |
|---|---|---|---|
| Plain | +0 | +0 | — |
| Forest | +1 | +20 | — |
| Mountain | +1 | +30 | — |
| Peak | +2 | +40 | — |
| Fort | +3 | +20 | 75% HP/turno |
| Gate | +3 | +20 | 20% HP/turno |
| Throne | +3 | +10 | 20% HP/turno |
| Lake/Sea/House/Village/Arena | +0 | +10 | — |

**Lo que falta en Godot:**
1. `calculate_hit()` debe restar el terrain AVO bonus del defensor
2. `_calculate_damage()` debe restar el terrain DEF bonus
3. El `GameManager` debe aplicar la regeneración al inicio del turno si la unidad está en Fort/Gate/Throne
4. El `preview_combat()` debe mostrar el terrain bonus en el UI

**Corrección necesaria en `calculate_hit`:**
```gdscript
var terrain_avoid := _get_terrain_avoid(defender)
var avoid := (calculate_attack_speed(defender) * 2) + defender.luck + terrain_avoid
```

**Corrección necesaria en `_calculate_damage`:**
```gdscript
var terrain_def := _get_terrain_def(attacker, defender)  # 0 si efectivo (effective ignora terrain)
var effective_def := int(def_stat * def_multiplier) + terrain_def
```

---

## 3. CONVOY / SUMINISTROS — NO DOCUMENTADO

El documento no menciona el **Convoy**. En FE GBA existe un convoy compartido (baúl) accesible en prep screen donde las unidades pueden guardar y sacar items. En FE4 no había convoy — cada unidad llevaba sus 5 items y el Pawn Shop era la única forma de transferir.

**Decisión pendiente:** ¿hay convoy compartido (GBA) o no (FE4)?

---

## 4. PAWN SHOP — DOCUMENTADO PERO NO IMPLEMENTADO

El documento menciona la fragua (repair) pero no el **Pawn Shop** explícitamente como sistema de transferencia de items. En FE4:
- Solo puedes pasar items entre unidades vendiéndolos al Pawn Shop y comprándolos de nuevo
- El Pawn Shop cobra el 50% del valor al vender y el 100% al comprar

En GBA el intercambio es libre entre unidades adyacentes. El documento dice "pool de oro compartido" (GBA) pero no define si el intercambio de items es libre o via Pawn Shop.

**Decisión pendiente:** ¿intercambio libre de items (GBA) o solo via Pawn Shop (FE4)?

---

## 5. SKILLS DE LT NO DOCUMENTADAS — MECÁNICAS PERDIDAS

Estas skills existen en el proyecto LT pero **nunca se discutieron**:

### Rescue (penalización por cargar unidad)
```
Rescue skill: stat_multiplier {SKL: 0.5, SPD: 0.5}
```
Cuando una unidad rescata a otra, automáticamente recibe la skill `Rescue` que le reduce SKL y SPD a la mitad. **Esto NO está en el CombatSystem actual.** La fórmula de AVOID y HIT no lo tiene en cuenta.

### Throne (bonus de regeneración especial)
```
Throne: regeneration 20%, avoid +10, DEF +3
```
El Throne es distinto del Gate — da menos AVO pero es recuperable (el líder en su trono se cura). No estaba separado del Gate en el documento.

### Devil weapons
La skill `Devil` existe en LT pero sus componentes están vacíos `[]`. Significa que la mecánica del Devil Axe (puede hacerte daño a ti mismo) estaba pendiente en LT. En Godot hay que implementarla: al golpear, hay un % de que el daño te lo haga a ti en vez de al enemigo.

### NotHoly — restricción de rango de armas sagradas
```
NotHoly: wexp_multiplier=0, condition: wexp >= 226 (rango A)
```
Si una unidad sin sangre sagrada llega a rango A en un tipo de arma, la skill `NotHoly` se activa y le impide ganar más XP de arma (techo en A, nunca puede llegar a S/Holy). Esto es un sistema de restricción que **no está documentado ni implementado**.

### FakeCharge
Existe como skill oculta `[hidden]` — probablemente un placeholder para IA que simula Charge. Ignorable.

### Elite_Skill — tiene GROWTH BONUS no documentado
```
Elite_Skill: exp_multiplier=2.0 + growth_change {todos los stats +10%}
```
¡La skill Elite no solo da doble EXP — también da +10% a TODOS los growths mientras se lleva! Esto es un bonus significativo que nunca se mencionó.

### Charisma_child — la implementación interna de Charisma
```
Charisma_child: hit +15, avoid +15
```
El aura de Charisma se implementa en LT como la skill `Charisma` que aplica `Charisma_child` a todos los aliados en rango. El bonus real es +15 HIT y +15 AVOID (no +10 como pusimos en el documento). Hay discrepancia — el documento dice +10, LT dice +15.

---

## 6. MECÁNICAS DE FE4/FE5 NUNCA DISCUTIDAS

### A. Leadership Stars (Estrellas de Mando) — FE4/FE5
En los juegos originales, ciertos líderes tienen "Leadership Stars" (★) que dan bonus de HIT/AVO a todas las unidades aliadas en el campo. El LT tiene `lead: False` — está desactivado. El documento lo menciona brevemente y lo "elimina".

**¿Realmente queremos eliminarlo o hacemos algo con él?** El sistema de Charisma ya cubre parte de esto. Si se elimina, documentarlo explícitamente como decisión.

### B. Fog of War — FE5
FoW está referenciado en items (Torch) pero **nunca se define la mecánica en el documento**:
- ¿Se implementa FoW en algunos capítulos?
- ¿Cuál es el rango de visión base de cada unidad?
- ¿Los voladores ven más? ¿Los Thieves también?
- En FE5 el rango base era 3 tiles, Torch lo sube a 10 decreciente

### C. Gaiden Chapters / Capítulos Opcionales
FE5 los introdujo con condiciones de desbloqueo únicas. El documento no los menciona en absoluto. ¿Habrá capítulos opcionales con condiciones de acceso?

### D. Captura de Castillos — Objetivos de capítulo FE4
FE4 tenía múltiples castillos en cada capítulo que conquistar. Capturar cada uno da acceso a sus servicios. El documento no define la mecánica de **victoria del capítulo** ni si hay multi-objetivo de castillos.

### E. Gold Sharing FE4 — Parejas y Thieves
En FE4, las parejas pueden compartir oro directamente (estando adyacentes). Los Thieves pueden dar oro a cualquier unidad adyacente. El documento dice "pool compartido" (GBA) — ¿esto se elimina o se mezcla?

### F. Substitutes (Personajes Sustitutos)
Si un personaje de gen 1 muere o no se casa, aparece un sustituto genérico en gen 2. El documento lo menciona brevemente en el análisis de mecánicas pero **nunca define si el proyecto lo implementa o no**.

### G. Ballista como clase/unidad
La Ballista es una clase Tier 0 en el spreadsheet con MOV=0 y solo Bow C. Pero nunca se define cómo funciona en mapa: ¿Es una unidad enemiga fija? ¿Puede ser capturada? ¿Cómo interactúa con el sistema de movimiento?

### H. Escape Maps (FE5)
FE5 tenía capítulos de "Escape" donde el objetivo era llegar a un punto con Leif, no matar al jefe. El documento no los menciona.

### I. Weapon XP de Staves — por rango
En FE5 los staves dan weapon XP escalado por rango: E=1, D=2, C=3, B=4, A=5, *=10. El documento solo menciona que los staves dan EXP, pero no el WXP escalado por rango.

---

## 7. INCONSISTENCIAS DETECTADAS

| # | Inconsistencia | Fuente A | Fuente B | Decisión |
|---|---|---|---|---|
| 1 | Charisma bonus | Documento: +10 HIT/AVO/CRIT/CRIT_AVO | LT: +15 HIT/AVO (Charisma_child) | ¿+10 o +15? |
| 2 | Wrath en docs vs CombatSystem | Documento: "HP ≤ 25%" | CombatSystem: `HP ≤ max_hp / 3` (33%) | LT usa 1/3 — corregir el documento |
| 3 | Elite skill | Documento: solo doble EXP | LT: doble EXP + +10% a todos los growths | Confirmar si queremos el growth bonus |
| 4 | Orden de combate (Brave) | Documento: "Brave repiten el ciclo antes del contra" | CombatSystem: Brave da 2 ataques antes del contra, luego sigue | Alineado, solo el doc está impreciso |
| 5 | Terrain DEF en fórmula | Documento menciona TerrainDEF | CombatSystem no lo calcula | Implementar |
| 6 | Sword skills (Moonlight/Sun/Shooting Star) | Documento: "activación SKL%" | CombatSystem: proc al inicio del combate, mutuamente exclusivas | Correcto, solo falta documentar mejor |

---

## 8. RESUMEN DE ACCIONES

### Implementar en CombatSystem.gd:
- [ ] Terrain DEF/AVO bonus en las fórmulas
- [ ] Pavise (chance LVL% de negar un golpe)
- [ ] Nihil (niega skills proc del enemigo)
- [ ] Desperation (segundo ataque antes del contra si HP ≤ 50%)
- [ ] Rescue penalty (SKL/2, SPD/2 al cargar unidad)
- [ ] Devil weapons (daño puede redirigirse al usuario)
- [ ] NotHoly (techo de rango A para unidades sin sangre sagrada)

### Implementar fuera del CombatSystem:
- [ ] Adept (acción de mapa o skill de turno)
- [ ] Refresh (Dancer — acción de mapa)
- [ ] Steal (acción de mapa)
- [ ] Terrain regeneration (Fort/Gate/Throne — inicio de turno)
- [ ] Convoy (decidir si existe)

### Decisiones pendientes:
- [ ] Charisma: ¿+10 o +15?
- [ ] Wrath: corregir documento a HP ≤ 1/3
- [ ] Elite: ¿incluir el growth bonus de +10% a todos los stats?
- [ ] Paragon vs Elite: ¿son lo mismo? ¿uno reemplaza al otro?
- [ ] Intercambio de items: ¿libre (GBA) o solo via Pawn Shop (FE4)?
- [ ] Convoy: ¿existe o no?
- [ ] Fog of War: ¿se implementa? ¿rango base de visión?
- [ ] Leadership Stars: ¿eliminar definitivamente o adaptar?
- [ ] Gold sharing entre parejas/thieves: ¿mantener o pool global?
- [ ] Substitutes gen 2: ¿implementar o no?
- [ ] Ballista en mapa: comportamiento exacto
- [ ] Escape maps: ¿tipo de objetivo disponible?
