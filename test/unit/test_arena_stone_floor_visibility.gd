extends GutTest

const FOREST_PATH := "res://data/arenas/room_01_forest.tres"
const STONE_PATH := "res://tools/labs/dynamic_arena/assets/normalized/stone.png"
const FOREST_CELL := Vector2i(4, 0)
const ART_TEST_ROOT := "res://artifacts/studio_2_0/stone_floor_visibility"


func after_all() -> void:
	_remove_tree(ART_TEST_ROOT)


func test_real_forest_reproduces_hidden_normal_tile_before_all_defined() -> void:
	var source := load(FOREST_PATH) as ArenaDefinition
	assert_not_null(source)
	var source_fingerprint := ArenaEditSession.fingerprint(source.to_snapshot())
	var working := _forest_working_copy(
		ArenaModularVisualProfile.HybridFloorPolicy.NON_BASE_TERRAINS
	)
	var definition := working.get_cell_definition(FOREST_CELL)
	assert_eq(source.resource_path, FOREST_PATH)
	assert_true(working.resource_path.is_empty())
	assert_eq(working.visual_mode, ArenaDefinition.VisualMode.HYBRID)
	assert_not_null(working.modular_visual_profile)
	assert_eq(
		working.modular_visual_profile.hybrid_floor_policy,
		ArenaModularVisualProfile.HybridFloorPolicy.NON_BASE_TERRAINS
	)
	assert_eq(str(working.modular_visual_profile.base_terrain_id), "stone")
	assert_eq(str(definition.terrain_id), "normal")
	assert_eq(definition.cell_type, GridData.CellType.NORMAL)
	assert_true(definition.defined)
	assert_true(definition.playable)
	var registry_entry := ArenaTerrainRegistry.get_entry(definition.terrain_id)
	assert_eq(str(registry_entry.get("visual", "")), STONE_PATH)
	assert_not_null(ArenaTerrainRegistry.texture_for(definition.terrain_id))
	var entry := ArenaTerrainRenderPlanService.entry_for(working, FOREST_CELL)
	assert_false(entry.visible)
	assert_eq(str(entry.skip_reason), "hybrid_base_terrain")
	var plan := ArenaTerrainRenderPlanService.build(working)
	assert_false(plan.render_entries.any(func(value): return value.cell == FOREST_CELL))
	var canvas := ArenaStudioCanvas.new()
	add_child_autofree(canvas)
	canvas.set_arena(working)
	assert_true(canvas._terrain_entries.has(FOREST_CELL))
	assert_false(bool((canvas._terrain_entries[FOREST_CELL] as Dictionary).visible))
	assert_eq(ArenaEditSession.fingerprint(source.to_snapshot()), source_fingerprint)


func test_all_tactical_tiles_is_explicit_immediate_and_undoable_in_studio() -> void:
	var source := load(FOREST_PATH) as ArenaDefinition
	var source_fingerprint := ArenaEditSession.fingerprint(source.to_snapshot())
	var studio := ArenaStudioMain.new()
	add_child_autofree(studio)
	await get_tree().process_frame
	studio._set_arena(_forest_working_copy(
		ArenaModularVisualProfile.HybridFloorPolicy.NON_BASE_TERRAINS
	), false, "stone_floor_policy")
	studio.show_dynamic_construction()
	assert_true(studio.hybrid_floor_policy_panel.visible)
	var all_index := studio._hybrid_floor_policy_option_index(
		studio.hybrid_floor_policy_option,
		ArenaModularVisualProfile.HybridFloorPolicy.ALL_DEFINED
	)
	assert_gte(all_index, 0)
	assert_true(studio.hybrid_floor_policy_option.get_item_text(all_index).contains(
		"TOUTES LES DALLES TACTIQUES"
	))
	assert_eq(studio.history_entries().size(), 0)
	assert_true(studio.set_hybrid_floor_policy(
		ArenaModularVisualProfile.HybridFloorPolicy.ALL_DEFINED
	))
	assert_eq(
		studio.arena.modular_visual_profile.hybrid_floor_policy,
		ArenaModularVisualProfile.HybridFloorPolicy.ALL_DEFINED
	)
	var visible_entry := studio.canvas._terrain_entries[FOREST_CELL] as Dictionary
	assert_true(visible_entry.visible)
	assert_eq(str(visible_entry.texture_path), STONE_PATH)
	assert_eq(studio.history_entries().size(), 1)
	assert_true(studio.dynamic_document_label.text.contains("TOUTES LES DALLES TACTIQUES"))
	assert_true(studio.history_undo())
	assert_false(bool((studio.canvas._terrain_entries[FOREST_CELL] as Dictionary).visible))
	assert_true(studio.history_redo())
	assert_true(bool((studio.canvas._terrain_entries[FOREST_CELL] as Dictionary).visible))
	assert_eq(ArenaEditSession.fingerprint(source.to_snapshot()), source_fingerprint)


