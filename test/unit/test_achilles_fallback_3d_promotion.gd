extends GutTest

const PROFILE_PATH := (
	"res://data/visuals/achilles/achilles_character_only_profile.tres"
)
const FALLBACK_SCENE_PATH := (
	"res://characters/achilles/3d/AchillesLegacy2DBackend.tscn"
)
const MISSING_CHARACTER_PATH := (
	"res://assets/characters/Achilles/3d/__fallback_test_missing__.glb"
)
const FALLBACK_SCRIPT := preload(
	"res://characters/achilles/3d/achilles_legacy_2d_backend.gd"
)
const ADAPTER_SCENE := preload(
	"res://characters/achilles/AchillesIsoUnitView.tscn"
)
const RUNTIME_READY_TIMEOUT_MSEC := 10000


func test_profile_requests_viewport_3d_with_verified_legacy_fallback() -> void:
	var profile := load(PROFILE_PATH) as AchillesVisualProfile
	assert_not_null(profile)
	assert_true(profile.is_character_only_valid())
	assert_eq(
		profile.rendering_mode,
		AchillesVisualProfile.RENDERING_VIEWPORT_3D,
	)
	assert_eq(
		profile.fallback_policy,
		AchillesVisualProfile.FALLBACK_POLICY_LEGACY_2D_ON_VERIFIED_ERROR,
	)
	assert_not_null(profile.fallback_backend_scene)
	assert_eq(profile.fallback_backend_scene.resource_path, FALLBACK_SCENE_PATH)
	assert_false(_has_property(profile, &"fallback_2d_scene"))
	var legacy_dependency_found := false
	for dependency: String in ResourceLoader.get_dependencies(PROFILE_PATH):
		var lowered := dependency.to_lower()
		legacy_dependency_found = legacy_dependency_found or (
			"achilleslegacy2dbackend" in lowered
		)
		assert_false("achillesnovisualfallbackbackend" in lowered)
	assert_true(legacy_dependency_found)


func test_legacy_scene_defaults_to_hidden_and_processing_disabled() -> void:
	var profile := load(PROFILE_PATH) as AchillesVisualProfile
	var fallback := profile.fallback_backend_scene.instantiate() as Node2D
	assert_not_null(fallback)
	add_child_autofree(fallback)
	await wait_process_frames(1)
	assert_eq(fallback.get_script(), FALLBACK_SCRIPT)
	assert_false(fallback.visible)
	assert_false(fallback.can_process())
	assert_false(bool(fallback.call("is_backend_active")))


func test_nominal_tree_never_instantiates_legacy_fallback() -> void:
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
	var state := adapter.get_visual_runtime_state()
	assert_false(bool(state.get("ACHILLES_VISUAL_FALLBACK_ACTIVE", true)))
	assert_false(bool(state.get("ACHILLES_LEGACY_BODY_VISIBLE", true)))
	assert_false(bool(state.get("ACHILLES_LEGACY_BODY_PROCESSING", true)))


func test_verified_missing_asset_activates_visible_processing_legacy() -> void:
	var adapter := await _create_missing_asset_adapter()
	assert_eq(adapter.get_active_backend_name(), &"Legacy2DFallbackBackend")
	assert_not_null(adapter.fallback_backend)
	assert_eq(adapter.fallback_backend.get_script(), FALLBACK_SCRIPT)
	assert_true(adapter.fallback_backend.is_backend_active())
	assert_true(adapter.fallback_backend.visible)
	assert_true(adapter.fallback_backend.is_visible_in_tree())
	assert_true(adapter.fallback_backend.can_process())
	assert_false(adapter.viewport_backend.is_backend_active())
	assert_false(adapter.viewport_backend.visible)
	assert_null(adapter.viewport_backend.get_achilles_visual())
	var sprites := adapter.find_children(
		"*", "AnimatedSprite2D", true, false
	)
	assert_eq(sprites.size(), 1)
	assert_true((sprites[0] as AnimatedSprite2D).is_visible_in_tree())
	assert_true((sprites[0] as AnimatedSprite2D).can_process())
	var event := adapter.get_last_backend_error()
	assert_eq(event.get("error_code"), "CHARACTER_ASSET_MISSING")
	assert_eq(event.get("failed_resource"), MISSING_CHARACTER_PATH)
	assert_eq(event.get("fallback"), "LEGACY_2D_ON_VERIFIED_ERROR")
	assert_true(bool(event.get("legacy_2d_loaded", false)))
	assert_true(bool(event.get("fallback_active", false)))


func test_verified_fallback_keeps_one_backend_and_signals_once() -> void:
	var adapter := await _create_missing_asset_adapter()
	var fallback_started := {"count": 0}
	var viewport_started := {"count": 0}
	var released := {"count": 0}
	var finished := {"count": 0}
	adapter.fallback_backend.action_started.connect(
		func(_name: StringName) -> void: fallback_started.count += 1
	)
	adapter.viewport_backend.action_started.connect(
		func(_name: StringName) -> void: viewport_started.count += 1
	)
	adapter.cast_release_reached.connect(func() -> void: released.count += 1)
	adapter.animation_finished.connect(
		func(_name: StringName) -> void: finished.count += 1
	)
	assert_eq(
		int(adapter.viewport_backend.is_backend_active())
		+ int(adapter.fallback_backend.is_backend_active()),
		1,
	)
	assert_true(adapter.play_spell_action())
	assert_false(adapter.play_spell_action())
	await get_tree().create_timer(1.7).timeout
	assert_eq(fallback_started.count, 1)
	assert_eq(viewport_started.count, 0)
	assert_eq(released.count, 1)
	assert_eq(finished.count, 1)
	await get_tree().create_timer(0.2).timeout
	assert_eq(released.count, 1)
	assert_eq(finished.count, 1)


func test_cancelled_verified_fallback_action_emits_nothing_late() -> void:
	var adapter := await _create_missing_asset_adapter()
	var released := {"count": 0}
	var finished := {"count": 0}
	adapter.cast_release_reached.connect(func() -> void: released.count += 1)
	adapter.animation_finished.connect(
		func(_name: StringName) -> void: finished.count += 1
	)
	assert_true(adapter.play_spell_action())
	adapter.cancel_pending_visual_actions()
	await get_tree().create_timer(1.7).timeout
	assert_eq(released.count, 0)
	assert_eq(finished.count, 0)
	assert_true(adapter.play_idle())


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


func _has_property(instance: Object, property_name: StringName) -> bool:
	for property in instance.get_property_list():
		if StringName(property.get("name", "")) == property_name:
			return true
	return false
