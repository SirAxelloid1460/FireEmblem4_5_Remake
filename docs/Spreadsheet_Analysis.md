# Análisis del Spreadsheet del Proyecto
## Genealogy + Thracia Data — Resumen por hoja

---

## HOJA 1 — CLASES (ya analizada via web)

### Sistema de tiers
El proyecto usa **4 tiers** de clases, no 2 como GBA:

```
Tier 0  → Clases "trainee" / base débil (Citizen, Ballista, Pegasus Rider, Dragon Rider)
Tier 1  → Clases base estándar (Lord, Cavalier, Fighter, Mage, etc.)
Tier 2  → Clases promovidas (Swordmaster, Paladin, Sage, General, etc.)
Tier 3  → Clases élite / final (Emperor, Queen, Bishop, Dark Prince, etc.)
```

### Formato de stats: `base/cap`
Cada stat tiene dos valores separados por `/`:
- El primero es el **valor base** de la clase al crearla/promoverla a ella
- El segundo es el **cap** máximo de ese stat en esa clase

Ejemplo: `HP 30/80` en Warrior = empieza con 30 HP base, cap de 80

### Notas clave de las clases

**Tier 0:**
- Ballista: MOV=0, CON=30, solo Bow C. Enemy ONLY. Stats de torre fija.
- Pegasus Rider / Dragon Rider: versiones pre-promoción de las voladoras. Tienen growths propios (los más altos de Tier 0).

**Tier 1:**
- **Princess**: tiene Staff C y skill Charisma innata. Es la única clase Tier 1 con skill.
- **Paladin (Tier 2)**: el masculino usa Lanza B, el femenino usa Staff C en su lugar — género cambia el arsenal.
- **Dancer (Tier 2)**: clasificado como Tier 2, no Tier 1. Promoción de algo anterior.
- **Master Knight (Tier 2)**: acceso a TODAS las armas en rango A/A/A/A/A/–/C/A. El comodín total.
- **Berserker (Tier 2)**: Enemy ONLY con skill Wrath innata.
- **Baron (Tier 2)**: Enemy ONLY con Pavise innata.
- **Mage Fighter (Tier 2)**: HP growth 100%, spada C + Anima B + Staff B — híbrido físico/mágico único.

**Tier 3:** Todas son Enemy ONLY excepto posiblemente Bishop.
- Emperor: Pavise + Charisma, acceso a todo.
- Queen: Charisma, MAG cap 30, RES cap 30 — la unidad de soporte/magia definitiva.
- Dark Bishop: Anima A + Dark A + Staff A.
- Dark Prince: growths todos al 0% — es un jefe fijo, no crece.

### Skills ligadas a clases (directamente en la columna Skills)
Solo estas clases tienen skills como parte de su definición:
```
Princess        → Charisma
Dancer          → Refresh
Rogue           → Ambush
General         → Pavise
Berserker       → Wrath (Enemy Only)
Baron           → Pavise (Enemy Only)
Emperor         → Pavise + Charisma (Enemy Only)
Queen           → Charisma (Enemy Only)
```

---

## HOJA 2 — WEAPONS

### Estructura completa
Columnas: `Name / Mt / Wt / Hit / Rng / Rank / Worth / Uses / Effects`

### Armas con rango `*` (personales / sagradas)
Son las armas con nombre propio del proyecto — el sistema de Named Weapons que discutimos aplica exactamente a estas.

**Espadas personales `*`:**
| Arma | Mt | Wt | Hit | Rng | Efecto clave |
|---|---|---|---|---|---|
| Darkness Sword | 13 | 6 | 70 | 1 | Mareeta. Brave + Awareness |
| Mareeta's Sword | 11 | 6 | 80 | 1 | Mareeta. Brave + Awareness |
| Beo Sword | 16 | 13 | 70 | 1 | Delmud/Fergus. Da Ambush + Wrath |
| Holy Sword | 17 | 11 | 65 | 1 | Olwen. Brave + Effective horses + Mag+10 + Prayer |
| Blaggi Sword | 15 | 12 | 70 | 1 | Leaf/Nanna/Delmud/Fergus. Effective armoured + Niega Loputo + Prayer |
| Loputo Sword | 15 | 20 | 70 | 1 | Raydrik/Mus. Halves enemy ATK + Mag+20 |
| Mistoltin | 30 | 5 | 80 | 1 | Skl+20 + Mdf+10 + Critical |
| Tyrfing | 30 | 7 | 80 | 1 | Skl+10 + Spd+10 + Mdf+20 + Prayer |
| Balmung | 30 | 3 | 90 | 1 | Skl+10 + Spd+20 |

