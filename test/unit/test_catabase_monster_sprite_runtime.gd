extends GutTest

const IDS := ["sentinelle_airain", "rejeton_braise", "molosse_styx", "lamie_lethe"]
const DIRECTIONS := ["N", "E", "S", "W"]
const PROFILE_ROOT := "res://data/visuals/catabase_monsters/"


func after_each() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0


func test_four_profiles_use_distinct_gaits_and_keep_fixed_ground_anchor() -> void:
	var expected := {"sentinelle_airain": 0.5, "rejeton_braise": 0.5,
		"molosse_styx": 1.0, "lamie_lethe": 0.65}
	for id: String in IDS:
		var view := _create_view(id)
		var sprite := view.animated_sprite
		var parent := view.get_parent() as Node2D
		var owner_transform := parent.transform
		var sprite_transform := sprite.transform
		assert_eq(view.find_children("*", "AnimatedSprite2D", true, false).size(), 1)
		assert_eq(view.find_children("*", "SubViewport", true, false).size(), 0)
		assert_eq(view.sprite_profile.stride_cycles_per_cell, expected[id])
		for direction: String in DIRECTIONS:
			view.set_facing_label(direction)
			assert_true(view.play_idle())
			view.advance_simulation(10.0)
			assert_eq(sprite.animation, StringName("idle_" + direction))
			assert_eq(sprite.frame, 0)
			assert_false(sprite.is_playing())
			assert_false(sprite.flip_h)
			assert_false(sprite.flip_v)
			assert_eq(sprite.transform, sprite_transform)
			assert_eq(parent.transform, owner_transform)
			assert_eq(sprite.transform * (sprite.offset + view.sprite_profile.foot_anchor), Vector2.ZERO)


func test_stride_follows_distance_and_remains_continuous_between_cells_and_turns() -> void:
	for id: String in IDS:
		var view := _create_view(id)
		view.begin_movement_feedback(Vector2i.ZERO, Vector2i.RIGHT)
		view.update_movement_stride(0, 0.6)
		var phase := float(view.get_visual_runtime_state().movement_phase)
		var frame := view.animated_sprite.frame
		view.advance_simulation(8.0)
		assert_eq(view.animated_sprite.frame, frame, "No sliding gait on a stationary root: " + id)
		view.begin_movement_feedback(Vector2i.RIGHT, Vector2i(2, 0))
		assert_eq(float(view.get_visual_runtime_state().movement_phase), phase)
		view.update_movement_stride(0, 1.0)
		var boundary_frame := view.animated_sprite.frame
		var boundary_progress := view.animated_sprite.frame_progress
		view.update_movement_stride(1, 0.0)
		assert_eq(view.animated_sprite.frame, boundary_frame)
		assert_almost_eq(view.animated_sprite.frame_progress, boundary_progress, 0.0001)
		view.set_facing_label("N")
		assert_eq(view.animated_sprite.animation, &"walk_N")
		assert_eq(view.animated_sprite.frame, boundary_frame)
		view.end_movement_feedback()
		view.update_movement_stride(1, 0.8)
		assert_eq(view.animated_sprite.animation, &"idle_N")


func test_external_motion_and_teleport_sync_keep_root_and_pose_consistent() -> void:
	var view := _create_view()
	var parent := view.get_parent() as Node2D
	parent.position += Vector2(32, 0)
	view.advance_simulation(0.05)
	assert_eq(view.animated_sprite.animation, &"walk_S")
	assert_gt(view.animated_sprite.frame, 0)
	view.advance_simulation(0.1)
	assert_eq(view.animated_sprite.animation, &"idle_S")
	parent.position += Vector2(700, -200)
	view.synchronize_external_movement()
	view.advance_simulation(1.0)
	assert_eq(view.animated_sprite.animation, &"idle_S")
	assert_eq(view.animated_sprite.to_global(view.animated_sprite.offset + view.sprite_profile.foot_anchor),
		parent.global_position)


