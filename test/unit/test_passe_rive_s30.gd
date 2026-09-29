extends GutTest
const Backend := preload("res://characters/achilles/2d/passe_rive_s19_backend.gd")
const Body := preload("res://characters/achilles/2d/passe_rive_renew_body.gd")
const PROFILE := preload("res://data/visuals/achilles/passe_rive_autosprite_profile_v1.tres")
const Spells := preload("res://core/expedition/consumable_card_spells.gd")
const DIRECTIONS := ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]


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


func test_two_cards_both_versions_all_directions_keep_one_release_and_native_recovery() -> void:
	var node := backend()
	var releases: Array = []
	node.action_release_reached.connect(
		func():
			releases.append(node.get_runtime_state()),
	)
	for id in ["i01", "l02"]:
		var release := Body.RELEASE if id == "i01" else Body.SHORT_RELEASE
		for upgraded in [false, true]:
			for facing in DIRECTIONS:
				releases.clear()
				var spell := Spells.make_spell(id, upgraded)
				assert_true(node.play_action(facing, &"cast", { "spell_id": spell.spell_id }))
				node.advance_simulation(release - .001)
				assert_eq(releases.size(), 0)
				assert_false(node.confirm_renew(str(spell.spell_id), 10, 5))
				node.advance_simulation(.001)
				assert_eq(releases.size(), 1)
				assert_eq(releases[0].animation, Body.CLIP)
				assert_eq(releases[0].frame, 6 if id == "i01" else 4)
				assert_true(node.renew.painted)
				assert_true(node.renew.drawing.visible)
				assert_eq(releases[0].authored_direction, facing)
				assert_ne(releases[0].gesture_binding.status, "pending_direction")
				assert_true(node.confirm_renew(str(spell.spell_id), 10, 5))
				node.advance_simulation(.16)
				assert_true(node.renew.healing_visible)
				assert_true(node.renew.guard_visible)
				node.advance_simulation(2.0)
				assert_eq(releases.size(), 1)
				assert_eq(node.get_runtime_state().animation, "idle_" + facing)
				assert_false(node.renew.visible)
				assert_eq(node.animated_sprite.self_modulate, Color.WHITE)


func test_actual_healing_and_guard_are_independent_and_confirmation_is_idempotent() -> void:
	var node := backend()
	for amounts in [[0, 5], [10, 0], [0, 0], [10, 5]]:
		node.play_action("SE", &"cast", { "spell_id": "cc2_i01" })
		node.advance_simulation(Body.RELEASE)
		assert_false(node.confirm_renew("cc2_l02", 999, 999))
		assert_true(node.confirm_renew("cc2_i01", amounts[0], amounts[1]))
		assert_false(node.confirm_renew("cc2_i01", 999, 999))
		node.advance_simulation(.16)
		assert_eq(node.renew.healing, amounts[0])
		assert_eq(node.renew.guard_gain, amounts[1])
		assert_eq(node.renew.healing_visible, amounts[0] > 0)
		assert_eq(node.renew.guard_visible, amounts[1] > 0)
		node.advance_simulation(2.0)


func test_missing_result_never_claims_restoration_or_guard() -> void:
	var node := backend()
	node.play_action("SE", &"cast", { "spell_id": "cc2_i01" })
	node.advance_simulation(.62)
	assert_false(node.renew.confirmed)
	assert_false(node.renew.healing_visible)
	assert_false(node.renew.guard_visible)
	for sprite in node.renew.plumes + node.renew.facets:
		assert_false(sprite.is_visible_in_tree())
	node.advance_simulation(1.0)
	assert_eq(node.get_runtime_state().animation, "idle_SE")


