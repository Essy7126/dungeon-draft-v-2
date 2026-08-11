extends GutTest

const PRODUCTION_DESTINATION := "res://artifacts/studio_1_3_1/pipeline_repair_fixture"


func test_01_to_06_data_contract_and_undo_restore_terrain_id() -> void:
	var source := _terrain_fixture()
	var session := ArenaEditSession.new()
	assert_true(session.open(source, "", true, "pipeline_data"))
	var arena := session.working_arena
	var before := arena.to_snapshot().duplicate(true)
	assert_true(ArenaDynamicEditingService.paint_terrain(arena, Vector2i(0, 0), &"water"))
	assert_eq(str(arena.get_cell_definition(Vector2i(0, 0)).terrain_id), "water") # 1
	assert_eq(arena.get_cell_definition(Vector2i(0, 0)).cell_type, GridData.CellType.NORMAL) # 2
	assert_eq(arena.get_cell_definition(Vector2i(0, 1)).cell_type, GridData.CellType.NORMAL) # 3
	assert_eq(str(arena.get_cell_definition(Vector2i(0, 1)).terrain_id), "stone")
	assert_eq(arena.get_cell_definition(Vector2i(3, 0)).cell_type, GridData.CellType.WALL) # 4
	assert_eq(str(arena.get_cell_definition(Vector2i(3, 0)).terrain_id), "lava")
	var after := arena.to_snapshot().duplicate(true)
	assert_true(session.commit("Peindre eau", before, after))
	assert_true(session.history.undo())
	assert_eq(str(arena.get_cell_definition(Vector2i(0, 0)).terrain_id), "stone") # 6
	assert_true(session.history.redo())
	assert_eq(str(arena.get_cell_definition(Vector2i(0, 0)).terrain_id), "water")
	var void_entry := ArenaTerrainRenderPlanService.entry_for(arena, Vector2i(4, 0))
	assert_false(void_entry.visible) # 5
	assert_eq(str(void_entry.skip_reason), "cell_void")


func test_07_to_13_render_plan_policies_and_asset_errors() -> void:
	var arena := _terrain_fixture()
	var plan := ArenaTerrainRenderPlanService.build(arena)
	assert_true(plan.ok)
	assert_eq(plan.expected_terrain_cell_count, 16) # 7
	arena.visual_mode = ArenaDefinition.VisualMode.PAINTED
	plan = ArenaTerrainRenderPlanService.build(arena)
	assert_eq(plan.expected_terrain_cell_count, 0) # 8
	assert_true(plan.base_floor_intentionally_painted)
	arena.visual_mode = ArenaDefinition.VisualMode.HYBRID
	arena.modular_visual_profile.hybrid_floor_policy = ArenaModularVisualProfile.HybridFloorPolicy.NONE
	assert_eq(ArenaTerrainRenderPlanService.build(arena).expected_terrain_cell_count, 0) # 9
	arena.modular_visual_profile.hybrid_floor_policy = ArenaModularVisualProfile.HybridFloorPolicy.NON_BASE_TERRAINS
	plan = ArenaTerrainRenderPlanService.build(arena)
	assert_eq(plan.expected_terrain_cell_count, 12) # 10
	assert_false(plan.expected_by_terrain_id.has("stone"))
	arena.modular_visual_profile.hybrid_floor_policy = ArenaModularVisualProfile.HybridFloorPolicy.ALL_DEFINED
	assert_eq(ArenaTerrainRenderPlanService.build(arena).expected_terrain_cell_count, 16) # 11
	var definition := arena.get_cell_definition(Vector2i(0, 0))
	definition.terrain_id = &"terrain_inconnu"
	plan = ArenaTerrainRenderPlanService.build(arena)
	assert_false(plan.ok) # 12
	assert_true(_contains_prefix(plan.errors, "unknown_terrain"))
	definition.terrain_id = &"wall"
	definition.defined = true
	plan = ArenaTerrainRenderPlanService.build(arena)
	assert_false(plan.ok) # 13
	assert_true(_contains_prefix(plan.errors, "texture_missing:wall"))


