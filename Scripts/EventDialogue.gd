# EventDialogue.gd
# ============================================================
# Presentación de diálogo de EVENTOS (comando `speak`) + escenario de retratos,
# estilo FE, por código (sin depender de ninguna .tscn — patrón fiable del
# proyecto). Lo instancia EventSystem sobre un CanvasLayer.
#
# Escenario de retratos: add/remove/move/change_portrait colocan retratos por
# slot (Left/Right/FarRight/… o coordenada nativa "x,y"); `speak` resalta al
# hablante (los demás se atenúan). Retrato = cara principal 96×80 de la hoja LT
# (144×112). Los del lado derecho se voltean para mirar al centro.
#
# La caja de texto tiene efecto máquina de escribir con "skip" y espera input.

extends Control
class_name EventDialogue

const SERIF_FONT := "res://assets/fonts/IMFellFrenchCanonSC-Regular.ttf"
const COLOR_GOLD_DIM := Color(0.70, 0.60, 0.30, 1.0)
const COLOR_TEXT     := Color(0.96, 0.95, 0.90, 1.0)
const COLOR_OUTLINE  := Color(0.0, 0.0, 0.0, 1.0)
const CHAR_TIME := 0.028   # s por carácter

# Hoja de retrato LT: cara principal 96×80 arriba-izquierda. Frames de parpadeo
# (hoja de 144 ancho, ver app/events/event_portrait.py): se pegan en el
# `blinking_offset` del retrato (data/general/portrait_offsets.json).
const FACE_REGION := Rect2(0, 0, 96, 80)
const FULLBLINK := Rect2(96, 80, 32, 16)   # ojos cerrados  → CloseEyes
const HALFBLINK := Rect2(96, 64, 32, 16)   # ojos entrecerrados → HalfCloseEyes
const PORTRAIT_SCALE := 3
const DIM := Color(0.55, 0.55, 0.55, 1.0)   # retratos no-hablantes

var _panel: PanelContainer
var _name_label: Label
var _text_label: RichTextLabel
var _cont: Label
var _stage: Control              # contenedor de retratos (detrás de la caja)
var _portraits: Dictionary = {}  # nid -> TextureRect

var _typing := false
var _waiting := false
var _skip := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()


