# Handoff — rename Evan → Eve (edición en CreditsScreen.gd)

Se renombró el personaje **Evan → Eve** en todo el proyecto (nid, nombre visible,
`portrait_nid`, assets de retrato y combat anims, y referencias en datos). El único
sitio que **no** toqué es `Scripts/CreditsScreen.gd`, que pertenece a la sesión de
créditos/traducción.

## Cambio pendiente en `Scripts/CreditsScreen.gd`

Línea ~351:

```gdscript
["",        "Alvar, Evan, Evar",     "Aruka, Kenpuhu, Nuramon"],
```

`Evan` (columna inglesa) debería pasar a `Eve`:

```gdscript
["",        "Alvar, Eve, Evar",      "Aruka, Kenpuhu, Nuramon"],
```

La columna japonesa (`Aruka, Kenpuhu, Nuramon`) es dato tuyo; no la toco.

## Contexto del rename (por si necesitas coherencia en otros textos)

- Motivo: **Eve** es el nombre NoJ (según fireemblemfandom); lo aportó el autor.
- Alcance ya aplicado por la sesión de desarrollo: `data/general/units.json`
  (nid+name+portrait_nid), `data/fe4/levels/2.json`, `data/fe4/events/2/*`,
  `data/general/portrait_offsets.json`, assets
  `portraits/characters/Eve.png` y `combat_anims/Paladin_Eve/`.
- **Ojo (lore):** la descripción de la unidad dice *"the middle triplet brother of
  **Eve** and Alva"*. Al pasar la unidad a llamarse Eve, esa frase queda
  autorreferente. No la reescribí (es decisión de lore del autor); si toca los
  textos de historia, revisar ahí.

## Nota: rename Ulster → Skasaher

También se cambió el **id** interno `Ulster → Skasaher` (el nombre visible sigue
siendo **Scáthach**). No aparece en los créditos, así que **no requiere cambios**
en `CreditsScreen.gd`.
