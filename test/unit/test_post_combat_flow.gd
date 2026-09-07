extends GutTest

const SCREEN_SCENE := preload("res://ui/post_combat/PostCombatScreen.tscn")
const GAME_MANAGER_SCRIPT := preload("res://core/game_manager.gd")
const TEAM_HEAL := preload("res://data/post_combat/rewards/team_heal_percent.tres")
const HERO_MAX_HP := preload("res://data/post_combat/rewards/hero_max_hp.tres")
const NEXT_SHIELD := preload("res://data/post_combat/rewards/next_combat_shield.tres")
const ELF_PATH := "res://data/units/alliés/elfe.tres"


func before_each() -> void:
	GameManager.cleanup_run_state()
	await get_tree().process_frame
	_prepare_global_run(2)


func after_each() -> void:
	GameManager.set_reduced_motion_enabled(false)
	GameManager.cleanup_run_state()
	await get_tree().process_frame


func test_combat_report_tracks_real_events_casts_movement_and_idle_hero() -> void:
	var states := GameManager.get_ordered_character_states()
	var elf := states[0].unit as Unit
	var mage := states[1].unit as Unit
	var warrior := states[2].unit as Unit
	elf.grid_pos = Vector2i(0, 0)
	mage.grid_pos = Vector2i(1, 0)
	warrior.grid_pos = Vector2i(2, 0)
	var tracker := CombatReportTracker.new()
	tracker.begin(states, 0, "Salle test")
	var enemy := Unit.new("Cible", 1, 40)
	enemy.take_damage(12, elf)
	elf.take_damage(7, enemy)
	elf.heal(4, mage)
	elf.add_shield(6, mage)
	var victim := Unit.new("Victime", 1, 5)
	victim.take_damage(8, elf)
	elf.grid_pos = Vector2i(3, 1)
	var spell := elf.spells[0] as Spell
	EventBus.spell_cast.emit(elf, spell, {"affected_units": [enemy, victim]})
	EventBus.spell_cast.emit(elf, spell, {"affected_units": [enemy]})
	var report := tracker.finalize(states, true)
	var elf_report := report.get_character_report(states[0].character_id)
	var mage_report := report.get_character_report(states[1].character_id)
	var warrior_report := report.get_character_report(states[2].character_id)
	assert_eq(elf_report.damage_dealt, 20)
	assert_eq(elf_report.damage_taken, 7)
	assert_eq(elf_report.kills, 1)
	assert_eq(elf_report.cells_moved, 4)
	assert_eq(elf_report.spells_cast_total, 2)
	assert_eq(elf_report.spells_cast_by_id[str(spell.get_effective_spell_id())], 2)
	assert_eq(mage_report.healing_done, 4)
	assert_eq(mage_report.shield_applied, 6)
	assert_eq(warrior_report.damage_dealt, 0)
	assert_eq(warrior_report.spells_cast_total, 0)


func test_progression_snapshots_keep_before_after_rank_and_acquired_node() -> void:
	var states := GameManager.get_ordered_character_states()
	var state := states[0] as CharacterRunState
	var discipline := state.get_disciplines()[0] as DisciplineData
	var progress := state.get_discipline_progress(discipline.discipline_id)
	progress.add_xp(4)
	var tracker := CombatReportTracker.new()
	tracker.begin(states, 0, "Progression")
	assert_eq(progress.add_xp(1), [2])
	var available := SkillTreeResolver.get_available_nodes(
		discipline,
		2,
		progress.rank,
		progress.get_pending_rank_choices(),
		progress.get_selected_upgrade_ids(),
	)
	assert_true(state.select_upgrade(discipline.discipline_id, 2, available[0].upgrade_id))
	var report := tracker.finalize(states, true)
	var character := report.get_character_report(state.character_id)
	var delta := character.discipline_deltas[0]
	assert_eq(delta.xp_before, 4)
	assert_eq(delta.xp_after, 5)
	assert_eq(delta.rank_before, 1)
	assert_eq(delta.rank_after, 2)
	assert_eq(delta.reached_ranks, [2])
	assert_eq(delta.acquired_nodes.size(), 1)
	assert_eq(delta.acquired_nodes[0]["upgrade_id"], available[0].upgrade_id)
	assert_eq(character.selected_nodes_during_combat.size(), 1)
	assert_eq(character.discipline_deltas.size(), 4)


func test_report_contains_three_characters_and_all_twelve_discipline_deltas() -> void:
	var states := GameManager.get_ordered_character_states()
	var tracker := CombatReportTracker.new()
	tracker.begin(states, 0, "Trio")
	var report := tracker.finalize(states, true)
	assert_eq(report.character_reports.size(), 3)
	var total_deltas := 0
	for character in report.character_reports:
		total_deltas += character.discipline_deltas.size()
		for delta in character.discipline_deltas:
			assert_eq(delta.xp_before, delta.xp_after)
	assert_eq(total_deltas, 12)


