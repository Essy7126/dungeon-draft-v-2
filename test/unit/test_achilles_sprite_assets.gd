extends GutTest

const PROFILE_PATH := "res://data/visuals/achilles/achilles_cour_des_sources_sprite_profile_v1.tres"
const FRAMES_PATH := "res://assets/characters/Achilles/sprites_cour_des_sources_v1/achilles_sprite_frames.tres"
const DIRECTIONS := ["N", "E", "S", "W"]


func test_production_frames_cover_three_actions_in_all_four_directions() -> void:
	var frames := load(FRAMES_PATH) as SpriteFrames
	var profile := load(PROFILE_PATH) as Resource
	assert_not_null(frames)
	assert_not_null(profile)
	if frames == null or profile == null:
		return
	var canvas: Vector2i = profile.get("frame_canvas_size")
	var anchor: Vector2 = profile.get("foot_anchor")
	assert_eq(canvas, Vector2i(512, 384))
	assert_eq(anchor, Vector2(256, 320))
	assert_true(Rect2(Vector2.ZERO, Vector2(canvas)).has_point(anchor))
	for direction: String in DIRECTIONS:
		for action: String in ["idle", "walk", "attack"]:
			var animation := StringName("%s_%s" % [action, direction])
			assert_true(frames.has_animation(animation), str(animation))
			if not frames.has_animation(animation):
				continue
			var count := frames.get_frame_count(animation)
			assert_gte(count, 1 if action == "idle" else 2, "Authored frame count: %s" % animation)
			assert_gt(frames.get_animation_speed(animation), 0.0)
			assert_eq(frames.get_animation_loop(animation), action != "attack")
			if action == "attack":
				assert_gte(int(profile.get("attack_release_frame")), 1)
				assert_lt(int(profile.get("attack_release_frame")), count - 1)
			var distinct_frames: Dictionary = {}
			for index in count:
				var texture := frames.get_frame_texture(animation, index)
				assert_not_null(texture, "%s frame %d" % [animation, index])
				if texture == null:
					continue
				assert_eq(Vector2i(texture.get_size()), canvas)
				var image := texture.get_image()
				assert_not_null(image)
				if image == null:
					continue
				if image.is_compressed():
					assert_eq(image.decompress(), OK)
				var used := image.get_used_rect()
				assert_gt(used.size.y, 80, "Visible height: %s/%d" % [animation, index])
				assert_true(used.has_area(), "Empty frame: %s/%d" % [animation, index])
				assert_gt(used.position.x, 0, "Left clipping: %s/%d" % [animation, index])
				assert_gt(used.position.y, 0, "Top clipping: %s/%d" % [animation, index])
				assert_lt(used.end.x, canvas.x, "Right clipping: %s/%d" % [animation, index])
				assert_lt(used.end.y, canvas.y, "Bottom clipping: %s/%d" % [animation, index])
				assert_almost_eq(image.get_pixel(0, 0).a, 0.0, 0.001)
				assert_almost_eq(image.get_pixel(canvas.x - 1, canvas.y - 1).a, 0.0, 0.001)
				assert_almost_eq(float(used.end.y), anchor.y, 40.0,
					"Feet must stay near the shared ground anchor: %s/%d" % [animation, index])
				distinct_frames[hash(image.get_data())] = true
			if action == "idle":
				assert_eq(distinct_frames.size(), 1, "Rest must use the same stable authored pose: %s" % animation)
			else:
				assert_gte(distinct_frames.size(), 2, "Repeated still image: %s" % animation)