func test_14_to_17_texture_identity_and_wall_layer_are_separate() -> void:
	var arena := _terrain_fixture(true)
	var plan := ArenaTerrainRenderPlanService.build(arena)
	var stone := ArenaTerrainRenderPlanService.entry_for(arena, Vector2i(0, 0))
	var water := ArenaTerrainRenderPlanService.entry_for(arena, Vector2i(1, 0))
	var ice := ArenaTerrainRenderPlanService.entry_for(arena, Vector2i(2, 0))
	var lava := ArenaTerrainRenderPlanService.entry_for(arena, Vector2i(3, 0))
	assert_ne(stone.texture_path, water.texture_path) # 14
	assert_true(str(lava.texture_path).ends_with("/lava.png")) # 15
	assert_false(str(lava.texture_path).contains("wall"))
	assert_true(str(ice.texture_path).ends_with("/ice.png")) # 16
	assert_eq(plan.expected_by_terrain_id.get("lava", 0), 4)
	var assembly := _assemble(arena)
	var report := assembly.report as ArenaVisualAssemblyReport
	assert_true(report.valid, str(report.to_dict()))
	assert_eq(report.rendered_terrain_node_count, 16)
	assert_eq(report.rendered_wall_count, 3) # 17
	assert_eq((assembly.renderer as ArenaTerrainVisualRenderer).node_for_cell(Vector2i(0, 0)).get_meta("renderer_layer"), &"terrain")
	for wall in assembly.walls:
		assert_eq((wall as DynamicWall).get_meta("renderer_layer"), &"wall")


func test_18_canvas_incrementally_refreshes_only_changed_entries() -> void:
	var arena := _terrain_fixture()
	var canvas := ArenaStudioCanvas.new()
	add_child_autofree(canvas)
	canvas.set_arena(arena)
	var untouched: Dictionary = canvas._terrain_entries[Vector2i(1, 1)]
	assert_eq(str((canvas._terrain_entries[Vector2i(0, 0)] as Dictionary).terrain_id), "stone")
	assert_true(ArenaDynamicEditingService.paint_terrain(arena, Vector2i(0, 0), &"water"))
	canvas.update_terrain_cells([Vector2i(0, 0)])
	assert_eq(str((canvas._terrain_entries[Vector2i(0, 0)] as Dictionary).terrain_id), "water") # 18
	assert_true(canvas._terrain_entries[Vector2i(1, 1)] == untouched)


func test_19_20_canvas_tracks_history_undo_and_redo() -> void:
	var studio := ArenaStudioMain.new()
	add_child_autofree(studio)
	await get_tree().process_frame
	studio._set_arena(_terrain_fixture(), true, "visual_history")
	var before := studio.arena.to_snapshot().duplicate(true)
	assert_true(ArenaDynamicEditingService.paint_terrain(studio.arena, Vector2i(0, 0), &"water"))
	assert_true(studio.edit_session.commit("Peindre eau", before, studio.arena.to_snapshot()))
	studio.canvas.update_terrain_cells([Vector2i(0, 0)])
	assert_true(studio.history_undo())
	assert_eq(str((studio.canvas._terrain_entries[Vector2i(0, 0)] as Dictionary).terrain_id), "stone") # 19
	assert_true(studio.history_redo())
	assert_eq(str((studio.canvas._terrain_entries[Vector2i(0, 0)] as Dictionary).terrain_id), "water") # 20


func test_21_22_brush_preview_is_read_only_and_visual_nodes_do_not_capture_input() -> void:
	var arena := _terrain_fixture()
	var canvas := ArenaStudioCanvas.new()
	add_child_autofree(canvas)
	canvas.set_arena(arena)
	var fingerprint := ArenaEditSession.fingerprint(arena.to_snapshot())
	canvas.set_brush_preview_terrain(&"lava")
	canvas._hovered = Vector2i(1, 1)
	canvas.queue_redraw()
	assert_eq(ArenaEditSession.fingerprint(arena.to_snapshot()), fingerprint) # 21
	var holder := Node2D.new()
	add_child_autofree(holder)
	var renderer := ArenaTerrainVisualRenderer.new()
	holder.add_child(renderer)
	renderer.configure(null, holder)
	renderer.render_plan(ArenaTerrainRenderPlanService.build(arena))
	var tile := renderer.node_for_cell(Vector2i(1, 1))
	assert_true(tile is Node2D)
	assert_eq(tile.find_children("*", "Control", true, false).size(), 0) # 22
	assert_true(tile.get_node("Visual") is Sprite2D)


