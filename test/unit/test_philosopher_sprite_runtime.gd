extends GutTest

const SCENE_PATH := "res://characters/philosopher_mage/PhilosopherMageIsoUnitView.tscn"
const UNIT_PATH := "res://data/units/enemies/philosopher_mage.tres"
const DIRECTIONS := {"N": Vector2i.UP, "E": Vector2i.RIGHT, "S": Vector2i.DOWN, "W": Vector2i.LEFT}
const SPELLS := {
	"philosopher_axiom": {"stem": "attack", "duration": 0.64},
	"philosopher_refutation": {"stem": "control", "duration": 0.72},
	"philosopher_mending": {"stem": "heal", "duration": 0.80},
	"philosopher_aporia": {"stem": "control", "duration": 0.72},
	"philosopher_aegis": {"stem": "shield", "duration": 0.64},
}


func test_canonical_visual_has_complete_directional_sprite_kit_and_fixed_pivot() -> void:
	var view := await _create_view()
	var sprite := _sprite(view)
	var profile := view.get("sprite_profile") as PhilosopherSpriteVisualProfile
	assert_eq(profile.validation_error(sprite.sprite_frames), &"")
	assert_eq(view.find_children("*", "AnimatedSprite2D", true, false).size(), 1)
	assert_eq(view.find_children("*", "SubViewport", true, false).size(), 0)
	assert_eq(view.find_children("*", "Node3D", true, false).size(), 0)
	assert_eq(profile.frame_canvas_size, Vector2i(512, 384))
	assert_eq(profile.foot_anchor, Vector2(256, 320))
	assert_almost_eq(_ground_anchor(view).length(), 0.0, 0.001)
	assert_false(sprite.flip_h)
	assert_false(sprite.flip_v)
	for direction: String in DIRECTIONS:
		for stem: String in ["idle", "walk", "attack", "heal", "control", "shield", "hit", "death"]:
			var clip := StringName(stem + "_" + direction)
			assert_true(sprite.sprite_frames.has_animation(clip), str(clip))
			for index in sprite.sprite_frames.get_frame_count(clip):
				var texture := sprite.sprite_frames.get_frame_texture(clip, index)
				assert_eq(texture.get_size(), Vector2(512, 384))
				var picture := texture.get_image()
				assert_not_null(picture)
				if picture == null:
					continue
				if picture.is_compressed():
					picture.decompress()
				assert_ne(picture.get_used_rect().size, Vector2i.ZERO, "Every authored pose is visible")
				assert_eq(picture.get_pixel(0, 0).a, 0.0)
				assert_eq(picture.get_pixel(511, 383).a, 0.0)


func test_idle_cannot_drift_when_requested_repeatedly_or_after_large_delta() -> void:
	var view := await _create_view()
	var sprite := _sprite(view)
	var original_owner := (view.get_parent() as Node2D).transform
	var original_sprite := sprite.transform
	for direction: String in DIRECTIONS:
		view.set_facing(DIRECTIONS[direction])
		for _sample in 20:
			assert_true(view.play_idle())
			view.advance_simulation(0.5)
			assert_eq(sprite.animation, StringName("idle_" + direction))
			assert_eq(sprite.frame, 0)
			assert_false(sprite.is_playing())
			assert_eq(sprite.transform, original_sprite)
			assert_eq((view.get_parent() as Node2D).transform, original_owner)
			assert_almost_eq(_ground_anchor(view).length(), 0.0, 0.001)


func test_walk_is_distance_driven_and_preserves_phase_between_cells_and_turns() -> void:
	var view := await _create_view()
	var sprite := _sprite(view)
	view.begin_movement_feedback(Vector2i.ZERO, Vector2i.RIGHT)
	view.update_movement_stride(0, 0.8)
	var phase := float(view.get_visual_runtime_state().movement_phase)
	var frame := sprite.frame
	var progress := sprite.frame_progress
	view.advance_simulation(2.0)
	assert_eq(sprite.frame, frame, "Standing at an unchanged tween position cannot advance feet")
	assert_almost_eq(sprite.frame_progress, progress, 0.001)
	view.begin_movement_feedback(Vector2i.RIGHT, Vector2i(2, 0))
	assert_almost_eq(float(view.get_visual_runtime_state().movement_phase), phase, 0.001)
	view.update_movement_stride(0, 1.0)
	var boundary_frame := sprite.frame
	var boundary_progress := sprite.frame_progress
	view.update_movement_stride(1, 0.0)
	assert_eq(sprite.frame, boundary_frame, "Odd frame counts remain continuous at cell boundaries")
	assert_almost_eq(sprite.frame_progress, boundary_progress, 0.001)
	view.set_facing(Vector2i.DOWN)
	assert_eq(sprite.animation, &"walk_S")
	assert_eq(sprite.frame, boundary_frame)
	view.update_movement_stride(1, 0.9)
	assert_ne(sprite.frame, boundary_frame)
	assert_almost_eq(_ground_anchor(view).length(), 0.0, 0.001)
	view.cancel_movement_feedback()
	view.update_movement_stride(9, 0.9)
	view.advance_simulation(2.0)
	assert_eq(sprite.animation, &"idle_S")
	assert_eq(sprite.frame, 0)


