extends GutTest

const PROFILE_PATH := (
	"res://data/visuals/achilles/achilles_character_only_profile.tres"
)
const VISUAL_SCENE := preload(
	"res://characters/achilles/3d/Achilles3DVisual.tscn"
)


func test_legacy_profiles_keep_the_original_rig_contract_by_default() -> void:
	var profile := load(PROFILE_PATH) as AchillesVisualProfile
	assert_not_null(profile)
	assert_eq(profile.expected_bone_count, 52)
	assert_eq(profile.root_motion_bone_names, [
		&"mixamorig_Hips", &"mixamorig:Hips",
	] as Array[StringName])
	assert_eq(profile.required_action_names, [
		&"Anim_0_001", &"Anim_0_003", &"Anim_0_004", &"Anim_0_005",
	] as Array[StringName])
	assert_eq(
		profile.skeleton_signature_mode,
		AchillesVisualProfile
			.SKELETON_SIGNATURE_MODE_LEGACY_MIXAMO_NORMALIZED,
	)
	assert_true(profile.is_character_only_valid())


func test_exact_bone_name_signature_mode_accepts_an_exact_signature() -> void:
	var profile := _profile_copy()
	profile.skeleton_signature_mode = (
		AchillesVisualProfile.SKELETON_SIGNATURE_MODE_EXACT_BONE_NAMES
	)
	profile.skeleton_signature = _exact_signature_for_asset(
		profile.character_asset_path
	)

	var visual := _new_visual()
	assert_true(visual.initialize_from_profile(profile))
	assert_eq(
		visual.get_runtime_skeleton_signature(),
		profile.skeleton_signature,
	)


func test_bone_count_and_root_candidates_are_profile_driven() -> void:
	var profile := _profile_copy()
	profile.root_motion_bone_names = [
		&"missing_probe_bone", &"mixamorig_Hips", &"mixamorig:Hips",
	] as Array[StringName]
	var visual := _new_visual()
	assert_true(visual.initialize_from_profile(profile))

	var invalid_profile := _profile_copy()
	invalid_profile.expected_bone_count = 24
	var invalid_visual := _new_visual()
	var failures: Array[StringName] = []
	invalid_visual.setup_failed.connect(
		func(error_code: StringName) -> void: failures.append(error_code)
	)
	assert_false(invalid_visual.initialize_from_profile(invalid_profile))
	assert_eq(
		failures,
		[&"SKELETON_BONE_COUNT_MISMATCH"] as Array[StringName],
	)


func test_required_actions_are_profile_driven_without_restricting_other_clips() -> void:
	var empty_profile := _profile_copy()
	empty_profile.required_action_names = [] as Array[StringName]
	assert_false(empty_profile.is_character_only_valid())

	var profile := _profile_copy()
	profile.required_action_names = [&"Anim_0_004"] as Array[StringName]
	var visual := _new_visual()
	assert_true(visual.initialize_from_profile(profile))
	assert_eq(
		visual.get_source_action_names(),
		[&"Anim_0_004"] as Array[StringName],
	)
	assert_true(visual.play_action(&"arbitrary_clip_probe", &"Anim_0_005"))
	visual.cancel_action()

	var invalid_profile := _profile_copy()
	invalid_profile.required_action_names = [
		&"missing_arbitrary_action",
	] as Array[StringName]
	var invalid_visual := _new_visual()
	var failures: Array[StringName] = []
	invalid_visual.setup_failed.connect(
		func(error_code: StringName) -> void: failures.append(error_code)
	)
	assert_false(invalid_visual.initialize_from_profile(invalid_profile))
	assert_eq(
		failures,
		[&"SOURCE_ACTION_SET_MISMATCH"] as Array[StringName],
	)


func _profile_copy() -> AchillesVisualProfile:
	return (
		load(PROFILE_PATH) as AchillesVisualProfile
	).duplicate(true) as AchillesVisualProfile


func _new_visual() -> Achilles3DVisual:
	var visual := VISUAL_SCENE.instantiate() as Achilles3DVisual
	assert_not_null(visual)
	add_child_autofree(visual)
	return visual


func _exact_signature_for_asset(asset_path: String) -> String:
	var packed_scene := load(asset_path) as PackedScene
	assert_not_null(packed_scene)
	var asset := packed_scene.instantiate() as Node3D
	assert_not_null(asset)
	var skeletons := asset.find_children("*", "Skeleton3D", true, false)
	assert_eq(skeletons.size(), 1)
	var skeleton := skeletons[0] as Skeleton3D
	var bone_names: Array[String] = []
	for bone_index in range(skeleton.get_bone_count()):
		bone_names.append(String(skeleton.get_bone_name(bone_index)))
	asset.free()
	return JSON.stringify(bone_names).sha256_text().to_upper()
