#!/usr/bin/env python3
# build_map_sprites.py
# =============================================================================
# Convierte map sprites de origen (tiras / sheets con fondo verde "color key")
# a NUESTRO formato canónico LT-maker, limpiando el fondo a transparente.
#
# FORMATO DESTINO (ver Scripts/UnitSprite.gd / UnitMapSprite.gd):
#   {clase}-stand.png  →  192×144, rejilla 3 cols × 3 filas, celda 64×48:
#       fila 0: passive (idle, 3 frames)          ← animación idle en el mapa
#       fila 1: gray    (unidad ya actuada)        ← se puede SINTETIZAR (gris)
#       fila 2: active  (seleccionada / parpadeo)  ← se puede SINTETIZAR (= idle)
#   {clase}-move.png   →  192×160, rejilla 4 cols × 4 filas, celda 48×40:
#       fila 0: down    fila 1: left    fila 2: right    fila 3: up   (4 frames c/u)
#
# COLOR KEY: el verde LT (129,160,128) se vuelve transparente (con tolerancia).
#
# CLAVE DE DISEÑO: esta herramienta NO adivina qué frame de tu tira es cada cosa.
# Recorta el origen en frames (autodetectado o por --frame WxH) y coloca cada uno
# en la celda destino SEGÚN LOS ÍNDICES que indiques. Así el mapeo es explícito y
# correcto sea cual sea la convención del origen. Los defaults asumen el layout
# más común (una columna vertical: primero los frames idle, luego caminar por
# dirección abajo/izq/der/arriba), pero se sobreescriben por CLI.
#
# Uso típico (un archivo):
#   # 1) Inspeccionar: ¿cuántos frames y de qué tamaño detecta?
#   python tools/build_map_sprites.py --src in/Cavalier.png --inspect
#
#   # 2) Convertir a stand+move (indica los índices de frame de cada cosa):
#   python tools/build_map_sprites.py --src in/Cavalier.png --name Cavalier \
#       --frame 24x32 \
#       --idle 0,1,2 \
#       --walk-down 3,4,5,6 --walk-left 7,8,9,10 \
#       --walk-right 11,12,13,14 --walk-up 15,16,17,18
#
#   # Sólo stand (idle), sintetizando gris/activo:
#   python tools/build_map_sprites.py --src in/Priest.png --name Priest \
#       --idle 0,1,2 --no-move
#
# Modo lote (una carpeta de PNGs → assets/.../map_sprites/):
#   python tools/build_map_sprites.py --src-dir in/ --out assets/GBA/map_sprites/ \
#       --frame 24x32 --idle 0,1,2 --walk-order down,left,right,up --walk-len 4 \
#       --walk-start 3
#
# Genera "{out}/{name}-stand.png" y "{out}/{name}-move.png".
# =============================================================================

import argparse
import os
import sys

try:
    from PIL import Image
except ImportError:
    sys.exit("Falta Pillow. Instala con: pip install Pillow")

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(HERE)

# Color key LT y formato destino (no tocar salvo que cambie el motor).
KEY_RGB = (129, 160, 128)
STAND_COLS, STAND_ROWS = 3, 3
STAND_CELL = (64, 48)
MOVE_COLS, MOVE_ROWS = 4, 4
MOVE_CELL = (48, 40)

DIRS = ("down", "left", "right", "up")   # orden de filas en -move.png


# ── Limpieza del color key ───────────────────────────────────────────────────
def clean_key(img, key=KEY_RGB, tol=8):
    """Devuelve una copia RGBA con los píxeles ~= key vueltos transparentes."""
    img = img.convert("RGBA")
    px = img.load()
    w, h = img.size
    kr, kg, kb = key
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a != 0 and abs(r - kr) <= tol and abs(g - kg) <= tol and abs(b - kb) <= tol:
                px[x, y] = (0, 0, 0, 0)
    return img


