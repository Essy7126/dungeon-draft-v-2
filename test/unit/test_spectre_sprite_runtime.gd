extends GutTest

const SCENE_PATH := "res://characters/enemies/spectre_greatsword/SpectreGreatswordIsoUnitView.tscn"
const DIRECTIONS := {"N": Vector2i.UP, "E": Vector2i.RIGHT, "S": Vector2i.DOWN, "W": Vector2i.LEFT}


func test_canonical_view_uses_only_one_sprite_with_one_fixed_ground_anchor() -> void:
	var view := await _create_view()
	assert_eq(view.find_children("*", "AnimatedSprite2D", true, false).size(), 1)
	assert_eq(view.find_children("*", "SubViewport", true, false).size(), 0)
	assert_eq(view.find_children("*", "Node3D", true, false).size(), 0)
	var sprite := _sprite(view)
	var profile := view.get("sprite_profile") as Resource
	assert_eq(profile.get("frame_canvas_size"), Vector2i(512, 384))
	assert_eq(profile.get("foot_anchor"), Vector2(256, 320))
	assert_almost_eq(_ground_anchor(view).length(), 0.0, 0.001)
	assert_false(sprite.flip_h)
	assert_false(sprite.flip_v)


func test_idle_remains_still_for_repeated_requests_and_large_elapsed_time() -> void:
	var view := await _create_view()
	var sprite := _sprite(view)
	var owner := view.get_parent() as Node2D
	var original_owner := owner.transform
	for direction: String in DIRECTIONS:
		view.set_facing(DIRECTIONS[direction])
		assert_true(view.play_idle())
		var original_sprite := sprite.transform
		for _sample in 20:
			view.advance_simulation(0.5)
			assert_true(view.play_idle())
		assert_eq(sprite.animation, StringName("idle_%s" % direction))
		assert_eq(sprite.frame, 0)
		assert_false(sprite.is_playing())
		assert_eq(sprite.transform, original_sprite)
		assert_eq(owner.transform, original_owner)
		assert_almost_eq(_ground_anchor(view).length(), 0.0, 0.001)


func test_levitation_phase_continues_between_cells_and_direction_changes() -> void:
	var view := await _create_view()
	var sprite := _sprite(view)
	var original_owner := (view.get_parent() as Node2D).transform
	view.begin_movement_feedback(Vector2i.ZERO, Vector2i.RIGHT)
	view.advance_simulation(0.27)
	var old_frame := sprite.frame
	var old_progress := sprite.frame_progress
	assert_gt(old_frame, 0)
	view.begin_movement_feedback(Vector2i.RIGHT, Vector2i(2, 0))
	assert_eq(sprite.frame, old_frame, "A cell boundary must not restart the cloth cycle")
	assert_almost_eq(sprite.frame_progress, old_progress, 0.001)
	view.set_facing(Vector2i.DOWN)
	assert_eq(sprite.animation, &"walk_S")
	assert_eq(sprite.frame, old_frame, "A turn preserves the levitation phase")
	assert_almost_eq(sprite.frame_progress, old_progress, 0.001)
	view.update_movement_stride(2, 0.4)
	assert_eq(sprite.frame, old_frame, "The walking-foot stride callback does not drive levitation")
	view.advance_simulation(0.18)
	assert_ne(sprite.frame, old_frame)
	assert_false(sprite.is_playing(), "The manual clock is the only playback driver")
	assert_eq((view.get_parent() as Node2D).transform, original_owner)
	assert_almost_eq(_ground_anchor(view).length(), 0.0, 0.001)
	view.cancel_movement_feedback()
	view.update_movement_stride(2, 1.0)
	view.advance_simulation(1.0)
	assert_eq(sprite.animation, &"idle_S")
	assert_eq(sprite.frame, 0)


func test_attack_release_and_finish_are_once_in_all_four_directions() -> void:
	var view := await _create_view()
	var events := _watch_actions(view)
	for direction: String in DIRECTIONS:
		var before_release: int = events.releases
		var before_finish: int = events.finishes
		view.set_facing(DIRECTIONS[direction])
		assert_true(view.play_basic_attack())
		assert_false(view.play_cast(), "Concurrent actions cannot consume a second release")
		assert_false(view.play_idle())
		view.advance_simulation(0.299)
		assert_eq(events.releases, before_release)
		view.advance_simulation(0.002)
		assert_eq(events.releases, before_release + 1)
		assert_eq(events.release_frame, 3)
		view.advance_simulation(0.498)
		assert_eq(events.finishes, before_finish)
		view.advance_simulation(0.002)
		assert_eq(events.finishes, before_finish + 1)
		assert_eq(_sprite(view).animation, StringName("idle_%s" % direction))
		assert_eq(_sprite(view).frame, 0)
		view.advance_simulation(10.0)
		assert_eq(events.releases, before_release + 1)
		assert_eq(events.finishes, before_finish + 1)