func test_team_heal_is_clamped_and_applied_once() -> void:
	var states := GameManager.get_ordered_character_states()
	for state in states:
		state.unit.current_hp = state.unit.max_hp.get_int() - 3
	var service := PostCombatRewardService.new()
	var report := _reward_report(&"heal_report")
	var pending := {}
	var result := service.apply(report, TEAM_HEAL, &"", states, pending)
	assert_true(result["success"])
	for state in states:
		assert_eq(state.unit.current_hp, state.unit.max_hp.get_int())
	var hp_after := states[0].unit.current_hp
	var duplicate := service.apply(report, TEAM_HEAL, &"", states, pending)
	assert_false(duplicate["success"])
	assert_eq(duplicate["error_code"], "REWARD_ALREADY_APPLIED")
	assert_eq(states[0].unit.current_hp, hp_after)


func test_hero_max_hp_uses_persistent_stat_modifier_and_heals_ten() -> void:
	var states := GameManager.get_ordered_character_states()
	var target := states[1] as CharacterRunState
	target.unit.current_hp -= 20
	var old_max := target.unit.max_hp.get_int()
	var old_hp := target.unit.current_hp
	var service := PostCombatRewardService.new()
	var report := _reward_report(&"max_hp_report")
	var result := service.apply(
		report,
		HERO_MAX_HP,
		target.character_id,
		states,
		{},
	)
	assert_true(result["success"])
	assert_eq(target.unit.max_hp.get_int(), old_max + 10)
	assert_eq(target.unit.current_hp, old_hp + 10)
	target.unit.reset_combat_resources()
	assert_eq(target.unit.max_hp.get_int(), old_max + 10)
	var duplicate := service.apply(
		report,
		HERO_MAX_HP,
		target.character_id,
		states,
		{},
	)
	assert_false(duplicate["success"])
	assert_eq(target.unit.max_hp.get_int(), old_max + 10)


func test_next_combat_shield_is_stored_max_applied_and_consumed_once() -> void:
	var states := GameManager.get_ordered_character_states()
	var service := PostCombatRewardService.new()
	var pending := {}
	var report := _reward_report(&"shield_report")
	var result := service.apply(report, NEXT_SHIELD, &"", states, pending)
	assert_true(result["success"])
	assert_eq(pending.size(), 3)
	for state in states:
		assert_eq(state.unit.current_shield, 0)
	var applied := service.consume_next_combat_shields(states, pending)
	assert_eq(applied.size(), 3)
	assert_true(pending.is_empty())
	for state in states:
		assert_eq(state.unit.current_shield, 6)
	assert_true(service.consume_next_combat_shields(states, pending).is_empty())
	for state in states:
		assert_eq(state.unit.current_shield, 6)


func test_reward_options_are_two_deterministic_relic_cards() -> void:
	GameManager._last_combat_report = _reward_report(&"options")
	GameManager._room_exit_selected = true
	assert_true(GameManager.can_claim_post_combat_equipment(&"options"))
	assert_false(GameManager.can_claim_post_combat_equipment(&"wrong_report"))
	var options := GameManager.get_post_combat_reward_options()
	assert_eq(options.size(), 2)
	assert_eq(GameManager.get_post_combat_reward_options(), options)
	assert_ne(options[0]["item_id"], options[1]["item_id"])
	for option in options:
		var definition := option["definition"] as ItemDefinition
		assert_true(definition.is_valid())
		assert_true(definition.is_relic())
		assert_not_null(definition.get_inventory_icon())
		assert_true((option["compatible_character_ids"] as Array).is_empty())


func test_reward_offer_and_applied_state_survive_snapshot_restore() -> void:
	GameManager._last_combat_report = _reward_report(&"persistent_offer")
	GameManager._room_exit_selected = true
	var initial_options := GameManager.get_post_combat_reward_options()
	var initial_ids := initial_options.map(func(option): return option["item_id"])
	var selected := initial_options[0] as Dictionary
	assert_true(GameManager.confirm_post_combat_equipment(
		selected["item_id"],
		&"",
	).get("success", false))
	var snapshot := GameManager.get_inventory_equipment_snapshot()
	assert_true(snapshot.has("equipment_reward"))
	assert_true(GameManager._equipment_reward_service.reset(
		GameManager.item_catalog,
		999999,
	))
	assert_true(GameManager.restore_inventory_equipment_snapshot(snapshot))
	var restored_reward_snapshot := GameManager.get_equipment_reward_deck_snapshot()
	var restored_ids := (
		restored_reward_snapshot["options_by_report"]["persistent_offer"] as Array
	).map(func(item_id): return StringName(item_id))
	assert_eq(restored_ids, initial_ids)
	assert_false(GameManager.can_claim_post_combat_equipment(&"persistent_offer"))
	assert_false(GameManager.confirm_post_combat_equipment(
		selected["item_id"],
		&"",
	).get("success", true))