def _row_is_key(img, y, key, tol):
    """¿La fila y es enteramente color key (separador/gutter)?"""
    px = img.load()
    w = img.size[0]
    kr, kg, kb = key
    for x in range(w):
        r, g, b, a = px[x, y]
        if not (abs(r - kr) <= tol and abs(g - kg) <= tol and abs(b - kb) <= tol):
            return False
    return True


# ── Detección / recorte de frames ────────────────────────────────────────────
def detect_frames_vertical(img, key=KEY_RGB, tol=8):
    """Autodetecta frames en una TIRA VERTICAL separando por bandas de color key.
    Devuelve lista de (top, bottom) de cada bloque no-key. Sólo fiable si los
    frames están separados por al menos una fila totalmente verde."""
    h = img.size[1]
    bands = []
    y = 0
    while y < h:
        if _row_is_key(img, y, key, tol):
            y += 1
            continue
        top = y
        while y < h and not _row_is_key(img, y, key, tol):
            y += 1
        bands.append((top, y))   # [top, bottom)
    return bands


def slice_frames(img, frame_wh=None, count=None):
    """Recorta el origen en una lista de frames RGBA (ya limpios de color key).
    - Si frame_wh=(fw,fh): rejilla regular (columnas = w//fw, filas = h//fh),
      en orden fila-por-fila.
    - Si no: autodetección por bandas verticales."""
    clean = clean_key(img)
    frames = []
    if frame_wh:
        fw, fh = frame_wh
        w, h = img.size
        cols = max(1, w // fw)
        rows = max(1, h // fh)
        for ry in range(rows):
            for cx in range(cols):
                box = (cx * fw, ry * fh, cx * fw + fw, ry * fh + fh)
                frames.append(clean.crop(box))
    else:
        for (top, bot) in detect_frames_vertical(img):
            frames.append(clean.crop((0, top, img.size[0], bot)))
    if count is not None:
        frames = frames[:count]
    return frames


# ── Composición al formato destino ───────────────────────────────────────────
def _place(dst, frame, cell_x, cell_y, cell_w, cell_h, anchor="bottom"):
    """Pega `frame` centrado horizontalmente en la celda (cell_x,cell_y) de dst.
    anchor='bottom' alinea los pies al borde inferior de la celda (coincide con
    el anclaje por pies del motor); 'center' centra vertical."""
    fw, fh = frame.size
    ox = cell_x + (cell_w - fw) // 2
    if anchor == "center":
        oy = cell_y + (cell_h - fh) // 2
    else:  # bottom
        oy = cell_y + (cell_h - fh)
    dst.alpha_composite(frame, (ox, oy))


def _desaturate(frame, darken=0.75):
    """Versión gris (unidad ya actuada): luminancia * darken, conservando alpha."""
    out = frame.copy()
    px = out.load()
    w, h = out.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            lum = int((0.299 * r + 0.587 * g + 0.114 * b) * darken)
            lum = max(0, min(255, lum))
            px[x, y] = (lum, lum, lum, a)
    return out


def compose_stand(idle_frames, anchor="bottom",
                  gray_frames=None, active_frames=None,
                  synth_gray=True, synth_active=True):
    """Construye el sheet -stand.png (192×144). idle_frames = lista (se usan los
    3 primeros; si hay menos, se repite el último). Filas gris/activo se toman de
    gray_frames/active_frames o se sintetizan."""
    sheet = Image.new("RGBA", (STAND_COLS * STAND_CELL[0], STAND_ROWS * STAND_CELL[1]), (0, 0, 0, 0))
    if not idle_frames:
        raise ValueError("compose_stand: se requieren frames idle")

    def col_frames(src):
        out = list(src)[:STAND_COLS]
        while len(out) < STAND_COLS:
            out.append(out[-1])
        return out

    idle = col_frames(idle_frames)
    if gray_frames:
        gray = col_frames(gray_frames)
    elif synth_gray:
        gray = [_desaturate(f) for f in idle]
    else:
        gray = idle
    if active_frames:
        active = col_frames(active_frames)
    elif synth_active:
        active = idle   # sin pose activa en el origen → reutiliza idle
    else:
        active = idle

    for row, frames in enumerate((idle, gray, active)):
        for col, fr in enumerate(frames):
            _place(sheet, fr, col * STAND_CELL[0], row * STAND_CELL[1],
                   STAND_CELL[0], STAND_CELL[1], anchor)
    return sheet


def compose_move(walk_by_dir, anchor="bottom"):
    """Construye -move.png (192×160). walk_by_dir = dict dir→lista de frames.
    Usa 4 frames por dirección (repite el último si faltan; celda vacía si no hay
    ninguna para esa dirección)."""
    sheet = Image.new("RGBA", (MOVE_COLS * MOVE_CELL[0], MOVE_ROWS * MOVE_CELL[1]), (0, 0, 0, 0))
    for row, d in enumerate(DIRS):
        frames = list(walk_by_dir.get(d, []) or [])
        if not frames:
            continue
        while len(frames) < MOVE_COLS:
            frames.append(frames[-1])
        for col in range(MOVE_COLS):
            _place(sheet, frames[col], col * MOVE_CELL[0], row * MOVE_CELL[1],
                   MOVE_CELL[0], MOVE_CELL[1], anchor)
    return sheet


# ── CLI ──────────────────────────────────────────────────────────────────────
def _parse_idx(s):
    """'0,1,2' → [0,1,2]; '' → []."""
    s = (s or "").strip()
    return [int(x) for x in s.split(",") if x.strip() != ""] if s else []


def _frame_wh(s):
    if not s:
        return None
    a, b = s.lower().split("x")
    return (int(a), int(b))


def _pick(frames, indices, what):
    out = []
    for i in indices:
        if i < 0 or i >= len(frames):
            sys.exit("Índice de frame %d fuera de rango para %s (hay %d frames)." % (i, what, len(frames)))
        out.append(frames[i])
    return out


def _walk_map(frames, args):
    """Construye dir→frames desde --walk-<dir> explícitos, o desde el orden
    regular --walk-order/--walk-len/--walk-start."""
    explicit = any([args.walk_down, args.walk_left, args.walk_right, args.walk_up])
    result = {}
    if explicit:
        result["down"] = _pick(frames, _parse_idx(args.walk_down), "walk-down")
        result["left"] = _pick(frames, _parse_idx(args.walk_left), "walk-left")
        result["right"] = _pick(frames, _parse_idx(args.walk_right), "walk-right")
        result["up"] = _pick(frames, _parse_idx(args.walk_up), "walk-up")
        return result
    # Regular: bloques contiguos de --walk-len desde --walk-start, en --walk-order.
    order = [d.strip() for d in args.walk_order.split(",") if d.strip()]
    n = args.walk_len
    start = args.walk_start
    for k, d in enumerate(order):
        idx = list(range(start + k * n, start + k * n + n))
        # sólo incluye si todos los índices existen
        if idx and idx[-1] < len(frames):
            result[d] = [frames[i] for i in idx]
    return result


def convert_one(src_path, out_dir, name, args):
    img = Image.open(src_path)
    frames = slice_frames(img, frame_wh=_frame_wh(args.frame), count=args.count)
    if args.inspect:
        print("[%s] %s  →  %d frames detectados" % (name, img.size, len(frames)))
        if not _frame_wh(args.frame):
            bands = detect_frames_vertical(img)
            for i, (t, b) in enumerate(bands):
                print("   frame %2d: y=%d..%d (alto %d)" % (i, t, b, b - t))
        return

    made = []
    # stand
    idle_idx = _parse_idx(args.idle)
    if idle_idx:
        idle = _pick(frames, idle_idx, "idle")
        gray = _pick(frames, _parse_idx(args.gray), "gray") if args.gray else None
        active = _pick(frames, _parse_idx(args.active), "active") if args.active else None
        stand = compose_stand(idle, args.anchor, gray, active,
                              synth_gray=not args.no_synth_gray,
                              synth_active=not args.no_synth_active)
        p = os.path.join(out_dir, "%s-stand.png" % name)
        stand.save(p)
        made.append(p)
    # move
    if not args.no_move:
        wm = _walk_map(frames, args)
        if any(wm.values()):
            move = compose_move(wm, args.anchor)
            p = os.path.join(out_dir, "%s-move.png" % name)
            move.save(p)
            made.append(p)
    if made:
        print("[%s] escrito: %s" % (name, ", ".join(os.path.relpath(m, PROJECT_ROOT) for m in made)))
    else:
        print("[%s] nada que escribir (¿faltó --idle / --walk-*?)" % name)


def main():
    ap = argparse.ArgumentParser(description="Convierte map sprites (fondo verde) al formato LT del proyecto.")
    src = ap.add_mutually_exclusive_group(required=True)
    src.add_argument("--src", help="PNG de origen (un solo sprite).")
    src.add_argument("--src-dir", help="Carpeta de PNGs (modo lote; --name se toma del nombre de archivo).")
    ap.add_argument("--name", help="Nombre de clase de salida (obligatorio con --src).")
    ap.add_argument("--out", default=os.path.join(PROJECT_ROOT, "assets", "GBA", "map_sprites"),
                    help="Carpeta destino (default assets/GBA/map_sprites/).")

    ap.add_argument("--frame", help="Tamaño de frame 'WxH' (rejilla regular). Si se omite, autodetecta por bandas verdes.")
    ap.add_argument("--count", type=int, default=None, help="Limita al número de frames leídos.")
    ap.add_argument("--anchor", choices=["bottom", "center"], default="bottom",
                    help="Anclaje del frame en la celda destino (default bottom = pies).")

    ap.add_argument("--idle", default="", help="Índices de frame idle, p.ej. '0,1,2'.")
    ap.add_argument("--gray", default="", help="Índices para la fila gris (si el origen la trae).")
    ap.add_argument("--active", default="", help="Índices para la fila activa (si el origen la trae).")
    ap.add_argument("--no-synth-gray", action="store_true", help="No sintetizar la fila gris (dejar = idle).")
    ap.add_argument("--no-synth-active", action="store_true", help="No sintetizar la fila activa.")

    ap.add_argument("--no-move", action="store_true", help="No generar -move.png (sólo stand).")
    ap.add_argument("--walk-down", default="", help="Índices de caminar ABAJO.")
    ap.add_argument("--walk-left", default="", help="Índices de caminar IZQUIERDA.")
    ap.add_argument("--walk-right", default="", help="Índices de caminar DERECHA.")
    ap.add_argument("--walk-up", default="", help="Índices de caminar ARRIBA.")
    ap.add_argument("--walk-order", default="down,left,right,up",
                    help="Orden de bloques regulares de caminar (si no usas --walk-<dir>).")
    ap.add_argument("--walk-len", type=int, default=4, help="Frames por dirección en modo regular.")
    ap.add_argument("--walk-start", type=int, default=3, help="Índice del 1er frame de caminar en modo regular.")

    ap.add_argument("--inspect", action="store_true", help="Sólo reporta tamaño y frames detectados; no escribe.")
    args = ap.parse_args()

    if args.src:
        if not args.inspect and not args.name:
            ap.error("--name es obligatorio con --src (salvo --inspect).")
        name = args.name or os.path.splitext(os.path.basename(args.src))[0]
        os.makedirs(args.out, exist_ok=True)
        convert_one(args.src, args.out, name, args)
    else:
        os.makedirs(args.out, exist_ok=True)
        pngs = sorted(f for f in os.listdir(args.src_dir) if f.lower().endswith(".png"))
        if not pngs:
            sys.exit("No hay PNGs en %s" % args.src_dir)
        for fn in pngs:
            name = os.path.splitext(fn)[0]
            convert_one(os.path.join(args.src_dir, fn), args.out, name, args)


if __name__ == "__main__":
    main()
