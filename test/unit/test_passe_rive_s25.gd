extends GutTest
const Backend := preload("res://characters/achilles/2d/passe_rive_s19_backend.gd")
const Body := preload("res://characters/achilles/2d/passe_rive_pull_body.gd")
const Tether := preload("res://vfx/class_cards/passe_rive_pull_tether.gd")
const PROFILE := preload("res://data/visuals/achilles/passe_rive_autosprite_profile_v1.tres")
const Spells := preload("res://core/expedition/consumable_card_spells.gd")
const Factory := preload("res://test/support/factory.gd")


func backend() -> Node2D:
	var node := Backend.new()
	add_child_autofree(node)
	assert_true(node.configure(PROFILE))
	node.set_backend_active(true)
	node.set_cards_mode(true)
	node.set_process(false)
	return node


func test_pull_release_owns_traction_pose_and_is_once_even_on_a_hitch() -> void:
	for step in [.4, 2.0]:
		for upgraded in [false, true]:
			var node := backend()
			var releases: Array = []
			node.action_release_reached.connect(
				func():
					releases.append(node.get_runtime_state()),
			)
			var spell := Spells.make_spell("g04", upgraded)
			assert_true(node.play_action("SE", &"cast:cc2_g04", { "spell_id": spell.spell_id }))
			node.advance_simulation(step)
			assert_eq(releases.size(), 1)
			assert_eq(releases[0].animation, Body.CLIP)
			assert_eq(releases[0].frame, 6)
			assert_almost_eq(float(releases[0].release_seconds), .4, .00001)
			node.advance_simulation(2.0)
			assert_eq(releases.size(), 1)
			assert_true(node.animated_sprite.visible and not node.pull.visible)


func test_pull_uses_fixed_scale_support_and_one_silhouette() -> void:
	var node := backend()
	node.play_action("SE", &"cast:cc2_g04", { "spell_id": "cc2_g04" })
	var initial_scale: Vector2 = node.pull.scale
	for second in [0.0, .1, .17, .25, .33, .41, .48, .59, .66, .74, .82]:
		node._show_pull(second)
		var frame: Dictionary = node.pull.data.frames[node.pull.source_frame]
		var pivot := Vector2(frame.pivot[0], frame.pivot[1])
		var support: Vector2 = node.pull.position + pivot * initial_scale
		assert_almost_eq(support, Body.SUPPORT * PROFILE.display_scale, Vector2(.001, .001))
		assert_eq(node.pull.scale, initial_scale)
		assert_false(node.body.visible or node.kick.visible)
		assert_almost_eq(node.animated_sprite.self_modulate.a + node.pull.self_modulate.a, 1.0, .00001)
		assert_true(node.get_vfx_origin().is_equal_approx(node.pull.hand_position()))


func test_cancel_has_no_late_release_and_nw_uses_authored_traction() -> void:
	var node := backend()
	watch_signals(node)
	node.play_action("SE", &"cast:cc2_g04", { "spell_id": "cc2_g04" })
	node.advance_simulation(.32)
	node.cancel_action()
	node.play_idle("SE")
	node.advance_simulation(1.0)
	assert_signal_not_emitted(node, "action_release_reached")
	assert_false(node.pull.visible)
	node.play_action("NW", &"cast:cc2_g04", { "spell_id": "cc2_g04" })
	assert_ne(node.get_runtime_state().gesture_binding.status, "pending_direction")
	assert_eq(node.get_runtime_state().animation, Body.CLIP)
	assert_eq(node.get_runtime_state().authored_direction, "NW")


func test_tether_only_replays_confirmed_movement_and_cancellation_settles_visual() -> void:
	var node := backend()
	var hero := Factory.make_unit("Hero")
	var victim := Factory.make_unit("Victim", 1)
	victim.grid_pos = Vector2i(3, 0)
	var view := Node2D.new()
	add_child_autofree(view)
	view.position = Vector2(300, 0)
	var fx := Tether.new()
	add_child(fx)
	fx.configure(node, hero, victim, view, _cell_world, 100)
	fx.set_process(false)
	node.play_action("SE", &"cast:cc2_g04", { "spell_id": "cc2_g04" })
	node.advance_simulation(.3)
	fx.sample(.3)
	assert_eq(view.position, Vector2(300, 0), "Flight cannot move a victim")
	fx._displacement(victim, Vector2i(3, 0), Vector2i(2, 0), false)
	assert_false(fx.moved, "No movement before body release")
	node.advance_simulation(.1)
	victim.grid_pos = Vector2i(2, 0)
	view.position = Vector2(200, 0)
	fx._displacement(victim, Vector2i(3, 0), Vector2i(2, 0), false)
	fx._resolved(hero, Spells.make_spell("g04"), { "pushed": true, "damaged_enemies": [victim] })
	assert_true(fx.confirmed and fx.moving)
	assert_eq(view.position, Vector2(300, 0))
	fx.sample(.5)
	assert_gt(view.position.x, 200.0)
	assert_lt(view.position.x, 300.0)
	assert_eq(victim.grid_pos, Vector2i(2, 0), "VFX never alters final logical cell")
	assert_eq(victim.current_hp, 100, "VFX never deals damage")
	fx.cancel()
	assert_eq(view.position, Vector2(200, 0), "Cancel settles an already committed translation")
	await get_tree().process_frame


func test_missing_hit_does_not_pull_and_a_later_movement_keeps_ownership() -> void:
	var node := backend()
	var hero := Factory.make_unit("Hero")
	var victim := Factory.make_unit("Victim", 1)
	var view := Node2D.new()
	add_child_autofree(view)
	view.position = Vector2(300, 0)
	var fx := Tether.new()
	add_child(fx)
	fx.configure(node, hero, victim, view, _cell_world, 100)
	fx.set_process(false)
	node.play_action("SE", &"cast:cc2_g04", { "spell_id": "cc2_g04" })
	node.advance_simulation(.4)
	fx._resolved(hero, Spells.make_spell("g04"), { "damaged_enemies": [] })
	fx.sample(.5)
	assert_false(fx.moving)
	assert_true(fx.closed, "A miss has no contact accent")
	assert_eq(view.position, Vector2(300, 0))
	await get_tree().process_frame
	fx = Tether.new()
	add_child(fx)
	fx.configure(node, hero, victim, view, _cell_world, 100)
	fx.set_process(false)
	victim.grid_pos = Vector2i(2, 0)
	fx._displacement(victim, Vector2i(3, 0), Vector2i(2, 0), false)
	fx._resolved(hero, Spells.make_spell("g04"), { "pushed": true })
	view.position = Vector2(500, 0)
	fx.sample(.55)
	assert_false(fx.moving)
	fx.cancel()
	assert_eq(view.position, Vector2(500, 0), "Do not overwrite a later movement")
	await get_tree().process_frame


func _cell_world(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * 100, cell.y * 50)
