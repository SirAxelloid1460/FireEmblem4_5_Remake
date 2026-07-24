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
const COLOR_BG_TOP        := Color(0.0, 0.0, 0.0, 1.0)      # Negro
const COLOR_BG_BOTTOM     := Color(0.0, 0.0, 0.0, 1.0)      # Negro
const COLOR_VIGNETTE      := Color(0.0, 0.0, 0.0, 0.55)
const COLOR_TITLE         := Color(1.0, 1.0, 1.0, 1.0)      # Blanco
const COLOR_HEADER        := Color(1.0, 1.0, 1.0, 1.0)      # Blanco
const COLOR_SUBHEADER     := Color(1.0, 1.0, 1.0, 1.0)      # Blanco
const COLOR_TEXT          := Color(1.0, 1.0, 1.0, 1.0)      # Blanco
const COLOR_DIM           := Color(0.70, 0.70, 0.70, 1.0)   # Gris (atenuado, p. ej. "(Unknown)")
const COLOR_OUTLINE       := Color(0.0, 0.0, 0.0, 1.0)
const COLOR_PILLAR        := Color(0.0, 0.0, 0.0, 1.0)      # Negro
const COLOR_PILLAR_LIGHT  := Color(0.0, 0.0, 0.0, 1.0)      # Negro
const COLOR_DIVIDER       := Color(1.0, 1.0, 1.0, 0.55)     # Blanco (línea del divisor)

# Velocidad de scroll en píxeles por segundo
const SCROLL_SPEED_NORMAL := 70.0
const SCROLL_SPEED_FAST   := SCROLL_SPEED_NORMAL * 4.0   # Mantener A (ui_accept): x4
const FADE_IN_TIME        := 0.6
const FADE_OUT_TIME       := 0.5
const END_HOLD_TIME       := 6.0     # Pausa final tras los créditos (matches original wait 6000)

# Tamaños de tipo (estilo GBA-ish: pequeño, legible, con outline)
const SIZE_TITLE      := 24    # credit_title nativo 8 (se escala ~3x)
const SIZE_HEADER     := 34
const SIZE_SUBHEADER  := 28
const SIZE_TEXT       := 26
const SIZE_GRID       := 22
const SIZE_TABLE      := 24    # Tabla asset/work/name
const NAMES_PER_LINE  := 2     # Máximo de autores por línea en columna name de tabla
const SIZE_END        := 56
const OUTLINE_PX      := 4
const CREDIT_FONT       := "res://assets/fonts/bmp/credit.fnt"          # cuerpo, GBA/Original (bitmap)
const CREDIT_TITLE_FONT := "res://assets/fonts/bmp/credit_title.fnt"    # título, GBA/Original (bitmap)
const CREDIT_FONT_HD    := "res://assets/fonts/Fire_Emblem_Heroes_Font.ttf"  # HD: TTF FE Heroes (todo)

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
var _credit_font_res = null            # sprite-font LT de créditos (cacheada)


## Fuente del CUERPO de créditos, cacheada. GBA/Original: credit.fnt (bitmap).
## HD: la TTF de FE Heroes (p() no traduce .fnt→.ttf, así que se elige a mano).
func _credit_font():
	if _credit_font_res == null:
		var path := CREDIT_FONT
		if AssetSet.current() == "HD":
			path = CREDIT_FONT_HD
		var p := AssetSet.p(path)
		if ResourceLoader.exists(p):
			_credit_font_res = load(p)
	return _credit_font_res

