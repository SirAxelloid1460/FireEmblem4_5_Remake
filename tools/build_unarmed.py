#!/usr/bin/env python3
"""
build_unarmed.py

Genera una animación de combate "Unarmed" a partir de un sheet YA generado
(por build_combat_sheet.py), para las animaciones que no la traen.

Una unidad "desarmada" (sin arma equipada, o al quedarse sin usos) solo necesita
las poses pasivas: STAND (idle), DODGE (esquivar el golpe) y, si existe, MISS.
Todas esas poses ya están presentes en CUALQUIER sheet de arma del mismo
personaje/clase, así que este script:

  1. Lee un {prefix}_{Weapon}.png + .json existente.
  2. Extrae las poses Stand / Dodge / Miss y los frames que usan.
  3. Recorta esos frames del sheet fuente y compone un sheet nuevo (grid regular).
  4. Escribe {prefix}_Unarmed.png + .json  en la misma carpeta.

El {prefix} es "{NID}_{Variant}" (p.ej. Archer_Febail, ArcherKnight_Generic).

═══════════════════════════════════════════════════════════════════════════════
USO
═══════════════════════════════════════════════════════════════════════════════

  # Una carpeta concreta (genera su Unarmed si le falta):
  py build_unarmed.py assets/combat_anims/Archer_Febail/

  # TODO el árbol de combat_anims (recursivo) — genera el Unarmed que falte:
  py build_unarmed.py assets/combat_anims/ --recursive

  # Regenerar aunque ya exista:
  py build_unarmed.py assets/combat_anims/ --recursive --force

  # Ver qué haría sin escribir:
  py build_unarmed.py assets/combat_anims/ --recursive --dry-run

Notas:
  - Si una carpeta ya tiene un *_Unarmed.json, se salta (salvo --force).
  - Como fuente elige el primer sheet (que NO sea Unarmed) que tenga pose Stand.
  - Solo se necesita UN Unarmed por carpeta (por {NID}_{Variant}).
"""

import argparse
import json
import math
import sys
from pathlib import Path
from typing import Dict, List, Optional, Set

try:
    from PIL import Image
except ImportError:
    print("ERROR: necesita Pillow. Instala con: py -m pip install Pillow")
    sys.exit(1)


# Poses que necesita una unidad desarmada (en orden de preferencia).
UNARMED_POSES = ["Stand", "Dodge", "Miss"]


def _frames_used(poses: Dict[str, List[dict]]) -> Set[str]:
    used: Set[str] = set()
    for cmds in poses.values():
        for c in cmds:
            for k in ("frame", "frame_top", "frame_bottom"):
                name = c.get(k)
                if isinstance(name, str) and name:
                    used.add(name)
    return used


