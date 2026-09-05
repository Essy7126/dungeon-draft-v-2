extends GutTest

const PROFILE: CharacterProgressionProfile = preload("res://data/runs/progression/odyssey/achilles_progression_profile.tres")
const CHAMPION_PROFILE: ChampionProgressionProfile = preload("res://data/runs/progression/odyssey/achilles_champion_progression_v0.tres")
const LEGACY_RUN: RunData = preload("res://data/runs/first_run.tres")

var _states: Array[CharacterRunState] = []

func after_each() -> void:
	for state in _states:
		state.dispose()
	_states.clear()

func _odyssey_progression_profile() -> CharacterProgressionProfile:
	return PROFILE

func _champion_state() -> CharacterRunState:
	var data := UnitData.new()
	data.unit_id = PROFILE.character_id
	data.max_hp = 110
	data.attack_power = 18
	data.spells = PROFILE.spells
	data.progression_profile = PROFILE
	var state := CharacterRunState.new()
	assert_true(state.initialize(Unit.from_data(data), data))
	_states.append(state)
	return state

func test_odyssey_profile_uses_exact_champion_curves_and_legacy_default_survives() -> void:
	var progression := _odyssey_progression_profile()
	assert_true(progression.uses_champion_progression())
	assert_same(progression.champion_progression_profile, CHAMPION_PROFILE)
	assert_true(CHAMPION_PROFILE.is_valid(), str(CHAMPION_PROFILE.validation_errors()))
	assert_eq(CHAMPION_PROFILE.level_cap, 14)
	assert_eq(Array(CHAMPION_PROFILE.cumulative_xp_thresholds), [
		0, 100, 220, 360, 520, 700, 900, 1120, 1360, 1700, 1990, 2300,
		2630, 2950,
	])
	assert_eq(Array(CHAMPION_PROFILE.base_hp_by_level), [
		110, 135, 165, 200, 240, 290, 350, 420, 500, 600, 635, 675, 720, 770,
	])
	assert_eq(Array(CHAMPION_PROFILE.base_prowess_by_level), [
		18, 22, 27, 33, 40, 48, 57, 68, 82, 100, 106, 112, 119, 127,
	])
	assert_eq(Array(CHAMPION_PROFILE.attribute_point_levels), range(2, 11))
	assert_eq(Array(CHAMPION_PROFILE.mastery_point_levels), range(2, 15))
	for hero_profile in LEGACY_RUN.content_profile.hero_profiles:
		assert_true(hero_profile.progression_profile.uses_legacy_cast_xp())
		assert_null(hero_profile.progression_profile.champion_progression_profile)



func test_encounter_xp_requires_victory_is_once_and_resolves_multiple_levels() -> void:
	var state := _champion_state()
	state.unit.current_hp = 80
	state.begin_encounter()
	var refused := state.award_encounter_xp(&"not_won", 1700, false)
	assert_false(refused.granted)
	assert_eq(refused.refusal_reason, &"ENCOUNTER_NOT_WON")
	assert_eq(state.champion_progression.current_xp, 0)
	var result := state.award_encounter_xp(&"won", 1700, true)
	assert_true(result.granted)
	assert_eq(result.level_before, 1)
	assert_eq(result.level_after, 10)
	assert_eq(result.levels_gained, 9)
	assert_true(result.multiple_levels)
	assert_eq(result.reached_levels, range(2, 11))
	assert_eq(result.attribute_points_gained, 9)
	assert_eq(result.mastery_points_gained, 9)
	assert_eq(state.unit.max_hp.get_int(), 600)
	assert_eq(state.unit.current_hp, 570)
	assert_lt(state.unit.current_hp, state.unit.max_hp.get_int())
	var duplicate := state.award_encounter_xp(&"won", 1700, true)
	assert_false(duplicate.granted)
	assert_eq(duplicate.refusal_reason, &"ENCOUNTER_ALREADY_AWARDED")
	assert_eq(state.champion_progression.current_xp, 1700)



