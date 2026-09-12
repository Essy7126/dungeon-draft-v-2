extends GutTest
const Challenge = preload("res://core/expedition/catabase_challenge_state.gd")
const Adapter = preload("res://battle/catabase_challenge_battle.gd")
const Factory = preload("res://test/support/factory.gd")
const Cleanup = preload("res://test/support/isolated_battlefield_cleanup.gd")
var managers: Array = []


class Manager:
	extends "res://core/game_manager.gd"
	func start_next_battle() -> void:
		pass


	func _request_scene_change(
		_path: String,
		_mode: PersistentRunUI.RunUIMode = PersistentRunUI.RunUIMode.NON_COMBAT,
	) -> void:
		pass


	func _ensure_persistent_run_ui() -> PersistentRunUI:
		return null


class Room:
	extends Node
	var units: Array[Unit] = []
	var grid: GridData
	var pathfinder: Pathfinder
	var active: Unit
	var accepts := true


	func get_active_unit() -> Unit:
		return active


	func _can_accept_player_intent() -> bool:
		return accepts


func _manager():
	var manager := Manager.new()
	DirAccess.make_dir_recursive_absolute("res://artifacts/dev/challenge_tests")
	manager.expedition_save_path = "res://artifacts/dev/challenge_tests/save_%d.json" % Time.get_ticks_usec()
	add_child(manager)
	managers.append(manager)
	return manager


func after_each() -> void:
	for manager in managers:
		manager.cleanup_run_state()
		manager.queue_free()
	managers.clear()
	await get_tree().process_frame


func test_declining_has_no_time_penalty_and_previous_alert_is_consumed() -> void:
	var state := Challenge.new()
	state.outgoing_alert = 2
	state.begin_encounter()
	assert_eq(state.incoming_alert, 2)
	state.turns = 99
	state.finish_combat(5)
	assert_eq(state.outgoing_alert, 0)
	assert_false(state.outgoing_boon)
	state.begin_encounter()
	assert_eq(state.incoming_alert, 0)


func test_each_objective_has_a_success_boundary_and_failure_never_accumulates() -> void:
	for contract in ["tempo", "control", "seal"]:
		var state := Challenge.new()
		state.outgoing_alert = 2
		state.begin_encounter()
		state.contract = contract
		state.turns = 6
		state.displaced = 1
		state.finish_combat(5)
		assert_eq(state.outgoing_alert, 1, contract)
		assert_false(state.outgoing_boon)
		state.turns = 5
		state.displaced = 2
		state.sabotaged = true
		state.finish_combat(5)
		assert_eq(state.outgoing_alert, 0)
		assert_true(state.outgoing_boon)


func test_consequence_save_is_validated_and_has_no_combat_loadout() -> void:
	var state := Challenge.new()
	state.enabled = true
	state.outgoing_boon = true
	var saved: Dictionary = JSON.parse_string(JSON.stringify(state.snapshot()))
	var restored := Challenge.new()
	assert_true(restored.restore(saved))
	assert_true(restored.outgoing_boon)
	assert_false(saved.has("cards"))
	saved.outgoing_alert = 0.5
	assert_false(restored.restore(saved))
	assert_true(restored.outgoing_boon)


func test_consequences_preserve_spells_stats_and_baseline_attack() -> void:
	var hero := Factory.make_unit("Achille", 0)
	var enemy := Factory.make_unit("Ennemi", 1)
	var second := Factory.make_unit("Autre", 1)
	var spell := Factory.make_spell({ "damage": 10, "ap_cost": 2 })
	hero.spells = [spell]
	var state := Challenge.new()
	state.incoming_alert = 1
	state.incoming_boon = true
	var room := Room.new()
	room.units = [hero, enemy, second]
	var adapter := Adapter.new()
	adapter.battle = room
	adapter.hero = hero
	adapter.state = state
	adapter._apply_consequences()
	assert_eq(hero.current_shield, 10)
	assert_eq(enemy.current_shield, 10)
	assert_eq(second.current_shield, 0)
	assert_eq(enemy.max_hp.get_int(), 100)
	assert_eq(enemy.attack_power.get_int(), 20)
	assert_eq(hero.spells, [spell])
	assert_true(hero.basic_attack_enabled)
	assert_eq(hero.max_ap.get_int(), 6)
	assert_eq(hero.max_mp.get_int(), 3)
	for unit in room.units:
		unit.clear_combat_effect_history()
		unit.clear_shield()
	adapter.free()
	room.free()


