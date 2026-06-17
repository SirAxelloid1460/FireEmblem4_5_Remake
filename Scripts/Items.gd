# Items.gd
# Definición completa de todos los items del proyecto FE Remake.
# Incluye todos los items del spreadsheet, incluidos los que no pudieron
# implementarse en LT-maker por limitaciones técnicas del engine.
#
# CATEGORÍAS:
#   A) Rings de equipo    — efectos pasivos desde el inventario (on_hold)
#   B) Consumibles        — se usan y se gastan
#   C) Stat Boosters      — mejoran stats permanentemente (una vez)
#   D) Manuales de skill  — enseñan una skill permanentemente
#   E) Items especiales   — mecánicas únicas (Valkyrie, Member Card, etc.)
#
# MECÁNICA on_hold vs on_equip:
#   on_hold  → el efecto se aplica mientras el item esté en CUALQUIER slot
#              del inventario. No hace falta equiparlo.
#   on_equip → el efecto solo aplica si el item está en el slot de arma activo.
#              Solo aplica a armas sagradas y algunas espadas especiales.
#
# USO:
#   var item = ItemDatabase.get_item("Life Ring")
#   unit.add_to_inventory(item)
#   # El efecto on_hold se aplica automáticamente

class_name ItemCatalog
extends RefCounted

# ── Clase base de Item ────────────────────────────────────────────────────────

class ItemData:
	var id:           String
	var name:         String
	var description:  String
	var value:        int     # Precio en tienda
	var uses:         int     # -1 = ilimitado / sin usos (rings pasivos)
	var category:     String  # "ring", "consumable", "booster", "manual", "special", "key"
	var hold_type:    String  # "on_hold", "on_equip", "usable", "none"
	var usable_in_base: bool  # Puede usarse solo en castillo, no en campo
	var lose_on_miss: bool    # Pierde uso aunque falle (arcos/magia/staves)

	# Efectos
	var stat_bonus:       Dictionary  # stat → valor. Para rings on_hold (temporal)
	var stat_permanent:   Dictionary  # stat → valor. Para stat boosters (permanente)
	var skill_granted:    String      # ID de skill que otorga
	var heal_percent:     float       # 0.0–1.0 de HP máximo curado (1.0 = todo)
	var heal_flat:        int         # HP fijos curados
	var status_applied:   String      # Status negativo/positivo que aplica
	var event_on_use:     String      # ID de evento que dispara al usarse

	func _init(p_id: String, p_name: String, p_desc: String,
			p_value: int, p_uses: int, p_cat: String, p_hold: String):
		id             = p_id
		name           = p_name
		description    = p_desc
		value          = p_value
		uses           = p_uses
		category       = p_cat
		hold_type      = p_hold
		usable_in_base = false
		lose_on_miss   = false
		stat_bonus     = {}
		stat_permanent = {}
		skill_granted  = ""
		heal_percent   = 0.0
		heal_flat      = 0
		status_applied = ""
		event_on_use   = ""


# ══════════════════════════════════════════════════════════════════════════════
# BASE DE DATOS DE ITEMS
# ══════════════════════════════════════════════════════════════════════════════

static func get_all() -> Array[ItemData]:
	var items: Array[ItemData] = []
	items.append_array(_rings_equipment())
	items.append_array(_consumables())
	items.append_array(_stat_boosters())
	items.append_array(_skill_manuals())
	items.append_array(_special())
	return items

static func get_item(item_id: String) -> ItemData:
	for item in get_all():
		if item.id == item_id:
			return item
	push_warning("ItemDatabase: item '%s' no encontrado" % item_id)
	return null


# ══════════════════════════════════════════════════════════════════════════════
# A) RINGS DE EQUIPO — efectos pasivos on_hold (en inventario)
# ══════════════════════════════════════════════════════════════════════════════
#
# Todos estos items otorgan su efecto simplemente por estar en el inventario.
# NO hace falta equiparlos. Se pueden vender o transferir via Pawn Shop.
# Los rings de stat (+5 SPD etc.) están codificados como stat_bonus temporal
# (duran mientras el ring esté en el inventario).
# Los rings que dan skills están codificados como skill_granted.

