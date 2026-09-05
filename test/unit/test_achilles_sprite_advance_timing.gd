extends GutTest

const UNIT_VIEW := preload("res://battle/unit_view.tscn")
const ACHILLES_DATA := preload("res://data/units/allies/achilles.tres")
const ADVANCE := preload("res://data/spells/achilles/advance.tres")


class AdvanceBattleFixture:
	extends "res://battle/battle.gd"

	func _ready() -> void:
		pass

	func grid_cell_to_parent_local(cell: Vector2i, _parent: Node2D) -> Vector2:
		return Vector2(float(cell.x - cell.y) * 64.0, float(cell.x + cell.y) * 32.0)


func test_long_advance_keeps_running_until_real_controller_arrival() -> void:
	# Three cells already exceed the former 0.4 s visual action budget after
	# its release marker. Four cells exercise Battle's maximum travel time.
	for distance: int in [3, 4]:
		await _assert_advance_arrival(distance)


func _assert_advance_arrival(distance: int) -> void:
	var battle := AdvanceBattleFixture.new()
	add_child_autofree(battle)
	var unit := Unit.from_data(ACHILLES_DATA)
	unit.grid_pos = Vector2i.ZERO
	var view = UNIT_VIEW.instantiate()
	battle.add_child(view)
	view.setup(unit)
	battle._unit_views[unit] = view
	await wait_process_frames(4)
	var adapter := view.get_optional_visual() as AchillesIsoUnitView
	assert_not_null(adapter)
	if adapter == null:
		return
	var sprite := adapter.sprite_backend.animated_sprite
	var state := {"releases": 0, "finishes": 0, "arrived": false, "release_at": 0}
	adapter.cast_release_reached.connect(func() -> void:
		state.releases += 1
		state.release_at = Time.get_ticks_msec()
	)
	adapter.animation_finished.connect(func(_clip: StringName) -> void:
		state.finishes += 1
	)
	var destination := Vector2i(distance, 0)
	# Use UnitView's real release wait, then the same logical-position-first
	# ordering used by the spell system. Battle owns the actual visual tween.
	assert_true(await view.prepare_spell_visual(destination, ADVANCE))
	assert_eq(state.releases, 1)
	assert_eq(unit.grid_pos, Vector2i.ZERO, "The sprite action must not move gameplay")
	unit.grid_pos = destination
	battle._start_spell_movement_feedback(unit, view, Vector2i.ZERO, destination)
	var movement_tween: Tween = battle._spell_movement_feedback_tween
	assert_not_null(movement_tween)
	if movement_tween == null:
		return
	movement_tween.finished.connect(func() -> void: state.arrived = true, CONNECT_ONE_SHOT)
	var late_samples := 0
	var deadline := Time.get_ticks_msec() + 1800
	var expected_speed := adapter.sprite_profile.walk_segment_duration_seconds \
		/ adapter.sprite_profile.run_segment_duration_seconds
	while not bool(state.arrived) and Time.get_ticks_msec() < deadline:
		await wait_process_frames(1)
		if bool(state.arrived) or Time.get_ticks_msec() - int(state.release_at) < 315:
			continue
		late_samples += 1
		assert_eq(sprite.animation, &"walk_E", "Long advance must not drop to idle in flight")
		assert_true(sprite.is_playing(), "Advance keeps its running clock until arrival")
		assert_true(adapter._action_pending, "Ordinary movement must not replace the active advance")
		assert_eq(state.finishes, 0, "The clip budget must not finish ahead of the movement tween")
		assert_almost_eq(sprite.speed_scale, expected_speed, 0.0001)
	assert_true(bool(state.arrived), "Battle must finish the real advance tween")
	assert_gt(late_samples, 0, "The test must observe travel beyond the old visual budget")
	assert_eq(unit.grid_pos, destination)
	assert_almost_eq(view.position, battle.grid_cell_to_parent_local(destination, battle), Vector2(0.001, 0.001))
	assert_false(adapter._action_pending)
	assert_false(view._optional_visual_action_pending)
	assert_eq(sprite.animation, &"idle_E")
	assert_eq(sprite.frame, 0)
	assert_false(sprite.is_playing())
	# Arrival cancels the remaining fallback budget. It must neither emit a
	# stale completion nor let parent-motion tracking restart the walk clip.
	await wait_seconds(0.35)
	assert_eq(sprite.animation, &"idle_E")
	assert_eq(sprite.frame, 0)
	assert_false(sprite.is_playing())
	assert_eq(state.releases, 1)
	assert_eq(state.finishes, 0)