func _build() -> void:
	var font = load(AssetSet.p(SERIF_FONT))

	# Escenario de retratos (debajo de la caja).
	_stage = Control.new()
	_stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)

	# Caja inferior.
	_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.06, 0.12, 0.96)
	sb.set_border_width_all(3)
	sb.border_color = COLOR_GOLD_DIM
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 28
	sb.content_margin_right = 28
	sb.content_margin_top = 16
	sb.content_margin_bottom = 16
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_panel.offset_left = 60
	_panel.offset_right = -60
	_panel.offset_top = -220
	_panel.offset_bottom = -40
	add_child(_panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	_panel.add_child(vb)

	_name_label = Label.new()
	if font != null:
		_name_label.add_theme_font_override("font", font)
	_name_label.add_theme_font_size_override("font_size", 30)
	_name_label.add_theme_color_override("font_color", COLOR_GOLD_DIM)
	_name_label.add_theme_color_override("font_outline_color", COLOR_OUTLINE)
	_name_label.add_theme_constant_override("outline_size", 4)
	vb.add_child(_name_label)

	_text_label = RichTextLabel.new()
	_text_label.bbcode_enabled = false
	_text_label.fit_content = true
	_text_label.scroll_active = false
	_text_label.custom_minimum_size = Vector2(0, 96)
	if font != null:
		_text_label.add_theme_font_override("normal_font", font)
	_text_label.add_theme_font_size_override("normal_font_size", 28)
	_text_label.add_theme_color_override("default_color", COLOR_TEXT)
	vb.add_child(_text_label)

	_cont = Label.new()
	_cont.text = "▼"
	_cont.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_cont.add_theme_color_override("font_color", COLOR_GOLD_DIM)
	_cont.visible = false
	vb.add_child(_cont)

	visible = false


# ── Escenario de retratos ────────────────────────────────────────────────────

## Coloca (o mueve) el retrato de `nid` en la posición `pos`. tex = hoja LT.
func add_portrait(nid: String, pos: String, tex: Texture2D,
		blink_offset: Vector2 = Vector2(-1, -1)) -> void:
	if tex == null:
		return
	var rect: TextureRect = _portraits.get(nid)
	if rect == null or not is_instance_valid(rect):
		rect = TextureRect.new()
		rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# La cara mide 96×80 (nativo); escalamos el nodo ×PORTRAIT_SCALE. Con el
		# stretch por defecto (KEEP) el TextureRect se dibuja a tamaño de textura,
		# y el `scale` del nodo lo agranda a 288×240 sin deformar.
		rect.scale = Vector2(PORTRAIT_SCALE, PORTRAIT_SCALE)
		_stage.add_child(rect)
		_portraits[nid] = rect
		# Overlay de parpadeo (hijo → hereda escala/posición del retrato).
		var blink := TextureRect.new()
		blink.name = "Blink"
		blink.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		blink.mouse_filter = Control.MOUSE_FILTER_IGNORE
		blink.visible = false
		rect.add_child(blink)
	_apply_face(rect, tex)
	rect.set_meta("sheet", tex)
	if blink_offset.x >= 0.0:
		rect.set_meta("blink_offset", blink_offset)
	_place(rect, pos)
	visible = true


## expression(nid, expr): estado de ojos del retrato en escena.
##   CloseEyes → parpadeo cerrado; HalfCloseEyes → entrecerrado; otro → abierto.
func set_expression(nid: String, expr: String) -> void:
	var rect: TextureRect = _portraits.get(nid)
	if rect == null or not is_instance_valid(rect):
		return
	var blink := rect.get_node_or_null("Blink") as TextureRect
	if blink == null:
		return
	if (expr == "CloseEyes" or expr == "HalfCloseEyes") \
			and rect.has_meta("sheet") and rect.has_meta("blink_offset"):
		var at := AtlasTexture.new()
		at.atlas = rect.get_meta("sheet")
		at.region = FULLBLINK if expr == "CloseEyes" else HALFBLINK
		blink.texture = at
		blink.position = rect.get_meta("blink_offset")   # px nativos (padre escala)
		blink.visible = true
	else:
		blink.visible = false


func remove_portrait(nid: String) -> void:
	var rect: TextureRect = _portraits.get(nid)
	if rect != null and is_instance_valid(rect):
		rect.queue_free()
	_portraits.erase(nid)


func move_portrait(nid: String, pos: String) -> void:
	var rect: TextureRect = _portraits.get(nid)
	if rect != null and is_instance_valid(rect):
		_place(rect, pos)


## Cambia la hoja del retrato de `nid` (change_portrait) manteniendo su posición.
func change_portrait(nid: String, tex: Texture2D) -> void:
	var rect: TextureRect = _portraits.get(nid)
	if rect != null and is_instance_valid(rect) and tex != null:
		_apply_face(rect, tex)


func clear_portraits() -> void:
	for nid in _portraits.keys():
		var rect: TextureRect = _portraits[nid]
		if rect != null and is_instance_valid(rect):
			rect.queue_free()
	_portraits.clear()


func _apply_face(rect: TextureRect, tex: Texture2D) -> void:
	var at := AtlasTexture.new()
	at.atlas = tex
	at.region = FACE_REGION
	rect.texture = at


## Traduce un slot a posición de pantalla (+ flip si mira al centro desde la
## derecha). Slots nombrados o coordenada nativa "x,y" (base 240×160).
func _place(rect: TextureRect, pos: String) -> void:
	var vp := get_viewport_rect().size
	var pw := 96 * PORTRAIT_SCALE
	var ph := 80 * PORTRAIT_SCALE
	var y := vp.y - 220.0 - ph + 40.0   # justo por encima de la caja
	var x := 48.0
	var flip := false
	match pos:
		"FarLeft":
			x = 8
		"Left":
			x = 48
		"MidLeft":
			x = vp.x * 0.28
		"MidRight":
			x = vp.x * 0.72 - pw
			flip = true
		"Right":
			x = vp.x - pw - 48
			flip = true
		"FarRight":
			x = vp.x - pw - 8
			flip = true
		_:
			# Coordenada nativa "x,y" (240×160) → escala a pantalla (best effort).
			var parts := str(pos).split(",")
			if parts.size() == 2 and str(parts[0]).strip_edges().is_valid_int() \
					and str(parts[1]).strip_edges().is_valid_int():
				x = float(int(str(parts[0]).strip_edges())) / 240.0 * vp.x
				y = float(int(str(parts[1]).strip_edges())) / 160.0 * vp.y
	rect.position = Vector2(x, y)
	rect.flip_h = flip


## Resalta al hablante (los demás se atenúan). Si no está en escena y hay tex de
## respaldo, lo añade a la izquierda para que igual se vea una cara.
func _highlight(nid: String, fallback: Texture2D) -> void:
	if not _portraits.has(nid) and fallback != null:
		add_portrait(nid, "Left", fallback)
	for k in _portraits.keys():
		var rect: TextureRect = _portraits[k]
		if rect != null and is_instance_valid(rect):
			rect.modulate = Color.WHITE if k == nid else DIM


# ── Diálogo ──────────────────────────────────────────────────────────────────

## Muestra una línea del hablante `nid` y espera al jugador.
func play_line(nid: String, speaker_name: String, text: String,
		fallback: Texture2D = null) -> void:
	visible = true
	_name_label.text = speaker_name
	_highlight(nid, fallback)
	_text_label.text = ""
	# {w} marca una pausa intramedio: el texto se va acumulando en la misma caja
	# y en cada {w} se espera input antes de seguir escribiendo.
	var parts := text.split("{w}")
	for i in range(parts.size()):
		var seg := _clean_seg(parts[i])
		if seg == "" and i == parts.size() - 1:
			break   # {w} final: no añadir una espera vacía extra
		if seg != "":
			await _type_append(seg)
		_cont.visible = true
		await _wait_for_input()
		_cont.visible = false


## Fin de la secuencia del evento: oculta la caja y limpia los retratos.
func finish() -> void:
	visible = false
	clear_portraits()


## Escribe `seg` (máquina de escribir) APPENDeando al texto ya visible.
func _type_append(seg: String) -> void:
	_typing = true
	_skip = false
	_cont.visible = false
	var start := _text_label.text
	for i in range(seg.length()):
		if _skip:
			_text_label.text = start + seg
			break
		_text_label.text += seg[i]
		await get_tree().create_timer(CHAR_TIME).timeout
	_typing = false


func _wait_for_input() -> void:
	_waiting = true
	while _waiting:
		await get_tree().process_frame


func _unhandled_input(event: InputEvent) -> void:
	var confirm = event.is_action_pressed("ui_accept") or (event is InputEventMouseButton \
			and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
	if not confirm:
		return
	if _typing:
		_skip = true          # primer input: completa el texto
		get_viewport().set_input_as_handled()
	elif _waiting:
		_waiting = false      # segundo input: avanza
		get_viewport().set_input_as_handled()


## Limpia un segmento de texto LT SIN recortar bordes (para poder concatenar
## segmentos separados por {w} sin perder espacios): {br}/{sub_break} → salto de
## línea; el resto de tokens {..} (colores, estilos) se eliminan.
func _clean_seg(s: String) -> String:
	s = s.replace("{br}", "\n").replace("{sub_break}", "\n").replace("{clear}", "\n")
	var re := RegEx.new()
	re.compile("\\{[^}]*\\}")
	return re.sub(s, "", true)
