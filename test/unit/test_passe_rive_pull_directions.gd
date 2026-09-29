extends GutTest
const Backend := preload("res://characters/achilles/2d/passe_rive_s19_backend.gd")
const PROFILE := preload("res://data/visuals/achilles/passe_rive_autosprite_profile_v1.tres")
const Tether := preload("res://vfx/class_cards/passe_rive_pull_tether.gd")
const Factory := preload("res://test/support/factory.gd")
const FACINGS := ["E", "SE", "S", "SW", "W", "NW", "N", "NE"]


func make_backend() -> Node2D:
	var backend := Backend.new()
	add_child_autofree(backend)
	assert_true(backend.configure(PROFILE))
	backend.set_backend_active(true)
	backend.set_cards_mode(true)
	backend.set_process(false)
	return backend


func test_every_facing_releases_on_the_same_authored_retraction() -> void:
	var backend := make_backend()
	var releases: Array = []
	backend.action_release_reached.connect(
		func():
			releases.append(backend.get_runtime_state()),
	)
	for facing in FACINGS:
		for step in [.4, 2.0]:
			releases.clear()
			backend.play_idle(facing)
			assert_true(backend.play_action(facing, &"cast", { "spell_id": "cc2_g04" }))
			backend.advance_simulation(step)
			assert_eq(releases.size(), 1)
			var state: Dictionary = releases[0]
			assert_eq(state.animation, Backend.PullBody.CLIP)
			assert_eq(state.frame, 6)
			assert_eq(state.authored_direction, facing)
			assert_eq(state.gesture_binding.status, "assigned")
			assert_false(state.mirrored)
			assert_almost_eq(float(state.release_seconds), .4, .00001)
			assert_almost_eq(float(state.painted_weight), 1.0, .00001)
			backend.advance_simulation(2.0)
			assert_eq(releases.size(), 1)
			assert_eq(backend.get_runtime_state().animation, "idle_" + facing)
			assert_false(backend.pull.visible)
			assert_eq(backend.animated_sprite.self_modulate, Color.WHITE)


func test_registered_hand_tracks_runtime_tether_under_room_transforms() -> void:
	var backend := make_backend()
	backend.position = Vector2(70, 120)
	backend.scale = Vector2.ONE * 1.35
	var hero := Factory.make_unit("Hero")
	var victim := Factory.make_unit("Victim", 1)
	var view := Node2D.new()
	add_child_autofree(view)
	view.position = Vector2(350, 170)
	var fx := Tether.new()
	add_child(fx)
	fx.configure(
		backend,
		hero,
		victim,
		view,
		func(cell):
			return Vector2(cell.x * 100, cell.y * 50),
		100,
	)
	fx.set_process(false)
	for facing in FACINGS:
		backend.play_action(facing, &"cast", { "spell_id": "cc2_g04" })
		var body: Sprite2D = backend.pull
		var fixed_scale: Vector2 = body.scale
		var start := 0.0
		for i in body.data.sequence.size():
			var time := start + .001
			backend._show_pull(time)
			var pose: Dictionary = body.data.frames[body.source_frame]
			var support := Vector2(body.data.support[0], body.data.support[1]) * PROFILE.display_scale
			assert_eq(body.scale, fixed_scale)
			assert_almost_eq(
				body.position + Vector2(pose.pivot[0], pose.pivot[1]) * body.scale,
				support,
				Vector2(.001, .001),
			)
			assert_true(Rect2(Vector2.ZERO, body.texture.get_size()).encloses(body.region_rect))
			assert_false(body.flip_h or body.flip_v)
			fx.sample(time)
			var expected: Vector2 = backend.to_global(
				body.position + Vector2(pose.hand[0], pose.hand[1]) * fixed_scale
			)
			assert_almost_eq(fx.source_point, expected, Vector2(.001, .001))
			assert_eq(view.position, Vector2(350, 170), "Unconfirmed flight never drags the target")
			start += float(body.data.duration_ms[i]) / 1000.0
		backend.cancel_action()
	fx.cancel()
	await get_tree().process_frame


func test_cancel_death_and_mode_switch_clear_all_directions_without_late_release() -> void:
	for facing in FACINGS:
		var backend := make_backend()
		watch_signals(backend)
		for exit_mode in ["cancel", "mode", "death"]:
			backend.set_cards_mode(true)
			backend.play_idle(facing)
			assert_true(backend.play_action(facing, &"cast", { "spell_id": "cc2_g04" }))
			backend.advance_simulation(.32)
			assert_true(backend.pull.visible)
			if exit_mode == "death":
				backend.play_death(facing)
			elif exit_mode == "mode":
				backend.set_cards_mode(false)
			else:
				backend.cancel_action()
				backend.play_idle(facing)
			backend.advance_simulation(1.0)
			assert_false(backend.pull.visible)
			assert_true(backend.animated_sprite.visible)
			assert_eq(backend.animated_sprite.self_modulate, Color.WHITE)
		assert_signal_not_emitted(backend, "action_release_reached")