var _credit_title_font_res = null
## Fuente del TÍTULO ("C R E D I T S"), cacheada. GBA/Original: credit_title.fnt.
## HD: la misma TTF de FE Heroes que el cuerpo (HD solo tiene esa fuente).
func _credit_title_font():
	if _credit_title_font_res == null:
		var path := CREDIT_TITLE_FONT
		if AssetSet.current() == "HD":
			path = CREDIT_FONT_HD
		var p := AssetSet.p(path)
		if ResourceLoader.exists(p):
			_credit_title_font_res = load(p)
	return _credit_title_font_res
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
	{ "type": "spacer", "size": 8 },
	{ "type": "text", "text": "(check my patreon for updates)", "font_size": 22 },
	{ "type": "spacer", "size": 200 },
	{ "type": "divider" },
	{ "type": "spacer", "size": 60 },

	# ---------- AUTHORSHIP (matches original order) ----------
	{ "type": "header", "text": "A REMAKE BY" },
	{ "type": "subheader", "text": "SirAxelloid1460 with the help of\nClaude Code AI and The Fire Emblem Fan Community" },
	{ "type": "spacer", "size": SECTION_GAP * 2 },

	{ "type": "divider" },
	{ "type": "spacer", "size": 40 },

	# ---------- PROGRAMMING (dividido: port Godot / versión LT original) ----------
	{ "type": "header", "text": "PROGRAMMING (GODOT VERSION)", "key": "CRPROGRAMMINGGODOT" },
	{ "type": "spacer", "size": 12 },
	{ "type": "table", "columns": 3, "fracs": [0.05, 0.43, 0.04, 0.43, 0.05], "cols": [1, 2, 3], "mono": true, "rows": [
		["SirAxelloid1460", "&", "Claude Code AI", { "work": { "size": 30 } }],
	] },
	{ "type": "spacer", "size": SECTION_GAP },

	{ "type": "header", "text": "PROGRAMMING (LEX TALIONIS VERSION)", "key": "CRPROGRAMMINGLT" },
	{ "type": "spacer", "size": 12 },
	{ "type": "table", "columns": 3, "fracs": [0.05, 0.30, 0.30, 0.30, 0.05], "cols": [1, 2, 3], "mono": true, "rows": [
		["rainlash",     "Beccarte",               "LordTweed"],
		["mag",          "Legendary Super Shaggy", "KD"],
		["ZessDynamite", "Klokinator",             "Nemid"],
		["TheeBill",     "",                       "Lorwyn Boi"],
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
	{ "type": "text", "text": "Fire Emblem Wars Of Dragons" },
	{ "type": "text", "text": "Fire Emblem Fandom" },
	{ "type": "text", "text": "Fire Emblem Fan Community" },
	{ "type": "spacer", "size": SECTION_GAP },

	{ "type": "divider" },
	{ "type": "spacer", "size": 40 },

	# ---------- MAP SPRITES & CUSTOM CLASS CARDS (52 contributors) ----------
	{ "type": "header", "text": "MAP SPRITES & CUSTOM CLASS CARDS", "key": "CRMAPSPRITES" },
	{ "type": "spacer", "size": 16 },
	# --- Créditos comunitarios del grid original (comentados de momento) ---
	# { "type": "grid", "columns": 4, "names": [
	#	"Serenes Forest", "FEUniverse", "SirAxelloid1460", "Lexou",
	#	"Jirbytaylor", "RobertFPY", "flasuban", "Tordo45",
	#	"DerTheVaporeon", "Pikmin1211", "HyperGammaSpaces (HGS)", "L95",
	#	"Someone Unknown", "FEGirls", "CamusZekeSirius", "Rexacuse",
	#	"Peerless", "Alusq", "WarPath", "Yangfly Master",
	#	"Cath", "Chad", "Rasdel", "Agro",
	#	"Yggdra", "Aruka", "Kenpuhu", "Smug_mug",
	#	"BatimaTheBat", "Jeorge_Reds", "Cipher", "Lee",
	#	"Sephie", "Eldritch Abomination", "MeatofJustice", "Leif",
	#	"Nuramon", "Its_Just_Jay", "SamirPlayz", "N426",
	#	"Mikey_Seregon", "StreetHero", "Blood", "Huichelaar",
	#	"Seal", "Mobile21", "Team SALVAGED", "Teraspark"
	# ] },
	{ "type": "table", "columns": 3, "fracs": [0.05, 0.30, 0.30, 0.30, 0.05], "cols": [1, 2, 3], "rows": [
		["Original FE4 & FE5", "Ripping & Formatting", "Stephano, Zane"],
	] },
	{ "type": "spacer", "size": SECTION_GAP },

	# ---------- ADDITIONAL SPRITING RESOURCES ----------
	{ "type": "header", "text": "ADDITIONAL SPRITING RESOURCES" },
	{ "type": "text", "text": "FEUniverse" },
	{ "type": "spacer", "size": SECTION_GAP },

	# ---------- CUSTOM ITEM SPRITES ----------
	{ "type": "header", "text": "CUSTOM ITEM SPRITES" },
	# --- Créditos anteriores (comentados de momento) ---
	# { "type": "text", "text": "SirAxelloid1460" },
	# { "type": "text", "text": "FEUniverse" },
	{ "type": "spacer", "size": 16 },
	{ "type": "table", "columns": 3, "fracs": [0.05, 0.30, 0.30, 0.30, 0.05], "cols": [1, 2, 3], "rows": [
		["HD", "FEH Weapons", "Kazkirigiri"],
	] },
	{ "type": "spacer", "size": SECTION_GAP },

	{ "type": "divider" },
	{ "type": "spacer", "size": 40 },

	# ---------- PORTRAIT DESIGN (32 contributors) ----------
	{ "type": "header", "text": "PORTRAIT DESIGN" },
	{ "type": "spacer", "size": 16 },
	{ "type": "table", "columns": 3, "fracs": [0.05, 0.30, 0.30, 0.30, 0.05], "cols": [1, 2, 3], "mono": true, "rows": [
		["SirAxelloid1460", "Treasure Artwork Compilation", "Melia"],
		["TheBlindArcher",  "Nayr",                         "BoneSethMan"],
		["Vampire Elf",     "Aeorys Kirru",                 "Blackavar"],
		["TheeBill",        "Renoud",                       "Blade"],
		["Atey",            "Nobody",                       "flyingace24"],
		["Dalsin",          "MageKnight404",                "Jeigan"],
		["Leo Valkirye",    "SquareRootOfPi",               "Miss Tama"],
		["Kai Shinen",      "Arcfalchion",                  "Zelkami"],
		["NoetherianRing",  "Ruby",                         "Sterling Glovner"],
		["Vilkalizer",      "Wasdye",                       "Obsidian Daddy"],
		["TBA",             "Vyland",                       ""],
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
		["Archer", "Generics",                          "Pushwall"],
		["",       "Jamke, Febail, Ronan, Asaello",     "DerTheVaporeon"],
		["",       "Tanya",                             "NamelessX"],

		["Archer Knight", "Generics", "eCut, Pikmin1211, Maiser6"],

		["Armour", "Generics", "Iscaneus, Nuramon, Jeorge_Reds"],

		["Axe Knight", "Generic, Lex", "Leo_Link, Pushwall"],

		["Ballista", "Repalette", "Pushwall"],

		["Bandit", "Original", "Flasuban"],

		["Barbarian", "HeadBand, Metal Bracers", "RRSKAI"],

		["Bard", "Generics",      "Flasuban"],
		["",     "Lewyn, Homer",  "Leo_Link, L95, Flasuban"],

		["Baron", "Animation", "Leo_Link, Nuramon, Iscaneus, The_Big_Dededester"],
		["",      "Handaxe, Sword, Lance, Magic",   "UltraFenix"],

		["Berserker", "Handaxe", "Yerek"],

		["Bishop", "Magic", "Marlon0024, Asael, Jj09, Huichelaar"],
		["",       "Staff", "Marlon0024, Asael"],

		["Bow Knight", "Original", "Pikmin1211, Maiser6"],

		["Cavalier", "Original", "Team SALVAGED"],
		["",         "Female",   "Flasuban"],

		["Citizen", "Generics", "Nuramon"],

		["Dancer", "Sword",     "Circleseverywhere, SirKnite31"],

		["Dark Bishop", "Magic", "SHYUTERz, Blademaster"],
		["",            "Staff", "Orihara_Saki"],

		["Dark Mage", "Generics, Salem", "BatimaTheBat, Leo_Link"],

		["Dark Prince", "Generics", "Shin19"],

		["Dragon Master", "Generics", "Nuramon"],

		["Dragon Rider", "Sword", "Rawr776"],

		["Duke Knight", "Animation",  "Leo_Link"],
		["",            "Script",     "Enjin"],
		["",            "Helmetless", "UltraFenix"],

		["Emperor", "Animation",              "Nuramon"],
		["",        "Handaxe, Magic, Staff",  "UltraFenix"],

		["Falcon Knight", "Original", "Dinar"],
		["",              "Staff",    "CelestiaHeart"],

		["Fighter", "Osian",     "YellowToadstool"],
		["",        "Male, DiMaggio",  "Leo_Link, Pushwall, UltraFenix"],
		["",        "Female",    "FEGirls"],
		["",        "Halvan",    "MK404, Glenwing"],
		["",        "Iucharba",  "Waleed, Flasuban"],
		["",        "Gerrard",   "Jey the Count"],

		["Forrest Knight", "Animation", "Leo_Link, Pikmin1211"],

		["Free Knight", "Animation", "Leo_Link"],
		["",            "Script",    "Pushwall"],

		["General", "Shield",            "TheBlindArcher, DerTheVaporeon, Nuramon"],
		["",        "Sword",             "The_Big_Dededester"],
		["",        "Magic",             "DerTheVaporeon"],
		["",        "Bow",               "tatata"],
		["",        "Chainless Lance",   "Pushwall, Knabepicer"],

		["Great Knight", "Animation", "Leo_Link"],
		["",             "Script",    "Jj09, UltraFenix, Vyland, apolo15"],

		["Hero", "Holyn",     "Greentea"],
		["",     "Skasaher",  "Greentea, Seliost1"],
		["",     "Dalvin",    "Nuramon"],
		["",     "Machyua",   "Flasuban, Nuramon, Itranc"],
		["",     "Creidne",   "WarPath, Red Bean"],
		["",     "Generics",  "Pikmin1211, Pushwall, St Jack, Swain, Itranc"],

		["High Priest(ess)", "Generics", "MrNight48, DerTheVaporeon"],

		["Lance Knight", "Animation", "Leo_Link"],
		["",             "Script",    "Jj09"],

		["Lightpriestess", "Staff",           "Teraspark"],
		["",               "Julia, Deirdre",  "GabrielKnight, SirKnite31, Seal, Sacred War"],
		["",               "Linoan, Sara",    "Mikey_Seregon, Aviv"],

		["Loptrian Mage", "Rip", "(Unknown)", { "name": { "italic": true, "dim": true } }],

		["Lord", "Animation", "UltraFenix"],
		["",     "Still",     "Jeorge_Reds"],

		["Lord Knight", "Seliph",  "Obsidian Daddy, ZoramineFae"],
		["",            "Sigurd",  "Caim Van Fang, Seliost1"],

		["Mage", "Generics Fixed",   "Shin19"],
		["",     "Tailtiu",          "Leo_Link, L95"],
		["",     "Linda, Tine",      "Yerek"],
		["",     "Amid",             "Shin19, OmegaZero"],
		["",     "Asbel",            "GabrielKnight"],
		["",     "Azelle",           "Eldritch Abomination"],
		["",     "Miranda",          "Flasuban, RRSKAI"],
		["",     "Arthur",           "TytheBub"],

		["Mage Fighter", "Female, Tailtiu",  "St Jack"],
		["",             "Male",             "St Jack, The_Big_Dededester, Dolkar, CranJam"],
		["",             "Amid",             "Obsidian Daddy, StrudelMuffin, Maximus03, Card, Leo_Link, Feier"],

		["Mage Knight", "Generics",                                                        "Aruka, DatonDemand, Vyland"],
		["",            "Ovo",                                                             "Aruka, Kenpuhu, NamelessX"],
		["",            "Arthur, Azelle, Olwen, Ilios, Kempf, Reinhart, Miranda, Musar",   "BatimaTheBat, UltraFenix, Aruka, Kenpuhu, Seal, Sacred War, Leo_Link"],

		["Master Knight", "Original", "tatata"],

		["Mercenary", "Female",     "Zionzap, Reyk_Retro0337"],
		["",          "Creidne",    "Russell Clark, Orihara_Saki"],
		["",          "Machyua",    "Team SALVAGED, Jey the Count, Pushwall, Citrus"],
		["",          "Holyn",      "Alusq, Maiser6"],
		["",          "Dalvin",     "RRSKAI"],
		["",          "Skasaher",   "Team SALVAGED, UltraFenix"],

		["Paladin", "Female Staff",          "Primefusion"],
		["",        "Ethlyn",                "Greentea, Brober"],
		["",        "Alvar, Evan, Evar",     "Aruka, Kenpuhu, Nuramon"],
		["",        "Amalda, Nanna, Jeanne", "Team SALVAGED, Leo_Link, Flasuban, The_Big_Dededester, CelestiaHeart"],
		["",        "Naoise, Alec",          "Greentea, RobertFPY"],

		["Pegasus Knight", "Generics", "Fiuke Bnuy, Jeorge_Reds"],

		["Pegasus Rider", "Generics", "Flasuban, UltraFenix"],

		["Pirate", "Animation", "DerTheVaporeon"],

		["Priest(ess)", "Short Hair Female",  "BatimaTheBat, Fiuke Bnuy"],
		["",             "Safy",               "HeroDW"],
		["",             "Sleuf",              "Flasuban, Eldritch Abomination"],
		["",             "Male Repalette",     "Vilkalizer"],

		["Prince", "Leif", "Obsidian Daddy, Jj09"],

		["Princess", "Staff", "Lisandra_Brave"],
		["",         "Sword", "RedBean"],

		["Queen", "Generics", "HyperGammaSpaces (HGS), Nuramon, Seliost1"],

		["Rogue", "Lara",   "Leo_Link, TATUTA_CHANG"],
		["",      "Patty",  "Pikmin1211, Maiser6, Ukelele, SD9k, Temp, Black Mage, Wan, Sme"],
		["",      "Lifis",  "Dinar87, Seliost1"],

		["Sage", "Ishtar",                       "L95, Brendor"],
		["",     "Sara, Julia, Linoan",          "Yerek"],
		["",     "Generics",                     "Aruka, Kenpuhu, Levin64, HyperGammaSpaces (HGS)"],
		["",     "Ced, Asbel, Hawk, Homer",      "Greentea, DerTheVaporeon"],
		["",     "Arvis (Young), Lewys",         "Faolin"],

		["Sniper", "Jamke",                    "Itranc, Pushwall"],
		["",       "Tanya",                    "NamelessX"],
		["",       "Febail, Ronan, Asaello",   "Greentea, HeroDW"],
		["",       "Generics",                 "Meteor, Nuramon, Swain, Temp"],
		["",       "Brigit",                   "ShadowAllyX"],

		["Soldier", "Original", "AstraLunaSol"],

		["Swordfighter", "Shiva",           "Leo_Link, Tsushi, Iscaneus"],
		["",             "Troude",          "Leo_Link, UltraFenix"],
		["",             "Larcei",          "Seliost1"],
		["",             "Ayra",            "Greentea, RobertFPY"],
		["",             "Mareeta",         "Maiser6, Alice"],
		["",             "Female",          "Maiser6"],

		["Swordmaster", "Shiva",                        "Solusaeternus, SHYUTERz"],
		["",            "Troude",                       "Greentea, RobertFPY, Itranc, Seliost1"],
		["",            "Mareeta",                      "RedBean, Jj09, UltraFenix"],
		["",            "Eyvel",                        "Seliost1"],
		["",            "Shannan, Shannam",             "Cybaster, Seliost1"],
		["",            "Boyle, Lamia, Simia, Larcei",  "Seliost1"],
		["",            "Ayra",                         "FE7if, BwdYeti, Seliost1"],
		["",            "Female Pants",                 "Seliost1"],

		["Thief", "Lara, Patty, Dew",   "Pikmin1211, Maiser6, Skitty, GabrielKnight"],
		["",      "Daisy",              "Eldritch Abomination, GabrielKnight, Skitty, Mikey_Seregon"],
		["",      "Lifis",              "RedBean"],

		["Warrior", "Handaxe",  "Yerek"],

		["Global", "Repalette", "SirAxelloid1460"],
		] },
	{ "type": "spacer", "size": SECTION_GAP },

	{ "type": "divider" },
	{ "type": "spacer", "size": 40 },

	# ---------- WRITING & TRANSLATIONS ----------
	{ "type": "header", "text": "WRITING & TRANSLATIONS" },
	{ "type": "spacer", "size": 16 },
	{ "type": "table", "columns": 2, "rows": [
		["FE4 English",         "Project Naga, Lil'Nordion, SirAxelloid1460 (Reconciliation)"],
		["FE4 Spanish", "DarkAdvent"],
		["FE4 Partial German", "Sephie & Slomo"],
		["FE5 English",         "Cirosan & Miacis"],
		["FE5 Italian",         "EnDavio"],
		["FE5 Spanish",         "Dark Advent Team (Xabier)"],
		["Missing Translations","Claude Code AI"],
		["Transcription",       "SirAxelloid1460"],
		["GBA Latin fonts",     "LT Engine, FEXP"],
		["GBA Japanese fonts",  "MonadABXY"],
		["HD fonts",            "FE Heroes"],
	] },
	{ "type": "spacer", "size": SECTION_GAP },

	# ---------- MUSIC ----------
	{ "type": "header", "text": "MUSIC" },
	{ "type": "subheader", "text": "FE4 and FE5 OST" },
	{ "type": "spacer", "size": 8 },
	{ "type": "text", "text": "© Nintendo / Intelligent Systems" },
	{ "type": "spacer", "size": SECTION_GAP },

	# ---------- TOOLS (both stacks) ----------
	{ "type": "header", "text": "BUILT WITH" },
	{ "type": "subheader", "text": "Godot Engine 4  ·  GDScript" },
	{ "type": "spacer", "size": SECTION_GAP * 2 },

	{ "type": "divider" },
	{ "type": "spacer", "size": 50 },

	# ---------- DISCLAIMER ----------
	{ "type": "header", "text": "DISCLAIMER" },
	{ "type": "spacer", "size": 16 },
	{ "type": "subheader", "text": "This Fire Emblem 4 and 5 remake is a non-profit fangame and released for free.", "key": "CRDISCLAIMER1", "wrap_frac": 0.66 },
	{ "type": "subheader", "text": "Developed using Godot 4 and Claude Code AI, as well as rainlash's Lex Talionis Engine during the earliest versions of this project.", "key": "CRDISCLAIMER2", "wrap_frac": 0.66 },
	{ "type": "spacer", "size": SECTION_GAP * 2 },

	{ "type": "divider" },
	{ "type": "spacer", "size": 50 },

	# ---------- SPECIAL THANKS (personal, named) ----------
	{ "type": "header", "text": "SPECIAL THANKS TO" },
	{ "type": "spacer", "size": 24 },
	{ "type": "subheader", "text": "Beccarte, Vyland, rainlash and the whole, amazing Fire Emblem Fans Community", "wrap_frac": 0.66 },
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
	sb.bg_color = Color(0.0, 0.0, 0.0, 1.0)   # Opaco: oculta el texto que pasa por debajo
	sb.border_color = COLOR_OUTLINE
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
	var _tf = _credit_title_font()
	if _tf:
		title.add_theme_font_override("font", _tf)
	title.add_theme_font_size_override("font_size", SIZE_TITLE)
	title.add_theme_color_override("font_color", COLOR_TITLE)
	title.add_theme_color_override("font_outline_color", COLOR_OUTLINE)
	# Outline pequeño acorde al tamaño nativo del título (subir junto con SIZE_TITLE)
	title.add_theme_constant_override("outline_size", 1)
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
				# custom_minimum_size (no get_minimum_size, que en un Control base
				# devuelve 0 y no respeta el mínimo → todo se apilaría).
				y += grid.custom_minimum_size.y + LINE_GAP
			"table":
				var tbl := _make_table(entry)
				tbl.position = Vector2(0, y)
				container.add_child(tbl)
				y += tbl.custom_minimum_size.y + LINE_GAP
			_:
				var lbl := _make_label(entry)
				container.add_child(lbl)
				# Vertical por offsets (el horizontal ya lo fija _make_label con
				# anclas 0.5; usar position lo sobreescribiría y descentraría).
				var lh: float = lbl.custom_minimum_size.y
				lbl.offset_top = y
				lbl.offset_bottom = y + lh
				y += lh + LINE_GAP

	_content_height = y
	# Hacemos que el container se centre horizontalmente y tenga ancho de pista
	container.custom_minimum_size = Vector2(0, _content_height)
	container.size = Vector2(_scroll_node.size.x, _content_height)
	# Lo posicionamos justo bajo el área visible para que entre desde abajo
	container.position = Vector2(0, _scroll_node.size.y)

	_scroll_node.resized.connect(_on_scroll_resized)


## Texto localizado de una entrada: si trae "key" usa esa clave; si es un
## "header" (título de sección) deriva la clave del propio texto; el resto
## (nombres propios, herramientas) se deja literal.
func _credit_text(entry: Dictionary) -> String:
	if entry.has("key"):
		return tr(str(entry["key"]))
	var raw: String = str(entry.get("text", ""))
	if str(entry.get("type", "text")) == "header":
		return tr(_credit_key(raw))
	return raw


## Clave de traducción derivada de un título: "MAP DESIGN" → "CRMAPDESIGN".
func _credit_key(t: String) -> String:
	var s := ""
	for c in t.to_upper():
		if (c >= "A" and c <= "Z") or (c >= "0" and c <= "9"):
			s += c
	return "CR" + s


func _make_label(entry: Dictionary) -> Label:
	var lbl := Label.new()
	lbl.text = _credit_text(entry)
	var _cf = _credit_font()
	if _cf:
		lbl.add_theme_font_override("font", _cf)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_color_override("font_outline_color", COLOR_OUTLINE)
	lbl.add_theme_constant_override("outline_size", OUTLINE_PX)

	var t: String = entry.get("type", "text")
	var fs: int = SIZE_TEXT
	match t:
		"header":
			fs = SIZE_HEADER
			lbl.add_theme_color_override("font_color", COLOR_HEADER)
		"subheader":
			fs = SIZE_SUBHEADER
			lbl.add_theme_color_override("font_color", COLOR_SUBHEADER)
		_:
			fs = SIZE_TEXT
			lbl.add_theme_color_override("font_color", COLOR_TEXT)

	# Override opcional de tamaño de fuente por entrada (p. ej. líneas pequeñas)
	if entry.has("font_size"):
		fs = int(entry["font_size"])
	lbl.add_theme_font_size_override("font_size", fs)

	# Ancho de envoltura: por defecto el bloque de créditos (min(CONTENT_MAX_W, inner));
	# si la entrada trae "wrap_frac", se limita a esa fracción del ancho interno
	# (p. ej. 0.66 = 66% de pantalla, usado en DISCLAIMER y SPECIAL THANKS).
	var iw := _get_inner_width()
	var wrap_w: float = iw * float(entry["wrap_frac"]) if entry.has("wrap_frac") else min(float(CONTENT_MAX_W), iw)
	# ALTURA real del texto ya ajustado a wrap_w. Godot no la calcula de forma
	# fiable en get_minimum_size() para autowrap antes del layout, así que la
	# medimos con la fuente (si no, las secciones se solapan por altura a 0).
	var wrap_h: float = float(fs)
	if _cf:
		wrap_h = _cf.get_multiline_string_size(lbl.text, HORIZONTAL_ALIGNMENT_CENTER, wrap_w, fs).y
	# Se fija ancho+alto y se centra por anclas (0.5): el bloque queda centrado
	# sea cual sea el ancho del contenedor, y el auto-ajuste parte a ese ancho.
	lbl.custom_minimum_size = Vector2(wrap_w, wrap_h)
	lbl.anchor_left = 0.5
	lbl.anchor_right = 0.5
	lbl.anchor_top = 0.0
	lbl.anchor_bottom = 0.0
	lbl.offset_left = -wrap_w / 2.0
	lbl.offset_right = wrap_w / 2.0
	lbl.size = Vector2(wrap_w, wrap_h)
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
	wrapper.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var rows: int = int(ceil(float(names.size()) / float(columns)))
	wrapper.custom_minimum_size = Vector2(0, rows * cell_height)

	for i in range(names.size()):
		var col: int = i % columns
		var row: int = i / columns
		var lbl := Label.new()
		lbl.text = String(names[i]).strip_edges()
		var _cf = _credit_font()
		if _cf:
			lbl.add_theme_font_override("font", _cf)
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
	# Tabla de 2 o 3 columnas con celdas vacías cuando la primera columna
	# se omite (agrupación visual). Cuando una celda de texto contiene más
	# de NAMES_PER_LINE items (separados por comas), se reparten en múltiples
	# sub-filas; la primera columna solo aparece en la primera sub-fila.
	#
	# entry = {
	#   "type": "table",
	#   "columns": 3,                          # 2 o 3 (default 3)
	#   "rows": [ [c1, c2, c3?], ... ]         # c1 puede ser "" para agrupar
	# }
	#
	# 3 columnas: asset / work / name (dorado / crema / blanco)
	# 2 columnas: label / value          (dorado / blanco)
	var rows_data: Array = entry.get("rows", [])
	var columns_count: int = int(entry.get("columns", 3))
	if columns_count < 2 or columns_count > 3:
		columns_count = 3
	var inner_w := _get_inner_width()
	var line_height := SIZE_TABLE + 10
	# Geometría de 5 columnas físicas, con columnas espaciadoras vacías (*) que
	# actúan como separadores naturales:
	#   3 columnas (Combat):  Asset | * | Part    | * | Credito
	#   2 columnas (W&T):      *    | Language | * | Credito | *
	# fracs = anchos relativos (suman 1.0). idx_* = índice de la columna física
	# donde va cada contenido (-1 = no aplica).
	var fracs: Array
	var idx_asset: int
	var idx_work: int
	var idx_name: int
	if entry.has("fracs"):
		# Layout a medida: "fracs" = 5 anchos (suman 1.0); "cols" = índices físicos
		# de las columnas de contenido: [asset, work, name] en 3-col, [asset, name]
		# en 2-col. El resto de columnas quedan como separadores vacíos.
		fracs = entry["fracs"]
		var cc: Array = entry.get("cols", ([1, 2, 3] if columns_count == 3 else [1, 3]))
		idx_asset = int(cc[0])
		if columns_count == 3:
			idx_work = int(cc[1])
			idx_name = int(cc[2])
		else:
			idx_work = -1
			idx_name = int(cc[1])
	elif columns_count == 3:
		fracs = [0.30, 0.04, 0.28, 0.04, 0.34]
		idx_asset = 0    # Asset
		idx_work  = 2    # Part
		idx_name  = 4    # Credito
	else:
		fracs = [0.05, 0.43, 0.04, 0.43, 0.05]
		idx_asset = 1    # Language
		idx_work  = -1   # sin columna central de contenido
		idx_name  = 3    # Credito

	# x y ancho (px) de cada columna física, acumulando las fracciones
	var col_x: Array[float] = []
	var col_w: Array[float] = []
	var acc := 0.0
	for fr in fracs:
		col_x.append(acc * inner_w)
		col_w.append(float(fr) * inner_w)
		acc += float(fr)

	# "mono": todas las celdas en color de texto (blanco perla). Para tablas que
	# en realidad son listas de créditos (nombres), no asset/work/name.
	var mono: bool = bool(entry.get("mono", false))
	var c_asset: Color = COLOR_TEXT if mono else COLOR_HEADER
	var c_work: Color = COLOR_TEXT if mono else COLOR_SUBHEADER
	# En tablas mono (listas de créditos) todas las columnas van centradas;
	# en las semánticas se mantiene 1ª derecha / central centrada / última izquierda.
	var a_asset: int = HORIZONTAL_ALIGNMENT_CENTER if mono else HORIZONTAL_ALIGNMENT_RIGHT
	var a_name: int = HORIZONTAL_ALIGNMENT_CENTER if mono else HORIZONTAL_ALIGNMENT_LEFT

	var wrapper := Control.new()
	wrapper.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Pre-calcular cuántas líneas usa cada fila (según el número de autores)
	# para saber el alto total y poder posicionar correctamente.
	#
	# Formato de fila (3 columnas):
	#   [asset, work, name]                       — fila simple
	#   [asset, work, name, styles_dict]          — fila con estilos por columna.
	#
	# Formato de fila (2 columnas):
	#   [label, value]
	#   [label, value, styles_dict]               — styles_dict claves: "asset", "name"
	var y := 0.0
	for row in rows_data:
		var asset_text: String = String(row[0]) if row.size() > 0 else ""
		var work_text: String = ""
		var name_text: String = ""
		var styles: Dictionary = {}

		if columns_count == 3:
			work_text = String(row[1]) if row.size() > 1 else ""
			name_text = String(row[2]) if row.size() > 2 else ""
			styles = row[3] if row.size() > 3 and row[3] is Dictionary else {}
		else:
			# 2 columnas: c2 va directamente a la columna "name" (blanco)
			name_text = String(row[1]) if row.size() > 1 else ""
			styles = row[2] if row.size() > 2 and row[2] is Dictionary else {}

		var st_asset: Dictionary = styles.get("asset", {})
		var st_work:  Dictionary = styles.get("work",  {})
		var st_name:  Dictionary = styles.get("name",  {})

		# Máximo de items por línea: global NAMES_PER_LINE, salvo override por fila
		# ("names_per_line" en el dict de estilos). Útil cuando un crédito lleva "&"
		# y no debe compartir línea con otro (p. ej. "Sephie & Slomo").
		var npl: int = int(styles.get("names_per_line", NAMES_PER_LINE))

		# Trocear columnas multi-valor. WORK: por conteo (npl). NAME (créditos):
		# por conteo Y por ancho — fuerza línea nueva si el texto supera el 90%
		# del ancho de su columna.
		var work_lines: Array[String] = _wrap_csv(work_text, npl) if columns_count == 3 else ([""] as Array[String])
		var name_lines: Array[String] = _wrap_credit(name_text, npl, col_w[idx_name])

		# El bloque es tan alto como la columna más larga
		var lines_count: int = max(work_lines.size(), name_lines.size())
		if lines_count < 1:
			lines_count = 1
		var block_height := lines_count * line_height

		# ASSET / LANGUAGE (columna izquierda de contenido): alineada a la derecha,
		# solo en la primera línea del bloque.
		_add_table_cell(wrapper, asset_text,
			Vector2(col_x[idx_asset], y),
			Vector2(col_w[idx_asset], line_height),
			c_asset, st_asset, a_asset)

		# PART (solo 3 columnas): una celda por sub-línea, centrada
		if columns_count == 3:
			for li in range(work_lines.size()):
				_add_table_cell(wrapper, work_lines[li],
					Vector2(col_x[idx_work], y + li * line_height),
					Vector2(col_w[idx_work], line_height),
					c_work, st_work, HORIZONTAL_ALIGNMENT_CENTER)

		# CREDITO (última columna de contenido): una celda por sub-línea, a la izquierda
		for li in range(name_lines.size()):
			_add_table_cell(wrapper, name_lines[li],
				Vector2(col_x[idx_name], y + li * line_height),
				Vector2(col_w[idx_name], line_height),
				COLOR_TEXT, st_name, a_name)

		y += block_height

	wrapper.custom_minimum_size = Vector2(0, y)
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


func _wrap_credit(text: String, per_line: int, col_width: float) -> Array[String]:
	# Como _wrap_csv pero, además del tope de `per_line` items, fuerza salto de
	# línea si al añadir el siguiente autor la línea superaría el 90% del ancho
	# de la columna (medido con la fuente real de créditos). Un autor que por sí
	# solo excede el 90% se queda en su línea (no se puede partir un nombre).
	var items: Array[String] = []
	for piece in text.split(","):
		var clean: String = piece.strip_edges()
		if clean != "":
			items.append(clean)
	var out: Array[String] = []
	if items.is_empty():
		out.append("")
		return out
	var font = _credit_font()
	var max_w := col_width * 0.9
	var cur := ""
	var cur_count := 0
	for it in items:
		var candidate: String = it if cur == "" else cur + ", " + it
		var too_wide := false
		if font != null and max_w > 0.0:
			too_wide = font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1.0, SIZE_TABLE).x > max_w
		if cur != "" and (cur_count >= per_line or too_wide):
			out.append(cur)
			cur = it
			cur_count = 1
		else:
			cur = candidate
			cur_count += 1
	if cur != "":
		out.append(cur)
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
	var _cf = _credit_font()
	if _cf:
		lbl.add_theme_font_override("font", _cf)
	lbl.horizontal_alignment = align
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.clip_text = true
	# Tamaño por celda: "size" en el dict de estilo, o SIZE_TABLE por defecto.
	lbl.add_theme_font_size_override("font_size", int(style.get("size", SIZE_TABLE)))
	lbl.add_theme_color_override("font_color", final_color)
	lbl.add_theme_color_override("font_outline_color", COLOR_OUTLINE)
	lbl.add_theme_constant_override("outline_size", OUTLINE_PX - 1)
	lbl.position = pos
	lbl.size = sz

	# Cursiva simulada con FontVariation (sesgo horizontal). SOLO en HD (TTF):
	# los bitmap fonts (GBA/Original) no soportan variation_transform y salen
	# como cuadros (tofu). En bitmap se omite la cursiva (queda el dim si lo hay).
	if style.get("italic", false) and AssetSet.current() == "HD":
		var fv := FontVariation.new()
		var theme_font := lbl.get_theme_font("font")
		if theme_font:
			fv.base_font = theme_font
		fv.variation_transform = Transform2D(Vector2(1, 0), Vector2(0.18, 1), Vector2(0, 0))
		lbl.add_theme_font_override("font", fv)

	parent.add_child(lbl)


func _make_divider() -> Control:
	# Divisor: línea con dos rombos en los extremos.
	# El Control debe tener el ancho de la pista, o la línea (anclada a él) y los
	# rombos (anclados a la derecha) quedan a ancho 0 / fuera y no se ven.
	var iw := _get_inner_width()
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.custom_minimum_size = Vector2(iw, 8)
	c.size = Vector2(iw, 8)

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
	hint.add_theme_font_size_override("font_size", 24)
	hint.add_theme_color_override("font_color", COLOR_DIM)
	hint.add_theme_color_override("font_outline_color", COLOR_OUTLINE)
	hint.add_theme_constant_override("outline_size", 3)
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.offset_top = -36
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
	# Anchura disponible entre pilares
	var w := size.x - PILLAR_WIDTH * 2
	if w <= 0:
		w = 800  # Fallback antes de que se calcule el tamaño
	return w


func _on_scroll_resized() -> void:
	var lines: Control = _scroll_node.get_node_or_null("Lines")
	if lines:
		lines.size.x = _scroll_node.size.x
		# Re-centramos labels: ya están con anchor TOP_WIDE, así que ok.