func test_seal_is_reachable_costs_two_ap_once_and_respects_turn_four() -> void:
	var field = Factory.make_battlefield(7, 5)
	var hero := Factory.make_unit("Achille", 0)
	field.grid.place_unit(hero, Vector2i(2, 2))
	var room := Room.new()
	room.grid = field.grid
	room.pathfinder = field.pathfinder
	room.active = hero
	var adapter := Adapter.new()
	adapter.battle = room
	adapter.hero = hero
	adapter.state = Challenge.new()
	adapter.state.contract = "seal"
	adapter.state.turns = 4
	adapter._find_seal()
	var path: Array = field.pathfinder.find_path(hero.grid_pos, adapter.seal, hero)
	assert_true(path.size() in [2, 3, 4])
	adapter._sabotage()
	assert_false(adapter.state.sabotaged, "Cannot act from too far away")
	field.grid.move_unit(hero.grid_pos, adapter.seal)
	adapter._sabotage()
	assert_true(adapter.state.sabotaged)
	assert_eq(hero.current_ap, 4)
	adapter._sabotage()
	assert_eq(hero.current_ap, 4, "No duplicate payment")
	adapter.state.sabotaged = false
	adapter.state.turns = 5
	adapter._sabotage()
	assert_false(adapter.state.sabotaged)
	assert_eq(hero.current_ap, 4)
	adapter.free()
	room.free()
	hero.clear_combat_effect_history()
	field.terrain.dispose()
	Cleanup.dispose_grid(field.grid)


func test_retired_deck_checkpoint_resumes_with_normal_spells_and_normal_rewards() -> void:
	var manager = _manager()
	assert_true(manager.start_expedition(2401))
	var original: Array = manager.expedition.character.unit.spells.duplicate()
	var snapshot: Dictionary = manager.get_expedition_snapshot()
	snapshot.session["deck"] = {
		"enabled": true,
		"configured": true,
		"outgoing_alert": 1,
		"outgoing_boon": true,
		"cards": { "c0": "frappe" },
	}
	var restored = _manager()
	assert_true(restored.restore_expedition_snapshot(snapshot))
	var session: ExpeditionSession = restored.expedition
	assert_true(session.challenges.enabled)
	assert_eq(session.challenges.outgoing_alert, 1)
	assert_true(session.challenges.outgoing_boon)
	assert_eq(session.character.unit.spells.size(), original.size())
	for index in original.size():
		assert_eq(
			session.character.unit.spells[index].get_effective_spell_id(),
			original[index].get_effective_spell_id(),
		)
	assert_false(session.to_snapshot().has("deck"))
	assert_true(session.to_snapshot().has("challenges"))
	assert_true(session.combat_won())
	var rewards := session.reward_options(restored.item_catalog)
	assert_false(rewards.is_empty())
	for reward in rewards:
		assert_false(str(reward.id).begins_with("deck:"))
	var result: Dictionary = restored.claim_expedition_reward("supplies")
	assert_true(result.success)
	assert_true(result.saved)


func test_new_challenge_checkpoint_keeps_standard_loadout_on_restore() -> void:
	var manager = _manager()
	assert_true(manager.start_expedition(2401, { }, true))
	assert_eq(manager.expedition.character.unit.spells.size(), 4)
	manager.expedition.challenges.outgoing_alert = 1
	assert_true(manager.save_expedition())
	var restored = _manager()
	assert_true(
		restored.restore_expedition_snapshot(
			ExpeditionSaveService.read_snapshot(manager.expedition_save_path)
		)
	)
	assert_eq(restored.expedition.character.unit.spells.size(), 4)
	assert_eq(restored.expedition.challenges.outgoing_alert, 1)
