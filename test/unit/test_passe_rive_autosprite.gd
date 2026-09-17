extends GutTest

const PROFILE := preload("res://data/visuals/achilles/passe_rive_autosprite_profile_v1.tres")
const Backend := preload("res://characters/achilles/2d/passe_rive_autosprite_backend.gd")
const VIEW := preload("res://characters/achilles/PasseRiveIsoUnitView.tscn")
const Threshold := preload("res://hub/catabase_threshold/catabase_threshold.gd")
const Halt := preload("res://hub/painted_halt/living_halt.gd")
const Player := preload("res://hub/painted_halt/halt_player.gd")


class SaveManager:
	extends "res://core/game_manager.gd"

	func start_next_battle() -> void:
		pass


	func save_expedition(_path: String = ExpeditionSaveService.SAVE_PATH) -> bool:
		return not get_expedition_snapshot().is_empty()


func test_json_save_restore_keeps_passe_rive_and_its_hud_portrait() -> void:
	var source := SaveManager.new()
	var restored := SaveManager.new()
	for manager in [source, restored]:
		manager.expedition_save_path = "user://passe_rive_%d.json" % manager.get_instance_id()
		manager._ready()
	assert_true(source.start_expedition(731, { "achilles": "passe_rive" }))
	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(source.get_expedition_snapshot()))
	assert_true(restored.restore_expedition_snapshot(snapshot))
	assert_eq(restored.get_active_run_data().hero_visual_variants, { "achilles": "passe_rive" })
	var unit: Unit = restored.get_character_state(&"achilles").unit
	assert_eq(unit.visual_scene, VIEW)
	assert_eq(
		CharacterHUDThemeCatalog.resolve_refined(unit).portrait_texture.resource_path,
		RunHeroVisualVariants.PASSE_RIVE_PORTRAIT_PATH,
	)
	assert_eq(
		RunHeroVisualVariants.exploration_profile(
			restored.get_active_run_data().hero_visual_variants
		),
		PROFILE,
	)
	for manager in [source, restored]:
		manager.cleanup_run_state()
		manager._exit_tree()
		manager.free()


func test_public_selection_and_runtime_variant_preserve_gameplay() -> void:
	var entries := CharacterSelectionCatalog.get_entries()
	var matches := entries.filter(
		func(e: Dictionary) -> bool:
			return e.id == &"achilles_passe_rive",
	)
	assert_eq(matches.size(), 1)
	if matches.is_empty():
		return
	var entry: Dictionary = matches[0]
	assert_eq(entry.run.hero_visual_variants, { "achilles": "passe_rive" })
	assert_eq(entry.unit.get_effective_unit_id(), &"achilles")
	assert_eq(entry.unit.visual_scene, VIEW)
	assert_eq(entry.unit.preview_sprite_frames_path, PROFILE.sprite_frames_path)
	assert_eq(Threshold.profile_for_variants(entry.run.hero_visual_variants), PROFILE)
	var classic := load("res://data/units/allies/achilles.tres") as UnitData
	assert_eq(entry.unit.max_hp, classic.max_hp)
	assert_eq(entry.unit.max_ap, classic.max_ap)
	assert_eq(entry.unit.max_mp, classic.max_mp)


func test_66_original_sheets_transparency_and_complete_clips() -> void:
	var backend := _backend()
	var frames := backend.animated_sprite.sprite_frames
	assert_eq(PROFILE.validation_error(frames), &"")
	assert_eq(frames.get_animation_names().size(), 152)
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Backend.MANIFEST))
	assert_eq(manifest.sheets.size(), 66)
	for sheet: Dictionary in manifest.sheets:
		var path := "res://assets/characters/PasseRive/autosprite_v1/" + str(sheet.file)
		assert_eq(FileAccess.get_sha256(path), str(sheet.sha256))
		var image := (load(path) as Texture2D).get_image()
		assert_eq(image.get_size(), Vector2i(1280, 1280))
		assert_eq(image.get_pixel(0, 0).a, 0.0)
	assert_string_contains(
		(frames.get_frame_texture(&"jump_SW", 7) as AtlasTexture).atlas.resource_path,
		"jump_southwest",
	)
	assert_string_contains(
		(frames.get_frame_texture(&"jump_W", 7) as AtlasTexture).atlas.resource_path,
		"jump_left",
	)
	assert_string_contains(
		(frames.get_frame_texture(&"jump_NE", 7) as AtlasTexture).atlas.resource_path,
		"dodge_northeast",
	)


