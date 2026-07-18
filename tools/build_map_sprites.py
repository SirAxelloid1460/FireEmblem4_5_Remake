#!/usr/bin/env python3
# build_map_sprites.py
# =============================================================================
# Convierte map sprites de origen (fondo verde "color key") a NUESTRO formato
# canónico LT-maker, limpiando el fondo a transparente.
#
# FORMATO DESTINO (ver Scripts/UnitSprite.gd / UnitMapSprite.gd):
#   {clase}-stand.png  →  192×144, rejilla 3 cols × 3 filas, celda 64×48:
#       fila 0: passive (idle, 3 frames)          ← animación idle en el mapa
#       fila 1: gray    (unidad ya actuada)        ← se SINTETIZA (gris) por def.
#       fila 2: active  (seleccionada / parpadeo)  ← se SINTETIZA (= idle) por def.
#   {clase}-move.png   →  192×160, rejilla 4 cols × 4 filas, celda 48×40:
#       fila 0: down    fila 1: left    fila 2: right    fila 3: up   (4 frames c/u)
#   · La fila RIGHT es el ESPEJO horizontal de LEFT (así están los 152 sprites del
#     proyecto), por eso el origen suele traer sólo 3 direcciones y --mirror-right
#     genera la derecha. El personaje se ancla por los PIES en y=40 (líneas de pie
#     medidas en los sprites existentes: stand=40 constante, move≈40).
#
# COLOR KEY: el verde LT (129,160,128) se vuelve transparente (con tolerancia).
#
# FORMATO GBAFE (el habitual): idle y walk vienen en DOS archivos con tamaños de
# frame distintos, así que se pasan por separado:
#   --src-stand  columna 16×48  → 3 frames de 16×16   (idle)
#   --src-move   columna 32×480 → 12 frames de 32×32  (3 dir × 4, right = mirror)
#
# La herramienta NO adivina qué frame es cada cosa: idle por --idle; caminar por
# --walk-<dir> explícitos o por bloques regulares (--walk-order/--walk-len/
# --walk-start). Defaults afinados al caso GBAFE de arriba.
#
# Uso (una clase, formato GBAFE con defaults):
#   python tools/build_map_sprites.py --name Cavalier \
#       --src-stand in/Cavalier_stand.png --src-move in/Cavalier_move.png
#   # equivale a: --stand-frame 16x16 --idle 0,1,2 --move-frame 32x32 \
#   #             --walk-order down,up,left --walk-len 4 --walk-start 0 --mirror-right
#
# Inspeccionar un origen (nº de frames, alto detectado):
#   python tools/build_map_sprites.py --src-move in/Cavalier_move.png --inspect
#
# Si up/left salen intercambiados, cambia --walk-order (p.ej. down,left,up).
#
# Modo LOTE (una carpeta con pares '{X}-stand.png' + '{X}-walk.png'):
#   # parado en la carpeta de sprites (crea ./map_sprites y mete ahí la salida):
#   cd "C:\...\FE4 Map Sprites"
#   python C:\ruta\al\repo\tools\build_map_sprites.py --batch .
#   · Empareja por prefijo, deriva el nombre limpiándolo:
#       'Bard (U) {Stephano, Zane}' → 'Bard'   (usa --raw-names para dejarlo tal cual)
#   · Acepta el sufijo -walk.png o -move.png para el caminar.
#
# SALIDA: por defecto una carpeta 'map_sprites' en el DIRECTORIO ACTUAL. Para
# escribir directo al proyecto: --out <repo>/assets/GBA/map_sprites.
# =============================================================================

import argparse
import os
import re
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
FEET_Y = 40                      # línea de pies (y en la celda) medida en los sprites
DIRS = ("down", "left", "right", "up")   # orden de filas en -move.png


# ── Limpieza del color key ───────────────────────────────────────────────────
def clean_key(img, key=KEY_RGB, tol=8):
    """Copia RGBA con los píxeles ~= key vueltos transparentes."""
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
    px = img.load()
    kr, kg, kb = key
    for x in range(img.size[0]):
        r, g, b, a = px[x, y]
        if not (abs(r - kr) <= tol and abs(g - kg) <= tol and abs(b - kb) <= tol):
            return False
    return True


