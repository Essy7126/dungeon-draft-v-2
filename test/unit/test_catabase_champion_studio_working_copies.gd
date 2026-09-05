extends GutTest


func test_champion_profile_working_copy_isolates_curves_and_spell_scaling() -> void:
	var profile := CharacterProgressionProfile.new()
	profile.champion_progression_profile = ChampionProgressionProfile.new()
	profile.champion_progression_profile.base_hp_by_level = PackedInt32Array([110, 121])
	var spell := Spell.new()
	spell.spell_id = &"studio_scaled_spell"
	spell.damage_scaling = SpellScalingData.new()
	spell.damage_scaling.prowess_coefficient = 0.55
	profile.spells = [spell]
	var copied := SkillTreeCopyService.copy_progression_profile(profile)
	assert_ne(copied.champion_progression_profile, profile.champion_progression_profile)
	assert_ne(copied.spells[0].damage_scaling, spell.damage_scaling)
	copied.champion_progression_profile.base_hp_by_level[0] = 999
	copied.spells[0].damage_scaling.prowess_coefficient = 0.9
	assert_eq(profile.champion_progression_profile.base_hp_by_level[0], 110)
	assert_almost_eq(spell.damage_scaling.prowess_coefficient, 0.55, 0.0001)


func test_item_parameters_and_reaction_priority_survive_undo_redo() -> void:
	var source := load("res://data/items/definitions/odyssey/thetis_anchor.tres") as ItemDefinition
	var original := source.reactive_effects[0].priority
	var document := ItemStudioDocument.new()
	assert_true(document.open_definition(source))
	assert_true(document.record_edit("Priorité", func():
		document.working_copy.reactive_effects[0].priority = 17
		document.working_copy.reactive_effects[0].parameters[0].float_value = 0.4
	))
	assert_eq(source.reactive_effects[0].priority, original)
	assert_true(document.history.undo())
	assert_eq(document.working_copy.reactive_effects[0].priority, original)
	assert_true(document.history.redo())
	assert_eq(document.working_copy.reactive_effects[0].priority, 17)
	assert_almost_eq(document.working_copy.reactive_effects[0].parameters[0].float_value, 0.4, 0.0001)


func test_encounter_glory_copy_is_independent_and_changes_fingerprint() -> void:
	var source := EncounterDefinition.new()
	source.encounter_id = &"current_room"
	source.base_xp = 110
	source.glory_challenge = GloryChallengeData.new()
	source.glory_challenge.challenge_id = &"no_consumable"
	var copied := EncounterCopyService.copy_encounter(source)
	assert_ne(copied.glory_challenge, source.glory_challenge)
	assert_eq(EncounterCopyService.encounter_snapshot(copied), EncounterCopyService.encounter_snapshot(source))
	copied.glory_challenge.xp_multiplier = 1.5
	assert_almost_eq(source.glory_challenge.xp_multiplier, 1.3, 0.0001)
	assert_ne(EncounterCopyService.encounter_snapshot(copied), EncounterCopyService.encounter_snapshot(source))


func test_odyssey_authoring_counts_exclude_only_preserved_starting_consumables() -> void:
	var sheet := OdysseyItemAuthoringService.catalog_sheet()
	assert_true(sheet.valid)
	assert_true(sheet.contract_ok)
	assert_eq(sheet.total, 26)
	assert_eq(sheet.equipment_count, 16)
	assert_eq(sheet.relic_count, 8)


func test_conditional_range_requires_actual_prior_movement() -> void:
	var modifier := ItemSpellModifierData.new()
	modifier.range_bonus = 1
	modifier.minimum_prior_moved_cells = 2
	var spell := Spell.new()
	spell.spell_range = 3
	assert_eq(modifier.get_range_bonus(null, spell), 0)
	modifier.minimum_prior_moved_cells = 0
	assert_eq(modifier.get_range_bonus(null, spell), 1)
	assert_true(modifier._history_conditions_pass({}))
	assert_eq(modifier._scaled_delta(1, 0.2), 1)
	assert_eq(modifier._scaled_delta(1, -0.2), -1)
