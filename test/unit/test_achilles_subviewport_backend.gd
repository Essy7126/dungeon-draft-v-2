extends GutTest

const PROFILE_PATH := (
	"res://data/visuals/achilles/achilles_character_only_profile.tres"
)
const BACKEND_SCENE := preload(
	"res://characters/achilles/3d/AchillesViewport3DBackend.tscn"
)
const ADAPTER_SCENE := preload(
	"res://characters/achilles/AchillesIsoUnitView.tscn"
)


func test_subviewport_backend_is_transparent_passive_and_textured() -> void:
	var backend := BACKEND_SCENE.instantiate() as AchillesViewport3DBackend
	add_child_autofree(backend)
	var profile := load(PROFILE_PATH) as AchillesVisualProfile
	assert_true(backend.configure(profile))
	await wait_process_frames(3)
	assert_true(backend.is_ready_for_render())
	assert_true(backend.character_viewport.transparent_bg)
	assert_true(backend.character_viewport.own_world_3d)
	assert_true(backend.character_viewport.gui_disable_input)
	assert_false(backend.character_viewport.physics_object_picking)
	assert_eq(backend.character_viewport.size, Vector2i(384, 384))
	assert_not_null(backend.rendered_sprite.texture)
	assert_not_null(backend.get_achilles_visual())
	assert_eq(
		backend.character_viewport.find_children(
			"*", "CollisionObject3D", true, false
		).size(),
		0,
	)


func test_three_candidate_resolutions_and_foot_anchor_are_deterministic() -> void:
	var backend := BACKEND_SCENE.instantiate() as AchillesViewport3DBackend
	add_child_autofree(backend)
	assert_true(backend.configure(load(PROFILE_PATH) as AchillesVisualProfile))
	await wait_process_frames(3)
	backend.set_backend_active(true)
	for resolution in [256, 384, 512]:
		assert_true(backend.set_viewport_resolution(resolution))
		assert_eq(
			backend.character_viewport.size,
			Vector2i(resolution, resolution),
		)
	await wait_process_frames(2)
	var anchored := (
		backend.rendered_sprite.position
		+ backend.get_projected_foot_pixel() * backend.rendered_sprite.scale
	)
	assert_almost_eq(anchored.x, 0.0, 0.01)
	assert_almost_eq(anchored.y, 0.0, 0.01)
	assert_false(backend.set_viewport_resolution(320))


func test_four_cardinal_orientations_rotate_only_internal_character() -> void:
	var gameplay_parent := Node2D.new()
	gameplay_parent.position = Vector2(170.0, 240.0)
	add_child_autofree(gameplay_parent)
	var backend := BACKEND_SCENE.instantiate() as AchillesViewport3DBackend
	gameplay_parent.add_child(backend)
	var profile := load(PROFILE_PATH) as AchillesVisualProfile
	assert_true(backend.configure(profile))
	await wait_process_frames(3)
	var parent_before := gameplay_parent.transform
	for direction in ["N", "E", "S", "W"]:
		backend.set_facing_label(direction)
		assert_almost_eq(
			backend.get_achilles_visual().character_asset.rotation_degrees.y,
			profile.yaw_for_direction(direction),
			0.001,
		)
		assert_eq(gameplay_parent.transform, parent_before)


func test_backend_action_signals_are_exactly_once() -> void:
	var backend := BACKEND_SCENE.instantiate() as AchillesViewport3DBackend
	add_child_autofree(backend)
	assert_true(backend.configure(load(PROFILE_PATH) as AchillesVisualProfile))
	await wait_process_frames(3)
	var started := {"count": 0}
	var released := {"count": 0}
	var finished := {"count": 0}
	backend.action_started.connect(func(_name: StringName) -> void:
		started.count += 1
	)
	backend.action_release_reached.connect(func() -> void:
		released.count += 1
	)
	backend.action_finished.connect(func(_name: StringName) -> void:
		finished.count += 1
	)
	assert_true(backend.play_action())
	await get_tree().create_timer(1.5).timeout
	assert_eq(started.count, 1)
	assert_eq(released.count, 1)
	assert_eq(finished.count, 1)


func test_adapter_uses_exactly_one_backend_and_can_force_fallback() -> void:
	var adapter := ADAPTER_SCENE.instantiate() as AchillesIsoUnitView
	add_child_autofree(adapter)
	await wait_process_frames(3)
	assert_eq(adapter.get_active_backend_name(), &"Viewport3DBackend")
	assert_true(adapter.viewport_backend.visible)
	assert_false(adapter.legacy_backend.visible)
	adapter.force_legacy_2d(&"TEST_FORCED_FALLBACK")
	assert_eq(adapter.get_active_backend_name(), &"Legacy2DBackend")
	assert_true(adapter.legacy_backend.visible)
	assert_false(adapter.viewport_backend.visible)
	assert_eq(
		adapter.get_last_backend_error().get("error_code"),
		"TEST_FORCED_FALLBACK",
	)


func test_adapter_preserves_release_and_finished_signals_once() -> void:
	var adapter := ADAPTER_SCENE.instantiate() as AchillesIsoUnitView
	add_child_autofree(adapter)
	await wait_process_frames(4)
	var releases := {"count": 0}
	var finishes := {"count": 0}
	adapter.cast_release_reached.connect(func() -> void:
		releases.count += 1
	)
	adapter.animation_finished.connect(func(_name: StringName) -> void:
		finishes.count += 1
	)
	assert_true(adapter.play_spell_action())
	assert_false(adapter.play_spell_action())
	await get_tree().create_timer(1.5).timeout
	assert_eq(releases.count, 1)
	assert_eq(finishes.count, 1)
	await get_tree().create_timer(0.2).timeout
	assert_eq(releases.count, 1)
	assert_eq(finishes.count, 1)


func test_missing_lazy_character_asset_falls_back_without_dual_render() -> void:
	var profile := (
		load(PROFILE_PATH) as AchillesVisualProfile
	).duplicate(true) as AchillesVisualProfile
	profile.character_asset_path = (
		"res://assets/characters/Achilles/3d/missing_character.glb"
	)
	var adapter := ADAPTER_SCENE.instantiate() as AchillesIsoUnitView
	adapter.visual_profile = profile
	add_child_autofree(adapter)
	await wait_process_frames(3)
	assert_eq(adapter.get_active_backend_name(), &"Legacy2DBackend")
	assert_true(adapter.legacy_backend.visible)
	assert_false(adapter.viewport_backend.visible)
	assert_eq(
		adapter.get_last_backend_error().get("error_code"),
		"CHARACTER_ASSET_MISSING",
	)


func test_backend_cleanup_disables_and_releases_viewport_content() -> void:
	var backend := BACKEND_SCENE.instantiate() as AchillesViewport3DBackend
	add_child_autofree(backend)
	assert_true(backend.configure(load(PROFILE_PATH) as AchillesVisualProfile))
	await wait_process_frames(3)
	backend.set_backend_active(true)
	backend.shutdown()
	assert_true(backend.is_shutdown())
	assert_false(backend.visible)
	assert_eq(
		backend.character_viewport.render_target_update_mode,
		SubViewport.UPDATE_DISABLED,
	)
	assert_null(backend.rendered_sprite.texture)
	assert_null(backend.get_achilles_visual())
