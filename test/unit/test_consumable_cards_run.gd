extends GutTest
const Run := preload("res://core/expedition/consumable_cards_run.gd")
const Catalog := preload("res://core/expedition/consumable_card_catalog.gd")
var runs: Array = []
var paths: Array[String] = []


func after_each() -> void:
	for run in runs:
		run.dispose()
	for path in paths:
		ExpeditionSaveService.remove_snapshot(path)
		ExpeditionSaveService.remove_snapshot(path + ".tmp")
	runs.clear()
	paths.clear()


func create_run():
	var run := Run.new()
	var path := "user://cc2_run_test_%d.json" % Time.get_ticks_usec()
	paths.append(path)
	runs.append(run)
	assert_true(run.create(Catalog.preset("gardien"), 641, path))
	return run


func test_real_first_victory_and_checkpoint_after_every_action() -> void:
	var run = create_run()
	assert_true(run.act({ "kind": "depart" }).success, run.last_error)
	if run.battle == null:
		return
	assert_true(run.act({ "kind": "move", "cell": [3, 2] }).success)
	for _turn in 8:
		if run.checkpoint.state.phase != "combat":
			break
		var target: Unit = run.battle.enemies[0]
		assert_true(run.act({
				"kind": "fallback",
				"family": "fallback_strike",
				"cell": [target.grid_pos.x, target.grid_pos.y],
			}).success)
		if run.checkpoint.state.phase != "combat":
			break
		var cell: Vector2i = run.battle.hero.grid_pos
		assert_true(run.act({
				"kind": "fallback",
				"family": "fallback_guard",
				"cell": [cell.x, cell.y],
			}).success)
		assert_true(run.act({ "kind": "end_turn" }).success)
		while run.checkpoint.state.phase == "combat" and run.battle.phase != "hero":
			assert_true(run.act({ "kind": "next_actor" }).success, run.last_error)
		var resumed := Run.new()
		runs.append(resumed)
		assert_true(resumed.resume(run.checkpoint.path), resumed.last_error)
		assert_eq(
			JSON.stringify(resumed.checkpoint.state),
			JSON.stringify(JSON.parse_string(JSON.stringify(run.checkpoint.state))),
		)
	assert_eq(run.checkpoint.state.phase, "reward")
	assert_eq(run.cards.level, 2)
	assert_eq(run.cards.gold, 75)
	assert_eq(run.cards.consumed.size(), 0, "fallbacks never consume copies")
	assert_true(run.act({ "kind": "attribute", "id": "vitality" }).success)
	assert_false(run.act({ "kind": "attribute", "id": "power" }).success)
	assert_true(run.act({ "kind": "continue" }).success)
	assert_eq(int(run.battle.encounter.index), 2)


func test_failed_combat_write_keeps_live_hp_cards_and_action_sequence() -> void:
	var run = create_run()
	assert_true(run.act({ "kind": "depart" }).success)
	if run.battle == null:
		return
	var before: Dictionary = run.battle.snapshot()
	var sequence: int = run.checkpoint.state.action_seq
	watch_signals(EventBus)
	run.checkpoint.writer = func(_data, _path):
		return false
	assert_false(run.act({ "kind": "fallback", "family": "fallback_guard", "cell": [3, 5] }).success)
	assert_eq(run.battle.snapshot(), before)
	assert_eq(int(run.checkpoint.state.action_seq), sequence)
	assert_true(run.checkpoint.blocked)
	assert_signal_not_emitted(EventBus, "ap_changed")
	assert_signal_not_emitted(EventBus, "shield_granted")
	assert_false(EventBus.is_blocking_signals())
	run.checkpoint.writer = ExpeditionSaveService.write_snapshot
	assert_true(run.checkpoint.retry())
	assert_true(run.act({ "kind": "move", "cell": [3, 4] }).success)
	assert_eq(run.battle.hero.grid_pos, Vector2i(3, 4))


func test_chronicle_survives_new_run_without_transferring_power() -> void:
	var run = create_run()
	assert_true(run.act({ "kind": "abandon" }).success)
	var history: Dictionary = run.checkpoint.state.chronicle.duplicate(true)
	assert_eq(history.runs.size(), 1)
	assert_gt(history.families.size(), 0)
	assert_eq(history.runs[0].outcome, "abandoned")
	assert_false(run.act({ "kind": "abandon" }).success)
	var next := Run.new()
	runs.append(next)
	assert_true(next.create(Catalog.preset("assassin"), 642, run.checkpoint.path))
	assert_eq(next.checkpoint.state.chronicle, JSON.parse_string(JSON.stringify(history)))
	assert_eq(next.cards.level, 1)
	assert_eq(next.cards.gold, 40)
	assert_eq(next.cards.consumed.size(), 0)
	assert_eq(next.cards.primary_class, "assassin")
	var malformed: Dictionary = next.checkpoint.state.duplicate(true)
	malformed.chronicle.runs[0].erase("class_id")
	assert_false(Run.Checkpoint.validation_errors(malformed).is_empty())


func test_equipment_roundtrip_keeps_exact_health_ratio_across_json_reload() -> void:
	var run = create_run()
	var gear: Array = Catalog.data().equipment.filter(
		func(row):
			return row.mods.has("hp"),
	)
	assert_gt(gear.size(), 0)
	var state = run.cards
	var candidate := { "route": { "hero_hp": 1, "hero_max_hp": 110 } }
	for hp in range(1, 111):
		candidate.route = { "hero_hp": hp, "hero_max_hp": 110 }
		for row in gear:
			state.equipped[row.slot] = row.id
			Run._rebuild_route(candidate, state, true)
			candidate = JSON.parse_string(JSON.stringify(candidate))
			state.equipped.clear()
			Run._rebuild_route(candidate, state, true)
			assert_eq(int(candidate.route.hero_hp), hp, "%d PV, %s" % [hp, row.id])
	Run._heal_route(candidate, state, .3)
	assert_false(candidate.route.has("equipment_health_basis"))


func test_same_seed_departures_keep_distinct_chronicle_entries() -> void:
	var first = create_run()
	var first_id: String = first.checkpoint.state.run_id
	assert_true(first.act({"kind": "abandon"}).success)
	var second := Run.new()
	runs.append(second)
	assert_true(second.create(Catalog.preset("gardien"), 641, first.checkpoint.path))
	assert_ne(second.checkpoint.state.run_id, first_id)
	assert_eq(second.cards.run_seed, first.cards.run_seed)
	assert_true(second.act({"kind": "abandon"}).success)
	assert_eq(second.checkpoint.state.chronicle.runs.size(), 2)
