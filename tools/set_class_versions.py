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


def _block(spec_tuple):
    """(base, cap|None) -> bloque de versión; sin caps si cap es None (hereda)."""
    base, cap = spec_tuple
    blk = {"bases": d8(base)}
    if cap is not None:
        blk["caps"] = d8(cap)
    return blk


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
    {  # Citizen (= "Civilian")  — tier 0
        "ids": ["Citizen"],
        "saga": ([20, 0, 0, 0, 10, 0, 2, 0], [80, 20, 20, 20, 25, 30, 20, 15]),
        "fe4":  ([20, 0, 0, 0, 10, 0, 2, 0], [80, 15, 15, 15, 25, 30, 17, 15]),
        "fe5":  ([10, 0, 0, 0, 0, 0, 0, 0],  [80, 20, 20, 20, 20, 20, 20, 0]),
    },
    {  # Dragon Rider  — tier 0
        "ids": ["DragonRider"],
        "saga": ([35, 9, 0, 5, 5, 0, 8, 0], [80, 25, 20, 22, 21, 30, 26, 15]),
        "fe4":  ([35, 9, 0, 5, 5, 0, 8, 0], [80, 25, 15, 22, 21, 30, 26, 15]),
        "fe5":  ([16, 5, 0, 3, 4, 0, 7, 0], [80, 20, 20, 20, 20, 20, 20, 0]),
    },
    {  # Pegasus Rider  — tier 0 (max invertido de Dragon Rider por pares)
        "ids": ["PegasusRider"],
        "saga": ([30, 6, 3, 5, 10, 0, 3, 5], [80, 20, 25, 21, 22, 30, 20, 26]),
        "fe4":  ([30, 6, 0, 5, 10, 0, 3, 5], [80, 15, 25, 21, 22, 30, 15, 26]),
        "fe5":  ([16, 2, 3, 3, 6, 0, 2, 0],  [80, 20, 20, 20, 20, 20, 20, 0]),
    },
    {  # Caballerías iguales: Cavalier, Free Knight, Axe Knight
        "ids": ["Cavalier", "CavalierS", "CavalierA"],
        "saga": ([30, 7, 0, 6, 6, 0, 6, 0], [80, 22, 20, 21, 21, 30, 21, 15]),
        "fe4":  ([30, 7, 0, 6, 6, 0, 6, 0], [80, 22, 15, 21, 21, 30, 21, 15]),
        "fe5":  ([20, 3, 0, 3, 4, 0, 3, 0], [80, 20, 20, 20, 20, 20, 20, 0]),
    },
    {  # Lance Knight  (FE5 max LCK 30)
        "ids": ["CavalierL"],
        "saga": ([30, 7, 0, 6, 6, 0, 6, 0], [80, 22, 20, 21, 21, 30, 21, 15]),
        "fe4":  ([30, 7, 0, 6, 6, 0, 6, 0], [80, 22, 15, 21, 21, 30, 21, 15]),
        "fe5":  ([20, 3, 0, 3, 4, 0, 3, 0], [80, 20, 20, 20, 20, 30, 20, 0]),
    },
    {  # Archer Knight  (FE5 base SPD 5)
        "ids": ["CavalierB"],
        "saga": ([30, 7, 0, 6, 6, 0, 6, 0], [80, 22, 20, 21, 21, 30, 21, 15]),
        "fe4":  ([30, 7, 0, 6, 6, 0, 6, 0], [80, 22, 15, 21, 21, 30, 21, 15]),
        "fe5":  ([20, 3, 0, 3, 5, 0, 3, 0], [80, 20, 20, 20, 20, 20, 20, 0]),
    },
    {  # Troubadour
        "ids": ["Troubadour"],
        "saga": ([26, 3, 3, 6, 6, 0, 3, 3], [80, 20, 20, 21, 30, 30, 20, 18]),
        "fe4":  ([26, 3, 3, 6, 6, 0, 3, 3], [80, 18, 18, 21, 21, 30, 18, 18]),
        "fe5":  ([16, 2, 2, 2, 3, 0, 2, 0], [80, 20, 20, 20, 30, 20, 20, 0]),
    },
    {  # Dragon Knight  (Wyvern Rider)
        "ids": ["DragonKnight"],
        "saga": ([40, 10, 1, 7, 6, 0, 11, 0], [80, 25, 20, 22, 21, 30, 26, 15]),
        "fe4":  ([40, 10, 0, 7, 6, 0, 11, 0], [80, 25, 15, 22, 21, 30, 26, 15]),
        "fe5":  ([24, 7, 1, 6, 6, 0, 9, 0],   [80, 20, 20, 20, 20, 20, 20, 0]),
    },
    {  # Pegasus Knight
        "ids": ["PegasusKnight"],
        "saga": ([35, 7, 5, 7, 12, 0, 5, 7], [80, 22, 20, 22, 27, 30, 20, 22]),
        "fe4":  ([35, 7, 0, 7, 12, 0, 5, 7], [80, 22, 15, 22, 27, 30, 20, 22]),
        "fe5":  ([17, 4, 5, 5, 8, 0, 3, 0],  [80, 20, 20, 20, 20, 20, 20, 0]),
    },
    {  # Bard
        "ids": ["Bard"],
        "saga": ([30, 0, 7, 7, 10, 0, 3, 7], [80, 20, 22, 22, 25, 30, 20, 22]),
        "fe4":  ([30, 0, 7, 7, 10, 0, 3, 7], [80, 15, 22, 22, 25, 30, 18, 22]),
        "fe5":  ([16, 0, 1, 1, 5, 0, 0, 0],  [80, 20, 20, 20, 20, 20, 20, 0]),
    },
    {  # Light Priestess  (FE5 "Sister")
        "ids": ["LightPriestess"],
        "saga": ([30, 0, 8, 7, 7, 0, 3, 10], [80, 20, 23, 22, 22, 30, 20, 25]),
        "fe4":  ([30, 0, 8, 7, 7, 0, 3, 10], [80, 15, 23, 22, 22, 30, 18, 25]),
        "fe5":  ([14, 0, 1, 2, 5, 0, 0, 0],  [80, 20, 20, 20, 20, 20, 20, 0]),
    },
    {  # Priest / Priestess
        "ids": ["Priest", "Priestess"],
        "saga": ([26, 0, 7, 6, 6, 0, 1, 7], [80, 20, 22, 21, 21, 30, 22, 22]),
        "fe4":  ([26, 0, 7, 6, 6, 0, 1, 7], [80, 15, 22, 21, 21, 30, 22, 22]),
        "fe5":  ([16, 0, 3, 2, 1, 0, 0, 0], [80, 20, 20, 20, 20, 20, 20, 0]),
    },
    {  # Soldier  (= Axe/Sword/Lance/Bow Soldier; caps de FE8, HP a 80)
        "ids": ["Soldier"],
        "saga": ([30, 6, 0, 5, 5, 0, 7, 0], [80, 20, 20, 20, 20, 20, 20, 20]),
        "fe4":  ([30, 6, 0, 5, 5, 0, 7, 0], [80, 20, 20, 20, 20, 20, 20, 20]),
        "fe5":  ([20, 3, 0, 0, 0, 0, 1, 0], [80, 20, 20, 20, 20, 20, 20, 20]),
    },
    {  # Armour  (= FE4 Sword/Lance/Bow/Axe Armour, unificados)
        "ids": ["Armour"],
        "saga": ([40, 9, 0, 5, 3, 0, 10, 0], [80, 24, 20, 20, 20, 30, 25, 15]),
        "fe4":  ([40, 9, 0, 5, 3, 0, 10, 0], [80, 24, 15, 20, 18, 30, 25, 15]),
        "fe5":  ([20, 4, 0, 0, 0, 0, 8, 0],  [80, 20, 20, 20, 20, 20, 20, 0]),
    },
    {  # Mage  (= FE4 Fire/Thunder/Wind Mage + Mage, unificados)
        "ids": ["Mage"],
        "saga": ([26, 0, 8, 7, 7, 0, 3, 4], [80, 20, 23, 22, 22, 30, 20, 20]),
        "fe4":  ([26, 0, 8, 7, 7, 0, 3, 4], [80, 15, 23, 22, 22, 30, 16, 20]),
        "fe5":  ([17, 0, 2, 2, 4, 0, 0, 0], [80, 20, 20, 20, 20, 20, 20, 0]),
    },
    {  # Fighter  (= FE4 "Axe Fighter")
        "ids": ["Fighter"],
        "saga": ([35, 8, 0, 4, 10, 0, 8, 0], [80, 23, 20, 20, 25, 30, 23, 15]),
        "fe4":  ([35, 8, 0, 3, 10, 0, 8, 0], [80, 23, 15, 18, 25, 30, 23, 15]),
        "fe5":  ([20, 4, 0, 4, 5, 0, 2, 0],  [80, 20, 20, 20, 20, 20, 20, 0]),
    },
    {  # Archer  (= FE4 "Bow Fighter + Hunter")
        "ids": ["Archer"],
        "saga": ([33, 7, 0, 5, 9, 0, 5, 0], [80, 21, 20, 20, 24, 30, 20, 15]),
        "fe4":  ([33, 7, 0, 5, 9, 0, 5, 0], [80, 21, 15, 20, 24, 30, 20, 15]),
        "fe5":  ([19, 3, 0, 2, 3, 0, 2, 0], [80, 20, 20, 20, 20, 20, 20, 10]),
    },
    {  # Pirate
        "ids": ["Pirate"],
        "saga": ([35, 5, 0, 0, 7, 0, 5, 0], [80, 20, 20, 20, 22, 30, 20, 15]),
        "fe4":  ([35, 5, 0, 0, 7, 0, 5, 0], [80, 20, 20, 20, 20, 20, 20, 15]),
        "fe5":  ([24, 5, 0, 0, 0, 0, 3, 0], [80, 20, 20, 20, 20, 20, 20, 0]),
    },
    {  # Thief  (FE5 sin caps → hereda SAGA)
        "ids": ["Thief"],
        "saga": ([26, 3, 0, 3, 7, 7, 1, 0], [80, 18, 15, 18, 22, 30, 16, 15]),
        "fe4":  ([26, 3, 0, 3, 0, 7, 1, 0], [80, 18, 15, 18, 22, 30, 16, 15]),
        "fe5":  ([15, 1, 0, 1, 7, 0, 0, 0], None),
    },
    {  # Prince (Leif)
        "ids": ["LordLeaf"],
        "saga": ([30, 8, 3, 7, 6, 7, 3, 6], [80, 23, 20, 22, 21, 30, 22, 18]),
        "fe4":  ([30, 8, 3, 7, 6, 7, 3, 6], [80, 23, 18, 22, 21, 30, 22, 18]),
        "fe5":  ([18, 5, 1, 3, 4, 0, 3, 0], [80, 20, 20, 20, 20, 20, 20, 0]),
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
                "FE4": _block(spec["fe4"]),
                "FE5": _block(spec["fe5"]),
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
