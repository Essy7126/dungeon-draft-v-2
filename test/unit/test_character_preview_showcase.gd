extends GutTest

const PREVIEW := preload("res://ui/characters/CharacterPreview3D.tscn")


func test_showcase_is_opt_in_and_disabling_restores_portrait_transform() -> void:
	var preview := _make_preview(false)
	var sprite := preview.get_sprite_instance()
	var portrait_transform := sprite.transform
	assert_false(preview.is_showcase_mode())
	assert_false(preview.set_showcase_zoom(1.1))
	assert_eq(sprite.transform, portrait_transform)
	var fitted := _fitted_rect(preview)
	assert_almost_eq(fitted.get_center().y, preview.size.y * 0.5, 0.001)
	assert_almost_eq(fitted.size.y, preview.size.y * 0.9, 0.001)
	preview.set_showcase_mode(true)
	assert_true(preview.set_showcase_zoom(1.1))
	preview.set_showcase_mode(false)
	assert_eq(sprite.transform, portrait_transform)
	assert_eq(preview.get_showcase_zoom(), 1.0)


func test_showcase_fits_height_and_keeps_feet_on_stage_across_zoom_and_resize() -> void:
	var preview := _make_preview(true)
	var fitted := _fitted_rect(preview)
	assert_almost_eq(fitted.size.y, preview.size.y * 0.94, 0.001)
	_assert_stage_anchor(preview)
	for zoom: float in [0.2, 0.95, 1.0, 2.0]:
		assert_true(preview.set_showcase_zoom(zoom))
		assert_almost_eq(preview.get_showcase_zoom(), clampf(zoom, 0.85, 1.1), 0.0001)
		_assert_stage_anchor(preview)
	assert_false(preview.set_showcase_zoom(NAN))
	assert_false(preview.set_showcase_zoom(INF))
	preview.size = Vector2(420, 320)
	await wait_process_frames(2)
	_assert_stage_anchor(preview)


func test_showcase_has_one_reference_transform_across_poses_and_animation_frames() -> void:
	var preview := _make_preview(true)
	var sprite := preview.get_sprite_instance()
	var reference := preview.get_sprite_reference_rect()
	var transform := sprite.transform
	assert_true(preview.play_clip(&"attack_W"))
	sprite.frame = 1
	await wait_process_frames(2)
	assert_eq(sprite.transform, transform)
	assert_eq(preview.get_sprite_reference_rect(), reference)
	assert_true(preview.play_clip(&"idle_E"))
	assert_eq(sprite.transform, transform)
	_assert_stage_anchor(preview)


func test_showcase_still_honors_pause_cleanup_and_reconfigure() -> void:
	var preview := _make_preview(true)
	assert_true(preview.play_clip(&"attack_W"))
	preview.set_preview_active(false)
	assert_false(preview.get_sprite_instance().is_playing())
	assert_eq(preview.preview_viewport.render_target_update_mode, SubViewport.UPDATE_DISABLED)
	preview.set_preview_active(true)
	assert_true(preview.get_sprite_instance().is_playing())
	preview.clear_preview()
	assert_null(preview.get_sprite_instance())
	assert_eq(preview.find_children("*", "AnimatedSprite2D", true, false).size(), 0)
	assert_eq(preview.preview_viewport.render_target_update_mode, SubViewport.UPDATE_DISABLED)
	preview.configure(_sprite_data())
	assert_true(preview.is_showcase_mode())
	_assert_stage_anchor(preview)


func test_showcase_3d_origin_uses_stage_anchor_and_camera_restores() -> void:
	var model := Node3D.new()
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	model.add_child(mesh)
	mesh.owner = model
	var scene := PackedScene.new()
	assert_eq(scene.pack(model), OK)
	model.free()
	var preview := PREVIEW.instantiate() as CharacterPreview3D
	add_child_autofree(preview)
	preview.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	preview.custom_minimum_size = Vector2.ZERO
	preview.size = Vector2(596, 483)
	preview.configure(scene)
	await wait_process_frames(2)
	var camera_transform := preview.camera.transform
	var camera_size := preview.camera.size
	preview.set_showcase_mode(true)
	assert_lt(preview.camera.size, camera_size)
	var anchor := preview.camera.unproject_position(preview.visual_root.global_position)
	assert_almost_eq(anchor.x, preview.preview_viewport.size.x * 0.5, 0.01)
	assert_almost_eq(anchor.y, preview.preview_viewport.size.y * 0.96, 0.01)
	preview.set_showcase_zoom(0.85)
	anchor = preview.camera.unproject_position(preview.visual_root.global_position)
	assert_almost_eq(anchor.y, preview.preview_viewport.size.y * 0.96, 0.01)
	preview.set_showcase_mode(false)
	assert_eq(preview.camera.transform, camera_transform)
	assert_eq(preview.camera.size, camera_size)


func _assert_stage_anchor(preview: CharacterPreview3D) -> void:
	var fitted := _fitted_rect(preview)
	assert_almost_eq(fitted.end.y, preview.size.y * 0.96, 0.001)
	assert_almost_eq(fitted.get_center().x, preview.size.x * 0.5, 0.001)


func _fitted_rect(preview: CharacterPreview3D) -> Rect2:
	var sprite := preview.get_sprite_instance()
	var reference := preview.get_sprite_reference_rect()
	return Rect2(sprite.position + reference.position * sprite.scale, reference.size * sprite.scale)


func _make_preview(showcase: bool) -> CharacterPreview3D:
	var preview := PREVIEW.instantiate() as CharacterPreview3D
	preview.unit_data = _sprite_data()
	preview.set_showcase_mode(showcase)
	add_child_autofree(preview)
	preview.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	preview.custom_minimum_size = Vector2.ZERO
	preview.size = Vector2(596, 483)
	return preview


func _sprite_data() -> UnitData:
	var frames := SpriteFrames.new()
	frames.add_animation(&"idle_E")
	frames.add_frame(&"idle_E", _texture(Rect2i(20, 5, 40, 90)))
	frames.add_animation(&"attack_W")
	frames.set_animation_speed(&"attack_W", 1.0)
	frames.add_frame(&"attack_W", _texture(Rect2i(5, 15, 70, 80)))
	frames.add_frame(&"attack_W", _texture(Rect2i(8, 10, 60, 85)))
	var data := UnitData.new()
	data.preview_sprite_frames = frames
	data.preview_sprite_animation = &"idle_E"
	return data


func _texture(bounds: Rect2i) -> ImageTexture:
	var image := Image.create(80, 100, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	for y: int in range(bounds.position.y, bounds.end.y):
		for x: int in range(bounds.position.x, bounds.end.x):
			image.set_pixel(x, y, Color.WHITE)
	return ImageTexture.create_from_image(image)
