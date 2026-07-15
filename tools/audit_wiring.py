#!/usr/bin/env python3
"""
audit_wiring.py

Audita la integridad referencial entre las 4 bases de datos/assets:
  classes.json  <->  units.json  <->  map_sprites/  <->  combat_anims/

Comprueba, en ambos sentidos, que todo lo que una tabla referencia exista, y
lista los huérfanos (assets que nadie referencia). NO modifica nada.
"""
import json, os
from collections import defaultdict

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MS_DIR = os.path.join(ROOT, "assets", "map_sprites")
CA_DIR = os.path.join(ROOT, "assets", "combat_anims")


def load(p):
    with open(os.path.join(ROOT, p), encoding="utf-8") as f:
        return json.load(f)


def ms_variants():
    """map_sprite_nid -> set(variantes con -stand y -move)."""
    stand, move = set(), set()
    for f in os.listdir(MS_DIR):
        if f.endswith("-stand.png"):
            stand.add(f[:-len("-stand.png")])
        elif f.endswith("-move.png"):
            move.add(f[:-len("-move.png")])
    return stand, move


def ca_folders():
    """nombre_carpeta -> set(armas)."""
    out = {}
    for name in sorted(os.listdir(CA_DIR)):
        d = os.path.join(CA_DIR, name)
        if not os.path.isdir(d):
            continue
        w = set()
        for f in os.listdir(d):
            if f.endswith(".png") and f.startswith(name + "_"):
                w.add(f[len(name) + 1:-4])
        out[name] = w
    return out


classes = load("data/general/classes.json")
units = load("data/general/units.json")
stand, move = ms_variants()
ca = ca_folders()
ca_names = set(ca.keys())

class_by_id = {str(c["id"]): c for c in classes}
can_by_class = {str(c["id"]): str(c.get("combat_anim_nid", c["id"])) for c in classes}
msn_by_class = {str(c["id"]): str(c.get("map_sprite_nid", c["id"])) for c in classes}

# Conjunto de "bases" de combat_anim que las clases esperan.
can_all = set(can_by_class.values())
msn_all = set(msn_by_class.values())

sep = lambda t: print("\n" + "=" * 78 + "\n" + t + "\n" + "=" * 78)

# ── 1. units.klass -> classes.id ──────────────────────────────────────────────
sep("1. units.klass -> classes.id  (unidades con clase inexistente)")
bad = sorted({str(u["nid"]) + " -> klass=" + str(u.get("klass"))
              for u in units if str(u.get("klass")) not in class_by_id})
print("\n".join("  ✗ " + b for b in bad) if bad else "  ✓ todas las clases existen")

# ── 2. classes.map_sprite_nid -> map_sprites ─────────────────────────────────
sep("2. classes.map_sprite_nid -> map_sprites  (falta -stand/-move)")
prob = []
for cid, msn in sorted(msn_by_class.items()):
    miss = []
    if msn not in stand: miss.append("stand")
    if msn not in move: miss.append("move")
    if miss:
        prob.append(f"  ✗ {cid}: map_sprite_nid='{msn}' falta {','.join(miss)}")
print("\n".join(prob) if prob else "  ✓ todas las clases tienen su map sprite")

# ── 3. Resolución REAL por unidad (imita CombatAnimResolver) ──────────────────
# El resolver prueba, en orden:  {can}_{nid}  ->  {can}_{Male|Female}  ->  {can}_Generic
sep("3. Resolución de combat anim por unidad (PRF -> género -> Generic)")
def resolves(can, nid, gender):
    if not can:
        return None
    if f"{can}_{nid}" in ca_names:
        return f"{can}_{nid}"
    g = {"M": "Male", "F": "Female"}.get(gender, "")
    if g and f"{can}_{g}" in ca_names:
        return f"{can}_{g}"
    if f"{can}_Generic" in ca_names:
        return f"{can}_Generic"
    return None
prob = []
for u in sorted(units, key=lambda x: (str(x.get("klass")), str(x["nid"]))):
    nid = str(u["nid"]); klass = str(u.get("klass"))
    can = can_by_class.get(klass, "")
    if resolves(can, nid, str(u.get("gender", ""))) is None:
        # ¿existe algún asset {*}_{nid} que NO resuelve por mal combat_anim_nid?
        stray = [f for f in sorted(ca_names) if f.endswith("_" + nid)]
        note = f"  (hay assets {stray} pero base!='{can}')" if stray else "  (sin asset)"
        prob.append(f"  ✗ {nid} ({klass}, ca='{can}'): no resuelve{note}")
print("\n".join(prob) if prob else "  ✓ todas las unidades resuelven una anim")
print(f"  ({len(units) - len(prob)}/{len(units)} unidades resuelven)")

# ── 4. clases SIN NINGUNA unidad que no tengan anim base (informativo) ────────
sep("4. clases sin anim base Generic/Male/Female (solo importa si se usan como genéricas)")
prob = []
classes_with_units = {str(u.get("klass")) for u in units}
for cid, can in sorted(can_by_class.items()):
    has = [v for v in ("Generic", "Male", "Female") if f"{can}_{v}" in ca_names]
    if not has:
        tag = "  <- EN USO por unidades" if cid in classes_with_units else "  (sin unidades)"
        prob.append(f"  · {cid}: combat_anim_nid='{can}' sin Generic/Male/Female{tag}")
print("\n".join(prob) if prob else "  ✓ todas las clases tienen anim base")

# ── 5. HUÉRFANOS: map sprites que ninguna clase referencia ───────────────────
sep("5. map_sprites huérfanos (base, sin variantes de género/letra)")
# Consideramos base = nombre sin sufijo M/F/Female/Female2/A/B etc. Difícil de
# inferir; mostramos los -stand cuyo nombre exacto no es map_sprite_nid de nadie
# NI un sufijo de género de uno que sí lo es.
def is_gender_variant(name):
    for base in msn_all:
        if name != base and name.startswith(base) and name[len(base):] in (
                "M", "F", "Female", "Male", "Female2", "Male2"):
            return base
    return None
orphan_ms = sorted(s for s in stand
                   if s not in msn_all and is_gender_variant(s) is None)
print("\n".join("  · " + o for o in orphan_ms) if orphan_ms
      else "  ✓ sin map sprites huérfanos")
print(f"  ({len(orphan_ms)} huérfanos de {len(stand)} sprites -stand)")

# ── 6. HUÉRFANOS: carpetas combat_anim que ninguna clase/personaje referencia ─
sep("6. combat_anims huérfanas ({NID} base que ninguna clase espera)")
# Base de cada carpeta = parte antes de _Generic/_Male/_Female/_{Char}.
orphan_ca = []
for name in sorted(ca_names):
    # separar sufijo variante
    for suf in ("_Generic", "_Male", "_Female"):
        if name.endswith(suf):
            base = name[:-len(suf)]
            break
    else:
        # variante PRF: {base}_{Char} — base = todo menos el ultimo _seg
        base = name.rsplit("_", 1)[0]
    if base not in can_all:
        orphan_ca.append(f"  · {name}/  (base '{base}' no es combat_anim_nid de ninguna clase)")
print("\n".join(orphan_ca) if orphan_ca else "  ✓ sin carpetas huérfanas")
print(f"  ({len(orphan_ca)} huérfanas de {len(ca_names)} carpetas)")

sep("RESUMEN")
print(f"  clases={len(classes)}  units={len(units)}  "
      f"map_sprite_stand={len(stand)}  combat_anim_folders={len(ca_names)}")
