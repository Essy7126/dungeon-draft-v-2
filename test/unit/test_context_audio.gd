extends GutTest
const Audio := preload("res://battle/audio/catabase_battle_audio.gd")
const Player := preload("res://core/audio/feedback_player.gd")


class Encounter extends Node:
	var units: Array[Unit] = []
	var grid := GridData.new(5, 5)


	func _exit_tree() -> void:
		preload("res://test/support/isolated_battlefield_cleanup.gd").dispose_grid(grid)
		units.clear()


func test_steps_follow_committed_walk_cells_not_pushes_or_deployment() -> void:
	var battle := Encounter.new()
	var hero := Unit.new("Hero", 0, 100, 20)
	battle.units.append(hero)
	add_child_autofree(battle)
	var audio := Audio.new()
	battle.add_child(audio)
	watch_signals(audio.feedback)
	EventBus.combat_started.emit(battle.units, battle.grid)
	battle.grid.place_unit(hero, Vector2i(1, 1))
	battle.grid.relocate_unit(hero, Vector2i(1, 2))
	assert_signal_not_emitted(audio.feedback, "played")
	EventBus.voluntary_movement_prepared.emit(hero, [Vector2i(1, 2), Vector2i(1, 3)], 1, 1, &"walk")
	battle.grid.relocate_unit(hero, Vector2i(1, 3))
	assert_signal_emitted_with_parameters(audio.feedback, "played", [&"step"])
	EventBus.voluntary_movement_resolved.emit(hero, [], 1, &"walk")
	await get_tree().create_timer(0.16).timeout
	battle.grid.relocate_unit(hero, Vector2i(1, 4))
	assert_signal_emit_count(audio.feedback, "played", 1)
	audio.dispose()
	assert_eq(battle.grid.occupancy_changed.get_connections().size(), 0)


func test_resolved_facts_skip_overheal_periodic_damage_and_duplicate_events() -> void:
	var battle := Encounter.new()
	var hero := Unit.new("Hero", 0, 100, 20)
	var enemy := Unit.new("Enemy", 1, 100, 20)
	battle.units.assign([hero, enemy])
	add_child_autofree(battle)
	var audio := Audio.new()
	battle.add_child(audio)
	watch_signals(audio.feedback)
	EventBus.heal_received.emit(
		CombatEventFact.create(&"heal_received", hero, hero, { "amount_applied": 0 })
	)
	EventBus.hit_resolved.emit(
		CombatEventFact.create(
			&"hit_resolved",
			hero,
			enemy,
			{ "amount_resolved": 5, "amount_applied": 5, "is_periodic": true },
		)
	)
	EventBus.hit_resolved.emit(
		CombatEventFact.create(
			&"hit_resolved",
			enemy,
			hero,
			{ "ability_id": &"achilles_peleid_strike", "amount_resolved": 5, "amount_applied": 5 },
		)
	)
	assert_signal_not_emitted(audio.feedback, "played")
	var hit := CombatEventFact.create(
		&"hit_resolved",
		hero,
		enemy,
		{ "amount_resolved": 5, "amount_applied": 5 },
	)
	EventBus.hit_resolved.emit(hit)
	assert_signal_emitted_with_parameters(audio.feedback, "played", [&"hit"])
	await get_tree().create_timer(0.16).timeout
	EventBus.hit_resolved.emit(hit)
	assert_signal_emit_count(audio.feedback, "played", 1)
	audio.feedback.stop()
	EventBus.heal_received.emit(
		CombatEventFact.create(&"heal_received", hero, hero, { "amount_applied": 5 })
	)
	assert_signal_emitted_with_parameters(audio.feedback, "played", [&"heal"])
	EventBus.shield_absorption_resolved.emit(
		CombatEventFact.create(&"shield_absorption_resolved", hero, enemy, { "amount_absorbed": 5 })
	)
	assert_signal_emitted_with_parameters(audio.feedback, "played", [&"block"])
	EventBus.attack_dodge_resolved.emit(
		CombatEventFact.create(&"attack_dodge_resolved", hero, enemy)
	)
	assert_signal_emitted_with_parameters(audio.feedback, "played", [&"dodge"])
	audio.dispose()
	var count: int = get_signal_emit_count(audio.feedback, "played")
	EventBus.heal_received.emit(
		CombatEventFact.create(&"heal_received", hero, hero, { "amount_applied": 7 })
	)
	assert_eq(get_signal_emit_count(audio.feedback, "played"), count)


func test_ui_audio_works_in_pause_and_variants_do_not_repeat() -> void:
	var player := Player.new()
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child_autofree(player)
	get_tree().paused = true
	var played: bool = player.play(&"open")
	get_tree().paused = false
	assert_true(played)
	assert_false(player.play(&"open"), "Suppress accidental double activation")
	player.stop()
	assert_true(player.play(&"step"))
	var first: AudioStream = player.voices[0].stream
	player.stop()
	await get_tree().create_timer(0.16).timeout
	assert_true(player.play(&"step"))
	assert_ne(player.voices[0].stream, first)
	player.stop()
	for voice in player.voices:
		assert_null(voice.stream)
		assert_false(voice.playing)


func test_reward_sound_requires_confirmed_success() -> void:
	AudioManager.feedback.stop()
	await get_tree().create_timer(0.16).timeout
	var overlay: EquipmentRewardOverlay = load("res://ui/post_combat/EquipmentRewardOverlay.tscn").instantiate()
	add_child_autofree(overlay)
	var catalog: ItemCatalog = load("res://data/items/catalogs/default_item_catalog.tres")
	var definitions: Array = catalog.get_definitions().filter(
		func(item):
			return item != null and item.equipment_slot != ItemDefinition.EquipmentSlot.NONE,
	)
	assert_gte(definitions.size(), 2)
	if definitions.size() < 2:
		return
	var options: Array[Dictionary] = []
	for index in 2:
		options.append({ "item_id": definitions[index].item_id, "definition": definitions[index] })
	assert_true(overlay.present(options, true))
	AudioManager.feedback.stop()
	watch_signals(AudioManager.feedback)
	overlay.select_item_by_id(options[0].item_id)
	overlay.request_confirmation()
	overlay.resolve_confirmation(false, "Transaction refusée")
	assert_signal_emitted_with_parameters(AudioManager.feedback, "played", [&"select"])
	assert_eq(get_signal_emit_count(AudioManager.feedback, "played"), 1)
	overlay.request_confirmation()
	overlay.resolve_confirmation(true)
	assert_signal_emitted_with_parameters(AudioManager.feedback, "played", [&"reward"])
	AudioManager.feedback.stop()
