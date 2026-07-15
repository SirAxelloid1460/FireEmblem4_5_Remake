#!/usr/bin/env python3
"""Sync class bases/caps/growths/mov/con/weapon-ranks from the Genealogy+Thracia
Excel into classes.json. Fixes the placeholder growths (60/61 had HP=100).
Preserves id/name/desc/tier/promotion/skills/map_sprite/combat_anim/etc."""
import json, sys, openpyxl

ROOT = "/home/user/FireEmblem4_5_Remake"
XLSX = "/root/.claude/uploads/673f9207-232c-5aa6-8373-3bdcf28f418b/77182c7e-Genealogy__Thracia_Classes.xlsx"
DRY = "--write" not in sys.argv

M = {  # Excel name -> DB id
 "Citizen":"Citizen","Ballista":"Ballistae","Pegasus Rider":"PegasusRider","Dragon Rider":"DragonRider",
 "Lord":"LordSeliph","Prince":"LordLeaf","Princess":"Princess","Swordfighter":"Swordfighter",
 "Thief":"Thief","Fighter":"Fighter","Bandit":"Bandit","Archer":"Archer","Cavalier":"Cavalier",
 "Trobadour":"Troubadour","Free Knight":"CavalierS","Lance Knight":"CavalierL","Axe Knight":"CavalierA",
 "Archer Knight":"CavalierB","Armour":"Armour","Mage":"Mage","Bard":"Bard","Light Priestress":"LightPriestess",
 "Priest":"Priest","Loptous Mage":"LoptoMage","Dragon Knight":"DragonKnight","Pegasus Knight":"PegasusKnight",
 "Barbarian":"Barbarian","Pirate":"Pirate","Soldier":"Soldier","Warrior":"Warrior","Forrest Knight":"ForrestKnight",
 "Duke Knight":"DukeKnight","Great Knight":"GreatKnight","Lord Knight":"LordKnight","Swordmaster":"Swordmaster",
 "Hero":"Hero","Rogue":"Rogue","Dancer":"Dancer","Sniper":"Sniper","Paladin":"Paladin","Bow Knight":"BowKnight",
 "General":"General","Mage Fighter":"MageFighter","Mage Knight":"MageKnight","Sage":"Sage","High Priest":"HighPriest",
 "Dark Mage":"DarkMage","Falcon Knight":"FalconKnight","Dragon Master":"DragonMaster","Master Knight":"MasterKnight",
 "Berserker":"Berserker","Baron":"Baron","Emperor":"Emperor","Bishop":"Bishop","Queen":"Queen",
 "Dark Bishop":"DarkBishop","Dark Prince":"DarkPrince",
}
# Classes that also feed a FEMALE-variant DB class (share the Excel row, use Female weapon ranks).
FEMALE_TWIN = {"Priest":"Priestess","High Priest":"HighPriestess",
               "Swordfighter":"Mercenary"}  # Swordfighter row also drives Mercenary
RANK = {"E":1,"D":1,"C":51,"B":126,"A":226,"S":1023,"HOLY":1023}
STAT = ["HP","Str","Mag","Skl","Spd","Lck","Def","Res"]
KEY  = ["HP","STR","MAG","SKL","SPD","LCK","DEF","RES"]
WEAP = {"Sword":13,"Lance":14,"Axe":15,"Bow":16,"Anima":17,"Dark":18,"Light":19,"Staff":20}  # col idx; Holy->Light

def num(v):
    try: return int(round(float(v)))
    except (TypeError, ValueError): return None

def parse_basecap(v):
    if v is None: return None, None
    s = str(v).strip()
    if s in ("--",""): return None, None
    if "/" in s:
        a,b = s.split("/",1); return num(a), num(b)
    return num(s), num(s)

def rank_val(cell):
    """Return (value, gender) for a weapon cell like 'B', 'B (Male)', 'C (Female)', '--'."""
    if cell is None: return None, None
    s = str(cell).strip()
    if s in ("--",""): return None, None
    gender = None
    if "(Male)" in s: gender = "M"
    if "(Female)" in s: gender = "F"
    letter = s.split()[0].upper()
    return RANK.get(letter), gender

