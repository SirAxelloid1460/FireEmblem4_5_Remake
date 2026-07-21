#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
build_dialogue_l10n.py — separa un events.json de LT en:

  1) DOCUMENTO POR IDIOMA (base inglesa), por capítulo:
       data/<game>/events/lang/<chapter>/dialogue.en.json
       { "<EVENTO>": [ { "SPEAKER": "línea{w}..." }, ... ], ... }
     Solo los `speak`, en orden, agrupados por el `name` del evento (= la escena).
     Es EXACTAMENTE el formato que traducen los idiomas y que lee el autoload
     DialogueL10n (ver docs/examples/dialogue_format/ y docs/dialogue_localization_handoff.md).

  2) DOCUMENTO GENERAL, independiente de la localización:
       data/<game>/events/events.general.json
     La MISMA lista de eventos, pero el texto de cada `speak` se sustituye por una
     CLAVE que llama al diálogo (`@dlg:<EVENTO>#<idx>`). El resto de comandos
     (spawns, movimientos, música, retratos, transiciones...) se conserva igual.

El casado en runtime es por (capítulo = level_nid, escena = name del evento,
índice = posición del `speak` dentro del evento), idéntico a lo que hace
DialogueL10n. `<chapter>` = level_nid; los eventos globales (level_nid null) van
al capítulo "global".

La operación es LOSSLESS: `--verify` reconstruye el events.json original a partir
del general + los dialogue.en y comprueba que coincide byte a byte (estructura).

Uso:
    python tools/build_dialogue_l10n.py --game fe5 [--verify] [--dry-run]
    python tools/build_dialogue_l10n.py --input <events.json> --out <dir> [--verify]
"""

import argparse
import copy
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)

REF_PREFIX = "@dlg:"        # marca de la clave que llama al diálogo en el general


def chapter_of(ev):
    """Capítulo de un evento: str(level_nid), o 'global' si es null/ausente."""
    lv = ev.get("level_nid", None)
    return "global" if lv in (None, "", "null") else str(lv)


def _is_speak(c):
    return isinstance(c, list) and len(c) >= 1 and c[0] == "speak"


def split_events(events):
    """events (lista LT) -> (dialogue, general, warnings).

    dialogue: { chapter -> { event_name -> [ {speaker: texto}, ... ] } }
    general:  lista de eventos con el texto de cada `speak` cambiado por la clave.
    """
    dialogue = {}
    general = []
    used = {}            # chapter -> set(event_name) para detectar colisiones
    warnings = []
    for ev in events:
        ch = chapter_of(ev)
        name = str(ev.get("name", ""))
        used.setdefault(ch, set())
        if name in used[ch]:
            warnings.append("Colisión de nombre '%s' en el capítulo '%s' "
                            "(el runtime no puede distinguirlos)." % (name, ch))
        used[ch].add(name)

        gev = copy.deepcopy(ev)
        lines = []
        gcmds = []
        for c in ev.get("commands", []):
            if _is_speak(c):
                args = c[1] if len(c) > 1 else []
                speaker = str(args[0]) if len(args) > 0 else ""
                text = args[1] if len(args) > 1 else ""
                idx = len(lines)
                lines.append({speaker: text})
                new_args = list(args)
                ref = "%s%s#%d" % (REF_PREFIX, name, idx)
                if len(new_args) > 1:
                    new_args[1] = ref
                else:
                    new_args = [speaker, ref]
                gcmds.append([c[0], new_args] + list(c[2:]))
            else:
                gcmds.append(copy.deepcopy(c))
        gev["commands"] = gcmds
        general.append(gev)

        if lines:
            dialogue.setdefault(ch, {})[name] = lines
    return dialogue, general, warnings


def rebuild_events(general, dialogue):
    """Inverso: general + dialogue -> events.json original (para --verify)."""
    events = []
    for gev in general:
        ch = chapter_of(gev)
        name = str(gev.get("name", ""))
        lines = dialogue.get(ch, {}).get(name, [])
        ev = copy.deepcopy(gev)
        cmds = []
        i = 0
        for c in gev.get("commands", []):
            if _is_speak(c):
                args = list(c[1]) if len(c) > 1 else []
                if i < len(lines):
                    entry = lines[i]
                    speaker = list(entry.keys())[0]
                    text = entry[speaker]
                    if len(args) > 1:
                        args[1] = text
                    else:
                        args = [speaker, text]
                i += 1
                cmds.append([c[0], args] + list(c[2:]))
            else:
                cmds.append(copy.deepcopy(c))
        ev["commands"] = cmds
        events.append(ev)
    return events


def _write(path, data, dry):
    if dry:
        print("  (dry-run) %s" % path)
        return
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write("\n")
    print("  escrito %s" % path)


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--game", choices=["fe4", "fe5"], help="resuelve rutas por defecto")
    ap.add_argument("--input", help="events.json de entrada (si no, por --game)")
    ap.add_argument("--out", help="carpeta base de salida (si no, data/<game>/events)")
    ap.add_argument("--verify", action="store_true", help="solo comprueba round-trip lossless")
    ap.add_argument("--dry-run", action="store_true", help="no escribe; solo informa")
    args = ap.parse_args()

    if args.input:
        in_path = args.input
    elif args.game:
        in_path = os.path.join(ROOT, "data", args.game, "events", "events.json")
    else:
        ap.error("indica --game o --input")
    if not os.path.exists(in_path):
        print("No existe %s" % in_path, file=sys.stderr)
        return 2

    with open(in_path, encoding="utf-8") as f:
        events = json.load(f)
    if not isinstance(events, list):
        print("El events.json debe ser una lista de eventos.", file=sys.stderr)
        return 2

    dialogue, general, warnings = split_events(events)
    for w in warnings:
        print("  [aviso] %s" % w, file=sys.stderr)

    n_lines = sum(len(v) for ch in dialogue.values() for v in ch.values())
    n_scenes = sum(len(ch) for ch in dialogue.values())
    print("%d eventos · %d capítulos con diálogo · %d escenas · %d líneas" % (
        len(events), len(dialogue), n_scenes, n_lines))

    # Round-trip lossless.
    rebuilt = rebuild_events(general, dialogue)
    if rebuilt == events:
        print("round-trip: OK (lossless)")
    else:
        print("round-trip: DIFERENCIAS (no lossless) — no se escribe", file=sys.stderr)
        return 1
    if args.verify:
        return 0

    out_base = args.out or os.path.join(ROOT, "data", args.game or "", "events")
    _write(os.path.join(out_base, "events.general.json"), general, args.dry_run)
    for ch in sorted(dialogue):
        path = os.path.join(out_base, "lang", ch, "dialogue.en.json")
        _write(path, dialogue[ch], args.dry_run)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