func test_unconfirmed_reward_selection_survives_snapshot_restore() -> void:
	GameManager._last_combat_report = _reward_report(&"persistent_selection")
	GameManager._room_exit_selected = true
	var initial_options := GameManager.get_post_combat_reward_options()
	var selected_id := StringName(initial_options[1]["item_id"])
	var inventory_count: int = (
		GameManager.run_inventory.capacity
		- GameManager.run_inventory.get_empty_slot_count()
	)
	assert_true(GameManager.select_post_combat_equipment(selected_id))
	var snapshot := GameManager.get_inventory_equipment_snapshot()
	var reward_snapshot := snapshot["equipment_reward"] as Dictionary
	assert_eq(
		StringName(reward_snapshot["selected_by_report"]["persistent_selection"]),
		selected_id,
	)
	assert_eq(
		StringName(reward_snapshot["reward_states_by_report"]["persistent_selection"]),
		&"selected",
	)
	assert_true(GameManager._equipment_reward_service.reset(
		GameManager.item_catalog,
		123456,
	))
	assert_true(GameManager.restore_inventory_equipment_snapshot(snapshot))
	assert_eq(GameManager.get_selected_post_combat_equipment(), selected_id)
	assert_eq(
		GameManager.run_inventory.capacity
		- GameManager.run_inventory.get_empty_slot_count(),
		inventory_count,
	)


func test_screen_runs_victory_stats_progression_and_displays_two_cards() -> void:
	GameManager._last_combat_report = _finalized_global_report_with_progress()
	var deck_before := GameManager.get_equipment_reward_deck_snapshot()
	var screen := SCREEN_SCENE.instantiate() as PostCombatScreen
	add_child_autofree(screen)
	await get_tree().process_frame
	assert_eq(screen.get_phase_name(), &"VICTORY_REVEAL")
	assert_eq(screen.get_stat_card_count(), 3)
	assert_eq(screen.get_progression_panel_count(), 3)
	assert_eq(screen.get_reward_card_count(), 0)
	assert_eq(GameManager.get_equipment_reward_deck_snapshot(), deck_before)
	screen.advance_or_skip()
	assert_eq(screen.get_phase_name(), &"VICTORY_REVEAL")
	screen.advance_or_skip()
	assert_eq(screen.get_phase_name(), &"COMBAT_STATS")
	screen.advance_or_skip()
	screen.advance_or_skip()
	assert_eq(screen.get_phase_name(), &"PROGRESSION")
	assert_eq(GameManager.get_equipment_reward_deck_snapshot(), deck_before)
	screen.advance_or_skip()
	screen.advance_or_skip()
	assert_eq(screen.get_phase_name(), &"REWARD_SELECTION")
	assert_eq(screen.get_reward_card_count(), 2)
	var deck_after := GameManager.get_equipment_reward_deck_snapshot()
	assert_eq((deck_after["offered_ids"] as Array).size(), 2)
	assert_eq(
		(deck_after["deck"] as Array).size(),
		(deck_before["deck"] as Array).size() - 2,
	)


func test_solo_victory_names_the_actual_non_achilles_hero() -> void:
	GameManager.cleanup_run_state()
	assert_true(GameManager._prepare_preconfigured_run(_run_data(2), [ELF_PATH]))
	GameManager.current_room_index = 0
	var states := GameManager.get_ordered_character_states()
	var tracker := CombatReportTracker.new()
	tracker.begin(states, 0, "Salle solo")
	GameManager._last_combat_report = tracker.finalize(states, true)
	GameManager.set_reduced_motion_enabled(true)
	var screen := SCREEN_SCENE.instantiate() as PostCombatScreen
	add_child_autofree(screen)
	await get_tree().process_frame
	assert_eq((screen.get_node("%VictoryTitle") as Label).text, "SALLE SÉCURISÉE")
	assert_eq((screen.get_node("%VictorySubtitle") as Label).text, "Elfe demeure debout.")
	assert_false((screen.get_node("%VictorySubtitle") as Label).text.contains("Achille"))


