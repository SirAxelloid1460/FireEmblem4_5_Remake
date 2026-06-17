# Sistema de Mecánicas — Diseño del Proyecto
## Base FE4/FE5 + Mejoras GBA + Decisiones propias

---

## FILOSOFÍA GENERAL

El proyecto toma la complejidad estratégica de FE4/FE5 como base y la hace **legible** con las mejoras de QoL de GBA. No se simplifica el fondo, se mejora la presentación. El jugador siempre tiene información suficiente para tomar decisiones conscientes.

---

## 1. SISTEMA DE COMBATE — FÓRMULAS

### Seguimos las fórmulas GBA con ajustes

```
AS (Attack Speed)  = SPD - max(0, WEIGHT - CON)
  → Si peso del arma ≤ CON: AS = SPD (sin penalización)
  → Si peso del arma > CON: AS = SPD - (WEIGHT - CON)
  → Magia y staves: la penalización usa MAG en vez de CON
    AS_magia = SPD - max(0, WEIGHT - MAG)
HIT                = SKL×2 + LCK/2 + WeaponHit
AVOID              = AS×2 + LCK
CRIT               = SKL/2 + WeaponCrit + ClassBonus
CRIT_AVOID         = LCK
DAMAGE (físico)    = STR + WeaponMight - DEF_enemigo - TerrainDEF
DAMAGE (mágico)    = MAG + WeaponMight - RES_enemigo
CRIT DAMAGE        = (ATK - DEF) × 3           ← estilo GBA, no FE4
```

### RNG: True Hit (2RNG, GBA)
- Se tiran dos dados de 0–99, se hace la media
- Los valores altos de HIT llegan más de lo mostrado; los bajos, menos
- El jugador ve el número de HIT display; internamente se usa 2RNG
- **Excepción:** staves de estado ofensivos usan 1RNG (igual que GBA)

### Doble ataque — Pasiva global automática (GBA)
- Si AS del atacante ≥ AS del defensor + 4 → ataca dos veces
- **No** requiere la skill Pursuit de FE4
- Es un resultado de los stats, no una habilidad que se tiene o no
- Pursuit desaparece como skill; el concepto vive como mecánica base

### Orden de combate
```
1. Vantage check (si defensor tiene skill Vantage)
2. Atacante ataca
3. Defensor contraataca (si tiene rango y arma)
4. Double check atacante → segundo ataque si AS ≥ AS_def + 4
5. Double check defensor → segundo ataque si AS ≥ AS_atk + 4
6. Brave weapons repiten el ciclo antes del contra
```

---

## 2. TRIÁNGULO DE ARMAS

### Físico (igual que GBA)
```
Espada > Hacha > Lanza > Espada
Ventaja:     +1 ATK / +15 HIT
Desventaja:  -1 ATK / -15 HIT
```

### Mágico (igual que FE4/GBA)
```
Anima (Fuego/Trueno/Viento) > Luz > Oscuridad > Anima
Mismos bonuses que el físico
```

### Reaver weapons (de GBA)
- Armas especiales que invierten la ventaja del triángulo
- Útiles situacionalmente contra usuarios de arma fuerte

### Arcos y Magia Oscura/Luz
- Fuera del triángulo físico
- Arcos: ventaja innata ×3 contra voladores (sin triangulo)

---

## 3. SISTEMA DE SKILLS

### Diseño base
- Las skills son **pasivas** en su mayoría
- Se asignan a personajes o se obtienen vía nivel/promoción/sangre sagrada
- El jugador las ve en el perfil de la unidad con descripción clara
- No hay maná ni recursos de activación — todas se aplican automáticamente

### Skills que pasan a ser PASIVAS GLOBALES (no son skills)
Estas mecánicas existían como skills en FE4 pero en este proyecto son comportamientos base de todos:

| Antes (FE4 skill) | Ahora |
|---|---|
| Pursuit | Doble ataque automático por AS (pasiva global, no skill) |
| Critical | Todos tienen tasa de crítico basada en SKL; el juego muestra el % |

### Skills que SÍ permanecen como sistema
Estas son propias de personajes específicos o clases:

**Skills ofensivas de combate:**
- `Sol` — al golpear, recupera HP igual al daño infligido (chance basada en SKL)
- `Luna` — ignora la defensa del enemigo en ese ataque (chance basada en SKL)
- `Wrath` — cuando HP ≤ 25%, tasa de crítico se multiplica ×2
- `Vantage` — si te atacan con HP ≤ 50%, contraatacas primero
- `Adept` — chance de realizar un segundo ataque inmediato antes de que el enemigo contraataque (chance = SKL%)
- `Continue` — si el primer ataque mata, puede atacar a otro enemigo adyacente (chance = SKL%)
- `Accost` — si puedes doblar, en lugar de un segundo ataque haces una secuencia de ataques adicionales (chance = SKL%)
- `Charge` — puede moverse después de atacar (Canto, pero solo después de atacar)

