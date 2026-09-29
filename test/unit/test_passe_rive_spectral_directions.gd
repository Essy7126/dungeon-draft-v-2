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


func test_registered_body_and_veil_keep_scale_and_shared_opacity_in_all_views() -> void:
	for factor in [.75, 1.0, 1.4]:
		var node := make_backend(factor)
		for facing in FACINGS:
			node.play_idle(facing)
			node.play_action(facing, &"cast", { "spell_id": "cc2_a05" })
			var body: Node2D = node.spectral
			var scale: Vector2 = body.drawing.scale
			var veil_scale: Vector2 = body.veil.scale
			body.arrival_confirmed = true
			var edge := 0.0
			for i in 12:
				node._show_spectral(edge + .001)
				var pose: Dictionary = body.data.frames[i]
				var support: Vector2 = Vector2(body.data.support[0], body.data.support[1]) * PROFILE.display_scale * factor
				assert_eq(body.source_frame, i)
				assert_eq(body.drawing.scale, scale)
				assert_eq(body.veil.scale, veil_scale)
				assert_almost_eq(
					body.drawing.position + Vector2(pose.pivot[0], pose.pivot[1]) * scale,
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
					body.body_alpha,
					.00001,
				)
				assert_eq(body.facing, facing)
				edge += float(body.data.duration_ms[i]) / 1000.0
			assert_almost_eq(
				scale.y * float(body.data.source_height),
				214.0 * PROFILE.display_scale * factor,
				.001,
			)
			node.cancel_action()


func test_no_relocation_restores_native_and_interruptions_clear_all_eight_views() -> void:
	for facing in FACINGS:
		var node := make_backend()
		node.play_idle(facing)
		assert_true(node.play_action(facing, &"cast", { "spell_id": "cc2_r08" }))
		node.advance_simulation(.51)
		assert_false(node.spectral.arrival_confirmed)
		assert_eq(node.spectral.body_alpha, 0.0)
		node.advance_simulation(.31)
		assert_eq(node.spectral.native_weight, 1.0)
		assert_false(node.spectral.drawing.visible)
		node.advance_simulation(.1)
		assert_eq(node.get_runtime_state().animation, "idle_" + facing)
		for mode in ["cancel", "mode", "death"]:
			node.set_cards_mode(true)
			node.play_idle(facing)
			assert_true(node.play_action(facing, &"cast", { "spell_id": "cc2_r08" }))
			node.advance_simulation(.29)
			if mode == "death":
				node.play_death(facing)
			elif mode == "mode":
				node.set_cards_mode(false)
			else:
				node.cancel_action()
				node.play_idle(facing)
			assert_false(node.spectral.visible)
			assert_false(node.spectral.veil.is_visible_in_tree())
			assert_true(node.animated_sprite.visible)
			assert_eq(node.animated_sprite.self_modulate, Color.WHITE)
