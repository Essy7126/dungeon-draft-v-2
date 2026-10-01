extends GutTest
const Backend := preload("res://characters/achilles/2d/passe_rive_s19_backend.gd")
const Body := preload("res://characters/achilles/2d/passe_rive_recenter_body.gd")
const PROFILE := preload("res://data/visuals/achilles/passe_rive_autosprite_profile_v1.tres")
const Spells := preload("res://core/expedition/consumable_card_spells.gd")
const FACINGS := ["E", "SE", "S", "SW", "W", "NW", "N", "NE"]


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


func test_base_upgraded_and_hitch_have_one_correct_release_in_all_views() -> void:
	var node := backend()
	var releases: Array = []
	node.action_release_reached.connect(
		func():
			releases.append(node.get_runtime_state()),
	)
	for upgraded in [false, true]:
		for facing in FACINGS:
			for hitch in [false, true]:
				releases.clear()
				var spell := Spells.make_spell("n08", upgraded)
				assert_true(node.play_action(facing, &"cast", { "spell_id": spell.spell_id }))
				if not hitch:
					node.advance_simulation(Body.RELEASE - .001)
					assert_eq(releases.size(), 0)
					assert_false(node.confirm_recenter("cc2_n08", 3))
					node.advance_simulation(.001)
				else:
					node.advance_simulation(3.0)
				assert_eq(releases.size(), 1)
				assert_eq(releases[0].animation, Body.CLIP)
				assert_eq(releases[0].frame, 6)
				assert_eq(releases[0].authored_direction, facing)
				assert_false(releases[0].mirrored)
				node.advance_simulation(2.0)
				assert_eq(releases.size(), 1)
				assert_eq(node.get_runtime_state().animation, "idle_" + facing)
				assert_false(node.recenter.visible)
				assert_eq(node.animated_sprite.self_modulate, Color.WHITE)


func test_fixed_scale_feet_and_palm_registration_for_every_pose_and_room_scale() -> void:
	for factor in [.75, 1.0, 1.4]:
		var node := backend(factor)
		for facing in FACINGS:
			assert_true(node.play_action(facing, &"cast", { "spell_id": "cc2_n08" }))
			var body: Node2D = node.recenter
			var fixed_scale: Vector2 = body.drawing.scale
			var edge := 0.0
			for i in 12:
				node._show_recenter(edge + .001)
				var frame: Dictionary = body.data.frames[i]
				assert_eq(body.source_frame, i)
				assert_eq(body.drawing.scale, fixed_scale)
				assert_almost_eq(
					body.drawing.position + Vector2(frame.pivot[0], frame.pivot[1]) * fixed_scale,
					Vector2(body.data.support[0], body.data.support[1])
					* PROFILE.display_scale * factor,
					Vector2(.001, .001),
				)
				assert_true(
					Rect2(Vector2.ZERO, body.drawing.texture.get_size()).encloses(
						body.drawing.region_rect
					)
				)
				assert_lt(
					absf(float(frame.solid_height) / float(body.data.source_height) - 1.0),
					.04,
					"No changing stature",
				)
				assert_almost_eq(
					body.drawing.self_modulate.a + node.animated_sprite.self_modulate.a,
					1.0,
					.00001,
				)
				assert_almost_eq(
					body.hand_position(),
					body.drawing.transform * Vector2(frame.hand[0], frame.hand[1]),
					Vector2(.001, .001),
				)
				edge += float(body.data.duration_ms[i]) / 1000.0
			assert_almost_eq(
				fixed_scale.y * float(body.data.source_height),
				214.0 * PROFILE.display_scale * factor,
				.001,
			)
			node.cancel_action()


func test_glyphs_follow_actual_draw_count_and_missing_or_duplicate_results() -> void:
	var node := backend()
	for facing in FACINGS:
		for count in [-1, 0, 1, 2, 3, 99]:
			assert_true(node.play_action(facing, &"cast", { "spell_id": "cc2_n08" }))
			node.advance_simulation(.40)
			assert_eq(node.recenter.glyph_count, 0)
			assert_false(node.confirm_recenter("cc2_n02", 3))
			assert_true(node.confirm_recenter("cc2_n08", count))
			assert_false(node.confirm_recenter("cc2_n08", 3))
			assert_eq(node.recenter.glyph_count, clampi(count, 0, 3))
			for i in 3:
				assert_eq(node.recenter.glyphs[i].is_visible_in_tree(), i < clampi(count, 0, 3))
			node.advance_simulation(.40)
			assert_false(node.recenter.is_visible_in_tree())
			assert_false(node.confirm_recenter("cc2_n08", 3))


func test_interruptions_remove_every_layer_without_late_confirmation() -> void:
	for facing in FACINGS:
		for at in [.2, .45]:
			for operation in ["cancel", "mode", "death", "shutdown"]:
				var node := backend()
				assert_true(node.play_action(facing, &"cast", { "spell_id": "cc2_n08" }))
				node.advance_simulation(at)
				assert_true(node.recenter.drawing.is_visible_in_tree())
				if at > Body.RELEASE:
					assert_true(node.confirm_recenter("cc2_n08", 2))
					assert_true(node.recenter.glyphs[0].is_visible_in_tree())
				match operation:
					"cancel":
						node.cancel_action()
					"mode":
						node.set_cards_mode(false)
					"death":
						node.play_death(facing)
					"shutdown":
						node.shutdown()
				assert_false(node.recenter.is_visible_in_tree())
				for glyph in node.recenter.glyphs:
					assert_false(glyph.is_visible_in_tree())
				assert_false(node.confirm_recenter("cc2_n08", 3))
				assert_eq(node.animated_sprite.self_modulate, Color.WHITE)
