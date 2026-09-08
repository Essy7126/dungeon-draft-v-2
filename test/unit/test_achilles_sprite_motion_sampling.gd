extends GutTest

const BACKEND := preload("res://characters/achilles/2d/achilles_sprite_2d_backend.gd")
const PROFILE := preload("res://data/visuals/achilles/achilles_kit_sprite_profile_v2.tres")


func test_distance_stride_honors_authored_contact_weights_and_cell_boundaries() -> void:
	var backend := await _create_backend()
	var sprite := backend.animated_sprite
	var original := sprite.transform
	var original_offset := sprite.offset
	_set_walk_weights(sprite.sprite_frames, "E", [1.0, 1.0, 1.0, 3.0, 1.0, 1.0, 1.0, 3.0])
	assert_true(backend.play_move("E"))
	backend.update_movement_stride(0, 0.5)
	assert_eq(sprite.frame, 3, "The first contact occupies the last half of the real cell step")
	assert_almost_eq(sprite.frame_progress, 0.0, 0.0001)
	backend.update_movement_stride(0, 0.75)
	assert_eq(sprite.frame, 3)
	assert_almost_eq(sprite.frame_progress, 0.5, 0.0001)
	backend.update_movement_stride(0, 1.0)
	assert_eq(sprite.frame, 3, "An exact arrival cannot start the opposite lifted foot")
	assert_almost_eq(sprite.frame_progress, 1.0, 0.0001)
	backend.advance_simulation(2.0)
	assert_eq(sprite.frame, 3, "A paused cell tween holds the planted drawing")
	backend.update_movement_stride(1, 0.0)
	assert_eq(sprite.frame, 4)
	backend.update_movement_stride(1, 1.5)
	assert_eq(sprite.frame, 7)
	assert_eq(sprite.transform, original)
	assert_eq(sprite.offset, original_offset)
	assert_false(sprite.is_playing())


func test_turn_preserves_distance_phase_when_direction_drawings_have_other_weights() -> void:
	var backend := await _create_backend()
	var sprite := backend.animated_sprite
	_set_walk_weights(sprite.sprite_frames, "E", [1.0, 1.0, 1.0, 3.0, 1.0, 1.0, 1.0, 3.0])
	_set_walk_weights(sprite.sprite_frames, "S", [3.0, 1.0, 1.0, 1.0, 3.0, 1.0, 1.0, 1.0])
	assert_true(backend.play_move("E"))
	backend.update_movement_stride(0, 0.5)
	assert_eq(sprite.frame, 3)
	backend.set_facing_label("S")
	assert_eq(sprite.animation, &"walk_S")
	assert_eq(sprite.frame, 1, "The same physical half-step selects its matching directional pose")
	assert_almost_eq(sprite.frame_progress, 0.0, 0.0001)
	assert_almost_eq(float(backend.get_runtime_state().walk_step_progress), 0.5, 0.0001)
	backend.set_facing_label("E")
	assert_eq(sprite.frame, 3)
	backend.play_move("E")
	assert_eq(sprite.frame, 3, "Repeated movement feedback cannot restart the stride")
	backend.play_idle("E")
	backend.update_movement_stride(1, 0.75)
	assert_eq(sprite.animation, &"idle_E", "Late tween samples cannot revive a stopped walk")


func test_free_walk_uses_profile_cell_duration_even_with_twelve_authored_drawings() -> void:
	var backend := await _create_backend()
	var sprite := backend.animated_sprite
	var weights: Array[float] = []
	weights.resize(12)
	weights.fill(1.0)
	_set_walk_weights(sprite.sprite_frames, "E", weights)
	# Source preview FPS does not control production locomotion.
	sprite.sprite_frames.set_animation_speed(&"walk_E", 99.0)
	assert_true(backend.play_move("E"))
	backend.advance_simulation(PROFILE.walk_segment_duration_seconds * 0.5)
	assert_eq(sprite.frame, 3)
	backend.advance_simulation(PROFILE.walk_segment_duration_seconds * 0.5)
	assert_eq(sprite.frame, 6, "One physical cell is one half-cycle regardless of source FPS")
	backend.advance_simulation(PROFILE.walk_segment_duration_seconds)
	assert_eq(sprite.frame, 0)
	assert_true(backend.play_idle("E"))
	assert_true(backend.play_move("E", true))
	backend.advance_simulation(PROFILE.run_segment_duration_seconds - 0.0001)
	assert_eq(sprite.frame, 5, "The next step cannot be selected early to hide clock quantization")
	backend.advance_simulation(0.0001)
	assert_eq(sprite.frame, 6, "Running preserves the same contacts at its own cell duration")
	assert_almost_eq(sprite.frame_progress, 0.0, 0.000001)
	backend.advance_simulation(PROFILE.run_segment_duration_seconds)
	assert_eq(sprite.frame, 0, "The second running step wraps exactly without a one-frame hitch")
	assert_almost_eq(sprite.frame_progress, 0.0, 0.000001)


