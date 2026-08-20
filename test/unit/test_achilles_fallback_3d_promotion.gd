extends GutTest

const PROFILE_PATH := (
	"res://data/visuals/achilles/achilles_character_only_profile.tres"
)
const FALLBACK_SCENE_PATH := (
	"res://characters/achilles/3d/AchillesNoVisualFallbackBackend.tscn"
)
const FALLBACK_SCRIPT := preload(
	"res://characters/achilles/3d/achilles_no_visual_fallback_backend.gd"
)


func test_profile_is_subviewport_only_with_no_visual_fallback() -> void:
	var profile := load(PROFILE_PATH) as AchillesVisualProfile
	assert_not_null(profile)
	assert_true(profile.is_character_only_valid())
	assert_eq(
		profile.rendering_mode,
		AchillesVisualProfile.RENDERING_SUBVIEWPORT,
	)
	assert_eq(
		profile.fallback_policy,
		AchillesVisualProfile.FALLBACK_POLICY_NO_VISUAL_ACTION_CONTRACT,
	)
	assert_not_null(profile.fallback_backend_scene)
	assert_false(_has_property(profile, &"fallback_2d_scene"))
	assert_true(_has_property(profile, &"weapon_profile"))
	assert_false(profile.equipment_enabled)
	assert_null(profile.weapon_profile)
	for dependency in ResourceLoader.get_dependencies(PROFILE_PATH):
		var lowered := String(dependency).to_lower()
		assert_false("achilleslegacy2dbackend" in lowered)
		assert_false("achillesvisual2d" in lowered)


func test_fallback_scene_has_no_2d_character_or_renderable_pixels() -> void:
	var profile := load(PROFILE_PATH) as AchillesVisualProfile
	var fallback: Node = profile.fallback_backend_scene.instantiate()
	assert_not_null(fallback)
	add_child_autofree(fallback)
	await wait_process_frames(1)
	assert_eq(fallback.get_script(), FALLBACK_SCRIPT)
	assert_false((fallback as CanvasItem).visible)
	assert_eq(
		fallback.find_children("*", "AnimatedSprite2D", true, false).size(),
		0,
	)
	assert_eq(fallback.find_children("*", "Sprite2D", true, false).size(), 0)
	assert_eq(fallback.find_children("*", "TextureRect", true, false).size(), 0)
	assert_eq(fallback.find_children("*", "SubViewport", true, false).size(), 0)
	for dependency in ResourceLoader.get_dependencies(FALLBACK_SCENE_PATH):
		var lowered := String(dependency).to_lower()
		assert_false("achillesvisual2d" in lowered)
		assert_false("legacy2d" in lowered)
		assert_false("animatedsprite" in lowered)


func test_no_visual_fallback_completes_action_exactly_once() -> void:
	var backend: Node = _create_active_backend()
	var started := {"count": 0}
	var released := {"count": 0}
	var finished := {"count": 0}
	backend.connect(&"action_started", func(_name: StringName) -> void:
		started.count += 1
	)
	backend.connect(&"action_release_reached", func() -> void:
		released.count += 1
	)
	backend.connect(&"action_finished", func(_name: StringName) -> void:
		finished.count += 1
	)
	assert_true(bool(backend.call("play_action", "SE")))
	assert_false(bool(backend.call("play_action", "SE")))
	await get_tree().create_timer(0.7).timeout
	assert_eq(started.count, 1)
	assert_eq(released.count, 1)
	assert_eq(finished.count, 1)
	assert_false((backend as CanvasItem).visible)
	await get_tree().create_timer(0.1).timeout
	assert_eq(released.count, 1)
	assert_eq(finished.count, 1)


func test_cancelled_no_visual_action_emits_nothing_late() -> void:
	var backend: Node = _create_active_backend()
	var released := {"count": 0}
	var finished := {"count": 0}
	backend.connect(&"action_release_reached", func() -> void:
		released.count += 1
	)
	backend.connect(&"action_finished", func(_name: StringName) -> void:
		finished.count += 1
	)
	assert_true(bool(backend.call("play_action", "N")))
	backend.call("cancel_action")
	await get_tree().create_timer(0.7).timeout
	assert_eq(released.count, 0)
	assert_eq(finished.count, 0)
	assert_true(bool(backend.call("play_idle", "N")))
	assert_true(bool(backend.call("play_move", "N")))
	assert_false((backend as CanvasItem).visible)


func _create_active_backend() -> Node:
	var profile := load(PROFILE_PATH) as AchillesVisualProfile
	var backend: Node = profile.fallback_backend_scene.instantiate()
	add_child_autofree(backend)
	backend.call("set_backend_active", true)
	return backend


func _has_property(instance: Object, property_name: StringName) -> bool:
	for property in instance.get_property_list():
		if StringName(property.get("name", "")) == property_name:
			return true
	return false
