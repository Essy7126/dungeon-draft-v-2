extends GutTest
const Backend := preload("res://characters/achilles/2d/passe_rive_s19_backend.gd")
const PROFILE := preload("res://data/visuals/achilles/passe_rive_autosprite_profile_v1.tres")
const FACINGS := ["E", "SE", "S", "SW", "W", "NW", "N", "NE"]


func make_backend() -> Node2D:
	var backend := Backend.new()
	add_child_autofree(backend)
	assert_true(backend.configure(PROFILE))
	backend.set_backend_active(true)
	backend.set_cards_mode(true)
	backend.set_process(false)
	return backend


func test_every_facing_releases_on_the_same_authored_opening() -> void:
	var backend := make_backend()
	var releases: Array = []
	backend.action_release_reached.connect(
		func():
			releases.append(backend.get_runtime_state()),
	)
	for facing in FACINGS:
		for step in [.24, 2.0]:
			releases.clear()
			backend.play_idle(facing)
			assert_true(backend.play_action(facing, &"cast", { "spell_id": "cc2_n02" }))
			backend.advance_simulation(step)
			assert_eq(releases.size(), 1)
			var state: Dictionary = releases[0]
			assert_eq(state.animation, Backend.GuardBody.CLIP)
			assert_eq(state.frame, 5)
			assert_eq(state.authored_direction, facing)
			assert_eq(state.gesture_binding.status, "assigned")
			assert_false(state.mirrored)
			assert_almost_eq(float(state.release_seconds), .24, .00001)
			assert_almost_eq(float(state.painted_weight), 1.0, .00001)
			backend.advance_simulation(2.0)
			assert_eq(releases.size(), 1)
			assert_eq(backend.get_runtime_state().animation, "idle_" + facing)
			assert_false(backend.guard.visible)
			assert_eq(backend.animated_sprite.self_modulate, Color.WHITE)


func test_all_three_guard_uses_share_timing_and_authored_angles() -> void:
	var backend := make_backend()
	for id in ["n02", "g05", "fallback_guard"]:
		for facing in FACINGS:
			backend.play_idle(facing)
			backend.play_action(facing, &"cast", { "spell_id": "cc2_" + id })
			backend.advance_simulation(.239)
			assert_false(backend.get_runtime_state().release_emitted)
			backend.advance_simulation(.001)
			var state: Dictionary = backend.get_runtime_state()
			assert_true(state.release_emitted)
			assert_eq(state.authored_direction, facing)
			assert_eq(state.animation, Backend.GuardBody.CLIP)
			assert_eq(state.frame, 5)
			var body: Sprite2D = backend.guard
			var scale: Vector2 = body.scale
			var time := 0.0
			for ms in body.data.duration_ms:
				backend._show_guard(time + .001)
				var pose: Dictionary = body.data.frames[body.source_frame]
				var support := Vector2(body.data.support[0], body.data.support[1]) * PROFILE.display_scale
				assert_eq(body.scale, scale)
				assert_almost_eq(
					body.position + Vector2(pose.pivot[0], pose.pivot[1]) * scale,
					support,
					Vector2(.001, .001),
				)
				assert_true(Rect2(Vector2.ZERO, body.texture.get_size()).encloses(body.region_rect))
				assert_almost_eq(
					backend.get_vfx_origin(),
					body.position + Vector2(pose.hand[0], pose.hand[1]) * scale,
					Vector2(.001, .001),
				)
				time += float(ms) / 1000.0
			backend.cancel_action()


func test_cancel_death_and_mode_switch_clear_all_directions_without_late_release() -> void:
	for facing in FACINGS:
		var backend := make_backend()
		watch_signals(backend)
		for exit_mode in ["cancel", "mode", "death"]:
			backend.set_cards_mode(true)
			backend.play_idle(facing)
			assert_true(backend.play_action(facing, &"cast", { "spell_id": "cc2_n02" }))
			backend.advance_simulation(.12)
			assert_true(backend.guard.visible)
			if exit_mode == "death":
				backend.play_death(facing)
			elif exit_mode == "mode":
				backend.set_cards_mode(false)
			else:
				backend.cancel_action()
				backend.play_idle(facing)
			backend.advance_simulation(1.0)
			assert_false(backend.guard.visible)
			assert_true(backend.animated_sprite.visible)
			assert_eq(backend.animated_sprite.self_modulate, Color.WHITE)
		assert_signal_not_emitted(backend, "action_release_reached")


func test_arc_requires_confirmation_and_keeps_world_scale_in_every_view() -> void:
	var backend := make_backend()
	backend.scale = Vector2.ONE * 1.35
	for facing in FACINGS:
		backend.play_idle(facing)
		backend.play_action(facing, &"cast", { "spell_id": "cc2_n02" })
		backend.confirm_guard_ward()
		assert_false(backend.guard.ward_confirmed)
		backend.advance_simulation(.24)
		assert_false(backend.guard.ward.visible)
		backend.confirm_guard_ward()
		var body: Sprite2D = backend.guard
		var arc: Node2D = body.ward
		assert_true(arc.visible)
		var factor := PROFILE.display_scale * 214.0 / 336.0
		assert_almost_eq(arc.global_transform.x.length(), factor * .93 * 1.35, .00001)
		assert_almost_eq(arc.global_transform.y.length(), factor * 1.35, .00001)
		var angle := float(body.data.ward_angle)
		var expected: Vector2 = backend.to_global(
			body.hand_position() + (Vector2(9, 22) * Vector2(.93, 1) * factor).rotated(angle)
		)
		assert_almost_eq(arc.global_position, expected, Vector2(.001, .001))
		backend.advance_simulation(.25)
		assert_false(arc.visible)
		backend.cancel_action()
		assert_false(body.ward_confirmed)