func test_primary_spells_and_specials_have_distinct_poses_and_once_only_signals() -> void:
	for id: String in IDS:
		var view := _create_view(id)
		var events := _watch_actions(view)
		var primary := Spell.new()
		primary.spell_id = view.sprite_profile.primary_spell_ids[0]
		var special := Spell.new()
		special.spell_id = &"test_special"
		for direction: String in DIRECTIONS:
			for spell: Spell in [primary, special]:
				var stem := "attack" if spell == primary else "cast"
				var before_release := int(events.releases)
				var before_finish := int(events.finishes)
				view.set_facing_label(direction)
				assert_true(view.play_spell_action(spell))
				assert_eq(view.animated_sprite.animation, StringName(stem + "_" + direction))
				assert_false(view.play_idle())
				assert_false(view.play_cast())
				assert_false(view.play_hit())
				var duration := view.sprite_profile.duration_for(stem)
				view.advance_simulation(duration * 0.5 - 0.001)
				assert_eq(events.releases, before_release)
				view.advance_simulation(0.001)
				assert_eq(events.releases, before_release + 1)
				assert_eq(events.release_frame, 2)
				view.advance_simulation(duration * 0.5 + 0.001)
				assert_eq(events.finishes, before_finish + 1)
				assert_eq(events.finished_id, StringName("cast:" + String(spell.spell_id)))
				view.advance_simulation(10.0)
				assert_eq(events.releases, before_release + 1)
				assert_eq(events.finishes, before_finish + 1)


func test_large_delta_still_shows_release_pose_before_completion() -> void:
	var view := _create_view()
	var events := _watch_actions(view)
	assert_true(view.play_basic_attack())
	view.advance_simulation(20.0)
	assert_eq(events.release_frame, 2)
	assert_eq(events.order, ["release", "finish"])
	assert_eq(events.finished_id, &"attack")


func test_weighted_pose_duration_keeps_impact_at_authored_release_frame() -> void:
	var view := _create_view()
	view.sprite_profile.frames.set_frame(&"cast_S", 0,
		view.sprite_profile.frames.get_frame_texture(&"cast_S", 0), 3.0)
	var events := _watch_actions(view)
	assert_true(view.play_cast())
	var release_time := view.sprite_profile.duration_for("cast") * 4.0 / 6.0
	view.advance_simulation(release_time - 0.001)
	assert_eq(events.releases, 0)
	view.advance_simulation(0.001)
	assert_eq(events.releases, 1)
	assert_eq(events.release_frame, 2)


func test_cancel_before_release_does_not_leak_into_next_action() -> void:
	var view := _create_view()
	var events := _watch_actions(view)
	assert_true(view.play_cast())
	view.advance_simulation(0.1)
	view.cancel_pending_visual_actions()
	view.advance_simulation(3.0)
	assert_eq(events.order, [])
	assert_true(view.play_cast())
	view.advance_simulation(3.0)
	assert_eq(events.order, ["release", "finish"])


func test_release_callback_can_cancel_and_start_another_action_without_stale_finish() -> void:
	var view := _create_view()
	var events := _watch_actions(view)
	view.cast_release_reached.connect(func() -> void:
		view.cancel_pending_visual_actions()
		view.play_basic_attack()
	, CONNECT_ONE_SHOT)
	assert_true(view.play_cast())
	view.advance_simulation(3.0)
	assert_eq(events.releases, 1)
	assert_eq(events.finishes, 0)
	assert_eq(view.animated_sprite.animation, &"attack_S")
	assert_eq(view.animated_sprite.frame, 0)
	view.advance_simulation(3.0)
	assert_eq(events.releases, 2)
	assert_eq(events.finishes, 1)
	assert_eq(events.finished_id, &"attack")