func test_distance_stride_supports_six_drawings_per_step_without_dropping_arrival() -> void:
	var backend := await _create_backend()
	var sprite := backend.animated_sprite
	var weights: Array[float] = []
	weights.resize(12)
	weights.fill(1.0)
	_set_walk_weights(sprite.sprite_frames, "W", weights)
	assert_true(backend.play_move("W"))
	for step in 2:
		backend.update_movement_stride(step, 0.5)
		assert_eq(sprite.frame, step * 6 + 3)
		backend.update_movement_stride(step, 1.0)
		assert_eq(sprite.frame, step * 6 + 5)
		backend.advance_simulation(0.5)
		assert_eq(sprite.frame, step * 6 + 5)



func test_extended_bow_markers_publish_authored_release_pose_once_in_all_directions() -> void:
	var profile := _extended_bow_profile()
	var backend := await _create_backend(profile)
	var sprite := backend.animated_sprite
	var counts := {"release": 0, "finish": 0}
	backend.action_release_reached.connect(func() -> void: counts.release += 1)
	backend.action_finished.connect(func(_action: StringName) -> void: counts.finish += 1)
	var initial := sprite.transform
	for direction: String in ["N", "E", "S", "W"]:
		for stem: String in ["bow", "bow_piercing", "bow_death", "volley"]:
			var before: int = counts.release
			var settings := profile.get_action_clip_settings(stem)
			assert_true(backend.play_action(direction, &"cast:achilles_pelion_shot", {"animation_stem": stem}))
			assert_eq(sprite.animation, StringName(stem + "_" + direction))
			assert_almost_eq(backend.get_action_watchdog_seconds(&"cast", {"animation_stem": stem}),
				float(settings.duration_seconds) + 0.5, 0.000001)
			backend.advance_simulation(float(settings.release_seconds) - 0.001)
			assert_eq(counts.release, before)
			assert_eq(sprite.frame, 3, "Full draw remains visible immediately before release")
			backend.advance_simulation(0.001)
			assert_eq(sprite.frame, 4, "Arrow release uses the explicit new drawing index")
			assert_eq(counts.release, before + 1)
			assert_eq(counts.finish, before)
			backend.advance_simulation(float(settings.duration_seconds) - float(settings.release_seconds) + 0.001)
			assert_eq(counts.finish, before + 1)
			assert_eq(sprite.animation, StringName("idle_" + direction))
			backend.advance_simulation(1.0)
			assert_eq(counts.release, before + 1)
			assert_eq(counts.finish, before + 1)
			assert_eq(sprite.transform, initial)
			assert_eq(sprite.position, Vector2.ZERO)
			assert_false(sprite.flip_h)


func test_legacy_kit_falls_back_to_real_bow_for_new_evolutions() -> void:
	var backend := await _create_backend()
	for stem: String in ["bow_piercing", "bow_death"]:
		assert_true(backend.play_action("E", &"cast:achilles_pelion_shot", {"animation_stem": stem}))
		var state := backend.get_runtime_state()
		assert_eq(state.animation, "bow_E", "A legacy archer must never swing a spear for an evolved shot")
		assert_eq(state.release_frame, 3)
		assert_almost_eq(float(state.release_seconds), PROFILE.shot_release_seconds, 0.000001)
		assert_almost_eq(float(state.duration_seconds), PROFILE.shot_duration_seconds, 0.000001)
		backend.advance_simulation(2.0)
	assert_true(backend.play_action("N", &"cast:achilles_fulminant_dash", {"animation_stem": "dash"}))
	backend.advance_simulation(PROFILE.advance_release_seconds + 0.48)
	assert_eq(backend.animated_sprite.animation, &"dash_N")
	assert_eq(backend.animated_sprite.frame, 2, "New bow settings do not change the appreciated airborne charge")


func test_arrow_origin_uses_actual_gesture_and_release_callback_can_cancel_cleanly() -> void:
	var profile := _extended_bow_profile()
	profile.action_clip_settings["bow_piercing"]["cast_origins"] = {"E": Vector2(43.0, -51.0)}
	profile.action_clip_settings["bow_death"]["cast_origins"] = {"E": Vector2(37.0, -56.0)}
	var backend := await _create_backend(profile)
	var observed := {"release": 0, "finish": 0, "origin": Vector2.ZERO, "frame": -1}
	backend.action_finished.connect(func(_action: StringName) -> void: observed.finish += 1)
	backend.action_release_reached.connect(func() -> void:
		observed.release += 1
		observed.origin = backend.get_vfx_origin()
		observed.frame = backend.animated_sprite.frame
		backend.cancel_action()
		backend.play_idle("E")
	, CONNECT_ONE_SHOT)
	assert_true(backend.play_action("E", &"cast", {"animation_stem": "bow_piercing"}))
	backend.advance_simulation(3.0)
	assert_eq(observed.release, 1)
	assert_eq(observed.finish, 0)
	assert_eq(observed.frame, 4, "Even a slow frame presents the real release pose before observers run")
	assert_eq(observed.origin, Vector2(43.0, -51.0))
	assert_eq(backend.animated_sprite.animation, &"idle_E")
	assert_eq(backend.get_vfx_origin(), profile.cast_origins.E, "An old shot cannot change idle/default origins")
	assert_true(backend.play_action("E", &"cast", {"animation_stem": "bow_death"}))
	assert_eq(backend.get_vfx_origin(), Vector2(37.0, -56.0))
	backend.advance_simulation(3.0)
	assert_eq(observed.finish, 1)


