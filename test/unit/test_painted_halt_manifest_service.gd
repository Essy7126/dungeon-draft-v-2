extends GutTest

const Service := preload(
	"res://addons/dungeon_draft_arena_studio/halts/services/painted_halt_manifest_service.gd"
)

var fixture: String
var path: String
var source_path: String
var manifest: Dictionary


func before_each() -> void:
	fixture = "res://artifacts/dev/halt-native-fixtures/%d-%d" % [Time.get_ticks_usec(), randi()]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(fixture))
	path = fixture.path_join("map.json")
	source_path = fixture.path_join("original.png")
	var source := Image.create(100, 60, false, Image.FORMAT_RGB8)
	source.fill(Color(0.2, 0.5, 0.4))
	assert_eq(source.save_png(source_path), OK)
	manifest = {
		"schema_version": 1,
		"id": "test_halt_v1",
		"title": "Fixture",
		"kind": "sanctuary",
		"stage": "playable_study",
		"source": {
			"image": source_path,
			"size": [100, 60],
			"sha256": FileAccess.get_sha256(source_path),
		},
		"style": "res://data/halts/styles/roots_bronze_v1.json",
		"build_dir": fixture.path_join("built"),
		"world": {
			"width": 2000,
			"player_scale": 0.5,
			"speed": 195,
			"foot_clearance": 12,
			"spawn": [0.1, 0.1],
		},
		"navigation": { "outline": [[0, 0], [1, 0], [1, 1], [0, 1]], "obstacles": [] },
		"water": {
			"polygons": [[[0.1, 0.2], [0.9, 0.2], [0.9, 0.8], [0.1, 0.8]]],
			"exclusions": [],
		},
		"landmarks": [{ "id": "altar", "point": [0.5, 0.5] }],
	}


func test_canonical_hash_handles_git_line_endings_without_weakening_content_check() -> void:
	var lf := "{\n  \"title\": \"Émeraude\"\n}\n"
	assert_eq(Service.text_hash(lf), Service.text_hash("\ufeff" + lf.replace("\n", "\r\n")))
	assert_eq(Service.text_hash(lf), Service.text_hash(lf.replace("\n", "\r")))
	assert_ne(Service.text_hash(lf), Service.text_hash(lf.replace("Émeraude", "Forge")))
	assert_eq(Service.text_hash(lf), lf.sha256_text())


func test_native_masks_preserve_independent_channels_and_source_bytes() -> void:
	var source_hash := FileAccess.get_sha256(source_path)
	var exclusion := [[0.35, 0.3], [0.65, 0.3], [0.65, 0.7], [0.35, 0.7]]
	manifest.water.exclusions = [exclusion]
	manifest["cascades"] = [{ "polygon": exclusion, "splash": [0.5, 0.7], "width": 10 }]
	var prepared := Service.prepare_images(manifest)
	assert_true(prepared.ok, str(prepared.get("errors", [])))
	if not prepared.ok:
		return
	var materials: Image = prepared.materials
	assert_eq(materials.get_pixel(20, 30), Color(1, 0, 0, 0))
	assert_eq(materials.get_pixel(50, 30), Color(0, 1, 0, 0))
	assert_eq(FileAccess.get_sha256(source_path), source_hash)


func test_dry_forge_accepts_missing_optional_materials_and_review() -> void:
	manifest.erase("water")
	manifest.kind = "forge"
	var result := Service.prepare_images(manifest)
	assert_true(result.ok, str(result.get("errors", [])))
	if not result.ok:
		return
	assert_eq((result.materials as Image).get_pixel(50, 30), Color(0, 0, 0, 0))
	assert_eq((result.flow as Image).get_pixel(50, 30).a, 0.0)


func test_per_region_flow_encodes_direction_speed_and_exclusion() -> void:
	var polygon: Array = manifest.water.polygons.pop_back()
	manifest.water["regions"] = [{ "polygon": polygon, "direction": [-1, 0], "speed": 2 }]
	manifest.water.exclusions = [[[0.35, 0.3], [0.65, 0.3], [0.65, 0.7], [0.35, 0.7]]]
	var result := Service.prepare_images(manifest)
	assert_true(result.ok, str(result.get("errors", [])))
	if not result.ok:
		return
	var flow: Image = result.flow
	assert_almost_eq(flow.get_pixel(20, 30).r, 0.0, 0.005)
	assert_almost_eq(flow.get_pixel(20, 30).g, 0.5, 0.005)
	assert_almost_eq(flow.get_pixel(20, 30).b, 0.5, 0.005)
	assert_eq(flow.get_pixel(20, 30).a, 1.0)
	assert_eq(flow.get_pixel(50, 30).a, 0.0)


