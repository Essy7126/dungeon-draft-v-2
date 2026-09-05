extends GutTest

const ADAPTER := preload("res://characters/achilles/AchillesIsoUnitView.tscn")
const DIRECTIONS := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]


func test_one_cell_arrival_uses_drawn_foot_contact_in_all_directions() -> void:
	var visual := await _create_visual()
	var sprite := visual.sprite_backend.animated_sprite
	for direction: Vector2i in DIRECTIONS:
		visual.set_facing(direction)
		visual.play_idle()
		var rest_foot := _lowest_opaque_pixel(sprite)
		visual.begin_movement_feedback(Vector2i.ZERO, direction)
		for progress: float in [0.0, 0.25, 0.5, 0.75, 1.0]:
			visual.update_movement_stride(0, progress)
		assert_eq(sprite.frame, 3)
		assert_almost_eq(float(_lowest_opaque_pixel(sprite)), float(rest_foot), 3.0,
			"The actual drawn foot must already be down before switching to idle")
		assert_false(sprite.is_playing(), "Position tween owns the stride phase")
		visual.cancel_movement_feedback()
		assert_eq(sprite.frame, 0)
		assert_true(String(sprite.animation).begins_with("idle_"))
		assert_false(sprite.is_playing())


func test_stride_phase_waits_with_position_and_survives_direction_changes() -> void:
	var visual := await _create_visual()
	var sprite := visual.sprite_backend.animated_sprite
	visual.begin_path_movement_feedback([Vector2i.ZERO, Vector2i.RIGHT, Vector2i(1, 1)])
	visual.update_movement_stride(0, 0.625)
	assert_eq(sprite.frame, 2)
	assert_almost_eq(sprite.frame_progress, 0.5, 0.001)
	await wait_seconds(0.12)
	assert_eq(sprite.frame, 2, "A stationary movement tween cannot advance the feet")
	assert_almost_eq(sprite.frame_progress, 0.5, 0.001)
	visual.set_facing(Vector2i.DOWN)
	assert_eq(sprite.animation, &"walk_S")
	assert_eq(sprite.frame, 2)
	assert_almost_eq(sprite.frame_progress, 0.5, 0.001)
	assert_false(sprite.is_playing())
	visual.update_movement_stride(1, 0.0)
	assert_eq(sprite.frame, 4, "The second cell continues the opposite step")
	visual.update_movement_stride(1, 1.0)
	assert_eq(sprite.frame, 7)
	var contact_foot := _lowest_opaque_pixel(sprite)
	visual.cancel_movement_feedback()
	assert_almost_eq(float(contact_foot), float(_lowest_opaque_pixel(sprite)), 3.0)
	visual.update_movement_stride(1, 0.5)
	assert_eq(sprite.animation, &"idle_S", "Late tween callbacks cannot restart a finished path")
	assert_eq(sprite.frame, 0)


func test_running_stride_keeps_all_contacts_and_does_not_block_next_action() -> void:
	var visual := await _create_visual()
	var sprite := visual.sprite_backend.animated_sprite
	var path: Array = []
	for index in 7:
		path.append(Vector2i(index, 0))
	visual.begin_path_movement_feedback(path)
	assert_almost_eq(visual.get_movement_segment_duration(path), 0.2, 0.0001)
	assert_almost_eq(sprite.speed_scale, 1.4, 0.0001)
	for step_index in 6:
		visual.update_movement_stride(step_index, 1.0)
		assert_true(sprite.frame in [3, 7])
		assert_almost_eq(float(_lowest_opaque_pixel(sprite)), 320.0, 3.0)
	visual.cancel_movement_feedback()
	assert_true(visual.play_basic_attack())
	assert_eq(sprite.animation, &"attack_E")
	assert_true(sprite.is_playing(), "Distance-driven walking must not pause the next attack")
	visual.cancel_pending_visual_actions()


func _create_visual() -> AchillesIsoUnitView:
	var owner := Node2D.new()
	add_child_autofree(owner)
	var visual := ADAPTER.instantiate() as AchillesIsoUnitView
	owner.add_child(visual)
	await wait_process_frames(4)
	return visual


func _lowest_opaque_pixel(sprite: AnimatedSprite2D) -> int:
	var texture := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	var pixels := texture.get_image()
	if pixels.is_compressed():
		pixels.decompress()
	for y in range(pixels.get_height() - 1, -1, -1):
		for x in pixels.get_width():
			if pixels.get_pixel(x, y).a > 0.13:
				return y + 1
	return -1
