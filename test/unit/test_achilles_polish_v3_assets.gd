extends GutTest

const CANONICAL := preload("res://data/units/allies/achilles.tres")
const PROFILE_PATH := "res://data/visuals/achilles/achilles_polish_sprite_profile_v3.tres"
const FRAMES_PATH := "res://assets/characters/Achilles/sprites_polish_v3/achilles_sprite_frames.tres"
const LEGACY_FRAMES_PATH := "res://assets/characters/Achilles/sprites_kit_v2/achilles_sprite_frames.tres"
const MANIFEST_PATH := "res://assets/characters/Achilles/sprites_polish_v3/manifest.json"
const DIRECTIONS := {"N": Vector2i.UP, "E": Vector2i.RIGHT, "S": Vector2i.DOWN, "W": Vector2i.LEFT}
const NEW_STEMS := ["walk", "bow", "bow_piercing", "bow_death", "volley"]
const PRESERVED_STEMS := ["idle", "attack", "dash", "guard", "sweep", "hit", "death"]
const SHOT := preload("res://data/spells/achilles/pelion_shot.tres")


func test_actual_classic_scene_selects_complete_v3_profile_and_sprite_resources() -> void:
	var visual := await _classic_view()
	assert_eq(visual.scene_file_path, "res://characters/achilles/AchillesIsoUnitView.tscn")
	assert_eq(visual.sprite_profile.resource_path, PROFILE_PATH)
	assert_eq(visual.sprite_profile.profile_id, &"achilles_polish_sprites_v3")
	assert_eq(visual.sprite_profile.sprite_frames_path, FRAMES_PATH)
	var frames := visual.sprite_backend.animated_sprite.sprite_frames
	assert_eq(frames.resource_path, FRAMES_PATH)
	assert_eq(visual.sprite_profile.validation_error(frames), &"")
	assert_eq(frames.get_animation_names().size(), 48)
	assert_eq(visual.find_children("*", "AnimatedSprite2D", true, false).size(), 1)
	assert_eq(visual.find_children("*", "Node3D", true, false).size(), 0)
	assert_eq(visual.find_children("*", "SubViewport", true, false).size(), 0)
	assert_eq(visual.sprite_profile.frame_canvas_size, Vector2i(512, 384))
	assert_eq(visual.sprite_profile.foot_anchor, Vector2(256, 320))
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	assert_true(bool(manifest.get("complete", false)), "Actual build must be complete; no pending or fallback clips")
	assert_eq(int(manifest.get("clip_count", 0)), 48)
	assert_eq((manifest.get("missing_clips", []) as Array).size(), 0)
	assert_eq((manifest.get("sheets", []) as Array).size(), 20)


func test_twenty_eight_preserved_clips_keep_exact_v2_textures_and_timing() -> void:
	var frames := load(FRAMES_PATH) as SpriteFrames
	var legacy := load(LEGACY_FRAMES_PATH) as SpriteFrames
	assert_not_null(frames)
	assert_not_null(legacy)
	if frames == null or legacy == null:
		return
	var expected: Array[String] = []
	for stem: String in PRESERVED_STEMS:
		for direction: String in DIRECTIONS:
			var clip := StringName(stem + "_" + direction)
			expected.append(str(clip))
			assert_true(frames.has_animation(clip), str(clip))
			assert_eq(frames.get_frame_count(clip), legacy.get_frame_count(clip), str(clip))
			assert_eq(frames.get_animation_loop(clip), legacy.get_animation_loop(clip), str(clip))
			assert_eq(frames.get_animation_speed(clip), legacy.get_animation_speed(clip), str(clip))
			for frame in legacy.get_frame_count(clip):
				assert_eq(frames.get_frame_duration(clip, frame), legacy.get_frame_duration(clip, frame), str(clip))
				var actual := frames.get_frame_texture(clip, frame) as AtlasTexture
				var old := legacy.get_frame_texture(clip, frame) as AtlasTexture
				assert_not_null(actual)
				assert_not_null(old)
				if actual != null and old != null:
					assert_eq(actual.atlas.resource_path, old.atlas.resource_path, "Same source pixels: " + str(clip))
					assert_eq(actual.region, old.region, str(clip))
					assert_eq(actual.margin, old.margin, str(clip))
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	var preserved: Array = manifest.get("legacy", {}).get("preserved_clips", [])
	expected.sort()
	preserved.sort()
	assert_eq(preserved, expected, "Manifest must match the independently expected 28 preserved clips")