func test_incomplete_wave_chain_announces_a_wave_and_pending_decision() -> void:
	GameManager.cleanup_run_state()
	var run := RunData.new()
	run.run_name = "Chaîne de vagues"
	run.room_flow_mode = RunData.RoomFlowMode.WAVE_CHAIN
	run.maximum_waves_per_room = 10
	run.rooms = [
		load("res://data/rooms/test_waves/first_run_room_01_waves.tres") as RoomData,
		load("res://data/rooms/first_run_room_02.tres") as RoomData,
	]
	assert_true(GameManager._prepare_preconfigured_run(run, [ELF_PATH]))
	GameManager.current_room_index = 0
	var states := GameManager.get_ordered_character_states()
	var tracker := CombatReportTracker.new()
	tracker.begin(states, 0, "Vague solo")
	GameManager._last_combat_report = tracker.finalize(states, true)
	GameManager.set_reduced_motion_enabled(true)
	var screen := SCREEN_SCENE.instantiate() as PostCombatScreen
	add_child_autofree(screen)
	await get_tree().process_frame
	assert_eq((screen.get_node("%PhaseTitle") as Label).text, "RÉSULTAT DE VAGUE")
	assert_eq((screen.get_node("%VictoryTitle") as Label).text, "VAGUE REPOUSSÉE")
	assert_eq(
		(screen.get_node("%StatusLabel") as Label).text,
		"Une décision reste à prendre.",
	)
	assert_true(screen._can_enter_room_decision())


func test_room_decision_shows_secured_gains_party_state_and_qualitative_risk() -> void:
	GameManager.cleanup_run_state()
	var run := RunData.new()
	run.room_flow_mode = RunData.RoomFlowMode.WAVE_CHAIN
	run.maximum_waves_per_room = 10
	run.rooms = [
		load("res://data/rooms/test_waves/first_run_room_01_waves.tres") as RoomData,
		load("res://data/rooms/first_run_room_02.tres") as RoomData,
	]
	assert_true(GameManager._prepare_preconfigured_run(
		run,
		GameManager.PRODUCTION_HERO_DATA_PATHS,
	))
	GameManager.current_room_index = 0
	var states := GameManager.get_ordered_character_states()
	states[0].unit.current_hp = maxi(1, states[0].unit.max_hp.get_int() / 2)
	var tracker := CombatReportTracker.new()
	tracker.begin(states, 0, "Gué forestier")
	GameManager._last_combat_report = tracker.finalize(states, true)
	var deck_before := GameManager.get_equipment_reward_deck_snapshot()
	var screen := SCREEN_SCENE.instantiate() as PostCombatScreen
	add_child_autofree(screen)
	await get_tree().process_frame
	screen.advance_or_skip()
	screen.advance_or_skip()
	assert_eq(screen.get_phase_name(), &"ROOM_DECISION")
	var snapshot := screen.get_decision_visual_snapshot()
	assert_eq(snapshot["party_card_count"], 3)
	assert_string_contains(snapshot["threat_text"], "MENACE")
	assert_string_contains(snapshot["secured_text"], "XP")
	assert_string_contains(snapshot["secured_text"], "objets")
	assert_eq(snapshot["reward_text"], "Coffre de salle")
	assert_string_contains(snapshot["reward_detail_text"], "perdu")
	assert_string_contains(snapshot["ultimate_chance_text"], "CHANCE ULTIME")
	assert_string_contains(snapshot["ultimate_chance_text"], "%")
	assert_string_contains(snapshot["ultimate_chance_text"], "+2 à +5")
	assert_eq(snapshot["heal_text"], "Progression et équipement")
	assert_false(str(snapshot["detail_text"]).contains("/"))
	assert_false(str(snapshot["detail_text"]).contains("Vague"))
	assert_eq(snapshot["status_text"], "")
	assert_eq(snapshot["leave_button_text"], "SÉCURISER ET PARTIR")
	assert_eq(snapshot["continue_button_text"], "POUSSER PLUS LOIN")
	assert_null(screen.find_child("MysteryRewardDetail", true, false))
	assert_null(screen.find_child("RewardGrowth", true, false))
	assert_null(screen.find_child("ThreatDetail", true, false))
	assert_null(screen.find_child("DecisionRisk", true, false))
	assert_eq(GameManager.get_equipment_reward_deck_snapshot(), deck_before)
	assert_true(GameManager.get_post_combat_reward_options().is_empty())
	assert_true(screen.choose_leave_room())
	assert_eq(screen.get_phase_name(), &"COMBAT_STATS")
	assert_eq(GameManager.get_equipment_reward_deck_snapshot(), deck_before)
	assert_true(GameManager.can_claim_post_combat_equipment(
		GameManager.get_current_combat_report().report_id
	))
	_reach_reward_phase(screen)
	assert_eq(screen.get_phase_name(), &"REWARD_SELECTION")
	assert_eq(screen.get_reward_card_count(), 2)