static func _rings_equipment() -> Array[ItemData]:
	var rings: Array[ItemData] = []

	# ── Life Ring ─────────────────────────────────────────────────────────────
	# Regenera 5~10 HP al inicio de cada turno (equivale a la skill Life)
	var life_ring := ItemData.new(
		"LifeRing", "Life Ring",
		"Restores 5~10 HP to the bearer at the start of each turn.",
		40000, -1, "ring", "on_hold")
	life_ring.skill_granted = "Life"
	rings.append(life_ring)

	# ── Elite Ring ────────────────────────────────────────────────────────────
	var elite_ring := ItemData.new(
		"EliteRing", "Elite Ring",
		"Bearer receives double EXP (max 100 per action).",
		40000, -1, "ring", "on_hold")
	elite_ring.skill_granted = "Elite"
	rings.append(elite_ring)

	# ── Thief Ring ────────────────────────────────────────────────────────────
	var thief_ring := ItemData.new(
		"ThiefRing", "Thief Ring",
		"Grants the Steal skill while held.",
		40000, -1, "ring", "on_hold")
	thief_ring.skill_granted = "Steal"
	rings.append(thief_ring)

	# ── Prayer Ring ───────────────────────────────────────────────────────────
	var prayer_ring := ItemData.new(
		"PrayerRing", "Prayer Ring",
		"Grants Prayer: when HP ≤ 10, adds [(11 − HP) × 10] to Avoid.",
		40000, -1, "ring", "on_hold")
	prayer_ring.skill_granted = "Prayer"
	rings.append(prayer_ring)

	# ── Pursuit Ring ─────────────────────────────────────────────────────────
	# En el proyecto Pursuit es mecánica global — el ring da +2 AS en su lugar,
	# simulando que el portador "persigue" mejor. Es un item coleccionable/valioso.
	var pursuit_ring := ItemData.new(
		"PursuitRing", "Pursuit Ring",
		"Increases Attack Speed by 2 while held.",
		40000, -1, "ring", "on_hold")
	pursuit_ring.stat_bonus = {"SPD": 2}
	rings.append(pursuit_ring)
	# NOTA: Pursuit como mecánica de doble ataque es global en este proyecto.
	# El Pursuit Ring da +2 AS como compensación al ser un ring valioso.

	# ── Recover Ring ─────────────────────────────────────────────────────────
	var recover_ring := ItemData.new(
		"RecoverRing", "Recover Ring",
		"Fully restores the bearer's HP at the start of each turn.",
		40000, -1, "ring", "on_hold")
	recover_ring.skill_granted = "Recover"
	# Recover skill: recupera 100% HP por turno. Extremadamente poderoso.
	rings.append(recover_ring)

	# ── Bargain Ring ──────────────────────────────────────────────────────────
	var bargain_ring := ItemData.new(
		"BargainRing", "Bargain Ring",
		"Items and repairs cost half price while held.",
		40000, -1, "ring", "on_hold")
	bargain_ring.skill_granted = "Bargain"
	rings.append(bargain_ring)

	# ── Knight Ring ───────────────────────────────────────────────────────────
	# Canto: permite usar el movimiento restante después de actuar
	var knight_ring := ItemData.new(
		"KnightRing", "Knight Ring",
		"Bearer can use remaining movement after performing an action (Canto).",
		40000, -1, "ring", "on_hold")
	knight_ring.skill_granted = "Canto"
	rings.append(knight_ring)

	# ── Return Ring ───────────────────────────────────────────────────────────
	# Este ring es USABLE (consume el uso al activarlo), no pasivo.
	# Al usarlo, teletransporta al portador de vuelta al castillo principal.
	var return_ring := ItemData.new(
		"ReturnRing", "Return Ring",
		"Use to instantly return the bearer to the home castle.",
		20000, 1, "ring", "usable")
	return_ring.event_on_use = "ReturnToHomeCastle"
	rings.append(return_ring)

	# ── Speed Ring ────────────────────────────────────────────────────────────
	var speed_ring := ItemData.new(
		"SpeedRing_equip", "Speed Ring",
		"+5 Speed while held.",
		20000, -1, "ring", "on_hold")
	speed_ring.stat_bonus = {"SPD": 5}
	rings.append(speed_ring)

	# ── Magic Ring ────────────────────────────────────────────────────────────
	var magic_ring := ItemData.new(
		"MagicRing_equip", "Magic Ring",
		"+5 Magic while held.",
		20000, -1, "ring", "on_hold")
	magic_ring.stat_bonus = {"MAG": 5}
	rings.append(magic_ring)

	# ── Power Ring ────────────────────────────────────────────────────────────
	var power_ring := ItemData.new(
		"PowerRing_equip", "Power Ring",
		"+5 Strength while held.",
		20000, -1, "ring", "on_hold")
	power_ring.stat_bonus = {"STR": 5}
	rings.append(power_ring)

	# ── Shield Ring ───────────────────────────────────────────────────────────
	var shield_ring := ItemData.new(
		"ShieldRing_equip", "Shield Ring",
		"+5 Defense while held.",
		20000, -1, "ring", "on_hold")
	shield_ring.stat_bonus = {"DEF": 5}
	rings.append(shield_ring)

	# ── Barrier Ring ──────────────────────────────────────────────────────────
	var barrier_ring := ItemData.new(
		"BarrierRing", "Barrier Ring",
		"+5 Resistance while held.",
		20000, -1, "ring", "on_hold")
	barrier_ring.stat_bonus = {"RES": 5}
	rings.append(barrier_ring)

	# ── Leg Ring ──────────────────────────────────────────────────────────────
	var leg_ring := ItemData.new(
		"LegRing_equip", "Leg Ring",
		"+3 Movement while held.",
		20000, -1, "ring", "on_hold")
	leg_ring.stat_bonus = {"MOV": 3}
	rings.append(leg_ring)

	# ── Skill Ring ────────────────────────────────────────────────────────────
	var skill_ring := ItemData.new(
		"SkillRing_equip", "Skill Ring",
		"+5 Skill while held.",
		20000, -1, "ring", "on_hold")
	skill_ring.stat_bonus = {"SKL": 5}
	rings.append(skill_ring)

	# ── Circlet ───────────────────────────────────────────────────────────────
	# Otorga tanto Prayer como Life mientras se lleva
	var circlet := ItemData.new(
		"Circlet", "Circlet",
		"Grants Prayer and Life skills while held.",
		0, -1, "ring", "on_hold")
	# Dos skills — lista en extra, manejada por el sistema de items
	circlet.skill_granted = "Prayer,Life"
	# NOTA: El Circlet otorga dos skills a la vez. El ItemSystem debe
	# iterar la lista separada por comas al aplicar el on_hold.
	rings.append(circlet)

	return rings


