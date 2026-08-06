extends GutTest

const GAME_MANAGER_SCRIPT := preload("res://core/game_manager.gd")
const MAIN_RUN: RunData = preload("res://data/runs/first_run.tres")
const DEFAULT_RUN: RunData = preload("res://data/runs/run_default.tres")
const WAVE_RUN: RunData = preload("res://data/runs/fixed_trio_prototype_run.tres")


func test_main_run_uses_single_encounter_flow() -> void:
	assert_true(MAIN_RUN.is_single_encounter_flow())
	assert_eq(MAIN_RUN.get_room_flow_mode_name(), &"SINGLE_ENCOUNTER")


func test_main_run_maximum_waves_is_one() -> void:
	assert_eq(MAIN_RUN.maximum_waves_per_room, 1)


func test_main_run_rooms_have_no_wave_profiles() -> void:
	assert_eq(MAIN_RUN.rooms.size(), 6)
	for room in MAIN_RUN.rooms:
		assert_true(room.waves.is_empty(), room.resource_path)
		assert_eq(room.minimum_wave_count, 1, room.resource_path)
		assert_eq(room.maximum_wave_count, 1, room.resource_path)
		assert_not_null(room.encounter_definition, room.resource_path)
	assert_true(MAIN_RUN.is_valid(), str(MAIN_RUN.validation_errors()))


func test_test_run_uses_wave_chain() -> void:
	assert_true(WAVE_RUN.uses_wave_chain())
	assert_eq(WAVE_RUN.get_room_flow_mode_name(), &"WAVE_CHAIN")
	assert_eq(WAVE_RUN.maximum_waves_per_room, 10)
	assert_true(WAVE_RUN.is_valid(), str(WAVE_RUN.validation_errors()))


func test_test_run_keeps_at_least_one_multi_wave_room() -> void:
	assert_true(WAVE_RUN.rooms.any(func(room): return room.get_wave_count() > 1))


func test_single_and_wave_runs_do_not_share_room_data_resources() -> void:
	var main_paths := MAIN_RUN.rooms.map(func(room): return room.resource_path)
	for room in WAVE_RUN.rooms:
		assert_false(main_paths.has(room.resource_path), room.resource_path)
		for main_room in MAIN_RUN.rooms:
			assert_ne(room, main_room)


func test_wave_wrappers_have_distinct_resource_uids() -> void:
	var first_uid := ResourceLoader.get_resource_uid(
		"res://data/rooms/test_waves/first_run_room_01_waves.tres"
	)
	var third_uid := ResourceLoader.get_resource_uid(
		"res://data/rooms/test_waves/first_run_room_03_waves.tres"
	)
	assert_ne(first_uid, ResourceUID.INVALID_ID)
	assert_ne(third_uid, ResourceUID.INVALID_ID)
	assert_ne(first_uid, third_uid)
	assert_ne(first_uid, ResourceLoader.get_resource_uid(
		"res://data/rooms/first_run_room_01.tres"
	))
	assert_ne(third_uid, ResourceLoader.get_resource_uid(
		"res://data/rooms/first_run_room_03.tres"
	))


func test_run_default_is_classified_explicitly() -> void:
	assert_true(DEFAULT_RUN.is_single_encounter_flow())
	assert_eq(DEFAULT_RUN.maximum_waves_per_room, 1)
	assert_true(DEFAULT_RUN.is_valid(), str(DEFAULT_RUN.validation_errors()))


func test_new_run_data_defaults_to_single_encounter() -> void:
	var run := RunData.new()
	assert_true(run.is_single_encounter_flow())
	assert_eq(run.maximum_waves_per_room, 1)


func test_single_flow_rejects_room_with_wave_profiles() -> void:
	var room := RoomData.new()
	room.encounter_definition = MAIN_RUN.rooms[0].encounter_definition
	var wave := RoomWaveData.new()
	wave.encounter_definition = room.encounter_definition
	room.waves = [wave]
	var run := RunData.new()
	run.rooms = [room]
	assert_true(str(run.validation_errors()).contains("profils de vagues"))


func test_single_flow_requires_valid_base_encounter() -> void:
	var run := RunData.new()
	run.rooms = [RoomData.new()]
	assert_true(str(run.validation_errors()).contains("rencontre de base valide"))


func test_wave_flow_rejects_inverted_wave_range() -> void:
	var room := RoomData.new()
	room.encounter_definition = MAIN_RUN.rooms[0].encounter_definition
	var wave := RoomWaveData.new()
	wave.encounter_definition = room.encounter_definition
	room.waves = [wave]
	room.minimum_wave_count = 2
	room.maximum_wave_count = 1
	var run := RunData.new()
	run.room_flow_mode = RunData.RoomFlowMode.WAVE_CHAIN
	run.maximum_waves_per_room = 10
	run.rooms = [room]
	assert_true(str(run.validation_errors()).contains("plage de vagues inversee"))


func test_single_flow_resolves_one_encounter_per_room_for_every_seed() -> void:
	for run_seed in 100:
		var counts := RunWaveCountResolver.resolve_counts(MAIN_RUN, run_seed)
		assert_eq(counts, PackedInt32Array([1, 1, 1, 1, 1, 1]))


func test_single_flow_is_independent_from_seed() -> void:
	assert_eq(
		RunWaveCountResolver.resolve_counts(MAIN_RUN, -999),
		RunWaveCountResolver.resolve_counts(MAIN_RUN, 999999),
	)


func test_wave_flow_remains_deterministic_for_same_seed() -> void:
	assert_eq(
		RunWaveCountResolver.resolve_counts(WAVE_RUN, 424242),
		RunWaveCountResolver.resolve_counts(WAVE_RUN, 424242),
	)