func test_release_callback_queue_free_suppresses_stale_completion() -> void:
	var view := _create_view()
	var events := _watch_actions(view)
	view.cast_release_reached.connect(view.queue_free, CONNECT_ONE_SHOT)
	assert_true(view.play_cast())
	view.advance_simulation(3.0)
	assert_eq(events.releases, 1)
	assert_eq(events.finishes, 0)


func test_reorientation_waits_for_recovery_and_never_mirrors() -> void:
	var view := _create_view()
	view.set_facing_label("E")
	assert_true(view.play_cast())
	view.set_facing_label("W")
	view.advance_simulation(0.1)
	assert_eq(view.animated_sprite.animation, &"cast_E")
	view.advance_simulation(2.0)
	assert_eq(view.animated_sprite.animation, &"idle_W")
	assert_false(view.animated_sprite.flip_h)


func test_hit_displays_authored_pose_without_resetting_repeated_damage() -> void:
	var view := _create_view()
	var events := _watch_actions(view)
	for direction: String in DIRECTIONS:
		view.set_facing_label(direction)
		assert_true(view.play_hit())
		assert_false(view.play_idle())
		assert_false(view.play_hit())
		view.advance_simulation(0.19)
		assert_eq(view.animated_sprite.animation, StringName("hit_" + direction))
		view.advance_simulation(0.02)
		assert_eq(view.animated_sprite.animation, StringName("idle_" + direction))
	assert_eq(events.order, [])


func test_damage_events_only_react_on_bound_living_target_and_disconnect_on_rebind() -> void:
	var view := _create_view()
	var unit := Unit.from_data(UnitData.new())
	var other := Unit.from_data(UnitData.new())
	view.bind_unit(unit)
	EventBus.hit_resolved.emit(CombatEventFact.create(&"hit_resolved", other, null, {"amount_resolved": 8}))
	assert_eq(view.animated_sprite.animation, &"idle_S")
	EventBus.hit_resolved.emit(CombatEventFact.create(&"hit_resolved", unit, null, {"amount_resolved": 8}))
	assert_eq(view.animated_sprite.animation, &"hit_S")
	view.bind_unit(other)
	unit.died.emit(unit)
	assert_false(view.get_visual_runtime_state().dead)
	other.died.emit(other)
	assert_true(view.get_visual_runtime_state().dead)


func test_death_displays_all_four_authored_poses_before_fading_and_finishes_once() -> void:
	var view := _create_view()
	var events := _watch_actions(view)
	var death := {"count": 0}
	view.death_animation_finished.connect(func() -> void: death.count += 1)
	var root_transform := view.transform
	assert_true(view.play_cast())
	assert_true(view.play_death())
	assert_false(view.play_death())
	view.cancel_pending_visual_actions()
	var pose_duration := view.sprite_profile.death_duration_seconds / 4.0
	for index in 4:
		assert_eq(view.animated_sprite.animation, &"death_S")
		assert_eq(view.animated_sprite.frame, index)
		assert_eq(view.modulate.a, 1.0)
		assert_eq(death.count, 0)
		view.advance_simulation(pose_duration)
	assert_eq(view.modulate.a, 1.0)
	view.advance_simulation(view.sprite_profile.death_fade_seconds * 0.5)
	assert_gt(view.modulate.a, 0.0)
	assert_lt(view.modulate.a, 1.0)
	view.advance_simulation(3.0)
	assert_eq(death.count, 1)
	assert_eq(events.order, [])
	assert_false(view.visible)
	assert_false(view.play_cast())
	assert_eq(view.transform, root_transform)
	view.advance_simulation(3.0)
	assert_eq(death.count, 1)


func test_rebind_after_death_clears_dead_pose_and_pending_action() -> void:
	var view := _create_view()
	view.play_cast()
	view.play_death()
	view.advance_simulation(3.0)
	view.bind_unit(Unit.from_data(UnitData.new()))
	assert_true(view.visible)
	assert_eq(view.modulate.a, 1.0)
	assert_eq(view.animated_sprite.animation, &"idle_S")
	assert_true(view.play_cast())


