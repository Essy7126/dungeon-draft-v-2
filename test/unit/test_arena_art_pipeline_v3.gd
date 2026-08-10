extends GutTest

const ROOT := "user://dungeon_draft_studio/tests/art_pipeline_v3"


func before_each() -> void:
	_remove_tree(ROOT)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ROOT))


func after_all() -> void:
	_remove_tree(ROOT)


func test_resolution_contract_separates_native_previews_thumbnail_and_runtime() -> void:
	for size in [
		Vector2i(1376, 768), Vector2i(1280, 720), Vector2i(1920, 1080),
		Vector2i(2560, 1440), Vector2i(1200, 896),
	]:
		var arena := _fixture(size)
		var contract := ArenaArtResolutionContract.from_arena(arena)
		assert_eq(contract.native_art_size, size)
		assert_eq(contract.reference_export_size, size)
		assert_eq(contract.preview_logic_size, Vector2i(1280, 720))
		assert_eq(contract.preview_art_size, Vector2i(1280, 720))
		assert_eq(contract.preview_game_size, Vector2i(1280, 720))
		assert_eq(contract.thumbnail_size, Vector2i(512, 288))
		assert_eq(contract.runtime_reference_viewport, Vector2i(1200, 896))
		assert_eq(contract.scaling_policy, &"NATIVE_NO_RESAMPLE")
		assert_true(contract.validation_errors().is_empty())


func test_affine_centres_corners_and_walls_match_runtime_projection() -> void:
	var arena := _fixture(Vector2i(640, 360))
	var control_cells := [Vector2i.ZERO, Vector2i(2, 1), Vector2i(4, 3)]
	for cell in control_cells:
		var native_center := GridTransformService.cell_to_position(
			cell, arena.grid_origin, arena.axis_x, arena.axis_y
		)
		var expected_center := arena.image_offset + native_center * arena.image_scale
		assert_almost_eq(
			ArenaArtProjectionRenderer.cell_center(arena, cell).x,
			expected_center.x, 0.0001
		)
		assert_almost_eq(
			ArenaArtProjectionRenderer.cell_center(arena, cell).y,
			expected_center.y, 0.0001
		)
		var runtime_corners := GridTransformService.cell_polygon(
			cell, arena.grid_origin, arena.axis_x, arena.axis_y
		)
		var exported_corners := ArenaArtProjectionRenderer.cell_polygon(arena, cell)
		for index in range(4):
			var expected := arena.image_offset + runtime_corners[index] * arena.image_scale
			assert_lte(exported_corners[index].distance_to(expected), 0.0001)
	var obstacle := arena.obstacles[0]
	var wall := ArenaArtProjectionRenderer.wall_polygon(arena, obstacle)
	assert_eq(wall.size(), 4)
	var cell_polygon := ArenaArtProjectionRenderer.cell_polygon(arena, obstacle.cell)
	assert_lte(wall[0].distance_to(cell_polygon[0]), 0.0001)
	assert_lte(wall[1].distance_to(cell_polygon[1]), 0.0001)


func test_masks_rasterize_affine_polygons_without_rectangular_fallback() -> void:
	var arena := _fixture(Vector2i(640, 360))
	var playable := ArenaArtProjectionRenderer.render_pass(arena, &"playable_mask")
	var center := ArenaArtProjectionRenderer.cell_center(arena, Vector2i(2, 1))
	assert_gt(playable.get_pixelv(Vector2i(roundi(center.x), roundi(center.y))).a, 0.95)
	# Le centre qu'aurait produit l'ancien maillage rectangulaire (marge 44)
	# est volontairement loin de la projection affine de cette fixture.
	assert_lt(playable.get_pixel(55, 55).a, 0.05)
	var wall_mask := ArenaArtProjectionRenderer.render_pass(arena, &"wall_mask")
	var wall_polygon := ArenaArtProjectionRenderer.wall_polygon(arena, arena.obstacles[0])
	var wall_center := Vector2.ZERO
	for point in wall_polygon:
		wall_center += point
	wall_center /= float(wall_polygon.size())
	assert_gt(wall_mask.get_pixelv(Vector2i(roundi(wall_center.x), roundi(wall_center.y))).a, 0.95)