# ══════════════════════════════════════════════════════════════════════════════
# B) CONSUMIBLES
# ══════════════════════════════════════════════════════════════════════════════

static func _consumables() -> Array[ItemData]:
	var cons: Array[ItemData] = []

	# ── Vulnerary ─────────────────────────────────────────────────────────────
	var vuln := ItemData.new(
		"Vulnerary", "Vulnerary",
		"Fully restores the user's HP.",
		600, 3, "consumable", "usable")
	vuln.heal_percent = 1.0
	cons.append(vuln)

	# ── Holy Water ────────────────────────────────────────────────────────────
	# +7 MAG temporal. El bonus decrece en 1 cada turno hasta llegar a 0.
	# Implementación: aplica el status "HolyWater" que tiene stat_change temporal.
	# ⚠️ NUEVO (no estaba en LT): ahora implementable via sistema de status.
	var holy_water := ItemData.new(
		"HolyWater", "Holy Water",
		"Temporarily increases Magic by 7. Effect decreases by 1 each turn.",
		1000, 1, "consumable", "usable")
	holy_water.status_applied = "HolyWater"
	# El status HolyWater tiene: stat_change {MAG: +7}, upkeep: -1 MAG por turno,
	# duración hasta que el bonus llegue a 0 (7 turnos)
	cons.append(holy_water)

	# ── Antidote ──────────────────────────────────────────────────────────────
	# ⚠️ NUEVO (no estaba en LT): elimina el status Poison del portador.
	var antidote := ItemData.new(
		"Antidote", "Antidote",
		"Cures the Poison status.",
		1500, 3, "consumable", "usable")
	antidote.status_applied = "CurePoison"
	# El sistema de items, al usarlo, busca y elimina cualquier status
	# de tipo "Poison" en la unidad objetivo.
	cons.append(antidote)

	# ── Torch ─────────────────────────────────────────────────────────────────
	# Item de uso que expande la visión en FoW a radio 10.
	# El radio decrece en 1 cada turno.
	var torch := ItemData.new(
		"Torch_item", "Torch",
		"Expands vision to radius 10 in Fog of War. Decreases by 1 each turn.",
		500, 1, "consumable", "usable")
	torch.status_applied = "TorchVision"
	cons.append(torch)

	# ── Key ───────────────────────────────────────────────────────────────────
	# Llave genérica que abre puertas, cofres o puentes levadizos.
	# En FE4 era un item con 3 usos (todos usos en uno).
	# En FE5 se separó en Door Key / Chest Key / Bridge Key.
	# Para el proyecto mantenemos la Key genérica de FE4.
	var key := ItemData.new(
		"Key", "Key",
		"Opens a door, chest, or drawbridge. 3 uses.",
		500, 3, "key", "usable")
	key.event_on_use = "UnlockAdjacent"
	cons.append(key)

	# ── Lockpick ──────────────────────────────────────────────────────────────
	# Solo Thieves/Rogues. Abre cualquier cerradura, 30 usos.
	var lockpick := ItemData.new(
		"Lockpick", "Lockpick",
		"Thieves only. Opens any lock. 30 uses.",
		3000, 30, "key", "usable")
	lockpick.event_on_use = "UnlockAdjacent"
	# El ItemSystem verifica que el portador sea Thief/Rogue antes de permitir el uso.
	cons.append(lockpick)

	# ── Knight Proof ──────────────────────────────────────────────────────────
	# Item de promoción. Solo usable en el Home Castle (usable_in_base).
	var kp := ItemData.new(
		"KnightProof", "Knight Proof",
		"Promotes most units at level 10 or above. Use at the home castle.",
		8000, 1, "consumable", "usable")
	kp.usable_in_base = true
	kp.event_on_use   = "PromoteUnit"
	cons.append(kp)

	return cons


