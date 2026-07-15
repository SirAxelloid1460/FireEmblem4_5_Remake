#!/usr/bin/env python3
"""
resource_audit.py

Auditoría global de recursos: cruza TODA la data (units, classes, items, skills,
weapons) contra los assets (retratos, map sprites, combat anims, iconos, audio)
y reporta lo que tenemos vs lo que falta, además de referencias colgantes.

Salida: consola + docs/RESOURCE_AUDIT.md
"""
import json, os
from collections import Counter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
D = lambda *p: os.path.join(ROOT, *p)
load = lambda p: json.load(open(D(*p.split("/")), encoding="utf-8"))
def listdir(*p):
    d = D(*p)
    return os.listdir(d) if os.path.isdir(d) else []

# ---- data ----
units = load("data/general/units.json")
classes = load("data/general/classes.json")
items = load("data/general/items.json")
skills = load("data/general/skills.json")
weapons = load("data/general/weapons.json")
class_by = {c["id"]: c for c in classes}
item_nids = {i["nid"] for i in items} | {w["nid"] for w in weapons}
skill_nids = {s["nid"] for s in skills}

# ---- assets ----
char_ports = {f[:-4] for f in listdir("assets","portraits","characters") if f.endswith(".png")}
extra_ports = {f[:-4] for f in listdir("assets","portraits","extra") if f.endswith(".png")}
gen_ports = {f[len("Generic_Portrait_"):-4] for f in listdir("assets","portraits","generic")
             if f.startswith("Generic_Portrait_") and f.endswith(".png")}
ms_stand = {f[:-len("-stand.png")] for f in listdir("assets","map_sprites") if f.endswith("-stand.png")}
ms_move = {f[:-len("-move.png")] for f in listdir("assets","map_sprites") if f.endswith("-move.png")}
ca_folders = {n for n in listdir("assets","combat_anims") if os.path.isdir(D("assets","combat_anims",n))}

PORTRAIT_ALIASES = {"Arvis":"ArvisYoung","Finn":"FinnYoung","Lewyn":"LewynYoung",
                    "Oifey":"OifayeYoung","Oifaye":"OifayeYoung","Robert":"RobertFE5"}
def has_portrait(nid):
    return (nid in char_ports or nid in extra_ports
            or PORTRAIT_ALIASES.get(nid) in char_ports)

def anim_resolves(can, nid, gender):
    if not can: return False
    if f"{can}_{nid}" in ca_folders: return True
    g = {"M":"Male","F":"Female"}.get(gender, "")
    if g and f"{can}_{g}" in ca_folders: return True
    return f"{can}_Generic" in ca_folders

R = []  # report lines
def sec(t): R.append("\n## " + t)
def line(s): R.append(s)

R.append("# Auditoría de recursos — FE4/FE5 remake\n")
R.append("> Generado por `tools/resource_audit.py`. ✅ tenemos · ⬜ falta\n")

# ================= INVENTARIO =================
sec("Inventario")
inv = [
    ("Clases (classes.json)", len(classes)),
    ("Personajes (units.json)", len(units)),
    ("Items (items.json)", len(items)),
    ("Armas (weapons.json)", len(weapons)),
    ("Skills (skills.json)", len(skills)),
    ("Retratos de personaje", len(char_ports)),
    ("Retratos extra (NPC)", len(extra_ports)),
    ("Retratos genéricos de clase", len(gen_ports)),
    ("Map sprites (stand)", len(ms_stand)),
    ("Carpetas de combat anim", len(ca_folders)),
    ("Pistas de música (assets/music)", len([f for f in listdir("assets","music")])),
    ("SFX (assets/sfx)", len([f for f in listdir("assets","sfx")])),
    ("Tilesets", len([f for f in listdir("assets","tilesets") if f.endswith('.png')])),
]
for k, v in inv:
    line(f"- {k}: **{v}**")

