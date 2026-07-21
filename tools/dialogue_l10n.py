#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
dialogue_l10n.py — utilidades de localización de diálogos por capítulo.

Formato de los documentos por idioma (uno por capítulo × idioma), tal como los
produce la sesión de extracción desde ROMs/parches. Ejemplos canónicos en
docs/examples/dialogue_format/Chapter01.{en,es,it,jp}.json:

    {
      "<CLAVE_DE_ESCENA>": [ {"SPEAKER": "linea{w}..."}, ... ],
      ...
    }

CLAVES por idioma
-----------------
- Idiomas de alfabeto LATINO (en, es, it, de, fr): usan la MISMA clave de escena
  (OPENING1, DAGDARARRIVE, OSIANHOUSEOSIAN, ...). Se leen tal cual.
- JAPONÉS (jp): la clave es una descripción en japonés con el equivalente latino
  ANOTADO entre ⟦ ... ⟧. Debemos usar ESE comentario como clave, no el japonés:
      "民家（下）  ⟦OSIANHOUSEOSIAN⟧"        -> OSIANHOUSEOSIAN
      "ワールドマップ  ⟦WORLDMAP1-6⟧"         -> WORLDMAP1-6      (rango)
      "オープニング  ⟦OPENING1 · OPENING3⟧"  -> OPENING1 · OPENING3  (fusión)
      "ワイズマン初戦時  ⟦... (sin equiv.)⟧"  -> sin equivalente en la versión LT

  El token ⟦...⟧ puede referenciar:
    · una sola escena           -> "OSIANHOUSEOSIAN"
    · un RANGO                  -> "WORLDMAP1-6"     (WORLDMAP1..WORLDMAP6)
    · una FUSIÓN de escenas     -> "OPENING1 · OPENING3" / "DAGDARARRIVE · MARTYARRIVE"
    · contenido SOLO-ROM        -> "... (sin equiv.)"  (no existe en los eventos LT)

  Esta herramienta EXTRAE el token; resolver rangos/fusiones a escenas concretas
  es responsabilidad de la fase de casado (la estructura de la ROM japonesa no
  coincide 1:1 con la de los eventos LT).

Uso:
    python tools/dialogue_l10n.py normalize <chapter.jp.json> [-o out.json]
        Reescribe el JP con las claves ⟦...⟧ (limpio, alineado con el latino).
    python tools/dialogue_l10n.py check <dir_o_prefijo>
        Compara en/es/it/jp de un capítulo y reporta huecos/desalineaciones.