func test_23_to_30_preview_uses_actual_floor_nodes_in_art_and_game() -> void:
	var preview := ArenaRuntimePreview.new()
	preview.size = Vector2(1280, 720)
	add_child_autofree(preview)
	await get_tree().process_frame
	var arena := _terrain_fixture(true)
	preview.set_arena(arena)
	assert_true(preview.rebuild_now())
	var report := preview.assembly.report as ArenaVisualAssemblyReport
	assert_eq(report.rendered_terrain_node_count, 16) # 23, 27
	assert_eq(report.rendered_wall_count, 3) # 24
	preview.set_view_mode(ArenaRuntimePreview.ViewMode.ART)
	assert_true(preview.rebuild_now())
	assert_eq((preview.assembly.report as ArenaVisualAssemblyReport).rendered_terrain_node_count, 16) # 25
	preview.set_view_mode(ArenaRuntimePreview.ViewMode.GAME)
	assert_true(preview.rebuild_now())
	assert_eq((preview.assembly.report as ArenaVisualAssemblyReport).rendered_terrain_node_count, 16) # 26
	var renderer := preview.assembly.renderer as ArenaTerrainVisualRenderer
	assert_true(str(renderer.texture_for_cell(Vector2i(1, 0)).resource_path).ends_with("/water.png")) # 28
	assert_true(preview.parity_with_runtime().ok) # 29
	renderer.node_for_cell(Vector2i(0, 0)).free()
	var broken := preview.parity_with_runtime()
	assert_false(broken.ok) # 30
	assert_true(_contains_prefix(broken.errors, "terrain_node_missing"))


func test_31_to_33_visual_modes_control_dynamic_entry() -> void:
	var studio := ArenaStudioMain.new()
	add_child_autofree(studio)
	await get_tree().process_frame
	studio._set_arena(_terrain_fixture(), true, "mode_modular")
	studio.show_dynamic_construction()
	assert_eq(studio.workspace_mode, ArenaStudioMain.WorkspaceMode.DYNAMIC_CONSTRUCTION) # 31
	var hybrid := _terrain_fixture()
	hybrid.visual_mode = ArenaDefinition.VisualMode.HYBRID
	studio._set_arena(hybrid, true, "mode_hybrid")
	studio.show_dynamic_construction()
	assert_eq(studio.workspace_mode, ArenaStudioMain.WorkspaceMode.DYNAMIC_CONSTRUCTION) # 32
	var painted := _terrain_fixture()
	painted.visual_mode = ArenaDefinition.VisualMode.PAINTED
	studio._set_arena(painted, false, "mode_painted")
	studio.show_dynamic_construction()
	assert_ne(studio.workspace_mode, ArenaStudioMain.WorkspaceMode.DYNAMIC_CONSTRUCTION) # 33
	assert_true(studio.painted_dynamic_dialog.visible)


func test_34_to_37_painted_conversion_is_a_single_undoable_working_copy() -> void:
	var original := _terrain_fixture()
	original.visual_mode = ArenaDefinition.VisualMode.PAINTED
	var original_fingerprint := ArenaEditSession.fingerprint(original.to_snapshot())
	var studio := ArenaStudioMain.new()
	add_child_autofree(studio)
	await get_tree().process_frame
	studio._set_arena(original, false, "painted_conversion")
	studio.show_dynamic_construction()
	studio._convert_painted_to_hybrid()
	assert_true(studio.arena != original) # 34
	assert_eq(ArenaEditSession.fingerprint(original.to_snapshot()), original_fingerprint)
	assert_eq(studio.arena.visual_mode, ArenaDefinition.VisualMode.HYBRID)
	assert_eq(studio.arena.modular_visual_profile.hybrid_floor_policy, ArenaModularVisualProfile.HybridFloorPolicy.NON_BASE_TERRAINS)
	assert_eq(studio.history_entries().size(), 1)
	assert_true(studio.history_undo()) # 35
	assert_eq(studio.arena.visual_mode, ArenaDefinition.VisualMode.PAINTED)
	studio._enter_painted_logic_only()
	assert_true(studio._painted_logic_only_active) # 36
	assert_true(studio.dynamic_document_label.text.contains("ne seront pas rendues"))
	assert_eq(original.visual_mode, ArenaDefinition.VisualMode.PAINTED) # 37