**Lanzas personales `*`:**
| Arma | Mt | Wt | Hit | Rng | Efecto clave |
|---|---|---|---|---|---|
| Dragon Lance | 16 | 12 | 65 | 1 | Dean. Brave + Ambush |
| Gungnir | 25 | 8 | 85 | 1 | Str/Spd/Def+10 + Charisma+Ambush+Awareness+Wrath |
| Gaeborg | 25 | 8 | 85 | 1 | Str/Skl/Def+10 + Ambush+Awareness+Wrath+Elite |

**Armas rotas incluidas en la lista:**
- Broken Sword: Mt 0, Wt 30, Hit 0, Uses 0 — ya existe como objeto
- Broken Lance: Mt 0, Wt 25, Hit 0 — ya existe
- Broken Axe: Mt 0, Wt 30, Hit 0 — ya existe
- Broken Bow: Mt 0, Wt 25, Hit 0, Rng 0 — ya existe

→ El arma rota es un **item distinto** en el sistema, no un estado del arma original. Cuando un arma llega a 0 usos, se convierte en su versión "Broken". Esto confirma el sistema que diseñamos.

### Scrolls de Cruzada
Al final de la hoja de Weapons están los **12 Crusader Scrolls** — modificadores de growths que van en el inventario:
```
Odo Scroll:    Skl +30%
Baldr Scroll:  HP+5%, Str+5%, Skl+5%, Spd+5%, Def+5%
Hezul Scroll:  HP+30%, Str+10%, Lck-10%
Dain Scroll:   Str+5%, Def+30%, Mov+5%, Spd-10%
Njörun Scroll: Str+30%, Spd+10%, Def+5%, Mag-10%, Lck-5%
Neir Scroll:   HP+10%, Str+10%, Def+10%, Mdf+10%, Skl-10%
Ulir Scroll:   Skl+10%, Spd+10%, Lck+10%
Thrud Scroll:  HP+5%, Str+5%, Mag+5%, Skl+10%, Lck+5%
Fala Scroll:   Str+5%, Mag+5%, Skl+10%, Spd+10%
Sety Scroll:   Mag+10%, Spd+30%, HP-10%
Blaggi Scroll: Mag+10%, Lck+30%, Str-10%
Heim Scroll:   Mag+30%, Lck+10%, Def-10%
```
Los scrolls tienen efectos positivos y negativos. Pueden stack. Van al inventario de la unidad.

### Staves — sistema completo
Los staves tienen su propio bloque con columna de EXP ganada por uso:
```
Live:    Rng 1,   Rank D, 15 EXP — Cura HP+10+MAG
Relive:  Rng 1,   Rank C, 18 EXP — Cura (HP+10+MAG)×2
Recover: Rng 1,   Rank B, 25 EXP — Cura todo el HP
Libro:   Rng 1~10,Rank C, 30 EXP — Cura HP+10+MAG (rango medio)
Reblow:  Rng All, Rank B, 30 EXP — Cura HP+10+MAG (rango global)
Reserve: Rng All, Rank A, 60 EXP — Cura todos los aliados ×1.5
Return:  Rng 1,   Rank B, 35 EXP — Devuelve aliado al castillo
Warp:    Rng 1,   Rank B, 50 EXP — Teleporta aliado a cualquier tile
Rewarp:  Rng All, Rank A, 20 EXP — Teleporta al usuario
Rescue:  Rng All, Rank A, 65 EXP — Trae aliado junto al usuario
Rest:    Rng 1,   Rank C, 50 EXP — Elimina estados negativos
Silence: Rng 1~10,Rank C, 75 EXP — Sella magia si MAG > MDF enemigo
Sleep:   Rng 1~10,Rank C, 75 EXP — Duerme si MAG > MDF enemigo
Berserk: Rng 1~10,Rank B, 70 EXP — Berserks si MAG > MDF enemigo (no gates/thrones)
Thief:   Rng 1~10,Rank B, 20 EXP — Tina only: roba arma/staff/item
Valkyrie:Rng 0,   Rank *, 150 EXP — En castillo principal: revive aliado caído
Torch:   —,       Rank D, 30 EXP — FOW: visión radio 10, -1/turno
M Up:    Rng 1,   Rank C, 30 EXP — MAG+7 temporal (decrece por turno)
Kia:     Rng 1,   Rank *, 30 EXP — Sara only: elimina Stone
Repair:  Rng 1,   Rank *, 30 EXP — Safy only: repara arma/staff de aliado
```