func test_large_delta_still_emits_one_release_before_one_finish() -> void:
	var view := await _create_view()
	var events := _watch_actions(view)
	assert_true(view.play_cast())
	view.advance_simulation(4.0)
	assert_eq(events.releases, 1)
	assert_eq(events.finishes, 1)
	assert_eq(events.order, ["release", "finish"])


func test_cancel_before_release_cannot_leak_into_a_new_attack() -> void:
	var view := await _create_view()
	var events := _watch_actions(view)
	assert_true(view.play_cast())
	view.advance_simulation(0.15)
	view.cancel_pending_visual_actions()
	view.advance_simulation(2.0)
	assert_eq(events.releases, 0)
	assert_eq(events.finishes, 0)
	assert_true(view.play_cast())
	view.advance_simulation(0.81)
	assert_eq(events.releases, 1)
	assert_eq(events.finishes, 1)


func test_cancel_from_release_callback_prevents_stale_completion() -> void:
	var view := await _create_view()
	var events := _watch_actions(view)
	view.cast_release_reached.connect(func() -> void:
		view.cancel_pending_visual_actions()
	, CONNECT_ONE_SHOT)
	assert_true(view.play_cast())
	view.advance_simulation(2.0)
	assert_eq(events.releases, 1)
	assert_eq(events.finishes, 0)
	assert_true(view.play_cast())
	view.advance_simulation(0.81)
	assert_eq(events.releases, 2)
	assert_eq(events.finishes, 1)


func test_facing_during_attack_is_deferred_until_stable_rest() -> void:
	var view := await _create_view()
	view.set_facing(Vector2i.RIGHT)
	assert_true(view.play_cast())
	view.advance_simulation(0.2)
	view.set_facing(Vector2i.LEFT)
	assert_eq(_sprite(view).animation, &"attack_E")
	view.advance_simulation(0.61)
	assert_eq(_sprite(view).animation, &"idle_W")
	assert_false(_sprite(view).flip_h)


func test_death_cancels_attack_and_fades_once_without_root_motion() -> void:
	var view := await _create_view()
	var unit := Unit.from_data(load("res://data/units/enemies/spectre_greatsword.tres") as UnitData)
	view.bind_unit(unit)
	var events := _watch_actions(view)
	var death := {"count": 0}
	view.death_animation_finished.connect(func() -> void: death.count += 1)
	var original_transform: Transform2D = view.transform
	assert_true(view.play_cast())
	unit.died.emit(unit)
	unit.died.emit(unit)
	view.advance_simulation(0.4)
	assert_eq(events.releases, 0)
	assert_eq(events.finishes, 0)
	assert_eq(death.count, 1)
	assert_almost_eq(view.modulate.a, 0.0, 0.001)
	assert_eq(view.transform, original_transform)
	assert_false(view.play_cast())
	view.advance_simulation(4.0)
	assert_eq(death.count, 1)


func test_wall_clock_respects_tree_pause_without_catch_up_on_resume() -> void:
	var view := await _create_view()
	var events := _watch_actions(view)
	view.set_process(true)
	assert_true(view.play_cast())
	get_tree().paused = true
	await get_tree().create_timer(0.42, true, false, true).timeout
	var paused_frame := _sprite(view).frame
	var paused_releases: int = events.releases
	get_tree().paused = false
	assert_eq(paused_frame, 0)
	assert_eq(paused_releases, 0)
	await wait_process_frames(1)
	assert_eq(events.releases, 0, "Paused wall time must not be consumed on the next frame")
	var deadline := Time.get_ticks_msec() + 1800
	while int(events.finishes) < 1 and Time.get_ticks_msec() < deadline:
		await wait_process_frames(1)
	assert_eq(events.releases, 1)
	assert_eq(events.finishes, 1)


func _create_view() -> Node2D:
	var parent := Node2D.new()
	parent.position = Vector2(161, 215)
	add_child_autofree(parent)
	var scene := load(SCENE_PATH) as PackedScene
	var view := scene.instantiate() as Node2D
	parent.add_child(view)
	await wait_process_frames(2)
	view.set_process(false)
	return view


func _sprite(view: Node) -> AnimatedSprite2D:
	return view.get("animated_sprite") as AnimatedSprite2D


func _ground_anchor(view: Node) -> Vector2:
	var sprite := _sprite(view)
	var profile := view.get("sprite_profile") as Resource
	var point := sprite.offset + Vector2(profile.get("foot_anchor"))
	if sprite.centered:
		point -= Vector2(profile.get("frame_canvas_size")) * 0.5
	return sprite.transform * point


func _watch_actions(view: Node) -> Dictionary:
	var events := {"releases": 0, "finishes": 0, "release_frame": -1, "order": []}
	view.cast_release_reached.connect(func() -> void:
		events.releases += 1
		events.release_frame = _sprite(view).frame
		events.order.append("release")
	)
	view.animation_finished.connect(func(_clip: StringName) -> void:
		events.finishes += 1
		events.order.append("finish")
	)
	return events