func test_38_to_48_lab_transfer_preserves_complete_visual_document() -> void:
	var scene := load("res://tools/labs/dynamic_arena/DynamicArenaLab.tscn") as PackedScene
	var lab := scene.instantiate() as DynamicArenaLab
	add_child_autofree(lab)
	await get_tree().process_frame
	lab.new_document(Vector2i(8, 6), "Pipeline Lab", "pipeline_lab") # 38
	assert_true(lab.set_cell_surface(Vector2i(1, 1), DynamicCellState.Surface.WATER))
	assert_true(lab.set_cell_surface(Vector2i(1, 1), DynamicCellState.Surface.STONE))
	assert_true(lab.set_cell_surface(Vector2i(2, 1), DynamicCellState.Surface.WATER))
	assert_true(lab.set_cell_surface(Vector2i(3, 1), DynamicCellState.Surface.ICE))
	assert_true(lab.set_cell_surface(Vector2i(4, 1), DynamicCellState.Surface.LAVA))
	assert_true(lab.set_cell_surface(Vector2i(5, 1), DynamicCellState.Surface.VOID)) # 39
	assert_not_null(lab.place_wall(Vector2i(2, 3), DynamicWall.WallVariant.BASE))
	assert_not_null(lab.place_wall(Vector2i(3, 3), DynamicWall.WallVariant.FIRE))
	assert_not_null(lab.place_wall(Vector2i(4, 3), DynamicWall.WallVariant.ICE)) # 40
	assert_true(lab.set_start_cell(Vector2i(1, 4)))
	assert_true(lab.set_destination(Vector2i(6, 1)))
	assert_true(lab.place_objective(Vector2i(5, 4), &"pipeline_objective")) # 41
	var source_fingerprint := ArenaEditSession.fingerprint(lab.working_arena.to_snapshot())
	var source_plan := ArenaTerrainRenderPlanService.build(lab.working_arena)
	var transfer := lab.send_to_studio()
	assert_true(transfer.ok, str(transfer))
	var manifest := transfer.manifest as Dictionary
	assert_eq(manifest.version, ArenaLabTransferService.MANIFEST_VERSION) # 42
	for field in ["schema_version", "arena_fingerprint", "thumbnail_path", "grid_size", "visual_mode", "theme_id", "terrain_counts", "wall_count", "spawn_count", "objective_count", "modular_profile_fingerprint", "validation_verdict"]:
		assert_true(manifest.has(field), field)
	var loaded := ArenaLabTransferService.load_transfer(str(transfer.transfer_id))
	assert_true(loaded.ok, str(loaded))
	var imported := loaded.arena as ArenaDefinition
	var studio := ArenaStudioMain.new()
	add_child_autofree(studio)
	await get_tree().process_frame
	studio._set_arena(imported, true, "lab_import_test")
	assert_eq(str(studio.arena.arena_id), "pipeline_lab") # 43
	assert_eq(ArenaEditSession.fingerprint(imported.to_snapshot()), source_fingerprint) # 44, 48
	assert_eq(
		ArenaEditSession.fingerprint(imported.modular_visual_profile.to_dict()),
		str(manifest.modular_profile_fingerprint)
	) # 45
	var imported_plan := ArenaTerrainRenderPlanService.build(imported)
	assert_eq(imported_plan.expected_by_terrain_id, source_plan.expected_by_terrain_id) # 46
	var preview := ArenaRuntimePreview.new()
	add_child_autofree(preview)
	await get_tree().process_frame
	preview.set_arena(imported)
	assert_true(preview.rebuild_now()) # 47
	assert_true(preview.parity_with_runtime().ok)
	assert_true(ArenaLabTransferService.delete_transfer(str(transfer.transfer_id)))


func test_49_production_refuses_a_missing_floor_asset() -> void:
	var arena := _production_fixture()
	var broken := arena.get_cell_definition(Vector2i(4, 3))
	broken.terrain_id = &"wall"
	broken.defined = true
	broken.cell_type = GridData.CellType.WALL
	var production_plan := ArenaProductionService.plan(
		arena, "res://artifacts/studio_1_3_1/missing_floor_fixture"
	)
	assert_true(production_plan.ok)
	assert_false(production_plan.can_produce) # 49
	assert_false((production_plan.visual_report as ArenaVisualAssemblyReport).valid)


func test_50_to_54_production_reports_floor_reloads_and_is_idempotent() -> void:
	var arena := _production_fixture()
	var production_plan := ArenaProductionService.plan(arena, PRODUCTION_DESTINATION)
	assert_true(production_plan.ok)
	assert_true(production_plan.can_produce, str(production_plan.conflicts)) # 50
	var first := ArenaProductionService.produce(arena, PRODUCTION_DESTINATION)
	assert_true(first.ok, str(first))
	var visual := first.visual_report as ArenaVisualAssemblyReport
	assert_true(visual.valid)
	assert_eq(visual.expected_terrain_cell_count, visual.rendered_terrain_node_count) # 51
	assert_gt(visual.rendered_terrain_node_count, 0)
	for name in ["preview_art.png", "preview_game.png"]:
		var image := Image.load_from_file(ProjectSettings.globalize_path(PRODUCTION_DESTINATION.path_join(name)))
		assert_not_null(image, name)
		assert_false(image.is_empty(), name) # 52
	var reloaded := ResourceLoader.load(
		PRODUCTION_DESTINATION.path_join("arena.tres"), "", ResourceLoader.CACHE_MODE_IGNORE
	) as ArenaDefinition
	assert_not_null(reloaded) # 53
	assert_true(ArenaVisualAssembler.inspect(reloaded).valid)
	var second := ArenaProductionService.produce(arena, PRODUCTION_DESTINATION)
	assert_true(second.ok, str(second)) # 54
	assert_true(bool(second.get("idempotent_reuse", false)))
	assert_eq(second.manifest.files, first.manifest.files)


