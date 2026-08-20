extends GutTest

const CHARACTER_BLEND_PATH := (
	"res://art/source/characters/achilles/canonical/achilles_character_master_v1.blend"
)
const CHARACTER_GLB_PATH := (
	"res://assets/characters/Achilles/3d/achilles_rig_v1.glb"
)
const MASTER_MANIFEST_PATH := (
	"res://art/source/characters/achilles/canonical/character_master_manifest.json"
)
const GLB_INSPECTION_PATH := (
	"res://assets/characters/Achilles/3d/character_glb_inspection.json"
)
const PROFILE_PATH := (
	"res://data/visuals/achilles/achilles_character_only_profile.tres"
)
const EXPECTED_BLEND_SHA := (
	"F64F1F78269E3520F1383490D9428E56CC6454E1492B581253B4840E85095D78"
)
const EXPECTED_GLB_SHA := (
	"CA162138B9BE6693210619C06BBDABF0FD486E3DC75460A2566CBE140B4A774F"
)
const DIVERGENT_SOURCE_SHA := (
	"1FA92BD6A5C5CDC7E524F03B3FA41D7E26895E1FCB9425F394B1B2FFD1A79A57"
)
const SWORD_SOURCE_SHA := (
	"9F96D64E8CB95AA4B29638D049DFE458AB3833B3CB8C5A84F5B8F1F8277F662D"
)
const RUNTIME_TEXT_PATHS := [
	"res://characters/achilles/AchillesIsoUnitView.tscn",
	"res://characters/achilles/achilles_iso_unit_view.gd",
	"res://characters/achilles/3d/Achilles3DVisual.tscn",
	"res://characters/achilles/3d/AchillesLegacy2DBackend.tscn",
	"res://characters/achilles/3d/AchillesViewport3DBackend.tscn",
	"res://characters/achilles/3d/achilles_3d_visual.gd",
	"res://characters/achilles/3d/achilles_legacy_2d_backend.gd",
	"res://characters/achilles/3d/achilles_viewport_3d_backend.gd",
	"res://data/visuals/achilles/achilles_character_only_profile.tres",
	"res://data/visuals/achilles/achilles_visual_profile.gd",
]


func test_canonical_character_hashes_match() -> void:
	assert_eq(FileAccess.get_sha256(CHARACTER_BLEND_PATH).to_upper(), EXPECTED_BLEND_SHA)
	assert_eq(FileAccess.get_sha256(CHARACTER_GLB_PATH).to_upper(), EXPECTED_GLB_SHA)


func test_divergent_source_not_consumed() -> void:
	assert_false(_runtime_text().contains(DIVERGENT_SOURCE_SHA))
	assert_false(_runtime_text().contains("C:\\Blender_AI_Test\\input\\achilles.blend"))


func test_sword_source_not_consumed() -> void:
	var runtime_text := _runtime_text().to_lower()
	assert_false(runtime_text.contains(SWORD_SOURCE_SHA.to_lower()))
	assert_false(runtime_text.contains("art/source/weapons"))
	assert_false(runtime_text.contains("assets/weapons"))


func test_four_source_actions_unchanged() -> void:
	var manifest := _load_json(MASTER_MANIFEST_PATH)
	var before := manifest.actions.source_hashes_before as Dictionary
	var after := manifest.actions.master_hashes_after as Dictionary
	assert_eq(before.size(), 4)
	assert_eq(after.size(), 4)
	assert_eq(after, before)
	assert_false(bool(manifest.actions.source_actions_modified))


func test_hips_tracks_unchanged() -> void:
	var hips := _load_json(MASTER_MANIFEST_PATH).hips as Dictionary
	assert_true(bool(hips.exact))
	assert_eq(hips.per_action_master, hips.per_action_source)
	assert_eq(hips.policy, "ROOT_MOTION_UNCLASSIFIED")


func test_no_weapon_visual_profile_loaded() -> void:
	var profile := load(PROFILE_PATH) as AchillesVisualProfile
	assert_not_null(profile)
	assert_false(profile.equipment_enabled)
	assert_null(profile.weapon_profile)


func test_no_weapon_glb_loaded() -> void:
	var profile := load(PROFILE_PATH) as AchillesVisualProfile
	assert_eq(profile.character_asset_path, CHARACTER_GLB_PATH)
	assert_false(_runtime_text().to_lower().contains("assets/weapons"))