wb = openpyxl.load_workbook(XLSX, data_only=True)
ws = wb["Classes"]
def cell(r,c): return ws.cell(row=r,column=c).value

# find each Excel class row
rows = {}
for r in range(2, ws.max_row+1):
    b = cell(r,2)
    if b is None: continue
    b = str(b).strip()
    if b.upper().startswith("TIER") or b in ("Class Name",""): continue
    rows[b] = r

db = json.load(open(f"{ROOT}/data/general/classes.json", encoding="utf-8"))
by = {c["id"]: c for c in db}
updated = []
def sync_one(dbid, r, use_female):
    c = by.get(dbid)
    if not c: return None
    bases, caps, growths = {}, {}, {}
    for i,(s,k) in enumerate(zip(STAT,KEY)):
        base,cap = parse_basecap(cell(r, 3+i))          # cols C..J
        if base is not None: bases[k]=base
        if cap  is not None: caps[k]=cap
    bases["LCK"] = 0   # LCK base is always 0 in FE4 (guard vs the Cavalier '28' typo)
    mov = num(cell(r,11)); con = num(cell(r,12))         # Mov col K, Con col L
    # MOV: el Excel viejo tiene errores (mov 2 en casters a pie). Solo se usa
    # si es >=4; si no, se conserva el MOV actual de la DB (que es sano).
    if mov is not None and mov >= 4:
        bases["MOV"]=mov*10; caps["MOV"]=mov*10
    if con is not None: bases["CON"]=con;    caps["CON"]=con
    for i,(s,k) in enumerate(zip(STAT,KEY)):
        g = cell(r, 23+i)                                # growth cols W..AD
        if g is not None: growths[k]= int(round(float(g)*100))
    growths["CON"]=0; growths["MOV"]=0
    # weapon ranks
    wexp = {}
    for wname,col in WEAP.items():
        # Excel 'Holy' column (19) maps to DB 'Light'
        excol = col
        val,gender = rank_val(cell(r, excol))
        if val is None: continue
        # base (male/neutral) vs female-twin
        if gender == "F" and not use_female: continue
        if gender == "M" and use_female: continue
        wexp[wname] = val
    # apply
    old_g = dict(c.get("growths",{}))
    c["bases"]  = {**c.get("bases",{}), **bases}
    c["caps"]   = {**c.get("caps",{}),  **caps}
    c["growths"]= {**c.get("growths",{}), **growths}
    if wexp: c["wexp_gain"] = wexp
    return (dbid, old_g.get("HP"), c["growths"].get("HP"))

for xname, r in rows.items():
    dbid = M.get(xname)
    if dbid:
        res = sync_one(dbid, r, use_female=False)
        if res: updated.append(res)
    if xname in FEMALE_TWIN:
        res = sync_one(FEMALE_TWIN[xname], r, use_female=True)
        if res: updated.append(res)

print(f"Would update {len(updated)} classes." if DRY else f"Updated {len(updated)} classes.")
# ---- sanity report: flag likely old-file errors for review ----
print("\n[SANITY] posibles errores del Excel viejo (revisar):")
flags=[]
for c in db:
    b=c.get("bases",{}); cp=c.get("caps",{})
    mv=b.get("MOV")
    if mv is not None and mv < 40 and c["id"] not in ("Ballistae","Citizen"):
        flags.append(f"  {c['id']}: MOV={mv} (mov {mv//10}) — sospechosamente bajo")
    for k in KEY:
        if k in b and k in cp and b[k] > cp[k]:
            flags.append(f"  {c['id']}: base {k}={b[k]} > cap {cp[k]}")
print("\n".join(flags) if flags else "  ninguno")
# preview a few
for cid in ["Paladin","Mercenary","Priestess","Mage","Sniper","Sage","Cavalier"]:
    c = by.get(cid)
    if c: print(f"  {cid}: bases={c['bases']}\n     growths={c['growths']} wexp={c.get('wexp_gain')}")
if not DRY:
    open(f"{ROOT}/data/general/classes.json","w",encoding="utf-8").write(
        json.dumps(db, indent=1, ensure_ascii=False))
    print("WROTE classes.json")