func test_profile_rejects_incomplete_directions_looping_death_and_invalid_marker() -> void:
	var profile := _profile(IDS[0])
	assert_eq(profile.validation_error(profile.frames), &"")
	profile.frames.remove_animation(&"cast_N")
	assert_eq(profile.validation_error(profile.frames), &"SPRITE_DIRECTION_CLIP_MISSING")
	profile = _profile(IDS[0])
	profile.frames.set_animation_loop(&"death_S", true)
	assert_eq(profile.validation_error(profile.frames), &"SPRITE_CLIP_LOOP_INVALID")
	profile = _profile(IDS[0])
	profile.release_frame = 4
	assert_eq(profile.validation_error(profile.frames), &"SPRITE_RELEASE_MARKER_INVALID")


func test_pause_and_zero_time_scale_do_not_consume_wall_time_on_resume() -> void:
	var view := _create_view()
	var events := _watch_actions(view)
	view.set_process(true)
	assert_true(view.play_cast())
	get_tree().paused = true
	await get_tree().create_timer(0.3, true, false, true).timeout
	var paused_frame := view.animated_sprite.frame
	var paused_releases := int(events.releases)
	get_tree().paused = false
	assert_eq(paused_frame, 0)
	assert_eq(paused_releases, 0)
	Engine.time_scale = 0.0
	await get_tree().create_timer(0.3, true, false, true).timeout
	assert_eq(view.animated_sprite.frame, 0)
	assert_eq(events.releases, 0)
	Engine.time_scale = 1.0
	await wait_process_frames(1)
	assert_eq(events.releases, 0)
	var deadline := Time.get_ticks_msec() + 2000
	while int(events.finishes) < 1 and Time.get_ticks_msec() < deadline:
		await wait_process_frames(1)
	assert_eq(events.releases, 1)
	assert_eq(events.finishes, 1)


func _create_view(id := "sentinelle_airain") -> CatabaseMonsterIsoUnitView:
	var parent := Node2D.new()
	parent.position = Vector2(161, 215)
	add_child_autofree(parent)
	var view := CatabaseMonsterIsoUnitView.new()
	view.sprite_profile = _profile(id)
	parent.add_child(view)
	view.set_process(false)
	return view


func _profile(id: String) -> CatabaseMonsterSpriteProfile:
	var profile := (load(PROFILE_ROOT + id + "_sprite_profile.tres") as CatabaseMonsterSpriteProfile).duplicate() \
		as CatabaseMonsterSpriteProfile
	profile.frames = SpriteFrames.new()
	profile.frames.remove_animation(&"default")
	for direction: String in DIRECTIONS:
		for stem: String in CatabaseMonsterSpriteProfile.CLIP_COUNTS:
			var clip := StringName(stem + "_" + direction)
			profile.frames.add_animation(clip)
			profile.frames.set_animation_loop(clip, stem in ["idle", "walk"])
			profile.frames.set_animation_speed(clip, 8.0)
			for index in CatabaseMonsterSpriteProfile.CLIP_COUNTS[stem]:
				var texture := GradientTexture2D.new()
				texture.width = 512
				texture.height = 384
				texture.gradient = Gradient.new()
				texture.gradient.colors = PackedColorArray([Color(float(index) / 6.0, 0.4, 0.7), Color.WHITE])
				profile.frames.add_frame(clip, texture)
	return profile


func _watch_actions(view: CatabaseMonsterIsoUnitView) -> Dictionary:
	var events := {"releases": 0, "finishes": 0, "release_frame": -1, "order": [], "finished_id": &""}
	view.cast_release_reached.connect(func() -> void:
		events.releases += 1
		events.release_frame = view.animated_sprite.frame
		events.order.append("release")
	)
	view.animation_finished.connect(func(action_id: StringName) -> void:
		events.finishes += 1
		events.finished_id = action_id
		events.order.append("finish")
	)
	return events
