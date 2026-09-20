extends RefCounted
const Cards := preload("res://core/expedition/class_card_catalog.gd")
const Effects := preload("res://core/expedition/card_ecosystem_effects.gd")


## Only new card runs opt in. Factory units are already independent of authored assets.
static func apply(unit: UnitData, node: Dictionary) -> void:
	var depth := int(node.depth)
	if depth < 5 or depth == 20:
		return
	var role := str(unit.tactical_role_id).trim_prefix("catabase_evolution_")
	if not CatabaseMonsterEvolutionCatalog.ROLE_FAMILIES.has(StringName(role)):
		return
	unit.spells = unit.spells.duplicate()
	unit.max_hp = roundi(unit.max_hp * (1.0 if depth < 7 else 1.15))
	unit.attack_power = roundi(unit.attack_power * (1.0 if depth < 7 else 1.08))
	var technique := ""
	match role:
		"sentinelle", "brute", "champion":
			technique = "g_prison"
		"rabatteur", "deplaceur":
			technique = "g_hook"
		"porte_egide", "protecteur":
			technique = "g_bastion"
		"executeur":
			technique = "a_reap"
		"rejeton", "fondeur", "artilleur", "conducteur":
			technique = "t_flamewall"
		"molosse", "chasseur", "alpha":
			technique = "a_venom"
		"lamie", "oracle":
			technique = "t_charm"
		"tisseuse":
			technique = "t_glacier"
		"archer", "traqueur", "guetteur":
			technique = "r_caltrop"
		"collecteur":
			technique = "t_disrupt"
	if technique != "":
		var spell := Cards.make_spell(technique)
		spell.cooldown_activations = maxi(2, spell.cooldown_activations)
		spell.once_per_activation = true
		# Native terrain exposes hazards to the common tactical scorer.
		if technique == "t_flamewall":
			spell.terrain_effect = Effects.surface("fire_field", .35)
			spell.terrain_effect.damage = maxi(1, roundi(unit.attack_power * .35))
			spell.modifiers = []
		unit.spells.append(spell)
		unit.presentation_summary += "\n" + spell.spell_name + " : " + spell.description
	if role in ["officiant", "guerisseur"] and depth >= 5:
		unit.spells.append(_summon(unit, node))
		unit.presentation_summary += "\nAppelle un serviteur après une activation : occupez la dalle annoncée pour bloquer l'invocation."
	unit.description = unit.presentation_summary
	unit.active_spell_slots = unit.spells.size()


static func _summon(caster: UnitData, node: Dictionary) -> Spell:
	var minion := CatabaseMonsterEvolutionCatalog.build_unit(&"serviteur", node)
	minion.team = caster.team
	minion.max_hp = maxi(15, roundi(caster.max_hp * .25))
	minion.attack_power = maxi(5, roundi(caster.attack_power * .65))
	var spell := Spell.new()
	spell.spell_id = &"ecosystem_call_servant"
	spell.spell_name = "Appel du passeur"
	spell.description = "Invoque un serviteur à la prochaine activation sur la dalle annoncée. Occuper cette dalle interrompt l'appel. Recharge 4 activations ; 6 ennemis vivants maximum."
	spell.ap_cost = 3
	spell.spell_range = 3
	spell.minimum_range = 1
	spell.can_target_enemy = false
	spell.can_target_free_cell = true
	spell.cooldown_activations = 4
	spell.once_per_activation = true
	spell.delayed_resolution = Spell.DelayedResolution.SUMMON
	spell.telegraph_label = "Serviteur à la prochaine activation"
	spell.summon_unit_data = minion
	spell.summon_max_living_team = 6
	spell.summon_type = &"ecosystem_servant"
	spell.icon = Cards.icon("t_hex")
	return spell
