#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
build_jp_bitmap_font.py — genera BMFonts (.fnt + atlas PNG) para Godot a partir
de fuentes PIXEL-ART TTF, por bloque (hiragana / katakana / kanji).

Pensado para la fuente japonesa del proyecto: se rasteriza a su tamaño NATIVO
(sin antialias — se umbraliza el alfa) para que quede nítida como las demás
sprite-fonts LT, y se emite el mismo formato BMFont que build_bitmap_font.py.

COBERTURA / EXTENSIBILIDAD: se pueden pasar VARIAS fuentes en orden; cada glifo
se toma de la PRIMERA fuente que lo tenga. Así, si a la fuente principal le
faltan kanji, se rellenan con otras fuentes pixel-art añadiéndolas al final:
    --fonts Mona10x12.ttf otra_kanji.ttf otra_mas.ttf

Bloques predefinidos (--block):
    hiragana : U+3041..3096 + marcas (309B..309F, 3099..309A)
    katakana : U+30A0..30FF
    kanji    : U+4E00..9FFF (solo se emiten los que ALGUNA fuente tenga)
También: --ranges "4E00-4E10,738B" y/o --from-text a.json b.json (escanea los
caracteres que aparezcan en esos archivos).

Salida (por defecto assets/GBA/fonts/bmp/): <name>.fnt + <name>-white.png + .import
Uso:
    python tools/build_jp_bitmap_font.py --name hiragana --block hiragana \
        --fonts assets/GBA/fonts/Mona10x12.ttf
    python tools/build_jp_bitmap_font.py --name kanji --block kanji \
        --fonts Mona10x12.ttf fuente_kanji.ttf   # (Mona no trae kanji)