func test_push_more_button_never_builds_or_consumes_equipment_offer() -> void:
	GameManager.cleanup_run_state()
	var run := RunData.new()
	run.room_flow_mode = RunData.RoomFlowMode.WAVE_CHAIN
	run.maximum_waves_per_room = 10
	run.rooms = [
		load("res://data/rooms/test_waves/first_run_room_01_waves.tres") as RoomData,
		load("res://data/rooms/first_run_room_02.tres") as RoomData,
	]
	assert_true(GameManager._prepare_preconfigured_run(
		run,
		GameManager.PRODUCTION_HERO_DATA_PATHS,
	))
	GameManager.current_room_index = 0
	var tracker := CombatReportTracker.new()
	tracker.begin(GameManager.get_ordered_character_states(), 0, "Gué forestier")
	GameManager._last_combat_report = tracker.finalize(
		GameManager.get_ordered_character_states(),
		true,
	)
	var screen := SCREEN_SCENE.instantiate() as PostCombatScreen
	screen.transition_duration = 60.0
	add_child_autofree(screen)
	await get_tree().process_frame
	screen.advance_or_skip()
	screen.advance_or_skip()
	assert_eq(screen.get_phase_name(), &"ROOM_DECISION")
	var deck_before := GameManager.get_equipment_reward_deck_snapshot()
	assert_true(GameManager.get_post_combat_reward_options().is_empty())
	(screen.get_node("%PushWaveButton") as Button).pressed.emit()
	assert_eq(screen.get_phase_name(), &"TRANSITIONING")
	assert_eq(GameManager.get_equipment_reward_deck_snapshot(), deck_before)
	assert_eq((deck_before["offered_ids"] as Array).size(), 0)
	assert_eq((deck_before["discarded_ids"] as Array).size(), 0)
	screen.queue_free()
	await get_tree().process_frame


func test_progression_skip_reaches_exact_final_values_without_choice_ui() -> void:
	GameManager._last_combat_report = _finalized_global_report_with_progress()
	var screen := SCREEN_SCENE.instantiate() as PostCombatScreen
	add_child_autofree(screen)
	await get_tree().process_frame
	screen.advance_or_skip()
	screen.advance_or_skip()
	screen.advance_or_skip()
	screen.advance_or_skip()
	assert_eq(screen.get_phase_name(), &"PROGRESSION")
	screen.advance_or_skip()
	for snapshot in screen.get_progression_visual_snapshot():
		assert_eq(int(snapshot["value"]), int(snapshot["xp_after"]))
	assert_false(GameManager.has_active_progression_screen())
	assert_false(GameManager.has_pending_progression_choices())


func test_progression_skip_preserves_multiple_thresholds_and_characters() -> void:
	var report: CombatReport = _finalized_global_report_with_progress()
	var elf_delta: DisciplineProgressDelta = report.character_reports[0].discipline_deltas[0]
	elf_delta.xp_after = 30
	elf_delta.rank_after = 5
	elf_delta.reached_ranks = [2, 3, 4, 5]
	elf_delta.acquired_nodes.append({
		"upgrade_id": &"test_capstone",
		"display_name": "Apogée de test",
		"description": "Nœud de test multi-palier.",
		"rank": 5,
	})
	var mage_delta: DisciplineProgressDelta = report.character_reports[1].discipline_deltas[0]
	mage_delta.xp_after = 5
	mage_delta.rank_after = 2
	mage_delta.reached_ranks = [2]
	mage_delta.acquired_nodes.append({
		"upgrade_id": &"test_mage_node",
		"display_name": "Étincelle de test",
		"description": "Nœud de test second personnage.",
		"rank": 2,
	})
	GameManager._last_combat_report = report
	var screen := SCREEN_SCENE.instantiate() as PostCombatScreen
	add_child_autofree(screen)
	await get_tree().process_frame
	for _index in 5:
		screen.advance_or_skip()
	var snapshots := screen.get_progression_visual_snapshot()
	assert_eq(snapshots[0]["value"], 30.0)
	assert_eq(snapshots[0]["rank_text"], "Rang 5")
	assert_string_contains(snapshots[0]["node_text"], "Apogée de test")
	assert_eq(snapshots[4]["value"], 5.0)
	assert_eq(snapshots[4]["rank_text"], "Rang 2")
	assert_string_contains(snapshots[4]["node_text"], "Étincelle de test")


func test_reward_selection_is_unique_explicit_and_double_apply_is_blocked() -> void:
	GameManager._last_combat_report = _finalized_global_report_with_progress()
	var screen := SCREEN_SCENE.instantiate() as PostCombatScreen
	add_child_autofree(screen)
	await get_tree().process_frame
	_reach_reward_phase(screen)
	assert_eq(screen.get_phase_name(), &"REWARD_SELECTION")
	assert_false(screen.confirm_selected_reward())
	var option := GameManager.get_post_combat_reward_options()[0]
	var item_id := StringName(option["item_id"])
	var empty_before := GameManager.get_run_inventory().get_empty_slot_count()
	assert_true(screen.select_reward_by_id(item_id))
	assert_true(screen.confirm_selected_reward())
	assert_eq(screen.get_phase_name(), &"COMPLETED")
	assert_false(screen.confirm_selected_reward())
	assert_true(GameManager.get_current_combat_report().reward_result["success"])
	assert_false(GameManager.get_current_combat_report().reward_result["equipped"])
	assert_eq(GameManager.get_run_inventory().get_empty_slot_count(), empty_before - 1)
	for state in GameManager.get_ordered_character_states():
		assert_true(state.equipment_loadout.get_equipped_items().is_empty())


