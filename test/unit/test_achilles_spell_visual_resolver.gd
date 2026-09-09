extends GutTest

const Resolver = preload("res://data/visuals/achilles/achilles_spell_visual_resolver.gd")
const CATALOG: MasteryCatalogData = preload("res://data/characters/achilles/doctrines/achilles_mastery_catalog.tres")
const STRIKE: Spell = preload("res://data/spells/achilles/peleid_strike.tres")
const DASH: Spell = preload("res://data/spells/achilles/fulminant_dash.tres")
const SHOT: Spell = preload("res://data/spells/achilles/pelion_shot.tres")
const GUARD: Spell = preload("res://data/spells/achilles/bronze_guard.tres")


func test_four_canonical_techniques_have_distinct_body_families() -> void:
	var cases := [
		[STRIKE, &"strike", &"attack", false],
		[DASH, &"dash", &"dash", true],
		[SHOT, &"shot", &"bow", false],
		[GUARD, &"guard", &"guard", false],
	]
	for entry in cases:
		var spell := entry[0] as Spell
		var result := Resolver.resolve(spell)
		assert_eq(result.action_family, entry[1])
		assert_eq(result.animation_stem, entry[2])
		assert_eq(result.movement, entry[3])
		assert_eq(result.variant, &"base")
		assert_eq(result.spell_id, spell.get_effective_spell_id())
		assert_eq(result.inherited_spell_id, spell.get_effective_spell_id())


func test_legacy_spell_aliases_keep_guard_dash_estoc_and_sweep() -> void:
	var cases := [
		[&"achilles_guard", &"guard", &"guard", Resolver.GUARD],
		[&"achilles_advance", &"dash", &"dash", Resolver.DASH],
		[&"achilles_spear_thrust", &"strike", &"attack", Resolver.STRIKE],
		[&"achilles_sweep", &"strike", &"sweep", Resolver.STRIKE],
	]
	for entry in cases:
		var legacy := Spell.new()
		legacy.spell_id = entry[0]
		var result := Resolver.resolve(legacy)
		assert_eq(result.spell_id, entry[0], "The original identity is preserved for gameplay.")
		assert_eq(result.action_family, entry[1])
		assert_eq(result.animation_stem, entry[2])
		assert_eq(result.inherited_spell_id, entry[3])


func test_sourced_spell_copy_keeps_its_canonical_presentation_identity() -> void:
	var copied := SHOT.duplicate(true) as Spell
	copied.spell_name = "Libellé localisé de test"
	assert_eq(copied.resource_path, "")
	var result := Resolver.resolve(copied)
	assert_eq(result.spell_id, Resolver.SHOT)
	assert_eq(result.animation_stem, &"bow")
	assert_eq(result.action_family, &"shot")


func test_scourge_uses_resolved_two_cell_strike_geometry() -> void:
	var unit := _unit_with([&"achilles_wrath_scourge_of_troy"])
	var result := Resolver.resolve(STRIKE, unit)
	assert_eq(result.spell_id, Resolver.STRIKE)
	assert_eq(result.variant, &"scourge")
	assert_eq(result.animation_stem, &"sweep")
	assert_eq(result.effect_variant, &"strike_line")
	assert_eq([result.target_shape, result.maximum_targets], [&"LINE", 2])
	assert_false(result.piercing_enabled)
	assert_true(result.profile_source_ids.has(&"achilles_wrath_scourge_of_troy"))


func test_piercing_and_death_line_use_dedicated_bow_actions_and_projectiles() -> void:
	var unit := _unit_with([&"achilles_chiron_piercing_arrow"])
	var piercing := Resolver.resolve(SHOT, unit)
	assert_eq(piercing.animation_stem, &"bow_piercing")
	assert_eq(piercing.variant, &"piercing")
	assert_eq(piercing.maximum_targets, 2)
	assert_eq(piercing.effect_variant, &"arrow_piercing")
	unit.mastery_nodes.append(_node(&"achilles_chiron_death_line"))
	var line := Resolver.resolve(SHOT, unit)
	assert_eq(line.animation_stem, &"bow_death")
	assert_eq(line.variant, &"death_line")
	assert_eq(line.maximum_targets, 3)
	assert_true(line.piercing_enabled)
	assert_eq(line.effect_variant, &"arrow_death_line")
	assert_eq(line.spell_id, Resolver.SHOT)


