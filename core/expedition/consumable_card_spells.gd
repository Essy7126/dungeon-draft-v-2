extends RefCounted
const Catalog := preload("res://core/expedition/consumable_card_catalog.gd")
const LegacyIcons := preload("res://core/expedition/class_card_catalog.gd")
const ICONS := {
	"n01": "a_pierce",
	"n02": "a_parry",
	"n03": "r_step",
	"n04": "a_push",
	"n05": "a_dagger",
	"n06": "r_mark",
	"n07": "a_hamstring",
	"n08": "t_mark",
	"a01": "a_open",
	"a02": "a_finish",
	"a03": "a_cut",
	"a04": "a_ambush",
	"a05": "a_escape",
	"a06": "a_execute",
	"a07": "a_pierce",
	"a08": "a_blind",
	"a09": "t_weak",
	"g01": "g_guard",
	"g02": "g_hit",
	"g03": "g_push",
	"g04": "g_pull",
	"g05": "g_riposte",
	"g06": "g_crush",
	"g07": "g_punish",
	"g08": "g_wall",
	"g09": "g_sweep",
	"r01": "r_move",
	"r02": "r_push",
	"r03": "r_slow",
	"r04": "r_fan",
	"r05": "r_escape",
	"r06": "r_fan",
	"r07": "r_pull",
	"r08": "r_step",
	"r09": "r_long",
	"t01": "t_frost",
	"t02": "t_burn",
	"t03": "t_mark",
	"t04": "t_ice",
	"t05": "t_fire",
	"t06": "t_ice",
	"t07": "t_touch",
	"t08": "t_pull",
	"t09": "t_hex",
	"l01": "t_storm",
	"l02": "t_guard",
	"d01": "g_wall",
	"i01": "t_escape",
	"fallback_strike": "a_pierce",
	"fallback_guard": "a_parry",
}


static func definition(id: String, upgraded := false) -> Dictionary:
	if id == "fallback_strike":
		return {
			"id": id,
			"runtimeId": "cc2_" + id,
			"name": "Attaque de secours",
			"ap": 1,
			"min": 1,
			"max": 1,
			"damage": .28,
			"amount": 0,
			"op": "hit",
			"shape": "single",
			"type": "physical",
			"fallback": true,
			"baseText": "0,28 P physiques. Une fois par tour, hors pioche.",
		}
	if id == "fallback_guard":
		return {
			"id": id,
			"runtimeId": "cc2_" + id,
			"name": "Garde de secours",
			"ap": 1,
			"min": 0,
			"max": 0,
			"damage": 0,
			"amount": .25,
			"op": "guard",
			"shape": "single",
			"type": "physical",
			"fallback": true,
			"baseText": "0,25 P de garde. Une fois par tour, hors pioche.",
		}
	return Catalog.card(id, upgraded)


static func make_spell(id: String, upgraded := false) -> Spell:
	var row := definition(id, upgraded)
	if row.is_empty():
		return null
	var spell := Spell.new()
	spell.spell_id = StringName(row.runtimeId)
	spell.spell_name = str(row.name) + (" •" if upgraded else "")
	spell.ap_cost = int(row.ap)
	spell.minimum_range = int(row.min)
	spell.spell_range = int(row.max)
	spell.once_per_activation = true
	spell.damage_type = Spell.DamageType.PHYSICAL
	if row.type == "magic":
		spell.damage_type = Spell.DamageType.MAGICAL
	spell.damage_scaling = LegacyIcons.scaling(float(row.damage))
	spell.can_target_self = int(row.max) == 0
	spell.can_target_enemy = not spell.can_target_self
	spell.exclude_allies_from_area_effects = row.shape != "single"
	if row.shape == "cross":
		spell.aoe_shape = Spell.AoeShape.CROSS
		spell.aoe_size = 1
		spell.can_target_free_cell = true
	if row.op in ["move", "blink"]:
		spell.can_target_enemy = false
		spell.can_target_free_cell = true
		spell.caster_movement = Spell.CasterMovement.TARGET_CELL
		spell.movement_requires_clear_path = row.op == "move"
		spell.needs_line_of_sight = row.op != "blink"
	if row.op in ["firefield", "icefield"] or row.shape == "line3_perpendicular":
		spell.can_target_free_cell = true
	if row.op in ["burn", "firefield"]:
		spell.element = Spell.Element.FIRE
	elif row.op == "icefield" or row.id == "t01":
		spell.element = Spell.Element.ICE
	var modifier := preload("res://core/expedition/consumable_card_modifier.gd").new()
	modifier.card = row
	spell.modifiers.append(modifier)
	spell.icon = LegacyIcons.icon(str(ICONS[row.id]))
	spell.description = str(row.get("upgradeText" if upgraded else "baseText", "")) + "\n" + (
		"Hors deck." if row.get("fallback", false) else "Copie consommée pour cette traversée. Une fois par famille et par tour."
	)
	return spell