# ══════════════════════════════════════════════════════════════════════════════
# C) STAT BOOSTERS PERMANENTES
# ══════════════════════════════════════════════════════════════════════════════
#
# Se usan una sola vez y aumentan el stat permanentemente.
# Son consumibles de un solo uso. Pueden usarse en campo o en castillo.
# En FE4 se llamaban "Earrings"; en el spreadsheet aparecen con nombre propio.
# Tanto la versión FE4 (Earring) como FE5 (Ring) se unifican aquí.
# NOTA: Los nombres "Speed Ring", "Magic Ring", etc. colisionan con los rings
# de equipo — se diferencian añadiendo "Talisman" al nombre de los permanentes.
#
# ⚠️ TODOS estos items son NUEVOS respecto a LT (los Earrings ya estaban,
#    pero Luck Ring, Body Ring y las versiones "Talisman" son nuevos).

static func _stat_boosters() -> Array[ItemData]:
	var boosters: Array[ItemData] = []

	# helper local
	var _mk := func(id: String, name: String, desc: String, stat: String, amount: int) -> ItemData:
		var b := ItemData.new(id, name, desc, 8000, 1, "booster", "usable")
		b.stat_permanent = {stat: amount}
		b.usable_in_base = false  # Se pueden usar en campo también
		return b

	boosters.append(_mk.call("LuckRing",   "Luck Talisman",   "Permanently increases Luck by 3.",    "LCK", 3))
	boosters.append(_mk.call("HPRing",     "Vitality Talisman","Permanently increases Max HP by 7.", "HP",  7))
	boosters.append(_mk.call("SpeedRing",  "Speed Talisman",  "Permanently increases Speed by 3.",   "SPD", 3))
	boosters.append(_mk.call("MagicRing",  "Magic Talisman",  "Permanently increases Magic by 2.",   "MAG", 2))
	boosters.append(_mk.call("PowerRing",  "Power Talisman",  "Permanently increases Strength by 3.","STR", 3))
	boosters.append(_mk.call("BodyRing",   "Body Talisman",   "Permanently increases Constitution by 3.", "CON", 3))
	# ⚠️ NUEVO: Body Ring / Body Talisman no estaba en LT (limitación del engine)
	boosters.append(_mk.call("ShieldRing", "Shield Talisman", "Permanently increases Defense by 2.", "DEF", 2))
	boosters.append(_mk.call("SkillRing",  "Skill Talisman",  "Permanently increases Skill by 3.",   "SKL", 3))
	boosters.append(_mk.call("LegRing",    "Leg Talisman",    "Permanently increases Movement by 2.","MOV", 2))

	return boosters


