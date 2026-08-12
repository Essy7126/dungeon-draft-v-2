extends GutTest

const ROUNDTRIP := "user://dungeon_draft_studio/tests/backdrop_roundtrip.tres"
const PRODUCTION_SOURCE := "user://dungeon_draft_studio/tests/backdrop_promotion/source.png"
const PRODUCTION_STAGING := "user://dungeon_draft_studio/tests/backdrop_promotion/staging"
const PRODUCTION_PUBLISHED := "user://dungeon_draft_studio/tests/backdrop_promotion/published"
var _staged_path := ""


func after_all() -> void:
	for path in [
		ROUNDTRIP,
		_staged_path,
		PRODUCTION_SOURCE,
		PRODUCTION_STAGING.path_join("assets/background.png"),
		PRODUCTION_STAGING.path_join("assets/foreground.png"),
		PRODUCTION_STAGING.path_join("assets/occlusion.png"),
	]:
		if not path.is_empty() and FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_01_catalog_discovers_greece_without_ui_hardcode() -> void:
	var matches := ArenaBackdropCatalogService.discover().filter(func(source):
		return source.source_id == &"greece"
	)
	assert_eq(matches.size(), 1)
	assert_eq(matches[0].background_path, "res://asset/map/painted/greece/greece.png")


func test_02_background_only_preserves_calibration() -> void:
	var arena := _fixture()
	var before := GridTransformSnapshot.from_arena(arena)
	var result := ArenaBackdropTransactionService.new().apply(
		arena, _greece(), ArenaBackdropTransactionService.CopyMode.BACKGROUND_ONLY
	)
	assert_true(result.ok)
	assert_true(before.is_equal_to(GridTransformSnapshot.from_arena(arena)))


func test_03_decor_calibration_camera_adopts_greek_values() -> void:
	var arena := _fixture()
	var source := _greece()
	var result := ArenaBackdropTransactionService.new().apply(
		arena, source, ArenaBackdropTransactionService.CopyMode.DECOR_CALIBRATION_CAMERA
	)
	assert_true(result.ok)
	assert_eq(arena.grid_origin, source.grid_origin)
	assert_eq(arena.camera_zoom, source.camera_zoom)


func test_04_full_pack_copies_foreground_and_occlusion() -> void:
	var arena := _fixture()
	var source := _greece()
	source.foreground_path = source.background_path
	source.occlusion_mask_path = source.background_path
	source.foreground_offset = Vector2(9, 7)
	source.foreground_scale = Vector2(0.8, 0.9)
	var result := ArenaBackdropTransactionService.new().apply(
		arena, source, ArenaBackdropTransactionService.CopyMode.FULL_VISUAL_PACK
	)
	assert_true(result.ok)
	assert_eq(arena.foreground_path, source.foreground_path)
	assert_eq(arena.foreground_offset, Vector2(9, 7))


func test_05_gameplay_fingerprint_is_identical_in_every_mode() -> void:
	for mode in ArenaBackdropTransactionService.CopyMode.values():
		var arena := _fixture()
		var before := ArenaSnapshotService.gameplay_fingerprint(arena)
		assert_true(ArenaBackdropTransactionService.new().apply(arena, _greece(), mode).ok)
		assert_eq(ArenaSnapshotService.gameplay_fingerprint(arena), before)


func test_06_cells_terrains_spawns_and_vortex_survive() -> void:
	var arena := _fixture()
	var snapshot := arena.to_snapshot()
	assert_true(ArenaBackdropTransactionService.new().apply(
		arena, _greece(), ArenaBackdropTransactionService.CopyMode.DECOR_CALIBRATION_CAMERA
	).ok)
	for field in ["cells", "spawns", "vortex_networks"]:
		assert_eq(arena.to_snapshot()[field], snapshot[field], field)


func test_07_dimensions_difference_is_reported_not_silently_rescaled() -> void:
	var report := ArenaBackdropTransactionService.new().inspect(
		_fixture(), _greece(), ArenaBackdropTransactionService.CopyMode.BACKGROUND_ONLY
	)
	assert_true(report.ok)
	assert_true(report.dimensions_differ)


func test_08_recovery_restores_previous_visual() -> void:
	var arena := _fixture()
	var previous := arena.background_path
	var transaction := ArenaBackdropTransactionService.new()
	assert_true(transaction.apply(
		arena, _greece(), ArenaBackdropTransactionService.CopyMode.BACKGROUND_ONLY
	).ok)
	assert_true(transaction.restore(arena))
	assert_eq(arena.background_path, previous)


func test_09_snapshot_supports_undo_redo() -> void:
	var arena := _fixture()
	var result := ArenaBackdropTransactionService.new().apply(
		arena, _greece(), ArenaBackdropTransactionService.CopyMode.DECOR_CALIBRATION_CAMERA
	)
	assert_true(arena.restore_snapshot(result.before))
	assert_ne(arena.background_path, _greece().background_path)
	assert_true(arena.restore_snapshot(result.after))
	assert_eq(arena.background_path, _greece().background_path)


func test_10_roundtrip_persists_visual_and_gameplay() -> void:
	var arena := _fixture()
	var gameplay := ArenaSnapshotService.gameplay_fingerprint(arena)
	assert_true(ArenaBackdropTransactionService.new().apply(
		arena, _greece(), ArenaBackdropTransactionService.CopyMode.DECOR_CALIBRATION_CAMERA
	).ok)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ROUNDTRIP.get_base_dir()))
	assert_eq(ResourceSaver.save(arena, ROUNDTRIP), OK)
	var loaded := ResourceLoader.load(ROUNDTRIP, "", ResourceLoader.CACHE_MODE_IGNORE) as ArenaDefinition
	assert_not_null(loaded)
	assert_eq(loaded.background_path, _greece().background_path)
	assert_eq(ArenaSnapshotService.gameplay_fingerprint(loaded), gameplay)