func test_no_weapon_child_under_hand() -> void:
	var scene := load("res://characters/achilles/3d/Achilles3DVisual.tscn") as PackedScene
	var visual := scene.instantiate() as Achilles3DVisual
	add_child_autofree(visual)
	assert_true(visual.initialize_from_profile(load(PROFILE_PATH) as AchillesVisualProfile))
	var skeleton := visual.get_skeleton()
	assert_not_null(skeleton)
	assert_true(skeleton.find_bone("mixamorig_LeftHand") >= 0)
	assert_true(skeleton.find_bone("mixamorig_RightHand") >= 0)
	assert_true(
		visual.find_children("*", "BoneAttachment3D", true, false).is_empty(),
		"The real imported rig must have no object attached to either hand bone.",
	)
	assert_null(visual.find_child("WeaponAdapterRoot", true, false))
	assert_null(visual.find_child("EquipmentController", true, false))
	var inspection := _load_json(GLB_INSPECTION_PATH)
	assert_eq(inspection.weapon_name_matches, [])
	assert_eq(inspection.mesh_count, 1.0)


func test_no_sword_texture_loaded() -> void:
	var runtime_text := _runtime_text().to_lower()
	for line in runtime_text.split("\n"):
		var names_sword := (
			"sword" in line or "epee" in line or "épée" in line
		)
		var names_texture := (
			".png" in line or ".jpg" in line or ".jpeg" in line
			or ".webp" in line or ".tga" in line
		)
		assert_false(names_sword and names_texture)


func test_no_equipment_controller_required() -> void:
	var profile := load(PROFILE_PATH) as AchillesVisualProfile
	assert_true(profile.is_character_only_valid())
	assert_false(_runtime_text().contains("EquipmentController"))


func test_other_runs_do_not_use_achilles_3d_profile() -> void:
	var inspected_run_count := 0
	for path in _files_recursive("res://data/runs"):
		if not path.ends_with(".tres"):
			continue
		var text := FileAccess.get_file_as_string(path)
		if not text.contains('script_class="RunData"') \
				or path == "res://data/runs/odyssey.tres":
			continue
		var run := load(path) as RunData
		assert_not_null(run, path)
		if run == null:
			continue
		inspected_run_count += 1
		var resolution = RunHeroResolver.resolve_runtime_hero_data(run, true)
		assert_not_null(resolution, path)
		for hero: UnitData in resolution.heroes:
			assert_ne(hero.get_effective_unit_id(), &"achilles", path)
			var visual_path := (
				hero.visual_scene.resource_path
				if hero.visual_scene != null else ""
			)
			assert_ne(
				visual_path,
				"res://characters/achilles/AchillesIsoUnitView.tscn",
				path,
			)
		if run.content_profile == null:
			continue
		for hero_profile: RunHeroProfile in run.content_profile.hero_profiles:
			if hero_profile == null:
				continue
			assert_ne(hero_profile.character_id, &"achilles", path)
			if hero_profile.base_unit_data != null:
				assert_ne(
					hero_profile.base_unit_data.get_effective_unit_id(),
					&"achilles",
					path,
				)
	# Loading the historical trio currently emits its baseline invalid-UID
	# warning.  Handle only that exact known diagnostic so the transitive scan
	# remains useful without laundering unrelated engine errors.
	for tracked_error: GutTrackedError in get_errors():
		if tracked_error.contains_text("invalid UID: uid://0flkpto1jkby") \
				and tracked_error.contains_text("Guerrier.tres"):
			tracked_error.handled = true
	assert_true(inspected_run_count >= 4)


func test_trio_visuals_unchanged() -> void:
	var expected := {
		"res://data/units/alliés/elfe.tres": "5F021CD36AD17C12353103B933EACF27E0002E5488364A4A93A7E2DD64A065FC",
		"res://data/units/alliés/mage.tres": "810A97E041CA7E92F1FD1338DB16D8D2034561B02BC550BE3E7E02BD3BFCDD88",
		"res://data/units/alliés/Guerrier.tres": "A31B1B9120089A4AACC08D1E60147C23E4A8E0E65D9AF021013CAE6AFF28A272",
	}
	for path in expected:
		assert_eq(FileAccess.get_sha256(path).to_upper(), expected[path], path)


func _load_json(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	assert_true(parsed is Dictionary, "Expected a JSON object at %s" % path)
	return parsed as Dictionary if parsed is Dictionary else {}


func _runtime_text() -> String:
	var combined := ""
	for path in RUNTIME_TEXT_PATHS:
		combined += FileAccess.get_file_as_string(path) + "\n"
	return combined


func _files_recursive(root: String) -> Array[String]:
	var result: Array[String] = []
	var directory := DirAccess.open(root)
	if directory == null:
		return result
	for file_name in directory.get_files():
		result.append(root.path_join(file_name))
	for directory_name in directory.get_directories():
		if directory_name.begins_with("."):
			continue
		result.append_array(_files_recursive(root.path_join(directory_name)))
	return result