func test_contact_midpoint_is_at_root_and_jump_keeps_airborne_motion() -> void:
	var backend := _backend()
	for direction: String in PasseRiveAutoSpriteProfile.DIRECTIONS:
		backend.play_idle(direction)
		var sprite := backend.animated_sprite
		var geometry: Dictionary = backend._geometry[String(sprite.animation)]
		var contact := Vector2(geometry.anchor[0], geometry.anchor[1])
		assert_almost_eq(sprite.to_global(contact + sprite.offset).distance_to(
				backend.global_position
			), 0.0, 0.001)
		var transform := sprite.transform
		var offset := sprite.offset
		backend.advance_simulation(0.72)
		assert_gt(sprite.frame, 0)
		assert_eq(sprite.transform, transform)
		assert_eq(sprite.offset, offset)
	backend.play_action("SW", &"cast", { "animation_stem": "sweep" })
	var sprite := backend.animated_sprite
	var grounded := sprite.offset
	backend.advance_simulation(0.30)
	assert_eq(sprite.offset, grounded, "Do not cancel the jump by chasing the lowest pixel")
	assert_eq(backend.position, Vector2.ZERO)
	backend.cancel_action()


func test_different_spell_gestures_release_once_even_on_busy_frames() -> void:
	var backend := _backend()
	watch_signals(backend)
	var count := 0
	for direction: String in PasseRiveAutoSpriteProfile.DIRECTIONS:
		for stem: String in ["bow", "bow_piercing", "bow_death", "volley", "sweep", "guard", "dash"]:
			var presentation := { "animation_stem": stem }
			var chosen := Backend.action_for(&"cast", presentation)
			var settings := PROFILE.get_action_clip_settings(chosen)
			var event_frames: Array[int] = []
			var capture := func() -> void:
				event_frames.append(backend.animated_sprite.frame)
			backend.action_release_reached.connect(capture)
			assert_true(backend.play_action(direction, &"cast", presentation))
			backend.advance_simulation(2.0)
			count += 1
			assert_eq(event_frames, [int(settings.release_frame)])
			assert_signal_emit_count(backend, "action_release_reached", count)
			assert_signal_emit_count(backend, "action_finished", count)
			assert_eq(presentation.animation_stem, stem)
			backend.action_release_reached.disconnect(capture)
	assert_eq(Backend.action_for(&"cast:exp_moisson", { }), "jump")


func test_native_dash_lands_only_on_arrival_and_cancels_cleanly() -> void:
	var backend := _backend()
	watch_signals(backend)
	backend.play_action("NE", &"cast", { "animation_stem": "dash" })
	backend.advance_simulation(0.38)
	assert_eq(backend.animated_sprite.animation, &"dash_NE")
	assert_between(backend.animated_sprite.frame, 2, 13)
	backend.cancel_action()
	assert_true(backend.finish_dash_landing("NE"))
	assert_eq(backend.animated_sprite.frame, 14)
	backend.advance_simulation(0.15)
	assert_between(backend.animated_sprite.frame, 18, 20)
	assert_false(backend.play_idle("NE"))
	backend.advance_simulation(0.16)
	assert_eq(backend.animated_sprite.animation, &"idle_NE")
	assert_signal_emit_count(backend, "action_release_reached", 1)
	assert_signal_emit_count(backend, "action_finished", 0)


func test_shot_returns_restore_original_idle_in_all_directions() -> void:
	var backend := _backend()
	var frames := backend.animated_sprite.sprite_frames
	for direction: String in PasseRiveAutoSpriteProfile.DIRECTIONS:
		backend.play_idle(direction)
		assert_eq(backend.animated_sprite.animation, StringName("idle_" + direction))
		var ready := frames.get_frame_texture(StringName("combat_idle_" + direction), 0)
		for stem: String in ["bow_quick", "bow_charged", "bow_air"]:
			var clip := StringName(stem + "_" + direction)
			assert_eq(frames.get_frame_texture(clip, 0), ready)
			assert_eq(frames.get_frame_texture(clip, frames.get_frame_count(clip) - 1), ready)
			assert_true(backend.play_action(direction, StringName("preview:" + stem)))
			backend.advance_simulation(2.0)
			assert_eq(backend.animated_sprite.animation, StringName("idle_" + direction))
			assert_eq(backend.get_node("ContactShadow").position, Vector2.ZERO)
	assert_eq(backend.animated_sprite.animation, &"idle_NE")