**Skills defensivas:**
- `Pavise` — chance de anular completamente un ataque físico (chance = SKL/2 %)
- `Nihil` — niega todas las skills proc del enemigo durante el combate
- `Prayer` — si quedarías en 0 HP, sobrevives con 1 HP una vez por combate (chance = LCK%)

**Skills de soporte/movimiento:**
- `Canto` — puede moverse de nuevo después de atacar o usar objeto (no solo después de atacar como Charge)
- `Canto+` — puede moverse con movimiento completo después de cualquier acción
- `Refresh` — dancer/singer puede refrescar a aliados adyacentes
- `Steal` — puede robar ítems no equipados de enemigos más lentos

**Skills de progresión:**
- `Paragon` — gana el doble de experiencia
- `Bargain` — los ítems cuestan la mitad en tiendas

### Cómo se obtienen las skills
1. **Por clase** — algunas clases tienen skills fijas (ej. Paladin tiene Canto)
2. **Por nivel** — al alcanzar ciertos niveles, el personaje aprende una skill de su clase
3. **Via Sangre Sagrada** — ciertos linajes otorgan skills específicas (ver sección 6)
4. **Via items especiales** — anillos y pergaminos pueden dar o mejorar skills temporalmente

---

## 4. SISTEMA DE ARMAS — DURABILIDAD Y PROGRESIÓN

### Durabilidad estándar (de GBA)
- Todas las armas tienen usos finitos
- Al llegar a 0 usos, el comportamiento depende del **tipo de arma**

### Armas rotas — comportamiento según tipo (lógica de objeto real)

**Espadas — siguen siendo usables (degradadas):**
- La hoja sigue ahí, aunque más corta y dañada. Puede seguir cortando y apuñalando.
- Penalizaciones: MT −3, HIT −20, pierde ventaja en triángulo de armas
- Animación alternativa (golpes más cortos, menos fluidez)
- Reparable en herrería

**Lanzas — siguen siendo usables, pero muy degradadas:**
- El pedazo con la punta se puede agarrar y usar como daga improvisada, pero sigue siendo una lanza.
- **En el triángulo:** pierde la ventaja contra espadas (neutral) y pierde también contra otras lanzas — una lanza rota a distancia 1 no puede competir con una lanza entera. Solo mantiene su desventaja original contra hachas.
- Si era de rango 1-2, pierde el rango 2 — solo puede usarse a distancia 1.
- Penalizaciones: MT −4, HIT −15, pierde ventaja de triángulo
- Animación alternativa (ataques cortos, sin el alcance ni el barrido de lanza)
- Reparable

**Hachas — se pierden al romperse:**
- El mango roto deja un peso metálico inmanejable. Inútil como arma.
- Al llegar a 0 usos, se destruye

**Arcos — se pierden al romperse:**
- Cuerda rota o cuerpo partido: el arco no funciona de ninguna forma.
- Al llegar a 0 usos, se destruye

**Bastones/Staves — se vuelven objetos mundanos:**
- El poder mágico se agota pero el objeto físico permanece
- Se convierte en un bastón normal: sin efectos, sin usos, solo ocupa espacio
- El jugador puede venderlo por una miseria o desecharlo manualmente
- No se puede "recargar" de magia — hay que comprar uno nuevo

**Tomos de magia — se consumen completamente:**
- Las páginas se desintegran o se vacían de energía al agotarse
- Desaparecen del inventario automáticamente al llegar a 0 usos
- Justificación: el conocimiento mágico grabado en ellos se disipa con cada uso

### Armas con nombre propio — Progresión por uso (recuperado de FE4)
Las **Named Weapons** (armas únicas o de alto rango con nombre propio) ganan experiencia en combate y pueden mejorar sus stats.

**¿Cuándo gana XP un arma con nombre?**

| Condición | XP ganada |
|---|---|
| Atacas y golpeas (triángulo neutro) | +2 |
| Atacas y golpeas (triángulo favorable) | +1 — aprende algo, pero poco |
| Atacas y golpeas (triángulo desfavorable) | +4 — superar la desventaja enseña más |
| Matas a un enemigo | +2 bonus adicional |
| Golpeas con critical | +1 bonus adicional |
| Defiendes y sobrevives | +1 |
| El portador muere | −5 (el arma "sufre") |

