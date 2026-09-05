extends GutTest

const DATA_PATH := "res://data/units/enemies/spectre_greatsword.tres"
const FRAMES_PATH := "res://assets/characters/spectre_greatsword/sprites_v1/spectre_sprite_frames.tres"
const CANVAS := Vector2i(512, 384)


func test_canonical_data_and_preview_share_the_production_sprites() -> void:
	var data := load(DATA_PATH) as UnitData
	assert_not_null(data)
	if data == null:
		return
	assert_not_null(data.visual_scene)
	assert_eq(data.visual_scene.resource_path,
		"res://characters/enemies/spectre_greatsword/SpectreGreatswordIsoUnitView.tscn")
	assert_not_null(data.preview_sprite_frames)
	if data.preview_sprite_frames != null:
		assert_true(data.preview_sprite_frames.has_animation(data.preview_sprite_animation))
		var portrait := data.preview_sprite_frames.get_frame_texture(data.preview_sprite_animation, 0) as AtlasTexture
		var frames := load(FRAMES_PATH) as SpriteFrames
		assert_not_null(portrait, "Portrait crops an authored game atlas")
		if portrait != null and frames != null:
			var canonical := frames.get_frame_texture(data.preview_sprite_animation, 0) as AtlasTexture
			assert_not_null(canonical)
			if canonical != null:
				assert_eq(portrait.atlas.resource_path, canonical.atlas.resource_path,
					"Portrait and combat must use the same generated model")
	assert_true(data.preview_sprite_animation in [&"idle_N", &"idle_E", &"idle_S", &"idle_W"])


func test_four_directions_have_real_transparent_frames_without_edge_clipping() -> void:
	var frames := load(FRAMES_PATH) as SpriteFrames
	assert_not_null(frames)
	if frames == null:
		return
	var expected_counts := {"idle": 1, "walk": 4, "attack": 8}
	for direction: String in ["N", "E", "S", "W"]:
		for action: String in expected_counts:
			var animation := StringName("%s_%s" % [action, direction])
			assert_true(frames.has_animation(animation))
			if not frames.has_animation(animation):
				continue
			assert_eq(frames.get_frame_count(animation), expected_counts[action])
			assert_gt(frames.get_animation_speed(animation), 0.0)
			if action == "attack":
				assert_false(frames.get_animation_loop(animation))
			var distinct: Dictionary = {}
			for index in frames.get_frame_count(animation):
				var texture := frames.get_frame_texture(animation, index)
				assert_not_null(texture)
				if texture == null:
					continue
				assert_eq(Vector2i(texture.get_size()), CANVAS)
				var pixels := texture.get_image()
				assert_not_null(pixels)
				if pixels == null:
					continue
				if pixels.is_compressed():
					assert_eq(pixels.decompress(), OK)
				var used := pixels.get_used_rect()
				assert_gt(used.size.y, 100, "Visible spectre: %s/%d" % [animation, index])
				assert_gt(used.position.x, 0, "Left cut: %s/%d" % [animation, index])
				assert_gt(used.position.y, 0, "Top cut: %s/%d" % [animation, index])
				assert_lt(used.end.x, CANVAS.x, "Right cut: %s/%d" % [animation, index])
				assert_lt(used.end.y, CANVAS.y, "Bottom cut: %s/%d" % [animation, index])
				assert_almost_eq(pixels.get_pixel(0, 0).a, 0.0, 0.001)
				assert_almost_eq(pixels.get_pixel(CANVAS.x - 1, CANVAS.y - 1).a, 0.0, 0.001)
				distinct[hash(pixels.get_data())] = true
			assert_gte(distinct.size(), 1 if action == "idle" else (4 if action == "walk" else 6),
				"Enough distinct authored poses; neutral attack endpoints may repeat: %s" % animation)
