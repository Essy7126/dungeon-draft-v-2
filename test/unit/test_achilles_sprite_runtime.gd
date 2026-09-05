extends GutTest

const ADAPTER := preload("res://characters/achilles/AchillesIsoUnitView.tscn")
const SPRITE_PROFILE := "res://data/visuals/achilles/achilles_cour_des_sources_sprite_profile_v1.tres"
const DIRECTIONS := {"N": Vector2i.UP, "E": Vector2i.RIGHT, "S": Vector2i.DOWN, "W": Vector2i.LEFT}


func test_canonical_achilles_instantiates_one_sprite_and_no_3d_nodes() -> void:
	var data := load("res://data/units/allies/achilles.tres") as UnitData
	assert_not_null(data)
	var view := data.visual_scene.instantiate() as Node2D
	add_child_autofree(view)
	await wait_process_frames(4)
	assert_eq(str(view.get("rendering_backend")), "SPRITE_2D")
	_assert_sprite_only(view)
	var state: Dictionary = view.get_visual_runtime_state()
	assert_eq(state.get("ACHILLES_VISUAL_BACKEND_ACTIVE"), "SPRITE_2D")
	assert_false(bool(state.get("ACHILLES_VISUAL_FALLBACK_ACTIVE", true)))
	assert_eq(str(state.get("ACHILLES_SKELETON_PATH", "")), "")
	assert_eq(str(state.get("ACHILLES_SUBVIEWPORT_PATH", "")), "")


func test_cardinal_idle_and_walk_keep_anchor_and_gameplay_transform() -> void:
	var view := await _create_sprite_view()
	var sprite := _sprite(view)
	var parent := view.get_parent() as Node2D
	var original := parent.transform
	var anchored := sprite.position + sprite.offset * sprite.scale
	for direction: String in DIRECTIONS:
		view.set_facing(DIRECTIONS[direction])
		assert_true(view.play_idle())
		assert_eq(sprite.animation, StringName("idle_%s" % direction))
		view.begin_movement_feedback(Vector2i.ZERO, DIRECTIONS[direction])
		assert_eq(sprite.animation, StringName("walk_%s" % direction))
		assert_false(sprite.flip_h, "Handedness must not be changed by mirroring")
		assert_false(sprite.flip_v)
		assert_eq(parent.transform, original)
		assert_eq(sprite.position + sprite.offset * sprite.scale, anchored)
		view.cancel_movement_feedback()
		assert_eq(sprite.animation, StringName("idle_%s" % direction))
	var profile: Resource = view.get("sprite_profile")
	var anchor: Vector2 = profile.get("foot_anchor")
	var source_origin := sprite.position + sprite.offset * sprite.scale
	if sprite.centered:
		source_origin -= Vector2(profile.get("frame_canvas_size")) * 0.5 * sprite.scale
	assert_almost_eq((source_origin + anchor * sprite.scale).x, 0.0, 0.01)
	assert_almost_eq((source_origin + anchor * sprite.scale).y, 0.0, 0.01)


func test_repeated_idle_requests_keep_pose_zero_and_feet_still_over_time() -> void:
	var view := await _create_sprite_view()
	var sprite := _sprite(view)
	var original_parent := (view.get_parent() as Node2D).transform
	for direction: String in DIRECTIONS:
		view.set_facing(DIRECTIONS[direction])
		assert_true(view.play_idle())
		var original_transform := sprite.transform
		var original_foot := _source_foot_in_backend(view)
		var pose_changes := 0
		var playing_samples := 0
		var transform_changes := 0
		var maximum_foot_drift := 0.0
		var samples := 0
		var deadline := Time.get_ticks_msec() + 550
		while Time.get_ticks_msec() < deadline:
			await wait_process_frames(1)
			pose_changes += int(sprite.frame != 0)
			playing_samples += int(sprite.is_playing())
			transform_changes += int(sprite.transform != original_transform)
			maximum_foot_drift = maxf(maximum_foot_drift, original_foot.distance_to(_source_foot_in_backend(view)))
			samples += 1
			view.play_idle()
		assert_gt(samples, 0)
		assert_eq(pose_changes, 0, "Idle may not alternate authored drawings: %s" % direction)
		assert_eq(playing_samples, 0, "Idle holds frame zero instead of a cycling flipbook")
		assert_eq(transform_changes, 0, "Rest must not bob or rescale the character")
		assert_almost_eq(maximum_foot_drift, 0.0, 0.001)
		assert_eq((view.get_parent() as Node2D).transform, original_parent)
		assert_eq(sprite.frame, 0)


