#!/usr/bin/env python3
"""Setea el modelo BASE + versions{FE4,FE5} de las clases en
data/general/classes.json, de forma idempotente y con registro.

Convención:
  · El NIVEL SUPERIOR de la clase = versión SAGA (por defecto).
  · versions.FE4 / versions.FE5 = bloques que sobreescriben por-stat.
  · Solo se tocan los 8 stats de combate (HP..RES) de `bases` y `caps`;
    CON/MOV (y el resto) se dejan intactos y se heredan a los bloques.
  · Clases EXCLUSIVAS de un juego: solo nivel superior, sin `versions`.

Orden de stats: HP STR MAG SKL SPD LCK DEF RES.
"""
import json, os

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
PATH = os.path.join(REPO, "data", "general", "classes.json")
S8 = ["HP", "STR", "MAG", "SKL", "SPD", "LCK", "DEF", "RES"]


def d8(vals):
    return {S8[i]: int(vals[i]) for i in range(8)}


# Orden de los bonos de promoción (distinto del de bases/caps).
PS8 = ["STR", "MAG", "SKL", "SPD", "DEF", "RES", "MOV", "LCK"]


def dp(vals):
    """[8 gains] en orden Str·Mag·Skl·Spd·Def·Res·Mov·Lck -> dict."""
    return {PS8[i]: int(vals[i]) for i in range(8)}


def _promo_map(m):
    """{from_class: [8 gains]} -> {from_class: {stat:gain}}."""
    return {fc: dp(g) for fc, g in m.items()}


def _pmax(lists):
    """Máximo por-stat sobre varias listas de 8 gains."""
    return [max(l[i] for l in lists) for i in range(8)]


def _set_promotions(c, promotions, versioned):
    """`promotions` = { origen: {"FE4":[8], "FE5":[8]} | {"ALL":[8]} }.
    SAGA (nivel superior) = máximo por-stat de FE4 y FE5 (o el ALL / el único
    juego dado).  Además, en clases versionadas, FE4/FE5 llevan su propio set.
    """
    saga, fe4, fe5 = {}, {}, {}
    for key, gv in promotions.items():
        if "ALL" in gv:
            g = gv["ALL"]
            saga[key] = dp(g)
            if versioned:
                fe4[key] = dp(g)
                fe5[key] = dp(g)
        else:
            g4, g5 = gv.get("FE4"), gv.get("FE5")
            if versioned and g4 is not None:
                fe4[key] = dp(g4)
            if versioned and g5 is not None:
                fe5[key] = dp(g5)
            saga[key] = dp(_pmax([g for g in (g4, g5) if g is not None]))
    if saga:
        c["promotion_gains"] = saga
    if versioned:
        if fe4:
            c.setdefault("versions", {}).setdefault("FE4", {})["promotion_gains"] = fe4
        if fe5:
            c.setdefault("versions", {}).setdefault("FE5", {})["promotion_gains"] = fe5


def _find(data, cid):
    c = next((x for x in data if str(x.get("id")) == cid), None)
    if c is None:
        raise SystemExit("clase no encontrada: " + cid)
    return c


def _block(spec_tuple):
    """(base, cap|None) -> bloque de versión; sin caps si cap es None (hereda)."""
    base, cap = spec_tuple
    blk = {"bases": d8(base)}
    if cap is not None:
        blk["caps"] = d8(cap)
    return blk


def _set8(cls, base, cap):
    cls.setdefault("bases", {})
    cls.setdefault("caps", {})
    for i, s in enumerate(S8):
        cls["bases"][s] = int(base[i])
        cls["caps"][s] = int(cap[i])