func test_export_v3_has_exact_passes_roles_hashes_and_geometry() -> void:
	var arena := _fixture(Vector2i(640, 360))
	var validation := ArenaValidator.validate(arena, false)
	var exported := ArenaArtKitExporter.export_kit(
		arena, ROOT.path_join("kit"), validation
	)
	assert_true(exported.ok, str(exported))
	for file_name in [
		"reference_clean.png", "reference_grid.png", "reference_coordinates.png",
		"reference_gameplay.png", "reference_walls.png", "playable_mask.png",
		"void_mask.png", "wall_mask.png", "foreground_guide.png",
		"depth_guide.png", "alignment_markers.png", "map_game_preview.png",
	]:
		assert_true(FileAccess.file_exists(ROOT.path_join("kit").path_join(file_name)), file_name)
		var image := Image.load_from_file(ProjectSettings.globalize_path(
			ROOT.path_join("kit").path_join(file_name)
		))
		assert_eq(image.get_size(), Vector2i(640, 360), file_name)
	var manifest := JSON.parse_string(FileAccess.get_file_as_string(
		ROOT.path_join("kit/arena_art_manifest.json")
	)) as Dictionary
	assert_eq(int(manifest.schema_version), 3)
	assert_eq(str(manifest.studio_product_version), "2.0.0")
	assert_eq(str(manifest.reference_renderer_version), "affine_raster_v1")
	assert_eq(str(manifest.occlusion_policy), "ART_GUIDE_ONLY_FOREGROUND_POLYGON_RUNTIME")
	assert_eq(str(manifest.expected_occlusion_filename), "")
	assert_eq(str(manifest.arena_fingerprint), ArenaSnapshotService.arena_fingerprint(arena))
	assert_eq(str(manifest.gameplay_fingerprint), ArenaSnapshotService.gameplay_fingerprint(arena))
	var exported_size := (manifest.resolution_contract as Dictionary).reference_export_size as Array
	assert_eq(Vector2i(int(exported_size[0]), int(exported_size[1])), Vector2i(640, 360))
	assert_true((manifest.files as Dictionary).has("alignment_markers.png"))
	assert_eq(
		str(((manifest.files as Dictionary)["reference_grid.png"] as Dictionary).role),
		"guide_artistique_grille_affine_exacte"
	)
	assert_true(ArenaArtRoundTripService.validate_kit(ROOT.path_join("kit")).ok)


func test_v2_manifest_is_migrated_without_breaking_historical_reader() -> void:
	var arena := _fixture(Vector2i(640, 360))
	assert_true(ArenaArtKitExporter.export_kit(
		arena, ROOT.path_join("kit_v2"), ArenaValidator.validate(arena, false)
	).ok)
	var manifest_path := ROOT.path_join("kit_v2/arena_art_manifest.json")
	var manifest := JSON.parse_string(FileAccess.get_file_as_string(manifest_path)) as Dictionary
	manifest.schema_version = 2
	manifest.manifest_version = 2
	manifest.erase("resolution_contract")
	manifest.erase("studio_product_version")
	var file := FileAccess.open(manifest_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest, "  "))
	file.close()
	var validation := ArenaArtRoundTripService.validate_kit(ROOT.path_join("kit_v2"))
	assert_true(validation.ok, str(validation))
	assert_eq(int(validation.original_schema_version), 2)
	assert_eq(
		(validation.manifest.resolution_contract as Dictionary).reference_export_size,
		[640, 360]
	)