**Nota importante:** Varios staves tienen rango `All` (global/infinito) — confirmando que para los staves de rango del proyecto se usa el sistema FE5, no el GBA. Los de curación corta (Live, Relive, Recover) sí tienen rango limitado.

---

## HOJA 3 — SKILLS

### Lista final de skills del proyecto
Solo estas son skills en el sentido de "sistema de skills activo":

| Skill | Activación | Efecto |
|---|---|---|
| **Big Shield** | (Level)% | Niega completamente el daño de uno de los ataques del enemigo |
| **Wrath** | 100% | Siempre crítico cuando HP < (MaxHP/2)+1 |
| **Dance** | — (activo) | Permite a todas las unidades adyacentes ya movidas moverse de nuevo |
| **Ambush** | 100% | Siempre ataca primero cuando HP < MaxHP/2; niega Charge del enemigo |
| **Charisma** | — (pasivo) | Unidades en radio 3 reciben +10% a precisión y esquiva |
| **Awareness** | 100% | Niega críticos del enemigo, sword skills y effectividad contra el usuario |
| **Prayer** | 100% | Cuando HP ≤ 10, aumenta Avoid en [(11-HP)×10] durante un turno |
| **Life** | — (pasivo) | Usuario recupera 5~10 HP al inicio de cada turno |
| **Elite** | — (pasivo) | Usuario recibe el doble de EXP (máximo 100 por combate) |
| **Bargain** | — (pasivo) | Items y reparaciones cuestan la mitad |
| **Shooting Star Sword** | (SKL)% | 5 ataques consecutivos (10 con arma Hero); no puede activarse con Continue ni otra sword skill |
| **Moonlight Sword** | (SKL)% | Niega defensa del enemigo, siempre golpea; no se puede combinar con otra sword skill |
| **Sun Sword** | (SKL)% | Restaura HP igual al daño hecho, siempre golpea; no se puede combinar con otra sword skill |
| **Critical** | — | Mejora el cálculo de crítico: SKL×1.5 en lugar del estándar |
| **Charge** | 100% | Inicia otra ronda de combate si AS y HP del usuario > los del enemigo |

### Observaciones importantes

**Las "Sword Skills" son una subcategoría** — Shooting Star, Moonlight y Sun Sword son mutuamente exclusivas entre sí y con Continue. Son skills de espadachín que procean por SKL%.

**Critical** no es una skill de "tienes o no tienes crit" — modifica la fórmula de crit para ese personaje: en lugar del estándar usa SKL×1.5. Es un modificador de la pasiva global.

**Dance** es la skill del Dancer — no es un "action skill" como en GBA, aquí afecta a TODOS los adyacentes simultáneamente, no a uno solo. Importante diferencia de diseño.

**Ambush** activa al estar por debajo de la mitad de HP Y niega Charge del enemigo — doble función.

**Prayer** es más compleja que en GBA: no es solo "sobrevivir con 1HP", es un boost de Avoid escalonado según cuánto HP te queda por debajo de 10.

---

## HOJA 4 — ITEMS

