extends GutTest


func test_only_spells_with_a_tree_create_progression() -> void:
	var tree_spell := _spell(&"tree_spell", _tree(&"tree_alpha"))
	var plain_spell := _spell(&"plain_spell")
	var state := _state(&"hero", [tree_spell, plain_spell])
	assert_not_null(state.get_spell_progress(&"tree_spell"))
	assert_null(state.get_spell_progress(&"plain_spell"))
	assert_eq(state.get_skill_trees(), [tree_spell.skill_tree])


func test_shared_spell_resource_has_independent_progression_per_character() -> void:
	var shared := _spell(&"shared_spell", _tree(&"shared_tree"))
	var first := _state(&"first_hero", [shared])
	var second := _state(&"second_hero", [shared])
	first.add_spell_xp(&"shared_spell", 5)
	assert_eq(first.get_spell_progress(&"shared_spell").xp, 5)
	assert_eq(second.get_spell_progress(&"shared_spell").xp, 0)
	assert_same(
		first.get_spell_progress(&"shared_spell").get_skill_tree(),
		second.get_spell_progress(&"shared_spell").get_skill_tree(),
	)


func test_removed_spell_progression_is_dormant_and_restored_when_readded() -> void:
	var spell := _spell(&"returning_spell", _tree(&"returning_tree"))
	var initial := _state(&"hero", [spell])
	initial.add_spell_xp(&"returning_spell", 5)
	var saved := initial.get_progression_snapshot()

	var without_spell := _state(&"hero", [])
	assert_true(without_spell.restore_progression_snapshot(saved))
	assert_null(without_spell.get_spell_progress(&"returning_spell"))
	assert_true(without_spell.get_progression_snapshot().spell_progressions.has(
		"returning_spell"
	))

	var readded := _state(&"hero", [spell])
	assert_true(readded.restore_progression_snapshot(
		without_spell.get_progression_snapshot()
	))
	assert_eq(readded.get_spell_progress(&"returning_spell").xp, 5)
	assert_eq(readded.get_spell_progress(&"returning_spell").rank, 2)


func test_legacy_snapshot_migrates_only_with_one_unambiguous_owner() -> void:
	var first := _spell(&"first_spell", _tree(&"legacy_tree"))
	var legacy := {
		"character_id": &"hero",
		"disciplines": {
			"legacy_tree": {
				"discipline_id": &"legacy_tree",
				"xp": 5,
				"rank": 2,
				"selected_upgrade_ids": [],
				"pending_rank_choices": [2],
			},
		},
	}
	var migrated := ProgressionSnapshotMigrationService.migrate(legacy, [first])
	assert_true(migrated.ok)
	assert_eq(migrated.snapshot.spell_progressions.first_spell.spell_id, &"first_spell")

	var second := _spell(&"second_spell", first.skill_tree)
	var ambiguous := ProgressionSnapshotMigrationService.migrate(
		legacy, [first, second]
	)
	assert_false(ambiguous.ok)
	assert_true(ambiguous.unresolved.has("legacy_tree"))
	assert_eq(
		ambiguous.snapshot.unresolved_legacy_progressions.legacy_tree.snapshot.xp,
		5,
	)


func test_blank_progression_target_uses_the_owner_spell_bucket() -> void:
	var modifier := SpellModifier.new()
	var choice := SkillUpgradeData.new()
	choice.upgrade_id = &"owner_bonus"
	choice.rank = 2
	choice.spell_modifiers = [modifier]
	var tree := _tree(&"owner_tree", choice)
	var owner := _spell(&"owner_spell", tree)
	var other := _spell(&"other_spell", _tree(&"other_tree"))
	var state := _state(&"hero", [owner, other])
	state.add_spell_xp(&"owner_spell", 5)
	assert_true(state.select_upgrade(&"owner_spell", 2, &"owner_bonus"))
	var buckets := state.get_active_progression_spell_modifiers_by_spell()
	assert_eq(buckets.keys(), [&"owner_spell"])
	assert_same(buckets[&"owner_spell"][0], modifier)


func test_combat_report_keeps_two_spells_that_share_one_tree_distinct() -> void:
	var shared_tree := _tree(&"shared_tree")
	var first := _spell(&"first_spell", shared_tree)
	var second := _spell(&"second_spell", shared_tree)
	var state := _state(&"hero", [first, second])
	var tracker := CombatReportTracker.new()
	tracker.begin([state], 0, "Shared tree")
	state.add_spell_xp(&"second_spell", 1)
	var report := tracker.finalize([state], true)
	var deltas := report.get_character_report(&"hero").discipline_deltas
	assert_eq(deltas.size(), 2)
	assert_eq(
		deltas.map(func(delta): return delta.spell_id),
		[&"first_spell", &"second_spell"],
	)
	assert_eq(deltas[0].xp_after, 0)
	assert_eq(deltas[1].xp_after, 1)


func _tree(
		tree_id: StringName,
		choice: SkillUpgradeData = null
	) -> DisciplineData:
	var tree := DisciplineData.new()
	tree.discipline_id = tree_id
	tree.display_name = str(tree_id)
	var first := DisciplineRankData.new()
	first.rank = 1
	first.required_total_xp = 0
	var second := DisciplineRankData.new()
	second.rank = 2
	second.required_total_xp = 5
	if choice != null:
		second.choices = [choice]
	tree.ranks = [first, second]
	return tree


func _spell(spell_id: StringName, tree: DisciplineData = null) -> Spell:
	var spell := Spell.new()
	spell.spell_id = spell_id
	spell.spell_name = str(spell_id)
	spell.skill_tree = tree
	return spell


func _state(character_id: StringName, spells: Array[Spell]) -> CharacterRunState:
	var data := UnitData.new()
	data.unit_id = character_id
	data.unit_name = str(character_id)
	data.spells = spells
	var state := CharacterRunState.new()
	assert_true(state.initialize(Unit.from_data(data), data))
	return state