# ── Especificación ───────────────────────────────────────────────────────────
# versioned: SAGA (nivel superior) + bloques FE4/FE5.
VERSIONED = [
    {  # Lord
        "ids": ["LordSeliph"],
        "saga": ([30, 5, 0, 5, 5, 0, 5, 0], [80, 20, 20, 20, 20, 30, 20, 20]),
        "fe4":  ([30, 5, 0, 5, 5, 0, 5, 0], [80, 20, 15, 20, 20, 30, 20, 15]),
        "fe5":  ([18, 4, 0, 2, 3, 0, 2, 0], [80, 20, 20, 20, 20, 20, 20, 20]),
    },
    {  # Citizen (= "Civilian")  — tier 0
        "ids": ["Citizen"],
        "saga": ([20, 0, 0, 0, 10, 0, 2, 0], [80, 20, 20, 20, 25, 30, 20, 15]),
        "fe4":  ([20, 0, 0, 0, 10, 0, 2, 0], [80, 15, 15, 15, 25, 30, 17, 15]),
        "fe5":  ([10, 0, 0, 0, 0, 0, 0, 0],  [80, 20, 20, 20, 20, 20, 20, 0]),
    },
    {  # Dragon Rider  — tier 0
        "ids": ["DragonRider"],
        "saga": ([35, 9, 0, 5, 5, 0, 8, 0], [80, 25, 20, 22, 21, 30, 26, 15]),
        "fe4":  ([35, 9, 0, 5, 5, 0, 8, 0], [80, 25, 15, 22, 21, 30, 26, 15]),
        "fe5":  ([16, 5, 0, 3, 4, 0, 7, 0], [80, 20, 20, 20, 20, 20, 20, 0]),
    },
    {  # Pegasus Rider  — tier 0 (max invertido de Dragon Rider por pares)
        "ids": ["PegasusRider"],
        "saga": ([30, 6, 3, 5, 10, 0, 3, 5], [80, 20, 25, 21, 22, 30, 20, 26]),
        "fe4":  ([30, 6, 0, 5, 10, 0, 3, 5], [80, 15, 25, 21, 22, 30, 15, 26]),
        "fe5":  ([16, 2, 3, 3, 6, 0, 2, 0],  [80, 20, 20, 20, 20, 20, 20, 0]),
    },
    {  # Caballerías iguales: Cavalier, Free Knight, Axe Knight
        "ids": ["Cavalier", "CavalierS", "CavalierA"],
        "saga": ([30, 7, 0, 6, 6, 0, 6, 0], [80, 22, 20, 21, 21, 30, 21, 15]),
        "fe4":  ([30, 7, 0, 6, 6, 0, 6, 0], [80, 22, 15, 21, 21, 30, 21, 15]),
        "fe5":  ([20, 3, 0, 3, 4, 0, 3, 0], [80, 20, 20, 20, 20, 20, 20, 0]),
    },
    {  # Lance Knight  (FE5 max LCK 30)
        "ids": ["CavalierL"],
        "saga": ([30, 7, 0, 6, 6, 0, 6, 0], [80, 22, 20, 21, 21, 30, 21, 15]),
        "fe4":  ([30, 7, 0, 6, 6, 0, 6, 0], [80, 22, 15, 21, 21, 30, 21, 15]),
        "fe5":  ([20, 3, 0, 3, 4, 0, 3, 0], [80, 20, 20, 20, 20, 30, 20, 0]),
    },
    {  # Archer Knight  (FE5 base SPD 5)
        "ids": ["CavalierB"],
        "saga": ([30, 7, 0, 6, 6, 0, 6, 0], [80, 22, 20, 21, 21, 30, 21, 15]),
        "fe4":  ([30, 7, 0, 6, 6, 0, 6, 0], [80, 22, 15, 21, 21, 30, 21, 15]),
        "fe5":  ([20, 3, 0, 3, 5, 0, 3, 0], [80, 20, 20, 20, 20, 20, 20, 0]),
    },
    {  # Troubadour
        "ids": ["Troubadour"],
        "saga": ([26, 3, 3, 6, 6, 0, 3, 3], [80, 20, 20, 21, 30, 30, 20, 18]),
        "fe4":  ([26, 3, 3, 6, 6, 0, 3, 3], [80, 18, 18, 21, 21, 30, 18, 18]),
        "fe5":  ([16, 2, 2, 2, 3, 0, 2, 0], [80, 20, 20, 20, 30, 20, 20, 0]),
    },
    {  # Dragon Knight  (Wyvern Rider). Dragon Rider -> Dragon Knight (FE5 trainee).
        "ids": ["DragonKnight"],
        "saga": ([40, 10, 1, 7, 6, 0, 11, 0], [80, 25, 20, 22, 21, 30, 26, 15]),
        "fe4":  ([40, 10, 0, 7, 6, 0, 11, 0], [80, 25, 15, 22, 21, 30, 26, 15]),
        "fe5":  ([24, 7, 1, 6, 6, 0, 9, 0],   [80, 20, 20, 20, 20, 20, 20, 0]),
        "promotions": {"DragonRider": {"FE5": [2, 1, 3, 2, 2, 1, 1, 0]}},
    },
    {  # Pegasus Knight. Pegasus Rider -> Pegasus Knight (FE5 trainee).
        "ids": ["PegasusKnight"],
        "saga": ([35, 7, 5, 7, 12, 0, 5, 7], [80, 22, 20, 22, 27, 30, 20, 22]),
        "fe4":  ([35, 7, 0, 7, 12, 0, 5, 7], [80, 22, 15, 22, 27, 30, 20, 22]),
        "fe5":  ([17, 4, 5, 5, 8, 0, 3, 0],  [80, 20, 20, 20, 20, 20, 20, 0]),
        "promotions": {"PegasusRider": {"FE5": [2, 2, 2, 2, 1, 1, 1, 0]}},
    },
    {  # Bard
        "ids": ["Bard"],
        "saga": ([30, 0, 7, 7, 10, 0, 3, 7], [80, 20, 22, 22, 25, 30, 20, 22]),
        "fe4":  ([30, 0, 7, 7, 10, 0, 3, 7], [80, 15, 22, 22, 25, 30, 18, 22]),
        "fe5":  ([16, 0, 1, 1, 5, 0, 0, 0],  [80, 20, 20, 20, 20, 20, 20, 0]),
    },
    {  # Light Priestess  (FE5 "Sister")
        "ids": ["LightPriestess"],
        "saga": ([30, 0, 8, 7, 7, 0, 3, 10], [80, 20, 23, 22, 22, 30, 20, 25]),
        "fe4":  ([30, 0, 8, 7, 7, 0, 3, 10], [80, 15, 23, 22, 22, 30, 18, 25]),
        "fe5":  ([14, 0, 1, 2, 5, 0, 0, 0],  [80, 20, 20, 20, 20, 20, 20, 0]),
    },
    {  # Priest / Priestess
        "ids": ["Priest", "Priestess"],
        "saga": ([26, 0, 7, 6, 6, 0, 1, 7], [80, 20, 22, 21, 21, 30, 22, 22]),
        "fe4":  ([26, 0, 7, 6, 6, 0, 1, 7], [80, 15, 22, 21, 21, 30, 22, 22]),
        "fe5":  ([16, 0, 3, 2, 1, 0, 0, 0], [80, 20, 20, 20, 20, 20, 20, 0]),
    },
    {  # Soldier  (= Axe/Sword/Lance/Bow Soldier; caps de FE8, HP a 80)
        "ids": ["Soldier"],
        "saga": ([30, 6, 0, 5, 5, 0, 7, 0], [80, 20, 20, 20, 20, 20, 20, 20]),
        "fe4":  ([30, 6, 0, 5, 5, 0, 7, 0], [80, 20, 20, 20, 20, 20, 20, 20]),
        "fe5":  ([20, 3, 0, 0, 0, 0, 1, 0], [80, 20, 20, 20, 20, 20, 20, 20]),
    },
    {  # Bandit  (FE4 "Brigand" / FE5 "Mnt Bandit")
        "ids": ["Bandit"],
        "saga": ([35, 5, 0, 0, 7, 0, 5, 0], [80, 20, 20, 20, 22, 30, 20, 15]),
        "fe4":  ([35, 5, 0, 0, 7, 0, 5, 0], [80, 20, 15, 15, 22, 30, 20, 15]),
        "fe5":  ([22, 5, 0, 0, 0, 0, 3, 0], [80, 20, 20, 20, 20, 20, 20, 0]),
    },
    {  # Lord Knight  (Seliph promociona de Lord)
        "ids": ["LordKnight"],
        "saga": ([40, 10, 1, 7, 7, 0, 7, 3], [80, 25, 20, 22, 22, 30, 22, 18]),
        "fe4":  ([40, 10, 0, 7, 7, 0, 7, 3], [80, 25, 15, 22, 22, 30, 22, 18]),
        "fe5":  ([18, 5, 1, 3, 4, 0, 4, 0],  [80, 20, 20, 20, 20, 20, 20, 0]),
        # gains: Str·Mag·Skl·Spd·Def·Res·Mov·Lck; SAGA = max(FE4,FE5) por stat.
        "promotions": {"LordSeliph": {"FE4": [5, 0, 2, 2, 2, 3, 3, 0]}},
    },
    {  # Swordmaster  (FE4 = Ayra/Larcei; FE5 = Shiva/Troude/Mareeta)
        "ids": ["Swordmaster"],
        "saga": ([40, 12, 1, 15, 15, 0, 7, 3], [80, 27, 20, 30, 30, 30, 22, 18]),
        "fe4":  ([40, 12, 0, 15, 15, 0, 7, 3], [80, 27, 15, 30, 30, 30, 22, 18]),
        "fe5":  ([24, 5, 1, 8, 10, 0, 4, 0],   [80, 20, 20, 20, 20, 20, 20, 0]),
        "promotions": {"Swordfighter": {
            "FE4": [5, 0, 5, 5, 2, 3, 0, 0], "FE5": [2, 1, 3, 3, 2, 0, 1, 0]}},
    },
    {  # Rogue  (Thief Fighter). Override por personaje: Dancer->Rogue solo Lara.
        "ids": ["Rogue"],
        "saga": ([30, 7, 3, 7, 12, 0, 5, 3], [80, 22, 20, 22, 27, 30, 20, 18]),
        "fe4":  ([30, 7, 3, 7, 12, 0, 5, 3], [80, 22, 18, 22, 27, 30, 20, 18]),
        "fe5":  ([18, 4, 1, 3, 9, 0, 2, 0],  [80, 20, 20, 20, 20, 20, 20, 0]),
        "promotions": {
            "Thief": {"FE4": [4, 3, 4, 5, 4, 3, 1, 0], "FE5": [3, 1, 2, 2, 2, 1, 0, 0]},
            "Dancer@Lara": {"FE5": [3, 1, 2, 2, 2, 1, 1, 0]},   # solo Lara
        },
    },
    {  # Dancer. Solo Lara oscila hacia/desde Dancer en FE5 (gains negativos).
        "ids": ["Dancer"],
        "saga": ([26, 3, 0, 1, 7, 0, 1, 3], [80, 20, 20, 20, 22, 30, 20, 18]),
        "fe4":  ([26, 3, 0, 1, 7, 0, 1, 3], [80, 18, 15, 16, 22, 30, 16, 18]),
        "fe5":  ([14, 0, 0, 0, 2, 0, 0, 0], [80, 20, 20, 20, 20, 20, 20, 0]),
        "promotions": {
            "Thief@Lara": {"FE5": [0, 0, -2, -5, 0, 0, -1, 0]},
            "Rogue@Lara": {"FE5": [0, 0, -2, -5, 0, 0, -1, 0]},
        },
    },
    {  # Warrior  (orígenes Fighter y Bandit; sin etiqueta de juego → todos)
        "ids": ["Warrior"],
        "saga": ([40, 11, 1, 5, 12, 0, 10, 6], [80, 26, 20, 20, 27, 30, 25, 18]),
        "fe4":  ([40, 11, 0, 5, 12, 0, 10, 3], [80, 26, 15, 20, 27, 30, 25, 18]),
        "fe5":  ([28, 8, 1, 5, 6, 0, 6, 6],     [80, 20, 20, 20, 20, 20, 20, 0]),
        "promotions": {
            "Fighter": {"ALL": [3, 0, 2, 2, 2, 3, 0, 0]},
            "Bandit":  {"ALL": [3, 1, 5, 6, 3, 1, 0, 0]},
        },
    },
    {  # Sniper  (Archer -> Sniper, FE4/FE5)
        "ids": ["Sniper"],
        "saga": ([40, 12, 1, 12, 12, 0, 7, 7], [80, 27, 20, 27, 27, 30, 22, 18]),
        "fe4":  ([40, 12, 0, 12, 12, 0, 7, 3], [80, 27, 15, 27, 27, 30, 22, 18]),
        "fe5":  ([22, 5, 1, 6, 8, 0, 3, 7],     [80, 20, 20, 20, 20, 20, 20, 0]),
        "promotions": {"Archer": {
            "FE4": [5, 0, 2, 2, 2, 3, 0, 0], "FE5": [2, 1, 3, 3, 2, 1, 1, 0]}},
    },
    {  # Paladin  (Cavalier/Troubadour -> Paladin). FE4 = SAGA en base/caps.
        "ids": ["Paladin"],
        "saga": ([40, 9, 5, 9, 9, 0, 9, 5], [80, 24, 20, 24, 24, 30, 24, 20]),
        "fe4":  ([40, 9, 5, 9, 9, 0, 9, 5], [80, 24, 20, 24, 24, 30, 24, 20]),
        "fe5":  ([24, 5, 5, 6, 6, 0, 5, 0], [80, 20, 20, 20, 20, 20, 20, 0]),
        "promotions": {
            "Cavalier":   {"FE4": [2, 5, 3, 3, 3, 5, 1, 0], "FE5": [2, 1, 3, 2, 2, 1, 1, 0]},
            "Troubadour": {"FE4": [6, 2, 3, 3, 6, 2, 1, 0]},   # Ethlyn/Jeanne
            # Nanna: FE4 = default; FE5 propio; SAGA = max = [6,3,3,3,6,2,1,0].
            "Troubadour@Nanna": {"FE4": [6, 2, 3, 3, 6, 2, 1, 0], "FE5": [1, 3, 1, 3, 1, 1, 1, 0]},
        },
    },
    {  # Hero  (FE4 "Forrest" / FE5 "Mercenary-Campeón")
        "ids": ["Hero"],
        "saga": ([40, 12, 3, 12, 12, 0, 7, 6], [80, 27, 20, 27, 27, 30, 22, 18]),
        "fe4":  ([40, 12, 3, 12, 12, 0, 7, 3], [80, 27, 18, 27, 27, 30, 22, 18]),
        "fe5":  ([24, 6, 1, 7, 9, 0, 5, 6],    [80, 20, 20, 20, 20, 20, 20, 0]),
        # promo rows traen 7 valores (sin Lck final) → padded con 0.
        "promotions": {
            "Mercenary": {"FE4": [5, 3, 2, 2, 2, 3, 0, 0], "FE5": [3, 1, 2, 3, 3, 2, 0, 0]},
            "Fighter":   {"ALL": [2, 1, 3, 3, 3, 0, 0, 0]},
        },
    },
    {  # Ranger  (Forrest Knight; Free Knight -> Ranger)
        "ids": ["Ranger"],
        "saga": ([40, 8, 1, 15, 12, 0, 8, 3], [80, 23, 20, 30, 27, 30, 23, 18]),
        "fe4":  ([40, 8, 0, 15, 12, 0, 8, 3], [80, 23, 15, 30, 27, 30, 23, 18]),
        "fe5":  ([24, 5, 1, 6, 7, 0, 5, 0],   [80, 20, 20, 20, 20, 20, 20, 0]),
        "promotions": {"CavalierS": {
            "FE4": [1, 0, 9, 6, 2, 3, 1, 0], "FE5": [2, 1, 3, 3, 2, 1, 1, 0]}},
    },
    {  # Duke Knight  (Lance Knight -> Duke Knight; Finn override per-juego)
        "ids": ["DukeKnight"],
        "saga": ([40, 12, 0, 7, 7, 0, 8, 3], [80, 27, 20, 22, 22, 30, 23, 18]),
        "fe4":  ([40, 12, 0, 7, 7, 0, 8, 3], [80, 27, 15, 22, 22, 30, 23, 18]),
        "fe5":  ([24, 5, 0, 6, 6, 0, 5, 0],   [80, 20, 20, 20, 20, 20, 20, 0]),
        "promotions": {
            "CavalierL":       {"FE5": [2, 1, 3, 2, 2, 1, 1, 0]},   # genérico (FE4 = solo Finn)
            "CavalierL@Finn":  {"FE4": [5, 0, 1, 1, 2, 3, 1, 0], "FE5": [1, 1, 3, 2, 2, 1, 1, 0]},
        },
    },
    {  # Great Knight  (Axe Knight -> Great Knight)
        "ids": ["GreatKnight"],
        "saga": ([40, 12, 1, 7, 7, 0, 10, 3], [80, 27, 20, 22, 22, 30, 25, 18]),
        "fe4":  ([40, 12, 0, 7, 7, 0, 10, 3], [80, 27, 15, 22, 22, 30, 25, 18]),
        "fe5":  ([24, 5, 1, 6, 6, 0, 5, 0],    [80, 20, 20, 20, 20, 20, 20, 0]),
        "promotions": {"CavalierA": {
            "FE4": [5, 0, 1, 1, 4, 3, 1, 0], "FE5": [2, 1, 3, 2, 2, 1, 1, 0]}},
    },
    {  # Bow Knight  (Archer Knight -> Bow Knight)
        "ids": ["BowKnight"],
        "saga": ([40, 10, 1, 8, 8, 0, 8, 3], [80, 25, 20, 23, 23, 30, 23, 18]),
        "fe4":  ([40, 10, 0, 8, 8, 0, 8, 3], [80, 25, 15, 23, 23, 30, 23, 18]),
        "fe5":  ([24, 5, 1, 6, 7, 0, 5, 0],   [80, 20, 20, 20, 20, 20, 20, 0]),
        "promotions": {"CavalierB": {
            "FE4": [3, 0, 2, 2, 2, 3, 1, 0], "FE5": [2, 1, 3, 2, 2, 1, 1, 0]}},
    },
    {  # General  (Armour -> General)
        "ids": ["General"],
        "saga": ([40, 10, 1, 6, 5, 0, 12, 3], [80, 25, 20, 21, 20, 30, 27, 18]),
        "fe4":  ([40, 10, 0, 6, 5, 0, 12, 3], [80, 25, 15, 21, 20, 30, 27, 18]),
        "fe5":  ([26, 7, 1, 5, 2, 0, 12, 0],   [80, 20, 20, 20, 20, 20, 20, 0]),
        "promotions": {"Armour": {
            "FE4": [1, 0, 1, 2, 2, 3, 0, 0], "FE5": [3, 1, 5, 2, 4, 1, 1, 0]}},
    },
    {  # Falcon Knight  (Pegasus Knight -> Falcon Knight). FE4 = SAGA.
        "ids": ["FalconKnight"],
        "saga": ([40, 7, 7, 12, 15, 0, 6, 12], [80, 22, 22, 25, 30, 30, 21, 27]),
        "fe4":  ([40, 7, 7, 12, 15, 0, 6, 12], [80, 22, 22, 25, 30, 30, 21, 27]),
        "fe5":  ([20, 6, 7, 7, 10, 0, 5, 0],    [80, 20, 20, 20, 20, 20, 20, 0]),
        # FE4 daba solo estos gains; en el remake aplican en todos los modos.
        "promotions": {"PegasusKnight": {"ALL": [0, 7, 5, 3, 1, 5, 0, 0]}},
    },
    {  # Dark Bishop  (enemigo)
        "ids": ["DarkBishop"],
        "saga": ([40, 0, 15, 10, 10, 0, 10, 12], [80, 20, 30, 25, 25, 30, 25, 27]),
        "fe4":  ([40, 0, 15, 10, 10, 0, 10, 12], [80, 15, 30, 25, 25, 30, 25, 27]),
        "fe5":  ([30, 0, 9, 6, 6, 0, 6, 0],       [80, 20, 20, 20, 20, 20, 20, 0]),
    },
    {  # Emperor  (enemigo)
        "ids": ["Emperor"],
        "saga": ([45, 15, 15, 15, 15, 0, 15, 15], [80, 30, 30, 30, 30, 30, 30, 30]),
        "fe4":  ([45, 15, 15, 15, 15, 0, 15, 15], [80, 30, 30, 30, 30, 30, 30, 30]),
        "fe5":  ([26, 7, 1, 5, 2, 0, 12, 0],       [80, 20, 20, 20, 20, 20, 20, 0]),
    },
    {  # Bishop
        "ids": ["Bishop"],
        "saga": ([35, 0, 10, 8, 5, 0, 3, 8], [80, 20, 25, 23, 20, 30, 20, 23]),
        "fe4":  ([35, 0, 10, 8, 5, 0, 3, 8], [80, 15, 25, 23, 20, 30, 18, 23]),
        "fe5":  ([20, 0, 5, 2, 2, 0, 1, 0], [80, 20, 20, 20, 20, 20, 20, 0]),
    },
    {  # Dark Prince  (enemigo) — SAGA toma la base grande de FE5, RES de FE4
        "ids": ["DarkPrince"],
        "saga": ([50, 0, 20, 20, 20, 0, 20, 15], [80, 20, 30, 27, 27, 30, 25, 30]),
        "fe4":  ([30, 0, 15, 12, 12, 0, 10, 15], [80, 15, 30, 27, 27, 30, 25, 30]),
        "fe5":  ([50, 0, 20, 20, 20, 0, 20, 0],  [80, 20, 20, 20, 20, 20, 20, 0]),
    },
    {  # Armour  (= FE4 Sword/Lance/Bow/Axe Armour, unificados)
        "ids": ["Armour"],
        "saga": ([40, 9, 0, 5, 3, 0, 10, 0], [80, 24, 20, 20, 20, 30, 25, 15]),
        "fe4":  ([40, 9, 0, 5, 3, 0, 10, 0], [80, 24, 15, 20, 18, 30, 25, 15]),
        "fe5":  ([20, 4, 0, 0, 0, 0, 8, 0],  [80, 20, 20, 20, 20, 20, 20, 0]),
    },
    {  # Mage  (= FE4 Fire/Thunder/Wind Mage + Mage, unificados)
        "ids": ["Mage"],
        "saga": ([26, 0, 8, 7, 7, 0, 3, 4], [80, 20, 23, 22, 22, 30, 20, 20]),
        "fe4":  ([26, 0, 8, 7, 7, 0, 3, 4], [80, 15, 23, 22, 22, 30, 16, 20]),
        "fe5":  ([17, 0, 2, 2, 4, 0, 0, 0], [80, 20, 20, 20, 20, 20, 20, 0]),
    },
    {  # Fighter  (= FE4 "Axe Fighter")
        "ids": ["Fighter"],
        "saga": ([35, 8, 0, 4, 10, 0, 8, 0], [80, 23, 20, 20, 25, 30, 23, 15]),
        "fe4":  ([35, 8, 0, 3, 10, 0, 8, 0], [80, 23, 15, 18, 25, 30, 23, 15]),
        "fe5":  ([20, 4, 0, 4, 5, 0, 2, 0],  [80, 20, 20, 20, 20, 20, 20, 0]),
    },
    {  # Archer  (= FE4 "Bow Fighter + Hunter")
        "ids": ["Archer"],
        "saga": ([33, 7, 0, 5, 9, 0, 5, 0], [80, 21, 20, 20, 24, 30, 20, 15]),
        "fe4":  ([33, 7, 0, 5, 9, 0, 5, 0], [80, 21, 15, 20, 24, 30, 20, 15]),
        "fe5":  ([19, 3, 0, 2, 3, 0, 2, 0], [80, 20, 20, 20, 20, 20, 20, 10]),
    },
    {  # Pirate
        "ids": ["Pirate"],
        "saga": ([35, 5, 0, 0, 7, 0, 5, 0], [80, 20, 20, 20, 22, 30, 20, 15]),
        "fe4":  ([35, 5, 0, 0, 7, 0, 5, 0], [80, 20, 20, 20, 20, 20, 20, 15]),
        "fe5":  ([24, 5, 0, 0, 0, 0, 3, 0], [80, 20, 20, 20, 20, 20, 20, 0]),
    },
    {  # Thief  (FE5 sin caps → hereda SAGA)
        "ids": ["Thief"],
        "saga": ([26, 3, 0, 3, 7, 7, 1, 0], [80, 18, 15, 18, 22, 30, 16, 15]),
        "fe4":  ([26, 3, 0, 3, 0, 7, 1, 0], [80, 18, 15, 18, 22, 30, 16, 15]),
        "fe5":  ([15, 1, 0, 1, 7, 0, 0, 0], None),
    },
    {  # Prince (Leif)
        "ids": ["LordLeaf"],
        "saga": ([30, 8, 3, 7, 6, 7, 3, 6], [80, 23, 20, 22, 21, 30, 22, 18]),
        "fe4":  ([30, 8, 3, 7, 6, 7, 3, 6], [80, 23, 18, 22, 21, 30, 22, 18]),
        "fe5":  ([18, 5, 1, 3, 4, 0, 3, 0], [80, 20, 20, 20, 20, 20, 20, 0]),
    },
    {  # Swordfighter (y Mercenary, mismo nombre "Swordfighter")
        "ids": ["Swordfighter", "Mercenary"],
        "saga": ([30, 7, 0, 10, 10, 0, 5, 6], [80, 22, 20, 25, 25, 30, 20, 15]),
        "fe4":  ([30, 7, 0, 10, 10, 0, 5, 0], [80, 22, 15, 25, 25, 30, 20, 15]),
        "fe5":  ([19, 3, 0, 5, 7, 0, 2, 6],   [80, 20, 20, 20, 20, 30, 20, 6]),
    },
]