# ══════════════════════════════════════════════════════════════════════════════
# D) MANUALES DE SKILL
# ══════════════════════════════════════════════════════════════════════════════
#
# Se usan una vez y enseñan una skill permanentemente a la unidad objetivo.
# Solo usables en castillo (usable_in_base = true, aunque aquí lo dejamos
# flexible para que el GameManager decida el contexto).
# En LT se implementaban como status_on_hit con la skill correspondiente.
# ⚠️ Continue M y Moonlight Sw M son NUEVOS (no implementados en LT).

static func _skill_manuals() -> Array[ItemData]:
	var manuals: Array[ItemData] = []

	var _mk := func(id: String, name: String, skill: String, note: String = "") -> ItemData:
		var desc := "Teaches the %s skill permanently." % skill
		if note != "": desc += " %s" % note
		var m := ItemData.new(id, name, desc, 8000, 1, "manual", "usable")
		m.skill_granted  = skill
		m.usable_in_base = false
		return m

	manuals.append(_mk.call("EliteM",      "Elite Manual",          "Elite"))
	manuals.append(_mk.call("BargainM",    "Bargain Manual",        "Bargain"))
	manuals.append(_mk.call("AmbushM",     "Ambush Manual",         "Ambush"))
	manuals.append(_mk.call("WrathM",      "Wrath Manual",          "Wrath"))
	manuals.append(_mk.call("ContinueM",   "Continue Manual",       "Continue",
		"⚠️ NEW — Continue not in LT. Teaches the Continue skill (extra round if HP > enemy's)."))
	manuals.append(_mk.call("PrayerM",     "Prayer Manual",         "Prayer"))
	manuals.append(_mk.call("AwarenessM",  "Awareness Manual",      "Awareness"))
	manuals.append(_mk.call("SunSwordM",   "Sun Sword Manual",      "Sol"))
	manuals.append(_mk.call("MoonlightM",  "Moonlight Sword Manual","Luna",
		"⚠️ NEW — Was missing from LT project despite being in the spreadsheet."))

	return manuals


# ══════════════════════════════════════════════════════════════════════════════
# E) ITEMS ESPECIALES
# ══════════════════════════════════════════════════════════════════════════════