func test_all_five_real_spells_release_and_finish_once_in_four_directions() -> void:
	var view := await _create_view()
	var events := _watch_actions(view)
	var sprite := _sprite(view)
	var initial_transform := sprite.transform
	for direction: String in DIRECTIONS:
		for id: String in SPELLS:
			view.set_facing(DIRECTIONS[direction])
			var spell := load("res://data/spells/enemies/%s.tres" % id) as Spell
			assert_not_null(spell)
			var spec: Dictionary = SPELLS[id]
			var duration := float(spec.duration)
			var releases := int(events.releases)
			var finishes := int(events.finishes)
			assert_true(view.play_spell_action(spell))
			assert_eq(sprite.animation, StringName("%s_%s" % [spec.stem, direction]))
			assert_false(view.play_idle())
			assert_false(view.play_cast())
			assert_false(view.play_hit(), "Damage feedback never interrupts a committed spell")
			view.advance_simulation(duration * 0.5 - 0.001)
			assert_eq(events.releases, releases)
			view.advance_simulation(0.001)
			assert_eq(events.releases, releases + 1)
			assert_eq(events.release_frame, 2)
			assert_eq(events.finishes, finishes)
			view.advance_simulation(duration * 0.5 + 0.001)
			assert_eq(events.finishes, finishes + 1)
			assert_eq(sprite.animation, StringName("idle_" + direction))
			assert_eq(sprite.frame, 0)
			assert_eq(sprite.transform, initial_transform)
			view.advance_simulation(2.0)
			assert_eq(events.releases, releases + 1)
			assert_eq(events.finishes, finishes + 1)


func test_large_delta_samples_release_pose_before_single_completion() -> void:
	var view := await _create_view()
	var events := _watch_actions(view)
	assert_true(view.play_cast())
	view.advance_simulation(4.0)
	assert_eq(events.releases, 1)
	assert_eq(events.release_frame, 2)
	assert_eq(events.finishes, 1)
	assert_eq(events.order, ["release", "finish"])


func test_cancellation_before_release_cannot_leak_into_next_spell() -> void:
	var view := await _create_view()
	var events := _watch_actions(view)
	assert_true(view.play_cast())
	view.advance_simulation(0.15)
	view.cancel_pending_visual_actions()
	view.advance_simulation(1.0)
	assert_eq(events.releases, 0)
	assert_eq(events.finishes, 0)
	assert_true(view.play_cast())
	view.advance_simulation(1.0)
	assert_eq(events.releases, 1)
	assert_eq(events.finishes, 1)


func test_release_callback_cancellation_prevents_stale_finish() -> void:
	var view := await _create_view()
	var events := _watch_actions(view)
	view.cast_release_reached.connect(func() -> void:
		view.cancel_pending_visual_actions()
	, CONNECT_ONE_SHOT)
	assert_true(view.play_cast())
	view.advance_simulation(4.0)
	assert_eq(events.releases, 1)
	assert_eq(events.finishes, 0)
	assert_true(view.play_cast())
	view.advance_simulation(0.65)
	assert_eq(events.releases, 2)
	assert_eq(events.finishes, 1)


func test_reorientation_waits_until_action_recovery_is_complete() -> void:
	var view := await _create_view()
	view.set_facing(Vector2i.RIGHT)
	assert_true(view.play_cast())
	view.advance_simulation(0.15)
	view.set_facing(Vector2i.LEFT)
	assert_eq(_sprite(view).animation, &"attack_E")
	view.advance_simulation(0.5)
	assert_eq(_sprite(view).animation, &"idle_W")
	assert_false(_sprite(view).flip_h)


