extends GutTest

const PREVIEW := preload("res://ui/characters/CharacterPreview3D.tscn")
const ACHILLES_PATH := "res://data/units/allies/achilles.tres"
const FRAMES_PATH := "res://assets/characters/Achilles/sprites_cour_des_sources_v1/achilles_sprite_frames.tres"


func test_canonical_preview_uses_same_sprite_frames_and_stable_idle_without_model() -> void:
	var data := load(ACHILLES_PATH) as UnitData
	assert_null(data.preview_visual_scene)
	assert_not_null(data.preview_sprite_frames)
	assert_eq(data.preview_sprite_frames.resource_path, FRAMES_PATH)
	assert_eq(data.preview_sprite_animation, &"idle_E")
	for dependency: String in ResourceLoader.get_dependencies(ACHILLES_PATH):
		assert_false(dependency.to_lower().contains(".glb"), "Canonical preview must not preload an old model")
	var preview := _create_preview(data)
	var sprite := preview.get_sprite_instance()
	assert_true(preview.is_using_sprite_preview())
	assert_false(preview.is_using_fallback())
	assert_null(preview.get_visual_instance())
	assert_eq(sprite.sprite_frames, data.preview_sprite_frames)
	assert_eq(preview.visual_root.get_child_count(), 0)
	assert_eq(preview.find_children("*", "Skeleton3D", true, false).size(), 0)
	assert_false(preview.viewport_container.visible)
	assert_eq(preview.preview_viewport.render_target_update_mode, SubViewport.UPDATE_DISABLED)
	var transform := sprite.transform
	await wait_seconds(0.55)
	assert_eq(sprite.animation, &"idle_E")
	assert_eq(sprite.frame, 0)
	assert_false(sprite.is_playing())
	assert_eq(sprite.transform, transform)


func test_preview_exposes_twelve_clips_and_pauses_without_changing_framing() -> void:
	var preview := _create_preview(load(ACHILLES_PATH) as UnitData)
	var sprite := preview.get_sprite_instance()
	var clips := preview.get_available_clips()
	assert_eq(clips.size(), 12)
	var expected: Array[StringName] = []
	for action: String in ["attack", "idle", "walk"]:
		for direction: String in ["E", "N", "S", "W"]:
			expected.append(StringName("%s_%s" % [action, direction]))
	assert_eq(clips, expected)
	var transform := sprite.transform
	var reference := preview.get_sprite_reference_rect()
	for clip: StringName in clips:
		assert_true(preview.has_clip(clip))
		assert_true(preview.play_clip(clip))
		assert_eq(sprite.animation, clip)
		assert_eq(sprite.transform, transform)
		assert_eq(preview.get_sprite_reference_rect(), reference)
		assert_eq(sprite.is_playing(), not String(clip).begins_with("idle_"))
	assert_false(preview.play_clip(&"missing_clip"))
	for clip: StringName in [&"walk_E", &"attack_E"]:
		assert_true(preview.play_clip(clip))
		await wait_seconds(0.2)
		assert_gt(sprite.frame, 0, "Preview must actually advance %s" % clip)
		preview.stop_clip()
		var paused_frame := sprite.frame
		var paused_progress := sprite.frame_progress
		await wait_seconds(0.15)
		assert_false(sprite.is_playing())
		assert_eq(sprite.frame, paused_frame)
		assert_almost_eq(sprite.frame_progress, paused_progress, 0.0001)
		assert_eq(sprite.transform, transform)
		assert_eq(preview.preview_viewport.render_target_update_mode, SubViewport.UPDATE_DISABLED)


func test_preview_resize_fits_reference_once_and_does_not_pump_between_poses() -> void:
	var preview := _create_preview(load(ACHILLES_PATH) as UnitData)
	var sprite := preview.get_sprite_instance()
	var reference := preview.get_sprite_reference_rect()
	assert_true(reference.has_area())
	for requested_size: Vector2 in [Vector2(240, 160), Vector2(480, 320), Vector2(320, 210)]:
		preview.size = requested_size
		await wait_process_frames(2)
		assert_true(is_finite(sprite.scale.x))
		assert_true(is_finite(sprite.scale.y))
		assert_gt(sprite.scale.x, 0.0)
		assert_almost_eq(sprite.scale.x, sprite.scale.y, 0.0001)
		var fitted := Rect2(sprite.position + reference.position * sprite.scale, reference.size * sprite.scale)
		assert_true(Rect2(Vector2.ZERO, preview.size).encloses(fitted))
		assert_almost_eq(fitted.get_center().x, preview.size.x * 0.5, 0.01)
		assert_almost_eq(fitted.get_center().y, preview.size.y * 0.5, 0.01)
		var transform := sprite.transform
		for clip: StringName in [&"walk_S", &"attack_W", &"idle_N"]:
			assert_true(preview.play_clip(clip))
			await wait_process_frames(2)
			assert_eq(sprite.transform, transform, "Changing pose must not alter portrait scale or centering")


func test_preview_inactivity_and_clear_never_resume_idle_or_activate_3d() -> void:
	var data := load(ACHILLES_PATH) as UnitData
	var preview := _create_preview(data)
	var sprite := preview.get_sprite_instance()
	preview.set_preview_active(false)
	preview.set_preview_active(true)
	assert_false(sprite.is_playing(), "Rest stays still when a portrait becomes visible")
	assert_true(preview.play_clip(&"walk_E"))
	await wait_seconds(0.15)
	preview.set_preview_active(false)
	var stopped_frame := sprite.frame
	var stopped_progress := sprite.frame_progress
	await wait_seconds(0.15)
	assert_eq(sprite.frame, stopped_frame)
	assert_almost_eq(sprite.frame_progress, stopped_progress, 0.0001)
	preview.set_preview_active(true)
	assert_true(sprite.is_playing())
	assert_false(preview.viewport_container.visible)
	assert_eq(preview.preview_viewport.render_target_update_mode, SubViewport.UPDATE_DISABLED)
	preview.clear_preview()
	assert_null(preview.get_sprite_instance())
	assert_null(preview.get_visual_instance())
	assert_false(preview.is_using_sprite_preview())
	assert_true(preview.is_using_fallback())
	assert_eq(preview.find_children("*", "AnimatedSprite2D", true, false).size(), 0)
	assert_eq(preview.preview_viewport.render_target_update_mode, SubViewport.UPDATE_DISABLED)
	preview.configure(data)
	assert_eq(preview.find_children("*", "AnimatedSprite2D", true, false).size(), 1)
	assert_eq(preview.get_sprite_instance().frame, 0)
	assert_false(preview.get_sprite_instance().is_playing())
	preview.configure(null)
	assert_true(preview.is_using_fallback())
	assert_null(preview.get_sprite_instance())
	assert_null(preview.get_visual_instance())
	assert_false(preview.viewport_container.visible)


func _create_preview(data: UnitData) -> CharacterPreview3D:
	var preview := PREVIEW.instantiate() as CharacterPreview3D
	preview.unit_data = data
	add_child_autofree(preview)
	preview.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	preview.custom_minimum_size = Vector2.ZERO
	preview.size = Vector2(320, 210)
	return preview
