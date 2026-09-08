extends GutTest

const Factory := preload("res://test/support/factory.gd")
const Cleanup := preload("res://test/support/isolated_battlefield_cleanup.gd")
var _fixture_grids: Array[GridData] = []


class ReleaseView extends Node2D:
	signal release_requested
	var preparations := 0
	var recoveries := 0

	func prepare_spell_visual(_cell: Vector2i, _spell: Spell) -> bool:
		preparations += 1
		await release_requested
		return true

	func wait_for_action_visual_finished() -> void:
		recoveries += 1
		await get_tree().process_frame

	func has_optional_visual() -> bool:
		return true

	func set_active(_active: bool) -> void:
		pass


class HudSpy extends RefCounted:
	func update_info(_unit: Unit) -> void:
		pass
	func build_actions(_unit: Unit) -> void:
		pass
	func set_controls_enabled(_enabled: bool) -> void:
		pass
	func set_active_mode(_mode: String) -> void:
		pass
	func detach() -> void:
		pass


class PendingBattle extends "res://battle/battle.gd":
	var launches := 0
	var hp_at_launch := -1
	var observed_target: Unit
	var projectile: Node2D

	func _ready() -> void:
		pass

	func _end_battle(victory: bool) -> void:
		if not _battle_over:
			_battle_over = true
			EventBus.combat_ended.emit(victory)

	func _play_pending_spell_projectile(_unit: Unit, _spell: Spell, _cell: Vector2i) -> Node:
		launches += 1
		hp_at_launch = observed_target.current_hp
		projectile = Node2D.new()
		add_child(projectile)
		return projectile


func after_each() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	for grid in _fixture_grids:
		Cleanup.dispose_grid(grid)
	_fixture_grids.clear()


func test_delayed_damage_and_status_wait_for_release_then_full_flight_and_resolve_once() -> void:
	var f := _fixture()
	var state := {"done": false, "result": {}}
	_capture(f.battle, f.enemy, state)
	await wait_process_frames(2)
	assert_eq(f.view.preparations, 1)
	assert_eq(f.battle.launches, 0)
	assert_eq(f.hero.current_hp, 100)
	f.view.release_requested.emit()
	assert_eq(f.battle.launches, 1)
	assert_eq(f.battle.hp_at_launch, 100)
	assert_eq(f.hero.current_hp, 100)
	assert_false(state.done)
	await _until_done(state)
	assert_true(state.result.resolved)
	assert_eq(f.hero.current_hp, 86)
	assert_eq(f.hero.get_active_statuses().size(), 1)
	assert_eq(f.view.recoveries, 1)
	var second: Dictionary = await f.battle._resolve_pending_ability(f.enemy)
	assert_false(second.had_pending)
	assert_eq(f.hero.current_hp, 86)
	assert_eq(f.battle.launches, 1)


func test_warning_is_committed_at_charge_release_without_consuming_projectile_flight_delay() -> void:
	var f := _fixture()
	f.enemy.pending_ability.clear()
	f.enemy.add_spell(f.spell)
	f.enemy.start_turn()
	var runner := EnemyTurnRunner.new()
	f.battle.add_child(runner)
	runner.setup(f.battle)
	var state := {"done": false}
	_capture_preparation(runner, f.enemy, f.spell, f.hero.grid_pos, state)
	assert_true(f.enemy.pending_ability.is_empty())
	f.view.release_requested.emit()
	assert_false(f.enemy.pending_ability.is_empty(), "The warning starts at charge release, without a flight timer")
	assert_eq(f.hero.current_hp, 100)
	assert_eq(f.hero.get_active_statuses().size(), 0)
	await _until_done(state)
	assert_true(f.enemy.pending_ability.has("spell"))
	assert_eq(f.hero.current_hp, 100)
	assert_eq(f.battle._outcome_deferral_depth, 0)