func test_walk_cadence_survives_repeat_requests_and_settles_without_root_motion() -> void:
	var view := await _create_sprite_view()
	var sprite := _sprite(view)
	var backend: Node = view.get("sprite_backend")
	view.set_facing(Vector2i.DOWN)
	var profile: Resource = view.get("sprite_profile")
	var parent := view.get_parent() as Node2D
	var original_transform := parent.transform
	var original_foot := _source_foot_in_backend(view)
	for running: bool in [false, true]:
		assert_true(backend.play_move("S", running))
		var expected_speed := float(profile.get("walk_segment_duration_seconds")) \
			/ float(profile.get("run_segment_duration_seconds")) if running else 1.0
		assert_almost_eq(sprite.speed_scale, expected_speed, 0.0001)
		assert_eq(sprite.animation, &"walk_S")
		var frame_count := sprite.sprite_frames.get_frame_count(sprite.animation)
		var fps := sprite.sprite_frames.get_animation_speed(sprite.animation)
		var previous_phase := float(sprite.frame) + sprite.frame_progress
		var advanced_frames := 0.0
		var repeated_request_resets := 0
		var start := Time.get_ticks_usec()
		while Time.get_ticks_usec() - start < 300000:
			await wait_process_frames(1)
			var phase := float(sprite.frame) + sprite.frame_progress
			advanced_frames += fposmod(phase - previous_phase, float(frame_count))
			previous_phase = phase
			backend.play_move("S", running)
			if not is_equal_approx(float(sprite.frame) + sprite.frame_progress, phase):
				repeated_request_resets += 1
		var elapsed := float(Time.get_ticks_usec() - start) / 1000000.0
		assert_eq(repeated_request_resets, 0, "Repeated movement feedback may not reset the walk cycle")
		assert_almost_eq(advanced_frames, elapsed * fps * expected_speed, 1.1,
			"Walk playback must follow the authored FPS and movement speed")
		assert_gt(advanced_frames, 1.0)
		assert_eq(parent.transform, original_transform)
		assert_almost_eq(original_foot.distance_to(_source_foot_in_backend(view)), 0.0, 0.001)
		view.cancel_movement_feedback()
		await wait_process_frames(2)
		assert_eq(sprite.animation, &"idle_S")
		assert_eq(sprite.frame, 0)
		assert_false(sprite.is_playing())
		assert_eq(parent.transform, original_transform)
		assert_almost_eq(original_foot.distance_to(_source_foot_in_backend(view)), 0.0, 0.001)

func test_attack_release_and_completion_are_once_in_every_direction() -> void:
	var view := await _create_sprite_view()
	var counts := _watch_action(view)
	for direction: String in DIRECTIONS:
		var before: int = counts.releases
		var finished_before: int = counts.finishes
		view.set_facing(DIRECTIONS[direction])
		assert_true(view.play_spell_action())
		assert_false(view.play_spell_action(), "Concurrent actions must be rejected")
		assert_false(view.play_idle(), "Idle must not interrupt an action")
		assert_eq(_sprite(view).animation, StringName("attack_%s" % direction))
		await _wait_until_finished(counts, finished_before + 1)
		assert_eq(counts.releases, before + 1)
		assert_eq(counts.finishes, finished_before + 1)
		assert_eq(_sprite(view).animation, StringName("idle_%s" % direction))
	await wait_seconds(0.15)
	assert_eq(counts.releases, 4)
	assert_eq(counts.finishes, 4)


func test_cancellation_before_release_cannot_leak_events_into_next_cast() -> void:
	var view := await _create_sprite_view()
	var counts := _watch_action(view)
	assert_true(view.play_basic_attack())
	view.cancel_pending_visual_actions()
	await wait_seconds(1.0)
	assert_eq(counts.releases, 0)
	assert_eq(counts.finishes, 0)
	assert_true(view.play_basic_attack())
	await _wait_until_finished(counts, 1)
	assert_eq(counts.releases, 1)
	assert_eq(counts.finishes, 1)


func test_cancellation_inside_release_callback_prevents_completion() -> void:
	var view := await _create_sprite_view()
	var counts := _watch_action(view)
	view.cast_release_reached.connect(func() -> void:
		view.cancel_pending_visual_actions()
	, CONNECT_ONE_SHOT)
	assert_true(view.play_cast())
	await wait_seconds(1.0)
	assert_eq(counts.releases, 1)
	assert_eq(counts.finishes, 0)
	assert_true(String(_sprite(view).animation).begins_with("idle_"))
	assert_true(view.play_cast())
	await _wait_until_finished(counts, 1)
	assert_eq(counts.releases, 2)
	assert_eq(counts.finishes, 1)