> **Mínimo garantizado:** toda acción de combate da al menos +1 XP al arma, sin excepción.
> La lógica es la misma que la EXP de unidades en FE: un Paladin contra un Soldier gana solo 1 EXP — aprende algo mínimo del encuentro, pero no hay reto real. La ventaja de triángulo hace el combate más fácil, así que el margen de aprendizaje se comprime al mínimo. La desventaja fuerza al arma a "trabajar más" y el aprendizaje es mayor.

**¿Qué mejora con la XP del arma?**
- Cada cierto umbral de XP, el arma sube de "nivel" (max 3 niveles)
- Nivel 1 → 2: +1 MT, +5 HIT
- Nivel 2 → 3: +2 MT, +5 HIT, +5 CRIT, desbloquea efecto especial del arma
- El efecto especial es único por arma (ej. Tyrfing nivel 3 regenera HP al inicio del turno)

**Visualización:** el arma muestra un pequeño indicador de nivel en el inventario (★ / ★★ / ★★★)

---

## 5. SISTEMA DE SANGRES SAGRADAS (Holy Blood) — Recuperado de FE4, adaptado

### Qué es
Los personajes con ascendencia de los Doce Cruzados tienen **Sangre Sagrada** que influye en sus stats y habilidades. No es el sistema binario exacto de FE4 — se reformula como un sistema de **influencia en growths y proficiencias**.

### Minor vs Major Blood (igual que FE4)
- **Minor Blood:** bonus moderado a growths y proficiencias
- **Major Blood:** bonus mayor + acceso a las armas sagradas del linaje

### Efecto de la Sangre Sagrada

**En growths de stats:**
Cada linaje potencia ciertos stats. Ejemplo:
```
Sangre de Baldur (espadas)  → STR +10% growth, SKL +10% growth
Sangre de Naga (luz)        → MAG +15% growth, RES +10% growth
Sangre de Od (espadas)      → SPD +10% growth, SKL +15% growth
```
Minor Blood da la mitad del bonus. Major da el completo.

**En proficiencias de armas (weapon rank):**
```
Minor Blood: El weapon rank del tipo del linaje sube 30% más rápido
Major Blood: Desbloquea directamente el rango S en el tipo del linaje,
             sin importar la clase ni el nivel — es un don de nacimiento.
             + acceso al arma sagrada del linaje si se tiene
```

**Skills otorgadas por Major Blood:**
- Cada Major Blood otorga una skill pasiva adicional ligada al linaje
- Ejemplo: Major Blood de Od → skill "Astra" (variante de Adept mejorada)
- Estas skills NO se pueden perder ni transferir — son de nacimiento

### Herencia (si hay sistema de generaciones)
- Si el proyecto implementa generaciones, los hijos heredan la sangre
- Major del padre/madre dominante → Major en hijo
- Minor de ambos padres del mismo linaje → puede upgradearse a Major en el hijo

---

## 6. SISTEMA DE WEAPON RANKS (Proficiencia) — Sistema GBA con influencia de Sangre

### Sistema base: GBA
- Las proficiencias van de E → D → C → B → A → S
- Suben con el uso: cada combate en que se usa un arma de ese tipo suma XP de proficiencia
- Más XP por golpe exitoso, menos por fallo
- El rango determina qué armas puede equipar la unidad

### Modificadores sobre la progresión
- **Clase:** cada clase tiene una tasa de ganancia por tipo de arma (igual que LT)
  - Ej. Cavalier: Lanzas ×1.5, Espadas ×1.0, Hachas ×0.5
- **Sangre Sagrada Minor:** +30% velocidad de subida para el tipo del linaje
- **Sangre Sagrada Major:** +60% velocidad de subida, puede alcanzar S
- **Clases no-promovidas:** máximo rango A (salvo Major Blood)
- **Clases promovidas:** pueden llegar a S en su tipo principal

### Rango S vs Rango Holy (★)

**Rango S — máximo universal:**
- Cualquier unidad puede alcanzarlo con suficiente uso
- +5 HIT permanente mientras usa ese tipo de arma
- Solo un tipo de arma puede llegar a S por unidad

**Rango Holy (★) — exclusivo de Major Blood:**
- Requiere Major Holy Blood del linaje correspondiente
- Se desbloquea al nacer, no por entrenamiento — es un don
- Otorga acceso al Arma Sagrada del linaje
- Bonus adicionales sobre S: +10 HIT, +5 CRIT, +3 ATK mientras usa ese tipo
- El arma sagrada del linaje solo puede equiparse con este rango
- Visualmente diferenciado en el UI (icono ★ dorado vs S plateado)

---

## 7. ECONOMÍA — Pool compartido (GBA)

