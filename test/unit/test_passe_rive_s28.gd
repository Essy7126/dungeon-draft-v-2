extends GutTest
const Backend := preload("res://characters/achilles/2d/passe_rive_s19_backend.gd")
const Body := preload("res://characters/achilles/2d/passe_rive_drain_body.gd")
const Bindings := preload("res://characters/achilles/2d/passe_rive_card_bindings.gd")
const PROFILE := preload("res://data/visuals/achilles/passe_rive_autosprite_profile_v1.tres")
const Spells := preload("res://core/expedition/consumable_card_spells.gd")
const CARDS := ["t07"]


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


func test_each_assigned_card_and_upgrade_releases_once_on_the_grasp() -> void:
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
				assert_eq(Bindings.resolve(str(spell.spell_id)).reference, "drain")
				assert_true(node.play_action("SE", &"cast", { "spell_id": spell.spell_id }))
				node.advance_simulation(.329)
				assert_eq(releases.size(), 0, "No effect before the hand closes")
				node.advance_simulation(2.0 if hitch else .001)
				assert_eq(releases.size(), 1, id)
				assert_eq(releases[0].animation, Body.CLIP)
				assert_eq(releases[0].frame, 5)
				assert_almost_eq(float(releases[0].release_seconds), .33, .00001)
				node.advance_simulation(2.0)
				assert_eq(releases.size(), 1, "Recovery cannot commit twice")
				assert_eq(node.get_runtime_state().animation, "idle_SE")
				assert_true(node.animated_sprite.visible and not node.drain.visible)


func test_all_poses_keep_scale_ground_and_hand_registration_across_profile_sizes() -> void:
	for factor in [.75, 1.0, 1.4]:
		var node := backend(factor)
		node.play_action("SE", &"cast", { "spell_id": "cc2_t07" })
		var scale: Vector2 = node.drain.scale
		var edge := 0.0
		for i in 12:
			node._show_drain(edge + .0001)
			assert_eq(node.drain.source_frame, int(node.drain.data.sequence[i]))
			var row: Dictionary = node.drain.data.frames[node.drain.source_frame]
			var pivot := Vector2(row.pivot[0], row.pivot[1])
			assert_eq(node.drain.scale, scale, "No changing size during a cast")
			assert_almost_eq(
				node.drain.position + pivot * scale,
				Body.SUPPORT * PROFILE.display_scale * factor,
				Vector2(.001, .001),
			)
			assert_true(node.get_vfx_origin().is_equal_approx(node.drain.hand_position()))
			assert_false(
				node.body.visible or node.kick.visible or node.pull.visible
				or node.incantation.visible or node.guard.visible or node.animated_sprite.visible
			)
			edge += float(node.drain.data.duration_ms[i]) / 1000.0
		assert_almost_eq(
			scale.y * float(node.drain.data.source_height),
			214.0 * PROFILE.display_scale * factor,
			.001,
		)
		assert_almost_eq(scale.x / scale.y, .84, .0001, "One fixed width calibration")


func test_other_directions_keep_directional_cast_and_release_once() -> void:
	var node := backend()
	var releases: Array = []
	node.action_release_reached.connect(
		func():
			releases.append(node.get_runtime_state()),
	)
	for facing in ["N", "NE", "E", "S", "SW", "W", "NW"]:
		releases.clear()
		node.play_action(facing, &"cast", { "spell_id": "cc2_t07" })
		assert_false(node.drain.visible)
		assert_eq(node.get_runtime_state().gesture_binding.status, "pending_direction")
		node.advance_simulation(3.0)
		assert_eq(releases.size(), 1)
		assert_ne(releases[0].animation, Body.CLIP)
		assert_eq(releases[0].gesture_binding.fallback_reference, "t_mark")
		assert_eq(node.get_runtime_state().animation, "idle_" + facing)


