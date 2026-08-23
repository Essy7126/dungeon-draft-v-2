extends GutTest

const BATTLE_SCRIPT := preload("res://battle/battle.gd")
const SCREEN_SCENE := preload(
	"res://ui/progression/screens/skill_tree_screen.tscn"
)
const HERO_PATHS := [
	"res://data/units/alliés/elfe.tres",
	"res://data/units/alliés/mage.tres",
	"res://data/units/alliés/Guerrier.tres",
]


class ProgressionController:
	extends RefCounted

	var state: CharacterRunState

	func _init(wanted_state: CharacterRunState) -> void:
		state = wanted_state

	func get_character_state(wanted_character_id: StringName) -> CharacterRunState:
		return state if state.character_id == wanted_character_id else null

	func choose_progression_upgrade(
			character_id: StringName,
			discipline_id: StringName,
			rank: int,
			upgrade_id: StringName
		) -> bool:
		return character_id == state.character_id \
			and state.select_upgrade(discipline_id, rank, upgrade_id)


func after_each() -> void:
	GameManager.cleanup_run_state()


func _state(hero_path: String) -> CharacterRunState:
	var data := load(hero_path) as UnitData
	var state := CharacterRunState.new()
	assert_true(state.initialize(Unit.from_data(data), data))
	return state


func _request(
		state: CharacterRunState,
		discipline_id: StringName,
		rank: int,
		sequence: int = 1
	) -> EvolutionRequest:
	var source_spell_id: StringName = &""
	for spell in state.unit.spells:
		if spell != null and spell.skill_tree != null \
				and spell.skill_tree.discipline_id == discipline_id:
			source_spell_id = spell.get_effective_spell_id()
			break
	return EvolutionRequest.create(
		state.character_id,
		discipline_id,
		rank,
		source_spell_id,
		sequence,
		StringName("test_%s_%s_%d" % [
			state.character_id,
			discipline_id,
			rank,
		]),
	)


func _screen() -> SkillTreeScreen:
	var screen := SCREEN_SCENE.instantiate() as SkillTreeScreen
	add_child_autofree(screen)
	return screen


func _settle(frames: int = 3) -> void:
	for _index in frames:
		await get_tree().process_frame


func _resolve_first_overlay_choice(run_ui: PersistentRunUI) -> StringName:
	var overlay := run_ui.get_skill_evolution_overlay()
	assert_true(overlay.visible)
	assert_false(run_ui.get_skill_tree_screen().visible)
	assert_true(get_tree().paused)
	var available := overlay.get_available_upgrade_ids()
	assert_eq(available.size(), 2)
	var selected_id: StringName = available[0]
	assert_true(overlay.select_upgrade_by_id(selected_id))
	assert_true(overlay.request_confirmation())
	await get_tree().create_timer(0.3, true).timeout
	await _settle(4)
	return selected_id


func _prepare_global_run() -> CharacterRunState:
	var run := RunData.new()
	run.run_name = "Evolution en combat"
	run.rooms = [RoomData.new(), RoomData.new()]
	assert_true(GameManager._prepare_preconfigured_run(
		run,
		GameManager.PRODUCTION_HERO_DATA_PATHS,
	))
	return GameManager.get_ordered_character_states()[0]


func test_evolution_request_queue_is_fifo_and_deduplicated_by_rank() -> void:
	var queue := EvolutionRequestQueue.new()
	var state := _state(HERO_PATHS[0])
	var first := _request(state, &"archer", 2, 4)
	var second := _request(state, &"assassin", 2, 5)
	assert_true(queue.enqueue(first))
	assert_false(queue.enqueue(_request(state, &"archer", 2, 99)))
	assert_true(queue.enqueue(second))
	assert_eq(queue.size(), 2)
	assert_same(queue.peek(), first)
	assert_same(queue.complete_current(), first)
	assert_same(queue.peek(), second)
	assert_eq(first.to_dictionary(), {
		"character_id": &"elf",
		"discipline_id": &"archer",
		"pending_rank": 2,
		"source_spell_id": &"elf_precise_shot",
		"trigger_sequence": 4,
		"request_id": first.request_id,
	})


