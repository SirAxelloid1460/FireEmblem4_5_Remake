#!/usr/bin/env python3
# build.py — empaqueta el traductor como ejecutable único con PyInstaller.
# Uso:  pip install pyinstaller pywebview   &&   python build.py
# Salida:  dist/DialogueTranslator[.exe]
#
# Elige el separador de --add-data según el SO (';' en Windows, ':' en Unix) y
# empaqueta translator.html dentro del binario (app.py lo lee vía _MEIPASS).

import os
import sys

try:
    import PyInstaller.__main__ as pyi
except ImportError:
    sys.exit("Falta PyInstaller. Instala con:  pip install pyinstaller")

HERE = os.path.dirname(os.path.abspath(__file__))
SEP = ";" if os.name == "nt" else ":"

pyi.run([
    os.path.join(HERE, "app.py"),
    "--onefile",
    "--windowed",
    "--name", "DialogueTranslator",
    "--add-data", os.path.join(HERE, "translator.html") + SEP + ".",
    "--distpath", os.path.join(HERE, "dist"),
    "--workpath", os.path.join(HERE, "build"),
    "--specpath", HERE,
    "--noconfirm",
])
