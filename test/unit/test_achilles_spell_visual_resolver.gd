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


func test_piercing_and_death_line_share_bow_with_distinct_projectile_effects() -> void:
	var unit := _unit_with([&"achilles_chiron_piercing_arrow"])
	var piercing := Resolver.resolve(SHOT, unit)
	assert_eq(piercing.animation_stem, &"bow")
	assert_eq(piercing.variant, &"piercing")
	assert_eq(piercing.maximum_targets, 2)
	assert_eq(piercing.effect_variant, &"arrow_piercing")
	unit.mastery_nodes.append(_node(&"achilles_chiron_death_line"))
	var line := Resolver.resolve(SHOT, unit)
	assert_eq(line.animation_stem, &"bow")
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
	assert_eq(result.animation_stem, &"bow")
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