### Anillos de stat permanente (con nombre)
Items de equipo que dan efectos pasivos mientras se llevan:
```
Life Ring    → Regenera 3~10 HP por turno (pasivo)
Elite Ring   → Da skill Elite
Thief Ring   → Da skill Steal
Prayer Ring  → Da skill Prayer
Pursuit Ring → Da skill Pursuit  ← NOTA: Pursuit Ring existe como item
Recover Ring → Restaura TODO el HP por turno (pasivo, muy poderoso)
Bargain Ring → Da skill Bargain
Knight Ring  → Canto: puede usar movimiento restante después de una acción
Return Ring  → Al usarlo, vuelve al castillo principal
Speed Ring   → Spd +5
Magic Ring   → Mag +5
Power Ring   → Str +5
Shield Ring  → Def +5
Barrier Ring → Mdf +5
Leg Ring     → Mov +3
Skill Ring   → Skl +5
Circlet      → Da Prayer + Life (combo)
```

**NOTA crítica sobre Pursuit Ring:** Aunque Pursuit como mecánica de doble ataque pasó a ser global, el **Pursuit Ring** sigue existiendo como item. En el contexto del proyecto donde Pursuit es global, este ring podría ser redefinido — o simplemente eliminado de la lista de items disponibles.

### Consumibles estándar
```
Vulnerary    → 600G, 3 usos — Restaura todo el HP
Holy Water   → 1000G, 1 uso — Mag+7 temporal (decrece por turno)
Torch        → 500G, 1 uso — FOW: visión radio 10, decrece
Antidote     → 1500G, 3 usos — Elimina Poison
Key          → 500G, 1 uso — Abre puerta/cofre/puente levadizo
Lockpick     → 3000G, 30 usos — Solo Thieves, abre todo
Knight Proof → 8000G, 1 uso — Promueve unidades Lv10+
Member Card  → — — Acceso a Secret Shop
```

### Scrolls de habilidad (enseñan skills)
```
Elite M      → Enseña Elite
Bargain M    → Enseña Bargain (no usado)
Ambush M     → Enseña Ambush
Wrath M      → Enseña Wrath
Continue M   → Enseña Continue
Prayer M     → Enseña Prayer (no usado)
Awareness M  → Enseña Awareness
Sun Sword M  → Enseña Sun Sword
Moonlight Sw M → Enseña Moonlight Sword
```

### Stat boosters permanentes (consumibles de mejora)
```
Luck Ring    → 8000G — Luck +3 permanente
Life Ring    → 8000G — MaxHP +7 permanente
Speed Ring   → 8000G — Spd +3 permanente
Magic Ring   → 8000G — Mag +2 permanente
Power Ring   → 8000G — Str +3 permanente
Body Ring    → 8000G — CON/Build +3 permanente
Shield Ring  → 8000G — Def +2 permanente
Skill Ring   → 8000G — Skl +3 permanente
Leg Ring     → 8000G — Mov +2 permanente
```

**Nota:** Hay dos versiones del mismo nombre (Speed Ring, etc.) — una es equipo pasivo y otra es consumible de mejora permanente. Son items distintos con el mismo nombre base.

---

## HOJA 5 — LOVE (Sistema de amor/support)

### Generación 1 — Parejas disponibles
**Mujeres:** Rachesis, Ayra, Fury/Erinys, Tailtyu, Sylvia, Aideen, Brigit

**Hombres con sus valores base y modificador:**
```
Noishe:   Rachesis 50+2, Fury 50+2, Brigit 50+4, Tailtyu 120+3
Alec:     Rachesis 50+2, Fury 50+2, Brigit 50+4, Tailtyu 120+3
Arden:    Rachesis 50+2, Fury 50+2, Brigit 50+4, Tailtyu 120+3
Finn:     Tailtyu 180+10, Brigit 180+10 (valores más altos del juego)
Midir:    Aideen 120+1, Brigit 100+3
Lewyn:    Fury 210+2 (ya casi al límite), Sylvia 200+2, Ayra 50+2
Holyn:    Brigit 150+3
Azel:     Aideen 120+1, Brigit 150+3
Jamke:    Aideen 250+1 (el más alto del juego), Brigit 150+3
Claude:   Ayra 200+2, Sylvia 190+1, Aideen 150+3
Beowulf:  Aideen 100+2
Lex:      standard 50+2 con todos
Dew:      valores bajos
```