func test_all_frames_keep_fixed_scale_and_registered_foot_in_three_room_scales() -> void:
	for factor in [.75, 1.0, 1.4]:
		var node := backend(factor)
		for id in ["i01", "l02"]:
			node.play_action("SE", &"cast", { "spell_id": "cc2_" + id })
			assert_eq(node.animated_sprite.self_modulate.a, 1.0)
			var metadata: Dictionary = node.renew.data
			var sequence: Array = metadata.short_sequence if id == "l02" else metadata.sequence
			var times: Array = metadata.short_duration_ms if id == "l02" else metadata.duration_ms
			var fixed_scale: Vector2 = node.renew.drawing.scale
			var at := 0.0
			for i in sequence.size():
				node._show_renew(at + .00001)
				var frame: Dictionary = node.renew.data.frames[sequence[i]]
				assert_eq(node.renew.source_frame, int(sequence[i]))
				assert_eq(node.renew.drawing.scale, fixed_scale)
				assert_almost_eq(
					node.renew.drawing.position
					+ Vector2(frame.pivot[0], frame.pivot[1]) * fixed_scale,
					Body.SUPPORT * PROFILE.display_scale * factor,
					Vector2(.001, .001),
				)
				assert_eq(node.get_vfx_origin(), node.renew.hand_position())
				at += float(times[i]) / 1000.0
			assert_almost_eq(
				fixed_scale.y * float(node.renew.data.source_height),
				214.0 * PROFILE.display_scale * factor,
				.001,
			)
			node._show_renew(node.renew.duration() - .02)
			assert_eq(node.animated_sprite.self_modulate.a, 1.0)
			assert_false(node.renew.drawing.visible)
			node.cancel_action()


func test_cancel_before_and_after_release_removes_all_layers_without_late_signals() -> void:
	var node := backend()
	var releases: Array = []
	node.action_release_reached.connect(
		func():
			releases.append(true),
	)
	for time in [.15, .50, .80]:
		node.play_action("SE", &"cast", { "spell_id": "cc2_i01" })
		node.advance_simulation(time)
		node.confirm_renew("cc2_i01", 10, 10)
		var count := releases.size()
		node.cancel_action()
		assert_false(node.renew.visible)
		assert_false(node.renew.confirmed)
		assert_eq(node.animated_sprite.self_modulate, Color.WHITE)
		assert_eq(node.get_runtime_state().animation, "idle_SE")
		node.advance_simulation(3.0)
		assert_eq(releases.size(), count)
		assert_false(node.confirm_renew("cc2_i01", 99, 99))


func test_hitch_samples_the_correct_contact_before_completion() -> void:
	var node := backend()
	var releases: Array = []
	node.action_release_reached.connect(
		func():
			releases.append(node.get_runtime_state()),
	)
	for id in ["i01", "l02"]:
		releases.clear()
		node.play_action("SE", &"cast", { "spell_id": "cc2_" + id })
		node.advance_simulation(3.0)
		assert_eq(releases.size(), 1)
		assert_eq(releases[0].frame, 6 if id == "i01" else 4)
		assert_eq(node.get_runtime_state().animation, "idle_SE")


func test_mode_death_shutdown_and_next_cast_cannot_leave_aura_visible() -> void:
	for operation in ["mode", "death", "shutdown", "next"]:
		var node := backend()
		node.play_action("SE", &"cast", { "spell_id": "cc2_i01" })
		node.advance_simulation(.60)
		node.confirm_renew("cc2_i01", 15, 6)
		match operation:
			"mode":
				node.set_cards_mode(false)
			"death":
				node.play_death("SE")
			"shutdown":
				node.shutdown()
			"next":
				assert_false(node.play_action("SE", &"cast", { "spell_id": "cc2_n05" }))
				node.cancel_action()
				assert_true(node.play_action("SE", &"cast", { "spell_id": "cc2_n05" }))
		assert_false(node.renew.is_visible_in_tree())
		assert_eq(node.animated_sprite.self_modulate, Color.WHITE)


func test_light_uses_sibling_order_instead_of_dropping_below_the_floor() -> void:
	var node := backend()
	for plume in node.renew.plumes:
		assert_eq(plume.z_index, 0)
		assert_lt(plume.get_index(), node.renew.drawing.get_index())
	for facet in node.renew.facets:
		assert_eq(facet.z_index, 0)
	assert_lt(node.renew.facets[1].get_index(), node.renew.drawing.get_index())
	assert_gt(node.renew.facets[0].get_index(), node.renew.drawing.get_index())


func test_authored_light_tips_follow_both_palms_at_the_restoration_peak() -> void:
	var node := backend()
	node.play_action("SE", &"cast", { "spell_id": "cc2_i01" })
	node.advance_simulation(.45)
	node.confirm_renew("cc2_i01", 20, 10)
	var tip: Array = node.renew.data.vfx.frames[2].tip
	for i in 2:
		var plume: Sprite2D = node.renew.plumes[i]
		assert_almost_eq(
			plume.transform * Vector2(tip[0], tip[1]),
			node.renew.hand_position(i),
			Vector2(.001, .001),
		)
