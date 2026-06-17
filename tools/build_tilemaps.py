#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
build_tilemaps.py — Empaqueta los tilemaps de LT dentro del proyecto Godot en
forma SLIM (solo el terreno de gameplay), compatible con TilemapLoader.gd.

Lee el `tilemap.json` (catálogo con terrain_grid inline) extraído de cada
resources/tilemaps de LT y, por cada prefab, fusiona las terrain_grid de todas
las capas visibles (la última gana) en una única capa "base".

Salida (res://data/<game>/tilemaps/):
  tilemap.json                      índice [{nid,size}]
  tilemap_data/<nid>.json           [ {nid,size,autotile_fps,layers:[base]} ]

Descarta sprite_grid/tilesets (render por color de terrain.json; los PNG de
tileset no son necesarios para la lógica). NO incluye WorldMap/Chronology/DEBUG
salvo que aparezcan referenciados — se copian todos igualmente por si acaso.

Uso: python tools/build_tilemaps.py [fe4_tilemap.json] [fe5_tilemap.json] [out_data_dir]
"""
import sys, os, json, glob

# Raíz extraída de cada resources/tilemaps de LT (contiene tilemap_data/).
FE4_DEFAULT = r"..\_lt_tilemaps\fe4"
FE5_DEFAULT = r"..\_lt_tilemaps\fe5"
OUT_DEFAULT = os.path.join(os.path.dirname(__file__), "..", "data")

SKIP = {"DEBUG", "MTC--WIP"}  # mapas de prueba/WIP sin uso en campaña


def slim_prefab(pf):
    merged = {}
    for layer in pf.get("layers", []):
        if not layer.get("visible", True):
            continue
        for k, v in (layer.get("terrain_grid", {}) or {}).items():
            merged[k] = str(v)            # última capa visible gana
    return {
        "nid": pf["nid"],
        "size": pf.get("size", [0, 0]),
        "autotile_fps": pf.get("autotile_fps", 30),
        "layers": [{"nid": "base", "visible": True, "terrain_grid": merged}],
    }


def build_game(lt_root, out_game_dir):
    # Fuente completa: cada tilemap_data/<nid>.json (Array[1] con el prefab).
    # El catálogo tilemap.json suele estar desincronizado (le faltan mapas).
    src_dir = os.path.join(lt_root, "tilemap_data")
    tm_dir = os.path.join(out_game_dir, "tilemaps", "tilemap_data")
    os.makedirs(tm_dir, exist_ok=True)
    index = []
    for path in sorted(glob.glob(os.path.join(src_dir, "*.json"))):
        arr = json.load(open(path, encoding="utf-8"))
        if not isinstance(arr, list) or not arr:
            continue
        pf = arr[0]
        nid = pf.get("nid") or os.path.splitext(os.path.basename(path))[0]
        if nid in SKIP:
            continue
        slim = slim_prefab(pf)
        with open(os.path.join(tm_dir, nid + ".json"), "w", encoding="utf-8") as f:
            json.dump([slim], f, ensure_ascii=False, indent=1)
        index.append({"nid": nid, "size": slim["size"],
                      "cells": len(slim["layers"][0]["terrain_grid"])})
    with open(os.path.join(out_game_dir, "tilemaps", "tilemap.json"), "w", encoding="utf-8") as f:
        json.dump(index, f, ensure_ascii=False, indent=1)
    return index


def main():
    fe4 = sys.argv[1] if len(sys.argv) > 1 else FE4_DEFAULT
    fe5 = sys.argv[2] if len(sys.argv) > 2 else FE5_DEFAULT
    out = os.path.normpath(sys.argv[3] if len(sys.argv) > 3 else OUT_DEFAULT)
    for game, cat in (("fe4", fe4), ("fe5", fe5)):
        idx = build_game(cat, os.path.join(out, game))
        print(f"== {game} tilemaps: {len(idx)} ==")
        for e in idx:
            print(f"   {e['nid']:14} {e['size'][0]}x{e['size'][1]}  cells={e['cells']}")


if __name__ == "__main__":
    main()
