#!/usr/bin/env python3
"""
asset_coverage.py

Genera docs/ASSET_COVERAGE.md — una matriz de cobertura de assets de personajes
y clases (map sprites + animaciones de combate + retratos) para ir tachando a
medida que se completan.

Cruza:
  - data/general/classes.json  (clases: map_sprite_nid, combat_anim_nid, tier)
  - data/general/units.json    (personajes: nid, klass, gender)
  - assets/map_sprites/*-stand.png / *-move.png
  - assets/combat_anims/{NID}_{Variant}/*.png
  - assets/portraits/characters/{nid}.png

Uso:
  python tools/asset_coverage.py           # regenera docs/ASSET_COVERAGE.md
"""

import json
import os
from collections import defaultdict

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MS_DIR = os.path.join(ROOT, "assets", "map_sprites")
CA_DIR = os.path.join(ROOT, "assets", "combat_anims")
PT_DIR = os.path.join(ROOT, "assets", "portraits", "characters")
OUT = os.path.join(ROOT, "docs", "ASSET_COVERAGE.md")

YES, NO = "✅", "⬜"


def load(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def map_sprite_nids():
    """Set de nids con -stand.png y set con -move.png."""
    stand, move = set(), set()
    if os.path.isdir(MS_DIR):
        for f in os.listdir(MS_DIR):
            if f.endswith("-stand.png"):
                stand.add(f[:-len("-stand.png")])
            elif f.endswith("-move.png"):
                move.add(f[:-len("-move.png")])
    return stand, move


def combat_anim_folders():
    """{ folder_name: set(weapon_tokens) }  a partir de {folder}/{folder}_{Weapon}.png."""
    out = {}
    if not os.path.isdir(CA_DIR):
        return out
    for name in sorted(os.listdir(CA_DIR)):
        d = os.path.join(CA_DIR, name)
        if not os.path.isdir(d):
            continue
        weapons = set()
        for f in os.listdir(d):
            if f.endswith(".png") and f.startswith(name + "_"):
                weapons.add(f[len(name) + 1:-4])
        out[name] = weapons
    return out


def portrait_nids():
    out = set()
    if os.path.isdir(PT_DIR):
        for f in os.listdir(PT_DIR):
            if f.endswith(".png"):
                out.add(f[:-4])
    return out


def mark(cond):
    return YES if cond else NO


def weapons_str(weapons):
    return ", ".join(sorted(weapons)) if weapons else "—"


def main():
    classes = load(os.path.join(ROOT, "data", "general", "classes.json"))
    units = load(os.path.join(ROOT, "data", "general", "units.json"))
    stand, move = map_sprite_nids()
    ca = combat_anim_folders()
    ca_names = set(ca.keys())
    portraits = portrait_nids()

    # Personajes por clase.
    by_class = defaultdict(list)
    for u in units:
        by_class[str(u.get("klass", ""))].append(u)

    lines = []
    lines.append("# Cobertura de assets — personajes y clases\n")
    lines.append("> Generado por `tools/asset_coverage.py`. Regenera con "
                 "`python tools/asset_coverage.py`.\n")
    lines.append(f"> Leyenda: {YES} = tenemos · {NO} = falta · ⚠️ = el asset existe pero "
                 "su nombre no coincide con `combat_anim_nid` (el juego NO lo encuentra) · — = N/A\n")

    can_by_class = {str(c.get("id", "")): str(c.get("combat_anim_nid", "")) for c in classes}

    # ── Resumen ──────────────────────────────────────────────────────────────
    n_cls = len(classes)
    cls_with_ms = sum(1 for c in classes if str(c.get("map_sprite_nid", "")) in stand)
    cls_with_generic_ca = sum(1 for c in classes
                              if (str(c.get("combat_anim_nid", "")) + "_Generic") in ca_names)
    chars_with_pt = sum(1 for u in units if str(u.get("nid", "")) in portraits)
    lines.append("\n## Resumen\n")
    lines.append(f"- Clases: **{n_cls}** · con map sprite: **{cls_with_ms}** · "
                 f"con combat anim genérica: **{cls_with_generic_ca}**")
    lines.append(f"- Personajes: **{len(units)}** · con retrato: **{chars_with_pt}**")
    lines.append(f"- Carpetas de combat anim: **{len(ca)}**\n")

    # ── Tabla de CLASES ──────────────────────────────────────────────────────
    lines.append("\n## Clases — map sprites y combat anim (genérico / por género)\n")
    lines.append("| Clase | Tier | Map stand | Map move | Anim Generic | Anim Male | "
                 "Anim Female | Armas de la anim genérica |")
    lines.append("|---|---|:---:|:---:|:---:|:---:|:---:|---|")
    for c in sorted(classes, key=lambda x: (x.get("tier", 0), str(x.get("id", "")))):
        cid = str(c.get("id", ""))
        msn = str(c.get("map_sprite_nid", cid))
        can = str(c.get("combat_anim_nid", cid))
        gen_f = can + "_Generic"
        male_f = can + "_Male"
        fem_f = can + "_Female"
        row = [
            cid, str(c.get("tier", "")),
            mark(msn in stand), mark(msn in move),
            mark(gen_f in ca_names), mark(male_f in ca_names), mark(fem_f in ca_names),
            weapons_str(ca.get(gen_f, set()) - {"Unarmed"}),
        ]
        lines.append("| " + " | ".join(row) + " |")

    # ── Tabla de PERSONAJES ──────────────────────────────────────────────────
    lines.append("\n## Personajes — retrato y combat anim propia (PRF)\n")
    lines.append("| Personaje | Clase | Gén | Retrato | Map sprite propio | "
                 "Combat anim propia | Armas de su anim |")
    lines.append("|---|---|:---:|:---:|:---:|:---:|---|")
    for u in sorted(units, key=lambda x: (str(x.get("klass", "")), str(x.get("nid", "")))):
        nid = str(u.get("nid", ""))
        klass = str(u.get("klass", ""))
        can = can_by_class.get(klass, "")
        # Carpeta de anim propia: cualquiera que termine en _{nid} (semántica "¿lo
        # tenemos?"). Resuelve en juego solo si es exactamente {combat_anim_nid}_{nid}.
        prf_folder = next((f for f in sorted(ca_names) if f.endswith("_" + nid)), None)
        if prf_folder is None:
            anim_cell = NO
        elif can and prf_folder == can + "_" + nid:
            anim_cell = YES
        else:
            anim_cell = "⚠️"
        row = [
            nid, klass, str(u.get("gender", "")),
            mark(nid in portraits),
            mark(nid in stand),
            anim_cell,
            weapons_str(ca.get(prf_folder, set()) - {"Unarmed"}) if prf_folder else "—",
        ]
        lines.append("| " + " | ".join(row) + " |")

    # ── Problemas detectados (combat_anim_nid que rompe el resolver) ──────────
    problems = []
    for c in classes:
        can = str(c.get("combat_anim_nid", ""))
        if " " in can:
            problems.append(f"- Clase **`{c.get('id')}`**: `combat_anim_nid = \"{can}\"` "
                            "tiene un **espacio** → el resolver busca una carpeta con espacio "
                            "que nunca existirá. Quitar el espacio.")
    for u in units:
        nid = str(u.get("nid", ""))
        klass = str(u.get("klass", ""))
        can = can_by_class.get(klass, "")
        prf_folder = next((f for f in sorted(ca_names) if f.endswith("_" + nid)), None)
        if prf_folder and can and prf_folder != can + "_" + nid:
            problems.append(f"- **`{nid}`** ({klass}): anim en `assets/combat_anims/{prf_folder}/` "
                            f"pero `combat_anim_nid=\"{can}\"` → el resolver busca "
                            f"`{can}_{nid}` (no existe). Renombrar la carpeta a `{can}_{nid}` "
                            f"**o** corregir `combat_anim_nid`.")
    if problems:
        lines.append("\n## ⚠️ Problemas detectados (el juego no encuentra estos anims)\n")
        lines.extend(problems)

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    print("Escrito", os.path.relpath(OUT, ROOT))
    print(f"  clases={n_cls} (map={cls_with_ms}, anim_gen={cls_with_generic_ca}) "
          f"personajes={len(units)} (retrato={chars_with_pt})")


if __name__ == "__main__":
    main()