func test_turn_state_refuses_every_combat_intention_during_evolution() -> void:
	var state := TurnState.new()
	var requested := 0
	state.request_move_to.connect(func(_cell): requested += 1)
	state.request_attack.connect(func(_cell): requested += 1)
	state.request_cast_spell.connect(func(_spell, _cell): requested += 1)
	state.begin_skill_evolution_pending()
	state.on_move_button()
	state.on_attack_button()
	state.on_spell_selected(Spell.new())
	state.on_cell_clicked(Vector2i.ONE)
	state.on_cancel()
	assert_eq(state.current, TurnState.State.SKILL_EVOLUTION_PENDING)
	assert_eq(requested, 0)
	state.begin_skill_evolution_ui()
	state.on_move_button()
	state.on_cancel()
	assert_eq(state.current, TurnState.State.SKILL_EVOLUTION_UI)


func test_all_twelve_disciplines_open_their_two_r2_choices_and_sync_modifiers() -> void:
	var tested := 0
	for hero_path in HERO_PATHS:
		var state := _state(hero_path)
		var controller := ProgressionController.new(state)
		for discipline in state.get_disciplines():
			var progress := state.get_discipline_progress(discipline.discipline_id)
			assert_eq(progress.add_xp(5), [2], str(discipline.discipline_id))
			var screen := _screen()
			assert_true(screen.open_for_evolution(
				_request(state, discipline.discipline_id, 2, tested + 1),
				controller,
			))
			await _settle()
			assert_true(screen.is_evolution_choice_mode())
			assert_false(screen.is_consultative())
			assert_eq(screen.current_discipline_id, discipline.discipline_id)
			assert_eq(screen.get_evolution_rank(), 2)
			assert_eq(screen.get_tab_count(), 1)
			var available := screen.get_available_evolution_node_ids()
			assert_eq(available.size(), 2, str(discipline.discipline_id))
			var selected_id := available[0]
			var selected_node := screen.get_graph().get_node_view(
				selected_id
			).node_data as SkillUpgradeData
			assert_true(screen.confirm_evolution_choice(selected_id))
			assert_false(screen.visible)
			assert_true(progress.get_selected_upgrade_ids().has(selected_id))
			var base_spell: Spell = state.unit.spells.filter(
				func(spell): return spell.skill_tree == discipline
			)[0]
			var grid := GridData.new(4, 4)
			var caster := SpellCaster.new(
				grid,
				Pathfinder.new(grid),
				null,
			)
			var gathered: Array = caster._gather_modifiers(state.unit, base_spell)
			for modifier in selected_node.get_spell_modifiers():
				assert_true(gathered.has(modifier), selected_node.upgrade_id)
			screen.queue_free()
			await get_tree().process_frame
			tested += 1
	assert_eq(tested, 12)


func test_threshold_is_queued_but_ui_waits_for_the_explicit_safe_point() -> void:
	var state := _prepare_global_run()
	await _settle(1)
	var discipline := state.get_disciplines()[0] as DisciplineData
	state.add_discipline_xp(discipline.discipline_id, 4)
	var battle = BATTLE_SCRIPT.new()
	battle.turn_state = TurnState.new()
	battle.units = [state.unit]
	battle._active_trigger_sequence = 42
	GameManager.discipline_xp_gained.connect(battle._on_discipline_xp_gained)
	var spell: Spell = state.unit.spells.filter(
		func(candidate): return candidate.skill_tree == discipline
	)[0]
	EventBus.spell_cast.emit(state.unit, spell, {"effective_cast": true})
	var pending := battle.get_pending_evolution_requests()
	assert_eq(pending.size(), 1)
	assert_eq(pending[0]["character_id"], state.character_id)
	assert_eq(pending[0]["discipline_id"], discipline.discipline_id)
	assert_eq(pending[0]["pending_rank"], 2)
	assert_eq(pending[0]["source_spell_id"], spell.get_effective_spell_id())
	assert_eq(pending[0]["trigger_sequence"], 42)
	assert_false(GameManager.get_persistent_run_ui().get_skill_tree_screen().visible)
	GameManager.discipline_xp_gained.disconnect(battle._on_discipline_xp_gained)
	battle.free()