func test_lethal_projectile_finishes_pending_and_turn_contract_before_combat_closes() -> void:
	var f := _fixture()
	var enemy: Unit = f.enemy
	f.hero.current_hp = 1
	enemy.initiative.base_value = 20
	f.battle.turn_state = TurnState.new()
	f.battle._hud_port = HudSpy.new()
	f.battle.turn_queue = TurnQueue.new()
	f.battle.turn_queue.setup(f.battle.units)
	f.battle.turn_queue.start()
	f.hero.died.connect(f.battle._on_unit_died)
	var events: Array[StringName] = []
	var on_pending := func(source: Unit, _spell: Spell, _payload: Dictionary) -> void:
		if source == enemy:
			events.append(&"pending_resolved")
	var on_turn_end := func(source: Unit, _reason: StringName) -> void:
		if source == enemy:
			events.append(&"turn_ended")
	var on_combat_end := func(_victory: bool) -> void:
		events.append(&"combat_ended")
	EventBus.pending_ability_resolved.connect(on_pending)
	EventBus.turn_ended.connect(on_turn_end)
	EventBus.combat_ended.connect(on_combat_end)
	var state := {"done": false}
	_capture_turn(f.battle, enemy, state)
	assert_eq(f.hero.current_hp, 1)
	assert_eq(f.battle._outcome_deferral_depth, 1)
	f.view.release_requested.emit()
	assert_false(f.battle._battle_over)
	await _until_done(state)
	EventBus.pending_ability_resolved.disconnect(on_pending)
	EventBus.turn_ended.disconnect(on_turn_end)
	EventBus.combat_ended.disconnect(on_combat_end)
	assert_eq(events, [&"pending_resolved", &"turn_ended", &"combat_ended"])
	assert_true(f.battle._battle_over)
	assert_eq(f.battle._outcome_deferral_depth, 0)


func test_scene_generation_change_before_release_prevents_launch_and_damage() -> void:
	var f := _fixture()
	var state := {"done": false, "result": {}}
	_capture(f.battle, f.enemy, state)
	f.battle._lifecycle_generation += 1
	f.view.release_requested.emit()
	await _until_done(state)
	assert_false(state.result.resolved)
	assert_eq(f.battle.launches, 0)
	assert_eq(f.hero.current_hp, 100)
	assert_eq(f.hero.get_active_statuses().size(), 0)


func test_scene_generation_change_during_flight_cancels_projectile_and_damage() -> void:
	var f := _fixture()
	var state := {"done": false, "result": {}}
	_capture(f.battle, f.enemy, state)
	f.view.release_requested.emit()
	assert_eq(f.battle.launches, 1)
	f.battle._lifecycle_generation += 1
	await _until_done(state)
	assert_false(state.result.resolved)
	assert_eq(f.hero.current_hp, 100)
	assert_true(not is_instance_valid(f.battle.projectile) or f.battle.projectile.is_queued_for_deletion())


func test_escaping_during_anticipation_blocks_warning_without_projectile() -> void:
	var f := _fixture()
	var state := {"done": false, "result": {}}
	_capture(f.battle, f.enemy, state)
	f.battle.grid.relocate_unit(f.hero, Vector2i(10, 1))
	f.view.release_requested.emit()
	await _until_done(state)
	assert_true(state.result.blocked)
	assert_true(state.result.consume_activation)
	assert_eq(state.result.reason, &"target_escaped_telegraph")
	assert_eq(f.battle.launches, 0)
	assert_eq(f.hero.current_hp, 100)
	assert_true(f.enemy.pending_ability.is_empty())


func test_escaping_during_flight_is_revalidated_at_impact() -> void:
	var f := _fixture()
	var state := {"done": false, "result": {}}
	_capture(f.battle, f.enemy, state)
	f.view.release_requested.emit()
	f.battle.grid.relocate_unit(f.hero, Vector2i(10, 1))
	await _until_done(state)
	assert_true(state.result.blocked)
	assert_eq(f.hero.current_hp, 100)
	assert_eq(f.hero.get_active_statuses().size(), 0)
	assert_true(f.enemy.pending_ability.is_empty())


