extends GutTest

const GAME_MANAGER_SCRIPT := preload("res://core/game_manager.gd")
const FIRST_RUN := preload("res://data/runs/run_default.tres")


func test_first_run_exposes_the_thirty_minute_three_wave_contract() -> void:
	assert_eq(FIRST_RUN.target_duration_minutes, 30)
	assert_eq(FIRST_RUN.extended_duration_minutes, 45)
	assert_eq(FIRST_RUN.maximum_waves_per_room, 3)
	assert_true(FIRST_RUN.is_valid(), str(FIRST_RUN.validation_errors()))
	for room in FIRST_RUN.rooms:
		assert_eq(room.get_wave_count(), 3, room.room_name)
		assert_eq(room.get_wave(0).enemy_health_multiplier, 1.0)
		assert_gt(room.get_wave(1).enemy_health_multiplier, 1.0)
		assert_gt(
			room.get_wave(2).enemy_health_multiplier,
			room.get_wave(1).enemy_health_multiplier,
		)
		assert_gt(
			room.get_wave(2).reward_multiplier,
			room.get_wave(1).reward_multiplier,
		)


func test_legacy_room_keeps_its_single_encounter_contract() -> void:
	var room := RoomData.new()
	room.encounter_definition = FIRST_RUN.rooms[0].encounter_definition
	assert_eq(room.get_wave_count(), 1)
	assert_same(room.get_encounter_for_wave(0), room.encounter_definition)
	assert_null(room.get_encounter_for_wave(1))
	assert_eq(room.get_reward_multiplier_for_wave(0), 1.0)


func test_victory_waits_for_the_player_before_clearing_a_multi_wave_room() -> void:
	var manager := GAME_MANAGER_SCRIPT.new()
	assert_true(manager._prepare_preconfigured_run(
		FIRST_RUN,
		GameManager.PRODUCTION_HERO_DATA_PATHS,
	))
	manager.current_room_index = 0
	manager.current_wave_index = 0
	manager.begin_combat_report()
	var cleared_rooms: Array[int] = []
	manager.room_cleared.connect(func(index: int): cleared_rooms.append(index))
	manager.on_battle_won()

	var snapshot := manager.get_post_combat_decision_snapshot()
	assert_true(snapshot.get("can_continue", false))
	assert_eq(snapshot.get("wave_number", 0), 1)
	assert_eq(snapshot.get("wave_count", 0), 3)
	assert_eq(cleared_rooms, [])
	assert_true(manager.select_current_room_exit(
		manager.get_current_combat_report().report_id
	))
	assert_eq(cleared_rooms, [0])
	manager.cleanup_run_state()
	manager.free()


func test_current_wave_selects_its_data_driven_encounter() -> void:
	var manager := GAME_MANAGER_SCRIPT.new()
	assert_true(manager._prepare_preconfigured_run(
		FIRST_RUN,
		GameManager.PRODUCTION_HERO_DATA_PATHS,
	))
	manager.current_room_index = 0
	manager.current_wave_index = 2
	assert_same(
		manager.get_current_encounter_definition(),
		FIRST_RUN.rooms[0].get_wave(2).encounter_definition,
	)
	assert_almost_eq(manager.get_current_room_reward_multiplier(), 4.75, 0.001)
	manager.cleanup_run_state()
	manager.free()
