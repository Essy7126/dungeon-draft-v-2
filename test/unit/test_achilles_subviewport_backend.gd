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
const FALLBACK_SCRIPT := preload(
	"res://characters/achilles/3d/achilles_legacy_2d_backend.gd"
)
const MISSING_CHARACTER_PATH := (
	"res://assets/characters/Achilles/3d/__backend_test_missing__.glb"
)
const RUNTIME_READY_TIMEOUT_MSEC := 10000


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


func test_adapter_nominal_path_uses_only_viewport_backend() -> void:
	var adapter := await _create_ready_adapter()
	assert_eq(adapter.get_active_backend_name(), &"Viewport3DBackend")
	assert_true(adapter.viewport_backend.is_backend_active())
	assert_true(adapter.viewport_backend.visible)
	assert_null(adapter.fallback_backend)
	assert_true(
		adapter.find_children("*", "AchillesVisual2D", true, false).is_empty()
	)
	assert_true(
		adapter.find_children("*", "AnimatedSprite2D", true, false).is_empty()
	)
	assert_true(adapter.get_last_backend_error().is_empty())


func test_adapter_preserves_release_and_finished_signals_once() -> void:
	var adapter := await _create_ready_adapter()
	var backend_starts := {"count": 0}
	var releases := {"count": 0}
	var finishes := {"count": 0}
	adapter.viewport_backend.action_started.connect(
		func(_name: StringName) -> void: backend_starts.count += 1
	)
	adapter.cast_release_reached.connect(func() -> void:
		releases.count += 1
	)
	adapter.animation_finished.connect(func(_name: StringName) -> void:
		finishes.count += 1
	)
	assert_true(adapter.play_spell_action())
	assert_false(adapter.play_spell_action())
	await get_tree().create_timer(1.5).timeout
	assert_eq(backend_starts.count, 1)
	assert_eq(releases.count, 1)
	assert_eq(finishes.count, 1)
	await get_tree().create_timer(0.2).timeout
	assert_eq(releases.count, 1)
	assert_eq(finishes.count, 1)


func test_missing_lazy_character_asset_falls_back_without_dual_render() -> void:
	var adapter := await _create_missing_asset_adapter()
	assert_eq(adapter.get_active_backend_name(), &"Legacy2DFallbackBackend")
	assert_not_null(adapter.fallback_backend)
	assert_eq(adapter.fallback_backend.get_script(), FALLBACK_SCRIPT)
	assert_true(adapter.fallback_backend.is_backend_active())
	assert_true(adapter.fallback_backend.visible)
	assert_true(adapter.fallback_backend.is_visible_in_tree())
	assert_true(adapter.fallback_backend.can_process())
	assert_false(adapter.viewport_backend.visible)
	assert_false(adapter.viewport_backend.is_backend_active())
	assert_null(adapter.viewport_backend.get_achilles_visual())
	var legacy_sprites := adapter.find_children(
		"*", "AnimatedSprite2D", true, false
	)
	assert_eq(legacy_sprites.size(), 1)
	assert_true((legacy_sprites[0] as AnimatedSprite2D).is_visible_in_tree())
	assert_eq(
		adapter.get_last_backend_error().get("error_code"),
		"CHARACTER_ASSET_MISSING",
	)
	assert_eq(
		adapter.get_last_backend_error().get("failed_resource"),
		MISSING_CHARACTER_PATH,
	)
	assert_true(bool(
		adapter.get_last_backend_error().get("legacy_2d_loaded", false)
	))


func test_verified_fallback_does_not_duplicate_backend_signals() -> void:
	var adapter := await _create_missing_asset_adapter()
	var viewport_starts := {"count": 0}
	var fallback_starts := {"count": 0}
	var releases := {"count": 0}
	var finishes := {"count": 0}
	adapter.viewport_backend.action_started.connect(
		func(_name: StringName) -> void: viewport_starts.count += 1
	)
	adapter.fallback_backend.action_started.connect(
		func(_name: StringName) -> void: fallback_starts.count += 1
	)
	adapter.cast_release_reached.connect(func() -> void: releases.count += 1)
	adapter.animation_finished.connect(
		func(_name: StringName) -> void: finishes.count += 1
	)
	assert_eq(
		int(adapter.viewport_backend.is_backend_active())
		+ int(adapter.fallback_backend.is_backend_active()),
		1,
	)
	assert_true(adapter.play_spell_action())
	assert_false(adapter.play_spell_action())
	await get_tree().create_timer(1.7).timeout
	assert_eq(viewport_starts.count, 0)
	assert_eq(fallback_starts.count, 1)
	assert_eq(releases.count, 1)
	assert_eq(finishes.count, 1)
	await get_tree().create_timer(0.2).timeout
	assert_eq(releases.count, 1)
	assert_eq(finishes.count, 1)


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


func _create_ready_adapter() -> AchillesIsoUnitView:
	var adapter := ADAPTER_SCENE.instantiate() as AchillesIsoUnitView
	assert_not_null(adapter)
	add_child_autofree(adapter)
	var deadline := Time.get_ticks_msec() + RUNTIME_READY_TIMEOUT_MSEC
	while adapter.get_active_backend_name() != &"Viewport3DBackend" \
			and Time.get_ticks_msec() < deadline:
		await wait_process_frames(1)
	assert_eq(adapter.get_active_backend_name(), &"Viewport3DBackend")
	return adapter


func _create_missing_asset_adapter() -> AchillesIsoUnitView:
	var profile := (
		load(PROFILE_PATH) as AchillesVisualProfile
	).duplicate(true) as AchillesVisualProfile
	profile.character_asset_path = MISSING_CHARACTER_PATH
	var adapter := ADAPTER_SCENE.instantiate() as AchillesIsoUnitView
	assert_not_null(adapter)
	adapter.visual_profile = profile
	add_child_autofree(adapter)
	var deadline := Time.get_ticks_msec() + RUNTIME_READY_TIMEOUT_MSEC
	while adapter.get_active_backend_name() != &"Legacy2DFallbackBackend" \
			and Time.get_ticks_msec() < deadline:
		await wait_process_frames(1)
	assert_eq(adapter.get_active_backend_name(), &"Legacy2DFallbackBackend")
	return adapter
