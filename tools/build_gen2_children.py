#!/usr/bin/env python3
"""Convierte data/general/gen2_inheritance_source.json (cosecha cruda de
fireemblemwod) en data/general/gen2_children.json con el modelo
BASE + MODIFICADORES-POR-PADRE que consume SubstituteSystem.

Para cada hijo canónico de la gen 2:
  base_stats   = mínimo de la fila Nv.1 entre todos los padres (piso materno)
  base_growths = mínimo del growth% entre todos los padres
  max_stats    = tope de clase (tal cual la fuente)
  father_mods[<padre>] = {
      base:   { stat: father.lv1 - base_stats[stat] },
      growth: { stat: father.growth - base_growths[stat] },
      skills: [...],  blood: "<nota de sangre del padre>"
  }
El stat final de un hijo con padre P se resuelve como:
      final_base[s]   = clamp(base_stats[s]   + father_mods[P].base[s],   0, max_stats[s])
      final_growth[s] =        base_growths[s] + father_mods[P].growth[s]
El usuario puede ajustar cualquiera de estos números; la fuente cruda queda
en gen2_inheritance_source.json para trazabilidad.
"""
import json, os

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
SRC = os.path.join(REPO, "data", "general", "gen2_inheritance_source.json")
OUT = os.path.join(REPO, "data", "general", "gen2_children.json")

STATS = ["HP", "STR", "MAG", "SKL", "SPD", "LCK", "DEF", "RES"]

# Nombre de padre en la fuente -> nid de la unidad en el juego (units.json).
FATHER_MAP = {
    "Naoise": "Noish", "Azelle": "Azel", "Chulainn": "Holyn",
    "Beowolf": "Beowulf", "Claud": "Claude",
    # idénticos: Alec, Arden, Lex, Finn, Midir, Dew, Jamke, Lewyn
}

# Nombre de clase de la fuente -> id de classes.json (convención del proyecto).
CLASS_MAP = {
    "Arch Knight": "CavalierB",       # = "Archer Knight" (tier 1 mounted bow); Lester
    "Sword Fighter": "Swordfighter",
    "Free Knight": "CavalierS",       # tier 1 sword cavalier; Delmud (NO es Ranger/tier2)
    "Bow Fighter": "Archer",          # id "Archer" (name "Bow Fighter"); Faval
    "Priest": "Priest",
    "Troubadour": "Troubadour",
    "Dancer": "Dancer",
    "Sage": "Sage",
    "Pegasus Knight": "PegasusKnight",
    "Thief": "Thief",
    "Mage": "Mage",
}

# Nombre de cruzado en la fuente -> clave de holy_blood del motor.
BLOOD_MAP = {
    "baldo": "Baldr", "baldr": "Baldr",
    "odo": "Od", "od": "Od",
    "ulir": "Ulir",
    "neir": "Neir",
    "dain": "Dainn", "dainn": "Dainn",
    "noba": "Njörun", "njorun": "Njörun", "njörun": "Njörun",
    "hezul": "Hezul",
    "fala": "Fjalar", "fjalar": "Fjalar",
    "tordo": "Thrud", "thrud": "Thrud",
    "sety": "Sety", "holsety": "Sety",
    "bragi": "Bragi", "blaggi": "Bragi",
    "heim": "Heim",
    "naga": "Naga", "narga": "Naga",
    "loptous": "Loptos", "loptous ": "Loptos", "loptos": "Loptos",
}
MAJOR_WORDS = ("major", "mucha", "much", "grande")
MINOR_WORDS = ("minor", "poca", "pequeña", "pequena", "small", "little")


def parse_blood(text):
    """'Ulir (minor)' / 'Odo (mucha)' -> {'Ulir': 'Minor'}. Devuelve {} si nada."""
    if not text:
        return {}
    low = str(text).lower()
    crus = None
    for key, val in BLOOD_MAP.items():
        if key in low:
            crus = val
            break
    if crus is None:
        return {}
    grade = "Minor"
    if any(w in low for w in MAJOR_WORDS):
        grade = "Major"
    elif any(w in low for w in MINOR_WORDS):
        grade = "Minor"
    return {crus: grade}


def _load_class_con_mov():
    path = os.path.join(REPO, "data", "general", "classes.json")
    cl = {str(x.get("id") or x.get("nid")): x for x in json.load(open(path))}
    return cl


def main():
    src = json.load(open(SRC))
    classes = _load_class_con_mov()
    out = {
        "_meta": {
            "generated_from": "gen2_inheritance_source.json (fireemblemwod)",
            "model": "final = base +/- father_mods[father]; growth idem; base = min Nv.1 entre padres",
            "class_map": CLASS_MAP,
            "note": "Ajusta libremente base_stats/base_growths/father_mods; "
                    "skills en crudo (nombres de la fuente).",
        }
    }
    for nid, ch in src.items():
        if not isinstance(ch, dict) or "fathers" not in ch:
            continue
        fathers = ch["fathers"]
        base = {}
        gmin = {}
        for s in STATS:
            l1 = [f["lv1"][s] for f in fathers.values()
                  if isinstance(f, dict) and f.get("lv1", {}).get(s) is not None]
            gg = [f["growth"][s] for f in fathers.values()
                  if isinstance(f, dict) and f.get("growth", {}).get(s) is not None]
            base[s] = min(l1) if l1 else 0
            gmin[s] = min(gg) if gg else 0
        mods = {}
        for fname, f in fathers.items():
            if not isinstance(f, dict):
                continue
            b = {s: int(f.get("lv1", {}).get(s, base[s])) - base[s] for s in STATS}
            g = {s: int(f.get("growth", {}).get(s, gmin[s])) - gmin[s] for s in STATS}
            mods[FATHER_MAP.get(fname, fname)] = {
                "base": b,
                "growth": g,
                "skills": f.get("skills", []),
                "blood": f.get("holy_blood_note", ""),
            }
        klass_raw = str(ch.get("klass", "")).strip()
        klass = CLASS_MAP.get(klass_raw, klass_raw)
        cbase = classes.get(klass, {}).get("bases", {})
        out[nid] = {
            "klass": klass,
            "klass_source": klass_raw,
            "holy_blood": parse_blood(ch.get("holy_blood", "")),
            "personal_skills": ch.get("personal_skills", []),
            "starting_items": ch.get("starting_items", []),
            "max_stats": {s: int(ch.get("max_stats", {}).get(s, 0)) for s in STATS},
            "base_stats": base,
            "base_growths": gmin,
            # CON/MOV vienen de la clase (la fuente FE4 no los lista). MOV en tiles (valor real).
            "con": int(cbase.get("CON", 0)),
            "mov": int(cbase.get("MOV", 0)),
            "father_mods": mods,
        }
    json.dump(out, open(OUT, "w"), indent=1, ensure_ascii=False)
    open(OUT, "a").write("\n")
    n = len([k for k in out if not k.startswith("_")])
    print("wrote", OUT, "children:", n)


if __name__ == "__main__":
    main()
