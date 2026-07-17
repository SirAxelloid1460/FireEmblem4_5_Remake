# Castillo Base — menú inter-capítulo (rediseño desde la mecánica original de FE4)

Estado: **propuesta** (pendiente de confirmar bifurcaciones con el usuario).
Reemplaza el enfoque heredado de LT ("Preparation-Base" estilo GBA + arena GBA).

## 1. Qué se ha eliminado (remanentes LT/GBA)
- Líneas de tutorial "Preparation-Base Menu" y "This arena does not work as the
  original FE4's, just as the GBA ones" en los eventos `PreBase` (caps 1 y 2).
- Variable de juego `_base_arena` (arena estilo GBA).
- Región huérfana `HolynHouse` / sub_nid `Circus` en `data/fe4/levels/2.json`
  (placeholder del evento de arena de Holyn, que estaba *diseñado, no construido*).

Se conserva, de momento, el resto del flujo `PreBase` (mercado, reparación,
convoy, `BasePeople`) porque será absorbido por el menú inter-capítulo.

## 2. Concepto
En FE4 original el "Castillo Base" no es una pantalla de preparación: es tu
**castillo en el mapa** al que regresas durante el capítulo (arena, tienda,
promoción, repartir oro entre unidades adyacentes, conversaciones de
amor/apoyo). Aquí lo **reencarnamos como un menú INTER-CAPÍTULO**: entre un
capítulo y el siguiente se abre el Castillo Base con todas esas facilidades,
manteniendo el sabor FE4 pero con una UX de menú limpia y unificada para los 3
modos (FE4_ONLY / FE5_ONLY / SAGA_MODE).

## 3. Reutilizamos lo ya construido
Ya existe `CastleBase` (`Scripts/CastleBase.gd` + `Scenes/castle_base.tscn`) con:
- Lista de unidades + detalle, oro del ejército, persistencia de roster
  (`GameMode.capture_roster` / `build_roster_units`), convoy central
  (`Convoy.enter_castle` / `leave_castle`).
- Paneles: Shop, Convoy, Blacksmith (reparación), Fortune, **Promotion**
  (recién cableado a `promotion_gains`/caps por modo), Manage, Save, StartBattle.

El rediseño **no parte de cero**: consiste en (a) disparar `CastleBase` entre
capítulos desde `GameMode` en lugar de vía los eventos LT `base`, y (b) ajustar
las facilidades al canon FE4.

## 4. Flujo propuesto
```
Capítulo N (victoria) ─► GameManager captura roster + oro
      └─► GameMode.advance_chapter():
             ├─ ¿hay siguiente capítulo? ─► abrir CastleBase (menú inter-cap)
             │        └─ jugador gestiona; pulsa "Partir" (StartBattle)
             │              └─ CastleBase._leave_castle(): persistir → cargar cap N+1
             └─ no ─► créditos / fin de modo
```
- Se elimina la dependencia de eventos `PreBase` por-nivel para abrir la base.
- Los eventos por-capítulo (mercado inicial, intro narrativa) siguen siendo
  eventos del capítulo; el Castillo Base es una capa previa e independiente.

## 5. Facilidades (mapeo al canon FE4)
| Facilidad | FE4 original | En el menú inter-capítulo |
|---|---|---|
| **Tienda** | Pawn Shop (comprar/vender), Secret Shop | Comprar/vender; stock por capítulo + secret-shop opcional |
| **Reparación** | reparar armas por oro en el castillo | Blacksmith (ya existe) |
| **Promoción** | promocionar en tu castillo a Lv20+ | PromotionPanel (ya cableado por modo) |
| **Convoy / repartir oro** | pasar oro/ítems entre unidades adyacentes | Convoy central + transferencia de oro entre unidades |
| **Conversaciones** | amor/apoyo al mover a un castillo | Listar conversaciones disponibles del capítulo |
| **Arena** | arena FE4 (rondas crecientes, riesgo real, sin apuesta) | **BIFURCACIÓN — ver §6** |
| **Guardar** | — | Save |

## 6. Decisiones tomadas

### 6.1 Disparo del menú
El Castillo Base se abre **entre TODOS los capítulos** automáticamente, tras la
victoria y antes de cargar el siguiente capítulo.