func test_hit_plays_complete_authored_reaction_without_spell_release() -> void:
	var view := await _create_view()
	var events := _watch_actions(view)
	for direction: String in DIRECTIONS:
		view.set_facing(DIRECTIONS[direction])
		assert_true(view.play_hit())
		assert_false(view.play_idle(), "A new turn cannot cut the short hit reaction")
		assert_false(view.play_hit(), "Multi-hits cannot repeatedly reset the first reaction frame")
		view.advance_simulation(0.239)
		assert_eq(_sprite(view).animation, StringName("hit_" + direction))
		assert_eq(_sprite(view).frame, 3)
		view.advance_simulation(0.001)
		assert_eq(_sprite(view).animation, StringName("idle_" + direction))
		assert_almost_eq(_ground_anchor(view).length(), 0.0, 0.001)
	assert_eq(events.releases, 0)
	assert_eq(events.finishes, 0)


func test_confirmed_hit_fact_reaches_only_its_bound_living_unit() -> void:
	var view := await _create_view()
	var unit := Unit.from_data(load(UNIT_PATH) as UnitData)
	var other := Unit.from_data(load(UNIT_PATH) as UnitData)
	view.bind_unit(unit)
	EventBus.hit_resolved.emit(CombatEventFact.create(&"hit_resolved", other, null, {"amount_resolved": 8}))
	assert_false(view.get_visual_runtime_state().reaction_pending)
	EventBus.hit_resolved.emit(CombatEventFact.create(&"hit_resolved", unit, null, {"amount_resolved": 0}))
	assert_false(view.get_visual_runtime_state().reaction_pending)
	EventBus.hit_resolved.emit(CombatEventFact.create(&"hit_resolved", unit, null, {"amount_resolved": 8}))
	assert_true(view.get_visual_runtime_state().reaction_pending)
	assert_eq(_sprite(view).animation, &"hit_S")


func test_death_plays_four_poses_then_fades_once_without_moving_pivot() -> void:
	var view := await _create_view()
	var events := _watch_actions(view)
	var death := {"count": 0}
	view.death_animation_finished.connect(func() -> void: death.count += 1)
	var initial := view.transform
	assert_true(view.play_cast())
	view.advance_simulation(0.1)
	assert_true(view.play_death())
	assert_false(view.play_death())
	view.cancel_pending_visual_actions()
	view.advance_simulation(0.519)
	assert_eq(_sprite(view).animation, &"death_S")
	assert_eq(_sprite(view).frame, 3)
	assert_eq(death.count, 0)
	assert_almost_eq(view.modulate.a, 1.0, 0.001)
	view.advance_simulation(0.061)
	assert_gt(view.modulate.a, 0.0)
	assert_lt(view.modulate.a, 1.0)
	view.advance_simulation(0.061)
	assert_eq(death.count, 1)
	assert_false(view.visible)
	assert_eq(view.transform, initial)
	assert_almost_eq(_ground_anchor(view).length(), 0.0, 0.001)
	assert_eq(events.releases, 0)
	assert_eq(events.finishes, 0)
	assert_false(view.play_cast())
	view.advance_simulation(5.0)
	assert_eq(death.count, 1)


func test_spell_semantic_fallbacks_keep_new_authored_kits_usable() -> void:
	var view := await _create_view()
	var spell := Spell.new()
	assert_eq(view.get_spell_animation_stem(spell), "attack")
	spell.heal = 5
	assert_eq(view.get_spell_animation_stem(spell), "heal")
	spell.heal = 0
	spell.shield_grant = 6
	assert_eq(view.get_spell_animation_stem(spell), "shield")
	spell.shield_grant = 0
	spell.push_distance = 2
	assert_eq(view.get_spell_animation_stem(spell), "control")


func test_profile_rejects_missing_direction_or_looping_combat_action() -> void:
	var view := await _create_view()
	var profile := view.get("sprite_profile") as PhilosopherSpriteVisualProfile
	var frames := _sprite(view).sprite_frames.duplicate() as SpriteFrames
	frames.remove_animation(&"heal_N")
	assert_eq(profile.validation_error(frames), &"SPRITE_DIRECTION_CLIP_MISSING")
	frames = _sprite(view).sprite_frames.duplicate() as SpriteFrames
	frames.set_animation_loop(&"attack_E", true)
	assert_eq(profile.validation_error(frames), &"SPRITE_CLIP_LOOP_INVALID")