func test_new_actual_drawings_are_transparent_complete_and_specialist_release_is_distinct() -> void:
	var frames := load(FRAMES_PATH) as SpriteFrames
	assert_not_null(frames)
	if frames == null:
		return
	var cache: Dictionary = {}
	var release_drawings: Dictionary = {}
	for direction: String in DIRECTIONS:
		for stem: String in NEW_STEMS:
			var clip := StringName(stem + "_" + direction)
			assert_true(frames.has_animation(clip), str(clip))
			if not frames.has_animation(clip):
				continue
			assert_eq(frames.get_frame_count(clip), 8, str(clip))
			assert_eq(frames.get_animation_loop(clip), stem == "walk", str(clip))
			var content_hashes: Dictionary = {}
			for index in frames.get_frame_count(clip):
				var texture := frames.get_frame_texture(clip, index) as AtlasTexture
				assert_not_null(texture, "%s:%d" % [clip, index])
				if texture == null:
					continue
				assert_eq(texture.get_size(), Vector2(512, 384))
				assert_true(texture.atlas.resource_path.begins_with("res://assets/characters/Achilles/sprites_polish_v3/"))
				var signature := "%s:%s" % [texture.atlas.resource_path, texture.region]
				if not cache.has(signature):
					var image := texture.get_image()
					assert_not_null(image)
					if image == null:
						continue
					if image.is_compressed():
						assert_eq(image.decompress(), OK)
					var used := image.get_used_rect()
					assert_gt(used.size.y, 150, "A full authored character is present: " + signature)
					assert_gt(used.position.x, 0, "No left clipping: " + signature)
					assert_gt(used.position.y, 0, "No top clipping: " + signature)
					assert_lt(used.end.x, 512, "No right clipping: " + signature)
					assert_lt(used.end.y, 384, "No bottom clipping: " + signature)
					assert_eq(image.get_pixel(0, 0).a, 0.0)
					assert_eq(image.get_pixel(511, 383).a, 0.0)
					cache[signature] = hash(image.get_data())
				content_hashes[cache[signature]] = true
				if index == 4 and stem != "walk":
					release_drawings[str(clip)] = cache[signature]
			assert_gte(content_hashes.size(), 6 if stem == "walk" else 4,
				"Real distinct images, not renamed aliases: " + str(clip))
		var unique_releases: Dictionary = {}
		for stem: String in ["bow", "bow_piercing", "bow_death", "volley"]:
			var key := stem + "_" + direction
			assert_true(release_drawings.has(key), key)
			if release_drawings.has(key):
				unique_releases[release_drawings[key]] = true
		assert_eq(unique_releases.size(), 4, "Each bow specialization has its own actual release drawing: " + direction)


