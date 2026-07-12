#!/usr/bin/env python3
# build_events.py
# =============================================================================
# Genera data/<game>/events/events.json a partir de los eventos de un .ltproj.
#
# Fuente LT:  <ltproj>/game_data/events.json   (array consolidado de eventos)
#   (equivalente a la suma de <ltproj>/game_data/events/*.json)
#
# Cada evento LT tiene la forma:
#   { "name", "trigger", "level_nid", "condition", "commands", "only_once",
#     "priority" }
# y `commands` es una lista de pares  [cmd_name, [arg, ...]].
#
# El único remapeo necesario es de NIDs de unidad (los eventos referencian
# "FakeMidir", "Chagall1", "EldiganAlly", "Leaf"... que en el proyecto se
# unifican a "Midir"/"Chagall"/"Eldigan"/"Leif" — igual que build_levels.py).
# Los equipos ('player'/'enemy') en los comandos NO necesitan remapeo (no hay
# literales 'other'/'enemy2' en los eventos canónicos); aun así se aplica
# TEAM_REMAP de forma defensiva al 2º arg de `change_team`.
#
# Uso:
#   python build_events.py \
#       --fe4 "<GotHW.ltproj>/game_data/events.json" \
#       --fe5 "<Thracia776.ltproj>/game_data/events.json"
#
# Salida: data/fe4/events/events.json  y  data/fe5/events/events.json
# (formato consumido por PrologueTest._load_all_events → EventSystem).
# =============================================================================

import argparse
import json
import os

# Mismo mapeo que tools/build_levels.py (NID_REMAP) — mantener sincronizado.
NID_REMAP = {
    "FakeElliot": "Elliot", "FakeMidir": "Midir",
    "Chagall1": "Chagall", "Chagall2": "Chagall",
    "EldiganAlly": "Eldigan", "EldiganEnemy": "Eldigan",
    "Leaf": "Leif",
}
TEAM_REMAP = {"other": "ally", "enemy2": "other"}

# Rutas LT por defecto (máquina del autor) — coinciden con las otras tools.
DEFAULT_FE4 = r"D:\FEHW\lt-maker-moded\GotHW.ltproj\game_data\events.json"
DEFAULT_FE5 = r"D:\FEHW\lt-maker-moded\Thracia776.ltproj\game_data\events.json"

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(HERE)


def _remap_string(s):
    """Remapea un string: si es EXACTAMENTE un NID → su valor; además sustituye
    literales entrecomillados 'NID' / \"NID\" dentro de expresiones (condiciones
    tipo `unit.nid == 'Chagall1'`, `check_pair('Chagall1','Erinys')`), pues en
    runtime el nid ya viene unificado ('Chagall'). NO toca substrings sin comillas
    (los nombres de evento tipo "FightChagall1" se conservan como identificadores)."""
    if s in NID_REMAP:
        return NID_REMAP[s]
    for old, new in NID_REMAP.items():
        if old in s:
            s = s.replace("'%s'" % old, "'%s'" % new)
            s = s.replace('"%s"' % old, '"%s"' % new)
    return s


def remap_tokens(value):
    """Aplica _remap_string recursivamente a todos los strings del evento."""
    if isinstance(value, str):
        return _remap_string(value)
    if isinstance(value, list):
        return [remap_tokens(v) for v in value]
    if isinstance(value, dict):
        return {k: remap_tokens(v) for k, v in value.items()}
    return value


def remap_event(ev):
    ev = remap_tokens(ev)   # NIDs de unidad en todos los args
    # Remapeo defensivo de equipo en change_team (arg 1).
    for cmd in ev.get("commands", []):
        if (isinstance(cmd, list) and len(cmd) >= 2 and cmd[0] == "change_team"
                and isinstance(cmd[1], list) and len(cmd[1]) >= 2):
            if cmd[1][1] in TEAM_REMAP:
                cmd[1][1] = TEAM_REMAP[cmd[1][1]]
    return ev


def build_game(game, src_path):
    if not os.path.isfile(src_path):
        print("  [%s] fuente no encontrada: %s (omitido)" % (game, src_path))
        return
    with open(src_path, "r", encoding="utf-8") as f:
        events = json.load(f)
    if not isinstance(events, list):
        raise SystemExit("events.json de %s no es un array" % game)

    events = [remap_event(ev) for ev in events if isinstance(ev, dict)]

    out_dir = os.path.join(PROJECT_ROOT, "data", game, "events")
    os.makedirs(out_dir, exist_ok=True)
    out_path = os.path.join(out_dir, "events.json")
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(events, f, ensure_ascii=False, indent=2)

    triggers = {}
    for ev in events:
        triggers[ev.get("trigger", "?")] = triggers.get(ev.get("trigger", "?"), 0) + 1
    print("  [%s] %d eventos -> %s" % (game, len(events),
          os.path.relpath(out_path, PROJECT_ROOT)))


def main():
    ap = argparse.ArgumentParser(description="Genera data/<game>/events/events.json desde .ltproj")
    ap.add_argument("--fe4", default=DEFAULT_FE4, help="ruta a GotHW.ltproj/game_data/events.json")
    ap.add_argument("--fe5", default=DEFAULT_FE5, help="ruta a Thracia776.ltproj/game_data/events.json")
    args = ap.parse_args()
    print("build_events.py — generando eventos nativos")
    build_game("fe4", args.fe4)
    build_game("fe5", args.fe5)
    print("Listo.")


if __name__ == "__main__":
    main()
