#!/usr/bin/env python3
"""Setea el modelo BASE + versions{FE4,FE5,SAGA} de una clase en
data/general/classes.json.

Convención:
  · El NIVEL SUPERIOR de la clase = versión SAGA (por defecto).
  · versions.FE4 / versions.FE5 = bloques que sobreescriben por-stat.
  · Solo se tocan los 8 stats de combate (HP..RES) de `bases` y `caps`;
    CON/MOV (y el resto) se dejan intactos y se heredan a los bloques.

Uso: importar set_class_version() o editar SPEC abajo y ejecutar.
"""
import json, os

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
PATH = os.path.join(REPO, "data", "general", "classes.json")
S8 = ["HP", "STR", "MAG", "SKL", "SPD", "LCK", "DEF", "RES"]


def d8(vals):
    return {S8[i]: int(vals[i]) for i in range(8)}


def set_class_version(cid, saga_base, saga_cap, fe4_base, fe4_cap,
                      fe5_base, fe5_cap):
    data = json.load(open(PATH))
    cls = next((c for c in data if str(c.get("id")) == cid), None)
    if cls is None:
        raise SystemExit("clase no encontrada: " + cid)
    # Nivel superior = SAGA: sobreescribe solo los 8 stats de combate.
    cls.setdefault("bases", {})
    cls.setdefault("caps", {})
    for i, s in enumerate(S8):
        cls["bases"][s] = int(saga_base[i])
        cls["caps"][s] = int(saga_cap[i])
    # Bloques por modo (bases+caps, 8 stats; CON/MOV se heredan).
    cls["versions"] = {
        "FE4": {"bases": d8(fe4_base), "caps": d8(fe4_cap)},
        "FE5": {"bases": d8(fe5_base), "caps": d8(fe5_cap)},
    }
    json.dump(data, open(PATH, "w"), indent=1, ensure_ascii=False)
    open(PATH, "a").write("\n")
    print("OK", cid, "| SAGA base", saga_base, "| FE4 cap", fe4_cap,
          "| FE5 base", fe5_base)


# ── Clases procesadas (una llamada por clase) ────────────────────────────────
if __name__ == "__main__":
    # LordSeliph (nombre "Lord")  — base | max, 8 stats HP..RES
    set_class_version(
        "LordSeliph",
        saga_base=[30, 5, 0, 5, 5, 0, 5, 0], saga_cap=[80, 20, 20, 20, 20, 30, 20, 20],
        fe4_base=[30, 5, 0, 5, 5, 0, 5, 0],  fe4_cap=[80, 20, 15, 20, 20, 30, 20, 15],
        fe5_base=[18, 4, 0, 2, 3, 0, 2, 0],  fe5_cap=[80, 20, 20, 20, 20, 20, 20, 20],
    )