func test_facing_change_during_attack_preserves_action_then_selects_new_idle() -> void:
	var view := await _create_sprite_view()
	var counts := _watch_action(view)
	view.set_facing(Vector2i.RIGHT)
	assert_true(view.play_cast())
	await wait_process_frames(3)
	view.set_facing(Vector2i.LEFT)
	await _wait_until_finished(counts, 1)
	assert_eq(counts.releases, 1)
	assert_eq(counts.finishes, 1)
	assert_eq(_sprite(view).animation, &"idle_W")
	assert_false(_sprite(view).flip_h)


func test_guard_advance_and_sweep_reuse_three_clips_without_moving_gameplay() -> void:
	var view := await _create_sprite_view()
	var counts := _watch_action(view)
	var parent := view.get_parent() as Node2D
	var original := parent.transform
	var cases := {"guard": "idle", "advance": "walk", "sweep": "attack"}
	for spell_name: String in cases:
		var spell := load("res://data/spells/achilles/%s.tres" % spell_name) as Spell
		assert_not_null(spell)
		var finishes_before: int = counts.finishes
		var releases_before: int = counts.releases
		assert_true(view.play_spell_action(spell))
		assert_true(String(_sprite(view).animation).begins_with(cases[spell_name] + "_"))
		await _wait_until_finished(counts, finishes_before + 1)
		assert_eq(counts.releases, releases_before + 1)
		assert_eq(parent.transform, original, "Presentation may not move gameplay for %s" % spell_name)
		assert_eq(_sprite(view).position, Vector2.ZERO, "Reaction offset must settle")

func test_death_cancels_cast_completes_once_and_cannot_restart_action() -> void:
	var view := await _create_sprite_view()
	var unit := Unit.new("Achille sprite test")
	view.bind_unit(unit)
	var counts := _watch_action(view)
	var death := {"count": 0}
	view.death_animation_finished.connect(func() -> void: death.count += 1)
	assert_true(view.play_cast())
	unit.died.emit(unit)
	unit.died.emit(unit)
	await wait_seconds(0.6)
	assert_eq(counts.releases, 0)
	assert_eq(counts.finishes, 0)
	assert_eq(death.count, 1)
	assert_almost_eq(view.modulate.a, 0.0, 0.001)
	assert_false(view.play_cast())
	unit.died.emit(unit)
	await wait_seconds(0.4)
	assert_eq(death.count, 1)


func _create_sprite_view() -> Node2D:
	var parent := Node2D.new()
	parent.position = Vector2(151.0, 209.0)
	add_child_autofree(parent)
	var view := ADAPTER.instantiate() as Node2D
	view.set("rendering_backend", &"SPRITE_2D")
	view.set("visual_profile", null)
	view.set("sprite_profile", load(SPRITE_PROFILE))
	parent.add_child(view)
	await wait_process_frames(4)
	_assert_sprite_only(view)
	return view


func _assert_sprite_only(view: Node) -> void:
	assert_eq(view.find_children("*", "AnimatedSprite2D", true, false).size(), 1)
	assert_eq(view.find_children("*", "SubViewport", true, false).size(), 0)
	assert_eq(view.find_children("*", "Node3D", true, false).size(), 0)
	assert_not_null(view.get("sprite_backend"))
	assert_null(view.get("viewport_backend"))
	assert_null(view.get("fallback_backend"))


func _sprite(view: Node) -> AnimatedSprite2D:
	return view.get("sprite_backend").get("animated_sprite") as AnimatedSprite2D


func _source_foot_in_backend(view: Node) -> Vector2:
	var sprite := _sprite(view)
	var profile: Resource = view.get("sprite_profile")
	var local_foot: Vector2 = sprite.offset + Vector2(profile.get("foot_anchor"))
	if sprite.centered:
		local_foot -= Vector2(profile.get("frame_canvas_size")) * 0.5
	return sprite.transform * local_foot

func _watch_action(view: Node) -> Dictionary:
	var counts := {"releases": 0, "finishes": 0}
	view.cast_release_reached.connect(func() -> void: counts.releases += 1)
	view.animation_finished.connect(func(_clip: StringName) -> void: counts.finishes += 1)
	return counts


func _wait_until_finished(counts: Dictionary, expected: int) -> void:
	var deadline := Time.get_ticks_msec() + 2500
	while int(counts.finishes) < expected and Time.get_ticks_msec() < deadline:
		await wait_process_frames(1)
	assert_eq(counts.finishes, expected, "The authored attack must finish within 2.5 seconds")