func test_failed_cancelled_and_non_threshold_casts_never_open_evolution_ui() -> void:
	var state := _prepare_global_run()
	await _settle(1)
	var discipline := state.get_disciplines()[0] as DisciplineData
	var progress := state.get_discipline_progress(discipline.discipline_id)
	var spell: Spell = state.unit.spells.filter(
		func(candidate): return candidate.skill_tree == discipline
	)[0]
	var battle = BATTLE_SCRIPT.new()
	battle.turn_state = TurnState.new()
	battle.units = [state.unit]
	GameManager.discipline_xp_gained.connect(battle._on_discipline_xp_gained)
	EventBus.spell_cast.emit(state.unit, spell, {"failed": true})
	assert_eq(progress.xp, 0)
	assert_true(battle.get_pending_evolution_requests().is_empty())
	EventBus.spell_cast.emit(state.unit, spell, {"effective_cast": true})
	assert_eq(progress.xp, 1)
	assert_true(battle.get_pending_evolution_requests().is_empty())
	battle.turn_state.on_spell_selected(spell)
	battle.turn_state.on_cancel()
	assert_eq(progress.xp, 1)
	assert_false(GameManager.get_persistent_run_ui().get_skill_tree_screen().visible)
	GameManager.discipline_xp_gained.disconnect(battle._on_discipline_xp_gained)
	battle.free()


func test_safe_point_opens_mandatory_screen_applies_choice_and_resumes() -> void:
	var state := _prepare_global_run()
	await _settle(1)
	var discipline := state.get_disciplines()[0] as DisciplineData
	state.add_discipline_xp(discipline.discipline_id, 5)
	var run_ui := GameManager.get_persistent_run_ui()
	run_ui.evolution_feedback_duration = 0.001
	run_ui.get_skill_evolution_overlay().reduced_motion = true
	GameManager.set_run_ui_mode(PersistentRunUI.RunUIMode.COMBAT)
	var battle = BATTLE_SCRIPT.new()
	battle.turn_state = TurnState.new()
	assert_true(battle._evolution_queue.enqueue(
		_request(state, discipline.discipline_id, 2)
	))
	battle._process_evolution_queue_at_safe_point()
	await _settle(3)
	var overlay := run_ui.get_skill_evolution_overlay()
	assert_true(overlay.visible)
	assert_false(run_ui.get_skill_tree_screen().visible)
	assert_eq(battle.get_combat_evolution_state(), &"SKILL_EVOLUTION_UI")
	assert_true(battle.is_combat_input_locked_for_evolution())
	var available := overlay.get_available_upgrade_ids()
	assert_eq(available.size(), 2)
	assert_true(overlay.select_upgrade_by_id(available[0]))
	assert_true(overlay.request_confirmation())
	await get_tree().create_timer(0.3, true).timeout
	await _settle(4)
	assert_false(overlay.visible)
	assert_false(get_tree().paused)
	assert_false(battle.is_combat_input_locked_for_evolution())
	assert_eq(battle.get_combat_evolution_state(), &"")
	assert_eq(
		state.get_discipline_progress(discipline.discipline_id).get_selected_upgrade_ids(),
		[available[0]],
	)
	battle.free()


func test_last_action_victory_is_deferred_while_evolution_is_pending() -> void:
	var state := _state(HERO_PATHS[2])
	var battle = BATTLE_SCRIPT.new()
	battle.turn_state = TurnState.new()
	assert_true(battle._evolution_queue.enqueue(
		_request(state, state.get_disciplines()[0].discipline_id, 2)
	))
	battle._request_battle_outcome(true)
	assert_true(battle._battle_outcome_waiting)
	assert_true(battle._waiting_outcome_victory)
	assert_false(battle._battle_over)
	battle.free()


