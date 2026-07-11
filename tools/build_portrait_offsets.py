#!/usr/bin/env python3
# build_portrait_offsets.py
# =============================================================================
# Genera data/general/portrait_offsets.json a partir de los portraits.json de
# los .ltproj (FE4/FE5). Contiene, por nid de retrato, los offsets de parpadeo
# (blink) y boca (smile) que el motor LT usa para componer expresiones sobre la
# cara principal.
#
# Layout LT (hoja de 144×112, ver app/events/event_portrait.py):
#   main       = (0, 0, 96, 80)
#   halfblink  = (96, 64, 32, 16)   # ojos entrecerrados
#   fullblink  = (96, 80, 32, 16)   # ojos cerrados  → 'CloseEyes'
#   *mouth*    = filas (0/32/64, 80/96) — animación de habla (no usada aquí)
# El frame de parpadeo se pega en `blinking_offset` sobre la cara principal.
#
# Los nids de portraits.json llevan sufijo "Portrait" (SigurdPortrait); el asset
# y los eventos usan el nombre pelado (Sigurd), así que se recorta. Se aplica el
# mismo NID_REMAP que build_events/build_levels.
#
# Uso:
#   python build_portrait_offsets.py \
#       --fe4 "<GotHW.ltproj>/resources/portraits/portraits.json" \
#       --fe5 "<Thracia776.ltproj>/resources/portraits/portraits.json"
# =============================================================================

import argparse
import json
import os

NID_REMAP = {
    "FakeElliot": "Elliot", "FakeMidir": "Midir",
    "Chagall1": "Chagall", "Chagall2": "Chagall",
    "EldiganAlly": "Eldigan", "EldiganEnemy": "Eldigan",
    "Leaf": "Leif",
}

DEFAULT_FE4 = r"D:\FEHW\lt-maker-moded\GotHW.ltproj\resources\portraits\portraits.json"
DEFAULT_FE5 = r"D:\FEHW\lt-maker-moded\Thracia776.ltproj\resources\portraits\portraits.json"

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(HERE)


def _norm(nid):
    if nid.endswith("Portrait"):
        nid = nid[:-len("Portrait")]
    return NID_REMAP.get(nid, nid)


def _load(path, out):
    if not os.path.isfile(path):
        print("  fuente no encontrada: %s (omitida)" % path)
        return
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)
    items = data if isinstance(data, list) else list(data.values())
    for it in items:
        nid = _norm(str(it.get("nid", "")))
        if nid == "":
            continue
        out[nid] = {
            "blink": [int(x) for x in it.get("blinking_offset", [0, 0])],
            "smile": [int(x) for x in it.get("smiling_offset", [0, 0])],
        }


def main():
    ap = argparse.ArgumentParser(description="Genera data/general/portrait_offsets.json")
    ap.add_argument("--fe4", default=DEFAULT_FE4)
    ap.add_argument("--fe5", default=DEFAULT_FE5)
    args = ap.parse_args()
    out = {}
    _load(args.fe4, out)
    _load(args.fe5, out)
    dst_dir = os.path.join(PROJECT_ROOT, "data", "general")
    os.makedirs(dst_dir, exist_ok=True)
    dst = os.path.join(dst_dir, "portrait_offsets.json")
    with open(dst, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=1)
    print("  %d offsets -> %s" % (len(out), os.path.relpath(dst, PROJECT_ROOT)))


if __name__ == "__main__":
    main()
