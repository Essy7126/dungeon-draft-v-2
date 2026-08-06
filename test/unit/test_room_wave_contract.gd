extends GutTest

const GAME_MANAGER_SCRIPT := preload("res://core/game_manager.gd")
const FIRST_RUN := preload("res://data/runs/fixed_trio_prototype_run.tres")


func test_wave_run_exposes_the_hidden_three_to_ten_wave_contract() -> void:
	assert_eq(FIRST_RUN.target_duration_minutes, 30)
	assert_eq(FIRST_RUN.extended_duration_minutes, 45)
	assert_eq(FIRST_RUN.maximum_waves_per_room, 10)
	assert_true(FIRST_RUN.uses_wave_chain())
	assert_true(FIRST_RUN.is_valid(), str(FIRST_RUN.validation_errors()))
	var multi_wave_room_count := 0
	for room in FIRST_RUN.rooms:
		if room.waves.is_empty():
			assert_eq(room.get_wave_count(), 1, room.room_name)
			continue
		multi_wave_room_count += 1
		assert_eq(room.get_wave_count(), 10, room.room_name)
		assert_eq(room.minimum_wave_count, 3, room.room_name)
		assert_eq(room.maximum_wave_count, 10, room.room_name)
		assert_eq(room.get_ultimate_reward_base_chance(), 10, room.room_name)
		assert_eq(room.get_ultimate_reward_gain_range(), Vector2i(2, 5), room.room_name)
		assert_eq(room.get_wave(0).enemy_health_multiplier, 1.0)
		assert_gt(room.get_wave(1).enemy_health_multiplier, 1.0)
		assert_gt(
			room.get_wave(2).enemy_health_multiplier,
			room.get_wave(1).enemy_health_multiplier,
		)
		assert_gt(
			room.get_wave(9).reward_multiplier,
			room.get_wave(8).reward_multiplier,
		)
	assert_gte(multi_wave_room_count, 1)


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
	assert_between(int(snapshot.get("wave_count", 0)), 3, 10)
	assert_eq(cleared_rooms, [])
	assert_true(manager.select_current_room_exit(
		manager.get_current_combat_report().report_id
	))
	assert_eq(cleared_rooms, [])
	manager.cleanup_run_state()
	manager.free()


func test_same_seed_produces_the_same_hidden_wave_counts() -> void:
	var first_manager := GAME_MANAGER_SCRIPT.new()
	var second_manager := GAME_MANAGER_SCRIPT.new()
	assert_true(first_manager._prepare_preconfigured_run(
		FIRST_RUN,
		GameManager.PRODUCTION_HERO_DATA_PATHS,
	))
	assert_true(second_manager._prepare_preconfigured_run(
		FIRST_RUN,
		GameManager.PRODUCTION_HERO_DATA_PATHS,
	))
	for room_index in range(FIRST_RUN.rooms.size()):
		first_manager.current_room_index = room_index
		second_manager.current_room_index = room_index
		var first_count := first_manager.get_current_room_wave_count()
		var second_count := second_manager.get_current_room_wave_count()
		var room: RoomData = FIRST_RUN.rooms[room_index]
		assert_between(first_count, room.get_minimum_wave_count(), room.get_maximum_wave_count())
		assert_eq(second_count, first_count)
	first_manager.cleanup_run_state()
	second_manager.cleanup_run_state()
	first_manager.free()
	second_manager.free()