static func _special() -> Array[ItemData]:
	var specials: Array[ItemData] = []

	# ── Member Card ───────────────────────────────────────────────────────────
	# ⚠️ NUEVO — no estaba en LT. Acceso a la Secret Shop en el castillo.
	# Mecánica: cuando una unidad con Member Card entra en la tienda del castillo,
	# se desbloquea una opción adicional "Secret Shop" con items raros.
	# El item no se gasta al usarse — es una tarjeta permanente.
	var member_card := ItemData.new(
		"MemberCard", "Member Card",
		"Grants access to the Secret Shop at allied castles.",
		0, -1, "special", "on_hold")
	member_card.event_on_use = "UnlockSecretShop"
	# IMPLEMENTACIÓN GODOT:
	# CastleBase.gd verifica si alguna unidad del grupo lleva Member Card.
	# Si sí, muestra la opción "Secret Shop" en el menú de tienda.
	specials.append(member_card)

	# ── Valkyrie Staff ────────────────────────────────────────────────────────
	# Solo en el Home Castle. Revive a un aliado caído.
	# Solo un uso, rarísimo. Exclusivo de BragiHeir.
	var valkyrie := ItemData.new(
		"Valkyrie", "Valkyrie",
		"Use at the home castle to revive a fallen ally. Exclusive to Bragí bloodline.",
		30000, 1, "special", "usable")
	valkyrie.usable_in_base = true
	valkyrie.event_on_use   = "ReviveUnit"
	# IMPLEMENTACIÓN GODOT:
	# - Solo usable en el Home Castle (GameManager.is_home_castle)
	# - Muestra lista de unidades caídas en el capítulo actual
	# - La unidad elegida vuelve con HP completo en el siguiente capítulo
	# - Restricción: prf_tags = ["BragiHeir"] (solo Claud o su línea)
	specials.append(valkyrie)

	# ── Holy Water (staff versión) ─────────────────────────────────────────────
	# El MagicUp de LT es el Holy Water como staff (rango 1, rank C).
	# Se incluye también como item consumible (ya definido en consumibles).
	# Aquí está la versión staff para que los healers lo puedan lanzar.
	var holy_water_staff := ItemData.new(
		"HolyWaterStaff", "M Up Staff",
		"Staff version. Increases target's Magic by 7. Effect decreases by 1 each turn.",
		2200, 5, "special", "usable")
	holy_water_staff.status_applied = "HolyWater"
	# Es un staff: weapon_type = Staff, rank = C, weight = 7, range = 1
	specials.append(holy_water_staff)

	return specials


# ══════════════════════════════════════════════════════════════════════════════
# SISTEMA DE APLICACIÓN — cómo se procesan los efectos en Godot
# ══════════════════════════════════════════════════════════════════════════════
#
# El ItemSystem se encarga de aplicar/retirar efectos cuando un item
# entra o sale del inventario. Para cada unidad, en cada turno y en
# cada cambio de inventario se recalculan los bonuses.

class ItemSystem:

	# Aplica todos los efectos on_hold de los items en el inventario.
	# Llamar al inicio del turno y tras cualquier cambio de inventario.
	static func apply_hold_effects(unit) -> void:
		# Limpiar bonuses de items anteriores primero
		unit.clear_item_bonuses()

		for item: ItemData in unit.inventory:
			if item.hold_type != "on_hold":
				continue

			# Bonus de stats temporales (Speed Ring +5 SPD etc.)
			for stat in item.stat_bonus:
				unit.add_item_bonus(stat, item.stat_bonus[stat])

			# Skills otorgadas por el item
			if item.skill_granted != "":
				for skill_id in item.skill_granted.split(","):
					skill_id = skill_id.strip_edges()
					if skill_id != "" and not unit.has_skill(skill_id):
						unit.add_temporary_skill(skill_id, item.id)

	# Retira todos los skills y bonuses otorgados por items
	static func remove_hold_effects(unit) -> void:
		unit.clear_item_bonuses()
		unit.remove_temporary_skills_by_source("item")

	# Usa un item consumible sobre un objetivo
	static func use_item(user, target, item: ItemData) -> bool:
		if item.uses == 0:
			return false

		match item.hold_type:
			"usable":
				return _execute_use(user, target, item)
		return false

	static func _execute_use(user, target, item: ItemData) -> bool:
		var success := false

		# Curación por porcentaje
		if item.heal_percent > 0.0:
			var heal_amount := int(target.max_hp * item.heal_percent)
			target.heal(heal_amount)
			success = true

		# Curación fija
		if item.heal_flat > 0:
			target.heal(item.heal_flat)
			success = true

		# Status aplicado (Holy Water, Antidote, TorchVision...)
		if item.status_applied != "":
			success = _apply_status(target, item.status_applied)

		# Mejora permanente de stats (stat boosters)
		if not item.stat_permanent.is_empty():
			for stat in item.stat_permanent:
				target.increase_stat_permanently(stat, item.stat_permanent[stat])
			success = true

		# Enseñar skill (manuales)
		if item.skill_granted != "" and item.category == "manual":
			for skill_id in item.skill_granted.split(","):
				skill_id = skill_id.strip_edges()
				if not target.has_skill(skill_id):
					target.learn_skill(skill_id)
			success = true

		# Evento especial (Return Ring, Valkyrie, Promotion...)
		if item.event_on_use != "":
			success = _fire_event(user, target, item.event_on_use)

		# Gastar uso
		if success and item.uses > 0:
			item.uses -= 1

		return success

	static func _apply_status(target, status_id: String) -> bool:
		match status_id:
			"CurePoison":
				target.remove_status("Poison")
				return true
			"HolyWater":
				# Aplica status temporal con stat_change decreciente
				# El status gestiona su propio decremento por turno
				target.apply_status(status_id, {"MAG": 7, "decay_per_turn": 1})
				return true
			"TorchVision":
				target.apply_status(status_id, {"fow_radius": 10, "decay_per_turn": 1})
				return true
			_:
				target.apply_status(status_id, {})
				return true

	static func _fire_event(user, target, event_id: String) -> bool:
		# El GameManager escucha esta señal y ejecuta el evento correspondiente
		# Eventos implementados:
		#   ReturnToHomeCastle  — teleporta al portador al Home Castle
		#   UnlockAdjacent      — abre puerta/cofre/puente adyacente
		#   PromoteUnit         — inicia la pantalla de promoción
		#   ReviveUnit          — inicia la selección de unidad caída
		#   UnlockSecretShop    — activa la opción Secret Shop en la tienda
		var tree := Engine.get_main_loop() as SceneTree
		var gm = tree.root.get_node_or_null("GameManager") if tree else null
		if gm:
			gm.trigger_item_event(event_id, user, target)
			return true
		push_warning("ItemSystem: GameManager no disponible para evento '%s'" % event_id)
		return false


