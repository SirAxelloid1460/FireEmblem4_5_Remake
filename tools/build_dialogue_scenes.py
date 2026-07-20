#!/usr/bin/env python3
# build_dialogue_scenes.py
# =============================================================================
# Convierte los eventos de LT (data/<game>/events/events.json) a un formato de
# ESCENA legible y LOSSLESS (fuente de verdad — plan "B"), y viceversa.
#
# Cada escena = un evento. Estructura:
#   {
#     "<SCENE_KEY>": {
#        "name": "Intro", "trigger": "level_start", "level_nid": "1",
#        "condition": "...", "only_once": true, "priority": 20,
#        "steps": [ <paso>, <paso>, ... ]
#     }, ...
#   }
# Un <paso> es:
#   · Línea hablada:  { "<SpeakerNid>": "texto{w}", "@opts": [...]? }
#       (SpeakerNid con su CASE exacto; @opts preserva estilo/posición del bocadillo)
#   · Acotación/comando:  { "@<command>": <args>, "@rest": [...]? }
#       (@add_portrait, @remove_portrait, @transition, @wait, @add_unit, ...)
#
# El mapeo paso<->comando es reversible al 100% (ver --verify). Alcance COMPLETO:
# se incluyen TODOS los comandos (retratos, presentación y mapa/unidad).
#
# Uso:
#   python tools/build_dialogue_scenes.py --game fe5 [--level 1] [--out <dir>]
#   python tools/build_dialogue_scenes.py --game fe5 --verify        # solo round-trip
#   python tools/build_dialogue_scenes.py --from-scenes <scenes.json> # escenas -> comandos
# =============================================================================

import argparse
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)


def to_step(c):
    """Comando LT [name, args, ...] -> paso (dict). Lossless."""
    name = c[0]
    args = c[1] if len(c) > 1 else []
    rest = c[2:]
    if name == "speak":
        a = args
        s = {a[0]: (a[1] if len(a) > 1 else "")}
        if len(a) > 2:
            s["@opts"] = a[2:]
        if rest:
            s["@rest"] = rest
        return s
    s = {"@" + name: args}
    if rest:
        s["@rest"] = rest
    return s


def from_step(s):
    """Paso (dict) -> comando LT [name, args, ...]. Inverso exacto de to_step."""
    rest = list(s.get("@rest", []))
    spk = [k for k in s.keys() if not k.startswith("@")]
    if spk:
        k = spk[0]
        a = [k, s[k]] + list(s.get("@opts", []))
        return ["speak", a] + rest
    cmd = [k for k in s.keys() if k != "@rest"][0]
    return [cmd[1:], s[cmd]] + rest


def scene_key(name, used):
    """Clave de escena a partir del nombre del evento (única, mayúsculas)."""
    base = re.sub(r"[^A-Za-z0-9]", "", str(name or "SCENE")).upper() or "SCENE"
    key = base
    n = 2
    while key in used:
        key = "%s_%d" % (base, n)
        n += 1
    used.add(key)
    return key


META_KEYS = ["name", "trigger", "level_nid", "condition", "only_once", "priority"]


def event_to_scene(ev):
    sc = {}
    for k in META_KEYS:
        if k in ev:
            sc[k] = ev[k]
    sc["steps"] = [to_step(c) for c in ev.get("commands", []) if isinstance(c, list) and c]
    return sc


def scene_to_event(sc):
    ev = {}
    for k in META_KEYS:
        if k in sc:
            ev[k] = sc[k]
    ev["commands"] = [from_step(s) for s in sc.get("steps", [])]
    return ev


def dump_scenes(scenes):
    """JSON con un paso por línea (steps) y metadatos normales."""
    out = ["{"]
    keys = list(scenes.keys())
    for si, key in enumerate(keys):
        sc = scenes[key]
        out.append('  %s: {' % json.dumps(key, ensure_ascii=False))
        meta = [k for k in META_KEYS if k in sc]
        for mk in meta:
            out.append('    %s: %s,' % (json.dumps(mk), json.dumps(sc[mk], ensure_ascii=False)))
        out.append('    "steps": [')
        steps = sc.get("steps", [])
        out.append(",\n".join("      " + json.dumps(s, ensure_ascii=False) for s in steps))
        out.append("    ]")
        out.append("  }" + ("," if si < len(keys) - 1 else ""))
    out.append("}")
    return "\n".join(out) + "\n"


def load_events(game):
    p = os.path.join(ROOT, "data", game, "events", "events.json")
    if not os.path.exists(p):
        sys.exit("No existe %s" % p)
    return json.load(open(p, encoding="utf-8"))


def main():
    ap = argparse.ArgumentParser(description="Eventos LT <-> formato de escena legible y lossless.")
    ap.add_argument("--game", default="fe5", help="fe4 / fe5")
    ap.add_argument("--level", default="", help="Solo este level_nid (vacío = todos).")
    ap.add_argument("--out", default="", help="Carpeta destino (def data/<game>/events/scenes).")
    ap.add_argument("--verify", action="store_true", help="Solo comprobar round-trip lossless.")
    ap.add_argument("--from-scenes", default="", help="Convierte un scenes.json de vuelta a comandos (stdout).")
    args = ap.parse_args()

    if args.from_scenes:
        scenes = json.load(open(args.from_scenes, encoding="utf-8"))
        evs = [scene_to_event(sc) for sc in scenes.values()]
        print(json.dumps(evs, ensure_ascii=False, indent=2))
        return

    events = load_events(args.game)

    if args.verify:
        total = 0
        for ev in events:
            for c in ev.get("commands", []):
                if not (isinstance(c, list) and c):
                    continue
                total += 1
                if from_step(to_step(c)) != c:
                    sys.exit("ROUND-TRIP FALLÓ en: %r" % c)
        print("round-trip %d comandos → LOSSLESS ✓" % total)
        return

    used = set()
    by_level = {}
    for ev in events:
        lv = str(ev.get("level_nid"))
        if args.level and lv != args.level:
            continue
        by_level.setdefault(lv, {})
        key = scene_key(ev.get("name"), used)
        by_level[lv][key] = event_to_scene(ev)

    out_dir = args.out or os.path.join(ROOT, "data", args.game, "events", "scenes")
    os.makedirs(out_dir, exist_ok=True)
    for lv, scenes in by_level.items():
        path = os.path.join(out_dir, "%s.json" % lv)
        open(path, "w", encoding="utf-8").write(dump_scenes(scenes))
        print("[%s] %s  (%d escenas)" % (args.game, os.path.relpath(path, ROOT), len(scenes)))


if __name__ == "__main__":
    main()