func test_save_prepares_coherent_build_and_rejects_external_edit() -> void:
	var result := Service.save_and_prepare(path, manifest)
	assert_true(result.ok, str(result.get("errors", [])))
	if not result.ok:
		return
	var first_hash := str(result.manifest_sha256)
	var build_path := str(manifest.build_dir).path_join("build.json")
	var build: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(build_path))
	assert_eq(build.manifest_sha256, Service.manifest_hash(path))
	assert_eq(build.manifest_hash_mode, "lf_utf8_v1")
	assert_eq(
		build.mask_sha256,
		FileAccess.get_sha256(str(manifest.build_dir).path_join("materials.png")),
	)
	assert_eq(
		build.flow_sha256,
		FileAccess.get_sha256(str(manifest.build_dir).path_join("flow.png")),
	)
	var settings := FileAccess.get_file_as_string(
		str(manifest.build_dir).path_join("materials.png.import")
	)
	assert_string_contains(settings, "process/fix_alpha_border=false")
	assert_string_contains(settings, "process/premult_alpha=false")
	var loaded := Service.load_manifest(path)
	assert_true(loaded.ok)
	assert_not_null(loaded.source_image)
	var external_text := FileAccess.get_file_as_string(path).replace(
		'"Fixture"',
		'"Changed elsewhere"',
	)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(external_text)
	file.close()
	var build_before := FileAccess.get_sha256(build_path)
	assert_false(Service.save_and_prepare(path, manifest, first_hash).ok)
	assert_eq(FileAccess.get_sha256(build_path), build_before)
	assert_eq(FileAccess.get_file_as_string(path), external_text)


func test_invalid_geometry_and_changed_source_never_install_build() -> void:
	manifest.navigation.outline = [[0, 0], [1, 1], [0, 1], [1, 0]]
	assert_false(Service.save_and_prepare(path, manifest).ok)
	assert_false(FileAccess.file_exists(path))
	manifest.navigation.outline = [[0, 0], [1, 0], [1, 1], [0, 1]]
	var image := Image.create(100, 60, false, Image.FORMAT_RGB8)
	image.fill(Color.RED)
	image.save_png(source_path)
	assert_false(Service.save_and_prepare(path, manifest).ok)
	assert_false(FileAccess.file_exists(str(manifest.build_dir).path_join("build.json")))


func test_plan_attach_is_byte_exact_keeps_geometry_and_refuses_replacement() -> void:
	manifest.source = { }
	manifest.stage = "planning"
	var plan := Service.save_plan(path, manifest)
	assert_true(plan.ok, str(plan.get("errors", [])))
	if not plan.ok:
		return
	var attached := Service.attach_source(path, manifest, source_path, plan.manifest_sha256)
	assert_true(attached.ok, str(attached.get("errors", [])))
	if not attached.ok:
		return
	assert_eq(attached.manifest.navigation, manifest.navigation)
	assert_eq(attached.manifest.stage, "calibration")
	assert_eq(
		FileAccess.get_file_as_bytes(str(attached.manifest.source.image)),
		FileAccess.get_file_as_bytes(source_path),
	)
	assert_false(
		Service.attach_source(path, attached.manifest, source_path, attached.manifest_sha256).ok
	)
	var loaded := Service.load_manifest(path)
	assert_true(loaded.ok, str(loaded.get("errors", [])))
	var reviewed: Dictionary = attached.manifest
	reviewed.stage = "playable_study"
	assert_true(Service.save_and_prepare(path, reviewed, attached.manifest_sha256).ok)


func test_bad_properties_and_source_output_aliases_are_rejected() -> void:
	var wrong := manifest.duplicate(true)
	wrong.water["regions"] = [
		{ "polygon": manifest.water.polygons[0], "direction": [0, 0], "speed": 1 }
	]
	assert_false(Service.validate(wrong).ok)
	wrong = manifest.duplicate(true)
	wrong.landmarks.append(wrong.landmarks[0].duplicate(true))
	assert_false(Service.validate(wrong).ok)
	wrong = manifest.duplicate(true)
	wrong.landmarks[0].point = [1.2, 0.5]
	assert_false(Service.validate(wrong).ok)
	wrong = manifest.duplicate(true)
	wrong["torches"] = [{ "point": [0.5, 0.5], "radius": [0, 0.1] }]
	assert_false(Service.validate(wrong).ok)
	wrong = manifest.duplicate(true)
	wrong.source.image = str(wrong.build_dir).path_join("materials.png")
	assert_false(Service.validate(wrong).ok)
	assert_false(Service.save_plan("res://../outside.json", manifest).ok)
	assert_false(Service.create_plan("../invalid", "Bad").ok)


