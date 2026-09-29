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
		for step in [.33, 2.0]:
			releases.clear()
			backend.play_idle(facing)
			assert_true(backend.play_action(facing, &"cast", { "spell_id": "cc2_t07" }))
			backend.advance_simulation(step)
			assert_eq(releases.size(), 1)
			var state: Dictionary = releases[0]
			assert_eq(state.animation, Backend.DrainBody.CLIP)
			assert_eq(state.frame, 5)
			assert_eq(state.authored_direction, facing)
			assert_eq(state.gesture_binding.status, "assigned")
			assert_false(state.mirrored)
			assert_almost_eq(float(state.release_seconds), .33, .00001)
			assert_almost_eq(float(state.painted_weight), 1.0, .00001)
			backend.advance_simulation(2.0)
			assert_eq(releases.size(), 1)
			assert_eq(backend.get_runtime_state().animation, "idle_" + facing)
			assert_false(backend.drain.visible)
			assert_eq(backend.animated_sprite.self_modulate, Color.WHITE)


func test_drain_poses_keep_support_and_hand_in_all_angles() -> void:
	var backend := make_backend()
	for id in ["t07"]:
		for facing in FACINGS:
			backend.play_idle(facing)
			backend.play_action(facing, &"cast", { "spell_id": "cc2_" + id })
			backend.advance_simulation(.329)
			assert_false(backend.get_runtime_state().release_emitted)
			backend.advance_simulation(.001)
			var state: Dictionary = backend.get_runtime_state()
			assert_true(state.release_emitted)
			assert_eq(state.authored_direction, facing)
			assert_eq(state.animation, Backend.DrainBody.CLIP)
			assert_eq(state.frame, 5)
			var body: Sprite2D = backend.drain
			var scale: Vector2 = body.scale
			var time := 0.0
			for ms in body.data.duration_ms:
				backend._show_drain(time + .001)
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
			assert_true(backend.play_action(facing, &"cast", { "spell_id": "cc2_t07" }))
			backend.advance_simulation(.12)
			assert_true(backend.drain.visible)
			if exit_mode == "death":
				backend.play_death(facing)
			elif exit_mode == "mode":
				backend.set_cards_mode(false)
			else:
				backend.cancel_action()
				backend.play_idle(facing)
			backend.advance_simulation(1.0)
			assert_false(backend.drain.visible)
			assert_true(backend.animated_sprite.visible)
			assert_eq(backend.animated_sprite.self_modulate, Color.WHITE)
		assert_signal_not_emitted(backend, "action_release_reached")


func test_confirmed_flow_keeps_target_hand_and_thickness_across_all_views() -> void:
	var backend := make_backend()
	backend.position = Vector2(27, -19)
	backend.scale = Vector2.ONE * 1.35
	for facing in FACINGS:
		for amounts in [Vector2i(0, 0), Vector2i(10, 0), Vector2i(10, 5)]:
			backend.play_idle(facing)
			backend.play_action(facing, &"cast", { "spell_id": "cc2_t07" })
			assert_false(backend.confirm_drain(Vector2(500, 80), amounts.x, amounts.y))
			backend.advance_simulation(.33)
			assert_false(backend.drain.siphon.visible)
			assert_true(backend.confirm_drain(Vector2(500, 80), amounts.x, amounts.y))
			backend.advance_simulation(.20)
			var body: Sprite2D = backend.drain
			var flow: Node2D = body.siphon
			assert_eq(flow.visible, amounts.x > 0)
			assert_eq(flow.glint, amounts.y > 0)
			assert_almost_eq(flow.to_global(flow.start), Vector2(500, 80), Vector2(.001, .001))
			assert_almost_eq(
				flow.to_global(flow.finish),
				backend.to_global(backend.get_vfx_origin()),
				Vector2(.001, .001),
			)
			var factor := PROFILE.display_scale * 214.0 / 343.0 * 1.35
			assert_almost_eq(flow.global_transform.x.length(), factor * .84, .00001)
			assert_almost_eq(flow.global_transform.y.length(), factor, .00001)
			backend.advance_simulation(.3)
			assert_false(flow.visible)
			backend.cancel_action()
			assert_false(body.siphon_confirmed)
