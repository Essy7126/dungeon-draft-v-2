extends GutTest

const Factory := preload("res://test/support/factory.gd")
const UNIT_PATH := "res://data/units/enemies/catabase_shadow_paris.tres"


class PhaseAI:
	extends RefCounted
	var plans_built := 0
	var target: Unit

	func build_action_plan(enemy: Unit, _units: Array) -> EnemyActionPlan:
		plans_built += 1
		var result := EnemyActionPlan.new()
		if enemy.combat_form_id == &"spectral":
			result.append_action({"type": "move", "path": [enemy.grid_pos, Vector2i(2, 2)]})
			result.append_action({"type": "cast", "spell": load("res://data/spells/enemies/paris/spectral_arrow.tres"), "cell": target.grid_pos})
		else:
			result.append_action({"type": "cast", "spell": load("res://data/spells/enemies/paris/infernal_whip.tres"), "cell": target.grid_pos})
		return result


class RunnerBattle:
	extends Node
	var grid: GridData
	var pathfinder: Pathfinder
	var terrain: TerrainEffects
	var units: Array = []
	var enemy_ai := PhaseAI.new()
	var _unit_views := {}
	var _battle_over := false
	var _resolved_walk_paths := {}
	var _hud_port: Node
	var deferrals := 0

	func _begin_outcome_deferral() -> void:
		deferrals += 1

	func _finish_outcome_deferral() -> void:
		deferrals -= 1

	func _next_action_id(_kind: StringName) -> StringName:
		return &"phase_movement_fixture"

	func _animate_move(unit: Unit, path: Array) -> void:
		terrain.begin_unit_resolution(unit, &"movement")
		grid.relocate_unit(unit, path[-1])
		terrain.end_unit_resolution(unit)
		_resolved_walk_paths[unit] = path
		await get_tree().process_frame


class RecordingRunner:
	extends EnemyTurnRunner
	var executed_spells: Array[StringName] = []
	var casts_during_transformation := 0

	func _execute_cast(enemy: Unit, spell: Spell, _cell: Vector2i, _generation := -1) -> void:
		var visual: Variant = _battle._unit_views[enemy].get_optional_visual()
		if visual.is_transformation_pending():
			casts_during_transformation += 1
		executed_spells.append(spell.spell_id)


func after_each() -> void:
	Engine.time_scale = 1


func test_spell_preparation_waits_for_reveal_then_the_real_release_marker() -> void:
	var fixture := _fixture()
	var unit: Unit = fixture.unit
	var visual: ParisIsoUnitView = fixture.visual
	unit.take_damage(97)
	var state := {"finished": false, "result": false}
	_prepare(fixture.wrapper, state)
	await wait_process_frames(2)
	assert_false(state.finished)
	assert_false(visual.get_visual_runtime_state().action_pending)
	visual.advance_simulation(0.9)
	await wait_process_frames(2)
	assert_true(visual.get_visual_runtime_state().action_pending)
	assert_false(state.finished, "Completion of the reveal cannot release the whip")
	visual.advance_simulation(0.34)
	await wait_process_frames(2)
	assert_true(state.finished)
	assert_true(state.result)
	assert_true(visual.get_visual_runtime_state().release_emitted)


func test_freeing_unit_view_drains_a_pending_phase_wait_without_a_cast() -> void:
	var fixture := _fixture()
	(fixture.unit as Unit).take_damage(97)
	var state := {"finished": false, "result": true}
	_prepare(fixture.wrapper, state)
	await wait_process_frames(2)
	fixture.wrapper.queue_free()
	await wait_process_frames(3)
	assert_true(state.finished)
	assert_false(state.result)


func test_phase_watchdog_respects_zero_time_scale() -> void:
	var fixture := _fixture()
	(fixture.unit as Unit).take_damage(97)
	Engine.time_scale = 0
	var state := {"finished": false, "result": false}
	_wait_phase(fixture.wrapper, state, 0.001)
	await wait_process_frames(4)
	assert_false(state.finished)
	assert_true((fixture.visual as ParisIsoUnitView).is_transformation_pending())
	(fixture.visual as ParisIsoUnitView).advance_simulation(0.9)
	await wait_process_frames(2)
	assert_true(state.finished)
	assert_true(state.result)


func test_runner_replans_only_changed_form_after_real_fire_entry_and_keeps_action_bound() -> void:
	var fixture := _fixture()
	var unit: Unit = fixture.unit
	var body: ParisIsoUnitView = fixture.visual
	unit.take_damage(90)
	assert_eq(unit.current_hp, 30)
	var field := Factory.make_battlefield(8, 5)
	var target := Factory.make_unit("Cible", 0)
	field.grid.place_unit(unit, Vector2i(1, 2))
	field.grid.place_unit(target, Vector2i(4, 2))
	field.terrain.place_effect(Vector2i(2, 2), load("res://data/terrain/paris/fire.tres") as TerrainEffectData)
	var battle := RunnerBattle.new()
	add_child_autofree(battle)
	battle.grid = field.grid
	battle.pathfinder = field.pathfinder
	battle.terrain = field.terrain
	battle.units.assign([unit, target])
	battle.enemy_ai.target = target
	battle._unit_views[unit] = fixture.wrapper
	var runner := RecordingRunner.new()
	battle.add_child(runner)
	runner.setup(battle)
	# The runner waits on the same real-time view clock used by a live battle.
	body.set_process(true)
	await runner.run(unit)
	assert_eq(unit.combat_form_id, &"infernal")
	assert_eq(unit.current_hp, 22)
	assert_eq(unit.current_mp, 2)
	assert_eq(battle.enemy_ai.plans_built, 2)
	assert_eq(runner.executed_spells, [&"paris_infernal_whip"])
	assert_eq(runner.casts_during_transformation, 0)
	assert_eq(runner.last_action_count, 2)
	assert_lte(runner.last_action_count, EnemyActionPlan.MAX_STEPS)
	assert_eq(battle.deferrals, 0)


func _prepare(wrapper: Node, state: Dictionary) -> void:
	state.result = await wrapper.prepare_spell_visual(Vector2i(3, 2), load("res://data/spells/enemies/paris/infernal_whip.tres") as Spell)
	state.finished = true


func _wait_phase(wrapper: Node, state: Dictionary, timeout: float) -> void:
	state.result = await wrapper.wait_for_transformation_visual_finished(timeout)
	state.finished = true


func _fixture() -> Dictionary:
	var unit := Unit.from_data(load(UNIT_PATH) as UnitData)
	var wrapper := (load("res://battle/unit_view.gd") as Script).new() as Node2D
	add_child_autofree(wrapper)
	wrapper.setup(unit, false)
	var visual := wrapper.get_optional_visual() as ParisIsoUnitView
	visual.set_process(false)
	return {"unit": unit, "wrapper": wrapper, "visual": visual}
