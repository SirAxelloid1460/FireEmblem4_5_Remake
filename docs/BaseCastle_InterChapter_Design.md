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

## 6. Bifurcaciones a decidir (para ti)
1. **Arena**: ¿la mantenemos y en qué forma?
   - (a) Arena estilo **FE4 original**: peleas por rondas contra un rival del
     mismo tier/nivel, ganas EXP+oro, con **riesgo de muerte** si pierdes.
   - (b) Arena **sin riesgo** (derrota = solo pierdes la ronda, no la unidad).
   - (c) **Sin arena** (se retira del Castillo Base por completo).
2. **Disparo del menú**: ¿el Castillo Base se abre **entre TODOS** los capítulos
   automáticamente, o solo en capítulos concretos (como FE4, donde solo algunos
   castillos tienen tienda/arena)?

## 7. Fuera de alcance de esta iteración
- Balance económico (precios de tienda, coste de reparación, premios de arena).
- Conversaciones de apoyo nuevas (solo se listarán las que ya existan como eventos).
