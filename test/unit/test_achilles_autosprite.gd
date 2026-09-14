extends GutTest

const DATA := preload("res://data/units/allies/achilles.tres")
const PROFILE := preload("res://data/visuals/achilles/achilles_autosprite_profile_v1.tres")
const Backend := preload("res://characters/achilles/2d/achilles_autosprite_backend.gd")
const Threshold := preload("res://hub/catabase_threshold/catabase_threshold.gd")


func test_shipped_character_and_threshold_use_all_56_original_sheets() -> void:
	var visual := await _view()
	assert_eq(visual.sprite_profile, PROFILE)
	assert_true(visual.sprite_backend is AchillesAutoSpriteBackend)
	assert_eq(Threshold.profile_for_variants({ }), PROFILE)
	assert_ne(Threshold.profile_for_variants({ "achilles": "painted_g" }), PROFILE)
	var frames := DATA.preview_sprite_frames
	assert_eq(frames, visual.sprite_backend.animated_sprite.sprite_frames)
	assert_eq(PROFILE.validation_error(frames), &"")
	assert_eq(frames.get_animation_names().size(), 112)
	var manifest: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string(
			"res://assets/characters/Achilles/autosprite_v1/manifest.json"
		)
	)
	assert_eq(manifest.sheets.size(), 56)
	for sheet: Dictionary in manifest.sheets:
		var path := "res://assets/characters/Achilles/autosprite_v1/" + str(sheet.file)
		assert_eq(
			FileAccess.get_sha256(path),
			str(sheet.sha256),
			"Source pixels must stay unchanged",
		)
		var image := (load(path) as Texture2D).get_image()
		assert_eq(image.get_size(), Vector2i(1280, 1280))
		assert_eq(image.get_pixel(0, 0).a, 0.0, "The green palette background is transparent")
		var texture := frames.get_frame_texture(
			StringName(str(sheet.stem) + "_" + str(sheet.direction)),
			0,
		) as AtlasTexture
		assert_eq(texture.atlas.resource_path, path)
		assert_true(texture.filter_clip)


func test_grid_axes_project_to_screen_diagonals_and_aim_supports_eight_directions() -> void:
	var visual := await _view()
	var expected := {
		Vector2i(1, 0): "SE",
		Vector2i(0, 1): "SW",
		Vector2i(-1, 0): "NW",
		Vector2i(0, -1): "NE",
		Vector2i(1, 1): "S",
		Vector2i(-1, -1): "N",
		Vector2i(1, -1): "E",
		Vector2i(-1, 1): "W",
	}
	for direction: Vector2i in expected:
		visual.set_facing(direction)
		assert_eq(
			visual.sprite_backend.animated_sprite.animation,
			StringName("idle_" + str(expected[direction])),
		)
		assert_false(visual.sprite_backend.animated_sprite.flip_h)
	var player := SanctuaryPlayer.new()
	add_child_autofree(player)
	for index in 8:
		var direction := Vector2.RIGHT.rotated(index * PI / 4)
		assert_eq(player.face_for_direction(direction), AchillesAutoSpriteProfile.DIRECTIONS[index])


func test_idle_breathes_without_resetting_on_repeated_idle_requests() -> void:
	var visual := await _view()
	var backend := visual.sprite_backend
	var sprite := backend.animated_sprite
	backend.advance_simulation(0.8)
	assert_eq(sprite.frame, 10)
	var transform := sprite.transform
	for index in 10:
		visual.play_idle()
	assert_eq(sprite.frame, 10)
	backend.advance_simulation(1.2)
	assert_eq(sprite.frame, 0)
	assert_eq(sprite.transform, transform)
	assert_eq(visual.position, Vector2.ZERO)