func test_volley_replaces_selected_lower_tier_piercing_presentation() -> void:
	var unit := _unit_with([&"achilles_chiron_piercing_arrow", &"achilles_chiron_centaur_volley"])
	var result := Resolver.resolve(SHOT, unit)
	assert_eq(result.variant, &"volley")
	assert_eq(result.animation_stem, &"volley")
	assert_eq(result.effect_variant, &"arrow_volley")
	assert_eq(result.target_shape, &"FAN")
	assert_eq([result.minimum_range, result.maximum_range, result.maximum_targets], [2, 5, 3])
	assert_false(result.piercing_enabled)


func test_rampart_reuses_guard_body_without_replacing_personal_target_shape() -> void:
	var unit := _unit_with([&"achilles_aeacus_myrmidon_rampart"])
	var result := Resolver.resolve(GUARD, unit)
	assert_eq(result.animation_stem, &"guard")
	assert_eq(result.variant, &"rampart")
	assert_eq(result.effect_variant, &"guard_rampart")
	assert_eq(result.target_shape, &"SINGLE", "The three barrier cells are a separate effect, not the guard cast area.")
	assert_eq(result.inherited_spell_id, Resolver.GUARD)
	assert_eq(result.palette_variant, &"aeacus")


func test_bastion_requires_a_remaining_guard_source_not_an_unrelated_shield() -> void:
	var unit := _unit_with([&"achilles_aeacus_mobile_bastion"])
	unit.add_sourced_shield(&"unrelated", 20)
	assert_eq(Resolver.resolve(DASH, unit).variant, &"base")
	unit.add_sourced_shield(&"guard_test", 10, null, {"tags": [&"guard"]})
	var result := Resolver.resolve(DASH, unit)
	assert_eq(result.variant, &"bastion")
	assert_eq(result.animation_stem, &"dash")
	assert_eq(result.effect_variant, &"dash_bastion")
	assert_true(result.movement)
	assert_true(result.guard_active)
	unit.consume_shield_source(&"guard_test", 10)
	assert_eq(unit.current_shield, 20)
	assert_eq(Resolver.resolve(DASH, unit).variant, &"base")


func test_range_stance_and_summit_keep_bow_while_exposing_effective_range() -> void:
	var unit := _unit_with([&"achilles_chiron_pelion_reach", &"achilles_summit_chiron"])
	var result := Resolver.resolve(SHOT, unit)
	assert_eq(result.animation_stem, &"bow")
	assert_eq(result.variant, &"base")
	assert_eq([result.minimum_range, result.maximum_range], [3, 9])
	assert_eq(result.palette_variant, &"chiron")
	assert_eq(result.intensity_tier, 2)
	assert_true(result.selected_doctrine_ids.has(&"achilles_lesson_of_chiron"))
	assert_true(result.selected_mastery_ids.has(&"achilles_summit_chiron"))


func test_other_summits_do_not_invent_new_body_actions() -> void:
	var wrath := Resolver.resolve(STRIKE, _unit_with([&"achilles_summit_wrath"]))
	assert_eq(wrath.animation_stem, &"attack")
	assert_eq(wrath.palette_variant, &"wrath")
	assert_eq(wrath.intensity_tier, 2)
	var guard := Resolver.resolve(GUARD, _unit_with([&"achilles_summit_aeacus"]))
	assert_eq(guard.animation_stem, &"guard")
	assert_eq(guard.palette_variant, &"aeacus")
	assert_eq(guard.intensity_tier, 2)