func test_two_pending_ranks_are_resolved_r2_then_r3_before_resume() -> void:
	var state := _prepare_global_run()
	await _settle(1)
	var discipline := state.get_disciplines()[0] as DisciplineData
	state.add_discipline_xp(discipline.discipline_id, 12)
	var run_ui := GameManager.get_persistent_run_ui()
	run_ui.evolution_feedback_duration = 0.001
	run_ui.get_skill_evolution_overlay().reduced_motion = true
	GameManager.set_run_ui_mode(PersistentRunUI.RunUIMode.COMBAT)
	var battle = BATTLE_SCRIPT.new()
	battle.turn_state = TurnState.new()
	assert_true(battle._evolution_queue.enqueue(
		_request(state, discipline.discipline_id, 2, 8)
	))
	assert_true(battle._evolution_queue.enqueue(
		_request(state, discipline.discipline_id, 3, 8)
	))
	battle._process_evolution_queue_at_safe_point()
	await _settle(3)
	var overlay := run_ui.get_skill_evolution_overlay()
	assert_eq(overlay.get_request_id(), battle._evolution_queue.peek().request_id)
	var rank_two_choice := await _resolve_first_overlay_choice(run_ui)
	assert_true(overlay.visible)
	var rank_three_choices := overlay.get_available_upgrade_ids()
	assert_eq(rank_three_choices.size(), 2)
	var rank_three_choice := await _resolve_first_overlay_choice(run_ui)
	assert_false(battle.is_combat_input_locked_for_evolution())
	assert_eq(
		state.get_discipline_progress(discipline.discipline_id).get_selected_upgrade_ids(),
		[rank_two_choice, rank_three_choice],
	)
	battle.free()


func test_capstone_r5_is_focused_and_persists_in_snapshot() -> void:
	var state := _state(HERO_PATHS[1])
	var discipline := state.get_disciplines()[0] as DisciplineData
	var progress := state.get_discipline_progress(discipline.discipline_id)
	progress.add_xp(30)
	for rank in [2, 3, 4]:
		var available := SkillTreeResolver.get_available_nodes(
			discipline,
			rank,
			progress.rank,
			progress.get_pending_rank_choices(),
			progress.get_selected_upgrade_ids(),
		)
		assert_false(available.is_empty())
		assert_not_null(progress.select_upgrade(available[0].upgrade_id, rank))
	var screen := _screen()
	assert_true(screen.open_for_evolution(
		_request(state, discipline.discipline_id, 5, 18),
		ProgressionController.new(state),
	))
	await _settle()
	assert_eq(screen.get_evolution_rank(), 5)
	var capstones := screen.get_available_evolution_node_ids()
	assert_eq(capstones.size(), 2)
	assert_true(screen.confirm_evolution_choice(capstones[0]))
	var snapshot := state.get_progression_snapshot()
	var restored := _state(HERO_PATHS[1])
	assert_true(restored.restore_progression_snapshot(snapshot))
	assert_eq(
		restored.get_discipline_progress(discipline.discipline_id).get_selected_upgrade_ids(),
		progress.get_selected_upgrade_ids(),
	)


func test_existing_pending_choices_are_queued_in_party_discipline_rank_order() -> void:
	_prepare_global_run()
	var states := GameManager.get_ordered_character_states()
	states[0].add_discipline_xp(states[0].get_disciplines()[0].discipline_id, 12)
	states[0].add_discipline_xp(states[0].get_disciplines()[1].discipline_id, 5)
	states[1].add_discipline_xp(states[1].get_disciplines()[0].discipline_id, 5)
	var battle = BATTLE_SCRIPT.new()
	battle._enqueue_existing_pending_evolutions()
	var pending := battle.get_pending_evolution_requests()
	assert_eq(pending.map(func(item): return item["character_id"]), [
		states[0].character_id,
		states[0].character_id,
		states[0].character_id,
		states[1].character_id,
	])
	assert_eq(pending.map(func(item): return item["pending_rank"]), [2, 3, 2, 2])
	assert_true(pending.all(func(item): return item["trigger_sequence"] == 0))
	battle.free()