func test_wisdom_is_captured_at_start_and_glory_requires_acceptance_and_success() -> void:
	var state := _champion_state()
	state.begin_encounter()
	var level_result := state.award_encounter_xp(&"level", 1700, true)
	for _point in 5:
		assert_true(state.spend_champion_attribute(
			ChampionProgressionProfile.ATTRIBUTE_WISDOM
		))
	assert_eq(level_result.wisdom_points_at_encounter_start, 0)
	assert_eq(level_result.gained_xp, 1700)
	state.begin_encounter()
	var wisdom_only := state.award_encounter_xp(
		&"wisdom_only", 100, true, true, false
	)
	assert_eq(wisdom_only.gained_xp, 150)
	assert_eq(wisdom_only.wisdom_bonus_xp, 50)
	assert_eq(wisdom_only.glory_bonus_xp, 0)
	assert_eq(wisdom_only.wisdom_points_at_encounter_start, 5)
	state.begin_encounter()
	var glory := state.award_encounter_xp(&"glory", 100, true, true, true)
	assert_eq(glory.gained_xp, 195)
	assert_eq(glory.wisdom_bonus_xp, 50)
	assert_eq(glory.glory_bonus_xp, 45)
	state.begin_encounter()
	var inconsistent := state.award_encounter_xp(
		&"inconsistent", 100, true, false, true
	)
	assert_false(inconsistent.granted)
	assert_eq(inconsistent.refusal_reason, &"GLORY_NOT_ACCEPTED")



func test_attributes_apply_exact_stats_hp_delta_and_created_shield_multiplier() -> void:
	var state := _champion_state()
	state.unit.current_hp = 100
	state.begin_encounter()
	state.award_encounter_xp(&"level_ten", 1700, true)
	assert_eq(state.unit.current_hp, 590)
	assert_true(state.spend_champion_attribute(
		ChampionProgressionProfile.ATTRIBUTE_VITALITY
	))
	assert_eq(state.unit.max_hp.get_int(), 636)
	assert_eq(state.unit.current_hp, 626)
	assert_true(state.spend_champion_attribute(
		ChampionProgressionProfile.ATTRIBUTE_POWER
	))
	assert_eq(state.unit.attack_power.get_int(), 105)
	assert_true(state.spend_champion_attribute(
		ChampionProgressionProfile.ATTRIBUTE_RESOLVE
	))
	assert_eq(state.unit.armure.get_int(), 4)
	assert_almost_eq(state.unit.shield_creation_multiplier, 1.05, 0.0001)
	state.unit.add_shield(100, state.unit, {"shield_source_id": &"resolve_test"})
	assert_eq(state.unit.get_shield_value(&"resolve_test"), 105)



func test_equipment_max_hp_changes_never_heal_the_champion() -> void:
	var state := _champion_state()
	state.begin_encounter()
	state.award_encounter_xp(&"level_ten_for_equipment", 1700, true)
	state.unit.current_hp = 100
	var modifier := ItemStatModifierData.new()
	modifier.stat_id = &"max_hp"
	modifier.value = 100.0
	var definition := ItemDefinition.new()
	definition.item_id = &"gate2_hp_equipment"
	definition.stat_modifiers = [modifier]
	var instance := ItemInstance.new()
	assert_true(instance.initialize(definition.item_id, 1, &"gate2_hp_instance"))
	var service := EquipmentStatService.new()
	assert_true(service.apply_item(state.unit, instance, definition))
	assert_eq(state.unit.max_hp.get_int(), 700)
	assert_eq(state.unit.current_hp, 100)
	service.remove_item(state.unit, instance, definition)
	assert_eq(state.unit.max_hp.get_int(), 600)
	assert_eq(state.unit.current_hp, 100)



func test_purchased_mastery_is_capped_at_three_and_validated_on_restore() -> void:
	var state := _champion_state()
	assert_true(state.champion_progression.grant_purchased_mastery(3))
	assert_false(state.champion_progression.grant_purchased_mastery(1))
	var before := state.get_progression_snapshot()
	var invalid := before.duplicate(true)
	invalid.champion_progression.purchased_mastery_points = 4
	invalid.champion_progression.unspent_mastery_points = 4
	assert_false(state.restore_progression_snapshot(invalid))
	assert_eq(state.get_progression_snapshot(), before)



func test_champion_snapshot_roundtrip_is_exact_and_legacy_conversion_is_refused() -> void:
	var state := _champion_state()
	state.begin_encounter()
	state.award_encounter_xp(&"roundtrip", 1700, true)
	state.spend_champion_attribute(ChampionProgressionProfile.ATTRIBUTE_VITALITY)
	state.spend_champion_attribute(ChampionProgressionProfile.ATTRIBUTE_WISDOM)
	state.champion_progression.grant_purchased_mastery(2)
	state.unit.current_hp -= 17
	var snapshot := state.get_progression_snapshot()
	var restored := _champion_state()
	assert_true(restored.restore_progression_snapshot(snapshot))
	assert_eq(restored.get_progression_snapshot(), snapshot)
	assert_eq(restored.unit.current_hp, state.unit.current_hp)
	var legacy_snapshot := {
		"version": 2,
		"character_id": &"achilles",
		"spell_progressions": {},
		"unresolved_legacy_progressions": {},
	}
	assert_false(restored.restore_progression_snapshot(legacy_snapshot))
	assert_true(str(restored.last_restore_report.diagnostics[0]).contains(
		"ne peut pas etre convertie silencieusement"
	))