func _terrain_fixture(with_walls := false) -> ArenaDefinition:
	var arena := ArenaDefinition.new()
	arena.set_identity("Terrain pipeline fixture", "terrain_pipeline_fixture")
	arena.visual_mode = ArenaDefinition.VisualMode.MODULAR
	arena.theme_id = &"dynamic_default"
	arena.modular_visual_profile = ArenaModularVisualProfile.new()
	arena.grid_size = Vector2i(5, 4)
	arena.grid_origin = Vector2.ZERO
	arena.axis_x = Vector2(32, 16)
	arena.axis_y = Vector2(-32, 16)
	var terrain_ids := [&"stone", &"water", &"ice", &"lava", &"void"]
	for y in range(arena.grid_size.y):
		for x in range(arena.grid_size.x):
			ArenaTerrainRegistry.configure_cell(
				arena.ensure_cell(Vector2i(x, y)), terrain_ids[x]
			)
	if with_walls:
		for index in range(3):
			var obstacle := ArenaObstacleDefinition.new()
			obstacle.obstacle_id = StringName("pipeline_wall_%d" % index)
			obstacle.cell = [Vector2i(0, 0), Vector2i(1, 1), Vector2i(2, 2)][index]
			obstacle.wall_id = [&"normal", &"fire", &"ice"][index]
			obstacle.wall_config = ArenaWallRegistry.config_for(obstacle.wall_id)
			arena.obstacles.append(obstacle)
	ArenaRuntimeBridge.sync_runtime_resources(arena)
	return arena


func _production_fixture() -> ArenaDefinition:
	var arena := ArenaDefinition.new()
	arena.set_identity("Pipeline production", "pipeline_production")
	arena.visual_mode = ArenaDefinition.VisualMode.MODULAR
	arena.theme_id = &"dynamic_default"
	arena.modular_visual_profile = ArenaModularVisualProfile.new()
	arena.grid_size = Vector2i(10, 8)
	arena.grid_origin = Vector2.ZERO
	arena.axis_x = Vector2(32, 16)
	arena.axis_y = Vector2(-32, 16)
	for y in range(arena.grid_size.y):
		for x in range(arena.grid_size.x):
			ArenaTerrainRegistry.configure_cell(arena.ensure_cell(Vector2i(x, y)), &"stone")
	ArenaEditingService.prepare_automatically(arena)
	ArenaDynamicEditingService.paint_terrain(arena, Vector2i(4, 3), &"water")
	ArenaDynamicEditingService.paint_terrain(arena, Vector2i(5, 3), &"ice")
	ArenaDynamicEditingService.place_wall(arena, Vector2i(4, 4), &"fire")
	var objective := ArenaObjectiveDefinition.new()
	objective.objective_id = &"pipeline_goal"
	objective.cell = Vector2i(5, 4)
	arena.objectives.append(objective)
	ArenaRuntimeBridge.sync_runtime_resources(arena)
	return arena


func _assemble(arena: ArenaDefinition) -> Dictionary:
	ArenaRuntimeBridge.sync_runtime_resources(arena)
	var grid := ArenaRuntimeBridge.build_grid(arena)
	var pathfinder := Pathfinder.new(grid)
	var owner := Node2D.new()
	add_child_autofree(owner)
	var grid_view := PaintedGridView.new()
	grid_view.configure(
		arena.painted_map_visual_data,
		arena.grid_layout,
		arena.hero_spawn_zone,
		arena.enemy_spawn_zone
	)
	grid_view.setup(grid)
	owner.add_child(grid_view)
	var world := Node2D.new()
	world.y_sort_enabled = true
	owner.add_child(world)
	return ArenaVisualAssembler.assemble(
		arena, grid, pathfinder, grid_view, world, owner, true
	)


func _contains_prefix(values: Array, prefix: String) -> bool:
	for value in values:
		if str(value).begins_with(prefix):
			return true
	return false