func test_reward_error_blocks_completion_and_stays_controlled() -> void:
	GameManager._last_combat_report = _finalized_global_report_with_progress()
	var screen := SCREEN_SCENE.instantiate() as PostCombatScreen
	add_child_autofree(screen)
	await get_tree().process_frame
	_reach_reward_phase(screen)
	var option: Dictionary = GameManager.get_post_combat_reward_options()[0]
	var item_id := StringName(option["item_id"])
	assert_true(screen.select_reward_by_id(item_id))
	var removable_instance_id: StringName = &""
	while GameManager.get_run_inventory().get_empty_slot_count() > 0:
		var fill_result := GameManager.get_run_inventory().try_add(
			&"warrior_training_sword",
			1,
		)
		assert_true(fill_result.get("success", false))
		removable_instance_id = StringName(fill_result.get("instance_ids", [])[0])
	assert_false(screen.confirm_selected_reward())
	assert_eq(screen.get_phase_name(), &"REWARD_SELECTION")
	assert_true((screen.get_node("%EquipmentRewardOverlay") as EquipmentRewardOverlay).error_label.visible)
	assert_true(GameManager.get_current_combat_report().reward_result.is_empty())
	assert_false(GameManager.complete_post_combat_transition(
		GameManager.get_current_combat_report().report_id
	))
	assert_true(GameManager.get_run_inventory().remove_quantity(
		removable_instance_id,
		1,
	).get("success", false))
	assert_true(screen.confirm_selected_reward())
	assert_eq(screen.get_phase_name(), &"COMPLETED")
	assert_eq(GameManager.get_run_inventory().get_empty_slot_count(), 0)


func test_refused_transition_restores_visible_retry_without_losing_reward() -> void:
	GameManager._last_combat_report = _finalized_global_report_with_progress()
	GameManager.set_reduced_motion_enabled(true)
	var screen := SCREEN_SCENE.instantiate() as PostCombatScreen
	add_child_autofree(screen)
	await get_tree().process_frame
	_reach_reward_phase(screen)
	var option := GameManager.get_post_combat_reward_options()[0] as Dictionary
	assert_true(screen.select_reward_by_id(StringName(option["item_id"])))
	assert_true(screen.confirm_selected_reward())
	GameManager._post_combat_transition_pending = true
	var overlay := screen.get_node("%EquipmentRewardOverlay") as EquipmentRewardOverlay
	await overlay.confirmation_finished
	var transition_tween := screen.get("_current_tween") as Tween
	if transition_tween != null and transition_tween.is_running():
		await transition_tween.finished

	var retry_button := screen.get_node("%ContinueButton") as Button
	var visible_error := screen.get_node("%RewardError") as Label
	assert_eq(screen.get_phase_name(), &"COMPLETED")
	assert_true(visible_error.is_visible_in_tree())
	assert_string_contains(visible_error.text, "récompense reste enregistrée")
	assert_true(retry_button.is_visible_in_tree())
	assert_false(retry_button.disabled)
	assert_eq(retry_button.text, "RÉESSAYER LA TRANSITION")
	assert_false(overlay.visible)
	assert_true(GameManager.get_current_combat_report().reward_result.get("success", false))

	retry_button.pressed.emit()
	assert_eq(screen.get_phase_name(), &"TRANSITIONING")
	var retry_tween := screen.get("_current_tween") as Tween
	if retry_tween != null and retry_tween.is_running():
		await retry_tween.finished
	assert_eq(screen.get_phase_name(), &"COMPLETED")
	assert_true(visible_error.is_visible_in_tree())
	assert_false(retry_button.disabled)


func test_invalid_two_card_offer_is_visible_blocking_and_transactional() -> void:
	GameManager._last_combat_report = _finalized_global_report_with_progress()
	var reward_snapshot := GameManager.get_equipment_reward_deck_snapshot()
	var eligible_ids := reward_snapshot["eligible_ids"] as Array
	for index in maxi(0, eligible_ids.size() - 1):
		var item_id := StringName(eligible_ids[index])
		if GameManager.run_inventory.contains_definition(item_id):
			continue
		assert_true(
			GameManager.run_inventory.try_add(item_id, 1).get("success", false),
			str(item_id),
		)
	var deck_before_offer := GameManager.get_equipment_reward_deck_snapshot()
	var screen := SCREEN_SCENE.instantiate() as PostCombatScreen
	add_child_autofree(screen)
	await get_tree().process_frame
	_reach_reward_phase(screen)
	assert_eq(screen.get_phase_name(), &"REWARD_SELECTION")
	assert_eq(screen.get_reward_card_count(), 0)
	var overlay := screen.get_node("%EquipmentRewardOverlay") as EquipmentRewardOverlay
	assert_true(overlay.visible)
	assert_true(overlay.error_label.visible)
	assert_false(GameManager.complete_post_combat_transition(
		GameManager.get_current_combat_report().report_id
	))
	assert_eq(GameManager.get_equipment_reward_deck_snapshot(), deck_before_offer)