# exclusivas de un juego: solo nivel superior (sin versions).
EXCLUSIVE = [
    {  # Princess — exclusiva FE4
        "ids": ["Princess"],
        "base": [26, 5, 7, 5, 8, 0, 5, 7],
        "cap":  [80, 20, 22, 20, 23, 30, 20, 22],
    },
    {  # Barbarian — exclusiva FE4
        "ids": ["Barbarian"],
        "base": [35, 5, 0, 0, 7, 0, 5, 0],
        "cap":  [80, 20, 15, 15, 22, 30, 20, 15],
    },
    {  # Queen — exclusiva FE4
        "ids": ["Queen"],
        "base": [35, 5, 15, 10, 12, 0, 10, 15],
        "cap":  [80, 20, 30, 25, 27, 30, 25, 30],
    },
    {  # Loptrian Mage (LoptoMage) — exclusiva FE5
        "ids": ["LoptoMage"],
        "base": [18, 0, 2, 2, 3, 0, 0, 0],
        "cap":  [80, 20, 20, 20, 20, 20, 20, 20],
    },
    {  # Berserker — exclusiva FE5
        "ids": ["Berserker"],
        "base": [32, 12, 0, 12, 10, 0, 8, 0],
        "cap":  [80, 20, 20, 20, 20, 20, 20, 0],
    },
    {  # Dragon Master (Wyvern Lord) — un set para todos los modos.
        "ids": ["DragonMaster"],
        "base": [40, 12, 0, 9, 7, 0, 14, 0],
        "cap":  [80, 27, 15, 24, 22, 30, 29, 15],
        "promotions": {"DragonKnight": {"ALL": [2, 0, 2, 1, 3, 0, 0, 0]}},
    },
    {  # Master Knight — un set para todos los modos (FE4 + FE5 buff: Leif
       # promociona Prince -> Master Knight). Dos clases de origen: Prince
       # (LordLeaf) y Princess.
        "ids": ["MasterKnight"],
        "base": [40, 12, 7, 12, 12, 0, 12, 7],
        "cap":  [80, 27, 22, 27, 27, 30, 27, 22],
        "promotions": {
            "LordLeaf": {"ALL": [4, 4, 5, 6, 5, 4, 3, 0]},   # Prince -> Master Knight
            "Princess": {"ALL": [7, 0, 7, 4, 7, 0, 3, 0]},   # Princess -> Master Knight
        },
    },
]


def main():
    data = json.load(open(PATH))
    for spec in VERSIONED:
        for cid in spec["ids"]:
            c = _find(data, cid)
            _set8(c, *spec["saga"])
            c["versions"] = {
                "FE4": _block(spec["fe4"]),
                "FE5": _block(spec["fe5"]),
            }
            if "promotions" in spec:
                _set_promotions(c, spec["promotions"], versioned=True)
            print("versioned", cid)
    for spec in EXCLUSIVE:
        for cid in spec["ids"]:
            c = _find(data, cid)
            _set8(c, spec["base"], spec["cap"])
            c.pop("versions", None)
            if "promotions" in spec:
                _set_promotions(c, spec["promotions"], versioned=False)
            print("exclusive", cid)
    json.dump(data, open(PATH, "w"), indent=1, ensure_ascii=False)
    open(PATH, "a").write("\n")


if __name__ == "__main__":
    main()