### 6.2 Arena — modelo HÍBRIDO (decisión del usuario)
Combina la arena original de FE4 (rivales fijos) con la arena tradicional GBA
(genéricos random) por personaje:

1. **Fase fija (rivales de la casa).** Cada capítulo tiene sus **7 NPC fijos**
   propios (+ varios alternativos para los combates a distancia), tomados de la
   tabla real de FE4: https://www.fireemblemwod.com/fe4/arena.htm
   - Cada personaje que entra a la arena **empieza por el rival nº 1** y avanza
     en orden al derrotarlos.
   - El progreso es **por personaje** (cada uno lleva su propia cuenta de a qué
     rival fijo ha llegado).
2. **Fase tradicional (genéricos).** Una vez un personaje derrota a **los 7**
   rivales fijos, su arena pasa a generar **enemigos genéricos aleatorios** de
   **nivel = nivel del personaje + (1 a 3)**.
3. **Límite de victorias.** Cada personaje puede ganar **hasta 10 veces en total**
   por capítulo (fijas + genéricas combinadas).
4. **Derrota ≠ muerte.** Perder un combate solo termina la ronda: se **vuelve al
   menú de la Base** y el personaje **recupera todo su HP**. No hay permadeath en
   la arena.
5. **Reset.** El contador de victorias (y la fase fija/genérica) se **reinicia al
   final de cada capítulo** — cada capítulo trae sus propios 7 rivales.

Datos a construir (offline, sourced): tabla `arena/<cap>.json` con los 7 rivales
fijos + alternativos a distancia por capítulo, desde el enlace de fireemblemwod.
Estado runtime por personaje: `arena_fixed_index` (0..7) y `arena_wins` (0..10),
reseteados en `end_chapter`.

## 6.3 Layout visual (referencia: Vestaria Saga)
El usuario aportó una referencia (estilo *Vestaria Saga* de Kaga) para el aspecto
del menú inter-capítulo:
```
┌───────────────────────────────────────────────────────────┐
│ [HUD] oro · materiales · capacidad 95/150 · año/turno      │  ← barra superior
├──────────────┬────────────────────────────────────────────┤
│ Avanzar      │                                            │
│ Organización │        MAPA DEL CAPÍTULO ACTUAL             │  ← fondo = mapa
│ (Árbol tec.) │        (con bandera de posición)           │
│ Mercado      │                                            │
│ Info/Tutorial│                                            │
│ Soporte      │                                            │
│ Arena (gris) │  ← grisada si el cap no tiene arena        │
│ Sistema      │                                            │
├──────────────┴────────────────────────────────────────────┤
│ Capítulo N: «título»                                       │
│ [caja de narración / objetivo del capítulo]                │  ← pie
└───────────────────────────────────────────────────────────┘
```
- Fondo: imagen del mapa del capítulo actual (AssetLoader.get_tilemap_image /
  panorama), con marcador de la posición del jugador.
- Columna izquierda: botones de facilidad (mapeo en la tabla de abajo).
- Barra superior: recursos (oro, materiales, capacidad de ejército, fecha/turno).
- Pie: título del capítulo + caja de narración/objetivo.
- La **Arena se grisa** cuando `ArenaSystem.chapter_has_arena(cap)` es false
  (Prólogo y Cap. 6 en FE4), tal como el botón 闘技場 aparece deshabilitado en la
  referencia.

### Mapeo de botones (referencia → facilidad)
| Botón ref (JP / ES) | Facilidad del remake |
|---|---|
| 進軍 Avanzar | StartBattle → cargar siguiente capítulo |
| 部隊編成 Organización | Manage (roster / equipar / convoy) |
| 技術ツリー Árbol tecnológico | *(sin equivalente aún — candidato: meta-progresión / promoción)* |
| 市場 Mercado | Shop |
| チュートリアルと情報 Info | Ayuda / tutorial |
| サポート Soporte | Conversaciones / supports |
| 闘技場 Arena | Arena híbrida (§6.2) |
| システム Sistema | Save / Load / Opciones |

## 7. Fuera de alcance de esta iteración
- Balance económico (precios de tienda, coste de reparación, premios de arena).
- Conversaciones de apoyo nuevas (solo se listarán las que ya existan como eventos).
