# Paletas de equipo — imágenes fuente

Para construir el palette-swap real (Player → Enemy/Ally/Other/Used) necesito
muestrear los colores **exactos** (pixel-perfect). Guarda aquí las 3 imágenes que
pasaste, con estos nombres EXACTOS (PNG, sin reescalar):

1. `gba_team_palettes.png`
   → la imagen pequeña "FEPalletes": columnas Player, Enemy, Ally, Other(vacía), Used.

2. `fe4_mapsprites_a.png`
   → la primera hoja grande de map sprites de FE4 (SNES) con las 4 variantes de color.

3. `fe4_mapsprites_b.png`
   → la segunda hoja grande de map sprites de FE4 (SNES).

Con eso extraigo: rampas exactas de cada equipo (GBA) + colores de "Other" y
variantes SNES, y genero el mockup de cada paleta + el LUT para el shader.

> Nota: si las pegas como PNG nativos (no JPG) los colores son fieles.