func test_profile_rejects_missing_direction_and_invalid_new_action_contracts() -> void:
	var profile := _extended_bow_profile()
	assert_eq(profile.validation_error(profile.frames), &"")
	var settings := profile.get_action_clip_settings("bow")
	settings.release_frame = 100
	assert_eq(profile.action_clip_settings.bow.release_frame, 4, "Reading metadata never mutates the shared profile")
	var bad_settings: Array[Dictionary] = [
		{"frame_count": 8, "duration_seconds": 0.74, "release_seconds": 0.34, "release_frame": 8},
		{"frame_count": 8, "duration_seconds": 0.74, "release_seconds": 0.74, "release_frame": 4},
		{"frame_count": 8.5, "duration_seconds": 0.74, "release_seconds": 0.34, "release_frame": 4},
		{"frame_count": 8, "duration_seconds": 0.74, "release_seconds": 0.34, "release_frame": 4.5},
		{"frame_count": 8, "duration_seconds": 0.74, "release_seconds": 0.34, "release_frame": 4, "cast_origins": {"E": Vector2(INF, 0.0)}},
	]
	for bad: Dictionary in bad_settings:
		var invalid := profile.duplicate() as AchillesSpriteVisualProfile
		invalid.action_clip_settings = profile.action_clip_settings.duplicate(true)
		invalid.action_clip_settings.bow = bad
		assert_eq(invalid.validation_error(invalid.frames), &"SPRITE_ACTION_SETTINGS_INVALID")
	profile.frames.remove_animation(&"bow_death_W")
	assert_eq(profile.validation_error(profile.frames), &"SPRITE_DIRECTION_CLIP_MISSING")
	var legacy := _profile_copy()
	legacy.action_clip_settings = {"dash": profile.action_clip_settings.bow.duplicate(true)}
	assert_eq(legacy.validation_error(legacy.frames), &"SPRITE_ACTION_SETTINGS_INVALID",
		"Dash arrival remains Battle-owned rather than using an independent clip timer")
	legacy.action_clip_settings = {}
	legacy.frames.remove_frame(&"walk_E", 0)
	assert_eq(legacy.validation_error(legacy.frames), &"SPRITE_WALK_CYCLE_INVALID")


func _extended_bow_profile() -> AchillesSpriteVisualProfile:
	var profile := _profile_copy()
	for stem: String in ["bow", "bow_piercing", "bow_death", "volley"]:
		profile.action_clip_settings[stem] = {
			"frame_count": 8, "duration_seconds": 0.74, "release_seconds": 0.34, "release_frame": 4,
		}
		for direction: String in ["N", "E", "S", "W"]:
			var clip := StringName(stem + "_" + direction)
			var source := StringName("bow_" + direction)
			var texture := profile.frames.get_frame_texture(source, 0)
			if profile.frames.has_animation(clip):
				profile.frames.clear(clip)
			else:
				profile.frames.add_animation(clip)
			profile.frames.set_animation_loop(clip, false)
			profile.frames.set_animation_speed(clip, 8.0 / 0.74)
			for weight: float in [0.5, 1.0, 1.0, 2.0, 0.5, 0.75, 1.0, 0.5]:
				profile.frames.add_frame(clip, texture, weight)
	return profile


func _profile_copy() -> AchillesSpriteVisualProfile:
	var profile := PROFILE.duplicate() as AchillesSpriteVisualProfile
	var source := load(profile.sprite_frames_path) as SpriteFrames
	profile.frames = source.duplicate() as SpriteFrames
	profile.action_clip_settings = {}
	return profile


func _create_backend(profile: AchillesSpriteVisualProfile = null) -> AchillesSprite2DBackend:
	var backend := BACKEND.new() as AchillesSprite2DBackend
	add_child_autofree(backend)
	await wait_process_frames(1)
	if profile == null:
		profile = _profile_copy()
	assert_true(backend.configure(profile))
	backend.set_backend_active(true)
	backend.set_process(false)
	return backend


func _set_walk_weights(frames: SpriteFrames, direction: String, weights: Array) -> void:
	var clip := StringName("walk_" + direction)
	var texture := frames.get_frame_texture(clip, 0)
	frames.clear(clip)
	for weight: float in weights:
		frames.add_frame(clip, texture, weight)