func test_wall_clock_pause_does_not_skip_anticipation_on_resume() -> void:
	var view := await _create_view()
	var events := _watch_actions(view)
	view.set_process(true)
	assert_true(view.play_cast())
	get_tree().paused = true
	await get_tree().create_timer(0.40, true, false, true).timeout
	var paused_frame := _sprite(view).frame
	var paused_releases := int(events.releases)
	get_tree().paused = false
	assert_eq(paused_frame, 0)
	assert_eq(paused_releases, 0)
	await wait_process_frames(1)
	assert_eq(events.releases, 0)
	var deadline := Time.get_ticks_msec() + 1800
	while int(events.finishes) < 1 and Time.get_ticks_msec() < deadline:
		await wait_process_frames(1)
	assert_eq(events.releases, 1)
	assert_eq(events.finishes, 1)


func _create_view() -> Node2D:
	var parent := Node2D.new()
	parent.position = Vector2(161, 215)
	add_child_autofree(parent)
	var scene := load(SCENE_PATH) as PackedScene
	var view := scene.instantiate() as Node2D
	parent.add_child(view)
	await wait_process_frames(2)
	view.set_process(false)
	return view


func _sprite(view: Node) -> AnimatedSprite2D:
	return view.get("animated_sprite") as AnimatedSprite2D


func _ground_anchor(view: Node) -> Vector2:
	var sprite := _sprite(view)
	var profile := view.get("sprite_profile") as PhilosopherSpriteVisualProfile
	return sprite.transform * (sprite.offset + profile.foot_anchor)


func _watch_actions(view: Node) -> Dictionary:
	var events := {"releases": 0, "finishes": 0, "release_frame": -1, "order": []}
	view.cast_release_reached.connect(func() -> void:
		events.releases += 1
		events.release_frame = _sprite(view).frame
		events.order.append("release")
	)
	view.animation_finished.connect(func(_clip: StringName) -> void:
		events.finishes += 1
		events.order.append("finish")
	)
	return events


func test_courtyard_presentation_applies_mage_scale_like_achilles_without_moving_feet() -> void:
	var presentation := load("res://data/arenas/greek_drawn_courtyard_v1/presentation.tres") as BattlePresentationProfile
	var mage_data := load(UNIT_PATH) as UnitData
	var hero_data := load("res://data/units/allies/achilles.tres") as UnitData
	var unit_view_script := load("res://battle/unit_view.gd") as Script
	var mage_view := unit_view_script.new() as Node2D
	var hero_view := unit_view_script.new() as Node2D
	add_child_autofree(mage_view)
	add_child_autofree(hero_view)
	mage_view.position = Vector2(185, 226)
	hero_view.position = Vector2(257, 260)
	mage_view.setup(Unit.from_data(mage_data), false)
	hero_view.setup(Unit.from_data(hero_data), false)
	mage_view.apply_painted_presentation(presentation)
	hero_view.apply_painted_presentation(presentation)
	await wait_process_frames(2)
	var mage_scale := float(mage_view.get_painted_visual_scale())
	var hero_scale := float(hero_view.get_painted_visual_scale())
	assert_gt(mage_scale, 1.4, "A missing family profile must not leave the mage at scale 1.0.")
	assert_gte(mage_scale / hero_scale, 0.9)
	assert_lte(mage_scale / hero_scale, 1.1)
	assert_not_null(presentation.profile_for_unit(&"philosopher_mage"))
	var mage_visual := mage_view.get_optional_visual() as Node2D
	var sprite := mage_visual.get("animated_sprite") as AnimatedSprite2D
	var sprite_profile := mage_visual.get("sprite_profile") as PhilosopherSpriteVisualProfile
	assert_almost_eq(mage_visual.scale.x, mage_scale, 0.001)
	assert_almost_eq(mage_visual.scale.y, mage_scale, 0.001)
	assert_almost_eq(sprite.to_global(sprite.offset + sprite_profile.foot_anchor),
		mage_view.global_position, Vector2(0.001, 0.001),
		"Applying the map scale preserves the authored ground pivot.")
	mage_view.apply_painted_presentation(presentation)
	assert_almost_eq(mage_visual.scale.x, mage_scale, 0.001,
		"Repeated presentation binding cannot accumulate the scale multiplier.")


