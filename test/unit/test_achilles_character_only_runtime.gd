extends GutTest

const PROFILE_PATH := (
	"res://data/visuals/achilles/achilles_character_only_profile.tres"
)
const FALLBACK_SCENE_PATH := (
	"res://characters/achilles/3d/AchillesLegacy2DBackend.tscn"
)
const VISUAL_SCENE := preload(
	"res://characters/achilles/3d/Achilles3DVisual.tscn"
)


func test_character_only_profile_schema_and_backend_contract() -> void:
	var profile := load(PROFILE_PATH) as AchillesVisualProfile
	assert_not_null(profile)
	assert_true(profile.is_character_only_valid())
	assert_eq(profile.schema_version, 1)
	assert_eq(profile.profile_id, &"achilles_character_only_v1")
	assert_eq(profile.rendering_mode, AchillesVisualProfile.RENDERING_VIEWPORT_3D)
	assert_eq(profile.validated_viewport_size(), Vector2i(384, 384))
	assert_not_null(profile.character_scene)
	assert_not_null(profile.fallback_backend_scene)
	assert_eq(profile.fallback_backend_scene.resource_path, FALLBACK_SCENE_PATH)
	assert_eq(
		profile.fallback_policy,
		AchillesVisualProfile.FALLBACK_POLICY_LEGACY_2D_ON_VERIFIED_ERROR,
	)


func test_character_only_profile_has_no_3d_equipment_configuration() -> void:
	var profile := load(PROFILE_PATH) as AchillesVisualProfile
	assert_not_null(profile)
	assert_false(profile.equipment_enabled)
	assert_null(profile.weapon_profile)


func test_achilles_3d_visual_has_character_only_structure() -> void:
	var visual := VISUAL_SCENE.instantiate() as Achilles3DVisual
	assert_not_null(visual)
	assert_not_null(visual.get_node_or_null("CharacterAsset"))
	assert_not_null(visual.get_node_or_null("Markers/FootMarker"))
	assert_not_null(visual.get_node_or_null("Markers/VFXMarker"))
	assert_not_null(visual.get_node_or_null("Markers/FacingMarker"))
	assert_not_null(visual.get_node_or_null("Achilles3DVisualController"))
	visual.free()


func test_canonical_character_loads_single_rig_meshes_and_materials() -> void:
	var visual := VISUAL_SCENE.instantiate() as Achilles3DVisual
	add_child_autofree(visual)
	var profile := load(PROFILE_PATH) as AchillesVisualProfile
	assert_true(visual.initialize_from_profile(profile))
	assert_true(visual.is_initialized())
	assert_not_null(visual.get_skeleton())
	assert_eq(visual.get_skeleton().get_bone_count(), 52)
	assert_eq(
		visual.get_runtime_skeleton_signature(),
		profile.skeleton_signature,
	)
	assert_true(visual.get_mesh_instances().size() >= 1)
	assert_true(visual.has_visible_character_materials())
	assert_eq(visual.get_source_action_names().size(), 4)
	assert_eq(
		visual.get_root_motion_policy(),
		&"ROOT_MOTION_UNCLASSIFIED",
	)


func test_initialized_3d_character_has_no_equipment_nodes() -> void:
	var visual := VISUAL_SCENE.instantiate() as Achilles3DVisual
	add_child_autofree(visual)
	var profile := load(PROFILE_PATH) as AchillesVisualProfile
	assert_true(visual.initialize_from_profile(profile))
	assert_null(visual.find_child("EquipmentController", true, false))
	assert_null(visual.find_child("WeaponAdapterRoot", true, false))
	assert_true(
		visual.find_children("*", "BoneAttachment3D", true, false).is_empty()
	)
	assert_false(visual._contains_equipment_named_node())


func test_action_fallback_releases_and_finishes_once_without_root_motion() -> void:
	var gameplay_parent := Node3D.new()
	gameplay_parent.position = Vector3(7.0, 2.0, -4.0)
	add_child_autofree(gameplay_parent)
	var visual := VISUAL_SCENE.instantiate() as Achilles3DVisual
	gameplay_parent.add_child(visual)
	var profile := load(PROFILE_PATH) as AchillesVisualProfile
	assert_true(visual.initialize_from_profile(profile))
	var parent_before := gameplay_parent.transform
	var started := {"count": 0}
	var released := {"count": 0}
	var finished := {"count": 0}
	visual.action_started.connect(func(_name: StringName) -> void:
		started.count += 1
	)
	visual.action_release_reached.connect(func() -> void:
		released.count += 1
	)
	visual.action_finished.connect(func(_name: StringName) -> void:
		finished.count += 1
	)
	assert_true(visual.play_action())
	assert_false(visual.play_action())
	await get_tree().create_timer(1.5).timeout
	assert_eq(started.count, 1)
	assert_eq(released.count, 1)
	assert_eq(finished.count, 1)
	assert_eq(gameplay_parent.transform, parent_before)
	await get_tree().create_timer(0.2).timeout
	assert_eq(released.count, 1)
	assert_eq(finished.count, 1)


func test_cancelled_action_emits_no_late_release_or_finish() -> void:
	var visual := VISUAL_SCENE.instantiate() as Achilles3DVisual
	add_child_autofree(visual)
	assert_true(visual.initialize_from_profile(
		load(PROFILE_PATH) as AchillesVisualProfile
	))
	var released := {"count": 0}
	var finished := {"count": 0}
	visual.action_release_reached.connect(func() -> void:
		released.count += 1
	)
	visual.action_finished.connect(func(_name: StringName) -> void:
		finished.count += 1
	)
	assert_true(visual.play_action())
	visual.cancel_action()
	await get_tree().create_timer(1.5).timeout
	assert_eq(released.count, 0)
	assert_eq(finished.count, 0)