func test_supplied_resolved_profile_wins_without_mutating_profile_or_actor() -> void:
	var unit := _unit_with([&"achilles_chiron_centaur_volley"])
	unit.grid_pos = Vector2i(4, 3)
	unit.current_ap = 5
	unit.current_mp = 2
	unit.add_sourced_shield(&"guard_test", 7, null, {"tags": [&"guard"]})
	var profile := {
		"target_shape": &"LINE", "maximum_targets": 3,
		"piercing_enabled": true, "minimum_range": 0, "maximum_range": 11,
		"sources": [&"achilles_chiron_death_line"],
	}
	var profile_before := profile.duplicate(true)
	var nodes_before := unit.mastery_nodes.duplicate()
	var shields_before := unit.get_shield_instances_snapshot()
	var result := Resolver.resolve(SHOT, unit, profile)
	assert_eq(result.variant, &"death_line")
	assert_eq([result.minimum_range, result.maximum_range], [0, 11])
	assert_eq(result.animation_stem, &"bow_death")
	(result.profile_source_ids as Array).append(&"caller_local_change")
	(result.selected_mastery_ids as Array).clear()
	assert_eq(profile, profile_before)
	assert_eq(unit.mastery_nodes, nodes_before)
	assert_eq(unit.get_shield_instances_snapshot(), shields_before)
	assert_eq([unit.current_ap, unit.current_mp, unit.grid_pos], [5, 2, Vector2i(4, 3)])
	assert_eq(SHOT.spell_range, 6)
	assert_null(unit.mastery_combat_adapter, "The resolver does not instantiate a combat adapter.")


func test_profile_sources_can_describe_a_rampart_without_a_live_actor() -> void:
	var result := Resolver.resolve(GUARD, null, {"sources": [&"achilles_aeacus_myrmidon_rampart.barrier"]})
	assert_eq(result.variant, &"rampart")
	assert_eq(result.animation_stem, &"guard")
	assert_true(result.selected_mastery_ids.is_empty())


func test_null_and_unknown_spells_have_safe_generic_presentation() -> void:
	var empty := Resolver.resolve(null)
	assert_eq(empty.spell_id, &"")
	assert_eq(empty.action_family, &"generic")
	assert_false(empty.movement)
	var unknown := Spell.new()
	unknown.spell_id = &"another_character_spell"
	var result := Resolver.resolve(unknown)
	assert_eq(result.spell_id, &"another_character_spell")
	assert_eq(result.action_family, &"generic")
	assert_eq(result.animation_stem, &"attack")


## These are isolated presentation fixtures. Legal purchase paths are exercised
## by the Champion suite; the resolver consumes an already selected build.
func _unit_with(ids: Array[StringName]) -> Unit:
	var unit := Unit.new("Achille", 0, 110, 14, 6, 3, 18)
	for node_id in ids:
		unit.mastery_nodes.append(_node(node_id))
	return unit


func _node(node_id: StringName) -> SkillTreeNodeData:
	return CATALOG.node_catalog().get(node_id) as SkillTreeNodeData


func test_arrow_stances_have_distinct_physical_projectiles_without_elemental_rules() -> void:
	var plain := Resolver.resolve(SHOT)
	var reach := Resolver.resolve(SHOT, _unit_with([&"achilles_chiron_pelion_reach"]))
	var heavy := Resolver.resolve(SHOT, _unit_with([&"achilles_chiron_close_shot"]))
	assert_eq(plain.projectile_animation, &"arrow")
	assert_eq(plain.projectile_variant, &"bronze")
	assert_eq(reach.projectile_animation, &"arrow_reach")
	assert_eq(reach.impact_animation, &"impact_reach")
	assert_eq(reach.gesture_variant, &"bow_aimed")
	assert_eq(heavy.projectile_animation, &"arrow_heavy")
	assert_eq(heavy.impact_animation, &"impact_heavy")
	assert_eq(heavy.push_distance, 1)
	assert_eq(heavy.gesture_variant, &"bow_heavy")
	assert_eq([plain.animation_stem, reach.animation_stem, heavy.animation_stem], [&"bow", &"bow", &"bow"])
	assert_eq(SHOT.damage_type, 0, "Physical arrows do not acquire a cosmetic fire/ice status.")