func test_painted_room_without_family_uses_visual_default_and_preserves_pivot() -> void:
	var view := _create_bound_unit_view()
	var room := BattlePresentationProfile.new()
	room.global_unit_scale_multiplier = 1.1
	assert_null(room.profile_for_unit(&"philosopher_mage"))
	view.apply_painted_presentation(room)
	var visual := view.get_optional_visual() as Node2D
	var fallback := visual.get_painted_visual_profile() as UnitVisualProfile
	assert_eq(view.get("_painted_family_profile"), fallback)
	assert_almost_eq(float(view.get_painted_visual_scale()), 1.58 * 1.1, 0.001)
	assert_almost_eq(visual.scale, Vector2.ONE * 1.58 * 1.1, Vector2(0.001, 0.001))
	var sprite := _sprite(visual)
	var profile := visual.get("sprite_profile") as PhilosopherSpriteVisualProfile
	assert_almost_eq(sprite.to_global(sprite.offset + profile.foot_anchor),
		view.global_position, Vector2(0.001, 0.001))
	view.apply_painted_presentation(room)
	assert_almost_eq(visual.scale.x, 1.58 * 1.1, 0.001)
	view.apply_painted_presentation(room, false)
	assert_eq(visual.scale, Vector2.ONE, "Explicit scale opt-out remains authoritative")
	view.apply_painted_presentation(null)
	assert_eq(visual.scale, Vector2.ONE, "The fallback only applies to painted presentations")


func test_explicit_room_family_overrides_visual_default_including_shadow_metadata() -> void:
	var view := _create_bound_unit_view()
	var room := BattlePresentationProfile.new()
	var family := UnitVisualProfile.new()
	family.unit_ids.assign([&"philosopher_mage"])
	family.base_visual_scale = 1.73
	family.minimum_visual_scale = 1.0
	family.maximum_visual_scale = 2.0
	family.contact_shadow_scale = 0.7
	family.contact_shadow_opacity = 0.22
	room.unit_profiles.assign([family])
	view.apply_painted_presentation(room)
	assert_eq(view.get("_painted_family_profile"), family)
	assert_almost_eq(float(view.get_painted_visual_scale()), 1.73, 0.001)
	assert_almost_eq((view.get_optional_visual() as Node2D).scale.x, 1.73, 0.001)
	assert_eq((view.get("_painted_family_profile") as UnitVisualProfile).contact_shadow_scale, 0.7)
	assert_eq((view.get("_painted_family_profile") as UnitVisualProfile).contact_shadow_opacity, 0.22)


func test_external_teleport_sync_cannot_be_mistaken_for_walking_or_shift_the_feet() -> void:
	var view := _create_bound_unit_view()
	var visual := view.get_optional_visual() as Node2D
	visual.set_process(false)
	view.begin_movement_feedback(Vector2i(1, 2), Vector2i(2, 2))
	view.update_movement_stride(0, 1.0)
	view.position += Vector2(704, -160)
	view.synchronize_external_movement()
	view.end_movement_feedback()
	visual.advance_simulation(0.5)
	assert_eq(_sprite(visual).animation, &"idle_E")
	assert_eq(_sprite(visual).frame, 0)
	assert_false(bool(visual.get_visual_runtime_state().movement_active))
	var sprite := _sprite(visual)
	var profile := visual.get("sprite_profile") as PhilosopherSpriteVisualProfile
	assert_almost_eq(sprite.to_global(sprite.offset + profile.foot_anchor),
		view.global_position, Vector2(0.001, 0.001))
	view.begin_movement_feedback(Vector2i(7, 1), Vector2i(7, 2))
	view.update_movement_stride(0, 0.6)
	assert_eq(sprite.animation, &"walk_S")
	assert_gt(sprite.frame, 0, "The next real movement still receives the authored walk")
	var frame := sprite.frame
	visual.advance_simulation(0.3)
	assert_eq(sprite.frame, frame, "The resumed stride remains distance-driven")


func _create_bound_unit_view() -> Node2D:
	var script := load("res://battle/unit_view.gd") as Script
	var view := script.new() as Node2D
	add_child_autofree(view)
	view.position = Vector2(185, 226)
	view.setup(Unit.from_data(load(UNIT_PATH) as UnitData), false)
	return view