func test_production_view_rests_unarmed_and_keeps_original_idle_alive_after_transitions() -> void:
	var parent := Node2D.new()
	add_child_autofree(parent)
	var visual := VIEW.instantiate() as PasseRiveAutoSpriteView
	parent.add_child(visual)
	await get_tree().process_frame
	await get_tree().process_frame
	visual.set_process(false)
	var backend := visual.sprite_backend as PasseRiveAutoSpriteBackend
	backend.set_process(false)
	assert_true(String(backend.animated_sprite.animation).begins_with("idle_"))
	for direction: String in PasseRiveAutoSpriteProfile.DIRECTIONS:
		visual._facing = direction
		assert_true(visual.play_idle())
		var seen: Dictionary = { }
		for tick in 50:
			# Repeated requests (turn changes, UI refreshes) must not rewind breathing.
			visual.play_idle()
			backend.advance_simulation(0.05)
			seen[backend.animated_sprite.frame] = true
		assert_eq(backend.animated_sprite.animation, StringName("idle_" + direction))
		assert_eq(seen.size(), 25, "All original idle frames must remain reachable: " + direction)
		for stem: String in ["bow", "bow_piercing", "volley", "guard", "sweep", "dash"]:
			assert_true(visual._begin_action(&"cast", { "animation_stem": stem }))
			assert_eq(
				backend.animated_sprite.animation,
				StringName(
					Backend.action_for(&"cast", { "animation_stem": stem }) + "_" + direction
				),
			)
			backend.advance_simulation(2.0)
			assert_false(visual._action_pending)
			assert_eq(backend.animated_sprite.animation, StringName("idle_" + direction))
		for running in [false, true]:
			assert_true(backend.play_move(direction, running))
			backend.advance_ground_distance(100.0)
			assert_true(visual.play_idle())
			assert_eq(backend.animated_sprite.animation, StringName("idle_" + direction))
		assert_true(backend.play_hit(direction))
		backend.advance_simulation(0.6)
		assert_eq(backend.animated_sprite.animation, StringName("idle_" + direction))
		assert_true(backend.play_dodge(direction))
		backend.advance_simulation(0.6)
		assert_eq(backend.animated_sprite.animation, StringName("idle_" + direction))
		assert_true(visual._begin_action(&"cast", { "animation_stem": "volley" }))
		backend.advance_simulation(0.1)
		visual.cancel_pending_visual_actions()
		assert_eq(backend.animated_sprite.animation, StringName("idle_" + direction))
		assert_false(visual._action_pending)


func test_combat_atlases_have_real_alpha_full_airborne_poses_and_keep_native_clips() -> void:
	var backend := _backend()
	var frames := backend.animated_sprite.sprite_frames
	var original := load("res://assets/characters/PasseRive/autosprite_v1/sprite_frames.tres") as SpriteFrames
	for clip: StringName in original.get_animation_names():
		assert_eq(frames.get_frame_count(clip), original.get_frame_count(clip))
		for index in original.get_frame_count(clip):
			var current := frames.get_frame_texture(clip, index) as AtlasTexture
			var source := original.get_frame_texture(clip, index) as AtlasTexture
			assert_eq(current.atlas, source.atlas)
			assert_eq(current.region, source.region)
	for direction: String in PasseRiveAutoSpriteProfile.DIRECTIONS:
		var ready := frames.get_frame_texture(StringName("combat_idle_" + direction), 0).get_image()
		var apex := frames.get_frame_texture(StringName("bow_air_" + direction), 3).get_image()
		assert_ne(ready.detect_alpha(), Image.ALPHA_NONE)
		assert_eq(ready.get_pixel(0, 0).a, 0.0)
		assert_eq(apex.get_pixel(0, 0).a, 0.0)
		assert_lt(apex.get_used_rect().end.y, ready.get_used_rect().end.y - 10)
		assert_lt(
			PROFILE.get_cast_origin("bow_air", direction).y,
			PROFILE.get_cast_origin("bow_quick", direction).y - 20,
		)
		assert_gt(
			PROFILE.get_cast_origin("bow_charged", direction).y,
			PROFILE.get_cast_origin("bow_quick", direction).y,
		)


func test_charged_and_air_cancel_do_not_leak_release_or_completion() -> void:
	var backend := _backend()
	watch_signals(backend)
	for stem: String in ["bow_charged", "bow_air"]:
		backend.play_action("SE", StringName("preview:" + stem))
		backend.advance_simulation(PROFILE.get_action_clip_settings(stem).release_seconds - 0.001)
		backend.cancel_action()
		backend.advance_simulation(3.0)
	assert_signal_emit_count(backend, "action_release_reached", 0)
	assert_signal_emit_count(backend, "action_finished", 0)
	var cancel_at_release := func() -> void:
		backend.cancel_action()
	backend.action_release_reached.connect(cancel_at_release)
	backend.play_action("S", &"preview:bow_air")
	backend.advance_simulation(2.0)
	assert_signal_emit_count(backend, "action_release_reached", 1)
	assert_signal_emit_count(backend, "action_finished", 0)
	backend.action_release_reached.disconnect(cancel_at_release)
	backend.play_idle("S")
	assert_eq(backend.animated_sprite.animation, &"idle_S")