def generate_unarmed(src_json: Path, force: bool, dry_run: bool) -> str:
    """Genera {prefix}_Unarmed a partir de src_json. Devuelve un status string."""
    try:
        data = json.loads(src_json.read_text(encoding="utf-8"))
    except Exception as e:
        return f"err (json: {e})"

    src_poses: Dict[str, List[dict]] = data.get("poses", {})
    poses = {p: src_poses[p] for p in UNARMED_POSES if p in src_poses}
    if "Stand" not in poses:
        return "skip (fuente sin pose Stand)"

    nid = str(data.get("class", ""))
    variant = str(data.get("variant", "Generic"))
    prefix = "%s_%s" % (nid, variant)
    out_dir = src_json.parent
    out_png = out_dir / (prefix + "_Unarmed.png")
    out_json = out_dir / (prefix + "_Unarmed.json")

    if out_json.exists() and not force:
        return "skip (ya existe)"

    tile_size = data.get("tile_size", [240, 160])
    tile_w, tile_h = int(tile_size[0]), int(tile_size[1])
    src_frames: Dict[str, dict] = data.get("frames", {})

    used = _frames_used(poses)
    used = [n for n in used if n in src_frames]
    if not used:
        return "skip (poses sin frames)"

    if dry_run:
        return "ok (dry-run: %d frames, poses %s)" % (len(used), list(poses.keys()))

    # Cargar el sheet fuente y recortar cada frame por su tile.
    src_png = src_json.with_suffix(".png")
    if not src_png.exists():
        return "err (falta el .png fuente)"
    sheet = Image.open(src_png).convert("RGBA")

    crops: Dict[str, Image.Image] = {}
    for name in sorted(used):
        t = src_frames[name].get("tile", [0, 0])
        x, y = int(t[0]) * tile_w, int(t[1]) * tile_h
        crops[name] = sheet.crop((x, y, x + tile_w, y + tile_h))

    # Componer grid regular con las mismas celdas (tile_size incluye padding).
    n = len(crops)
    cols = max(1, int(math.ceil(math.sqrt(n))))
    rows = max(1, int(math.ceil(n / cols)))
    new_sheet = Image.new("RGBA", (cols * tile_w, rows * tile_h), (0, 0, 0, 0))
    frames_meta: Dict[str, dict] = {}
    for idx, name in enumerate(sorted(crops.keys())):
        col, row = idx % cols, idx // cols
        new_sheet.paste(crops[name], (col * tile_w, row * tile_h))
        frames_meta[name] = {"tile": [col, row]}

    new_sheet.save(out_png)
    meta = {
        "class": nid,
        "variant": variant,
        "weapon": "Unarmed",
        "tile_size": [tile_w, tile_h],
        "frame_size": data.get("frame_size", [tile_w, tile_h]),
        "padding": data.get("padding", 0),
        "grid": [cols, rows],
        "sheet_size": list(new_sheet.size),
        "frame_count": len(frames_meta),
        "frames": frames_meta,
        "poses": poses,
        "generated_from": src_json.name,
    }
    out_json.write_text(json.dumps(meta, indent=2, ensure_ascii=False), encoding="utf-8")
    return "ok (%d frames, poses %s)" % (len(frames_meta), list(poses.keys()))


def pick_source(folder: Path) -> Optional[Path]:
    """Elige el primer .json de la carpeta que NO sea Unarmed y tenga pose Stand."""
    for jp in sorted(folder.glob("*.json")):
        if jp.stem.endswith("_Unarmed"):
            continue
        try:
            d = json.loads(jp.read_text(encoding="utf-8"))
        except Exception:
            continue
        if "Stand" in d.get("poses", {}):
            return jp
    return None


def process_folder(folder: Path, force: bool, dry_run: bool) -> str:
    has_unarmed = any(jp.stem.endswith("_Unarmed") for jp in folder.glob("*.json"))
    if has_unarmed and not force:
        return "skip (ya tiene Unarmed)"
    src = pick_source(folder)
    if src is None:
        return "skip (sin fuente con Stand)"
    return generate_unarmed(src, force, dry_run)


def main():
    ap = argparse.ArgumentParser(
        description="Genera la animación Unarmed (Stand/Dodge/Miss) desde un sheet existente.",
        formatter_class=argparse.RawDescriptionHelpFormatter, epilog=__doc__)
    ap.add_argument("input", type=Path, help="Carpeta de una anim, o raíz con --recursive.")
    ap.add_argument("--recursive", "-r", action="store_true",
                    help="Procesa todas las carpetas {NID}_{Variant} bajo input.")
    ap.add_argument("--force", action="store_true", help="Regenera aunque ya exista.")
    ap.add_argument("--dry-run", action="store_true", help="No escribe; solo lista.")
    args = ap.parse_args()

    if not args.input.exists():
        print(f"ERROR: no existe {args.input}")
        sys.exit(1)

    if args.recursive:
        folders = sorted({jp.parent for jp in args.input.rglob("*.json")})
    else:
        folders = [args.input]

    print(f"Procesando {len(folders)} carpeta(s)...")
    counts = {"ok": 0, "skip": 0, "err": 0}
    for folder in folders:
        status = process_folder(folder, args.force, args.dry_run)
        key = "ok" if status.startswith("ok") else ("err" if status.startswith("err") else "skip")
        counts[key] += 1
        symbol = {"ok": "✓", "skip": "·", "err": "✗"}[key]
        if key != "skip":
            print(f"  {symbol} {folder.name}: {status}")

    print(f"\n=== Resumen ===")
    print(f"  ✓ Unarmed generados: {counts['ok']}")
    print(f"  · saltados:          {counts['skip']}")
    print(f"  ✗ errores:           {counts['err']}")


if __name__ == "__main__":
    main()
