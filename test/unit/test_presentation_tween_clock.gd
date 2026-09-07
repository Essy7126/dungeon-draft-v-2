extends GutTest

const CLOCK := preload("res://characters/presentation_tween_clock.gd")


func test_new_movement_uses_time_since_creation_instead_of_inherited_frame_delta() -> void:
	var fixture := _create_clock(1.0)
	var target: Node2D = fixture.target
	var clock: Node = fixture.clock
	# A movement created late in a busy frame can receive a much larger
	# engine delta than its own age. That must not skip the opening stride.
	clock.call("_process", 4.0)
	_assert_position_matches_age(fixture)
	assert_lt(target.position.x, 10.0, "A new movement must retain its opening pose")
	# Deliberately independent inputs: about 20 ms of real movement time,
	# but only 1 ms supplied by the engine's smoothed frame clock.
	OS.delay_msec(20)
	clock.call("_process", 0.001)
	_assert_position_matches_age(fixture)
	assert_gt(target.position.x, 1.0, "Playback must also advance when engine delta is understated")
	assert_false((fixture.tween as Tween).is_running(), "SceneTree must not advance the Tween a second time")


func test_inherited_pause_discards_paused_time_and_resumes_with_one_completion() -> void:
	var fixture := _create_clock(0.2)
	var owner: Node2D = fixture.owner
	var target: Node2D = fixture.target
	var clock: Node = fixture.clock
	var tween: Tween = fixture.tween
	var events := {"finished": 0}
	tween.finished.connect(func() -> void: events.finished += 1)
	clock.call("_process", 0.016)
	var before_pause := target.position.x
	owner.process_mode = Node.PROCESS_MODE_DISABLED
	assert_false(clock.can_process(), "The movement clock must inherit its owner's pause")
	OS.delay_msec(80)
	assert_eq(target.position.x, before_pause)
	var resumed_at := Time.get_ticks_usec()
	owner.process_mode = Node.PROCESS_MODE_INHERIT
	assert_true(clock.can_process())
	clock.call("_process", 4.0)
	var resumed_age := float(Time.get_ticks_usec() - resumed_at) / 1000000.0
	assert_lte(target.position.x - before_pause, resumed_age * 500.0 * Engine.time_scale + 0.1,
		"Paused wall time and the inherited engine delta must not jump the character forward")
	assert_eq(events.finished, 0)
	OS.delay_msec(20)
	clock.call("_process", 0.001)
	assert_gt(target.position.x, before_pause + 1.0, "Movement resumes after the inherited pause")
	OS.delay_msec(210)
	clock.call("_process", 0.001)
	assert_almost_eq(target.position.x, 100.0, 0.001)
	assert_eq(events.finished, 1)
	# A finished Tween can remain in SceneTree until the next process pass.
	# A second clock callback must be harmless and retire only this helper.
	clock.call("_process", 4.0)
	assert_eq(events.finished, 1)
	await wait_process_frames(2)
	assert_false(is_instance_valid(clock))


func _create_clock(duration: float) -> Dictionary:
	var owner := Node2D.new()
	add_child_autofree(owner)
	var target := Node2D.new()
	owner.add_child(target)
	var tween := owner.create_tween()
	tween.tween_property(target, "position:x", 100.0, duration)
	var started_before := Time.get_ticks_usec()
	CLOCK.drive(owner, tween)
	var started_after := Time.get_ticks_usec()
	var clock := owner.get_node("PresentationTweenClock")
	# Invoke the real callback deterministically; it must ignore its delta
	# argument. Node pause notifications still follow the actual owner tree.
	clock.set_process(false)
	return {"owner": owner, "target": target, "tween": tween, "clock": clock,
		"started_before": started_before, "started_after": started_after}


func _assert_position_matches_age(fixture: Dictionary) -> void:
	var now := Time.get_ticks_usec()
	var minimum_age := float(now - int(fixture.started_after)) / 1000000.0
	var maximum_age := float(now - int(fixture.started_before)) / 1000000.0
	var actual := (fixture.target as Node2D).position.x
	assert_gte(actual, minf(100.0, minimum_age * 100.0 * Engine.time_scale) - 0.1)
	assert_lte(actual, minf(100.0, maximum_age * 100.0 * Engine.time_scale) + 0.1)
