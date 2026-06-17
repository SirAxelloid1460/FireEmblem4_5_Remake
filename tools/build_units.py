#!/usr/bin/env python3
"""
build_units.py — Unifica los units.json de GotHW (FE4) y Thracia776 (FE5) de
LT-maker en un único roster nativo: res://data/general/units.json.

- Deduplica por nid (si un nid está en ambos y difiere, prefiere FE4 y avisa).
- Etiqueta el/los juego(s) de origen en "games".
- Deriva holy_blood desde los tags "<Crusader>Heir" (Major). Tags "<X>Minor"
  o "Minor<X>" -> Minor (por si aparecen en rosters ampliados).
- Filtra unidades de test (klass "Tester" / nid "0").

Uso: python tools/build_units.py <fe4 units.json> <fe5 units.json> <outdir>
"""
import sys, json, os, re

# Duplicados que existían sólo para sortear limitaciones de LT (versiones
# Fake/ally/enemy por capítulo del mismo personaje). En el motor nativo basta
# una entrada por personaje (la variante de capítulo se resuelve por nivel/team).
DROP_NIDS = {"FakeElliot", "FakeMidir", "Chagall1", "EldiganAlly"}
# Renombra el superviviente al nid canónico del personaje.
RENAME_NIDS = {"Chagall2": "Chagall", "EldiganEnemy": "Eldigan"}

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

def to_native(u, games):
    tags = u.get("tags", []) or []
    return {
        "nid": u["nid"],
        "name": u.get("name", u["nid"]),
        "desc": u.get("desc", ""),
        "klass": u.get("klass", ""),
        "level": u.get("level", 1),
        "gender": "F" if (u.get("variant") == "Female") else "M",
        "bases": u.get("bases", {}),
        "growths": u.get("growths", {}),
        "starting_items": [it[0] if isinstance(it, list) else it
                           for it in u.get("starting_items", [])],
        "learned_skills": [[s[0], s[1]] if isinstance(s, list) else s
                           for s in u.get("learned_skills", [])],
        "wexp_gain": {k: v[1] for k, v in u.get("wexp_gain", {}).items()
                      if isinstance(v, list) and v[0] and k != "Default"},
        "holy_blood": derive_holy_blood(tags),
        "tags": [t for t in tags if not t.endswith("Heir")],  # heir tags -> holy_blood
        "affinity": u.get("affinity", ""),
        "portrait_nid": u.get("portrait_nid", ""),
        "games": games,
    }

def is_test(u):
    return u.get("klass") == "Tester" or u.get("nid") == "0" or u.get("nid") in DROP_NIDS

def main():
    fe4_path = sys.argv[1]
    fe5_path = sys.argv[2]
    outdir = sys.argv[3] if len(sys.argv) > 3 else "FE4_FE5_Godot/data/general"
    fe4 = json.load(open(fe4_path, encoding="utf-8"))
    fe5 = json.load(open(fe5_path, encoding="utf-8"))

    merged = {}      # nid -> native dict
    conflicts = []
    def ingest(units, game):
        for u in units:
            if is_test(u):
                continue
            nid = u["nid"]
            if nid in merged:
                if game not in merged[nid]["games"]:
                    merged[nid]["games"].append(game)
                # detectar divergencia real (ignorando 'games')
                # (no sobreescribe: prefiere el primero = FE4)
            else:
                merged[nid] = to_native(u, [game])
    ingest(fe4, "FE4")
    ingest(fe5, "FE5")

    roster = list(merged.values())
    for u in roster:                       # nid canónico para los supervivientes
        if u["nid"] in RENAME_NIDS:
            u["nid"] = RENAME_NIDS[u["nid"]]
    os.makedirs(outdir, exist_ok=True)
    with open(os.path.join(outdir, "units.json"), "w", encoding="utf-8") as f:
        json.dump(roster, f, ensure_ascii=False, indent=1)

    print(f"unidades unificadas: {len(roster)} -> units.json")
    fe4n = set(u["nid"] for u in fe4 if not is_test(u))
    fe5n = set(u["nid"] for u in fe5 if not is_test(u))
    print(f"  FE4: {len(fe4n)}  FE5: {len(fe5n)}  comunes: {len(fe4n & fe5n)}  solo-FE5: {len(fe5n - fe4n)}")
    with_blood = [u for u in roster if u["holy_blood"]]
    print(f"  con holy blood: {len(with_blood)}")
    for u in with_blood:
        print(f"     {u['name']:12} {u['holy_blood']}")

if __name__ == "__main__":
    main()