"""

import argparse
import hashlib
import os
import sys

try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError:
    sys.exit("Falta Pillow. Instala con: pip install Pillow")
try:
    from fontTools.ttLib import TTFont
except ImportError:
    sys.exit("Falta fontTools. Instala con: pip install fonttools")

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
DEFAULT_OUT = os.path.join(ROOT, "assets", "GBA", "fonts", "bmp")

# Bloques Unicode predefinidos (rangos inclusivos).
BLOCKS = {
    "hiragana": [(0x3041, 0x3096), (0x3099, 0x309F)],
    "katakana": [(0x30A0, 0x30FF)],
    "kanji":    [(0x4E00, 0x9FFF)],
    "ascii":    [(0x20, 0x7E)],
}


def font_codepoints(path):
    """Unión de TODOS los subtables cmap (algunas TTF reparten glifos en varios)."""
    cps = set()
    for st in TTFont(path)["cmap"].tables:
        cps |= set(st.cmap.keys())
    return cps


def parse_ranges(spec):
    out = []
    for part in spec.split(","):
        part = part.strip()
        if not part:
            continue
        if "-" in part:
            a, b = part.split("-", 1)
            out.append((int(a, 16), int(b, 16)))
        else:
            v = int(part, 16)
            out.append((v, v))
    return out


def target_codepoints(args):
    cps = set()
    if args.block:
        for a, b in BLOCKS[args.block]:
            cps.update(range(a, b + 1))
    if args.ranges:
        for a, b in parse_ranges(args.ranges):
            cps.update(range(a, b + 1))
    for path in (args.from_text or []):
        with open(path, encoding="utf-8") as f:
            for ch in f.read():
                cps.add(ord(ch))
    return cps


def build(args):
    font_paths = [p if os.path.isabs(p) else os.path.join(ROOT, p) for p in args.fonts]
    for p in font_paths:
        if not os.path.exists(p):
            sys.exit("No existe la fuente %s" % p)
    faces = [ImageFont.truetype(p, args.size) for p in font_paths]
    covers = [font_codepoints(p) for p in font_paths]
    metrics = [f.getmetrics() for f in faces]           # (ascent, descent)
    max_asc = max(m[0] for m in metrics)
    max_desc = max(m[1] for m in metrics)
    cell_h = max_asc + max_desc

    targets = sorted(target_codepoints(args))
    # Resuelve cada cp a la primera fuente que lo tenga; mide su avance.
    glyphs = []          # (cp, font_index, advance)
    missing = []
    max_adv = 0
    for cp in targets:
        fi = next((i for i, cov in enumerate(covers) if cp in cov), -1)
        if fi < 0:
            missing.append(cp)
            continue
        adv = int(round(faces[fi].getlength(chr(cp))))
        if adv <= 0:
            adv = args.size
        max_adv = max(max_adv, adv)
        glyphs.append((cp, fi, adv))

    if not glyphs:
        print("Ningún glifo disponible para '%s' en las fuentes dadas "
              "(¿la fuente no cubre ese bloque?). No se escribe nada." % (args.name,))
        if missing:
            print("  faltan %d code points (p. ej. %s)" % (
                len(missing), " ".join("U+%04X" % c for c in missing[:8])))
        return 1

    cell_w = max_adv
    cols = args.cols
    rows = (len(glyphs) + cols - 1) // cols
    atlas = Image.new("RGBA", (cols * cell_w, rows * cell_h), (0, 0, 0, 0))

    char_lines = []
    for idx, (cp, fi, adv) in enumerate(glyphs):
        col, row = idx % cols, idx // cols
        cx, cy = col * cell_w, row * cell_h
        cell = Image.new("RGBA", (cell_w, cell_h), (0, 0, 0, 0))
        d = ImageDraw.Draw(cell)
        # Alinea las líneas base de todas las fuentes en max_asc.
        y_top = max_asc - metrics[fi][0]
        d.text((0, y_top), chr(cp), font=faces[fi], fill=(255, 255, 255, 255))
        # Umbraliza el alfa → 1 bit (nítido, sin AA), como las sprite-fonts LT.
        px = cell.load()
        for yy in range(cell_h):
            for xx in range(cell_w):
                a = px[xx, yy][3]
                px[xx, yy] = (255, 255, 255, 255) if a >= 128 else (0, 0, 0, 0)
        atlas.alpha_composite(cell, (cx, cy))
        char_lines.append("char id=%d x=%d y=%d width=%d height=%d xoffset=0 "
                          "yoffset=0 xadvance=%d page=0 chnl=15"
                          % (cp, cx, cy, cell_w, cell_h, adv))

    os.makedirs(args.out, exist_ok=True)
    png_name = "%s-white.png" % args.name
    atlas.save(os.path.join(args.out, png_name))

    head = [
        'info face="%s" size=%d bold=0 italic=0 charset="" unicode=1 stretchH=100 '
        'smooth=0 aa=1 padding=0,0,0,0 spacing=0,0 outline=0' % (args.name, cell_h),
        'common lineHeight=%d base=%d scaleW=%d scaleH=%d pages=1 packed=0'
        % (cell_h, max_asc, atlas.width, atlas.height),
        'page id=0 file="%s"' % png_name,
        'chars count=%d' % len(glyphs),
    ]
    fnt_path = os.path.join(args.out, "%s.fnt" % args.name)
    with open(fnt_path, "w", encoding="utf-8") as f:
        f.write("\n".join(head + char_lines) + "\n")
    _write_import(fnt_path, args.name)

    print("[%s] %s + %s  (%d glifos, celda %dx%d, atlas %dx%d)"
          % (args.name, os.path.relpath(fnt_path, ROOT), png_name,
             len(glyphs), cell_w, cell_h, atlas.width, atlas.height))
    if missing:
        print("  [aviso] %d code points del objetivo NO están en ninguna fuente "
              "(se omiten; añade otra fuente pixel-art al final de --fonts para "
              "cubrirlos). Ej.: %s"
              % (len(missing), " ".join("U+%04X" % c for c in missing[:8])))
    return 0


def _write_import(fnt_path, name):
    """Crea un .import válido para el importador font_data_bmfont de Godot.
    El hash/uid se derivan del nombre (Godot re-importa y los normaliza al abrir)."""
    h = hashlib.md5(name.encode("utf-8")).hexdigest()
    uid = "uid://b%s" % h[:12]
    rel = os.path.relpath(fnt_path, ROOT).replace(os.sep, "/")
    dest = "res://.godot/imported/%s.fnt-%s.fontdata" % (name, h)
    text = (
        "[remap]\n\n"
        'importer="font_data_bmfont"\n'
        'type="FontFile"\n'
        'uid="%s"\n'
        'path="%s"\n\n'
        "[deps]\n\n"
        'source_file="res://%s"\n'
        'dest_files=["%s"]\n\n'
        "[params]\n\n"
        "fallbacks=[]\n"
        "compress=true\n"
        "scaling_mode=2\n" % (uid, dest, rel, dest)
    )
    with open(fnt_path + ".import", "w", encoding="utf-8") as f:
        f.write(text)


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--name", required=True, help="Nombre de salida (hiragana/katakana/kanji).")
    ap.add_argument("--fonts", nargs="+", required=True,
                    help="Fuentes TTF en orden de preferencia (principal primero).")
    ap.add_argument("--block", choices=sorted(BLOCKS), help="Bloque Unicode predefinido.")
    ap.add_argument("--ranges", help='Rangos hex extra, p. ej. "3041-3096,30FC".')
    ap.add_argument("--from-text", nargs="*", help="Archivos a escanear por caracteres usados.")
    ap.add_argument("--size", type=int, default=12, help="Tamaño de rasterizado en px (default 12).")
    ap.add_argument("--cols", type=int, default=32, help="Columnas del atlas (default 32).")
    ap.add_argument("--out", default=DEFAULT_OUT, help="Carpeta destino (default assets/GBA/fonts/bmp).")
    args = ap.parse_args()
    if not (args.block or args.ranges or args.from_text):
        ap.error("indica --block, --ranges y/o --from-text")
    return build(args)


if __name__ == "__main__":
    raise SystemExit(main())
