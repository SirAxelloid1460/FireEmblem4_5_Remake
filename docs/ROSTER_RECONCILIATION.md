# Reconciliación del roster — FE4 + FE5

> Actualizado tras importar datos reales de Serenes Forest (bases + growths).


## Estado actual: **122 units**

- Solo FE4: 63
- Solo FE5: 52
- Cross-game (FE4+FE5): 7 → ['Finn', 'Leif', 'Nanna', 'Oifey', 'Hannibal', 'Delmud', 'Ced']


## Añadidos en esta tanda (58, datos reales de Serenes)

- **FE5 jugables**: ~35 (Asbel, Olwen, Fergus, Karin, Cain, Fred, Glade, Dean, Sara, Miranda, Misha, Xavier, Amalda, Conomor, Galzus, Sleuf, Linoan, Homer, Eda, Ralf, Ilios, Salem, Tina, Troude, Shannam, Pahn, Selphina, Carrion, Alva, Robert, Hicks, Dalsin, Brighton, Machyua, Cyas…).
- **FE4 sustitutos + reclutas fijos**: Mana, Radney, Roddlevan, Tristan, Dimna, Femina, Amid, Daisy, Jeanne, Laylea, Linda, Asaello, Hawk, Sharlow, Oifey, Julia, Johan, Johalva, Shannan, Ares, Hannibal.


## Pendientes — NO añadidos (sin inventar stats)

### FE4 gen2 hijos con herencia (stats dependen del padre elegido)
Sin valor fijo en Serenes: **Lana, Larcei, Ulster, Skasaher, Lester, Fee, Arthur, Patty, Lene, Tine, Faval**. Requieren el sistema de herencia/sustitutos (los sustitutos SÍ están añadidos como fallback canónico).

### Seliph, Altena, Leif (gen2) — Serenes NO publica bases fijas
Confirmado contra `characters/base-stats/fixed/` de Serenes: Seliph, Altena y Leif NO aparecen (sus stats se computan de los padres aunque estos sean fijos). No hay valor sourcable de las wikis indicadas. Opciones: (a) sistema de herencia, (b) el `.ltproj` original que sí les asignaba un default, o (c) otra fuente. **Leif ya está en la DB** (base asignada por LT).

### FE5 sin datos en la tabla base de Serenes
**Saias** (no aparece en la tabla base-stats; requiere otra fuente).


## Notas de datos
- FE5: `MOV = Mov×10`, `CON = Build`, `RES = 0` (Serenes no lista Res en FE5; base canónico 0).
- FE4: `CON`/`MOV` tomados de la clase (fijos por clase en FE4); `RES` = columna Mdf.
- `wexp_gain`/`starting_items`/`affinity` vacíos (no provistos por Serenes) — el acceso a armas lo da la clase. `holy_blood` (FE4) parseado a dict {sangre: rango}.
- 10 units nuevos sin retrato aún (renderizan en blanco, sin crash): Mana, Radney, Roddlevan, Dimna, Femina, Johan, Johalva, Sharlow, Pahn, Cyas.