"""

import argparse
import json
import os
import re
import sys

# Delimitadores del comentario latino en las claves japonesas.
_BRACKET = re.compile(r"⟦(.+?)⟧")
# Separadores de escenas dentro de un token de fusión ("A · B", "A, B", "A/B").
_SPLIT = re.compile(r"\s*[·,/]\s*")
_SIN_EQUIV = re.compile(r"\(?\s*sin\s+equiv\.?\s*\)?", re.IGNORECASE)


def latin_key(raw_key: str) -> str:
    """Clave latina de una clave de escena.

    - JP: devuelve el contenido de ⟦...⟧ (sin la descripción japonesa).
    - Latino: devuelve la clave tal cual (no lleva ⟦...⟧).
    """
    m = _BRACKET.search(raw_key)
    return m.group(1).strip() if m else raw_key.strip()


def is_rom_only(token: str) -> bool:
    """El token latino marca contenido solo-ROM (sin equivalente en eventos LT)."""
    return bool(_SIN_EQUIV.search(token))


def expand_scene_refs(token: str) -> list:
    """Escenas latinas concretas a las que se refiere un token ⟦...⟧.

    Resuelve rangos ("WORLDMAP1-6" -> WORLDMAP1..WORLDMAP6) y fusiones
    ("OPENING1 · OPENING3" -> [OPENING1, OPENING2, OPENING3]). El contenido
    solo-ROM devuelve [] (no casa con ninguna escena LT).
    """
    if is_rom_only(token):
        return []
    refs = []
    for part in _SPLIT.split(token.strip()):
        part = part.strip()
        if not part:
            continue
        m = re.match(r"^([A-Za-z]+?)(\d+)\s*-\s*([A-Za-z]*?)(\d+)$", part)
        if m:
            pre, a, pre2, b = m.group(1), int(m.group(2)), m.group(3), int(m.group(4))
            base = pre2 if pre2 else pre
            for i in range(min(a, b), max(a, b) + 1):
                refs.append("%s%d" % (base, i))
        else:
            refs.append(part)
    return refs


def load_chapter(path: str) -> dict:
    """Carga un documento de capítulo y NORMALIZA sus claves a latino (⟦...⟧ en jp)."""
    with open(path, encoding="utf-8") as f:
        raw = json.load(f)
    out = {}
    for k, v in raw.items():
        out[latin_key(k)] = v
    return out


def _cmd_normalize(args) -> int:
    data = load_chapter(args.file)
    text = json.dumps(data, ensure_ascii=False, indent=2)
    if args.out:
        with open(args.out, "w", encoding="utf-8") as f:
            f.write(text + "\n")
        print("Escrito %s (%d escenas)" % (args.out, len(data)))
    else:
        print(text)
    return 0


def _resolve_prefix(target: str) -> dict:
    """Devuelve {locale: path} para un directorio o prefijo 'dir/Chapter01'."""
    paths = {}
    if os.path.isdir(target):
        for name in os.listdir(target):
            m = re.match(r"(.+)\.([a-z]{2})\.json$", name)
            if m:
                paths[m.group(2)] = os.path.join(target, name)
    else:
        base = target
        for loc in ("en", "es", "it", "de", "fr", "jp", "ja"):
            p = "%s.%s.json" % (base, loc)
            if os.path.exists(p):
                paths[loc] = p
    return paths


def _cmd_check(args) -> int:
    paths = _resolve_prefix(args.target)
    if not paths:
        print("No encontré documentos <cap>.<locale>.json en %r" % args.target, file=sys.stderr)
        return 2
    chapters = {loc: load_chapter(p) for loc, p in sorted(paths.items())}
    print("Idiomas: %s" % ", ".join(sorted(chapters)))

    # Referencia = unión de claves de los idiomas latinos (comparten claves).
    latin_locs = [l for l in chapters if l not in ("jp", "ja")]
    ref_keys = set()
    for l in latin_locs:
        ref_keys |= set(chapters[l].keys())

    # Cobertura latina: qué escena falta en qué idioma.
    print("\n== Escenas por idioma latino ==")
    for l in sorted(latin_locs):
        missing = sorted(ref_keys - set(chapters[l].keys()))
        print("  %s: %d/%d escenas%s" % (l, len(chapters[l]), len(ref_keys),
              ("  faltan: " + ", ".join(missing)) if missing else ""))

    # Casado del japonés: cada token ⟦...⟧ -> escenas latinas concretas.
    for jp_loc in ("jp", "ja"):
        if jp_loc not in chapters:
            continue
        print("\n== Casado del japonés (%s) ==" % jp_loc)
        covered = set()
        for token in chapters[jp_loc]:
            if is_rom_only(token):
                print("  ⟦%s⟧  -> SOLO-ROM (sin escena LT)" % token)
                continue
            refs = expand_scene_refs(token)
            miss = [r for r in refs if r not in ref_keys]
            covered |= set(r for r in refs if r in ref_keys)
            flag = ""
            if len(refs) > 1:
                flag += "  [fusión/rango -> %s]" % ", ".join(refs)
            if miss:
                flag += "  [!] sin equivalente latino: %s" % ", ".join(miss)
            print("  ⟦%s⟧%s" % (token, flag))
        jp_missing = sorted(ref_keys - covered)
        if jp_missing:
            print("  [!] escenas latinas SIN cobertura japonesa: %s" % ", ".join(jp_missing))
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description="Utilidades de localización de diálogos.")
    sub = ap.add_subparsers(dest="cmd", required=True)

    n = sub.add_parser("normalize", help="Reescribe un jp.json con claves ⟦...⟧.")
    n.add_argument("file")
    n.add_argument("-o", "--out")
    n.set_defaults(func=_cmd_normalize)

    c = sub.add_parser("check", help="Reporta alineación en/es/it/jp de un capítulo.")
    c.add_argument("target", help="Carpeta o prefijo, p. ej. docs/examples/dialogue_format/Chapter01")
    c.set_defaults(func=_cmd_check)

    args = ap.parse_args()
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