func test_running_uses_native_sheet_and_stride_survives_turn_and_pause() -> void:
	var visual := await _view()
	var backend := visual.sprite_backend
	var path: Array = []
	for index in 7:
		path.append(Vector2i(index, 0))
	visual.begin_path_movement_feedback(path)
	visual.update_movement_stride(0, 0.5)
	assert_eq(backend.animated_sprite.animation, &"run_SE")
	var frame := backend.animated_sprite.frame
	var phase := backend.animated_sprite.frame_progress
	backend.advance_simulation(0.8)
	assert_eq(backend.animated_sprite.frame, frame, "Stationary tween cannot advance the stride")
	visual.set_facing(Vector2i.DOWN)
	assert_eq(backend.animated_sprite.animation, &"run_SW")
	assert_eq(backend.animated_sprite.frame, frame)
	assert_almost_eq(backend.animated_sprite.frame_progress, phase, 0.001)
	visual.cancel_movement_feedback()
	visual.update_movement_stride(2, 0.7)
	assert_eq(backend.animated_sprite.animation, &"idle_SW")
	visual.begin_movement_feedback(Vector2i.ZERO, Vector2i.RIGHT)
	assert_eq(backend.animated_sprite.animation, &"walk_SE")


func test_every_action_releases_once_on_authored_pose_in_all_directions() -> void:
	var backend := await _backend()
	watch_signals(backend)
	var releases := 0
	for direction: String in AchillesAutoSpriteProfile.DIRECTIONS:
		for stem: String in [
			"attack",
			"sweep",
			"hook",
			"bow",
			"bow_piercing",
			"bow_death",
			"volley",
			"guard",
		]:
			var settings := PROFILE.get_action_clip_settings(stem)
			assert_true(backend.play_action(direction, &"cast", { "animation_stem": stem }))
			backend.advance_simulation(float(settings.release_seconds) - 0.001)
			assert_signal_emit_count(backend, "action_release_reached", releases)
			backend.advance_simulation(0.001)
			releases += 1
			assert_eq(backend.animated_sprite.frame, int(settings.release_frame))
			assert_signal_emit_count(backend, "action_release_reached", releases)
			backend.advance_simulation(2.0)
			assert_signal_emit_count(backend, "action_release_reached", releases)
			assert_signal_emit_count(backend, "action_finished", releases)
			assert_eq(backend.animated_sprite.animation, StringName("idle_" + direction))


func test_crochet_routes_to_supplied_gesture_without_modifying_spell_presentation() -> void:
	var backend := await _backend()
	for id: String in ["exp_crochet", "exp_crochet_mutation", "exp_crochet_legend"]:
		var presentation := { "spell_id": id, "animation_stem": &"attack" }
		backend.play_action("NE", &"cast", presentation)
		assert_eq(backend.animated_sprite.animation, &"hook_NE")
		assert_eq(presentation.animation_stem, &"attack")
		backend.advance_simulation(2.0)


func test_reentrant_cancel_dash_arrival_and_death_do_not_emit_extra_markers() -> void:
	var backend := await _backend()
	watch_signals(backend)
	var cancel := func() -> void:
		backend.cancel_action()
	backend.action_release_reached.connect(cancel, CONNECT_ONE_SHOT)
	backend.play_action("NE", &"cast", { "animation_stem": "attack" })
	backend.advance_simulation(3.0)
	assert_signal_emit_count(backend, "action_release_reached", 1)
	assert_signal_not_emitted(backend, "action_finished")
	backend.play_action("SW", &"cast", { "animation_stem": "dash" })
	backend.advance_simulation(0.2)
	assert_eq(backend.animated_sprite.animation, &"run_SW")
	backend.cancel_action()
	assert_true(backend.finish_dash_landing("SW"))
	backend.advance_simulation(0.1)
	assert_eq(backend.animated_sprite.animation, &"idle_SW")
	assert_true(backend.play_hit("S"))
	backend.advance_simulation(0.3)
	assert_true(backend.play_death("S"))
	backend.advance_simulation(1.0)
	assert_false(backend.play_idle())
	assert_signal_emit_count(backend, "death_pose_finished", 1)
	assert_signal_emit_count(backend, "action_release_reached", 2)


func _view() -> AchillesIsoUnitView:
	var parent := Node2D.new()
	add_child_autofree(parent)
	var visual := DATA.visual_scene.instantiate() as AchillesIsoUnitView
	parent.add_child(visual)
	await wait_process_frames(3)
	visual.set_process(false)
	visual.sprite_backend.set_process(false)
	visual.sprite_backend._idle_elapsed = 0.0
	return visual


func _backend() -> AchillesSprite2DBackend:
	return (await _view()).sprite_backend