func test_cancellation_and_mode_changes_remove_the_drain_without_late_release() -> void:
	var node := backend()
	watch_signals(node)
	node.play_action("SE", &"cast", { "spell_id": "cc2_t07" })
	node.advance_simulation(.12)
	node.cancel_action()
	node.play_idle("SE")
	node.advance_simulation(2.0)
	assert_signal_not_emitted(node, "action_release_reached")
	assert_false(node.drain.visible)
	node.play_action("SE", &"cast", { "spell_id": "cc2_t07" })
	node.set_cards_mode(false)
	assert_false(node.drain.visible)
	assert_true(node.animated_sprite.visible)
	node.advance_simulation(2.0)
	assert_signal_not_emitted(node, "action_release_reached")
	node.set_cards_mode(true)
	node.play_action("SE", &"cast", { "spell_id": "cc2_t07" })
	node.shutdown()
	node.advance_simulation(2.0)
	assert_false(node.drain.visible)
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
		"g01": "incantation",
	}
	var node := backend()
	for id in expected:
		assert_eq(Bindings.resolve("cc2_" + id).reference, expected[id])
		node.play_action("SE", &"cast", { "spell_id": "cc2_" + id })
		assert_false(node.drain.visible)
		node.cancel_action()
		node.play_idle("SE")


func test_flow_requires_confirmed_hp_damage_and_glint_requires_actual_healing() -> void:
	var node := backend()
	for amounts in [Vector2i(0, 0), Vector2i(10, 0), Vector2i(10, 5)]:
		node.play_action("SE", &"cast", { "spell_id": "cc2_t07" })
		assert_false(node.confirm_drain(Vector2(500, 80), amounts.x, amounts.y))
		assert_false(node.drain.siphon_confirmed)
		assert_false(node.owns_drain_heal_feedback())
		node.advance_simulation(.33)
		assert_true(node.owns_drain_heal_feedback())
		assert_false(node.drain.siphon.visible, "Drawing alone is not confirmation")
		assert_true(node.confirm_drain(Vector2(500, 80), amounts.x, amounts.y))
		node.advance_simulation(.20)
		assert_false(
			node.owns_drain_heal_feedback(),
			"Unrelated healing keeps its ordinary feedback",
		)
		assert_eq(node.drain.siphon.visible, amounts.x > 0)
		assert_eq(node.drain.siphon.glint, amounts.y > 0)
		assert_almost_eq(node.drain.to_global(node.drain.siphon.start), Vector2(500, 80), Vector2(
				.001,
				.001,
			))
		assert_almost_eq(
			node.drain.position + node.drain.siphon.finish * node.drain.scale,
			node.get_vfx_origin(),
			Vector2(.001, .001),
			"Flow arrives at the current registered hand",
		)
		node.confirm_drain(Vector2(800, 40), 99, 99)
		assert_eq(
			node.drain.hp_damage,
			amounts.x,
			"A duplicate confirmation cannot replace the cast",
		)
		node.advance_simulation(.3)
		assert_false(node.drain.siphon.visible, "Bounded lifetime")
		node.cancel_action()
		node.play_idle("SE")
		assert_false(node.drain.siphon.visible)
		assert_false(node.drain.siphon_confirmed)
		assert_eq(node.drain.hp_damage, 0)


func test_confirmed_flow_is_removed_on_mode_change_and_not_reused() -> void:
	var node := backend()
	node.play_action("SE", &"cast", { "spell_id": "cc2_t07" })
	node.advance_simulation(.33)
	node.confirm_drain(Vector2(300, 40), 10, 5)
	assert_true(node.drain.siphon.visible)
	node.set_cards_mode(false)
	assert_false(node.drain.siphon.visible)
	node.set_cards_mode(true)
	node.play_action("SE", &"cast", { "spell_id": "cc2_t07" })
	node.advance_simulation(.53)
	assert_false(node.drain.siphon_confirmed)
	assert_false(node.drain.siphon.visible)
	assert_false(node.drain.siphon.glint)
	assert_false(9 in node.drain.data.sequence, "Rejected drawing never plays")
