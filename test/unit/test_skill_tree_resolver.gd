extends GutTest

const GameManagerScript = preload("res://core/game_manager.gd")
const ProgressionScreenScript = preload(
	"res://ui/progression/progression_choice_screen.gd"
)

const DISCIPLINE_ID := &"synthetic_tree"
const BRANCH_A := &"branch_a"
const BRANCH_B := &"branch_b"
const A_SUB := &"a_sub"
const B_SUB := &"b_sub"
const A_REFINEMENT := &"a_refinement"
const B_REFINEMENT := &"b_refinement"
const A_FINAL := &"a_final"
const B_FINAL := &"b_final"

var manager = null


func after_each() -> void:
	if manager != null and is_instance_valid(manager):
		manager.cleanup_run_state()
		manager._exit_tree()
		manager.free()
	manager = null


func _make_node(
		node_id: StringName,
		rank: int,
		prerequisites: Array = [],
		exclusions: Array = [],
		modifiers: Array = []
	) -> SkillTreeNodeData:
	var node := SkillTreeNodeData.new()
	node.upgrade_id = node_id
	node.display_name = str(node_id)
	node.description = "Noeud synthetique"
	node.discipline_id = DISCIPLINE_ID
	node.rank = rank
	node.prerequisite_node_ids.assign(prerequisites)
	node.excluded_node_ids.assign(exclusions)
	node.spell_modifiers.assign(modifiers)
	return node


func _make_legacy_choice(
		node_id: StringName,
		rank: int
	) -> SkillUpgradeData:
	var choice := SkillUpgradeData.new()
	choice.upgrade_id = node_id
	choice.display_name = str(node_id)
	choice.discipline_id = DISCIPLINE_ID
	choice.rank = rank
	return choice


func _make_rank(
		rank: int,
		required_total_xp: int,
		choices: Array = []
	) -> DisciplineRankData:
	var rank_data := DisciplineRankData.new()
	rank_data.rank = rank
	rank_data.required_total_xp = required_total_xp
	rank_data.choices.assign(choices)
	return rank_data


func _make_tree(with_modifier: bool = false) -> DisciplineData:
	var branch_modifiers: Array = []
	if with_modifier:
		branch_modifiers.append(SpellModifier.new())
	var discipline := DisciplineData.new()
	discipline.discipline_id = DISCIPLINE_ID
	discipline.display_name = "Arbre synthetique"
	discipline.ranks.assign([
		_make_rank(1, 0),
		_make_rank(2, 3, [
			_make_node(BRANCH_A, 2, [], [], branch_modifiers),
			_make_node(BRANCH_B, 2),
		]),
		_make_rank(3, 7, [
			_make_node(A_SUB, 3, [BRANCH_A]),
			_make_node(B_SUB, 3, [BRANCH_B]),
		]),
		_make_rank(4, 12, [
			_make_node(A_REFINEMENT, 4, [A_SUB]),
			_make_node(B_REFINEMENT, 4, [B_SUB]),
		]),
		_make_rank(5, 18, [
			_make_node(A_FINAL, 5, [BRANCH_A]),
			_make_node(B_FINAL, 5, [BRANCH_B]),
		]),
	])
	return discipline


func _make_progress(
		discipline: DisciplineData,
		xp: int
	) -> DisciplineProgressState:
	var progress := DisciplineProgressState.new()
	assert_true(progress.initialize(discipline))
	progress.add_xp(xp)
	return progress


func _make_unit_data(
		discipline: DisciplineData,
		with_spell: bool = false
	) -> UnitData:
	var data := UnitData.new()
	data.unit_id = &"synthetic_hero"
	data.unit_name = "Hero synthetique"
	data.disciplines.assign([discipline])
	if with_spell:
		var spell := Spell.new()
		spell.spell_id = &"synthetic_spell"
		spell.discipline_id = DISCIPLINE_ID
		spell.spell_name = "Sort synthetique"
		data.spells.assign([spell])
	return data


func _make_character_state(
		discipline: DisciplineData
	) -> CharacterRunState:
	var data := _make_unit_data(discipline)
	var state := CharacterRunState.new()
	assert_true(state.initialize(Unit.from_data(data), data))
	return state


