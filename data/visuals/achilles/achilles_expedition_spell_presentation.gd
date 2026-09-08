class_name AchillesExpeditionSpellPresentation
extends RefCounted

## Presentation whitelist for the actual expedition catalog. Original exp_* IDs
## remain authoritative; no catalog instantiation, copied Spell or rule mutation.
const ARCHETYPES := {
	&"achilles_peleid_strike": [
		&"exp_frappe_ouverte", &"exp_crochet", &"exp_crochet_mutation", &"exp_crochet_legend",
		&"exp_fauchage", &"exp_fauchage_signature", &"exp_entaille", &"exp_entaille_mutation",
		&"exp_entaille_legend", &"exp_moisson", &"exp_moisson_signature",
		&"exp_contretemps", &"exp_contretemps_signature", &"exp_heurt",
		&"exp_heurt_mutation", &"exp_heurt_legend", &"exp_tempest", &"exp_serment_brasier",
	],
	&"achilles_pelion_shot": [
		&"exp_tir_de_guet", &"exp_rupture", &"exp_rupture_mutation", &"exp_rupture_legend",
		&"exp_marque", &"exp_marque_signature", &"exp_braise", &"exp_braise_mutation",
		&"exp_braise_legend", &"exp_givre", &"exp_givre_signature", &"exp_foudre",
	],
	&"achilles_fulminant_dash": [
		&"exp_feinte", &"exp_feinte_mutation", &"exp_feinte_legend",
		&"exp_marche", &"exp_marche_signature",
	],
	&"achilles_bronze_guard": [
		&"exp_garde_eaque", &"exp_posture", &"exp_posture_signature",
		&"exp_souffle", &"exp_souffle_mutation", &"exp_souffle_legend", &"exp_serment_rempart",
	],
}


static func inherited_id(spell_id: StringName) -> StringName:
	for canonical in ARCHETYPES:
		if (ARCHETYPES[canonical] as Array).has(spell_id):
			return canonical
	return spell_id


static func is_expedition_spell(spell_id: StringName) -> bool:
	return inherited_id(spell_id) != spell_id


static func apply_geometry(result: Dictionary, spell: Spell) -> void:
	if spell == null or not is_expedition_spell(spell.get_effective_spell_id()):
		return
	result["expedition_spell"] = true
	result["palette_variant"] = &"base"
	# Historical reactive nodes target canonical IDs, not these learned cards.
	if result.variant in [&"bastion", &"rampart"]:
		result["variant"] = &"base"
		result["effect_variant"] = result.action_family
	result["native_aoe_shape"] = spell.aoe_shape
	result["native_aoe_size"] = spell.aoe_size
	result["native_line_from_caster"] = spell.line_from_caster
	# Native LINE/CROSS comes from SpellCaster's AoE, not a mastery cap.
	# Keep piercing_enabled/maximum_targets untouched; they still describe
	# the mastery profile and must not be mistaken for new combat rules.
	if spell.aoe_shape != Spell.AoeShape.SINGLE:
		result["target_geometry_source"] = &"native_spell"
		result["target_count_policy"] = &"native_area"
		result["target_shape"] = [&"SINGLE", &"CROSS", &"SQUARE", &"LINE"][spell.aoe_shape]
	if result.action_family == &"strike" and spell.aoe_shape != Spell.AoeShape.SINGLE:
		result["animation_stem"] = &"sweep"
		result["variant"] = &"sweep"
		result["gesture_variant"] = &"area_sweep"
		result["effect_variant"] = &"strike_sweep"
	elif result.action_family == &"shot":
		if spell.aoe_shape == Spell.AoeShape.LINE:
			var powerful := spell.get_effective_spell_id() in [&"exp_rupture_legend", &"exp_foudre"]
			result["animation_stem"] = &"bow_death" if powerful else &"bow_piercing"
			result["variant"] = &"death_line" if powerful else &"piercing"
		elif spell.aoe_shape in [Spell.AoeShape.CROSS, Spell.AoeShape.SQUARE]:
			result["animation_stem"] = &"volley"
			result["variant"] = &"elemental_area"
		elif spell.get_effective_spell_id() in [&"exp_marque_signature", &"exp_givre_signature"]:
			# A steadier kneeling aim, not a claim that these single hits pierce.
			result["animation_stem"] = &"bow_piercing"
	elif result.action_family == &"dash":
		result["gesture_variant"] = &"leap" if not spell.movement_requires_clear_path else &"advance"
	elif result.action_family == &"guard":
		result["gesture_variant"] = &"restore" if spell.heal > 0 else &"brace"


static func apply_effects(result: Dictionary, spell: Spell) -> void:
	if spell == null or not is_expedition_spell(spell.get_effective_spell_id()):
		return
	var spell_id := spell.get_effective_spell_id()
	if spell_id in [&"exp_marque", &"exp_marque_signature"]:
		result["projectile_variant"] = &"marked_shot"
		result["projectile_animation"] = &"arrow_reach"
		result["impact_animation"] = &"impact_reach"
		result["gesture_variant"] = &"marked_aim"
		result["effect_variant"] = &"arrow_marked"
		result["projectile_trail_count"] = 1
	# Element is read from the actual Spell, never guessed from its name or
	# from a selected but untriggered bonus. Character colors stay unchanged.
	if spell.element == Spell.Element.FIRE:
		result["effects_source"] = &"paris"
		result["projectile_variant"] = &"fire"
		result["projectile_animation"] = &"fire"
		result["impact_animation"] = &"hellfire"
		result["effect_variant"] = &"fire_area" if spell.aoe_shape != Spell.AoeShape.SINGLE else &"fire_shot"
		result["projectile_trail_count"] = 0
		if result.action_family == &"strike":
			result["aux_burst_animation"] = &"hellfire"
	elif spell.element == Spell.Element.ICE:
		result["effects_source"] = &"paris"
		result["projectile_variant"] = &"ice"
		result["projectile_animation"] = &"frost"
		result["impact_animation"] = &"frost"
		result["effect_variant"] = &"ice_shot"
		result["projectile_trail_count"] = 0
	elif spell.element == Spell.Element.LIGHTNING:
		result["effects_source"] = &"lightning"
		result["projectile_variant"] = &"lightning"
		result["projectile_animation"] = &"arrow_lightning"
		result["impact_animation"] = &"impact_lightning"
		result["effect_variant"] = &"lightning_line"
		result["projectile_trail_count"] = 0
	if spell.is_healing():
		result["heal_animation"] = &"heal"
	for modifier in spell.modifiers:
		if modifier is ExpeditionSpellModifier:
			var expedition_modifier := modifier as ExpeditionSpellModifier
			if expedition_modifier.heal_fraction > 0.0 or expedition_modifier.lifesteal_fraction > 0.0:
				result["heal_animation"] = &"heal"
				break