# ── Detección / recorte de frames ────────────────────────────────────────────
def detect_frames_vertical(img, key=KEY_RGB, tol=8):
    """Bandas no-key de una TIRA VERTICAL: lista de (top, bottom). Sólo fiable si
    los frames están separados por al menos una fila totalmente de color key."""
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
        bands.append((top, y))
    return bands


def slice_frames(img, frame_wh=None, count=None):
    """Recorta el origen en frames RGBA limpios de color key.
    frame_wh=(fw,fh) → rejilla regular; si no → autodetección por bandas."""
    clean = clean_key(img)
    frames = []
    if frame_wh:
        fw, fh = frame_wh
        w, h = img.size
        for ry in range(max(1, h // fh)):
            for cx in range(max(1, w // fw)):
                frames.append(clean.crop((cx * fw, ry * fh, cx * fw + fw, ry * fh + fh)))
    else:
        for (top, bot) in detect_frames_vertical(img):
            frames.append(clean.crop((0, top, img.size[0], bot)))
    if count is not None:
        frames = frames[:count]
    return frames


# ── Composición al formato destino ───────────────────────────────────────────
def _place(dst, frame, cell_x, cell_y, cell_w, cell_h, feet_y=FEET_Y):
    """Pega `frame` en la celda anclando por su CONTENIDO: centrado horizontal y
    con el borde inferior del contenido en la línea de pies (cell_y + feet_y).
    Robusto ante padding del frame de origen."""
    bbox = frame.getbbox()
    if bbox is None:
        return
    content_cx = (bbox[0] + bbox[2]) / 2.0
    ox = cell_x + int(round(cell_w / 2.0 - content_cx))
    oy = cell_y + feet_y - bbox[3]   # bbox[3] = borde inferior del contenido
    dst.alpha_composite(frame, (ox, oy))


def _desaturate(frame, darken=0.75):
    """Versión gris (unidad ya actuada): luminancia * darken, conservando alpha."""
    out = frame.copy()
    px = out.load()
    for y in range(out.size[1]):
        for x in range(out.size[0]):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            lum = max(0, min(255, int((0.299 * r + 0.587 * g + 0.114 * b) * darken)))
            px[x, y] = (lum, lum, lum, a)
    return out


def _fit(frames, n):
    """Recorta/rellena a n elementos repitiendo el último."""
    out = list(frames)[:n]
    while out and len(out) < n:
        out.append(out[-1])
    return out


def compose_stand(idle_frames, feet_y=FEET_Y,
                  gray_frames=None, active_frames=None,
                  synth_gray=True, synth_active=True):
    """Construye -stand.png (192×144): fila idle / gris / activo."""
    if not idle_frames:
        raise ValueError("compose_stand: se requieren frames idle")
    sheet = Image.new("RGBA", (STAND_COLS * STAND_CELL[0], STAND_ROWS * STAND_CELL[1]), (0, 0, 0, 0))
    idle = _fit(idle_frames, STAND_COLS)
    if gray_frames:
        gray = _fit(gray_frames, STAND_COLS)
    elif synth_gray:
        gray = [_desaturate(f) for f in idle]
    else:
        gray = idle
    if active_frames:
        active = _fit(active_frames, STAND_COLS)
    elif synth_active:
        active = idle
    else:
        active = idle
    for row, frames in enumerate((idle, gray, active)):
        for col, fr in enumerate(frames):
            _place(sheet, fr, col * STAND_CELL[0], row * STAND_CELL[1], STAND_CELL[0], STAND_CELL[1], feet_y)
    return sheet


def compose_move(walk_by_dir, feet_y=FEET_Y, mirror_right=True):
    """Construye -move.png (192×160). walk_by_dir = dict dir→lista de frames.
    Si mirror_right y falta 'right' pero hay 'left', genera derecha = espejo(izq)."""
    walk = dict(walk_by_dir)
    if mirror_right and not walk.get("right") and walk.get("left"):
        walk["right"] = [f.transpose(Image.FLIP_LEFT_RIGHT) for f in walk["left"]]
    sheet = Image.new("RGBA", (MOVE_COLS * MOVE_CELL[0], MOVE_ROWS * MOVE_CELL[1]), (0, 0, 0, 0))
    for row, d in enumerate(DIRS):
        frames = walk.get(d) or []
        if not frames:
            continue
        frames = _fit(frames, MOVE_COLS)
        for col in range(MOVE_COLS):
            _place(sheet, frames[col], col * MOVE_CELL[0], row * MOVE_CELL[1], MOVE_CELL[0], MOVE_CELL[1], feet_y)
    return sheet


# ── CLI ──────────────────────────────────────────────────────────────────────
def _parse_idx(s):
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
            sys.exit("Índice %d fuera de rango para %s (hay %d frames)." % (i, what, len(frames)))
        out.append(frames[i])
    return out


def _walk_map(frames, args):
    """dir→frames desde --walk-<dir> explícitos, o bloques regulares."""
    if any([args.walk_down, args.walk_left, args.walk_right, args.walk_up]):
        return {
            "down": _pick(frames, _parse_idx(args.walk_down), "walk-down"),
            "left": _pick(frames, _parse_idx(args.walk_left), "walk-left"),
            "right": _pick(frames, _parse_idx(args.walk_right), "walk-right"),
            "up": _pick(frames, _parse_idx(args.walk_up), "walk-up"),
        }
    order = [d.strip() for d in args.walk_order.split(",") if d.strip()]
    n, start = args.walk_len, args.walk_start
    result = {}
    for k, d in enumerate(order):
        idx = list(range(start + k * n, start + k * n + n))
        if idx and idx[-1] < len(frames):
            result[d] = [frames[i] for i in idx]
    return result


def _inspect(path, frame_wh):
    img = Image.open(path)
    frames = slice_frames(img, frame_wh=frame_wh)
    print("%s  %s  →  %d frames" % (os.path.basename(path), img.size, len(frames)))
    if not frame_wh:
        for i, (t, b) in enumerate(detect_frames_vertical(img)):
            print("   frame %2d: y=%d..%d (alto %d)" % (i, t, b, b - t))


def convert(name, out_dir, args, stand_path=None, move_path=None):
    stand_path = stand_path if stand_path is not None else args.src_stand
    move_path = move_path if move_path is not None else args.src_move
    made = []
    # STAND
    if stand_path:
        if args.inspect:
            _inspect(stand_path, _frame_wh(args.stand_frame))
        else:
            sframes = slice_frames(Image.open(stand_path), _frame_wh(args.stand_frame))
            idle = _pick(sframes, _parse_idx(args.idle), "idle")
            gray = _pick(sframes, _parse_idx(args.gray), "gray") if args.gray else None
            active = _pick(sframes, _parse_idx(args.active), "active") if args.active else None
            stand = compose_stand(idle, args.feet_y, gray, active,
                                  synth_gray=not args.no_synth_gray,
                                  synth_active=not args.no_synth_active)
            p = os.path.join(out_dir, "%s-stand.png" % name)
            stand.save(p)
            made.append(p)
    # MOVE
    if move_path:
        if args.inspect:
            _inspect(move_path, _frame_wh(args.move_frame))
        else:
            mframes = slice_frames(Image.open(move_path), _frame_wh(args.move_frame))
            wm = _walk_map(mframes, args)
            if any(wm.values()):
                move = compose_move(wm, args.feet_y, mirror_right=not args.no_mirror_right)
                p = os.path.join(out_dir, "%s-move.png" % name)
                move.save(p)
                made.append(p)
    if not args.inspect:
        if made:
            print("[%s] escrito: %s" % (name, ", ".join(os.path.relpath(m) for m in made)))
        else:
            print("[%s] nada que escribir (¿faltó --src-stand/--src-move o --idle/--walk-*?)" % name)


def _clean_name(prefix):
    """Deriva un NID limpio del prefijo del archivo: quita grupos '(...)' y
    '{...}' y colapsa espacios. Ej: 'Bard (U) {Stephano, Zane}' → 'Bard'."""
    s = re.sub(r"\([^)]*\)", "", prefix)
    s = re.sub(r"\{[^}]*\}", "", s)
    s = re.sub(r"\s+", " ", s).strip()
    return s or prefix.strip()


def run_batch(in_dir, out_dir, args):
    """Empareja '{X}-stand.png' con '{X}-walk.png' (o '-move.png') en in_dir y
    convierte cada par. El nombre de salida se limpia salvo --raw-names."""
    files = os.listdir(in_dir)
    stands = sorted(f for f in files if f.lower().endswith("-stand.png"))
    if not stands:
        sys.exit("No hay archivos '*-stand.png' en %s" % in_dir)
    lower = {f.lower(): f for f in files}
    n = 0
    for sf in stands:
        prefix = sf[:-len("-stand.png")]
        move = None
        for suf in ("-walk.png", "-move.png"):
            cand = (prefix + suf).lower()
            if cand in lower:
                move = lower[cand]
                break
        name = prefix if args.raw_names else _clean_name(prefix)
        if not args.inspect and prefix != name:
            print("  %-40s → %s" % (prefix, name))
        convert(name, out_dir, args,
                stand_path=os.path.join(in_dir, sf),
                move_path=os.path.join(in_dir, move) if move else None)
        n += 1
    print("Lote: %d clase(s) procesada(s)." % n)


def main():
    ap = argparse.ArgumentParser(description="Convierte map sprites (fondo verde) al formato LT del proyecto.")
    ap.add_argument("--src-stand", help="PNG de origen del idle (formato GBAFE: columna 16×48).")
    ap.add_argument("--src-move", help="PNG de origen del caminar/-walk (formato GBAFE: columna 32×480).")
    ap.add_argument("--batch", help="Carpeta con pares '{X}-stand.png' + '{X}-walk.png' (o -move.png); convierte todos.")
    ap.add_argument("--raw-names", action="store_true", help="En lote, no limpiar el nombre (deja 'Bard (U) {..}').")
    ap.add_argument("--name", help="Nombre de clase de salida (obligatorio salvo --inspect / --batch).")
    ap.add_argument("--out", default="map_sprites",
                    help="Carpeta destino (default: 'map_sprites' en el directorio actual). "
                         "Para escribir directo al proyecto: --out ruta/al/repo/assets/GBA/map_sprites.")

    ap.add_argument("--stand-frame", default="16x16", help="Tamaño de frame del idle (default 16x16). Vacío = autodetecta.")
    ap.add_argument("--move-frame", default="32x32", help="Tamaño de frame del caminar (default 32x32). Vacío = autodetecta.")
    ap.add_argument("--feet-y", type=int, default=FEET_Y, help="Línea de pies en la celda (default %d)." % FEET_Y)

    ap.add_argument("--idle", default="0,1,2", help="Índices de frame idle (default 0,1,2).")
    ap.add_argument("--gray", default="", help="Índices para la fila gris (si el origen la trae).")
    ap.add_argument("--active", default="", help="Índices para la fila activa (si el origen la trae).")
    ap.add_argument("--no-synth-gray", action="store_true", help="No sintetizar la fila gris.")
    ap.add_argument("--no-synth-active", action="store_true", help="No sintetizar la fila activa.")

    ap.add_argument("--walk-down", default="", help="Índices de caminar ABAJO (modo explícito).")
    ap.add_argument("--walk-left", default="", help="Índices de caminar IZQUIERDA.")
    ap.add_argument("--walk-right", default="", help="Índices de caminar DERECHA.")
    ap.add_argument("--walk-up", default="", help="Índices de caminar ARRIBA.")
    ap.add_argument("--walk-order", default="down,up,left",
                    help="Orden de bloques regulares (default GBAFE: down,up,left; right se espeja).")
    ap.add_argument("--walk-len", type=int, default=4, help="Frames por dirección (default 4).")
    ap.add_argument("--walk-start", type=int, default=0, help="Índice del 1er frame de caminar (default 0).")
    ap.add_argument("--no-mirror-right", action="store_true", help="No generar la derecha espejando la izquierda.")

    ap.add_argument("--inspect", action="store_true", help="Sólo reporta frames detectados; no escribe.")
    args = ap.parse_args()

    os.makedirs(args.out, exist_ok=True)
    if args.batch:
        run_batch(args.batch, args.out, args)
        return
    if not args.src_stand and not args.src_move:
        ap.error("Indica --batch, o --src-stand y/o --src-move.")
    if not args.inspect and not args.name:
        ap.error("--name es obligatorio (salvo --inspect / --batch).")
    convert(args.name or "sprite", args.out, args)


if __name__ == "__main__":
    main()
