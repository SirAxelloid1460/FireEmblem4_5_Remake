# Dialogue Translator — app de escritorio (offline)

Versión offline del traductor de diálogos. Es el **mismo** `translator.html` que
la versión web, mostrado en una ventana nativa con **pywebview** y con diálogos
de archivo nativos (abrir/guardar). Una sola fuente para web y escritorio.

## Ejecutar desde el código

```
pip install pywebview
python app.py
```

En **Linux** puede hacer falta un backend de webview:
`pip install 'pywebview[qt]'` (PyQt/PySide) o `pip install 'pywebview[gtk]'`
(GTK/WebKit2). En **Windows** usa el WebView2 de Edge (ya viene en Win10/11);
en **macOS** usa el WebKit del sistema (sin extras).

## Empaquetar un ejecutable (PyInstaller)

```
pip install pyinstaller pywebview
python build.py
```

Genera `dist/DialogueTranslator` (o `DialogueTranslator.exe` en Windows), un
**único archivo** con `translator.html` incrustado. Hay que compilar en cada SO
para su binario (PyInstaller no hace *cross-compile*).

Equivalente manual:
```
# Windows (separador ';')
pyinstaller --onefile --windowed --name DialogueTranslator --add-data "translator.html;." app.py
# Linux / macOS (separador ':')
pyinstaller --onefile --windowed --name DialogueTranslator --add-data "translator.html:." app.py
```

## Uso

1. **Importar fuente** → elige el scene `_en.json` (p. ej.
   `docs/examples/dialogue_format/prologue_fe5.scene.json`).
2. Traduce cada línea hablada (las acotaciones `@…` son contexto, no se tocan).
3. **Exportar** → guarda `nombre.<idioma>.json`. `Ctrl/Cmd+S` también exporta.
4. **Retomar** → reabre un `<idioma>.json` a medias para continuar.

El progreso se autoguarda en el almacenamiento local de la ventana (por archivo).

## Archivos

- `translator.html` — la UI (idéntica a la web; el puente pywebview es inerte en
  navegador, así que este HTML también abre suelto en un navegador).
- `app.py` — lanzador pywebview + puente de archivos.
- `build.py` — empaqueta con PyInstaller (separador de `--add-data` según SO).
- `requirements.txt` — pywebview + pyinstaller.