func test_geometric_evolutions_override_lower_arrow_stances() -> void:
	var cases := [
		[&"achilles_chiron_piercing_arrow", &"bow_piercing", &"arrow_piercing", &"impact_piercing", 2],
		[&"achilles_chiron_death_line", &"bow_death", &"arrow_death_line", &"impact_death_line", 3],
		[&"achilles_chiron_centaur_volley", &"volley", &"arrow_volley", &"impact_volley", 1],
	]
	for entry in cases:
		var result := Resolver.resolve(SHOT, _unit_with([&"achilles_chiron_close_shot", entry[0]]))
		assert_eq(result.animation_stem, entry[1])
		assert_eq(result.projectile_animation, entry[2])
		assert_eq(result.impact_animation, entry[3])
		assert_eq(result.projectile_trail_count, entry[4])
		assert_eq(result.spell_id, SHOT.spell_id, "This remains an evolution of the canonical spell.")


func test_numeric_and_conditional_masteries_do_not_claim_an_activated_effect() -> void:
	var eye := Resolver.resolve(SHOT, _unit_with([&"achilles_chiron_centaur_eye"]))
	var mobile := Resolver.resolve(SHOT, _unit_with([&"achilles_chiron_mobile_hunt"]))
	var stopping := Resolver.resolve(SHOT, _unit_with([&"achilles_chiron_stopping_arrow"]))
	for result in [eye, mobile, stopping]:
		assert_eq(result.projectile_variant, &"bronze")
		assert_eq(result.projectile_animation, &"arrow")
		assert_eq(result.impact_animation, &"impact")
	assert_true(stopping.stopping_arrow_selected)
	assert_false(stopping.has("control_applied"), "Buying a conditional mastery is not a confirmed control hit.")
	var override := Resolver.resolve(SHOT, _unit_with([&"achilles_chiron_close_shot"]), {"push_distance": 0})
	assert_eq(override.projectile_variant, &"bronze", "Resolved rules win over a still selected node.")


func test_context_freezes_real_alternate_origin_and_never_mutates_the_input() -> void:
	var original := Resolver.resolve(SHOT)
	var before := original.duplicate(true)
	var result := Resolver.with_cast_context(original, Vector2i(1, 1), Vector2i(6, 1), Vector2i(3, 1))
	assert_eq(result.origin_cell, Vector2i(1, 1))
	assert_eq(result.cell, Vector2i(6, 1))
	assert_eq(result.caster_cell, Vector2i(3, 1))
	assert_eq(result.cast_distance, 5)
	assert_true(result.alternate_origin)
	assert_eq(original, before)
	var regular := Resolver.with_cast_context(original, Vector2i(3, 1), Vector2i(6, 1), Vector2i(3, 1))
	assert_eq(regular.cast_distance, 3)
	assert_false(regular.alternate_origin)


func test_actual_expedition_catalog_has_no_unmapped_achilles_spell() -> void:
	var catalog := ExpeditionBuildCatalog.new()
	var expedition_count := 0
	for spell in catalog.all_spells():
		var before := _expedition_payload(spell)
		var result := Resolver.resolve(spell)
		assert_ne(result.action_family, &"generic", String(spell.spell_id))
		assert_eq(result.spell_id, spell.get_effective_spell_id(), "Presentation never replaces persistence/combat IDs.")
		assert_true(String(result.inherited_spell_id).begins_with("achilles_"))
		assert_eq(_expedition_payload(spell), before, "Resolving does not alter the actual catalog resource.")
		if String(spell.spell_id).begins_with("exp_"):
			expedition_count += 1
			assert_true(result.expedition_spell)
	assert_eq(expedition_count, 42, "Every actual expedition ID is covered; new catalog entries need an explicit review.")
	var unrelated := Spell.new()
	unrelated.spell_id = &"exp_unknown_future_spell"
	assert_eq(Resolver.resolve(unrelated).action_family, &"generic", "An exp_ prefix alone cannot claim Achilles art.")