func test_painted_conversion_can_choose_all_tactical_tiles_without_touching_source() -> void:
	var source := load(FOREST_PATH) as ArenaDefinition
	var source_fingerprint := ArenaEditSession.fingerprint(source.to_snapshot())
	var studio := ArenaStudioMain.new()
	add_child_autofree(studio)
	await get_tree().process_frame
	studio._set_arena(source, false, "painted_all_tactical")
	studio.show_dynamic_construction()
	assert_true(studio.painted_dynamic_dialog.visible)
	var labels: Array[String] = []
	for child in studio.painted_dynamic_dialog.find_children("*", "Button", true, false):
		if child is Button:
			labels.append((child as Button).text)
	assert_true(labels.any(func(label): return label.contains("TOUTES LES DALLES TACTIQUES")))
	studio._convert_painted_to_hybrid_all()
	assert_eq(studio.arena.visual_mode, ArenaDefinition.VisualMode.HYBRID)
	assert_eq(
		studio.arena.modular_visual_profile.hybrid_floor_policy,
		ArenaModularVisualProfile.HybridFloorPolicy.ALL_DEFINED
	)
	assert_true(bool((studio.canvas._terrain_entries[FOREST_CELL] as Dictionary).visible))
	assert_eq(studio.history_entries().size(), 1)
	assert_eq(ArenaEditSession.fingerprint(source.to_snapshot()), source_fingerprint)


func test_art_game_runtime_and_production_use_real_stone_nodes() -> void:
	var working := _forest_working_copy(
		ArenaModularVisualProfile.HybridFloorPolicy.ALL_DEFINED
	)
	var expected_plan := ArenaTerrainRenderPlanService.build(working)
	assert_true(expected_plan.ok)
	assert_eq(expected_plan.expected_terrain_cell_count, 163)
	assert_eq(expected_plan.expected_by_terrain_id.get("normal", 0), 163)
	var preview := ArenaRuntimePreview.new()
	preview.size = Vector2(1280, 720)
	preview.show_characters = false
	add_child_autofree(preview)
	await get_tree().process_frame
	preview.set_arena(working)
	preview.set_view_mode(ArenaRuntimePreview.ViewMode.ART)
	assert_true(preview.rebuild_now())
	_assert_preview_stone(preview)
	preview.set_view_mode(ArenaRuntimePreview.ViewMode.GAME)
	assert_true(preview.rebuild_now())
	_assert_preview_stone(preview)
	var runtime_report := ArenaVisualAssembler.inspect(working)
	assert_true(runtime_report.valid, str(runtime_report.to_dict()))
	assert_eq(runtime_report.expected_terrain_cell_count, 163)
	assert_eq(runtime_report.rendered_terrain_node_count, 163)
	var production := ArenaProductionService.plan(
		working, ART_TEST_ROOT.path_join("production")
	)
	assert_true(production.ok)
	var production_report := production.visual_report as ArenaVisualAssemblyReport
	assert_true(production_report.valid, str(production_report.to_dict()))
	assert_eq(production_report.expected_terrain_cell_count, 163)
	assert_eq(production_report.rendered_terrain_node_count, 163)