func test_champion_cast_xp_refuses_stably_without_mutating_state() -> void:
	var state := _champion_state()
	var spell := state.loadout.get_known_spells()[0]
	var service := CharacterProgressionService.new()
	service.begin_combat({state.character_id: state})
	var before := state.get_progression_snapshot()
	var result := service.grant_cast_xp(
		{state.character_id: state},
		state.unit,
		spell,
		{"effective_cast": true},
	)
	assert_false(result.granted)
	assert_eq(result.refusal_reason, &"champion_encounter_xp_only")
	assert_eq(state.get_progression_snapshot(), before)
	assert_eq(service.get_combat_xp(state.character_id, spell.get_effective_spell_id()), 0)



func test_dispose_removes_champion_modifiers_and_restores_shield_multiplier() -> void:
	var state := _champion_state()
	state.begin_encounter()
	state.award_encounter_xp(&"level", 1700, true)
	state.spend_champion_attribute(ChampionProgressionProfile.ATTRIBUTE_RESOLVE)
	var unit := state.unit
	assert_true(unit.armure.has_source(ChampionProgressionState.STAT_SOURCE))
	assert_almost_eq(unit.shield_creation_multiplier, 1.05, 0.0001)
	state.dispose()
	assert_false(unit.armure.has_source(ChampionProgressionState.STAT_SOURCE))
	assert_false(unit.max_hp.has_source(ChampionProgressionState.STAT_SOURCE))
	assert_false(unit.attack_power.has_source(ChampionProgressionState.STAT_SOURCE))
	assert_almost_eq(unit.shield_creation_multiplier, 1.0, 0.0001)
	assert_eq(unit.max_hp.get_int(), 110)
	assert_eq(unit.attack_power.get_int(), 18)



func test_runtime_profile_carrier_and_local_purchase_sync_without_canonical_mutation() -> void:
	var state := _champion_state()
	assert_true(state.uses_champion_progression())
	assert_same(state.progression_profile, PROFILE)
	assert_eq(state.get_mastery_nodes().size(), 36)
	assert_same(state.unit.mastery_runtime, state.mastery_runtime)
	state.champion_progression.grant_purchased_mastery(1)
	var result := state.purchase_mastery_node(&"achilles_wrath_focused_fury")
	assert_true(result.get("purchased", false), str(result))
	assert_eq(state.unit.mastery_nodes.size(), 1)
	assert_eq(state.mastery_runtime.active_effects().size(), 1)
	assert_eq(state.champion_progression.unspent_mastery_points, 0)
	var other := _champion_state()
	assert_true(other.unit.mastery_nodes.is_empty())
	assert_eq(other.champion_progression.unspent_mastery_points, 0)


func test_snapshot_rejects_unknown_masteries_wrong_budget_and_unmet_prerequisites_atomically() -> void:
	var state := _champion_state()
	state.champion_progression.grant_purchased_mastery(1)
	var original := state.get_progression_snapshot()
	for node_id in [&"unknown_mastery", &"achilles_wrath_execution"]:
		var invalid := original.duplicate(true)
		invalid.champion_progression.selected_node_ids = [str(node_id)]
		invalid.champion_progression.unspent_mastery_points = 0
		assert_false(state.restore_progression_snapshot(invalid))
		assert_eq(state.get_progression_snapshot(), original)
	var missing_point := original.duplicate(true)
	missing_point.champion_progression.unspent_mastery_points = 0
	assert_false(state.restore_progression_snapshot(missing_point))
	assert_eq(state.get_progression_snapshot(), original)


func test_snapshot_restores_selected_effects_and_dispose_releases_unit_references() -> void:
	var state := _champion_state()
	state.champion_progression.grant_purchased_mastery(1)
	assert_true(state.purchase_mastery_node(&"achilles_wrath_focused_fury").get("purchased", false))
	var restored := _champion_state()
	assert_true(restored.restore_progression_snapshot(state.get_progression_snapshot()))
	assert_eq(restored.unit.mastery_nodes.size(), 1)
	assert_eq(restored.mastery_runtime.active_effects().size(), 1)
	assert_eq(restored.get_progression_snapshot(), state.get_progression_snapshot())
	var runtime_unit := restored.unit
	restored.dispose()
	assert_null(runtime_unit.mastery_runtime)
	assert_true(runtime_unit.mastery_nodes.is_empty())