func _make_run(room_count: int = 2) -> RunData:
	var run := RunData.new()
	run.run_name = "Run arbre synthetique"
	for _room_index in range(room_count):
		run.rooms.append(RoomData.new())
	return run


func _prepare_manager(
		discipline: DisciplineData,
		with_spell: bool = false
	) -> CharacterRunState:
	manager = GameManagerScript.new()
	manager._ready()
	assert_true(manager._prepare_preconfigured_run(
		_make_run(),
		[_make_unit_data(discipline, with_spell)]
	))
	return manager.get_character_state(&"synthetic_hero")


func _available_ids(
		discipline: DisciplineData,
		progress: DisciplineProgressState,
		choice_rank: int
	) -> Array[StringName]:
	var ids: Array[StringName] = []
	for node in SkillTreeResolver.get_available_nodes(
			discipline,
			choice_rank,
			progress.rank,
			progress.get_pending_rank_choices(),
			progress.get_selected_upgrade_ids()
		):
		ids.append(node.upgrade_id)
	return ids


func _has_diagnostic(
		diagnostics: PackedStringArray,
		prefix: String
	) -> bool:
	for diagnostic in diagnostics:
		if diagnostic.begins_with(prefix):
			return true
	return false


func _choice_for_rank(
		choices: Array[Dictionary],
		rank: int
	) -> Dictionary:
	for choice in choices:
		if int(choice.get("rank", -1)) == rank:
			return choice
	return {}


func test_default_node_keeps_the_skill_upgrade_contract() -> void:
	var modifier := SpellModifier.new()
	var node := _make_node(&"contract_node", 2, [], [], [modifier])
	node.target_spell_id = &"target_spell"
	assert_true(node is SkillUpgradeData)
	assert_eq(node.get_node_id(), &"contract_node")
	assert_eq(node.target_spell_id, &"target_spell")
	assert_eq(node.get_spell_modifiers(), [modifier])
	assert_true(node.prerequisite_node_ids.is_empty())
	assert_true(node.excluded_node_ids.is_empty())


func test_rank_three_requires_the_selected_rank_two_branch() -> void:
	var discipline := _make_tree()
	var progress := _make_progress(discipline, 7)
	assert_true(_available_ids(discipline, progress, 3).is_empty())
	assert_same(progress.select_upgrade(BRANCH_A, 2).upgrade_id, BRANCH_A)
	assert_eq(_available_ids(discipline, progress, 3), [A_SUB])
	var rejected := SkillTreeResolver.evaluate_selection(
		discipline,
		3,
		B_SUB,
		progress.rank,
		progress.get_pending_rank_choices(),
		progress.get_selected_upgrade_ids()
	)
	assert_false(rejected["allowed"])
	assert_eq(
		rejected["reason"],
		SkillTreeResolver.RejectionReason.MISSING_PREREQUISITE
	)
	assert_eq(rejected["missing_prerequisites"], [BRANCH_B])


func test_rank_four_requires_the_selected_rank_three_node() -> void:
	var discipline := _make_tree()
	var progress := _make_progress(discipline, 12)
	assert_not_null(progress.select_upgrade(BRANCH_A, 2))
	assert_true(_available_ids(discipline, progress, 4).is_empty())
	assert_not_null(progress.select_upgrade(A_SUB, 3))
	assert_eq(_available_ids(discipline, progress, 4), [A_REFINEMENT])


func test_rank_five_requires_a_compatible_rank_two_branch() -> void:
	var discipline := _make_tree()
	var progress := _make_progress(discipline, 18)
	assert_not_null(progress.select_upgrade(BRANCH_A, 2))
	assert_not_null(progress.select_upgrade(A_SUB, 3))
	assert_not_null(progress.select_upgrade(A_REFINEMENT, 4))
	assert_eq(_available_ids(discipline, progress, 5), [A_FINAL])
	var rejected := SkillTreeResolver.evaluate_selection(
		discipline,
		5,
		B_FINAL,
		progress.rank,
		progress.get_pending_rank_choices(),
		progress.get_selected_upgrade_ids()
	)
	assert_eq(
		rejected["reason"],
		SkillTreeResolver.RejectionReason.MISSING_PREREQUISITE
	)