- El oro es del ejército completo, accesible en prep screen y tiendas
- No hay gold individual por unidad (se elimina la complejidad económica de FE4)
- **Sí se conserva:** tiendas en castillos conquistados (mecánica de FE4 simplificada)
- **Se conserva:** la fragua (weapon repair) — en ciudades y castillos aliados
- **Costo de reparación:** proporcional a los usos restaurados

---

## 8. RESCATE Y TRANSPORTE

### Mecánica GBA completa
- Una unidad puede rescatar a otra si su AID > CON del rescatado
- Rescatador pierde la mitad de SPD y SKL mientras carga
- Comandos: Rescatar, Dar, Tomar, Soltar
- AID de infantería = CON − 1
- AID de montados = 20 − CON (inverso, montura lleva el peso)

### No hay Captura (FE5)
- La captura de FE5 no se implementa
- Los enemigos derrotados desaparecen o dejan drops de items según diseño del capítulo

---

## 9. SOPORTES

### Sistema GBA reformulado
- Conversaciones narrativas desbloqueables (C/B/A/S) como en FE7/8
- Dan bonus de combate cuando la unidad aliada está en rango de soporte
- **Afinidades:** cada personaje tiene una afinidad (Fuego, Agua, Viento, Tierra, Luz, Oscuridad) que modifica qué bonus da el soporte
- Los bonus de soporte se muestran en el combat preview

### Bonus de soporte por nivel (GBA FE8)
```
Nivel C: pequeño bonus (ej. +5 HIT, +1 AVO)
Nivel B: bonus medio
Nivel A: bonus completo
Nivel S: bonus completo + conversación especial (romance/amistad profunda)
```

### Combination bonus — Combinación de unidades (FE4 + GBA fusionados)
El bonus de crítico adyacente se extiende más allá del matrimonio de FE4:

| Relación | Condición | Bonus |
|---|---|---|
| Parejas / familia directa | Adyacentes en combate | +crit mutuo (igual que FE4) |
| Soporte nivel A | En rango de soporte | Bonus de soporte máximo + +5 CRIT adicional |
| Soporte nivel S | En rango de soporte | Bonus máximo + +10 CRIT adicional |
| Mismo linaje de sangre (Major) | Adyacentes | +crit mutuo (igual que parejas) |

- Los bonus de soporte normales (C/B/A/S) ya se aplican por estar en rango — esto es encima
- El bonus adyacente de crit solo activa cuando están literalmente en casillas contiguas
- Se muestra en el combat preview cuando aplica

### Soportes y Sangre Sagrada
- Personajes del mismo linaje tienen bonus de soporte base adicional
- Major Blood compartido del mismo linaje → bonus de crit adyacente igual que parejas

---

## 10. PROMOCIÓN

### Cap de nivel y ventana de promoción
- Cap universal de **nivel 30** para todas las clases (base y promovidas)
- La promoción está disponible desde **nivel 20** — no hay obligación de promover antes del 30
- Al promover, el **nivel se resetea a 1** (igual que GBA, no como FE4)
- Esto permite llevar una unidad hasta nivel 30 sin promover, maximizando los gains de growths, y luego resetear a nivel 1 en la clase promovida con los bonus de promoción encima
- Estadísticas: se aplican los bonus de promoción de la clase destino
- Nivel de armas: se conservan y pueden seguir subiendo

### Bifurcaciones de promoción (FE8)
- Algunas clases tienen dos posibles clases de promoción distintas (ej. Cavalier → Paladin o Great Knight)
- El jugador elige en el momento de promover
- Las dos opciones tienen perfiles claramente diferenciados (ej. Paladin: Canto + movilidad; Great Knight: más DEF + acceso a hachas)
- Las trainee classes (tier 0) tienen cadena de dos promociones: Tier 0 → Tier 1 → Tier 2, con bifurcación posible en cada salto

### Trainee classes (pendiente documento de diseño propio)
- Clases de tier 0 — más débiles que las base al inicio pero con growths más altos y doble oportunidad de elección de clase
- Sistema detallado pendiente de documento específico que se integrará aquí

---

## 11. EXPERIENCIA

### Curva de EXP (configurable, como en LT)
```
EXP ganada por combate = función de:
  - Diferencia de nivel entre atacante y defensor
  - Si fue hit: EXP normal
  - Si fue kill: multiplicador ×3.0 adicional
  - Si fue critical que no mató: pequeño bonus
  - Si fue miss: EXP mínima garantizada (sistema GBA — siempre algo, nunca 0)
  - El triángulo de armas NO afecta la EXP de unidad (solo la XP del arma)
```