func test_pause_freezes_pending_flight_without_wall_clock_catch_up() -> void:
	var f := _fixture()
	var state := {"done": false, "result": {}}
	_capture(f.battle, f.enemy, state)
	f.view.release_requested.emit()
	get_tree().paused = true
	await get_tree().create_timer(0.3, true, false, true).timeout
	assert_eq(f.hero.current_hp, 100)
	assert_false(state.done)
	get_tree().paused = false
	await wait_process_frames(1)
	assert_eq(f.hero.current_hp, 100)
	await _until_done(state)
	assert_true(state.result.resolved)
	assert_eq(f.hero.current_hp, 86)


func test_caster_death_during_flight_prevents_damage_and_status() -> void:
	var f := _fixture()
	var state := {"done": false, "result": {}}
	_capture(f.battle, f.enemy, state)
	f.view.release_requested.emit()
	f.enemy.take_damage(10000)
	await _until_done(state)
	assert_false(state.result.resolved)
	assert_eq(f.hero.current_hp, 100)
	assert_eq(f.hero.get_active_statuses().size(), 0)


func test_pending_replacement_during_flight_does_not_resolve_new_action() -> void:
	var f := _fixture()
	var state := {"done": false, "result": {}}
	_capture(f.battle, f.enemy, state)
	f.view.release_requested.emit()
	var replacement: Dictionary = f.enemy.pending_ability.duplicate()
	replacement.prepared_activation = 999
	f.enemy.pending_ability = replacement
	await _until_done(state)
	assert_false(state.result.resolved)
	assert_eq(f.hero.current_hp, 100)
	assert_eq(f.enemy.pending_ability.prepared_activation, 999)


func _fixture() -> Dictionary:
	var battle := PendingBattle.new()
	add_child_autofree(battle)
	var field := Factory.make_battlefield(12, 3)
	_fixture_grids.append(field.grid)
	battle.grid = field.grid
	battle.pathfinder = field.pathfinder
	battle.terrain_effects = field.terrain
	battle.spell_caster = field.caster
	var enemy := Factory.make_unit("Rejeton", 1)
	var hero := Factory.make_unit("Héros", 0)
	field.grid.place_unit(enemy, Vector2i(1, 1))
	field.grid.place_unit(hero, Vector2i(4, 1))
	battle.units.assign([enemy, hero])
	battle.observed_target = hero
	var view := ReleaseView.new()
	battle.add_child(view)
	battle._unit_views[enemy] = view
	var status := StatusData.new()
	status.status_id = &"pending_test_burn"
	status.damage_per_turn = 4
	status.duration = 2
	var spell := Factory.make_spell({"spell_id": &"pending_test_fournaise", "damage": 14,
		"damage_type": Spell.DamageType.MAGICAL, "minimum_range": 2, "spell_range": 6,
		"delayed_resolution": Spell.DelayedResolution.RANGED_STRIKE,
		"consumes_activation_on_resolution": true, "impact_delay_seconds": 0.15,
		"applied_status": status})
	enemy.pending_ability = {"spell": spell, "target": hero, "cell": hero.grid_pos,
		"prepared_activation": 1}
	return {"battle": battle, "enemy": enemy, "hero": hero, "view": view, "spell": spell}


func _capture(battle: PendingBattle, enemy: Unit, state: Dictionary) -> void:
	state.result = await battle._resolve_pending_ability(enemy)
	state.done = true


func _capture_preparation(runner: EnemyTurnRunner, enemy: Unit, spell: Spell,
		cell: Vector2i, state: Dictionary) -> void:
	await runner._execute_cast(enemy, spell, cell)
	state.done = true


func _capture_turn(battle: PendingBattle, enemy: Unit, state: Dictionary) -> void:
	await battle._on_turn_started(enemy)
	state.done = true


func _until_done(state: Dictionary) -> void:
	var deadline := Time.get_ticks_msec() + 2000
	while not bool(state.done) and Time.get_ticks_msec() < deadline:
		await wait_process_frames(1)
	assert_true(state.done, "Pending presentation must settle within its bounded duration")