func test_expedition_roots_and_hunter_forms_use_actual_payload_geometry() -> void:
	var catalog := ExpeditionBuildCatalog.new()
	var cases := [
		["exp_frappe_ouverte", &"strike", &"attack", &"arrow", &"impact"],
		["exp_tir_de_guet", &"shot", &"bow", &"arrow", &"impact"],
		["exp_garde_eaque", &"guard", &"guard", &"arrow", &"impact"],
		["exp_rupture", &"shot", &"bow", &"arrow_heavy", &"impact_heavy"],
		["exp_rupture_mutation", &"shot", &"bow_piercing", &"arrow_piercing", &"impact_piercing"],
		["exp_rupture_legend", &"shot", &"bow_death", &"arrow_death_line", &"impact_death_line"],
		["exp_marque", &"shot", &"bow", &"arrow_reach", &"impact_reach"],
		["exp_marque_signature", &"shot", &"bow_piercing", &"arrow_reach", &"impact_reach"],
	]
	for entry in cases:
		var spell := catalog.get_spell(entry[0])
		var result := Resolver.resolve(spell)
		assert_eq([result.action_family, result.animation_stem, result.projectile_animation, result.impact_animation],
			[entry[1], entry[2], entry[3], entry[4]], entry[0])
		assert_eq(result.push_distance, spell.push_distance, "The pushing base and non-pushing line forms remain distinct.")
		if spell.aoe_shape == Spell.AoeShape.LINE:
			assert_eq(result.target_shape, &"LINE")
			assert_eq(result.target_geometry_source, &"native_spell")
			assert_eq(result.target_count_policy, &"native_area")
			assert_false(result.piercing_enabled, "Native AoE lines must not invent a mastery piercing rule.")


func test_expedition_area_movement_and_restore_keep_different_body_families() -> void:
	var catalog := ExpeditionBuildCatalog.new()
	for id in ["exp_fauchage", "exp_fauchage_signature", "exp_moisson_signature",
		"exp_heurt_legend", "exp_tempest", "exp_serment_brasier"]:
		var result := Resolver.resolve(catalog.get_spell(id))
		assert_eq([result.action_family, result.animation_stem, result.target_shape], [&"strike", &"sweep", &"CROSS"], id)
	for id in ["exp_feinte", "exp_feinte_mutation", "exp_feinte_legend", "exp_marche", "exp_marche_signature"]:
		var result := Resolver.resolve(catalog.get_spell(id))
		assert_eq([result.action_family, result.animation_stem, result.movement], [&"dash", &"dash", true], id)
	for id in ["exp_posture", "exp_posture_signature", "exp_souffle",
		"exp_souffle_mutation", "exp_souffle_legend", "exp_serment_rempart"]:
		var result := Resolver.resolve(catalog.get_spell(id))
		assert_eq([result.action_family, result.animation_stem], [&"guard", &"guard"], id)
	for id in ["exp_contretemps", "exp_contretemps_signature"]:
		var spell := catalog.get_spell(id)
		var result := Resolver.resolve(spell)
		assert_eq(result.animation_stem, &"attack", "Melee strike precedes the authoritative teleport.")
		assert_true(spell.teleport_behind_target)
		assert_false(result.movement, "Do not substitute a voluntary dash for a conditional post-hit teleport.")


