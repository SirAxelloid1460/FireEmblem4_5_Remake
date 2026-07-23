# Reconciliación del roster — FE4 + FE5

> Actualizado tras importar datos reales de Serenes Forest (bases + growths).


## Estado actual: **129 units**

> +1 Saias (FE5), +6 jefes: Julius, Manfroy, Travant, Ishtar, Veld y **Mua**
> (Dark Bishop, cap. 17A FE5) con stats reales de Serenes Forest. Falta **Mus**
> (Dreadlord — sin fuente; ver nota abajo).

- Solo FE4: 63
- Solo FE5: 52
- Cross-game (FE4+FE5): 7 → ['Finn', 'Leif', 'Nanna', 'Oifey', 'Hannibal', 'Diarmuid', 'Ced']


## Añadidos en esta tanda (58, datos reales de Serenes)

- **FE5 jugables**: ~35 (Asbel, Olwen, Fergus, Karin, Cain, Fred, Glade, Dean, Sara, Miranda, Misha, Xavier, Amalda, Conomor, Galzus, Sleuf, Linoan, Homer, Eda, Ralf, Ilios, Salem, Tina, Troude, Shannam, Perne, Selphina, Carrion, Alva, Robert, Hicks, Dalsin, Brighton, Machyua, Cyas…).
- **FE4 sustitutos + reclutas fijos**: Muirne, Creidne, Dalvin, Tristan, Deimne, Hermina, Amid, Daisy, Jeanne, Laylea, Linda, Asaello, Hawk, Charlot, Oifey, Julia, Johan, Johalva, Shannan, Ares, Hannibal.


## Pendientes — NO añadidos (sin inventar stats)

### FE4 gen2 hijos con herencia (stats dependen del padre elegido)
**Resuelto con modelo BASE + MODIFICADOR-POR-PADRE** (fuente: fireemblemwod).
- Datos: `data/general/gen2_children.json` (14 hijos: Lester, Lana, Larcei, Ulster,
  Diarmuid, Nanna, Coirpre, Lene, Ced, Fee, Faval, Patty, Arthur, Tine). Cada uno con
  clase real, sangre personal, skills, arma, `max_stats` (tope de clase),
  `base_stats`/`base_growths` (piso = mín entre padres) y `father_mods[padre]`
  (deltas de base y growth + skills que aporta cada padre) para los 13 padres.
- Resolución: `SubstituteSystem._build_canonical_child` →
  `final = base + father_mods[padre]` (base clamped a `max_stats`; CON/MOV de la clase;
  skills mapeadas al set actual: Ambush→Vantage, Pursuit/Continue descartadas).
- Regenerar: `python tools/build_gen2_children.py`. Excel de referencia:
  `docs/FE4_Gen2_Inheritance.xlsx` (`tools/build_gen2_xlsx.py`).
- **Sustitutos**: siguen su modelo base(fijo) + modificador paterno (paternal_factor)
  como fallback cuando la madre muere/no se casa.

### Seliph, Altena, Leif (gen2) — Serenes NO publica bases fijas
Confirmado contra `characters/base-stats/fixed/` de Serenes: Seliph, Altena y Leif NO aparecen (sus stats se computan de los padres aunque estos sean fijos). No hay valor sourcable de las wikis indicadas. Opciones: (a) sistema de herencia, (b) el `.ltproj` original que sí les asignaba un default, o (c) otra fuente. **Leif ya está en la DB** (base asignada por LT).

### FE5 sin datos en la tabla base de Serenes
~~**Saias**~~ → añadido con datos provistos por el autor.

### Jefes añadidos (boss-data de Serenes)
- **Julius** (Dark Prince, cap. final FE4): Loptous + Meteor; sangre Loptos Major / Fjalar Minor.
- **Manfroy** (Dark Bishop, cap. final FE4): Fenrir + Jormungandr.
- **Travant** (Dragon Master, cap. 9 FE4): Silver Lance + Power Ring; sangre Dainn Major.
- **Ishtar** (Sage, cap. 10 FE4): Mjolnir + Barrier/Life Ring; sangre Thrud Major.
- **Veld** (Dark Bishop, cap. final FE5): Jormungandr + Vulnerary.
- Skills remapeados al set actual: `Pursuit`/`Continue` se omiten (doblaje por Δ SPD),
  `Ambush`→`Vantage`. Growths vacíos (los jefes no suben de nivel; sin fuente).

### Mua ≠ Mus (aclarado por el autor)
- **Mua**: Bishop de FE5 (Dark Bishop, cap. 17A) → añadido con stats de Serenes.
- **Mus**: Dreadlord en FE4 y FE5, empuña la Loptyr Sword. **No hay clase
  `Dreadlord` ni stats de Mus en Serenes/LT** → pendiente de datos del autor
  (igual que Saias). Se mantiene en `prf_units` de la Loptyr Sword.

### Stone / Petrify Tome — añadida
Tomo Dark (no báculo): Rank A, Mt 1, Hit 100, Rng 3-10, Wt 20, Usos 5, sin
precio. `status_on_hit = Petrify` (petrifica hasta fin de capítulo). Cableada al
inventario de Veld. Pendiente: la mecánica "se convierte en Fenrir al ser
robada" queda anotada en la desc pero sin wiring (steal-transform).


## Personajes cross-game (versiones por juego FE4/FE5)
En la saga combinada (`SAGA_MODE`) los personajes que aparecen en ambos juegos
entran con su **versión más débil** y escalan a través de los dos juegos. Modelo:
cada unidad cross-game lleva un campo `versions` en `units.json`:
```
"versions": {
  "FE4": { "klass": ..., "level": ..., "bases": {...}, "growths": {...},
           "learned_skills": [...], "starting_items": [...], "wexp_gain": {...},
           "holy_blood": {...} },
  "FE5": { ...igual... }
}
```
`LevelLoader._resolve_game_version` elige: `FE4_ONLY`→FE4, `FE5_ONLY`→FE5,
`SAGA_MODE`→la de menor suma de bases (desempate por nivel). El bloque elegido
sobreescribe los campos que declara; el resto se hereda del nivel superior.
Cross-game: **Finn, Leif, Nanna, Oifey, Hannibal, Diarmuid, Ced, Coirpre**
(stats por versión pendientes de rellenar).

## Notas de datos
- FE5: `MOV = Mov×10`, `CON = Build`, `RES = 0` (Serenes no lista Res en FE5; base canónico 0).
- FE4: `CON`/`MOV` tomados de la clase (fijos por clase en FE4); `RES` = columna Mdf.
- `wexp_gain`/`starting_items`/`affinity` vacíos (no provistos por Serenes) — el acceso a armas lo da la clase. `holy_blood` (FE4) parseado a dict {sangre: rango}.
- 10 units nuevos sin retrato aún (renderizan en blanco, sin crash): Muirne, Creidne, Dalvin, Deimne, Hermina, Johan, Johalva, Charlot, Perne, Cyas.