func test_two_characters_are_presented_in_request_creation_order() -> void:
	_prepare_global_run()
	await _settle(1)
	var states := GameManager.get_ordered_character_states()
	var elf_discipline := states[0].get_disciplines()[0] as DisciplineData
	var mage_discipline := states[1].get_disciplines()[0] as DisciplineData
	states[0].add_discipline_xp(elf_discipline.discipline_id, 5)
	states[1].add_discipline_xp(mage_discipline.discipline_id, 5)
	var run_ui := GameManager.get_persistent_run_ui()
	run_ui.evolution_feedback_duration = 0.001
	run_ui.get_skill_evolution_overlay().reduced_motion = true
	GameManager.set_run_ui_mode(PersistentRunUI.RunUIMode.COMBAT)
	var battle = BATTLE_SCRIPT.new()
	battle.turn_state = TurnState.new()
	battle._evolution_queue.enqueue(
		_request(states[0], elf_discipline.discipline_id, 2, 11)
	)
	battle._evolution_queue.enqueue(
		_request(states[1], mage_discipline.discipline_id, 2, 12)
	)
	battle._process_evolution_queue_at_safe_point()
	await _settle(3)
	var overlay := run_ui.get_skill_evolution_overlay()
	assert_eq(overlay.get_request_id(), battle._evolution_queue.peek().request_id)
	var elf_choice := await _resolve_first_overlay_choice(run_ui)
	assert_true(overlay.visible)
	var mage_choice := await _resolve_first_overlay_choice(run_ui)
	assert_eq(
		states[0].get_discipline_progress(elf_discipline.discipline_id).get_selected_upgrade_ids(),
		[elf_choice],
	)
	assert_eq(
		states[1].get_discipline_progress(mage_discipline.discipline_id).get_selected_upgrade_ids(),
		[mage_choice],
	)
	battle.free()


func test_enemy_turn_start_is_suspended_before_statuses_or_ai() -> void:
	var battle = BATTLE_SCRIPT.new()
	battle.turn_state = TurnState.new()
	battle._evolution_processing = true
	var enemy := Unit.new()
	enemy.team = 1
	enemy.unit_name = "IA suspendue"
	battle._on_turn_started(enemy)
	assert_true(battle._turn_start_deferred_for_evolution)
	assert_eq(
		battle.turn_state.current,
		TurnState.State.SKILL_EVOLUTION_PENDING,
	)
	battle._evolution_processing = false
	battle.free()


func test_last_action_choice_is_resolved_before_victory_screen() -> void:
	var state := _prepare_global_run()
	await _settle(1)
	var discipline := state.get_disciplines()[0] as DisciplineData
	state.add_discipline_xp(discipline.discipline_id, 5)
	var run_ui := GameManager.get_persistent_run_ui()
	run_ui.evolution_feedback_duration = 0.001
	run_ui.get_skill_evolution_overlay().reduced_motion = true
	GameManager.set_run_ui_mode(PersistentRunUI.RunUIMode.COMBAT)
	var battle = BATTLE_SCRIPT.new()
	battle.turn_state = TurnState.new()
	battle._evolution_queue.enqueue(_request(state, discipline.discipline_id, 2))
	battle._request_battle_outcome(true)
	battle._process_evolution_queue_at_safe_point()
	await _settle(3)
	var overlay := run_ui.get_skill_evolution_overlay()
	assert_true(overlay.visible)
	assert_false(run_ui.get_skill_tree_screen().visible)
	assert_false(battle._battle_over)
	var choice := await _resolve_first_overlay_choice(run_ui)
	assert_true(battle._battle_over)
	assert_false(overlay.visible)
	assert_true(
		state.get_discipline_progress(discipline.discipline_id).get_selected_upgrade_ids().has(choice)
	)
	battle.free()