func test_11_external_image_is_staged_under_user() -> void:
	var external := ProjectSettings.globalize_path(_greece().background_path)
	var result := ArenaBackdropTransactionService.stage_external_image(external)
	assert_true(result.ok)
	_staged_path = str(result.staged_path)
	assert_true(_staged_path.begins_with("user://"))
	assert_true(FileAccess.file_exists(_staged_path))


func test_12_invalid_import_does_not_mutate_the_arena() -> void:
	var arena := _fixture()
	var before := arena.to_snapshot()
	var source := ArenaBackdropSourceDefinition.new()
	source.background_path = "res://missing/backdrop.png"
	assert_false(ArenaBackdropTransactionService.new().apply(
		arena, source, ArenaBackdropTransactionService.CopyMode.BACKGROUND_ONLY
	).ok)
	assert_eq(arena.to_snapshot(), before)


func test_13_catalog_contains_run_or_room_sources() -> void:
	var sources := ArenaBackdropCatalogService.discover()
	assert_true(sources.any(func(source):
		return not source.source_run_path.is_empty() or not source.source_arena_path.is_empty()
	))


func test_14_greek_calibration_is_invertible() -> void:
	var source := _greece()
	assert_true(GridTransformService.is_invertible(source.axis_x, source.axis_y))
	assert_gt(absf(source.axis_x.cross(source.axis_y)), 1.0)


func test_15_background_only_changes_visual_fingerprint() -> void:
	var arena := _fixture()
	var before := ArenaEditSession.fingerprint(arena.to_snapshot())
	assert_true(ArenaBackdropTransactionService.new().apply(
		arena, _greece(), ArenaBackdropTransactionService.CopyMode.BACKGROUND_ONLY
	).ok)
	assert_ne(ArenaEditSession.fingerprint(arena.to_snapshot()), before)


func test_16_source_summary_exposes_catalog_metadata() -> void:
	var summary := _greece().to_summary()
	for field in ["display_name", "source_image_size", "grid_size", "grid_angle_degrees", "theme_id"]:
		assert_true(summary.has(field), field)


func test_17_production_promotes_user_staging_instead_of_serializing_it() -> void:
	var image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.2, 0.4, 0.8, 1.0))
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(PRODUCTION_SOURCE.get_base_dir())
	)
	assert_eq(image.save_png(ProjectSettings.globalize_path(PRODUCTION_SOURCE)), OK)
	var clone := _fixture()
	clone.background_path = PRODUCTION_SOURCE
	clone.foreground_path = PRODUCTION_SOURCE
	clone.occlusion_mask_path = PRODUCTION_SOURCE
	var result := ArenaProductionService._write_runtime_assets(
		clone, PRODUCTION_STAGING, PRODUCTION_PUBLISHED, {}
	)
	assert_true(result.ok)
	assert_eq(clone.background_path, PRODUCTION_PUBLISHED.path_join("assets/background.png"))
	assert_eq(clone.foreground_path, PRODUCTION_PUBLISHED.path_join("assets/foreground.png"))
	assert_eq(clone.occlusion_mask_path, PRODUCTION_PUBLISHED.path_join("assets/occlusion.png"))
	assert_false(clone.background_path == PRODUCTION_SOURCE)
	assert_true(FileAccess.file_exists(PRODUCTION_STAGING.path_join("assets/background.png")))
	assert_true(FileAccess.file_exists(PRODUCTION_STAGING.path_join("assets/foreground.png")))
	assert_true(FileAccess.file_exists(PRODUCTION_STAGING.path_join("assets/occlusion.png")))


func test_18_canonical_serializer_rejects_unowned_user_visual_paths() -> void:
	var arena := _fixture()
	arena.background_path = "user://unowned/background.png"
	assert_eq(
		ArenaSerializer._materialize_staged_visual_assets(arena),
		ERR_INVALID_PARAMETER
	)
	arena.background_path = _greece().background_path
	arena.foreground_path = "user://unowned/foreground.png"
	assert_eq(
		ArenaSerializer._materialize_staged_visual_assets(arena),
		ERR_INVALID_PARAMETER
	)


func _greece() -> ArenaBackdropSourceDefinition:
	return ResourceLoader.load(
		"res://addons/dungeon_draft_arena_studio/catalog/backdrops/greece.tres",
		"", ResourceLoader.CACHE_MODE_IGNORE
	) as ArenaBackdropSourceDefinition


func _fixture() -> ArenaDefinition:
	var arena := ArenaDefinition.new()
	arena.set_identity("Backdrop fixture", "backdrop_fixture")
	arena.grid_size = Vector2i(4, 4)
	arena.source_image_size = Vector2i(640, 480)
	arena.background_path = "res://asset/map/painted/forest/forest_01.png"
	arena.grid_origin = Vector2(100, 80)
	arena.axis_x = Vector2(48, 24)
	arena.axis_y = Vector2(-48, 24)
	for y in range(4):
		for x in range(4):
			ArenaTerrainRegistry.configure_cell(arena.ensure_cell(Vector2i(x, y)), &"neutral")
	ArenaDynamicEditingService.place_spawn(arena, Vector2i.ZERO, ArenaSpawnDefinition.Kind.HERO_1)
	var network := ArenaVortexNetworkService.create_network(arena)
	ArenaVortexNetworkService.add_cell(arena, network.network_id, Vector2i(1, 1))
	ArenaRuntimeBridge.sync_runtime_resources(arena)
	return arena