func test_ultimate_reward_chance_is_seeded_and_gains_two_to_five_per_wave() -> void:
	var first_manager := GAME_MANAGER_SCRIPT.new()
	var second_manager := GAME_MANAGER_SCRIPT.new()
	assert_true(first_manager._prepare_preconfigured_run(
		FIRST_RUN,
		GameManager.PRODUCTION_HERO_DATA_PATHS,
	))
	assert_true(second_manager._prepare_preconfigured_run(
		FIRST_RUN,
		GameManager.PRODUCTION_HERO_DATA_PATHS,
	))
	first_manager.current_room_index = 0
	second_manager.current_room_index = 0
	assert_eq(first_manager.get_current_room_ultimate_reward_chance(), 10)
	first_manager.begin_combat_report()
	second_manager.begin_combat_report()
	first_manager.on_battle_won()
	second_manager.on_battle_won()
	var first_wave_chance := first_manager.get_current_room_ultimate_reward_chance()
	assert_eq(first_wave_chance, 10)
	assert_eq(
		second_manager.get_current_room_ultimate_reward_chance(),
		first_wave_chance,
	)
	first_manager.current_wave_index = 1
	second_manager.current_wave_index = 1
	var second_wave_chance := first_manager.get_current_room_ultimate_reward_chance()
	assert_between(second_wave_chance - first_wave_chance, 2, 5)
	assert_eq(
		second_manager.get_current_room_ultimate_reward_chance(),
		second_wave_chance,
	)
	first_manager.current_wave_index = 2
	second_manager.current_wave_index = 2
	var third_wave_chance := first_manager.get_current_room_ultimate_reward_chance()
	assert_between(third_wave_chance - second_wave_chance, 2, 5)
	assert_eq(
		second_manager.get_current_room_ultimate_reward_chance(),
		third_wave_chance,
	)
	first_manager.cleanup_run_state()
	second_manager.cleanup_run_state()
	first_manager.free()
	second_manager.free()


func test_room_report_accumulates_combat_stats_and_xp_across_waves() -> void:
	var manager := GAME_MANAGER_SCRIPT.new()
	assert_true(manager._prepare_preconfigured_run(
		FIRST_RUN,
		GameManager.PRODUCTION_HERO_DATA_PATHS,
	))
	manager.current_room_index = 0
	var state := manager.get_ordered_character_states()[0] as CharacterRunState
	var discipline := state.get_disciplines()[0] as DisciplineData
	var first_wave := manager.begin_combat_report()
	var first_character := first_wave.get_character_report(state.character_id)
	first_character.damage_dealt = 120
	first_character.kills = 2
	state.add_discipline_xp(discipline.discipline_id, 1)
	manager.on_battle_won()
	var first_cumulative := manager.get_current_combat_report()
	var first_report_id := first_cumulative.report_id
	assert_eq(first_cumulative.waves_included, 1)
	assert_eq(
		first_cumulative.get_character_report(state.character_id).damage_dealt,
		120,
	)
	await get_tree().process_frame
	manager.current_wave_index = 1
	manager._room_outcome_resolved = false
	var second_wave := manager.begin_combat_report()
	var second_character := second_wave.get_character_report(state.character_id)
	second_character.damage_dealt = 80
	second_character.kills = 1
	state.add_discipline_xp(discipline.discipline_id, 1)
	manager.on_battle_won()
	var cumulative := manager.get_current_combat_report()
	var cumulative_character := cumulative.get_character_report(state.character_id)
	var cumulative_delta := cumulative_character.discipline_deltas[0]
	assert_eq(cumulative.waves_included, 2)
	assert_ne(cumulative.report_id, first_report_id)
	assert_eq(cumulative_character.damage_dealt, 200)
	assert_eq(cumulative_character.kills, 3)
	assert_eq(cumulative_delta.xp_before, 0)
	assert_eq(cumulative_delta.xp_after, 2)
	assert_eq(manager._get_last_combat_progression_xp(), 2)
	manager.cleanup_run_state()
	manager.free()