func test_reward_layout_is_full_screen_without_legacy_panel_at_supported_resolutions() -> void:
	GameManager._last_combat_report = _finalized_global_report_with_progress()
	var screen := SCREEN_SCENE.instantiate() as PostCombatScreen
	add_child_autofree(screen)
	await get_tree().process_frame
	_reach_reward_phase(screen)
	for viewport_size in [Vector2(1280, 720), Vector2(1920, 1080), Vector2(2560, 1440)]:
		screen.apply_viewport_size_for_test(viewport_size)
		await get_tree().process_frame
		var screen_rect := screen.get_global_rect()
		var overlay := screen.get_node("%EquipmentRewardOverlay") as EquipmentRewardOverlay
		var snapshot := overlay.get_visual_snapshot()
		assert_false(screen.get_node("SafeMargin").visible)
		assert_true(overlay.visible)
		assert_eq(screen.get_reward_card_count(), 2)
		for card_rect in snapshot["card_rects"]:
			assert_true(
				_rect_contains(screen_rect, card_rect),
				str(viewport_size),
			)
		var card_sizes := snapshot["card_sizes"] as Array
		assert_almost_eq(card_sizes[0].x / card_sizes[0].y, 0.535, 0.01)


func test_victory_routes_to_post_combat_only_after_report_finalization() -> void:
	var manager := GAME_MANAGER_SCRIPT.new()
	var run := _run_data(2)
	assert_true(manager._prepare_preconfigured_run(run, GameManager.PRODUCTION_HERO_DATA_PATHS))
	manager.current_room_index = 0
	manager.begin_combat_report()
	var requested: Array[String] = []
	manager.scene_change_requested.connect(func(path): requested.append(path))
	manager.on_battle_won()
	assert_true(manager.get_current_combat_report().finalized)
	assert_eq(requested, [manager.POST_COMBAT_SCREEN_PATH])
	assert_false(requested.has(manager.PROGRESSION_CHOICE_SCREEN_PATH))
	assert_false(requested.has(manager.ROOM_TRANSITION_SCREEN_PATH))
	manager.cleanup_run_state()
	manager.free()


func test_victory_background_is_frozen_before_result_overlay() -> void:
	GameManager.begin_combat_report()
	var battlefield_frame := GradientTexture2D.new()
	GameManager._post_combat_background_texture = battlefield_frame
	GameManager._post_combat_background_captured_for_outcome = true

	assert_true(GameManager.capture_battle_outcome_background())
	assert_same(
		GameManager.get_post_combat_background_texture(),
		battlefield_frame,
		"Un overlay tardif ne doit jamais remplacer le dernier frame de combat.",
	)
	var snapshot := GameManager.get_battle_outcome_transition_snapshot()
	assert_true(snapshot["background_captured"])
	assert_true(snapshot["background_ready"])


func test_last_room_keeps_existing_no_equipment_rule_and_run_result() -> void:
	var manager := GAME_MANAGER_SCRIPT.new()
	assert_true(manager._prepare_preconfigured_run(
		_run_data(1),
		GameManager.PRODUCTION_HERO_DATA_PATHS,
	))
	manager.current_room_index = 0
	manager.begin_combat_report()
	manager.on_battle_won()
	var report_id := manager.get_current_combat_report().report_id
	assert_false(manager.can_claim_post_combat_equipment(report_id))
	assert_true(manager.get_post_combat_reward_options().is_empty())
	assert_false(manager.select_post_combat_equipment(&"any_item"))
	var unavailable_reward := manager.confirm_post_combat_equipment(&"any_item")
	assert_eq(unavailable_reward.get("error_code"), "FINAL_ROOM_HAS_NO_REWARD")
	assert_string_contains(str(unavailable_reward.get("error", "")), "récompense")
	assert_false(str(unavailable_reward.get("error", "")).contains("équipement"))
	var requested: Array[String] = []
	manager.scene_change_requested.connect(func(path): requested.append(path))
	assert_true(manager.complete_post_combat_transition(report_id))
	assert_eq(requested, [manager.RUN_RESULT_SCREEN_PATH])
	assert_false(manager.complete_post_combat_transition(report_id))
	manager.cleanup_run_state()
	manager.free()