### Generación 2 — Parejas disponibles
**Mujeres:** Patty, Lakche, Rana, Yuria, Fee, Tinny, Leen, Nanna

```
Celice:  Yuria 490-5 (NEGATIVO — sistema de celos, empieza casi al máximo pero decrece)
Shanan:  Lakche 220+1
Leaf:    Nanna 100+2
Johan/Johalva: Lakche 200+2
Corple:  Patty 200+3, Rana 220+3
Aless:   Leen 300+1
Arthur:  Fee 100+1
Oifey:   valores estándar bajos
```

**Caso especial:** `Daisy/Corple: 0+0` con Janne — valor fijo, no crece.

### Leyenda de niveles de relación
```
0–199:   Sin sentimientos
200–299: Feelings (atracción)
300–399: Likes (le gusta)
400–499: Loves (lo ama)
500:     Married (casados)
```

### Modificadores
- **Base natural:** el valor que se suma cada turno simplemente por estar en el mismo mapa
- **Bonus adyacencia:** +3 puntos adicionales (encima del natural) cada turno en que terminan adyacentes
- **Bonus Prioridad A:** +5 puntos adicionales — relacionado con el sistema de celos (ver abajo)

### Sistema de Celos (Jealousy)
El enlace apunta a: https://serenesforest.net/genealogy-of-the-holy-war/characters/jealousy/

En resumen: si un hombre tiene Prioridad A con una mujer y otra mujer le habla o hay interacción, la mujer con Prioridad A puede "reclamar" su atención, dando el bonus +5. Si el hombre tiene relaciones con múltiples mujeres, puede haber conflictos. Celice/Yuria con -5 es el caso más extremo: empieza a 490 pero decrecería sola sin intervención activa — se necesita acción del jugador para casarlos antes de que llegue a 0.

---

## RESUMEN — IMPLICACIONES PARA EL DISEÑO

### Sobre el sistema de Love/Support en el proyecto

El sistema ya tiene los valores numéricos completos de FE4. Para implementarlo en Godot:
1. Cada par de personajes tiene `{base, per_turn_modifier, adjacency_bonus}` 
2. El nivel de relación determina el texto de UI (sin sentimientos → feelings → likes → loves → married)
3. El sistema de celos (Prioridad A) es el bonus +5 que entra cuando hay competencia
4. Al llegar a 500 se activa la cinemática de matrimonio y los efectos de emparejamiento

### Sobre el Pursuit Ring
Con Pursuit siendo mecánica global en nuestro sistema, hay 3 opciones:
- **Eliminar** el Pursuit Ring de la lista
- **Redefinirlo** como algo útil (ej. da +1 AS, simula "perseguir mejor")
- **Mantenerlo** como item de colección/venta sin efecto funcional

### Sobre las Sword Skills
Shooting Star, Moonlight y Sun Sword funcionan como **combat arts exclusivos de espadachines** con activación por SKL. Esto se podría implementar como una variante especial dentro del sistema de skills — se activan al inicio del combate si el roll de SKL% sale favorable, y el efecto modifica toda esa secuencia de combate. Son mutuamente excluyentes entre sí.

### Sobre los Scrolls de Cruzada
Son los Crusader Scrolls de FE5 pero adaptados a los linajes de FE4. Van en el inventario, modifican growths mientras se llevan, y algunos tienen efectos negativos. Perfectamente integrables en Godot como items con `growth_modifiers: Dictionary`.

### Sobre los items con nombre duplicado (Speed Ring equipo vs. Speed Ring consumible)
Necesitan nombres distintos en la base de datos para no colisionar. Sugerencia:
- Equipo: `Speed Ring` (pasivo)  
- Consumible: `Speed Talisman` o similar, o simplemente distinguirlos por el campo `components`