func test_promoted_scene_plays_real_specialized_release_frames_once_in_every_direction() -> void:
	var visual := await _classic_view()
	var counts := {"releases": 0, "finishes": 0}
	visual.cast_release_reached.connect(func() -> void: counts.releases += 1)
	visual.animation_finished.connect(func(_clip: StringName) -> void: counts.finishes += 1)
	var original_parent := (visual.get_parent() as Node2D).transform
	var sprite := visual.sprite_backend.animated_sprite
	var original_sprite := sprite.transform
	var contracts := [
		{"stem": "bow", "duration": 0.74, "release": 0.34, "profile": {}},
		{"stem": "bow_piercing", "duration": 0.78, "release": 0.38,
			"profile": {"target_shape": &"LINE", "piercing_enabled": true, "maximum_targets": 2}},
		{"stem": "bow_death", "duration": 0.86, "release": 0.44,
			"profile": {"target_shape": &"LINE", "piercing_enabled": true, "maximum_targets": 3}},
		{"stem": "volley", "duration": 0.84, "release": 0.42,
			"profile": {"target_shape": &"FAN", "maximum_targets": 3}},
	]
	for direction: String in DIRECTIONS:
		for contract: Dictionary in contracts:
			var before: int = counts.releases
			visual.set_facing(DIRECTIONS[direction])
			assert_true(visual.play_spell_action(SHOT, contract.profile))
			var actual := visual.sprite_backend.get_runtime_state()
			assert_eq(actual.animation, "%s_%s" % [contract.stem, direction])
			assert_eq(actual.release_frame, 4)
			assert_almost_eq(float(actual.duration_seconds), float(contract.duration), 0.000001)
			assert_almost_eq(float(actual.release_seconds), float(contract.release), 0.000001)
			visual.sprite_backend.advance_simulation(float(contract.release) - 0.001)
			assert_eq(counts.releases, before)
			assert_eq(sprite.frame, 3, "The actual full-draw pose remains visible immediately before release")
			visual.sprite_backend.advance_simulation(0.001)
			assert_eq(counts.releases, before + 1)
			assert_eq(counts.finishes, before)
			assert_eq(sprite.frame, 4)
			assert_true(visual.get_default_cast_effect_origin().is_finite())
			visual.sprite_backend.advance_simulation(float(contract.duration) - float(contract.release) + 0.001)
			assert_eq(counts.finishes, before + 1)
			assert_eq(sprite.animation, StringName("idle_" + direction))
			assert_eq(sprite.frame, 0)
			assert_false(sprite.is_playing())
			assert_false(sprite.flip_h)
			assert_eq(sprite.transform, original_sprite)
			assert_eq((visual.get_parent() as Node2D).transform, original_parent)
			visual.sprite_backend.advance_simulation(0.5)
			assert_eq(counts.releases, before + 1)
			assert_eq(counts.finishes, before + 1)


func test_promoted_walk_has_actual_plant_drawings_and_distance_owns_arrival() -> void:
	var visual := await _classic_view()
	var sprite := visual.sprite_backend.animated_sprite
	var original := sprite.transform
	for direction: String in DIRECTIONS:
		visual.set_facing(DIRECTIONS[direction])
		visual.play_idle()
		var idle_bottom := _opaque_bottom(sprite.sprite_frames.get_frame_texture(sprite.animation, 0))
		visual.begin_path_movement_feedback([Vector2i.ZERO, DIRECTIONS[direction], DIRECTIONS[direction] * 2])
		for step in 2:
			visual.update_movement_stride(step, 1.0)
			assert_eq(sprite.frame, step * 4 + 3)
			assert_almost_eq(sprite.frame_progress, 1.0, 0.000001)
			assert_almost_eq(float(_opaque_bottom(sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame))),
				float(idle_bottom), 3.0, "Drawn ground contact before an idle transition")
			visual.sprite_backend.advance_simulation(0.5)
			assert_eq(sprite.frame, step * 4 + 3, "A stationary tween cannot move the feet")
			assert_eq(sprite.transform, original)
		visual.cancel_movement_feedback()
		assert_eq(sprite.animation, StringName("idle_" + direction))
		assert_eq(sprite.frame, 0)
		assert_false(sprite.is_playing())
		visual.update_movement_stride(2, 0.5)
		assert_eq(sprite.animation, StringName("idle_" + direction), "A late distance callback cannot restart the walk")


func _opaque_bottom(texture: Texture2D) -> int:
	var image := texture.get_image()
	if image.is_compressed():
		image.decompress()
	for y in range(image.get_height() - 1, -1, -1):
		for x in image.get_width():
			if image.get_pixel(x, y).a > 0.13:
				return y + 1
	return -1


func _classic_view() -> AchillesIsoUnitView:
	# Instantiate the actual shipped UnitData scene without replacing its profile.
	var owner := Node2D.new()
	owner.position = Vector2(143, 207)
	add_child_autofree(owner)
	var visual := CANONICAL.visual_scene.instantiate() as AchillesIsoUnitView
	owner.add_child(visual)
	await wait_process_frames(3)
	visual.set_process(false)
	visual.sprite_backend.set_process(false)
	return visual
