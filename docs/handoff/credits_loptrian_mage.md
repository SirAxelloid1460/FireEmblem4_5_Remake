# Handoff — "Loptyr Mage" → "Loptrian Mage" en créditos

Como parte de la unificación de nombres (organización = **Loptrian**, dios =
**Loptous**), casi todo el texto visible ya usa `Loptrian` para lo
organizacional. Falta un sitio, en un archivo que pertenece a la sesión de
créditos/traducción:

## Cambio pendiente en `Scripts/CreditsScreen.gd`

Línea ~315:

```gdscript
["Loptyr Mage", "Rip", "(Unknown)", { "name": { "italic": true, "dim": true } }],
```

`Loptyr Mage` debería ser **`Loptrian Mage`** (así coincide con el nombre de la
clase en `data/general/classes.json`, cuyo `name` es "Loptrian Mage"):

```gdscript
["Loptrian Mage", "Rip", "(Unknown)", { "name": { "italic": true, "dim": true } }],
```

## Contexto de la convención (por si aparece en otros textos)

- **Loptous** = nombre personal del dios oscuro (y del tomo `Loptous`).
- **Loptrian** = nombre organizacional/adjetivo (Imperio, Orden, Iglesia, culto,
  la clase "Loptrian Mage").
- Lo que **NO** se tocó (namespace de mecánica, ids internos): facción `Loptyr`,
  arma/estado `Loptyr Sword` / `Loptyr_negative` / `Loptyr_positive`, y su lógica
  en `CombatSystem.gd`. Si en créditos/UI aparece alguno de esos como texto
  visible, avisad y se decide aparte.