func test_import_requires_human_confirmation_and_rolls_back_partial_commit() -> void:
	var arena := _fixture(Vector2i(640, 360))
	var kit := ROOT.path_join("kit_import")
	assert_true(ArenaArtKitExporter.export_kit(
		arena, kit, ArenaValidator.validate(arena, false)
	).ok)
	assert_eq(DirAccess.copy_absolute(
		ProjectSettings.globalize_path(kit.path_join("reference_clean.png")),
		ProjectSettings.globalize_path(kit.path_join("background.png"))
	), OK)
	var plan := ArenaArtImportTransaction.prepare(arena, kit)
	assert_true(plan.ok, str(plan))
	var before := ArenaSnapshotService.room_fingerprint(arena)
	var destination := ROOT.path_join("runtime/background.png")
	var refused := ArenaArtImportTransaction.commit(
		arena, plan, destination, false
	)
	assert_false(refused.ok)
	assert_eq(str(refused.code), "ALIGNMENT_CONFIRMATION_REQUIRED")
	assert_eq(ArenaSnapshotService.room_fingerprint(arena), before)
	assert_false(FileAccess.file_exists(destination))
	var failed := ArenaArtImportTransaction.commit(
		arena, plan, destination, true,
		ArenaModularVisualProfile.HybridFloorPolicy.ALL_DEFINED,
		"after_background"
	)
	assert_false(failed.ok)
	assert_true(failed.rolled_back)
	assert_eq(ArenaSnapshotService.room_fingerprint(arena), before)
	assert_false(FileAccess.file_exists(destination))
	ArenaArtImportTransaction.cancel(plan)
	plan = ArenaArtImportTransaction.prepare(arena, kit)
	var committed := ArenaArtImportTransaction.commit(
		arena, plan, destination, true,
		ArenaModularVisualProfile.HybridFloorPolicy.ALL_DEFINED
	)
	assert_true(committed.ok, str(committed))
	assert_true(FileAccess.file_exists(destination))
	assert_eq(arena.background_path, destination)
	assert_eq(arena.visual_mode, ArenaDefinition.VisualMode.HYBRID)
	assert_eq(
		arena.modular_visual_profile.hybrid_floor_policy,
		ArenaModularVisualProfile.HybridFloorPolicy.ALL_DEFINED
	)
	assert_true(bool(committed.receipt.alignment_confirmed))
	assert_false(DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(str(plan.staging))))
	assert_eq(arena.occlusion_mask_path, "")


func _fixture(size: Vector2i) -> ArenaDefinition:
	var arena := ArenaDefinition.new()
	arena.set_identity("Art V3 fixture", "art_v3_fixture")
	arena.visual_mode = ArenaDefinition.VisualMode.MODULAR
	arena.theme_id = &"dynamic_default"
	arena.modular_visual_profile = ArenaModularVisualProfile.new()
	arena.source_image_size = size
	arena.grid_size = Vector2i(5, 4)
	arena.grid_origin = Vector2(300, 72)
	arena.axis_x = Vector2(34, 17)
	arena.axis_y = Vector2(-28, 21)
	arena.image_offset = Vector2(5, 7)
	arena.image_scale = Vector2(1.1, 1.1)
	for y in range(arena.grid_size.y):
		for x in range(arena.grid_size.x):
			ArenaTerrainRegistry.configure_cell(
				arena.ensure_cell(Vector2i(x, y)),
				&"water" if x == 2 and y == 1 else &"stone"
			)
	ArenaEditingService.prepare_automatically(arena)
	var obstacle := ArenaObstacleDefinition.new()
	obstacle.obstacle_id = &"wall_up"
	obstacle.cell = Vector2i(2, 2)
	obstacle.wall_id = &"normal"
	obstacle.wall_config = ArenaWallRegistry.config_for(&"normal")
	obstacle.orientation = Vector2i.UP
	arena.obstacles.append(obstacle)
	var objective := ArenaObjectiveDefinition.new()
	objective.objective_id = &"centre"
	objective.cell = Vector2i(3, 2)
	arena.objectives.append(objective)
	return arena


func _remove_tree(path: String) -> bool:
	var absolute := ProjectSettings.globalize_path(path)
	var directory := DirAccess.open(absolute)
	if directory == null:
		return true
	for file_name in directory.get_files():
		DirAccess.remove_absolute(absolute.path_join(file_name))
	for child in directory.get_directories():
		_remove_tree(path.path_join(child))
	return DirAccess.remove_absolute(absolute) == OK