func test_exclusion_is_enforced_from_either_direction() -> void:
	for inverse in [false, true]:
		var blocker := _make_node(&"blocker", 2)
		var candidate := _make_node(&"candidate", 3)
		if inverse:
			blocker.excluded_node_ids.assign([candidate.upgrade_id])
		else:
			candidate.excluded_node_ids.assign([blocker.upgrade_id])
		var discipline := DisciplineData.new()
		discipline.discipline_id = DISCIPLINE_ID
		discipline.ranks.assign([
			_make_rank(2, 3, [blocker]),
			_make_rank(3, 7, [candidate]),
		])
		var progress := _make_progress(discipline, 7)
		assert_not_null(progress.select_upgrade(blocker.upgrade_id, 2))
		var rejected := SkillTreeResolver.evaluate_selection(
			discipline,
			3,
			candidate.upgrade_id,
			progress.rank,
			progress.get_pending_rank_choices(),
			progress.get_selected_upgrade_ids()
		)
		assert_false(rejected["allowed"])
		assert_eq(
			rejected["reason"],
			SkillTreeResolver.RejectionReason.EXCLUDED_BY_SELECTION
		)
		assert_eq(rejected["conflicting_node_ids"], [blocker.upgrade_id])


func test_second_selection_in_the_same_rank_is_rejected() -> void:
	var discipline := _make_tree()
	var progress := _make_progress(discipline, 3)
	assert_not_null(progress.select_upgrade(BRANCH_A, 2))
	var rejected := SkillTreeResolver.evaluate_selection(
		discipline,
		2,
		BRANCH_B,
		progress.rank,
		progress.get_pending_rank_choices(),
		progress.get_selected_upgrade_ids()
	)
	assert_eq(
		rejected["reason"],
		SkillTreeResolver.RejectionReason.RANK_ALREADY_SELECTED
	)
	assert_null(progress.select_upgrade(BRANCH_B, 2))
	assert_eq(progress.get_selected_upgrade_ids(), [BRANCH_A])


func test_later_pending_rank_cannot_be_selected_before_earlier_rank() -> void:
	var discipline := _make_tree()
	var progress := _make_progress(discipline, 7)
	var rejected := SkillTreeResolver.evaluate_selection(
		discipline,
		3,
		A_SUB,
		progress.rank,
		progress.get_pending_rank_choices(),
		progress.get_selected_upgrade_ids()
	)
	assert_eq(
		rejected["reason"],
		SkillTreeResolver.RejectionReason.EARLIER_RANK_PENDING
	)
	assert_null(progress.select_upgrade(A_SUB, 3))
	assert_true(progress.get_selected_upgrade_ids().is_empty())
	assert_eq(progress.get_pending_rank_choices(), [2, 3])


func test_stale_candidate_is_revalidated_at_confirmation() -> void:
	var state := _prepare_manager(_make_tree())
	state.add_discipline_xp(DISCIPLINE_ID, 3)
	var screen = ProgressionScreenScript.new()
	screen.progression_controller = manager
	add_child_autofree(screen)
	assert_true(screen.select_upgrade_card(BRANCH_B))
	assert_true(manager.choose_progression_upgrade(
		state.character_id,
		DISCIPLINE_ID,
		2,
		BRANCH_A
	))
	assert_false(screen.confirm_selection())
	var progress := state.get_discipline_progress(DISCIPLINE_ID)
	assert_eq(progress.get_selected_upgrade_ids(), [BRANCH_A])
	assert_true(progress.get_pending_rank_choices().is_empty())


func test_plain_skill_upgrade_data_remains_a_legacy_unconditional_choice() -> void:
	var legacy := _make_legacy_choice(&"legacy_choice", 2)
	var discipline := DisciplineData.new()
	discipline.discipline_id = DISCIPLINE_ID
	discipline.ranks.assign([_make_rank(2, 3, [legacy])])
	var progress := _make_progress(discipline, 3)
	assert_eq(_available_ids(discipline, progress, 2), [legacy.upgrade_id])
	assert_same(progress.select_upgrade(legacy.upgrade_id, 2), legacy)
	assert_eq(progress.get_selected_upgrade_ids(), [legacy.upgrade_id])


