extends GutTest
const Backend := preload("res://tools/class_card_vfx/passe_rive_s24/kick_backend.gd")
const PROFILE := preload("res://data/visuals/achilles/passe_rive_autosprite_profile_v1.tres")


func make_backend() -> Node2D:
	var backend := Backend.new()
	add_child_autofree(backend)
	assert_true(backend.configure(PROFILE))
	backend.set_backend_active(true)
	backend.set_cards_mode(true)
	backend.set_process(false)
	return backend


func test_real_clock_publishes_contact_before_release_even_on_hitch() -> void:
	for step in [0.31, 1.0]:
		var backend := make_backend()
		var released: Array = []
		backend.action_release_reached.connect(
			func():
				released.append(backend.get_runtime_state()),
		)
		assert_true(backend.play_action("SE", &"cast:class_a_push", { "spell_id": "class_a_push" }))
		backend.advance_simulation(step)
		assert_eq(released.size(), 1)
		assert_eq(released[0].animation, Backend.KICK)
		assert_eq(released[0].frame, 4)
		backend.advance_simulation(1.0)
		assert_eq(released.size(), 1)
		backend.play_idle("SE")
		assert_true(
			backend.animated_sprite.visible
			and not backend.kick.visible and not backend.body.visible
		)


func test_cancel_before_impact_cannot_release_later() -> void:
	var backend := make_backend()
	watch_signals(backend)
	backend.play_action("SE", &"cast", { "spell_id": "class_a_push" })
	backend.advance_simulation(.20)
	backend.cancel_action()
	backend.play_idle("SE")
	backend.advance_simulation(1.0)
	assert_signal_not_emitted(backend, "action_release_reached")
	assert_false(backend.kick.visible)


func test_constant_scale_registered_support_and_prototype_isolation() -> void:
	var backend := make_backend()
	var original_script: Script = PROFILE.backend_script
	backend.play_action("SE", &"cast", { "spell_id": "class_a_push" })
	var scale: Vector2 = backend.kick.scale
	for i in 8:
		backend._show_kick(i)
		var pivot: Array = backend.kick_data.frames[i].pivot
		assert_eq(backend.kick.scale, scale, "No pose-dependent resizing")
		assert_almost_eq(backend.kick.to_local(Backend.SUPPORT * PROFILE.display_scale), Vector2(
				pivot[0],
				pivot[1],
			), Vector2(.001, .001))
		assert_false(backend.animated_sprite.visible or backend.body.visible, "Only one silhouette")
	backend.cancel_action()
	backend.play_action("NW", &"cast", { "spell_id": "class_a_push" })
	assert_false(backend.kick.visible, "No unvalidated mirrored direction")
	backend.cancel_action()
	backend.play_action("SE", &"cast", { "spell_id": "class_a_dagger" })
	assert_false(backend.kick.visible, "Other cards keep their backend")
	assert_eq(PROFILE.backend_script, original_script)