func test_expedition_elements_use_real_element_and_existing_atlases_without_body_tint() -> void:
	var catalog := ExpeditionBuildCatalog.new()
	var cases := [
		["exp_braise", &"bow", &"paris", &"fire", &"hellfire"],
		["exp_braise_mutation", &"volley", &"paris", &"fire", &"hellfire"],
		["exp_braise_legend", &"volley", &"paris", &"fire", &"hellfire"],
		["exp_givre", &"bow", &"paris", &"frost", &"frost"],
		["exp_givre_signature", &"bow_piercing", &"paris", &"frost", &"frost"],
		["exp_foudre", &"bow_death", &"lightning", &"arrow_lightning", &"impact_lightning"],
		["exp_serment_brasier", &"sweep", &"paris", &"fire", &"hellfire"],
	]
	for entry in cases:
		var result := Resolver.resolve(catalog.get_spell(entry[0]))
		assert_eq([result.animation_stem, result.effects_source, result.projectile_animation, result.impact_animation],
			[entry[1], entry[2], entry[3], entry[4]], entry[0])
		assert_eq(result.palette_variant, &"base", "Elemental art never recolors Achilles.")
		assert_false(result.has("control_applied"), "An equipped control spell is not a confirmed control hit.")
	var cold_copy := catalog.get_spell("exp_braise").duplicate(true) as Spell
	cold_copy.element = Spell.Element.ICE
	assert_eq(Resolver.resolve(cold_copy).projectile_animation, &"frost", "Actual element overrides the name/ID.")


func test_expedition_healing_capability_does_not_claim_a_heal_was_applied() -> void:
	var catalog := ExpeditionBuildCatalog.new()
	for id in ["exp_souffle", "exp_souffle_mutation", "exp_souffle_legend",
		"exp_marche", "exp_marche_signature", "exp_moisson", "exp_moisson_signature"]:
		var result := Resolver.resolve(catalog.get_spell(id))
		assert_eq(result.heal_animation, &"heal", id)
		assert_eq(result.heal_effects_source, &"philosopher")
		assert_false(result.has("healing_total"), "Only the subsequent combat report confirms consumed healing.")
	assert_eq(Resolver.resolve(catalog.get_spell("exp_entaille")).heal_animation, &"",
		"A sacrifice is not healing.")
	assert_eq(Resolver.resolve(catalog.get_spell("exp_serment_rempart")).heal_animation, &"")


func test_expedition_cards_do_not_inherit_inapplicable_historical_mastery_effects() -> void:
	var catalog := ExpeditionBuildCatalog.new()
	var unit := _unit_with([&"achilles_chiron_pelion_reach", &"achilles_chiron_death_line",
		&"achilles_aeacus_myrmidon_rampart"])
	var actual := Resolver.resolve(catalog.get_spell("exp_tir_de_guet"), unit)
	assert_eq(actual.projectile_animation, &"arrow")
	assert_eq(actual.animation_stem, &"bow")
	assert_true(actual.profile_source_ids.is_empty(), "Historical targeted modifiers do not affect exp_tir_de_guet.")
	var guard := Resolver.resolve(catalog.get_spell("exp_garde_eaque"), unit)
	assert_eq(guard.variant, &"base")
	assert_eq(guard.palette_variant, &"base")
	var overridden := Resolver.resolve(catalog.get_spell("exp_rupture"), null, {"push_distance": 0})
	assert_eq(overridden.projectile_animation, &"arrow", "Resolved pushing state wins over a named pushing technique.")


func _expedition_payload(spell: Spell) -> Dictionary:
	return {
		"id": spell.spell_id, "ap": spell.ap_cost, "range": [spell.minimum_range, spell.spell_range],
		"geometry": [spell.aoe_shape, spell.aoe_size, spell.line_from_caster],
		"damage": spell.damage, "scaling": spell.damage_scaling,
		"element": spell.element, "push": spell.push_distance, "pull": spell.pull_distance,
		"heal": spell.heal, "shield": spell.shield_scaling, "terrain": spell.terrain_effect,
		"status": spell.applied_status, "modifiers": spell.modifiers.duplicate(),
		"delay": spell.impact_delay_seconds, "movement": spell.caster_movement,
	}