func test_damage_dodge_and_death_have_distinct_sheets_and_finish_once() -> void:
	var backend := _backend()
	watch_signals(backend)
	assert_true(backend.play_hit("NW"))
	backend.advance_simulation(0.2)
	assert_eq(backend.animated_sprite.animation, &"hit_NW")
	backend.advance_simulation(0.3)
	assert_true(backend.play_dodge("NW"))
	backend.advance_simulation(0.2)
	assert_eq(backend.animated_sprite.animation, &"dodge_NW")
	assert_true(backend.play_death("NW"))
	backend.advance_simulation(0.8)
	assert_eq(backend.animated_sprite.animation, &"death_NW")
	assert_signal_emit_count(backend, "death_pose_finished", 0)
	backend.advance_simulation(0.4)
	backend.advance_simulation(0.4)
	assert_signal_emit_count(backend, "death_pose_finished", 1)
	assert_false(backend.play_idle())


func test_combat_walk_run_uses_distance_and_keeps_phase_at_turns() -> void:
	var parent := Node2D.new()
	add_child_autofree(parent)
	var visual := VIEW.instantiate() as PasseRiveAutoSpriteView
	parent.add_child(visual)
	await get_tree().process_frame
	visual.set_process(false)
	visual.sprite_backend.set_process(false)
	assert_true(String(visual.sprite_backend.animated_sprite.animation).begins_with("idle_"))
	visual._last_action_presentation = { "animation_stem": "volley" }
	assert_eq(visual.get_action_presentation().projectile_arc_ratio, 0.65)
	assert_false(visual._last_action_presentation.has("projectile_arc_ratio"), "Keep the shared snapshot intact.")
	visual._last_action_presentation = { "animation_stem": "bow" }
	assert_false(visual.get_action_presentation().has("projectile_arc_ratio"))
	visual.begin_path_movement_feedback([Vector2i.ZERO, Vector2i.RIGHT])
	parent.position = Vector2(20, 10)
	visual.update_movement_stride(0, 0.3)
	assert_eq(visual.sprite_backend.animated_sprite.animation, &"walk_SE")
	var phase := (visual.sprite_backend as PasseRiveAutoSpriteBackend)._ground_phase
	visual.set_facing(Vector2i.DOWN)
	assert_almost_eq(
		(visual.sprite_backend as PasseRiveAutoSpriteBackend)._ground_phase,
		phase,
		0.001,
	)
	var frame := visual.sprite_backend.animated_sprite.frame
	visual.sprite_backend.advance_simulation(1.0)
	assert_eq(visual.sprite_backend.animated_sprite.frame, frame)
	visual.cancel_movement_feedback()
	visual.begin_path_movement_feedback(
		[Vector2i.ZERO, Vector2i.RIGHT, Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0)]
	)
	assert_eq(visual.sprite_backend.animated_sprite.animation, &"run_SE")
	assert_eq(visual.get_movement_segment_duration([Vector2i.ZERO, Vector2i.RIGHT]), 0.72)
	assert_eq(visual.get_movement_segment_duration([0, 1, 2, 3]), 0.36)


func test_exploration_near_click_walks_far_click_runs_without_gait_flicker() -> void:
	var halt := Halt.new()
	halt.definition = { "world": { "speed": 200.0 } }
	var player := Player.new()
	player.sprite_profile = PROFILE
	player.display_scale = 0.5
	halt.player = player
	halt._path = PackedVector2Array([Vector2(80, 0)])
	halt._choose_route_gait()
	assert_false(player.locomotion_running)
	halt._path = PackedVector2Array([Vector2(200, 0)])
	halt._choose_route_gait()
	assert_true(player.locomotion_running)
	assert_eq(halt._route_speed_multiplier, 1.25)
	player.position = Vector2(195, 0)
	assert_true(player.locomotion_running, "Gait remains chosen for the whole click route")
	player.free()
	halt.free()


func _backend() -> PasseRiveAutoSpriteBackend:
	var backend := Backend.new()
	add_child_autofree(backend)
	backend.set_process(false)
	assert_true(backend.configure(PROFILE))
	backend.set_backend_active(true)
	return backend
