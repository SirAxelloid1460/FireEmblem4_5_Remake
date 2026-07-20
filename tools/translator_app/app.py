#!/usr/bin/env python3
# app.py — versión de escritorio (offline) del traductor de diálogos.
# =============================================================================
# Muestra el MISMO translator.html en una ventana nativa vía pywebview, y le da
# un puente de archivos nativo (abrir/guardar) para que funcione sin navegador.
# El HTML detecta pywebview (window.pywebview.api) y usa este puente; en un
# navegador normal usa la E/S del navegador. Una sola fuente para web y desktop.
#
# Ejecutar desde el código:   pip install pywebview   &&   python app.py
# Empaquetar .exe/binario:    pip install pyinstaller  &&   python build.py
# =============================================================================

import os
import sys

try:
    import webview  # pywebview
except ImportError:
    sys.exit("Falta pywebview. Instala con:  pip install pywebview\n"
             "(en Linux quizá necesites  pip install 'pywebview[qt]'  o  '[gtk]')")

WINDOW = None


def resource_path(rel):
    """Ruta a un recurso, tanto en dev como dentro del bundle de PyInstaller."""
    base = getattr(sys, "_MEIPASS", os.path.dirname(os.path.abspath(__file__)))
    return os.path.join(base, rel)


class Api:
    """Puente JS<->Python: diálogos de archivo nativos."""

    def open_file(self):
        res = WINDOW.create_file_dialog(
            webview.OPEN_DIALOG, allow_multiple=False,
            file_types=("JSON (*.json)", "All files (*.*)"))
        if not res:
            return None
        path = res[0] if isinstance(res, (list, tuple)) else res
        try:
            with open(path, "r", encoding="utf-8") as f:
                content = f.read()
        except OSError:
            return None
        return {"name": os.path.basename(path), "content": content}

    def save_file(self, name, content):
        path = WINDOW.create_file_dialog(
            webview.SAVE_DIALOG, save_filename=name,
            file_types=("JSON (*.json)", "All files (*.*)"))
        if not path:
            return False
        path = path if isinstance(path, str) else path[0]
        try:
            with open(path, "w", encoding="utf-8") as f:
                f.write(content)
        except OSError:
            return False
        return os.path.basename(path)


DOC = "<!doctype html><html><head><meta charset='utf-8'></head><body>{}</body></html>"


def main():
    global WINDOW
    with open(resource_path("translator.html"), encoding="utf-8") as f:
        html = DOC.format(f.read())
    WINDOW = webview.create_window(
        "Dialogue Translator — FE4/FE5 Remake",
        html=html, js_api=Api(), width=1180, height=820, min_size=(760, 560))
    webview.start()


if __name__ == "__main__":
    main()
