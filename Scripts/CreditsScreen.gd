extends Control
class_name CreditsScreen

# ============================================================
# CREDITS SCREEN — Fire Emblem GBA Style
# ============================================================
# Pantalla de créditos con scroll vertical automático, paleta
# y tipografía inspiradas en FE6/FE7/FE8 (Sacred Stones).
#
# Características:
#  - Scroll suave ascendente (los créditos suben desde abajo)
#  - Encabezado fijo con título del juego
#  - Decoración lateral (pilares dorados estilo GBA)
#  - Paleta GBA: fondo azul profundo, dorado FE, blanco perla
#  - Velocidad ajustable en runtime (mantén A para acelerar x4)
#  - Skip con B / ESC tras un breve fade
#  - Fade in / Fade out
#  - Hold final con fade a negro (fiel al wait 6000 del LT original)
# ============================================================

# ----------------------- CONFIG -----------------------------

# Paleta GBA Fire Emblem (FE7/FE8 inspired)
const COLOR_BG_TOP        := Color(0.04, 0.05, 0.12, 1.0)   # Azul muy oscuro
const COLOR_BG_BOTTOM     := Color(0.10, 0.08, 0.20, 1.0)   # Púrpura oscuro
const COLOR_VIGNETTE      := Color(0.0, 0.0, 0.0, 0.55)
const COLOR_TITLE         := Color(1.00, 0.86, 0.40, 1.0)   # Dorado FE
const COLOR_HEADER        := Color(1.00, 0.78, 0.20, 1.0)   # Dorado más saturado
const COLOR_SUBHEADER     := Color(0.98, 0.95, 0.70, 1.0)   # Crema
const COLOR_TEXT          := Color(0.96, 0.96, 0.92, 1.0)   # Blanco perla
const COLOR_DIM           := Color(0.70, 0.70, 0.78, 1.0)
const COLOR_OUTLINE       := Color(0.0, 0.0, 0.0, 1.0)
const COLOR_PILLAR        := Color(0.78, 0.62, 0.22, 1.0)   # Bronce/oro oscuro
const COLOR_PILLAR_LIGHT  := Color(1.00, 0.86, 0.40, 1.0)
const COLOR_DIVIDER       := Color(1.00, 0.86, 0.40, 0.55)

# Velocidad de scroll en píxeles por segundo
const SCROLL_SPEED_NORMAL := 35.0
const SCROLL_SPEED_FAST   := 140.0   # Mantener A (ui_accept) para acelerar
const FADE_IN_TIME        := 0.6
const FADE_OUT_TIME       := 0.5
const END_HOLD_TIME       := 6.0     # Pausa final tras los créditos (matches original wait 6000)

# Tamaños de tipo (estilo GBA-ish: pequeño, legible, con outline)
const SIZE_TITLE      := 38
const SIZE_HEADER     := 24
const SIZE_SUBHEADER  := 20
const SIZE_TEXT       := 18
const SIZE_GRID       := 15    # Más pequeño para listas masivas de la comunidad
const SIZE_TABLE      := 16    # Tabla 3 columnas (asset/work/name)
const NAMES_PER_LINE  := 2     # Máximo de autores por línea en columna name de tabla
const SIZE_END        := 56
const OUTLINE_PX      := 4

# Layout
const PILLAR_WIDTH    := 28
const CONTENT_MAX_W   := 700    # Ancho del bloque de créditos (más amplio para grids)
const SECTION_GAP     := 36
const LINE_GAP        := 6

# ----------------------- ESTADO -----------------------------

var _scroll_node: Control
var _scroll_offset: float = 0.0
var _content_height: float = 0.0
var _viewport_height: float = 0.0
var _running: bool = false
var _ending: bool = false
var _fade_rect: ColorRect
var _bg_gradient: ColorRect
var _header_panel: Panel
var _end_label: Label = null

