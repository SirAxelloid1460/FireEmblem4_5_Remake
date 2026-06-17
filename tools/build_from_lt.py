#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
build_from_lt.py — Genera TODA la data nativa del proyecto Godot desde el
game_data AUTORITATIVO de los dos proyectos LT (GotHW=FE4, Thracia776=FE5).

Reemplaza a build_data_from_spreadsheet.py + build_units.py: ahora la fuente de
verdad son los componentes reales de LT, no el spreadsheet.

Lee de cada <proj>/game_data/:
  classes/*.json  items/*.json  skills/*.json  units/*.json   (1 obj por archivo)
  weapon_ranks.json terrain.json mcost.json ai.json equations.json
  constants.json stats.json weapons.json                       (tablas globales)

Emite en FE4_FE5_Godot/data/:
  general/classes.json  general/weapons.json  general/items.json
  general/skills.json   general/units.json
  fe4/tables/*.json     fe5/tables/*.json      (tablas verbatim por juego)

Uso:
  python tools/build_from_lt.py [fe4_ltproj_dir] [fe5_ltproj_dir] [out_data_dir]
Defaults a las rutas D:\\FEHW\\lt-maker-moded\\*.ltproj y FE4_FE5_Godot/data.
"""
import sys, os, json, glob, re

FE4_DEFAULT = r"D:\FEHW\lt-maker-moded\GotHW.ltproj"
FE5_DEFAULT = r"D:\FEHW\lt-maker-moded\Thracia776.ltproj"
OUT_DEFAULT = os.path.join(os.path.dirname(__file__), "..", "data")

STAT_KEYS = ["HP","STR","MAG","SKL","SPD","LCK","DEF","RES","CON","MOV"]
TABLES = ["weapon_ranks","terrain","mcost","ai","equations","constants","stats","weapons"]

# Duplicados que sólo existían para sortear limitaciones de LT (versiones
# Fake/ally/enemy por capítulo). En el motor nativo basta una entrada.
DROP_UNIT_NIDS = {"FakeElliot", "FakeMidir", "Chagall1", "EldiganAlly"}
RENAME_UNIT_NIDS = {"Chagall2": "Chagall", "EldiganEnemy": "Eldigan"}


def clean(s):
    """Quita el carácter de reemplazo Unicode si quedara alguno."""
    return s.replace("�", "") if isinstance(s, str) else s


def load_one(path):
    """Cada archivo LT de clase/item/skill/unit es un array con UN objeto."""
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    if isinstance(data, list):
        return data[0] if data else None
    return data


def glob_objs(proj, sub):
    out = {}
    for p in sorted(glob.glob(os.path.join(proj, "game_data", sub, "*.json"))):
        o = load_one(p)
        if o and "nid" in o:
            out[o["nid"]] = o
    return out


def comp_dict(obj):
    """components LT = lista de [name, value] -> dict {name: value}."""
    d = {}
    for c in obj.get("components", []) or []:
        if isinstance(c, list) and c:
            d[c[0]] = c[1] if len(c) > 1 else None
    return d


# ── CLASES ────────────────────────────────────────────────────────────────────
def conv_class(o):
    wexp = {}
    for wt, v in (o.get("wexp_gain", {}) or {}).items():
        if wt == "Default":
            continue
        if isinstance(v, list) and len(v) == 2 and v[0] and int(v[1]) > 0:
            wexp[wt] = int(v[1])
    return {
        "id": o["nid"],
        "name": clean(o.get("name", o["nid"])),
        "desc": clean(o.get("desc", "")),
        "tier": int(o.get("tier", 1)),
        "movement_group": o.get("movement_group", ""),
        "promotes_from": o.get("promotes_from") or "",
        "turns_into": o.get("turns_into", []) or [],
        "tags": o.get("tags", []) or [],
        "max_level": int(o.get("max_level", 19)),
        "bases": {k: int(o.get("bases", {}).get(k, 0)) for k in STAT_KEYS},
        "growths": {k: int(o.get("growths", {}).get(k, 0)) for k in STAT_KEYS},
        "promotion": {k: int(o.get("promotion", {}).get(k, 0)) for k in STAT_KEYS},
        "caps": {k: int(o.get("max_stats", {}).get(k, 0)) for k in STAT_KEYS},
        "wexp_gain": wexp,
        "learned_skills": [[int(ls[0]), ls[1]] for ls in o.get("learned_skills", []) or []
                           if isinstance(ls, list) and len(ls) == 2],
        "map_sprite_nid": o.get("map_sprite_nid", ""),
        "combat_anim_nid": o.get("combat_anim_nid") or "",
    }


# ── ITEMS (armas/báculos vs consumibles) ────────────────────────────────────────
def conv_weapon(o, c):
    rng_eq = c.get("max_equation_range", "")
    rng_max = int(c.get("max_range", c.get("min_range", 1))) if not rng_eq else 0
    eff_tags = c.get("effective_tag", []) or []
    return {
        "nid": o["nid"],
        "name": clean(o.get("name", o["nid"])),
        "desc": clean(o.get("desc", "")),
        "weapon_type": c.get("weapon_type", ""),
        "might": int(c.get("damage", 0)),
        "hit": int(c.get("hit", 0)),
        "weight": int(c.get("weight", 0)),
        "crit": int(c.get("crit", 0)),
        "rng_min": int(c.get("min_range", 1)),
        "rng_max": rng_max,
        "rng_equation": rng_eq if isinstance(rng_eq, str) else "",
        "rank": c.get("weapon_rank", ""),
        "uses": int(c.get("uses", 0)),
        "worth": int(c.get("value", -1)),
        "magic": "magic" in c,
        "brave": "brave" in c,
        "reaver": "reaver" in c,
        "is_staff": c.get("weapon_type", "") == "Staff" or ("spell" in c and "weapon" not in c),
        "heal": int(c.get("heal", c.get("magic_heal", 0)) or 0),
        "effective_tags": eff_tags,
        "effective_multiplier": int(c.get("effective_multiplier", 1) or 1),
        "effective_bonus": int(c.get("effective", 0) or 0),
        "prf_tags": c.get("prf_tags", []) or [],
        "prf_units": c.get("prf_unit", []) or [],
        "status_on_equip": c.get("status_on_equip", "") or "",
        "status_on_hit": c.get("status_on_hit", "") or "",
        "personal": bool(c.get("prf_tags") or c.get("prf_unit")),
        "components": o.get("components", []) or [],  # crudo LT (báculos/efectos)
    }


def conv_consumable(o, c):
    psc = {}
    for pair in c.get("permanent_stat_change", []) or []:
        if isinstance(pair, list) and len(pair) == 2:
            psc[pair[0]] = int(pair[1])
    return {
        "nid": o["nid"],
        "name": clean(o.get("name", o["nid"])),
        "desc": clean(o.get("desc", "")),
        "category": o.get("icon_nid", ""),
        "worth": int(c.get("value", -1)),
        "uses": int(c.get("uses", -1)),
        "heal": int(c.get("heal", c.get("magic_heal", 0)) or 0),
        "permanent_stat_change": psc,
        "status_on_hold": c.get("status_on_hold", "") or "",
        "status_on_hit": c.get("status_on_hit", "") or "",
        "promote": "promote" in c,
        "restore": ("restore" in c) or ("restore_specific" in c),
        "restore_specific": c.get("restore_specific", "") or "",
        "components": o.get("components", []) or [],  # crudo LT (efectos especiales)
    }


def is_weapon_item(c):
    # Cualquier item con weapon_type (armas de combate, magia y báculos) o con
    # componente weapon/spell de ataque cuenta como "arma" (consume wexp).
    return ("weapon_type" in c and c.get("weapon_type")) or "weapon" in c \
        or (c.get("weapon_type", "") == "Staff")


# ── SKILLS ──────────────────────────────────────────────────────────────────────
def conv_skill(o):
    return {
        "nid": o["nid"],
        "name": clean(o.get("name", o["nid"])),
        "desc": clean(o.get("desc", "")),
        "icon_nid": o.get("icon_nid", ""),
        "components": o.get("components", []) or [],
    }


# ── UNIDADES ─────────────────────────────────────────────────────────────────────
def derive_holy_blood(tags):
    hb = {}
    for t in tags:
        if t.endswith("Heir"):
            hb[t[:-4]] = "Major"
        else:
            m = re.match(r"Minor(.+)$", t) or re.match(r"(.+)Minor$", t)
            if m:
                hb[m.group(1)] = "Minor"
    return hb


def conv_unit(o, games):
    tags = o.get("tags", []) or []
    wexp = {}
    for wt, v in (o.get("wexp_gain", {}) or {}).items():
        if wt == "Default":
            continue
        if isinstance(v, list) and len(v) == 2 and int(v[1]) > 0:
            wexp[wt] = int(v[1])
    return {
        "nid": o["nid"],
        "name": clean(o.get("name", o["nid"])),
        "desc": clean(o.get("desc", "")),
        "klass": o.get("klass", ""),
        "level": int(o.get("level", 1)),
        "gender": "F" if (o.get("variant") == "Female") else "M",
        "bases": {k: int(o.get("bases", {}).get(k, 0)) for k in STAT_KEYS},
        "growths": {k: int(o.get("growths", {}).get(k, 0)) for k in STAT_KEYS},
        "starting_items": [it[0] if isinstance(it, list) else it
                           for it in o.get("starting_items", []) or []],
        "learned_skills": [[int(ls[0]), ls[1]] if isinstance(ls, list) else ls
                           for ls in o.get("learned_skills", []) or []],
        "wexp_gain": wexp,
        "holy_blood": derive_holy_blood(tags),
        "tags": [t for t in tags if not t.endswith("Heir")],
        "affinity": o.get("affinity", "") or "",
        "portrait_nid": o.get("portrait_nid", "") or "",
        "games": list(games),
    }


def is_test_unit(o):
    return o.get("klass") == "Tester" or o.get("nid") == "0" or o.get("nid") in DROP_UNIT_NIDS


def merge_by_nid(fe4, fe5, conv):
    """Unifica dicts {nid:obj} de ambos proyectos; prefiere FE4 en conflicto."""
    out = {}
    order = []
    for nid, o in fe4.items():
        out[nid] = conv(o); order.append(nid)
    for nid, o in fe5.items():
        if nid not in out:
            out[nid] = conv(o); order.append(nid)
    return [out[n] for n in order]


def dump(path, obj):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(obj, f, ensure_ascii=False, indent=1)


# Convención de equipos del proyecto (igual que build_levels.TEAM_REMAP):
# LT player/enemy/enemy2/other -> player/enemy/other/ally.
TABLE_TEAM_REMAP = {"other": "ally", "enemy2": "other"}


def _remap_ai_teams(obj):
    """Remapea los target_spec ['Team', <equipo>] de ai.json a la convención del
    proyecto. Recursivo; sólo toca target_spec[1] cuando target_spec[0]=='Team'."""
    if isinstance(obj, dict):
        ts = obj.get("target_spec")
        if isinstance(ts, list) and len(ts) >= 2 and ts[0] == "Team" and ts[1] in TABLE_TEAM_REMAP:
            ts[1] = TABLE_TEAM_REMAP[ts[1]]
        for v in obj.values():
            _remap_ai_teams(v)
    elif isinstance(obj, list):
        for v in obj:
            _remap_ai_teams(v)
    return obj


def copy_tables(proj, out_game_dir):
    n = 0
    for t in TABLES:
        src = os.path.join(proj, "game_data", t + ".json")
        if os.path.exists(src):
            with open(src, encoding="utf-8") as f:
                data = json.load(f)
            if t == "ai":
                _remap_ai_teams(data)
            dump(os.path.join(out_game_dir, "tables", t + ".json"), data)
            n += 1
    return n


def main():
    fe4 = sys.argv[1] if len(sys.argv) > 1 else FE4_DEFAULT
    fe5 = sys.argv[2] if len(sys.argv) > 2 else FE5_DEFAULT
    out = os.path.normpath(sys.argv[3] if len(sys.argv) > 3 else OUT_DEFAULT)
    gen = os.path.join(out, "general")

    # CLASES
    classes = merge_by_nid(glob_objs(fe4, "classes"), glob_objs(fe5, "classes"), conv_class)
    dump(os.path.join(gen, "classes.json"), classes)

    # ITEMS -> armas + consumibles
    items4, items5 = glob_objs(fe4, "items"), glob_objs(fe5, "items")
    all_items = {}
    for d in (items4, items5):
        for nid, o in d.items():
            all_items.setdefault(nid, o)  # prefiere FE4
    weapons, consumables = [], []
    for nid, o in all_items.items():
        c = comp_dict(o)
        if is_weapon_item(c):
            weapons.append(conv_weapon(o, c))
        else:
            consumables.append(conv_consumable(o, c))
    dump(os.path.join(gen, "weapons.json"), weapons)
    dump(os.path.join(gen, "items.json"), consumables)

    # SKILLS
    skills = merge_by_nid(glob_objs(fe4, "skills"), glob_objs(fe5, "skills"), conv_skill)
    dump(os.path.join(gen, "skills.json"), skills)

    # UNIDADES (con etiqueta de juego + DROP/RENAME de duplicados workaround-LT)
    u4 = {n: o for n, o in glob_objs(fe4, "units").items() if not is_test_unit(o)}
    u5 = {n: o for n, o in glob_objs(fe5, "units").items() if not is_test_unit(o)}
    roster = {}
    order = []
    for nid, o in u4.items():
        roster[nid] = conv_unit(o, ["FE4"]); order.append(nid)
    for nid, o in u5.items():
        if nid in roster:
            if "FE5" not in roster[nid]["games"]:
                roster[nid]["games"].append("FE5")
        else:
            roster[nid] = conv_unit(o, ["FE5"]); order.append(nid)
    units = [roster[n] for n in order]
    for u in units:
        if u["nid"] in RENAME_UNIT_NIDS:
            u["nid"] = RENAME_UNIT_NIDS[u["nid"]]
    dump(os.path.join(gen, "units.json"), units)

    # TABLAS GLOBALES verbatim por juego
    t4 = copy_tables(fe4, os.path.join(out, "fe4"))
    t5 = copy_tables(fe5, os.path.join(out, "fe5"))

    # Resumen
    print("== build_from_lt ==")
    print(f"classes : {len(classes)}")
    print(f"weapons : {len(weapons)}  (incl. báculos/magia)")
    print(f"items   : {len(consumables)}  (consumibles/anillos/manuales)")
    print(f"skills  : {len(skills)}")
    print(f"units   : {len(units)}")
    nb = [u for u in units if u['holy_blood']]
    print(f"  con holy blood: {len(nb)}")
    for u in nb:
        print(f"     {u['name']:12} {u['holy_blood']}")
    print(f"tablas verbatim: fe4={t4} fe5={t5}")


if __name__ == "__main__":
    main()
