extends GutTest
const Backend := preload("res://characters/achilles/2d/passe_rive_s19_backend.gd")
const Body := preload("res://characters/achilles/2d/passe_rive_incantation_body.gd")
const Bindings := preload("res://characters/achilles/2d/passe_rive_card_bindings.gd")
const PROFILE := preload("res://data/visuals/achilles/passe_rive_autosprite_profile_v1.tres")
const Spells := preload("res://core/expedition/consumable_card_spells.gd")
const CARDS := ["g01", "g08", "l02", "a09", "t03", "t06", "t09"]


func backend(factor := 1.0) -> Node2D:
	var node := Backend.new()
	add_child_autofree(node)
	var profile := PROFILE.duplicate()
	profile.display_scale *= factor
	assert_true(node.configure(profile))
	node.set_backend_active(true)
	node.set_cards_mode(true)
	node.set_process(false)
	return node


func test_each_assigned_card_and_upgrade_releases_once_on_the_open_palms() -> void:
	assert_eq(PROFILE.backend_script, Backend, "The public profile owns this integration")
	var node := backend()
	var releases: Array = []
	node.action_release_reached.connect(
		func():
			releases.append(node.get_runtime_state()),
	)
	for id in CARDS:
		for upgraded in [false, true]:
			for hitch in [false, true]:
				releases.clear()
				var spell := Spells.make_spell(id, upgraded)
				assert_eq(Bindings.resolve(str(spell.spell_id)).reference, "incantation")
				assert_true(node.play_action("SE", &"cast", { "spell_id": spell.spell_id }))
				node.advance_simulation(.589)
				assert_eq(releases.size(), 0, "No effect before the palms open")
				node.advance_simulation(2.0 if hitch else .001)
				assert_eq(releases.size(), 1, id)
				assert_eq(releases[0].animation, Body.CLIP)
				assert_eq(releases[0].frame, 6)
				assert_almost_eq(float(releases[0].release_seconds), .59, .00001)
				node.advance_simulation(2.0)
				assert_eq(releases.size(), 1, "Recovery cannot commit twice")
				assert_eq(node.get_runtime_state().animation, "idle_SE")
				assert_true(node.animated_sprite.visible and not node.incantation.visible)


func test_all_poses_keep_scale_ground_and_hand_registration_across_profile_sizes() -> void:
	for factor in [.75, 1.0, 1.4]:
		var node := backend(factor)
		node.play_action("SE", &"cast", { "spell_id": "cc2_t03" })
		var scale: Vector2 = node.incantation.scale
		var edge := 0.0
		for i in 12:
			node._show_incantation(edge + .0001)
			assert_eq(node.incantation.source_frame, i)
			var row: Dictionary = node.incantation.data.frames[i]
			var pivot := Vector2(row.pivot[0], row.pivot[1])
			assert_eq(node.incantation.scale, scale, "No changing size during a cast")
			assert_almost_eq(
				node.incantation.position + pivot * scale,
				Body.SUPPORT * PROFILE.display_scale * factor,
				Vector2(.001, .001),
			)
			assert_true(node.get_vfx_origin().is_equal_approx(node.incantation.hand_position()))
			assert_false(
				node.body.visible or node.kick.visible
				or node.pull.visible or node.animated_sprite.visible
			)
			edge += float(node.incantation.data.duration_ms[i]) / 1000.0
		assert_almost_eq(
			scale.y * float(node.incantation.data.source_height),
			214.0 * PROFILE.display_scale * factor,
			.001,
		)
		assert_almost_eq(scale.x / scale.y, .8, .0001, "One fixed width calibration")


func test_other_directions_keep_their_directional_incantation_and_emit_once() -> void:
	var node := backend()
	var releases: Array = []
	node.action_release_reached.connect(
		func():
			releases.append(node.get_runtime_state()),
	)
	for facing in ["N", "NE", "E", "S", "SW", "W", "NW"]:
		releases.clear()
		node.play_action(facing, &"cast", { "spell_id": "cc2_t03" })
		assert_false(node.incantation.visible, "Never paste a SE drawing over a back view")
		assert_eq(node.get_runtime_state().gesture_binding.status, "pending_direction")
		assert_eq(node.get_runtime_state().gesture_binding.fallback_reference, "t_mark")
		node.advance_simulation(3.0)
		assert_eq(releases.size(), 1)
		assert_eq(releases[0].animation, "PR_SEAL")
		assert_eq(releases[0].facing, facing)
		if facing in ["E", "W"]:
			assert_true(
				node.body.atlases.has("PR_SEAL"),
				"Side views use the base atlas and its existing mirror",
			)
		else:
			assert_false(str(releases[0].directional_source).is_empty())
		assert_eq(node.get_runtime_state().animation, "idle_" + facing)


func test_cancellation_and_mode_changes_remove_the_incantation_without_late_release() -> void:
	var node := backend()
	watch_signals(node)
	node.play_action("SE", &"cast", { "spell_id": "cc2_g01" })
	node.advance_simulation(.40)
	node.cancel_action()
	node.play_idle("SE")
	node.advance_simulation(2.0)
	assert_signal_not_emitted(node, "action_release_reached")
	assert_false(node.incantation.visible)
	node.play_action("SE", &"cast", { "spell_id": "cc2_t03" })
	node.set_cards_mode(false)
	assert_false(node.incantation.visible)
	assert_true(node.animated_sprite.visible)
	node.advance_simulation(2.0)
	assert_signal_not_emitted(node, "action_release_reached")
	node.set_cards_mode(true)
	node.play_action("SE", &"cast", { "spell_id": "cc2_t03" })
	node.shutdown()
	node.advance_simulation(2.0)
	assert_false(node.incantation.visible)
	assert_signal_not_emitted(node, "action_release_reached")


func test_weapons_movement_and_other_magic_keep_their_own_gestures() -> void:
	var expected := {
		"n05": "r_shot",
		"r04": "r_fan",
		"a01": "a_dagger",
		"n04": "kick",
		"g04": "pull",
		"n03": "dash",
		"r05": "blink",
		"t02": "t_fire",
		"t01": "t_mark",
		"n02": "guard",
	}
	var node := backend()
	for id in expected:
		assert_eq(Bindings.resolve("cc2_" + id).reference, expected[id])
		node.play_action("SE", &"cast", { "spell_id": "cc2_" + id })
		assert_false(node.incantation.visible)
		node.cancel_action()
		node.play_idle("SE")
