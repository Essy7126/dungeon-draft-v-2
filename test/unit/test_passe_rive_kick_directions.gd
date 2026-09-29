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


func test_all_cards_and_facings_share_one_contact_and_no_idle_fallback() -> void:
	var backend := make_backend()
	var releases: Array = []
	backend.action_release_reached.connect(
		func():
			releases.append(backend.get_runtime_state()),
	)
	for id in ["cc2_n04", "cc2_g03", "cc2_g06"]:
		for facing in FACINGS:
			for step in [0.31, 1.0]:
				releases.clear()
				backend.play_idle(facing)
				assert_true(backend.play_action(facing, &"cast", { "spell_id": id }))
				backend.advance_simulation(step)
				assert_eq(releases.size(), 1)
				var state: Dictionary = releases[0]
				assert_eq(state.animation, Backend.KICK)
				assert_eq(state.frame, 4)
				assert_eq(state.authored_direction, facing)
				assert_eq(state.gesture_binding.status, "assigned")
				assert_false(state.mirrored)
				assert_almost_eq(float(state.painted_weight), 1.0, .00001)
				backend.advance_simulation(1.0)
				assert_eq(releases.size(), 1)
				assert_eq(backend.get_runtime_state().animation, "idle_" + facing)
				assert_false(backend.kick.visible)
				assert_eq(backend.animated_sprite.self_modulate, Color.WHITE)


func test_authored_regions_constant_scale_foot_registration_and_heel_socket() -> void:
	var backend := make_backend()
	for facing in FACINGS:
		backend.play_action(facing, &"cast", { "spell_id": "cc2_n04" })
		var kick: Sprite2D = backend.kick
		var size: Vector2 = kick.scale
		for frame in 8:
			backend._show_kick(frame)
			var metadata: Dictionary = kick.data
			var pose: Dictionary = metadata.frames[int(metadata.sequence[frame])]
			var support := Vector2(metadata.support[0], metadata.support[1]) * PROFILE.display_scale
			assert_eq(kick.scale, size, "Fixed scale: " + facing)
			assert_almost_eq(
				kick.to_local(support),
				Vector2(pose.pivot[0], pose.pivot[1]),
				Vector2(.001, .001),
			)
			assert_true(Rect2(Vector2.ZERO, kick.texture.get_size()).encloses(kick.region_rect))
			assert_false(kick.flip_h or kick.flip_v)
		backend._show_kick(4)
		var contact: Array = kick.data.contact
		assert_almost_eq(
			backend.get_vfx_origin(),
			kick.position + Vector2(contact[0], contact[1]) * kick.scale,
			Vector2(.001, .001),
		)
		backend.cancel_action()


func test_cancellation_death_and_mode_switch_remove_every_direction() -> void:
	for facing in FACINGS:
		var backend := make_backend()
		watch_signals(backend)
		for exit_mode in ["cancel", "mode", "death"]:
			backend.set_cards_mode(true)
			backend.play_idle(facing)
			assert_true(backend.play_action(facing, &"cast", { "spell_id": "cc2_g03" }))
			backend.advance_simulation(.20)
			assert_true(backend.kick.visible)
			if exit_mode == "death":
				backend.play_death(facing)
			elif exit_mode == "mode":
				backend.set_cards_mode(false)
			else:
				backend.cancel_action()
				backend.play_idle(facing)
			backend.advance_simulation(1.0)
			assert_false(backend.kick.visible)
			assert_true(backend.animated_sprite.visible)
			assert_eq(backend.animated_sprite.self_modulate, Color.WHITE)
		assert_signal_not_emitted(backend, "action_release_reached")