# Credits content. Edit freely — `type` controls the style.
# Valid types:
#   "header"     — gold section title
#   "subheader"  — cream-colored secondary line
#   "text"       — body line
#   "spacer"     — vertical space (uses `size`)
#   "divider"    — gold horizontal divider with diamonds
#   "grid"       — multi-column list (`names`: [], `columns`: int default 3)
#
# Faithful to the structure of the original LT-Maker global_Credits.json,
# adapted to Godot 4 stack and SirAxelloid1460 handle.
var credits_data: Array = [
	# ---------- TEASER (matches the original "MORE YET TO COME") ----------
	{ "type": "spacer", "size": 200 },
	{ "type": "header", "text": "MORE YET TO COME" },
	{ "type": "spacer", "size": 200 },
	{ "type": "divider" },
	{ "type": "spacer", "size": 60 },

	# ---------- AUTHORSHIP (matches original order) ----------
	{ "type": "header", "text": "A REMAKE BY" },
	{ "type": "subheader", "text": "SirAxelloid1460" },
	{ "type": "spacer", "size": SECTION_GAP },

	{ "type": "header", "text": "LEX TALIONIS ENGINE BY" },
	{ "type": "subheader", "text": "rainlash" },
	{ "type": "spacer", "size": SECTION_GAP * 2 },

	{ "type": "divider" },
	{ "type": "spacer", "size": 40 },

	# ---------- PROGRAMMING (LT ENGINE) ----------
	# Contribuyentes del motor Lex Talionis (Python/Pygame).
	{ "type": "header", "text": "PROGRAMMING (LT)" },
	{ "type": "spacer", "size": 12 },
	{ "type": "grid", "columns": 3, "names": [
		"rainlash", "mag", "KD",
		"Beccarte", "TheeBill", "LordTweed",
		"ZessDynamite", "Klokinator", "Nemid",
		"Legendary Super Shaggy", "Lorwyn Boi"
	] },
	{ "type": "spacer", "size": SECTION_GAP },

	# ---------- PROGRAMMING (GODOT PORT) ----------
	# Port y desarrollo del remake en Godot 4.
	{ "type": "header", "text": "PROGRAMMING (GODOT)" },
	{ "type": "spacer", "size": 12 },
	{ "type": "grid", "columns": 2, "names": [
		"SirAxelloid1460", "Claude (Anthropic)"
	] },
	{ "type": "spacer", "size": SECTION_GAP },

	# ---------- TESTING ----------
	{ "type": "header", "text": "TESTING" },
	{ "type": "text", "text": "SirAxelloid1460" },
	{ "type": "spacer", "size": SECTION_GAP },

	# ---------- MAP DESIGN ----------
	{ "type": "header", "text": "MAP DESIGN" },
	{ "type": "text", "text": "TheArkiterK" },
	{ "type": "text", "text": "SirAxelloid1460" },
	{ "type": "spacer", "size": SECTION_GAP },

	# ---------- INFORMATION RESOURCES ----------
	{ "type": "header", "text": "INFORMATION RESOURCES" },
	{ "type": "text", "text": "Serenes Forest" },
	{ "type": "text", "text": "Fire Emblem Wiki" },
	{ "type": "text", "text": "LordGlenn" },
	{ "type": "spacer", "size": SECTION_GAP },

	{ "type": "divider" },
	{ "type": "spacer", "size": 40 },

	# ---------- MAP SPRITES & CUSTOM CLASS CARDS (52 contributors) ----------
	{ "type": "header", "text": "MAP SPRITES & CUSTOM CLASS CARDS" },
	{ "type": "spacer", "size": 16 },
	{ "type": "grid", "columns": 4, "names": [
		"Serenes Forest", "FEUniverse", "SirAxelloid1460", "Lexou",
		"Jirbytaylor", "RobertFPY", "flasuban", "Tordo45",
		"IS", "DerTheVaporeon", "Pikmin1211", "Hypergammaspaces",
		"L95", "Someone Unknown", "FEGirls", "CamusZekeSirius",
		"Rexacuse", "Peerless", "Alusq", "WarPath",
		"Yangfly Master", "Cath", "Chad", "Rasdel",
		"Agro", "Yggdra", "Aruka", "Kenpuhu",
		"Smug_mug", "BatimaTheBat", "Jeorge Reds", "Cipher",
		"Lee", "Sephie", "Eldrich Abomination", "MeatofJustice",
		"Leif", "Nuramon", "Its_Just_Jay", "SamirPlayz",
		"N426", "Mikey_Seregon", "StreetHero", "Blood",
		"Huichelaar", "Seal", "Mobile21", "Team SALVAGED",
		"Teraspark"
	] },
	{ "type": "spacer", "size": SECTION_GAP },

	# ---------- ADDITIONAL SPRITING RESOURCES ----------
	{ "type": "header", "text": "ADDITIONAL SPRITING RESOURCES" },
	{ "type": "text", "text": "FEUniverse" },
	{ "type": "spacer", "size": SECTION_GAP },

	# ---------- CUSTOM ITEM SPRITES ----------
	{ "type": "header", "text": "CUSTOM ITEM SPRITES" },
	{ "type": "text", "text": "SirAxelloid1460" },
	{ "type": "text", "text": "FEUniverse" },
	{ "type": "spacer", "size": SECTION_GAP },

	{ "type": "divider" },
	{ "type": "spacer", "size": 40 },

	# ---------- PORTRAIT DESIGN (32 contributors) ----------
	{ "type": "header", "text": "PORTRAIT DESIGN" },
	{ "type": "spacer", "size": 16 },
	{ "type": "grid", "columns": 3, "names": [
		"SirAxelloid1460", "Treasure Artwork Compilation", "Melia",
		"TheBlindArcher", "Nayr", "BoneSethMan",
		"Vampire Elf", "Aeorys Kirru", "Blackavar",
		"TheeBill", "Renoud", "Blade",
		"Atey", "Nobody", "flyingace24",
		"Dalsin", "MageKnight404", "Jeigan",
		"Leo Valkirye", "SquareRootOfPi", "Miss Tama",
		"Kai Shinen", "Arcfalchion", "Zelkami",
		"NoetherianRing", "Ruby", "Sterling Glovner",
		"Vilkalizer", "Wasdye", "Obsidian Daddy",
		"TBA", "Vyland"
	] },
	{ "type": "spacer", "size": SECTION_GAP },

	{ "type": "divider" },
	{ "type": "spacer", "size": 40 },

	# ---------- CUSTOM COMBAT ANIMATIONS (table: asset / work / artist) ----------
	# Estructura: [asset, work, name]
	#   - asset = "" → fila pertenece al mismo asset que la anterior (agrupación visual)
	#   - work  = qué versión / variante (Vanilla, Sword, repalette, etc.)
	#   - name  = autor del trabajo
	{ "type": "header", "text": "CUSTOM COMBAT ANIMATIONS" },
	{ "type": "spacer", "size": 16 },
	{ "type": "table", "rows": [
		["Dancer", "Sword",     "Circleseverywhere, Sirkinite31"],

		["Warrior", "Handaxe",  "Yerek"],

		["Swordfighter", "Shiva",           "Leo_Link, Tsushi, Iscaneus"],
		["",             "Troude",          "Leo_Link, UltraFenix"],
		["",             "Female Pants",    "CelestiaHeart"],

		["SwordMaster", "Shiva, Troude",  "Seliost1"],
		["",            "Mareeta",        "RedBean, Jj09, UltraFenix"],
		["",            "Female Pants",   "Seliost1"],

		["Soldier", "Original", "AstraLunaSol"],

		["Ballista", "Repalette", "Pushwall"],

		["Sniper", "Jamke",                    "ltranc, Pushwall"],
		["",       "Tanya",                    "NamelessX"],
		["",       "Febail, Ronan, Asaello",   "Greentea, HeroDW"],
		["",       "Generics",                 "Meteor, Nuramon, Swain, Temp"],
		["",       "Brigit",                   "IS, ShadowAllyX"],

		["Sage", "Ishtar",                       "L95, Brendor"],
		["",     "Sara, Julia, Linoan",          "Yerek"],
		["",     "Generics",                     "Aruka, Kenpuhu, Levin64, HyperGammaSpaces"],
		["",     "Ced, Asbel, Hawk, Homer",      "Greentea, DerTheVaporeon"],
		["",     "Arvis (Young), Lewys",         "Faolin"],

		["Thief", "Lara, Patty",   "Pikmin1211, Maiser6, Skitty, GabrielKnight"],
		["",      "Daisy",         "Eldritch Abomination, GabrielKnight, Skitty, Mikey Séregon"],
		["",      "Dew, Lifis",    "RedBean"],

		["Rogue", "Lara, Patty, Daisy",  "Leo_Link, Epicer, Kanto Emblem, Sable Mage"],
		["",      "Dew, Lifis",          "Leo_Link, Epicer, Kanto Emblem"],
		["",      "Generic Female",      "Pikmin1211, Maiser6, Ukelele, SD9k, Temp, Black Mage, Wan, Sme"],

		["Queen", "Original",  "TytheBub"],
		["",      "Staff",     "Enthusiasm"],

		["Dark Prince", "Fixed", "Shin19"],

		["Lord Knight", "Seliph, Sigurd", "Obsidian Daddy, ZoramineFae"],

		["Prince", "Leif", "Obsidian Daddy, Jj09"],

		["Lord", "Animation", "UltraFenix"],
		["",     "Still",     "Jeorge_Reds"],

		["Princess", "Staff", "Lisandra_Brave"],

		["Loptyr Mage", "Rip", "(Unknown)", { "name": { "italic": true, "dim": true } }],

		["Lightpriestress", "Staff", "Teraspark"],

		["Priest(ress)", "Short Hair Female",  "BatimaTheBat, Fiuke Bnuy"],
		["",             "Safy",               "HeroDW"],
		["",             "Sleuf",              "Flasuban, Eldritch Abomination"],
		["",             "Male Repalette",     "Vilkalizer"],

		["High Priest(ress)", "Animation", "MrNight48"],
		["",                  "Fixed",     "DerTheVaporeon"],

		["Hero", "Holyn, Skasaher, Dalvin", "Greentea, Seliost1"],
		["",     "Machyua, Creidne",        "WarPath, Red Bean"],
		["",     "Generics",                "Flasuban, Nuramon, Sax-Marine, Itranc"],

		["Mercenary", "Female", "Russell Clark, Orihara_Saki"],
		["",          "Male",   "Alusq, Maiser6"],

		["Pirate", "Animation", "DerTheVaporeon"],

		["Berserker", "Handaxe", "Yerek"],

		["Mage", "Generics Fixed",   "Shin19"],
		["",     "Short Hair Male",  "Omega Zero"],
		["",     "Tailtiu",          "Yerek"],
		["",     "Miranda",          "Leo_Link, L95"],
		["",     "Arthur",           "Shin19, Saint Rubenio"],

		["Bard", "Male", "Flasuban"],

		["Bandit / Mtn. Thief", "Original", "Flasuban"],

		["Barbarian", "HeadBand, Metal Bracers", "RRSKAI"],

		["Duke Knight", "Animation",  "Leo_Link"],
		["",            "Script",     "Enjin"],
		["",            "Helmetless", "UltraFenix"],

		["Great Knight", "Animation", "Leo_Link"],
		["",             "Script",    "Jj09, UltraFenix, Vyland, apolo15"],

		["Forrest Knight", "Animation", "Leo_Link, Pikmin1211"],

		["Paladin", "Female Staff", "Primefusion"],

		["Bow Knight", "Original", "Pikmin1211, Maiser6"],

		["Archer Knight", "Original",  "eCut"],
		["",              "Repalette", "Pikmin1211, Maiser6"],

		["Master Knight", "Original", "tatata"],

		["Axe Knight", "Animation", "Leo_Link"],
		["",           "Script",    "Pushwall"],

		["Lance Knight", "Animation", "Leo_Link"],
		["",             "Script",    "Jj09"],

		["Free Knight", "Animation", "Leo_Link"],
		["",            "Script",    "Pushwall"],

		["Cavalier", "Original", "Team SALVAGED"],

		["Mage Knight", "Original",                       "Aruka"],
		["",            "Magic, Staff, Modifications",    "DatonDemand"],
		["",            "Script",                         "Vyland"],

		["Pegasus Rider", "Animation", "Redbean"],
		["",              "Script",    "Seliost1"],

		["Pegasus Knight", "Animation, Repalette", "Flasuban"],
		["",               "Fixed",                "UltraFenix"],

		["Falcon Knight", "Original", "Dinar"],
		["",              "Staff",    "CelestiaHeart"],

		["Dragon Rider", "Sword", "Rawr776"],

		["Dragon Master", "Animation", "Nuramon"],

		["Archer", "Generics",                          "Pushwall"],
		["",       "Jamke, Febail, Ronan, Asaello",     "DerTheVaporeon"],
		["",       "Tanya",                             "NamelessX"],

		["Fighter", "Osian",        "YellowToadstool"],
		["",        "Animation",    "Leo_Link"],
		["",        "Color Fixes",  "Pushwall, UltraFenix"],

		["Baron", "Animation", "Leo_Link, Nuramon, Iscaneus, The_Big_Dededester"],
		["",      "Handaxe",   "UltraFenix"],

		["Emperor", "Animation",              "Nuramon"],
		["",        "Handaxe, Magic, Staff",  "UltraFenix"],

		["Armour", "Base",               "Iscaneus"],
		["",       "Animation, Script",  "Nuramon, Jeorge Reds"],

		["General", "Shield",            "TheBlindArcher, DerTheVaporeon, Nuramon"],
		["",        "Sword",             "The_Big_Dededester"],
		["",        "Magic",             "DerTheVaporeon"],
		["",        "Bow",               "tatata"],
		["",        "Chainless Lance",   "Pushwall, Knabepicer"],

		["Mage Fighter", "Female", "St Jack"],
		["",             "Male",   "St Jack, The_Big_Dededester, Dolkar, CranJam"],

		["Dark Mage", "Generics, Salem", "BatimaTheBat, Leo_Link"],

		["Dark Bishop", "Magic", "SHYUTERz, Blademaster"],
		["",            "Staff", "Orihara_Saki"],

		["Bishop", "Magic", "Marlon0024, Asael, Jj09, Huichelaar"],
		["",       "Staff", "Marlon0024, Asael"],

		["Global", "Repalette", "SirAxelloid1460"],
	] },
	{ "type": "spacer", "size": SECTION_GAP },

	{ "type": "divider" },
	{ "type": "spacer", "size": 40 },

	# ---------- WRITING & TRANSLATIONS ----------
	{ "type": "header", "text": "ENGLISH WRITING & TRANSLATIONS" },
	{ "type": "text", "text": "Project Naga" },
	{ "type": "text", "text": "SirAxelloid1460" },
	{ "type": "spacer", "size": SECTION_GAP },

	# ---------- MUSIC ----------
	{ "type": "header", "text": "MUSIC" },
	{ "type": "subheader", "text": "FE4 OST" },
	{ "type": "spacer", "size": 8 },
	{ "type": "text", "text": "© Nintendo / Intelligent Systems" },
	{ "type": "spacer", "size": SECTION_GAP },

	# ---------- TOOLS (both stacks) ----------
	{ "type": "header", "text": "BUILT WITH" },
	{ "type": "subheader", "text": "Godot Engine 4  ·  GDScript" },
	{ "type": "spacer", "size": SECTION_GAP },

	{ "type": "header", "text": "ORIGINAL LT TOOLING" },
	{ "type": "spacer", "size": 12 },
	{ "type": "grid", "columns": 3, "names": [
		"Python", "Pygame", "GIMP",
		"Audacity", "Freemake Video Converter 4.0.0", "Sublime Text Editor",
		"IDLE"
	] },
	{ "type": "spacer", "size": SECTION_GAP * 2 },

	{ "type": "divider" },
	{ "type": "spacer", "size": 50 },

	# ---------- DISCLAIMER ----------
	{ "type": "header", "text": "DISCLAIMER" },
	{ "type": "spacer", "size": 16 },
	{ "type": "subheader", "text": "Many assets are copyrighted or trademarked" },
	{ "type": "subheader", "text": "by Nintendo and their respective owners." },
	{ "type": "spacer", "size": 18 },
	{ "type": "text", "text": "This Fire Emblem 4 / FE5 remake" },
	{ "type": "text", "text": "is a non-profit fangame, released for free," },
	{ "type": "text", "text": "developed using Godot 4 and based on the" },
	{ "type": "text", "text": "Lex Talionis engine (Python / Pygame)." },
	{ "type": "spacer", "size": SECTION_GAP * 2 },

	{ "type": "divider" },
	{ "type": "spacer", "size": 50 },

	# ---------- SPECIAL THANKS (personal, named) ----------
	{ "type": "header", "text": "SPECIAL THANKS TO" },
	{ "type": "spacer", "size": 24 },
	{ "type": "subheader", "text": "Beccarte" },
	{ "type": "text", "text": "for tolerating my constant 'Help!' cries" },
	{ "type": "text", "text": "and being such a tremendous programmer" },
	{ "type": "spacer", "size": 32 },
	{ "type": "subheader", "text": "Vyland" },
	{ "type": "text", "text": "for his constant help with the mouth" },
	{ "type": "text", "text": "and blinking animations" },
	{ "type": "spacer", "size": SECTION_GAP * 2 },

	{ "type": "divider" },
	{ "type": "spacer", "size": 60 },

	# ---------- CLOSING ----------
	{ "type": "header", "text": "THANKS FOR HAVING PLAYED" },
	{ "type": "spacer", "size": 12 },
	{ "type": "subheader", "text": "— — — — — — — — — — — — — — —" },
	{ "type": "spacer", "size": 80 },

	{ "type": "text", "text": "© 2020 — 2027  SirAxelloid1460" },
	{ "type": "spacer", "size": 120 },
]

