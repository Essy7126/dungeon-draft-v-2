extends GutTest
const Backend := preload("res://characters/achilles/2d/passe_rive_s19_backend.gd")
const Body := preload("res://characters/achilles/2d/passe_rive_spectral_body.gd")
const PROFILE := preload("res://data/visuals/achilles/passe_rive_autosprite_profile_v1.tres")
const Spells := preload("res://core/expedition/consumable_card_spells.gd")
const MovementFixtures := preload("res://test/unit/test_unit_movement_presentation.gd")
const DIRECTIONS := ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]


func test_blink_snaps_to_destination_and_publishes_arrival_after_report_turn() -> void:
	var fixture = MovementFixtures.MovementBattleFixture.new()
	add_child_autofree(fixture)
	var unit := Unit.new("Spectral", 0, 30)
	unit.grid_pos = Vector2i(3, 1)
	fixture._create_unit_view(unit)
	var view: Node2D = fixture._unit_views[unit]
	fixture._spell_resolution_pending = true
	fixture._active_spell_movement_instant = true
	watch_signals(EventBus)
	fixture._start_spell_movement_feedback(unit, view, Vector2i(1, 1), unit.grid_pos)
	assert_eq(view.position, Vector2(192, 32))
	assert_null(fixture._spell_movement_feedback_tween)
	assert_signal_not_emitted(EventBus, "unit_visual_movement_finished")
	await get_tree().process_frame
	assert_signal_emit_count(EventBus, "unit_visual_movement_finished", 1)
	fixture._spell_resolution_pending = false


func test_cancelled_instant_arrival_cannot_publish_over_a_later_action() -> void:
	var fixture = MovementFixtures.MovementBattleFixture.new()
	add_child_autofree(fixture)
	var unit := Unit.new("Spectral", 0, 30)
	unit.grid_pos = Vector2i(3, 1)
	fixture._create_unit_view(unit)
	var view: Node2D = fixture._unit_views[unit]
	fixture._spell_resolution_pending = true
	fixture._active_spell_movement_instant = true
	watch_signals(EventBus)
	fixture._start_spell_movement_feedback(unit, view, Vector2i(1, 1), unit.grid_pos)
	fixture._cancel_spell_movement_feedback(false)
	await get_tree().process_frame
	assert_signal_not_emitted(EventBus, "unit_visual_movement_finished")
	fixture._spell_resolution_pending = false


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


func test_three_cards_both_versions_all_directions_hide_at_the_single_release() -> void:
	var node := backend()
	var releases: Array = []
	node.action_release_reached.connect(
		func():
			releases.append(node.get_runtime_state()),
	)
	for id in ["a05", "r05", "r08"]:
		for upgraded in [false, true]:
			for facing in DIRECTIONS:
				releases.clear()
				var spell := Spells.make_spell(id, upgraded)
				assert_true(node.play_action(facing, &"cast", { "spell_id": spell.spell_id }))
				node.advance_simulation(.309)
				assert_eq(releases.size(), 0)
				node.advance_simulation(.001)
				assert_eq(releases.size(), 1)
				assert_eq(releases[0].animation, Body.CLIP)
				assert_eq(releases[0].frame, 5)
				assert_almost_eq(float(releases[0].spectral_alpha), 0.0, .00001)
				assert_false(releases[0].arrival_confirmed)
				node.position += Vector2(100, 50)
				node.advance_simulation(.20)
				var arrived: Dictionary = node.get_runtime_state()
				assert_true(arrived.arrival_confirmed)
				assert_almost_eq(float(arrived.spectral_alpha), 1.0, .00001)
				assert_true(node.spectral.painted)
				assert_true(node.spectral.drawing.visible)
				assert_eq(arrived.authored_direction, facing)
				assert_eq(arrived.gesture_binding.status, "assigned")
				assert_false(arrived.mirrored)
				node.advance_simulation(1.0)
				assert_eq(releases.size(), 1)
				assert_eq(node.get_runtime_state().animation, "idle_" + facing)
				assert_false(node.spectral.visible)
				assert_eq(node.animated_sprite.self_modulate, Color.WHITE)


