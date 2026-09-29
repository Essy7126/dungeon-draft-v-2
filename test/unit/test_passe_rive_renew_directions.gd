extends GutTest
const Backend := preload("res://characters/achilles/2d/passe_rive_s19_backend.gd")
const PROFILE := preload("res://data/visuals/achilles/passe_rive_autosprite_profile_v1.tres")
const FACINGS := ["E", "SE", "S", "SW", "W", "NW", "N", "NE"]


func make_backend(factor := 1.0) -> Node2D:
	var node := Backend.new()
	add_child_autofree(node)
	var profile := PROFILE.duplicate()
	profile.display_scale *= factor
	assert_true(node.configure(profile))
	node.set_backend_active(true)
	node.set_cards_mode(true)
	node.set_process(false)
	return node


func test_long_and_compact_frames_keep_registered_scale_support_and_hands() -> void:
	for factor in [.75, 1.0, 1.4]:
		var node := make_backend(factor)
		for facing in FACINGS:
			for id in ["i01", "l02"]:
				assert_true(node.play_action(facing, &"cast", { "spell_id": "cc2_" + id }))
				var body: Node2D = node.renew
				var fixed_scale: Vector2 = body.drawing.scale
				var sequence: Array = (
					body.data.short_sequence
					if id == "l02"
					else body \
							.data \
							.sequence
				)
				var times: Array = (
					body.data.short_duration_ms
					if id == "l02"
					else body \
							.data \
							.duration_ms
				)
				var edge := 0.0
				for i in sequence.size():
					node._show_renew(edge + .001)
					var pose: Dictionary = body.data.frames[sequence[i]]
					var support: Vector2 = Vector2(body.data.support[0], body.data.support[1]) * PROFILE.display_scale * factor
					assert_eq(body.source_frame, int(sequence[i]))
					assert_eq(body.drawing.scale, fixed_scale)
					assert_almost_eq(
						body.drawing.position + Vector2(pose.pivot[0], pose.pivot[1]) * fixed_scale,
						support,
						Vector2(.001, .001),
					)
					assert_true(
						Rect2(Vector2.ZERO, body.drawing.texture.get_size()).encloses(
							body.drawing.region_rect
						)
					)
					assert_almost_eq(
						body.drawing.self_modulate.a + node.animated_sprite.self_modulate.a,
						1.0,
						.00001,
					)
					assert_eq(body.facing, facing)
					for hand in 2:
						var socket: Vector2 = Vector2(pose.hands[hand][0], pose.hands[hand][1])
						assert_true(
							Rect2(Vector2.ZERO, body.drawing.region_rect.size).has_point(socket)
						)
						assert_almost_eq(
							body.hand_position(hand),
							body.drawing.transform * socket,
							Vector2(.001, .001),
						)
					edge += float(times[i]) / 1000.0
				assert_almost_eq(
					fixed_scale.y * float(body.data.source_height),
					214.0 * PROFILE.display_scale * factor,
					.001,
				)
				node.cancel_action()


func test_both_light_tips_follow_both_palms_and_only_actual_results_in_every_view() -> void:
	var node := make_backend()
	for facing in FACINGS:
		for id in ["i01", "l02"]:
			for amounts in [[0, 0], [12, 0], [0, 8], [12, 8]]:
				assert_true(node.play_action(facing, &"cast", { "spell_id": "cc2_" + id }))
				node.advance_simulation(node.renew.release_time())
				assert_true(node.confirm_renew("cc2_" + id, amounts[0], amounts[1]))
				assert_false(node.confirm_renew("cc2_" + id, 99, 99))
				node.advance_simulation(.12)
				assert_eq(node.renew.healing_visible, amounts[0] > 0)
				assert_eq(node.renew.guard_visible, amounts[1] > 0)
				if amounts[0] > 0:
					var tip: Array = node.renew.data.vfx.frames[2].tip
					for hand in 2:
						assert_almost_eq(
							node.renew.plumes[hand].transform * Vector2(tip[0], tip[1]),
							node.renew.hand_position(hand),
							Vector2(.001, .001),
						)
				node.advance_simulation(2.0)
				assert_eq(node.get_runtime_state().animation, "idle_" + facing)
				assert_false(node.renew.visible)


func test_interruptions_clear_body_and_light_in_all_directions() -> void:
	for facing in FACINGS:
		for id in ["i01", "l02"]:
			for operation in ["cancel", "mode", "death", "shutdown"]:
				var node := make_backend()
				assert_true(node.play_action(facing, &"cast", { "spell_id": "cc2_" + id }))
				node.advance_simulation(node.renew.release_time() + .12)
				assert_true(node.confirm_renew("cc2_" + id, 12, 8))
				assert_true(node.renew.drawing.is_visible_in_tree())
				assert_true(node.renew.healing_visible)
				match operation:
					"cancel":
						node.cancel_action()
					"mode":
						node.set_cards_mode(false)
					"death":
						node.play_death(facing)
					"shutdown":
						node.shutdown()
				assert_false(node.renew.is_visible_in_tree())
				for layer in node.renew.plumes + node.renew.facets:
					assert_false(layer.is_visible_in_tree())
				assert_eq(node.animated_sprite.self_modulate, Color.WHITE)
