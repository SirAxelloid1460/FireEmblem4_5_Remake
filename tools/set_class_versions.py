#!/usr/bin/env python3
"""Setea el modelo BASE + versions{FE4,FE5} de las clases en
data/general/classes.json, de forma idempotente y con registro.

Convención:
  · El NIVEL SUPERIOR de la clase = versión SAGA (por defecto).
  · versions.FE4 / versions.FE5 = bloques que sobreescriben por-stat.
  · Solo se tocan los 8 stats de combate (HP..RES) de `bases` y `caps`;
    CON/MOV (y el resto) se dejan intactos y se heredan a los bloques.
  · Clases EXCLUSIVAS de un juego: solo nivel superior, sin `versions`.

Orden de stats: HP STR MAG SKL SPD LCK DEF RES.
"""
import json, os

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
PATH = os.path.join(REPO, "data", "general", "classes.json")
S8 = ["HP", "STR", "MAG", "SKL", "SPD", "LCK", "DEF", "RES"]


def d8(vals):
    return {S8[i]: int(vals[i]) for i in range(8)}


def _find(data, cid):
    c = next((x for x in data if str(x.get("id")) == cid), None)
    if c is None:
        raise SystemExit("clase no encontrada: " + cid)
    return c


def _set8(cls, base, cap):
    cls.setdefault("bases", {})
    cls.setdefault("caps", {})
    for i, s in enumerate(S8):
        cls["bases"][s] = int(base[i])
        cls["caps"][s] = int(cap[i])


# ── Especificación ───────────────────────────────────────────────────────────
# versioned: SAGA (nivel superior) + bloques FE4/FE5.
VERSIONED = [
    {  # Lord
        "ids": ["LordSeliph"],
        "saga": ([30, 5, 0, 5, 5, 0, 5, 0], [80, 20, 20, 20, 20, 30, 20, 20]),
        "fe4":  ([30, 5, 0, 5, 5, 0, 5, 0], [80, 20, 15, 20, 20, 30, 20, 15]),
        "fe5":  ([18, 4, 0, 2, 3, 0, 2, 0], [80, 20, 20, 20, 20, 20, 20, 20]),
    },
    {  # Swordfighter (y Mercenary, mismo nombre "Swordfighter")
        "ids": ["Swordfighter", "Mercenary"],
        "saga": ([30, 7, 0, 10, 10, 0, 5, 6], [80, 22, 20, 25, 25, 30, 20, 15]),
        "fe4":  ([30, 7, 0, 10, 10, 0, 5, 0], [80, 22, 15, 25, 25, 30, 20, 15]),
        "fe5":  ([19, 3, 0, 5, 7, 0, 2, 6],   [80, 20, 20, 20, 20, 30, 20, 6]),
    },
]

# exclusivas de un juego: solo nivel superior (sin versions).
EXCLUSIVE = [
    {  # Princess — exclusiva FE4
        "ids": ["Princess"],
        "base": [26, 5, 7, 5, 8, 0, 5, 7],
        "cap":  [80, 20, 22, 20, 23, 30, 20, 22],
    },
]


def main():
    data = json.load(open(PATH))
    for spec in VERSIONED:
        for cid in spec["ids"]:
            c = _find(data, cid)
            _set8(c, *spec["saga"])
            c["versions"] = {
                "FE4": {"bases": d8(spec["fe4"][0]), "caps": d8(spec["fe4"][1])},
                "FE5": {"bases": d8(spec["fe5"][0]), "caps": d8(spec["fe5"][1])},
            }
            print("versioned", cid)
    for spec in EXCLUSIVE:
        for cid in spec["ids"]:
            c = _find(data, cid)
            _set8(c, spec["base"], spec["cap"])
            c.pop("versions", None)
            print("exclusive", cid)
    json.dump(data, open(PATH, "w"), indent=1, ensure_ascii=False)
    open(PATH, "a").write("\n")


if __name__ == "__main__":
    main()