func test_invalid_tree_reports_duplicate_unknown_self_and_cyclic_references() -> void:
	var cycle_a := _make_node(&"cycle_a", 2, [&"cycle_b"])
	var duplicate_a := _make_node(&"duplicate", 2)
	var cycle_b := _make_node(&"cycle_b", 3, [&"cycle_a"])
	var duplicate_b := _make_node(&"duplicate", 3)
	var invalid := _make_node(
		&"invalid",
		3,
		[&"invalid", &"unknown_prerequisite"],
		[&"invalid", &"unknown_exclusion"]
	)
	invalid.discipline_id = &"other_discipline"
	invalid.rank = 4
	var discipline := DisciplineData.new()
	discipline.discipline_id = DISCIPLINE_ID
	discipline.ranks.assign([
		_make_rank(1, 0),
		_make_rank(2, 3, [cycle_a, duplicate_a]),
		_make_rank(3, 7, [cycle_b, duplicate_b, invalid]),
	])
	var diagnostics := SkillTreeResolver.validate_discipline(discipline)
	for prefix in [
		"DUPLICATE_UPGRADE_ID:",
		"UNKNOWN_PREREQUISITE:",
		"UNKNOWN_EXCLUSION:",
		"SELF_PREREQUISITE:",
		"SELF_EXCLUSION:",
		"PREREQUISITE_NOT_IN_LOWER_RANK:",
		"PREREQUISITE_CYCLE:",
		"DISCIPLINE_MISMATCH:",
		"RANK_MISMATCH:",
	]:
		assert_true(_has_diagnostic(diagnostics, prefix), prefix)
	var rejected := SkillTreeResolver.evaluate_selection(
		discipline,
		2,
		cycle_a.upgrade_id,
		3,
		[2],
		[]
	)
	assert_eq(
		rejected["reason"],
		SkillTreeResolver.RejectionReason.INVALID_TREE_DATA
	)


func test_invalid_threshold_or_non_contiguous_rank_is_reported() -> void:
	var discipline := DisciplineData.new()
	discipline.discipline_id = DISCIPLINE_ID
	discipline.ranks.assign([
		_make_rank(1, 0),
		_make_rank(3, 0),
	])
	var diagnostics := SkillTreeResolver.validate_discipline(discipline)
	assert_true(_has_diagnostic(diagnostics, "NON_CONTIGUOUS_RANKS:"))
	assert_true(
		_has_diagnostic(diagnostics, "NON_INCREASING_XP_THRESHOLD:")
	)
	var missing_rank_two := DisciplineData.new()
	missing_rank_two.discipline_id = DISCIPLINE_ID
	missing_rank_two.ranks.assign([_make_rank(3, 7)])
	assert_true(_has_diagnostic(
		SkillTreeResolver.validate_discipline(missing_rank_two),
		"NON_CONTIGUOUS_RANKS:"
	))


func test_no_available_candidate_keeps_the_rank_pending() -> void:
	var base := _make_node(&"unselected_base", 1)
	var locked := _make_node(&"locked_rank_two", 2, [base.upgrade_id])
	var discipline := DisciplineData.new()
	discipline.discipline_id = DISCIPLINE_ID
	discipline.ranks.assign([
		_make_rank(1, 0, [base]),
		_make_rank(2, 3, [locked]),
	])
	var progress := _make_progress(discipline, 3)
	assert_true(_available_ids(discipline, progress, 2).is_empty())
	assert_null(progress.select_upgrade(locked.upgrade_id, 2))
	assert_eq(progress.get_pending_rank_choices(), [2])


func test_incompatible_choice_submitted_by_ui_is_rejected_without_mutation() -> void:
	var state := _prepare_manager(_make_tree())
	state.add_discipline_xp(DISCIPLINE_ID, 7)
	assert_true(manager.choose_progression_upgrade(
		state.character_id,
		DISCIPLINE_ID,
		2,
		BRANCH_A
	))
	var screen = ProgressionScreenScript.new()
	screen.progression_controller = manager
	add_child_autofree(screen)
	assert_eq(
		screen.get_current_choice()["choices"].map(
			func(choice): return choice.upgrade_id
		),
		[A_SUB]
	)
	screen._selected_upgrade_id = B_SUB
	assert_false(screen.confirm_selection())
	var progress := state.get_discipline_progress(DISCIPLINE_ID)
	assert_eq(progress.get_selected_upgrade_ids(), [BRANCH_A])
	assert_eq(progress.get_pending_rank_choices(), [3])