# ================= UNITS =================
sec("Personajes — cobertura de assets (122)")
u_no_port, u_no_ms, u_no_anim, u_bad_item, u_bad_skill = [], [], [], [], []
for u in units:
    nid, klass, g = u["nid"], u.get("klass",""), u.get("gender","")
    c = class_by.get(klass, {})
    msn = c.get("map_sprite_nid", klass)
    can = c.get("combat_anim_nid", klass)
    if not has_portrait(nid): u_no_port.append(nid)
    if msn not in ms_stand: u_no_ms.append(f"{nid}({msn})")
    if not anim_resolves(can, nid, g): u_no_anim.append(nid)
    for it in u.get("starting_items", []):
        n = it if isinstance(it, str) else it[0]
        if n and n not in item_nids: u_bad_item.append(f"{nid}:{n}")
    for sk in u.get("learned_skills", []):
        n = sk[1] if isinstance(sk, list) and len(sk) > 1 else (sk if isinstance(sk, str) else None)
        if n and n not in skill_nids: u_bad_skill.append(f"{nid}:{n}")
line(f"- con retrato: **{len(units)-len(u_no_port)}/{len(units)}** · sin retrato ({len(u_no_port)}): {', '.join(u_no_port) or '—'}")
line(f"- con map sprite: **{len(units)-len(u_no_ms)}/{len(units)}** · sin: {', '.join(u_no_ms) or '—'}")
line(f"- con combat anim: **{len(units)-len(u_no_anim)}/{len(units)}** · sin ({len(u_no_anim)}): {', '.join(u_no_anim) or '—'}")
line(f"- starting_items colgantes: {', '.join(sorted(set(u_bad_item))) or 'ninguno ✅'}")
line(f"- learned_skills colgantes: {', '.join(sorted(set(u_bad_skill))) or 'ninguno ✅'}")

# ================= CLASSES =================
sec("Clases — cobertura de assets (63)")
c_no_ms, c_no_anim, c_no_gen = [], [], []
for c in classes:
    cid = c["id"]; msn = c.get("map_sprite_nid", cid); can = c.get("combat_anim_nid", cid)
    if msn not in ms_stand or msn not in ms_move: c_no_ms.append(f"{cid}({msn})")
    if not any(f"{can}_{v}" in ca_folders for v in ("Generic","Male","Female")):
        c_no_anim.append(cid)
    if cid not in gen_ports: c_no_gen.append(cid)
line(f"- con map sprite: **{len(classes)-len(c_no_ms)}/{len(classes)}** · sin: {', '.join(c_no_ms) or '—'}")
line(f"- con combat anim base (Generic/Male/Female): **{len(classes)-len(c_no_anim)}/{len(classes)}**")
line(f"  · sin ({len(c_no_anim)}): {', '.join(c_no_anim) or '—'}")
line(f"- con retrato genérico: **{len(classes)-len(c_no_gen)}/{len(classes)}** · sin: {', '.join(c_no_gen) or '—'}")

# ================= DANGLING (data->data) =================
sec("Integridad de referencias data→data")
bad_klass = sorted({u["nid"]+"→"+u["klass"] for u in units if u["klass"] not in class_by})
line(f"- units.klass inexistente: {', '.join(bad_klass) or 'ninguno ✅'}")
# class promotes_from / turns_into
bad_promo = []
for c in classes:
    pf = c.get("promotes_from","")
    if pf and pf not in class_by: bad_promo.append(f"{c['id']}.promotes_from={pf}")
    for t in c.get("turns_into",[]):
        if t and t not in class_by: bad_promo.append(f"{c['id']}.turns_into={t}")
line(f"- class promotes_from/turns_into inexistente: {', '.join(bad_promo) or 'ninguno ✅'}")

os.makedirs(D("docs"), exist_ok=True)
open(D("docs","RESOURCE_AUDIT.md"),"w",encoding="utf-8").write("\n".join(R)+"\n")
print("\n".join(R))
print("\n>>> escrito docs/RESOURCE_AUDIT.md")