### EXP de staves
- Curar da EXP basada en cuánto HP se recuperó
- Staves de estado dan EXP fija

---

## 12. ARENA

### Sistema híbrido FE4 + GBA

La arena combina los 7 rivales nombrados de FE4 con el sistema de reposición continua de GBA.

**Estado inicial de la arena por capítulo:**
- 7 rivales con nombre, clase, nivel y arma definidos para ese capítulo
- Personajes únicos, algunos pueden ser reclutar si se dan condiciones narrativas (como Lex en FE4)
- Cada uno tiene su apuesta y EXP propios

**Reposición — cuando un rival es derrotado (por cualquier unidad):**
- Ese slot se reemplaza automáticamente por un **rival genérico** escalado al capítulo
- El genérico es visible para todos desde ese momento
- Los 7 slots siempre están ocupados — la arena nunca se "agota"
- Los rivales named que se reemplazan NO vuelven en ese capítulo

**Reglas de participación:**
- Cada unidad puede hacer **máximo 1 pelea por visita** a la arena (no 7 seguidas)
- Puede volver a entrar a la arena más adelante en el mismo capítulo si el castillo sigue siendo accesible
- Perder no mata — la unidad queda con 1 HP (igual que FE4)
- No hay límite de veces que una unidad puede entrar siempre que sobreviva

**Bonus de soporte en arena:**
- Los bonus de soporte activos de la unidad se aplican en los combates de arena
- Si la unidad tiene pareja/familiar con soporte nivel S/A adyacente al entrar, el combination bonus de crit también aplica

---

## 13. SKILL CHARISMA (de FE5, adaptada)

### Descripción
Si una unidad con la skill **Charisma** está en un radio de 3 casillas, todas las unidades aliadas en ese rango ganan **+10 en HIT, AVOID, CRIT y CRIT_AVOID** durante el combate.

### Diferencias respecto a FE5
- En FE5 era +10 a todos los stats de combate — aquí acotamos a las 4 stats de precisión para no romper el balance de daño
- El rango es 3 casillas (igual que FE5)
- El bonus se muestra en el combat preview cuando una unidad con Charisma está en rango
- Si hay múltiples unidades con Charisma en rango, el bonus **no se acumula** — se aplica una vez

### Quién tiene Charisma
- Es una skill de clase o de personaje específico, no generalizada
- Clases de liderazgo y personajes con roles narrativos de comandante son candidatos naturales
- Se puede obtener también via Major Blood de ciertos linajes

---


---

## 14. IMPLEMENTACIÓN EN EL COMBATSYSTEM.GD

Las mecánicas anteriores implican reescribir el CombatSystem actual con los siguientes sistemas:

### Orden de ejecución en `calculate_combat`
```
1. Pre-combat skill check (Nihil, pre-proc skills)
2. Vantage check → posiblemente invertir orden
3. Attacker phase:
   a. Adept proc check
   b. Attack → execute_attack con True Hit + fórmulas nuevas
   c. Brave weapon → segundo ataque inmediato
4. Defender counter phase (si tiene rango)
5. Double attack phase:
   a. Check AS atacante ≥ AS defensor + 4
   b. Check Accost proc
6. Defender double phase (si aplica)
7. Post-combat:
   a. weapon XP para Named Weapons
   b. weapon rank XP
   c. unit EXP
   d. skill post-combat procs (Sol HP restore, etc.)
```

### True Hit en código
```gdscript
static func true_hit(display_hit: int) -> bool:
    # Dos rolls de 0-99, media entre ellos
    var r1 = randi() % 100
    var r2 = randi() % 100
    var effective = (r1 + r2) / 2
    return effective < display_hit
```

### Daño crítico
```gdscript
# Fórmula GBA: (ATK - DEF) × 3, mínimo 0
if is_critical:
    damage = max(0, (attack - defense) * 3)
```

### Arma rota — check en execute_attack
```gdscript
# Si el arma tiene 0 usos pero es espada o lanza → sigue usable con penalty
func get_effective_weapon_stats(weapon: ItemData) -> Dictionary:
    if weapon.uses <= 0:
        if weapon.weapon_type in ["Sword", "Lance"]:
            return {
                "might": weapon.might - (3 if weapon.weapon_type == "Sword" else 2),
                "hit": weapon.hit - (20 if weapon.weapon_type == "Sword" else 15),
                "triangle_valid": false,  # pierde ventaja de triángulo
                "broken": true,
                "anim_variant": "broken"
            }
        else:
            return {}  # arma destruida, no usable
    return {"might": weapon.might, "hit": weapon.hit, "triangle_valid": true, "broken": false, "anim_variant": "normal"}
```