func test_wave_flow_respects_minimum_and_maximum_counts() -> void:
	var counts := RunWaveCountResolver.resolve_counts(WAVE_RUN, WAVE_RUN.default_seed)
	for room_index in WAVE_RUN.rooms.size():
		assert_between(
			counts[room_index],
			WAVE_RUN.rooms[room_index].get_minimum_wave_count(),
			WAVE_RUN.rooms[room_index].get_maximum_wave_count(),
		)


func test_single_flow_game_manager_contract_and_reward_access() -> void:
	var manager = _manager_for(MAIN_RUN)
	manager.current_room_index = 0
	manager.begin_combat_report()
	manager.on_battle_won()
	var report: CombatReport = manager.get_current_combat_report()
	var snapshot: Dictionary = manager.get_post_combat_decision_snapshot()
	assert_eq(manager.get_current_wave_index(), 0)
	assert_eq(manager.get_current_room_wave_count(), 1)
	assert_false(manager.can_continue_current_room())
	assert_false(manager.continue_current_room_combat(report.report_id))
	assert_eq(manager.get_current_room_reward_multiplier(), 1.0)
	assert_eq(manager.get_current_room_ultimate_reward_chance(), 0)
	assert_false(manager.is_current_room_ultimate_reward_won())
	assert_false(snapshot.waves_enabled)
	assert_eq(snapshot.room_flow_mode, &"SINGLE_ENCOUNTER")
	assert_true(snapshot.room_exit_selected)
	assert_true(manager.can_claim_post_combat_equipment(report.report_id))
	manager.cleanup_run_state()
	manager.free()


func test_single_flow_final_room_finishes_after_one_combat() -> void:
	var manager = _manager_for(MAIN_RUN)
	manager.current_room_index = MAIN_RUN.rooms.size() - 1
	manager.begin_combat_report()
	manager.on_battle_won()
	var report_id: StringName = manager.get_current_combat_report().report_id
	assert_true(manager.complete_post_combat_transition(report_id))
	assert_false(manager.run_active)
	assert_true(manager.get_last_run_result().victory)
	assert_eq(manager.get_last_run_result().room_flow_mode, &"SINGLE_ENCOUNTER")
	manager.cleanup_run_state()
	manager.free()


func test_cleanup_resets_active_flow_mode() -> void:
	var manager = _manager_for(WAVE_RUN)
	assert_true(manager.is_wave_chain_active())
	manager.cleanup_run_state()
	assert_false(manager.is_wave_chain_active())
	assert_eq(manager.get_active_room_flow_mode(), RunData.RoomFlowMode.SINGLE_ENCOUNTER)
	manager.free()


func test_switching_between_modes_does_not_leak_wave_state() -> void:
	var manager = _manager_for(WAVE_RUN)
	manager.current_room_index = 0
	manager.current_wave_index = 2
	assert_true(_prepare_manager_run(manager, MAIN_RUN))
	manager.current_room_index = 0
	assert_false(manager.is_wave_chain_active())
	assert_eq(manager.get_current_wave_index(), 0)
	assert_eq(manager.get_current_room_wave_count(), 1)
	assert_true(_prepare_manager_run(manager, WAVE_RUN))
	manager.current_room_index = 0
	assert_true(manager.is_wave_chain_active())
	assert_between(manager.get_current_room_wave_count(), 3, 10)
	manager.cleanup_run_state()
	manager.free()


func test_report_exports_explicit_room_flow_mode_and_single_segment() -> void:
	var manager = _manager_for(MAIN_RUN)
	manager.current_room_index = 0
	manager.begin_combat_report()
	manager.on_battle_won()
	var payload: Dictionary = manager.get_current_combat_report().to_dictionary()
	assert_eq(payload.room_flow_mode, &"SINGLE_ENCOUNTER")
	assert_false(payload.uses_wave_chain)
	assert_eq(payload.combat_segments_included, 1)
	assert_eq(payload.waves_included, 1)
	manager.cleanup_run_state()
	manager.free()


func test_run_projections_respect_both_flow_modes() -> void:
	var main_projection := EncounterRunProjectionService.project(MAIN_RUN, 1, 100)
	assert_eq(main_projection.room_flow_mode, &"SINGLE_ENCOUNTER")
	assert_false(main_projection.waves_enabled)
	assert_eq(main_projection.theoretical_minimum, MAIN_RUN.rooms.size())
	assert_eq(main_projection.theoretical_maximum, MAIN_RUN.rooms.size())
	assert_eq(main_projection.observed_minimum, MAIN_RUN.rooms.size())
	assert_eq(main_projection.observed_maximum, MAIN_RUN.rooms.size())
	var wave_projection := EncounterRunProjectionService.project(WAVE_RUN, 1, 100)
	assert_eq(wave_projection.room_flow_mode, &"WAVE_CHAIN")
	assert_true(wave_projection.waves_enabled)
	assert_gt(wave_projection.theoretical_maximum, WAVE_RUN.rooms.size())


func _manager_for(run: RunData):
	var manager := GAME_MANAGER_SCRIPT.new()
	assert_true(_prepare_manager_run(manager, run))
	return manager


func _prepare_manager_run(manager, run: RunData) -> bool:
	var prepared: bool = manager._prepare_preconfigured_run(
		run, GameManager.PRODUCTION_HERO_DATA_PATHS
	)
	_consume_known_warrior_uid_warning()
	return prepared


func _consume_known_warrior_uid_warning() -> void:
	# Dette de ressource anterieure a RUN_FLOW_ISOLATION_V1, observee dans la baseline.
	for error in get_errors():
		if error.contains_text("uid://0flkpto1jkby"):
			error.handled = true