func test_missing_relocation_never_claims_arrival_and_restores_native_body() -> void:
	var node := backend()
	node.play_action("SE", &"cast", { "spell_id": "cc2_a05" })
	node.advance_simulation(.51)
	assert_false(node.spectral.arrival_confirmed)
	assert_eq(node.spectral.body_alpha, 0.0)
	assert_eq(node.spectral.veil_frame, -1)
	node.advance_simulation(.30)
	assert_eq(node.spectral.native_weight, 1.0)
	assert_false(node.spectral.drawing.visible)
	node.advance_simulation(.20)
	assert_eq(node.get_runtime_state().animation, "idle_SE")
	assert_eq(node.animated_sprite.self_modulate, Color.WHITE)


func test_constant_scale_registered_foot_and_exact_native_endpoints() -> void:
	for factor in [.75, 1.0, 1.4]:
		var node := backend(factor)
		node.play_action("SE", &"cast", { "spell_id": "cc2_r05" })
		assert_eq(node.animated_sprite.self_modulate.a, 1.0)
		assert_false(node.spectral.drawing.visible)
		var scale: Vector2 = node.spectral.drawing.scale
		var edge := 0.0
		for i in 12:
			node._show_spectral(edge + .00001)
			var frame: Dictionary = node.spectral.data.frames[i]
			var pivot := Vector2(frame.pivot[0], frame.pivot[1])
			assert_eq(node.spectral.source_frame, i)
			assert_eq(node.spectral.drawing.scale, scale)
			assert_almost_eq(
				node.spectral.drawing.position + pivot * scale,
				Body.SUPPORT * PROFILE.display_scale * factor,
				Vector2(.001, .001),
			)
			edge += float(node.spectral.data.duration_ms[i]) / 1000.0
		assert_almost_eq(
			scale.y * float(node.spectral.data.source_height),
			214.0 * PROFILE.display_scale * factor,
			.001,
		)
		node.spectral.arrival_confirmed = true
		node._show_spectral(.82)
		assert_eq(node.animated_sprite.self_modulate.a, 1.0)
		assert_false(node.spectral.drawing.visible)


func test_cancel_during_absence_restores_visibility_without_late_release() -> void:
	var node := backend()
	watch_signals(node)
	for seconds in [.15, .30, .42]:
		node.play_action("SE", &"cast", { "spell_id": "cc2_r08" })
		node.advance_simulation(seconds)
		node.cancel_action()
		assert_false(node.spectral.visible)
		assert_false(node.spectral.veil.visible)
		assert_eq(node.animated_sprite.self_modulate, Color.WHITE)
		assert_true(node.animated_sprite.visible)
		node.advance_simulation(3.0)
	assert_signal_emit_count(node, "action_release_reached", 1)


func test_hitch_publishes_invisible_release_pose_once_and_finishes() -> void:
	var node := backend()
	var releases: Array = []
	node.action_release_reached.connect(
		func():
			releases.append(node.get_runtime_state()),
	)
	node.play_action("NE", &"cast", { "spell_id": "cc2_r05" })
	node.advance_simulation(2.0)
	assert_eq(releases.size(), 1)
	assert_eq(releases[0].spectral_alpha, 0.0)
	assert_eq(node.get_runtime_state().animation, "idle_NE")
	node.advance_simulation(2.0)
	assert_eq(releases.size(), 1)


func test_next_action_mode_change_death_and_shutdown_remove_the_veil() -> void:
	var node := backend()
	for operation in ["cast", "mode", "death", "shutdown"]:
		node.play_action("SE", &"cast", { "spell_id": "cc2_a05" })
		node.advance_simulation(.25)
		assert_true(node.spectral.veil.visible)
		match operation:
			"cast":
				assert_false(
					node.play_action("SE", &"cast", { "spell_id": "cc2_n05" }),
					"An active cast cannot be replaced",
				)
				node.cancel_action()
				assert_true(node.play_action("SE", &"cast", { "spell_id": "cc2_n05" }))
			"mode":
				node.set_cards_mode(false)
			"death":
				node.play_death("SE")
			"shutdown":
				node.shutdown()
		assert_false(node.spectral.is_visible_in_tree())
		assert_eq(node.animated_sprite.self_modulate, Color.WHITE)
		if operation == "death":
			node = backend()
		else:
			node.cancel_action()
			node.set_cards_mode(true)