func test_second_capstone_requires_level_thirteen_even_with_merchant_points() -> void:
	var catalog := PROFILE.mastery_catalog
	var doctrine := catalog.doctrines[1]
	var path: Array = SkillTreeResolver.champion_capstone_paths(doctrine, 13)[0]
	var selected: Array[StringName] = [&"achilles_wrath_scourge_of_troy"]
	for index in range(path.size() - 1):
		selected.append(StringName(path[index]))
	var capstone := catalog.node_catalog().get(StringName(path.back())) as SkillTreeNodeData
	var verdict := SkillTreeResolver.evaluate_mastery_purchase(capstone, catalog.doctrines, catalog.get_advanced_nodes(), 12, 99, selected, CHAMPION_PROFILE)
	assert_false(verdict.allowed)
	assert_eq(verdict.reason_id, "LEVEL_GATE")
	verdict = SkillTreeResolver.evaluate_mastery_purchase(capstone, catalog.doctrines, catalog.get_advanced_nodes(), 13, 99, selected, CHAMPION_PROFILE)
	assert_true(verdict.allowed, str(verdict))


func test_refreshing_selected_effects_does_not_reset_frequency_or_runtime_flags() -> void:
	var state := _champion_state()
	var runtime := state.mastery_runtime
	var context := {"combat_id": &"same_combat"}
	runtime.set_runtime_flag(&"once", MasteryReactiveEffectData.Scope.COMBAT, context)
	state.refresh_mastery_effects()
	assert_same(state.mastery_runtime, runtime)
	assert_true(runtime.has_runtime_flag(&"once", MasteryReactiveEffectData.Scope.COMBAT, context))


func test_attribute_preview_matches_equipment_modified_runtime_without_mutation() -> void:
	var state := _champion_state()
	state.award_encounter_xp(&"preview_points", 360, true)
	state.unit.max_hp.add_modifier(37, Stat.ModType.FLAT, "equipment")
	state.unit.max_hp.add_modifier(0.2, Stat.ModType.PERCENT, "equipment")
	state.unit.attack_power.add_modifier(11, Stat.ModType.FLAT, "equipment")
	state.unit.armure.add_modifier(0.5, Stat.ModType.PERCENT, "equipment")
	for attribute_id in [&"vitality", &"power", &"resolve"]:
		var before := state.get_progression_snapshot()
		var rows := state.get_champion_attribute_rows()
		assert_eq(state.get_progression_snapshot(), before)
		var expected := 0
		var impacts := state.preview_champion_attribute(attribute_id)
		for row in rows:
			if row.id == attribute_id:
				expected = int(row.next)
		assert_true(state.spend_champion_attribute(attribute_id))
		var actual := state.unit.max_hp.get_int() if attribute_id == &"vitality" else (state.unit.attack_power.get_int() if attribute_id == &"power" else state.unit.armure.get_int())
		assert_eq(actual, expected)
		for impact in impacts:
			for spell in PROFILE.spells:
				if spell.get_effective_spell_id() != impact.spell_id:
					continue
				if impact.kind == &"damage":
					assert_eq(spell.get_scaled_damage(state.unit), int(impact.next))
				else:
					var source_id := StringName("preview_" + str(attribute_id))
					state.unit.add_shield(spell.get_scaled_shield(state.unit), state.unit, {"shield_source_id": source_id})
					assert_eq(state.unit.get_shield_value(source_id), int(impact.next))


func test_reapplying_vitality_does_not_lose_hp_via_intermediate_stat_signals() -> void:
	var state := _champion_state()
	state.unit.current_hp = 100
	state.award_encounter_xp(&"consecutive_attributes", 1700, true)
	assert_eq(state.unit.current_hp, 590)
	assert_true(state.spend_champion_attribute(&"vitality"))
	assert_eq(state.unit.current_hp, 626)
	assert_true(state.spend_champion_attribute(&"vitality"))
	assert_eq(state.unit.current_hp, 662)
	assert_eq(state.unit.max_hp.get_int(), 672)
	assert_true(state.spend_champion_attribute(&"power"))
	assert_eq(state.unit.current_hp, 662)
	assert_true(state.spend_champion_attribute(&"resolve"))
	assert_eq(state.unit.current_hp, 662)


func test_vitality_uses_level_base_hp_and_does_not_amplify_flat_equipment() -> void:
	var state := _champion_state()
	state.award_encounter_xp(&"base_hp_contract", 360, true)
	state.unit.max_hp.add_modifier(100.0, Stat.ModType.FLAT, "equipment")
	assert_eq(state.unit.max_hp.get_int(), 300)
	assert_true(state.spend_champion_attribute(&"vitality"))
	assert_eq(state.unit.max_hp.get_int(), 312)