# ----------------------- SEÑALES ---------------------------

signal credits_finished

# ============================================================
# CONSTRUCCIÓN
# ============================================================

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_background()
	_build_pillars()
	_build_header()
	_build_scroll_content()
	_build_fade_rect()
	_build_hint()
	# Empezamos invisibles para fundido de entrada
	modulate.a = 0.0


func _build_background() -> void:
	# Degradado vertical pintado con shader simple (azul -> púrpura)
	_bg_gradient = ColorRect.new()
	_bg_gradient.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg_gradient.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var sh := Shader.new()
	sh.code = """
	shader_type canvas_item;
	uniform vec4 color_top : source_color;
	uniform vec4 color_bottom : source_color;
	uniform vec4 vignette_color : source_color;
	void fragment() {
		vec4 base = mix(color_top, color_bottom, UV.y);
		// Viñeta suave en las esquinas
		float d = distance(UV, vec2(0.5, 0.5));
		float v = smoothstep(0.45, 0.95, d);
		base.rgb = mix(base.rgb, vignette_color.rgb, v * vignette_color.a);
		COLOR = base;
	}
	"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("color_top", COLOR_BG_TOP)
	mat.set_shader_parameter("color_bottom", COLOR_BG_BOTTOM)
	mat.set_shader_parameter("vignette_color", COLOR_VIGNETTE)
	_bg_gradient.material = mat
	add_child(_bg_gradient)


func _build_pillars() -> void:
	# Pilares dorados a izquierda y derecha (decoración estilo GBA)
	var left := _make_pillar()
	left.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	left.offset_right = PILLAR_WIDTH
	add_child(left)

	var right := _make_pillar()
	right.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	right.offset_left = -PILLAR_WIDTH
	add_child(right)


func _make_pillar() -> Control:
	var pillar := Control.new()
	pillar.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var bar := ColorRect.new()
	bar.color = COLOR_PILLAR
	bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pillar.add_child(bar)

	var highlight := ColorRect.new()
	highlight.color = COLOR_PILLAR_LIGHT
	highlight.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	highlight.offset_right = 4
	pillar.add_child(highlight)

	var shadow := ColorRect.new()
	shadow.color = Color(0, 0, 0, 0.45)
	shadow.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	shadow.offset_left = -4
	pillar.add_child(shadow)
	return pillar


func _build_header() -> void:
	# Cabecera fija arriba con el título del juego
	_header_panel = Panel.new()
	_header_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_header_panel.offset_left = PILLAR_WIDTH
	_header_panel.offset_right = -PILLAR_WIDTH
	_header_panel.offset_bottom = 70

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.16, 0.85)
	sb.border_color = COLOR_TITLE
	sb.border_width_bottom = 2
	sb.border_width_top = 0
	sb.border_width_left = 0
	sb.border_width_right = 0
	_header_panel.add_theme_stylebox_override("panel", sb)
	add_child(_header_panel)

	var title := Label.new()
	title.text = "C R E D I T S"
	title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", SIZE_TITLE)
	title.add_theme_color_override("font_color", COLOR_TITLE)
	title.add_theme_color_override("font_outline_color", COLOR_OUTLINE)
	title.add_theme_constant_override("outline_size", OUTLINE_PX + 2)
	_header_panel.add_child(title)


func _build_scroll_content() -> void:
	# Contenedor que se desplaza hacia arriba
	_scroll_node = Control.new()
	_scroll_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Limitamos al área entre pilares y bajo el header
	_scroll_node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scroll_node.offset_left = PILLAR_WIDTH
	_scroll_node.offset_right = -PILLAR_WIDTH
	_scroll_node.offset_top = 70
	_scroll_node.offset_bottom = -50
	_scroll_node.clip_contents = true
	add_child(_scroll_node)

	# Crear todas las líneas dentro de un VBoxContainer manual
	# (no usamos VBox porque queremos animar la posición Y a mano)
	var container := Control.new()
	container.name = "Lines"
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scroll_node.add_child(container)

	var y := 0.0
	for entry in credits_data:
		var t: String = entry.get("type", "text")
		match t:
			"spacer":
				y += float(entry.get("size", LINE_GAP))
			"divider":
				var div := _make_divider()
				div.position = Vector2(0, y + 8)
				container.add_child(div)
				y += 24
			"grid":
				var grid := _make_grid(entry)
				grid.position = Vector2(0, y)
				container.add_child(grid)
				# OJO: get_minimum_size() devuelve 0 justo tras fijar
				# custom_minimum_size (recálculo diferido) → usamos el valor
				# explícito que ya conocemos, así no se solapa la sección siguiente.
				y += grid.custom_minimum_size.y + LINE_GAP
			"table":
				var tbl := _make_table(entry)
				tbl.position = Vector2(0, y)
				container.add_child(tbl)
				y += tbl.custom_minimum_size.y + LINE_GAP
			_:
				var lbl := _make_label(entry)
				lbl.position = Vector2(0, y)
				container.add_child(lbl)
				y += lbl.get_minimum_size().y + LINE_GAP

	_content_height = y
	# Hacemos que el container se centre horizontalmente y tenga ancho de pista
	container.custom_minimum_size = Vector2(_get_inner_width(), _content_height)
	container.size = Vector2(_get_inner_width(), _content_height)
	# Lo posicionamos justo bajo el área visible para que entre desde abajo
	container.position = Vector2(0, _scroll_node.size.y)

	_scroll_node.resized.connect(_on_scroll_resized)


func _make_label(entry: Dictionary) -> Label:
	var lbl := Label.new()
	lbl.text = entry.get("text", "")
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_color_override("font_outline_color", COLOR_OUTLINE)
	lbl.add_theme_constant_override("outline_size", OUTLINE_PX)

	var t: String = entry.get("type", "text")
	match t:
		"header":
			lbl.add_theme_font_size_override("font_size", SIZE_HEADER)
			lbl.add_theme_color_override("font_color", COLOR_HEADER)
		"subheader":
			lbl.add_theme_font_size_override("font_size", SIZE_SUBHEADER)
			lbl.add_theme_color_override("font_color", COLOR_SUBHEADER)
		_:
			lbl.add_theme_font_size_override("font_size", SIZE_TEXT)
			lbl.add_theme_color_override("font_color", COLOR_TEXT)

	# Ancho fijo = área interior entre pilares; el texto va CENTER dentro de él,
	# así queda centrado en pantalla. Sin anclas TOP_WIDE: mezclarlas con
	# position/size manuales descuadraba todo el bloque hacia la derecha.
	var w := _get_inner_width()
	lbl.custom_minimum_size = Vector2(w, 0)
	lbl.size = Vector2(w, 0)
	return lbl


func _make_grid(entry: Dictionary) -> Control:
	# Grid multi-columna para listas largas de contributors.
	# entry = { "type": "grid", "names": [...], "columns": 3 (opcional) }
	var names: Array = entry.get("names", [])
	var columns: int = int(entry.get("columns", 3))
	if columns < 1:
		columns = 1

	var inner_w := _get_inner_width()
	var col_width := inner_w / columns
	var cell_height := SIZE_TEXT + 8

	var wrapper := Control.new()
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var rows: int = int(ceil(float(names.size()) / float(columns)))
	wrapper.custom_minimum_size = Vector2(inner_w, rows * cell_height)
	wrapper.size = Vector2(inner_w, rows * cell_height)

	for i in range(names.size()):
		var col: int = i % columns
		var row: int = i / columns
		var lbl := Label.new()
		lbl.text = String(names[i]).strip_edges()
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.clip_text = true
		lbl.add_theme_font_size_override("font_size", SIZE_GRID)
		lbl.add_theme_color_override("font_color", COLOR_TEXT)
		lbl.add_theme_color_override("font_outline_color", COLOR_OUTLINE)
		lbl.add_theme_constant_override("outline_size", OUTLINE_PX - 1)
		lbl.position = Vector2(col * col_width, row * cell_height)
		lbl.size = Vector2(col_width, cell_height)
		wrapper.add_child(lbl)

	return wrapper


func _make_table(entry: Dictionary) -> Control:
	# Tabla de 3 columnas (asset / work / name) con celdas vacías cuando
	# el asset se omite (agrupación visual). Cuando una celda `name`
	# contiene más de NAMES_PER_LINE autores (separados por comas),
	# se reparten en múltiples sub-filas; asset y work solo aparecen
	# en la primera sub-fila del bloque.
	#
	# entry = {
	#   "type": "table",
	#   "rows": [ [asset, work, name], ... ]   # asset puede ser "" para agrupar
	# }
	var rows_data: Array = entry.get("rows", [])
	var inner_w := _get_inner_width()

	# Reparto de anchos: asset 38%, work 27%, name 35%
	var col_w_asset := inner_w * 0.38
	var col_w_work  := inner_w * 0.27
	var col_w_name  := inner_w * 0.35
	var col_x_asset := 0.0
	var col_x_work  := col_w_asset
	var col_x_name  := col_w_asset + col_w_work
	var line_height := SIZE_TABLE + 10
	var pad_left := 12.0

	var wrapper := Control.new()
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrapper.size = Vector2(inner_w, 0)

	# Pre-calcular cuántas líneas usa cada fila (según el número de autores)
	# para saber el alto total y poder posicionar correctamente.
	#
	# Formato de fila:
	#   [asset, work, name]                       — fila simple
	#   [asset, work, name, styles_dict]          — fila con estilos por columna.
	#                                                styles_dict = {
	#                                                  "asset": {italic:bool, dim:bool},
	#                                                  "work":  {...},
	#                                                  "name":  {...}
	#                                                }
	var y := 0.0
	for row in rows_data:
		var asset_text: String = String(row[0]) if row.size() > 0 else ""
		var work_text:  String = String(row[1]) if row.size() > 1 else ""
		var name_text:  String = String(row[2]) if row.size() > 2 else ""
		var styles: Dictionary = row[3] if row.size() > 3 and row[3] is Dictionary else {}
		var st_asset: Dictionary = styles.get("asset", {})
		var st_work:  Dictionary = styles.get("work",  {})
		var st_name:  Dictionary = styles.get("name",  {})

		# Trocear ambas columnas multi-valor en chunks de NAMES_PER_LINE
		var work_lines: Array[String] = _wrap_csv(work_text, NAMES_PER_LINE)
		var name_lines: Array[String] = _wrap_csv(name_text, NAMES_PER_LINE)

		# El bloque es tan alto como la columna más larga
		var lines_count: int = max(work_lines.size(), name_lines.size())
		if lines_count < 1:
			lines_count = 1
		var block_height := lines_count * line_height

		# ASSET solo en la primera línea del bloque — alineado a la DERECHA
		# (con un hueco de pad_left antes de la columna "work").
		_add_table_cell(wrapper, asset_text,
			Vector2(col_x_asset, y),
			Vector2(col_w_asset - pad_left, line_height),
			COLOR_HEADER, st_asset, HORIZONTAL_ALIGNMENT_RIGHT)

		# WORK: una celda por sub-línea
		for li in range(work_lines.size()):
			_add_table_cell(wrapper, work_lines[li],
				Vector2(col_x_work, y + li * line_height),
				Vector2(col_w_work, line_height),
				COLOR_SUBHEADER, st_work)

		# NAME: una celda por sub-línea
		for li in range(name_lines.size()):
			_add_table_cell(wrapper, name_lines[li],
				Vector2(col_x_name, y + li * line_height),
				Vector2(col_w_name, line_height),
				COLOR_TEXT, st_name)

		y += block_height

	wrapper.custom_minimum_size = Vector2(inner_w, y)
	return wrapper


func _wrap_csv(text: String, per_line: int) -> Array[String]:
	# Trocea una cadena CSV ("a, b, c, d") en líneas de hasta `per_line` items
	# separadas por ", ". Devuelve [""] si no hay items.
	var items: Array = []
	for piece in text.split(","):
		var clean: String = piece.strip_edges()
		if clean != "":
			items.append(clean)
	var out: Array[String] = []
	if items.is_empty():
		out.append("")
		return out
	var idx := 0
	while idx < items.size():
		var chunk := items.slice(idx, idx + per_line)
		out.append(", ".join(chunk))
		idx += per_line
	return out


func _add_table_cell(parent: Control, text: String, pos: Vector2, sz: Vector2, color: Color, style: Dictionary = {}, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	# style admite estos flags opcionales:
	#   "italic": bool   — sesga el texto horizontalmente para simular cursiva
	#   "dim":    bool   — atenúa el color (útil para etiquetas tipo "Unknown")
	var final_text: String = text
	var final_color: Color = color

	if style.get("dim", false):
		# Reduce saturación + alfa para que destaque menos sin desaparecer
		final_color = COLOR_DIM

	var lbl := Label.new()
	lbl.text = final_text
	lbl.horizontal_alignment = align
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.clip_text = true
	lbl.add_theme_font_size_override("font_size", SIZE_TABLE)
	lbl.add_theme_color_override("font_color", final_color)
	lbl.add_theme_color_override("font_outline_color", COLOR_OUTLINE)
	lbl.add_theme_constant_override("outline_size", OUTLINE_PX - 1)
	lbl.position = pos
	lbl.size = sz

	if style.get("italic", false):
		# Godot 4 no expone "italic" directo en Label sin una fuente cursiva.
		# Simulamos cursiva con un FontVariation que aplica sesgo horizontal.
		var fv := FontVariation.new()
		var theme_font := lbl.get_theme_font("font")
		if theme_font:
			fv.base_font = theme_font
		# Un sesgo de ~0.18 da una inclinación cercana a la cursiva clásica.
		# (FontVariation.transform sesga el texto al renderizar.)
		fv.variation_transform = Transform2D(Vector2(1, 0), Vector2(0.18, 1), Vector2(0, 0))
		lbl.add_theme_font_override("font", fv)

	parent.add_child(lbl)


func _make_divider() -> Control:
	# Divisor dorado: línea con dos rombos en los extremos
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var w := _get_inner_width()
	c.custom_minimum_size = Vector2(w, 8)
	c.size = Vector2(w, 8)

	var line := ColorRect.new()
	line.color = COLOR_DIVIDER
	line.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	line.offset_left = 80
	line.offset_right = -80
	line.offset_top = 3
	line.offset_bottom = 5
	c.add_child(line)

	# Rombos con dos rectángulos rotados
	var diamond_l := ColorRect.new()
	diamond_l.color = COLOR_TITLE
	diamond_l.size = Vector2(8, 8)
	diamond_l.pivot_offset = Vector2(4, 4)
	diamond_l.rotation_degrees = 45
	diamond_l.position = Vector2(70, 0)
	c.add_child(diamond_l)

	var diamond_r := ColorRect.new()
	diamond_r.color = COLOR_TITLE
	diamond_r.size = Vector2(8, 8)
	diamond_r.pivot_offset = Vector2(4, 4)
	diamond_r.rotation_degrees = 45
	c.add_child(diamond_r)
	# Anclaje a la derecha
	diamond_r.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	diamond_r.offset_left = -78
	diamond_r.offset_right = -70
	diamond_r.offset_top = 0
	diamond_r.offset_bottom = 8
	return c


func _build_fade_rect() -> void:
	_fade_rect = ColorRect.new()
	_fade_rect.color = Color.BLACK
	_fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.modulate.a = 1.0
	add_child(_fade_rect)


func _build_hint() -> void:
	# Pequeño texto en la esquina inferior con las teclas
	var hint := Label.new()
	hint.text = "A: Fast Forward     B / Esc: Skip"
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", COLOR_DIM)
	hint.add_theme_color_override("font_outline_color", COLOR_OUTLINE)
	hint.add_theme_constant_override("outline_size", 3)
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.offset_top = -28
	hint.offset_bottom = -8
	add_child(hint)


# ============================================================
# CICLO DE VIDA
# ============================================================

func show_credits() -> void:
	"""Muestra los créditos. Llamar tras add_child()."""
	# Fade in
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, FADE_IN_TIME)
	tween.parallel().tween_property(_fade_rect, "modulate:a", 0.0, FADE_IN_TIME)
	await tween.finished
	_running = true


func _process(delta: float) -> void:
	if not _running or _ending:
		return

	var speed := SCROLL_SPEED_NORMAL
	if Input.is_action_pressed("ui_accept"):
		speed = SCROLL_SPEED_FAST

	_scroll_offset += speed * delta

	var lines: Control = _scroll_node.get_node_or_null("Lines")
	if lines:
		lines.position.y = _scroll_node.size.y - _scroll_offset

	# ¿Llegamos al final?
	if _scroll_offset >= _content_height + _scroll_node.size.y:
		_running = false
		_show_the_end()


func _input(event: InputEvent) -> void:
	if not _running and not _ending:
		return
	if event.is_action_pressed("ui_cancel"):
		_skip_credits()


# ============================================================
# CIERRE
# ============================================================

func _show_the_end() -> void:
	# Faithful to the original LT-Maker behaviour: after "THANKS FOR HAVING PLAYED"
	# (which is the last header inside the scroll), the original waits 6s and ends.
	# We do the same: hold the screen for 6s then fade to black.
	_ending = true
	var tween := create_tween()
	tween.tween_interval(END_HOLD_TIME)
	tween.tween_property(_fade_rect, "modulate:a", 1.0, FADE_OUT_TIME)
	await tween.finished
	_finish()


func _skip_credits() -> void:
	if _ending:
		return
	_ending = true
	_running = false
	var tween := create_tween()
	tween.tween_property(_fade_rect, "modulate:a", 1.0, FADE_OUT_TIME)
	await tween.finished
	_finish()


func _finish() -> void:
	credits_finished.emit()
	queue_free()


# ============================================================
# UTILIDADES
# ============================================================

func _get_inner_width() -> float:
	# Anchura disponible entre pilares. Usamos el tamaño del VIEWPORT (fiable en
	# _ready, a diferencia de self.size que aún es 0 durante la construcción).
	var w := get_viewport_rect().size.x - PILLAR_WIDTH * 2
	if w <= 0:
		w = 904  # Fallback (960 - 2*28)
	return w


func _on_scroll_resized() -> void:
	var lines: Control = _scroll_node.get_node_or_null("Lines")
	if lines:
		lines.size.x = _scroll_node.size.x
		# Re-centramos labels: ya están con anchor TOP_WIDE, así que ok.