func test_art_reimport_applies_the_selected_all_tactical_policy() -> void:
	_remove_tree(ART_TEST_ROOT)
	var arena := _small_modular_fixture()
	var validation := ArenaValidationReport.new()
	var exported := ArenaArtKitExporter.export_kit(arena, ART_TEST_ROOT, validation)
	assert_true(exported.ok, str(exported))
	assert_true(DirAccess.copy_absolute(
		ProjectSettings.globalize_path(ART_TEST_ROOT.path_join("reference_clean.png")),
		ProjectSettings.globalize_path(ART_TEST_ROOT.path_join("background.png"))
	) == OK)
	var destination := ART_TEST_ROOT.path_join("imported/background.png")
	var imported := ArenaArtRoundTripService.apply_reimport(
		arena,
		ART_TEST_ROOT,
		destination,
		"background.png",
		ArenaModularVisualProfile.HybridFloorPolicy.ALL_DEFINED
	)
	assert_true(imported.ok, str(imported))
	assert_eq(arena.visual_mode, ArenaDefinition.VisualMode.HYBRID)
	assert_not_null(arena.modular_visual_profile)
	assert_eq(
		arena.modular_visual_profile.hybrid_floor_policy,
		ArenaModularVisualProfile.HybridFloorPolicy.ALL_DEFINED
	)
	var stone := ArenaTerrainRenderPlanService.entry_for(arena, Vector2i.ZERO)
	assert_true(stone.visible)
	assert_eq(str(stone.texture_path), STONE_PATH)
	assert_eq(arena.grid_origin, Vector2(160.0, 32.0))
	assert_eq(arena.axis_x, Vector2(32.0, 16.0))
	assert_eq(arena.axis_y, Vector2(-32.0, 16.0))


func test_historical_profile_default_remains_non_base_and_round_trips_all() -> void:
	var historical := ArenaModularVisualProfile.from_dict({})
	assert_eq(
		historical.hybrid_floor_policy,
		ArenaModularVisualProfile.HybridFloorPolicy.NON_BASE_TERRAINS
	)
	var selected := ArenaModularVisualProfile.new()
	selected.hybrid_floor_policy = ArenaModularVisualProfile.HybridFloorPolicy.ALL_DEFINED
	var reloaded := ArenaModularVisualProfile.from_dict(selected.to_dict())
	assert_eq(
		reloaded.hybrid_floor_policy,
		ArenaModularVisualProfile.HybridFloorPolicy.ALL_DEFINED
	)
	assert_eq(str(reloaded.base_terrain_id), "stone")


func _forest_working_copy(policy: int) -> ArenaDefinition:
	var source := load(FOREST_PATH) as ArenaDefinition
	var working := ArenaDefinition.new()
	working.restore_snapshot(source.to_snapshot())
	working.visual_mode = ArenaDefinition.VisualMode.HYBRID
	working.modular_visual_profile = ArenaModularVisualProfile.new()
	working.modular_visual_profile.theme_id = working.theme_id
	working.modular_visual_profile.base_terrain_id = &"stone"
	working.modular_visual_profile.hybrid_floor_policy = policy
	ArenaRuntimeBridge.sync_runtime_resources(working)
	return working


func _small_modular_fixture() -> ArenaDefinition:
	var arena := ArenaDefinition.new()
	arena.set_identity("Stone art round-trip", "stone_art_round_trip")
	arena.visual_mode = ArenaDefinition.VisualMode.MODULAR
	arena.theme_id = &"dynamic_default"
	arena.modular_visual_profile = ArenaModularVisualProfile.new()
	arena.grid_size = Vector2i(3, 2)
	arena.source_image_size = Vector2i(320, 180)
	arena.background_path = "res://assets/ui/pixel_transparent.png"
	arena.grid_origin = Vector2(160.0, 32.0)
	arena.axis_x = Vector2(32.0, 16.0)
	arena.axis_y = Vector2(-32.0, 16.0)
	for y in range(arena.grid_size.y):
		for x in range(arena.grid_size.x):
			ArenaTerrainRegistry.configure_cell(
				arena.ensure_cell(Vector2i(x, y)),
				&"stone" if (x + y) % 2 == 0 else &"water"
			)
	ArenaRuntimeBridge.sync_runtime_resources(arena)
	return arena


func _assert_preview_stone(preview: ArenaRuntimePreview) -> void:
	var report := preview.assembly.report as ArenaVisualAssemblyReport
	assert_true(report.valid, str(report.to_dict()))
	assert_eq(report.rendered_terrain_node_count, 163)
	var renderer := preview.assembly.renderer as ArenaTerrainVisualRenderer
	assert_not_null(renderer)
	var node := renderer.node_for_cell(FOREST_CELL)
	assert_not_null(node)
	assert_eq(str(node.get_meta("terrain_id")), "normal")
	assert_eq(str(renderer.texture_for_cell(FOREST_CELL).resource_path), STONE_PATH)


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