func test_failed_native_install_rolls_back_manifest_and_completed_files() -> void:
	var result := Service.save_and_prepare(path, manifest)
	assert_true(result.ok, str(result.get("errors", [])))
	if not result.ok:
		return
	var first_hash := str(result.manifest_sha256)
	var mask_path := str(manifest.build_dir).path_join("materials.png")
	var build_path := str(manifest.build_dir).path_join("build.json")
	var mask_before := FileAccess.get_file_as_bytes(mask_path)
	var build_before := FileAccess.get_file_as_bytes(build_path)
	var flow_path := str(manifest.build_dir).path_join("flow.png")
	# A destination directory makes installation fail after earlier files changed.
	assert_eq(DirAccess.remove_absolute(ProjectSettings.globalize_path(flow_path)), OK)
	assert_eq(DirAccess.make_dir_absolute(ProjectSettings.globalize_path(flow_path)), OK)
	manifest.water.polygons = []
	var failed := Service.save_and_prepare(path, manifest, first_hash)
	assert_false(failed.ok)
	assert_true(failed.get("rollback_ok", false), str(failed.get("errors", [])))
	assert_eq(Service.manifest_hash(path), first_hash)
	assert_eq(FileAccess.get_file_as_bytes(mask_path), mask_before)
	assert_eq(FileAccess.get_file_as_bytes(build_path), build_before)
	assert_eq(FileAccess.get_sha256(source_path), str(manifest.source.sha256))


func test_saved_source_identity_cannot_be_changed_within_a_version() -> void:
	var result := Service.save_and_prepare(path, manifest)
	assert_true(result.ok)
	var alternate := fixture.path_join("different_original.png")
	var image := Image.create(100, 60, false, Image.FORMAT_RGB8)
	image.fill(Color.CORAL)
	image.save_png(alternate)
	manifest.source.image = alternate
	manifest.source.sha256 = FileAccess.get_sha256(alternate)
	assert_false(Service.save_and_prepare(path, manifest, result.manifest_sha256).ok)
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert_eq(saved.source.image, source_path)


func test_spatial_export_is_versioned_and_keeps_safe_labels() -> void:
	manifest.source = { }
	manifest.stage = "planning"
	manifest.landmarks[0]["title"] = "Autel <feu> & bronze"
	var plan_path := fixture.path_join("spatial_plan.svg")
	var exported := Service.export_plan(manifest, plan_path)
	assert_true(exported.ok, str(exported.get("errors", [])))
	var svg := FileAccess.get_file_as_string(plan_path)
	assert_string_contains(svg, "Autel &lt;feu&gt; &amp; bronze")
	assert_string_contains(svg, "<polygon")
	assert_false(Service.export_plan(manifest, "res://../outside.svg").ok)


func test_ambient_configuration_rejects_unhandled_materials_and_bad_positions() -> void:
	manifest["ambience"] = {
		"footsteps": "stone",
		"sources": [{ "kind": "fire", "point": [0.5, 0.4], "radius": 0.3, "gain_db": -17 }],
	}
	assert_true(Service.validate(manifest).ok)
	manifest.ambience.sources[0].point = [4, 0]
	assert_false(Service.validate(manifest).ok)
	manifest.ambience.sources[0].point = [0.5, 0.4]
	manifest.ambience.sources[0].kind = "unsupported"
	assert_false(Service.validate(manifest).ok)


func test_source_build_collision_is_rejected_even_with_windows_case_alias() -> void:
	var build_dir := str(manifest.build_dir)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(build_dir))
	var name := "Materials.png" if OS.get_name() == "Windows" else "materials.png"
	var collision := build_dir.path_join(name)
	assert_eq(
		DirAccess.copy_absolute(
			ProjectSettings.globalize_path(source_path),
			ProjectSettings.globalize_path(collision),
		),
		OK,
	)
	var source_bytes := FileAccess.get_file_as_bytes(collision)
	manifest.source.image = collision
	var result := Service.save_and_prepare(path, manifest)
	assert_false(result.ok)
	assert_eq(FileAccess.get_file_as_bytes(collision), source_bytes)
	assert_false(FileAccess.file_exists(path))


func test_relative_actor_height_validation_and_embedded_plan_reference() -> void:
	manifest.world.erase("player_scale")
	manifest.world.player_height_ratio = 0.24
	assert_true(Service.validate(manifest).ok)
	var exported := fixture.path_join("scale_plan.svg")
	assert_true(Service.export_plan(manifest, exported).ok)
	var svg := FileAccess.get_file_as_string(exported)
	assert_string_contains(svg, "data:image/png;base64,")
	assert_string_contains(svg, "24.0%")
	assert_string_contains(svg, 'viewBox="0 0 1600.000000 960.000000"')
	for invalid in [0, -0.2, 0.36, NAN, INF, "0.24"]:
		manifest.world.player_height_ratio = invalid
		assert_false(Service.validate(manifest).ok, "Invalid actor height must not reach prepare")
