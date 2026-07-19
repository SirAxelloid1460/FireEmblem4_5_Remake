#!/usr/bin/env python3
# build_bitmap_font.py
# =============================================================================
# Convierte las sprite-fonts de Lex Talionis (.idx + .png) a BMFont .fnt, que
# Godot 4 importa como FontFile (fuente de mapa de bits usable en temas/labels).
#
# FORMATO LT .idx (texto):
#   width  <cw>            ← ancho de celda (px)
#   height <ch>            ← alto de celda (px)  [opcional; se deriva del PNG]
#   <char> <col> <row> <adv>   ← glifo: celda (col,row) en la rejilla, avance <adv>
#   · <char> = carácter literal, o la palabra "space".
#   · La rejilla es (img_w/cw) columnas × (img_h/ch) filas; el glifo se dibuja en
#     la celda cw×ch y el pen avanza <adv> px (proporcional).
#
# SALIDA: <name>.fnt (AngelCode BMFont, texto) + copia del PNG elegido. Godot
# genera el .import al abrir el editor.
#
# Uso (lote sobre una carpeta de fuentes LT):
#   python tools/build_bitmap_font.py --src in/ltfonts --out assets/GBA/fonts/bmp
#   · Empareja cada <name>.idx con <name>-<color>.png (prefiere --color, def white).
#
# Una sola fuente / color concreto:
#   python tools/build_bitmap_font.py --src in/ltfonts --out out --name text --color white
# =============================================================================

import argparse
import glob
import os
import shutil
import sys

try:
    from PIL import Image
except ImportError:
    sys.exit("Falta Pillow. Instala con: pip install Pillow")

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(HERE)


def parse_idx(path):
    """Devuelve (header dict, list de (codepoint, col, row, adv)).
    Cabecera: width/height/space_offset (int) y transrgb (color de fondo a
    transparentar, r g b). Glifo: '<char|space> <col> <row> <adv>'."""
    header = {}
    glyphs = []
    for ln in open(path, encoding="utf-8").read().splitlines():
        parts = ln.split()
        if not parts:
            continue
        key = parts[0]
        if key in ("width", "height", "space_offset") and len(parts) >= 2:
            header[key] = int(parts[1])
        elif key == "transrgb" and len(parts) >= 4:
            header["transrgb"] = (int(parts[1]), int(parts[2]), int(parts[3]))
        elif len(parts) >= 4 and (key == "space" or len(key) == 1):
            col, row, adv = int(parts[-3]), int(parts[-2]), int(parts[-1])
            cp = 32 if key == "space" else ord(key)
            glyphs.append((cp, col, row, adv))
        # cualquier otra línea se ignora
    return header, glyphs


def pick_png(src, name, color):
    """Elige el PNG del font: <name>-<color>.png, luego <name>-*.png, luego <name>.png."""
    cand = os.path.join(src, "%s-%s.png" % (name, color))
    if os.path.exists(cand):
        return cand
    alts = sorted(glob.glob(os.path.join(src, "%s-*.png" % name)))
    if alts:
        return alts[0]
    flat = os.path.join(src, "%s.png" % name)
    return flat if os.path.exists(flat) else None


def build_fnt(idx_path, png_path, out_dir, name):
    header, glyphs = parse_idx(idx_path)
    if not glyphs:
        print("[%s] .idx sin glifos, saltado" % name)
        return None
    img_w, img_h = Image.open(png_path).size
    max_col = max(g[1] for g in glyphs)
    max_row = max(g[2] for g in glyphs)
    cw = header.get("width", img_w // (max_col + 1))
    ch = header.get("height", img_h // (max_row + 1))
    base = ch - 3   # baseline aproximada (ajustable)

    # Copia del PNG a RGBA; si el idx define transrgb (fondo sólido), se
    # transparenta ese color. Si el PNG ya trae alpha, se deja igual.
    png_out = os.path.join(out_dir, os.path.basename(png_path))
    key = header.get("transrgb")
    if key is not None:
        img = Image.open(png_path).convert("RGBA")
        px = img.load()
        kr, kg, kb = key
        w, h = img.size
        for y in range(h):
            for x in range(w):
                r, g, b, a = px[x, y]
                if a != 0 and r == kr and g == kg and b == kb:
                    px[x, y] = (0, 0, 0, 0)
        img.save(png_out)
    elif os.path.abspath(png_out) != os.path.abspath(png_path):
        shutil.copyfile(png_path, png_out)

    lines = []
    lines.append('info face="%s" size=%d bold=0 italic=0 charset="" unicode=1 '
                 'stretchH=100 smooth=0 aa=1 padding=0,0,0,0 spacing=0,0 outline=0' % (name, ch))
    lines.append('common lineHeight=%d base=%d scaleW=%d scaleH=%d pages=1 packed=0'
                 % (ch, base, img_w, img_h))
    lines.append('page id=0 file="%s"' % os.path.basename(png_path))
    lines.append('chars count=%d' % len(glyphs))
    for cp, col, row, adv in glyphs:
        lines.append('char id=%d x=%d y=%d width=%d height=%d xoffset=0 yoffset=0 '
                     'xadvance=%d page=0 chnl=15' % (cp, col * cw, row * ch, cw, ch, adv))
    fnt_out = os.path.join(out_dir, "%s.fnt" % name)
    open(fnt_out, "w", encoding="utf-8").write("\n".join(lines) + "\n")
    print("[%s] %s + %s  (%d glifos, celda %dx%d)"
          % (name, os.path.relpath(fnt_out, PROJECT_ROOT),
             os.path.basename(png_out), len(glyphs), cw, ch))
    return fnt_out


def main():
    ap = argparse.ArgumentParser(description="Convierte sprite-fonts LT (.idx + .png) a BMFont .fnt para Godot.")
    ap.add_argument("--src", required=True, help="Carpeta con los .idx y .png de LT.")
    ap.add_argument("--out", default=os.path.join(PROJECT_ROOT, "assets", "GBA", "fonts", "bmp"),
                    help="Carpeta destino (default assets/GBA/fonts/bmp).")
    ap.add_argument("--color", default="white", help="Color preferido del PNG (default white).")
    ap.add_argument("--name", default="", help="Convertir solo esta fuente (por nombre); vacío = todas.")
    args = ap.parse_args()

    os.makedirs(args.out, exist_ok=True)
    idxs = sorted(glob.glob(os.path.join(args.src, "*.idx")))
    if args.name:
        idxs = [p for p in idxs if os.path.splitext(os.path.basename(p))[0] == args.name]
    if not idxs:
        sys.exit("No hay .idx que procesar en %s" % args.src)
    n = 0
    for idx_path in idxs:
        name = os.path.splitext(os.path.basename(idx_path))[0]
        png = pick_png(args.src, name, args.color)
        if png is None:
            print("[%s] sin PNG asociado, saltado" % name)
            continue
        if build_fnt(idx_path, png, args.out, name):
            n += 1
    print("Hecho: %d fuente(s)." % n)


if __name__ == "__main__":
    main()