func test_pending_choices_are_recalculated_after_branch_selection() -> void:
	var discipline := _make_tree()
	var state := _make_character_state(discipline)
	state.add_discipline_xp(DISCIPLINE_ID, 7)
	var before := state.get_pending_progression_choices()
	assert_eq(
		_choice_for_rank(before, 2)["choices"].map(
			func(choice): return choice.upgrade_id
		),
		[BRANCH_A, BRANCH_B]
	)
	assert_true(_choice_for_rank(before, 3)["choices"].is_empty())
	assert_true(state.select_upgrade(DISCIPLINE_ID, 2, BRANCH_A))
	var after := state.get_pending_progression_choices()
	assert_eq(
		_choice_for_rank(after, 3)["choices"].map(
			func(choice): return choice.upgrade_id
		),
		[A_SUB]
	)
	state.dispose()


func test_synthetic_fixture_uses_future_cumulative_thresholds() -> void:
	var discipline := _make_tree()
	assert_eq(
		discipline.ranks.map(
			func(rank_data): return rank_data.required_total_xp
		),
		[0, 3, 7, 12, 18]
	)
	var progress := _make_progress(discipline, 2)
	assert_eq(progress.rank, 1)
	progress.add_xp(1)
	assert_eq(progress.rank, 2)
	progress.add_xp(3)
	assert_eq(progress.rank, 2)
	progress.add_xp(1)
	assert_eq(progress.rank, 3)
	progress.add_xp(5)
	assert_eq(progress.rank, 4)
	progress.add_xp(6)
	assert_eq(progress.rank, 5)


func test_successful_cast_still_grants_one_xp_without_energy() -> void:
	var state := _prepare_manager(_make_tree(), true)
	assert_false(state.unit.has_energy())
	var spell: Spell = state.unit.spells[0]
	EventBus.spell_cast.emit(state.unit, spell, {})
	assert_eq(state.get_discipline_progress(DISCIPLINE_ID).xp, 1)
	EventBus.spell_cast.emit(state.unit, spell, {})
	assert_eq(state.get_discipline_progress(DISCIPLINE_ID).xp, 2)


func test_valid_selection_applies_spell_modifiers_exactly_once() -> void:
	var state := _make_character_state(_make_tree(true))
	assert_false(state.unit.has_energy())
	state.add_discipline_xp(DISCIPLINE_ID, 3)
	assert_true(state.select_upgrade(DISCIPLINE_ID, 2, BRANCH_A))
	assert_eq(state.unit.get_progression_spell_modifiers().size(), 1)
	state._sync_progression_modifiers_to_unit()
	state._sync_progression_modifiers_to_unit()
	assert_eq(state.unit.get_progression_spell_modifiers().size(), 1)
	state.dispose()


func test_conditional_selections_persist_between_rooms_and_reset_on_new_run() -> void:
	var discipline := _make_tree()
	var state := _prepare_manager(discipline)
	state.add_discipline_xp(DISCIPLINE_ID, 7)
	assert_true(state.select_upgrade(DISCIPLINE_ID, 2, BRANCH_A))
	assert_true(state.select_upgrade(DISCIPLINE_ID, 3, A_SUB))
	manager.current_room_index = 0
	manager._go_to_next_room()
	assert_same(manager.get_character_state(state.character_id), state)
	assert_eq(
		state.get_discipline_progress(
			DISCIPLINE_ID
		).get_selected_upgrade_ids(),
		[BRANCH_A, A_SUB]
	)

	assert_true(manager._prepare_preconfigured_run(
		_make_run(),
		[_make_unit_data(discipline)]
	))
	var fresh: CharacterRunState = manager.get_character_state(
		&"synthetic_hero"
	)
	assert_not_same(fresh, state)
	assert_true(
		fresh.get_discipline_progress(
			DISCIPLINE_ID
		).get_selected_upgrade_ids().is_empty()
	)