# ══════════════════════════════════════════════════════════════════════════════
# NOTAS DE IMPLEMENTACIÓN — Items nuevos respecto a LT
# ══════════════════════════════════════════════════════════════════════════════
#
# Los siguientes items no existían en el proyecto LT por limitaciones del engine.
# En Godot son perfectamente implementables:
#
# 1. HOLY WATER (item consumible)
#    LT tenía MagicUp como staff pero no como item consumible de inventario.
#    En Godot: status con stat_change {MAG: +7} y decay_per_turn: -1.
#    La unidad debe restar 1 MAG del bonus al inicio de cada turno hasta 0.
#
# 2. ANTIDOTE
#    LT no tenía sistema de Poison implementado.
#    En Godot: el status Poison hace perder HP al inicio de cada turno.
#    Antidote elimina ese status con remove_status("Poison").
#
# 3. BODY RING / BODY TALISMAN (+CON permanente)
#    LT no podía modificar CON permanentemente.
#    En Godot: CON es un stat normal, increase_stat_permanently("CON", 3).
#
# 4. LUCK RING / LUCK TALISMAN (+LCK permanente)
#    No estaba en el proyecto LT a pesar de aparecer en el spreadsheet.
#    Mismo sistema que los demás stat boosters.
#
# 5. MEMBER CARD
#    LT no tenía Secret Shop implementada.
#    En Godot: CastleBase.gd verifica if any(unit.has_item("MemberCard"))
#    antes de mostrar el botón "Secret Shop" en la UI de tienda.
#
# 6. CONTINUE MANUAL
#    Continue no estaba implementada como skill en LT.
#    En Godot: Continue = si HP del atacante > HP del defensor Y AS atacante
#    > AS defensor, inicia una ronda extra de combate (similar a Charge
#    pero sin requerir la victoria del round anterior).
#
# 7. MOONLIGHT SWORD MANUAL
#    Aparece en el spreadsheet pero no estaba en el proyecto LT.
#    En Godot: igual que los demás manuales, aplica skill "Luna".
#
# 8. PURSUIT RING (redefinido)
#    Pursuit es mecánica global en este proyecto.
#    El ring da +2 AS en su lugar (valor coleccionable / vendible).
