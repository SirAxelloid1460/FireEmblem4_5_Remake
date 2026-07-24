# Handoff — API de `AssetSet` y fuentes por set (para créditos)

Respuesta a la sesión de traducción/créditos sobre cómo saber el set gráfico
activo y cómo elegir la fuente en `CreditsScreen`. Fuente de verdad:
`Scripts/AssetSet.gd`, `Scripts/AssetLoader.gd`, `Scripts/CreditsScreen.gd`.

## 1. Saber el set activo desde código

Usa **`AssetSet.current()`** → `String`: `"Original"`, `"GBA"` o `"HD"`.

- **No** existe `is_hd()`. Comprueba `AssetSet.current() == "HD"`.
- Es una **función estática**, no una propiedad: `AssetSet.current()` con
  paréntesis (no `AssetSet.current`).
- Constantes útiles: `AssetSet.SETS`, `AssetSet.DEFAULT` (`"GBA"`),
  `AssetSet.FALLBACK` (`"GBA"`).

**No hay señal de cambio, y no hace falta.** El set NO cambia en caliente:
`OptionsMenu` / `AssetSet.save()` solo escriben en `user://settings.cfg` y el
cambio surte efecto **al reiniciar**. Durante la sesión el set es constante y
`current()` está cacheado → léelo una vez.

## 2. ¿`AssetSet.p()` contempla bmp → ttf?

**No.** `p()` es solo un **re-enraizador de rutas**:
`res://assets/X` → `res://assets/{set}/X`, con **fallback a GBA** si el archivo
no existe en el set activo. **No cambia extensiones ni elige `.fnt` vs `.ttf`.**

Ese fallback resuelve el caso actual gratis: HD no tiene
`fonts/bmp/credit.fnt`, así que

```gdscript
AssetSet.p("res://assets/fonts/bmp/credit.fnt")
# set=HD → prueba HD/fonts/bmp/credit.fnt (no existe) → cae a GBA/fonts/bmp/credit.fnt
```

Por eso `CreditsScreen` **ya funciona en HD hoy**: acaba usando el `credit.fnt`
de GBA por fallback. Si os vale con eso, no hay que tocar nada.

## 3. ¿Debe `CreditsScreen` elegir la fuente según versión?

Solo **si queréis una fuente distinta por set** (p. ej. el TTF de FE Heroes en
HD en lugar del bitmap). Como `p()` no traduce `.fnt`→`.ttf`, se elige a mano:

```gdscript
func _credit_font():
    if _credit_font_res == null:
        var path := CREDIT_FONT   # "res://assets/fonts/bmp/credit.fnt" (GBA/Original)
        if AssetSet.current() == "HD":
            path = "res://assets/fonts/Fire_Emblem_Heroes_Font.ttf"   # p() lo enraíza a HD/fonts/...
        var p := AssetSet.p(path)
        if ResourceLoader.exists(p):
            _credit_font_res = load(p)
    return _credit_font_res
```

**Ojo con el tamaño:** `credit.fnt` es **BMFont (bitmap, tamaño horneado)**;
`font_size_override` no lo escala como a un TTF. Si mezcláis bitmap (GBA) + TTF
(HD), el manejo de `font_size` difiere entre sets → probad cada set por separado.

## Rutas reales de fuentes por set

| Set | Fuentes de créditos disponibles |
|---|---|
| **GBA** | `assets/GBA/fonts/bmp/credit.fnt` · `credit_title.fnt` (+ TTFs latinos/JP) |
| **HD** | solo `assets/HD/fonts/Fire_Emblem_Heroes_Font.ttf` (sin `credit.fnt`) |
| **Original** | aún sin fuentes → caería a GBA por fallback |

## TL;DR

- Set activo: `AssetSet.current()` (sin señal; fijo por sesión, cambia al reiniciar).
- `p()` = re-enraíza + fallback a GBA; **no** cambia bmp↔ttf.
- Fuente propia por set → elígela con `if AssetSet.current() == "HD"` como arriba.
- Si no, el fallback ya te da el bitmap de GBA en los tres sets.
