#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
build_levels.py — Empaqueta los capítulos LT crudos dentro del proyecto Godot.

LevelLoader.gd está diseñado para leer el formato de nivel LT verbatim (units con
starting_position, generics con klass/faction/starting_items, regions, unit_groups).
Por eso copiamos cada nivel TAL CUAL (envuelto en Array[1], como espera
LevelLoader.load_chapter) — NO normalizamos (la normalización perdía genéricos).

Lee <proj>/game_data/levels.json (array de niveles) de cada .ltproj.
Emite res://data/<game>/levels/<nid>.json = [nivel]  +  _index.json.

Uso: python tools/build_levels.py [fe4_ltproj] [fe5_ltproj] [out_data_dir]
"""
import sys, os, json, glob

FE4_DEFAULT = r"D:\FEHW\lt-maker-moded\GotHW.ltproj"
FE5_DEFAULT = r"D:\FEHW\lt-maker-moded\Thracia776.ltproj"
OUT_DEFAULT = os.path.join(os.path.dirname(__file__), "..", "data")

# Las placements LT referencian los duplicados workaround (Fake/ally/enemy/N);
# el roster nativo los colapsó en un nid canónico (ver build_from_lt). Remapeamos
# las referencias en los niveles para que casen con units.json.
NID_REMAP = {
    "FakeElliot": "Elliot", "FakeMidir": "Midir",
    "Chagall1": "Chagall", "Chagall2": "Chagall",
    "EldiganAlly": "Eldigan", "EldiganEnemy": "Eldigan",
    # Inconsistencia de nid en el proyecto Thracia: el nivel usa "Leaf" pero la
    # unidad es "Leif" (misma persona, romanización clásica).
    "Leaf": "Leif",
}

# Convención de equipos del proyecto: player / enemy / other / ally.
# LT usa player/enemy/enemy2/other → remapeamos para que los nombres casen con
# las paletas (ally=verde NPC, other=neutral dorado, p.ej. MackilyNeutral cap 2).
TEAM_REMAP = {
    "other": "ally",     # LT 'other' = aliados NPC verdes
    "enemy2": "other",   # LT 'enemy2' = neutrales dorados
}


def remap_level(lv):
    for u in lv.get("units", []):
        if u.get("nid") in NID_REMAP:
            u["nid"] = NID_REMAP[u["nid"]]
        if u.get("starting_traveler") in NID_REMAP:
            u["starting_traveler"] = NID_REMAP[u["starting_traveler"]]
        if u.get("team") in TEAM_REMAP:
            u["team"] = TEAM_REMAP[u["team"]]
    for g in lv.get("unit_groups", []):
        gu = g.get("units", [])
        g["units"] = [NID_REMAP.get(n, n) for n in gu]
        pos = g.get("positions", {})
        if isinstance(pos, dict):
            g["positions"] = {NID_REMAP.get(k, k): v for k, v in pos.items()}
    return lv


def build_game(proj, out_game_dir):
    src = os.path.join(proj, "game_data", "levels.json")
    levels = json.load(open(src, encoding="utf-8"))
    out_dir = os.path.join(out_game_dir, "levels")
    os.makedirs(out_dir, exist_ok=True)
    # Limpiar niveles previos (incl. los normalizados obsoletos) antes de escribir.
    for old in glob.glob(os.path.join(out_dir, "*.json")):
        os.remove(old)
    index = []
    for lv in levels:
        nid = str(lv.get("nid", ""))
        if nid == "":
            continue
        lv = remap_level(lv)
        with open(os.path.join(out_dir, nid + ".json"), "w", encoding="utf-8") as f:
            json.dump([lv], f, ensure_ascii=False, indent=1)   # Array[1] LT crudo
        index.append({
            "nid": nid,
            "name": lv.get("name", nid),
            "tilemap": lv.get("tilemap", ""),
            "units": len(lv.get("units", [])),
            "regions": len(lv.get("regions", [])),
        })
    with open(os.path.join(out_dir, "_index.json"), "w", encoding="utf-8") as f:
        json.dump(index, f, ensure_ascii=False, indent=1)
    return index


def main():
    fe4 = sys.argv[1] if len(sys.argv) > 1 else FE4_DEFAULT
    fe5 = sys.argv[2] if len(sys.argv) > 2 else FE5_DEFAULT
    out = os.path.normpath(sys.argv[3] if len(sys.argv) > 3 else OUT_DEFAULT)
    for game, proj in (("fe4", fe4), ("fe5", fe5)):
        idx = build_game(proj, os.path.join(out, game))
        print(f"== {game}: {len(idx)} capitulos (LT crudo) ==")
        for e in idx:
            print(f"   {e['nid']:3} {e['name'][:30]:30} tm={e['tilemap']:10} units={e['units']} regions={e['regions']}")


if __name__ == "__main__":
    main()