func test_early_exit_loses_room_chest_but_unlocks_secured_equipment() -> void:
	var manager := GAME_MANAGER_SCRIPT.new()
	assert_true(manager._prepare_preconfigured_run(
		FIRST_RUN,
		GameManager.PRODUCTION_HERO_DATA_PATHS,
	))
	manager.current_room_index = 0
	manager.current_wave_index = 0
	var states := manager.get_ordered_character_states()
	var first_unit := states[0].unit
	var second_unit := states[1].unit
	var second_maximum := second_unit.max_hp.get_int()
	first_unit.current_hp = 40
	second_unit.current_hp = maxi(1, second_maximum - 5)
	manager.begin_combat_report()
	var cleared_rooms: Array[int] = []
	manager.room_cleared.connect(func(index: int): cleared_rooms.append(index))
	manager.on_battle_won()
	var report_id := manager.get_current_combat_report().report_id
	assert_false(manager.is_current_room_fully_cleared())
	assert_false(manager.is_current_room_ultimate_reward_won())
	assert_true(manager.get_post_combat_reward_options().is_empty())
	assert_true(manager.select_current_room_exit(report_id))
	assert_eq(cleared_rooms, [])
	assert_true(manager.can_claim_post_combat_equipment(report_id))
	assert_eq(first_unit.current_hp, 40)
	assert_eq(second_unit.current_hp, second_maximum - 5)
	assert_false(manager.select_current_room_exit(report_id))
	assert_eq(first_unit.current_hp, 40)
	var options := manager.get_post_combat_reward_options()
	assert_eq(options.size(), 2)
	assert_false(manager.complete_post_combat_transition(report_id))
	var empty_slots_before := manager.run_inventory.get_empty_slot_count()
	var selected := options[0] as Dictionary
	var reward_result := manager.confirm_post_combat_equipment(
		selected["item_id"],
		selected["compatible_character_ids"][0],
	)
	assert_true(reward_result.get("success", false))
	assert_false(reward_result.get("equipped", true))
	assert_eq(manager.run_inventory.get_empty_slot_count(), empty_slots_before - 1)
	assert_false(manager.confirm_post_combat_equipment(
		selected["item_id"],
		selected["compatible_character_ids"][0],
	).get("success", true))
	for state in manager.get_ordered_character_states():
		assert_true(state.equipment_loadout.get_equipped_items().is_empty())
	assert_false(manager.is_current_room_fully_cleared())
	assert_true(manager.complete_post_combat_transition(report_id))
	manager.cleanup_run_state()
	manager.free()


func test_pushing_multiple_waves_keeps_deck_offers_and_discards_unchanged() -> void:
	var manager := GAME_MANAGER_SCRIPT.new()
	assert_true(manager._prepare_preconfigured_run(
		FIRST_RUN,
		GameManager.PRODUCTION_HERO_DATA_PATHS,
	))
	manager.current_room_index = 0
	var deck_before := manager.get_equipment_reward_deck_snapshot()
	for wave_index in 2:
		manager.current_wave_index = wave_index
		manager._room_outcome_resolved = false
		manager._room_exit_selected = false
		manager.begin_combat_report()
		manager.on_battle_won()
		assert_true(manager.can_continue_current_room())
		assert_true(manager.get_post_combat_reward_options().is_empty())
		assert_eq(manager.get_equipment_reward_deck_snapshot(), deck_before)
	var report_id := manager.get_current_combat_report().report_id
	assert_true(manager.select_current_room_exit(report_id))
	var options := manager.get_post_combat_reward_options()
	assert_eq(options.size(), 2)
	assert_eq(manager.get_post_combat_reward_options(), options)
	var deck_after := manager.get_equipment_reward_deck_snapshot()
	assert_eq((deck_after["offered_ids"] as Array).size(), 2)
	assert_eq((deck_after["discarded_ids"] as Array).size(), 0)
	assert_eq(
		(deck_after["deck"] as Array).size(),
		(deck_before["deck"] as Array).size() - 2,
	)
	manager.cleanup_run_state()
	manager.free()


func test_hidden_last_wave_completes_the_room_and_unlocks_its_reward() -> void:
	var manager := GAME_MANAGER_SCRIPT.new()
	assert_true(manager._prepare_preconfigured_run(
		FIRST_RUN,
		GameManager.PRODUCTION_HERO_DATA_PATHS,
	))
	manager.current_room_index = 0
	manager.current_wave_index = manager.get_current_room_wave_count() - 1
	manager.begin_combat_report()
	var cleared_rooms: Array[int] = []
	manager.room_cleared.connect(func(index: int): cleared_rooms.append(index))
	manager.on_battle_won()
	assert_true(manager.is_current_room_fully_cleared())
	assert_eq(cleared_rooms, [0])
	assert_false(manager.get_post_combat_reward_options().is_empty())
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
