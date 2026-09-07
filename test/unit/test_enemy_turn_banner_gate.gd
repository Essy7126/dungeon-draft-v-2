extends GutTest

const Factory := preload("res://test/support/factory.gd")
const HEAL: Spell = preload("res://data/spells/enemies/philosopher_mending.tres")


class Banner extends Control:
	var close_count := 0

	func hide_immediately() -> void:
		close_count += 1
		hide()


class Hud extends RefCounted:
	var banner: Control

	func get_turn_intro_banner() -> Control:
		return banner


class CastPlanner extends RefCounted:
	var spell: Spell
	var recipient: Unit
	var calls := 0

	func build_action_plan(_enemy: Unit, _units: Array) -> EnemyActionPlan:
		calls += 1
		var plan := EnemyActionPlan.new()
		plan.append_action({"type": "cast", "spell": spell, "cell": recipient.grid_pos})
		return plan


class SpellView extends Node2D:
	var prepared := 0

	func prepare_spell_visual(_cell: Vector2i, _spell: Spell) -> bool:
		prepared += 1
		await get_tree().process_frame
		return true

	func has_optional_visual() -> bool:
		return true

	func wait_for_action_visual_finished() -> void:
		await get_tree().process_frame


class Battle extends Node:
	var _battle_over := false
	var _hud_port: Hud
	var enemy_ai: CastPlanner
	var units: Array[Unit] = []
	var spell_caster: SpellCaster
	var grid: GridData
	var grid_view: Node2D
	var _unit_views := {}
	var deferrals := 0

	func _begin_outcome_deferral() -> void:
		deferrals += 1

	func _finish_outcome_deferral() -> bool:
		deferrals -= 1
		return false


func test_first_real_spell_waits_for_banner_to_close_before_its_gesture_and_heal() -> void:
	var f := _fixture()
	var state := {"done": false}
	_capture_run(f.runner, f.enemy, state)
	await get_tree().create_timer(0.45).timeout
	assert_true(f.banner.is_visible_in_tree())
	assert_eq(f.battle.enemy_ai.calls, 0)
	assert_eq(f.visual.prepared, 0, "The anticipation must also remain visible to the player")
	assert_eq(f.ally.current_hp, 60)
	f.banner.hide_immediately()
	await _until_done(state)
	assert_true(state.done)
	assert_eq(f.battle.enemy_ai.calls, 1)
	assert_eq(f.visual.prepared, 1)
	assert_eq(f.ally.current_hp, 82, "The canonical heal resolves after the overlay is gone")
	assert_eq(f.battle.deferrals, 0)


func test_cancellation_while_banner_is_visible_cannot_spend_ap_or_start_a_spell() -> void:
	var f := _fixture()
	var state := {"done": false, "result": true}
	_capture_gate(f.runner, f.enemy, state)
	await wait_process_frames(2)
	assert_false(state.done)
	f.runner.cancel_pending_actions()
	await wait_process_frames(2)
	assert_true(state.done)
	assert_false(state.result)
	assert_eq(f.enemy.current_ap, 6)
	assert_eq(f.ally.current_hp, 60)
	assert_eq(f.visual.prepared, 0)
	assert_eq(f.battle.enemy_ai.calls, 0)


func test_missing_hidden_or_unattached_banner_adds_no_frame_wait() -> void:
	var f := _fixture()
	var state := {"done": false, "result": false}
	f.battle._hud_port = null
	_capture_gate(f.runner, f.enemy, state)
	assert_true(state.done, "A HUD without this overlay incurs no new wait")
	assert_true(state.result)
	var hud := Hud.new()
	hud.banner = f.banner
	f.battle._hud_port = hud
	f.banner.hide()
	state = {"done": false, "result": false}
	_capture_gate(f.runner, f.enemy, state)
	assert_true(state.done, "A finished overlay incurs no new wait")
	assert_true(state.result)
	var unattached := autofree(Banner.new()) as Banner
	hud.banner = unattached
	state = {"done": false, "result": false}
	_capture_gate(f.runner, f.enemy, state)
	assert_true(state.done)
	assert_true(state.result)


func test_scene_removal_during_banner_wait_cancels_before_gameplay() -> void:
	var f := _fixture()
	var state := {"done": false, "result": true}
	_capture_gate(f.runner, f.enemy, state)
	await wait_process_frames(1)
	remove_child(f.battle)
	await wait_process_frames(2)
	assert_true(state.done)
	assert_false(state.result)
	assert_eq(f.visual.prepared, 0)
	assert_eq(f.battle.enemy_ai.calls, 0)


func test_stuck_banner_is_closed_before_failsafe_allows_actions() -> void:
	var f := _fixture()
	var state := {"done": false, "result": false}
	_capture_gate(f.runner, f.enemy, state, 0.0)
	assert_true(state.done)
	assert_true(state.result)
	assert_false(f.banner.visible)
	assert_eq(f.banner.close_count, 1)


func _fixture() -> Dictionary:
	var field := Factory.make_battlefield(5, 2)
	var enemy := Factory.make_unit("Mage", 1)
	enemy.unit_id = &"philosopher_mage"
	enemy.spells.assign([HEAL])
	var ally := Factory.make_unit("Protege", 1)
	ally.current_hp = 60
	field.grid.place_unit(enemy, Vector2i(1, 0))
	field.grid.place_unit(ally, Vector2i(2, 0))
	var battle := Battle.new()
	add_child_autofree(battle)
	battle.grid = field.grid
	battle.spell_caster = field.caster
	battle.units.assign([enemy, ally])
	battle.grid_view = Node2D.new()
	battle.add_child(battle.grid_view)
	var banner := Banner.new()
	battle.add_child(banner)
	var hud := Hud.new()
	hud.banner = banner
	battle._hud_port = hud
	var planner := CastPlanner.new()
	planner.spell = HEAL
	planner.recipient = ally
	battle.enemy_ai = planner
	var visual := SpellView.new()
	battle.add_child(visual)
	battle._unit_views[enemy] = visual
	var runner := EnemyTurnRunner.new()
	battle.add_child(runner)
	runner.setup(battle)
	return {"battle": battle, "enemy": enemy, "ally": ally,
		"visual": visual, "banner": banner, "runner": runner}


func _capture_run(runner: EnemyTurnRunner, enemy: Unit, state: Dictionary) -> void:
	await runner.run(enemy)
	state.done = true


func _capture_gate(runner: EnemyTurnRunner, enemy: Unit, state: Dictionary, timeout := 4.0) -> void:
	state.result = await runner._wait_for_turn_intro_safe(
		runner._operation_generation, enemy, timeout)
	state.done = true


func _until_done(state: Dictionary) -> void:
	var deadline := Time.get_ticks_msec() + 3000
	while not bool(state.done) and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
