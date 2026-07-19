extends Node
# ============================================================
# InputConfig — esquema de teclado remapeable (autoload)
# ============================================================
# Centraliza el mapa de teclas del juego, con los 10 botones de una Game Boy
# Advance como referencia. Cada botón se corresponde con una acción de InputMap:
#
#   D-Pad ↑↓←→ → ui_up / ui_down / ui_left / ui_right
#   A (Confirmar) → ui_accept        B (Cancelar) → ui_cancel
#   L → ui_page_left                 R → ui_page_right
#   Start (Menú)  → ui_start         Select (Info) → ui_select
#
# Las acciones ui_* base ya las provee el motor; ui_page_left/right y ui_start
# se crean aquí si faltan. Al arrancar se aplican los remapeos guardados en
# user://settings.cfg  ([controls] <accion>=<keycode>).  El menú ControlsMenu
# lee/escribe a través de esta API (list / key_label / rebind / reset).
#
# Solo se tocan los eventos de TECLADO de cada acción (los de mando/ratón, si
# los hubiera, se conservan).
# ============================================================

const CFG := "user://settings.cfg"
const SECTION := "controls"

# Orden = disposición GBA (izq→der; el D-Pad arriba/abajo va en el centro). Cada
# entrada: action (InputMap), name (rótulo mostrado en la pantalla de la GBA) y
# def (keycode por defecto si la acción no tiene ninguna tecla asignada).
const ACTIONS := [
	{ "action": "ui_up",         "name": "Move Up",  "def": KEY_UP },
	{ "action": "ui_down",       "name": "Move Down", "def": KEY_DOWN },
	{ "action": "ui_left",       "name": "Move Left", "def": KEY_LEFT },
	{ "action": "ui_right",      "name": "Move Right", "def": KEY_RIGHT },
	{ "action": "ui_accept",     "name": "Confirm",  "def": KEY_ENTER },
	{ "action": "ui_cancel",     "name": "Cancel",   "def": KEY_ESCAPE },
	{ "action": "ui_page_left",  "name": "L Button", "def": KEY_Q },
	{ "action": "ui_page_right", "name": "R Button", "def": KEY_E },
	{ "action": "ui_start",      "name": "Menu",     "def": KEY_SPACE },
	{ "action": "ui_select",     "name": "Info",     "def": KEY_BACKSPACE },
]


func _ready() -> void:
	var cfg := ConfigFile.new()
	cfg.load(CFG)   # puede no existir aún; se ignora el error
	for spec in ACTIONS:
		var action: StringName = StringName(spec["action"])
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		# Sin remapeo guardado → se impone SIEMPRE la tecla por defecto de este
		# esquema (aunque el motor ya asignara otra, p. ej. ui_select trae Space
		# de fábrica). Así el mapa es determinista y sin teclas duplicadas.
		var saved: int = int(cfg.get_value(SECTION, str(spec["action"]), 0))
		_set_key(action, saved if saved != 0 else int(spec["def"]))


# ── API pública ───────────────────────────────────────────────────────────────

## Lista ordenada de acciones remapeables (copia de ACTIONS).
func actions() -> Array:
	return ACTIONS.duplicate(true)

## Rótulo legible de la tecla actualmente asignada a una acción ("Enter", "Esc"…).
func key_label(action: String) -> String:
	var kc := _first_key(StringName(action))
	if kc == 0:
		return "—"
	return _keycode_label(kc)

## Keycode actual de la primera tecla de la acción (0 si ninguna).
func current_key(action: String) -> int:
	return _first_key(StringName(action))

## Reasigna la tecla de una acción y lo persiste. Devuelve false si la tecla ya
## está en uso por OTRA acción de la lista (conflicto).
func rebind(action: String, keycode: int) -> bool:
	if keycode == 0:
		return false
	for spec in ACTIONS:
		if str(spec["action"]) != action and _first_key(StringName(spec["action"])) == keycode:
			return false
	_set_key(StringName(action), keycode)
	_save(action, keycode)
	return true

## Restaura todas las teclas a sus valores por defecto y limpia el guardado.
func reset_defaults() -> void:
	var cfg := ConfigFile.new()
	cfg.load(CFG)
	for spec in ACTIONS:
		_set_key(StringName(spec["action"]), int(spec["def"]))
		cfg.erase_section_key(SECTION, str(spec["action"]))
	cfg.save(CFG)


# ── Internos ──────────────────────────────────────────────────────────────────

func _first_key(action: StringName) -> int:
	if not InputMap.has_action(action):
		return 0
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			var k := ev as InputEventKey
			return k.physical_keycode if k.physical_keycode != 0 else k.keycode
	return 0

## Deja la acción con EXACTAMENTE una tecla (physical_keycode), preservando
## cualquier otro tipo de evento (mando, etc.).
func _set_key(action: StringName, keycode: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			InputMap.action_erase_event(action, ev)
	var k := InputEventKey.new()
	k.physical_keycode = keycode
	InputMap.action_add_event(action, k)

func _save(action: String, keycode: int) -> void:
	var cfg := ConfigFile.new()
	cfg.load(CFG)
	cfg.set_value(SECTION, action, keycode)
	cfg.save(CFG)

func _keycode_label(keycode: int) -> String:
	var s := OS.get_keycode_string(keycode)
	return s if s != "" else "Key %d" % keycode