func test_unsecured_room_reward_error_uses_neutral_reward_wording() -> void:
	var manager := GAME_MANAGER_SCRIPT.new()
	assert_true(manager._prepare_preconfigured_run(
		_run_data(2),
		GameManager.PRODUCTION_HERO_DATA_PATHS,
	))
	manager.current_room_index = 0
	manager.begin_combat_report()
	manager.on_battle_won()
	manager._room_exit_selected = false
	var unavailable_reward := manager.confirm_post_combat_equipment(&"any_item")
	assert_eq(unavailable_reward.get("error_code"), "ROOM_REWARD_UNAVAILABLE")
	assert_string_contains(str(unavailable_reward.get("error", "")), "récompense")
	assert_false(str(unavailable_reward.get("error", "")).contains("équipement"))
	manager.cleanup_run_state()
	manager.free()


func test_last_room_screen_transitions_without_opening_equipment_overlay() -> void:
	GameManager.cleanup_run_state()
	_prepare_global_run(1)
	GameManager._last_combat_report = _finalized_global_report_with_progress()
	var deck_before := GameManager.get_equipment_reward_deck_snapshot()
	var screen := SCREEN_SCENE.instantiate() as PostCombatScreen
	screen.transition_duration = 60.0
	add_child_autofree(screen)
	await get_tree().process_frame
	for _index in 8:
		if screen.get_phase_name() == &"PROGRESSION":
			break
		screen.advance_or_skip()
	assert_eq(screen.get_phase_name(), &"PROGRESSION")
	screen.advance_or_skip()
	if screen.get_phase_name() == &"PROGRESSION":
		screen.advance_or_skip()
	assert_eq(screen.get_phase_name(), &"TRANSITIONING")
	assert_eq(screen.get_reward_card_count(), 0)
	assert_eq(GameManager.get_equipment_reward_deck_snapshot(), deck_before)
	screen.queue_free()
	await get_tree().process_frame


func test_post_combat_reduced_motion_skips_spatial_reveal_sequences() -> void:
	GameManager.cleanup_run_state()
	_prepare_global_run(1)
	GameManager._last_combat_report = _finalized_global_report_with_progress()
	GameManager.set_reduced_motion_enabled(true)
	var screen := SCREEN_SCENE.instantiate() as PostCombatScreen
	add_child_autofree(screen)
	await get_tree().process_frame
	assert_true(bool(screen.get("_reduced_motion")))
	assert_false(bool(screen.get("_animation_active")))
	assert_eq((screen.get_node("%VictoryTitle") as Control).scale, Vector2.ONE)
	assert_true(screen.get_node("%EquipmentRewardOverlay").reduced_motion)


func _prepare_global_run(room_count: int) -> void:
	assert_true(GameManager._prepare_preconfigured_run(
		_run_data(room_count),
		GameManager.PRODUCTION_HERO_DATA_PATHS,
	))
	GameManager.current_room_index = 0


func _run_data(room_count: int) -> RunData:
	var run := RunData.new()
	run.run_name = "Test après-combat"
	for index in room_count:
		var room := RoomData.new()
		room.room_name = "Salle %d" % (index + 1)
		run.rooms.append(room)
	return run


func _reward_report(report_id: StringName) -> CombatReport:
	var report := CombatReport.new()
	report.report_id = report_id
	report.room_index = 0
	report.room_name = "Salle test"
	report.finalized = true
	report.victory = true
	return report


func _finalized_global_report_with_progress() -> CombatReport:
	var states := GameManager.get_ordered_character_states()
	var state := states[0] as CharacterRunState
	var discipline := state.get_disciplines()[0] as DisciplineData
	var progress := state.get_discipline_progress(discipline.discipline_id)
	progress.add_xp(4)
	var tracker := CombatReportTracker.new()
	tracker.begin(states, 0, "Salle 1 — Gué forestier")
	progress.add_xp(1)
	var available := SkillTreeResolver.get_available_nodes(
		discipline,
		2,
		progress.rank,
		progress.get_pending_rank_choices(),
		progress.get_selected_upgrade_ids(),
	)
	state.select_upgrade(discipline.discipline_id, 2, available[0].upgrade_id)
	GameManager._room_exit_selected = true
	return tracker.finalize(states, true)


func _reach_reward_phase(screen: PostCombatScreen) -> void:
	for _index in 8:
		if screen.get_phase_name() == &"REWARD_SELECTION":
			return
		screen.advance_or_skip()


func _rect_contains(outer: Rect2, inner: Rect2) -> bool:
	const TOLERANCE := 0.5
	return inner.position.x >= outer.position.x - TOLERANCE \
		and inner.position.y >= outer.position.y - TOLERANCE \
		and inner.end.x <= outer.end.x + TOLERANCE \
		and inner.end.y <= outer.end.y + TOLERANCE
