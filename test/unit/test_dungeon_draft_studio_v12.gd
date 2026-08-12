extends GutTest

const PRODUCTION_DESTINATION := "res://artifacts/studio_1_2/production_fixture"


func test_schema_v2_migration_and_shared_registries_are_deterministic() -> void:
	var legacy := _modular_arena().to_snapshot()
	legacy["schema_version"] = 1
	legacy.erase("visual_mode")
	legacy.erase("modular_visual_profile")
	legacy.erase("objectives")
	legacy.erase("decorations")
	var first := ArenaSchemaMigrator.migrate_snapshot(legacy)
	var second := ArenaSchemaMigrator.migrate_snapshot(legacy)
	assert_true(first.ok)
	assert_eq(first.snapshot, second.snapshot)
	assert_eq(first.snapshot.schema_version, ArenaDefinition.CURRENT_SCHEMA_VERSION)
	for terrain_id in [&"void", &"stone", &"water", &"ice", &"lava"]:
		assert_true(ArenaTerrainRegistry.has(terrain_id), str(terrain_id))
	for wall_id in [&"normal", &"fire", &"ice"]:
		assert_true(ArenaWallRegistry.has(wall_id), str(wall_id))
		assert_not_null(ArenaWallRegistry.config_for(wall_id))
	assert_eq(int(ArenaTerrainRegistry.get_entry(&"lava").cell_type), GridData.CellType.LAVA)


func test_dynamic_lab_round_trip_preserves_complete_arena_document() -> void:
	var scene := load("res://tools/labs/dynamic_arena/DynamicArenaLab.tscn") as PackedScene
	var lab := scene.instantiate() as DynamicArenaLab
	add_child_autofree(lab)
	await get_tree().process_frame
	lab.new_document(Vector2i(13, 9), "Round trip Lab", "round_trip_lab")
	assert_true(lab.set_cell_surface(Vector2i(2, 2), DynamicCellState.Surface.WATER))
	assert_true(lab.set_cell_surface(Vector2i(3, 2), DynamicCellState.Surface.ICE))
	assert_true(lab.set_cell_surface(Vector2i(4, 2), DynamicCellState.Surface.LAVA))
	assert_true(lab.set_cell_surface(Vector2i(5, 2), DynamicCellState.Surface.VOID))
	assert_not_null(lab.place_wall(Vector2i(6, 4), DynamicWall.WallVariant.BASE))
	assert_not_null(lab.place_wall(Vector2i(7, 4), DynamicWall.WallVariant.FIRE))
	assert_not_null(lab.place_wall(Vector2i(8, 4), DynamicWall.WallVariant.ICE))
	assert_true(lab.set_start_cell(Vector2i(1, 6)))
	assert_true(lab.set_destination(Vector2i(11, 2)))
	assert_true(lab.place_objective(Vector2i(8, 4), &"capture_rune"))
	assert_true(lab.place_decoration_anchor(Vector2i(9, 5), &"statue_anchor"))
	var source_fingerprint := ArenaEditSession.fingerprint(lab.working_arena.to_snapshot())
	var transfer := lab.send_to_studio()
	assert_true(transfer.ok, str(transfer))
	var loaded := ArenaLabTransferService.load_transfer(str(transfer.transfer_id))
	assert_true(loaded.ok, str(loaded))
	assert_eq(
		ArenaEditSession.fingerprint((loaded.arena as ArenaDefinition).to_snapshot()),
		source_fingerprint
	)
	assert_eq((loaded.arena as ArenaDefinition).grid_size, Vector2i(13, 9))
	assert_eq((loaded.arena as ArenaDefinition).objectives.size(), 1)
	assert_eq((loaded.arena as ArenaDefinition).decorations.size(), 1)
	assert_eq((loaded.arena as ArenaDefinition).obstacles.size(), 3)
	assert_true(ArenaLabTransferService.mark_imported(str(transfer.transfer_id)))


func test_integrated_lab_uses_exact_arena_session_and_single_history() -> void:
	var source := _modular_arena()
	var session := ArenaEditSession.new()
	assert_true(session.open(source, "", true, "integrated_lab_test"))
	var lab := (load("res://tools/labs/dynamic_arena/DynamicArenaLab.tscn") as PackedScene).instantiate() as DynamicArenaLab
	add_child_autofree(lab)
	await get_tree().process_frame
	assert_true(lab.bind_session(session, true))
	var history_before := session.history.get_history_entries().size()
	assert_true(lab.set_cell_surface(Vector2i(4, 4), DynamicCellState.Surface.WATER))
	assert_true(lab.working_arena == session.working_arena)
	assert_eq(session.history.get_history_entries().size(), history_before + 1)
	assert_true(session.history.undo())
	assert_eq(str(session.working_arena.get_cell_definition(Vector2i(4, 4)).terrain_id), "stone")
	assert_true(session.history.redo())
	assert_eq(str(session.working_arena.get_cell_definition(Vector2i(4, 4)).terrain_id), "water")


func test_runtime_preview_uses_shared_structural_signature_without_game_manager() -> void:
	var preview := ArenaRuntimePreview.new()
	preview.size = Vector2(1280, 720)
	add_child_autofree(preview)
	await get_tree().process_frame
	var source := _modular_arena()
	preview.set_arena(source)
	assert_true(preview.rebuild_now())
	await get_tree().process_frame
	assert_eq(
		preview.preview_signature,
		ArenaVisualAssembler.actual_visual_signature(preview.assembly)
	)
	assert_eq(
		int(preview.preview_signature.rendered_terrain_node_count),
		ArenaTerrainRenderPlanService.build(source).expected_terrain_cell_count
	)
	assert_true(preview.parity_with_runtime().ok)
	assert_null(preview.world_root.find_child("GameManager", true, false))
	assert_not_null(preview.world_root.find_child("SharedGridView", true, false))
	preview.set_view_mode(ArenaRuntimePreview.ViewMode.GAME)
	assert_true(preview.rebuild_now())
	assert_gt(preview.rebuild_count, 1)


func test_production_is_complete_reloadable_idempotent_and_portable() -> void:
	var source := _modular_arena()
	var initial_plan := ArenaProductionService.plan(source, PRODUCTION_DESTINATION)
	assert_true(initial_plan.ok, str(initial_plan))
	assert_true(initial_plan.can_produce, str(initial_plan.conflicts))
	var first := ArenaProductionService.produce(source, PRODUCTION_DESTINATION)
	assert_true(first.ok, str(first))
	assert_eq(str(first.status), "SALLE_PRETE")
	assert_true(first.resources_reloaded)
	assert_true(first.direct_test_available)
	for file_name in [
		"arena.tres", "modular_visual_profile.tres", "thumbnail.png",
		"preview_logic.png", "preview_art.png", "preview_game.png",
		"validation_report.json", "test_configuration.json",
		"production_manifest.json", "art_kit/map_reference.png",
		"art_kit/map_clean.png", "art_kit/map_logic.png", "art_kit/map_grid.png",
		"art_kit/map_game_preview.png", "art_kit/arena_definition.tres",
		"art_kit/art_brief.txt", "art_kit/validation_report.json",
	]:
		assert_true(FileAccess.file_exists(PRODUCTION_DESTINATION.path_join(file_name)), file_name)
	var first_manifest := FileAccess.get_file_as_string(
		PRODUCTION_DESTINATION.path_join("production_manifest.json")
	)
	assert_false("C:\\" in first_manifest)
	var first_hashes: Dictionary = (JSON.parse_string(first_manifest) as Dictionary).files
	var second_plan := ArenaProductionService.plan(source, PRODUCTION_DESTINATION)
	assert_true(second_plan.can_produce, str(second_plan.conflicts))
	assert_true(second_plan.creates.is_empty())
	var second := ArenaProductionService.produce(source, PRODUCTION_DESTINATION)
	assert_true(second.ok, str(second))
	assert_eq(second.manifest.files, first_hashes)
	var reloaded := ResourceLoader.load(
		PRODUCTION_DESTINATION.path_join("arena.tres"), "", ResourceLoader.CACHE_MODE_IGNORE
	) as ArenaDefinition
	assert_not_null(reloaded)
	assert_eq(reloaded.battle_scene.resource_path, ArenaDefinition.MODULAR_BATTLE_SCENE)
	assert_true(ArenaValidator.validate(reloaded, false).is_valid())


func test_production_plan_refuses_an_unowned_manual_file() -> void:
	var destination := "res://artifacts/studio_1_2/manual_conflict_fixture"
	var absolute := ProjectSettings.globalize_path(destination)
	assert_eq(DirAccess.make_dir_recursive_absolute(absolute), OK)
	var manual := ArenaDefinition.new()
	manual.set_identity("Travail manuel", "manual_do_not_overwrite")
	assert_eq(ResourceSaver.save(manual, destination.path_join("arena.tres")), OK)
	var production_plan := ArenaProductionService.plan(_modular_arena(), destination)
	assert_true(production_plan.ok)
	assert_false(production_plan.can_produce)
	assert_true(production_plan.conflicts.has(destination.path_join("arena.tres")))


func test_painted_and_hybrid_rooms_use_the_expected_runtime_scene() -> void:
	var painted := ArenaLegacyImporter.import_production(&"room_01_forest")
	assert_not_null(painted)
	var painted_result := ArenaProductionService.produce(
		painted, "res://artifacts/studio_1_2/production_painted_fixture"
	)
	assert_true(painted_result.ok, str(painted_result))
	var painted_reload := ResourceLoader.load(
		str(painted_result.arena_path), "", ResourceLoader.CACHE_MODE_IGNORE
	) as ArenaDefinition
	assert_eq(painted_reload.battle_scene.resource_path, ArenaDefinition.DEFAULT_BATTLE_SCENE)
	var hybrid := ArenaLegacyImporter.import_production(&"room_01_forest")
	hybrid.visual_mode = ArenaDefinition.VisualMode.HYBRID
	hybrid.modular_visual_profile = ArenaModularVisualProfile.new()
	ArenaTerrainRegistry.configure_cell(hybrid.ensure_cell(Vector2i(6, 4)), &"water")
	ArenaRuntimeBridge.sync_runtime_resources(hybrid)
	var hybrid_result := ArenaProductionService.produce(
		hybrid, "res://artifacts/studio_1_2/production_hybrid_fixture"
	)
	assert_true(hybrid_result.ok, str(hybrid_result))
	var hybrid_reload := ResourceLoader.load(
		str(hybrid_result.arena_path), "", ResourceLoader.CACHE_MODE_IGNORE
	) as ArenaDefinition
	assert_eq(hybrid_reload.battle_scene.resource_path, ArenaDefinition.DEFAULT_BATTLE_SCENE)
	assert_eq(hybrid_reload.visual_mode, ArenaDefinition.VisualMode.HYBRID)


func test_workspace_state_and_hosts_keep_one_workspace_instance() -> void:
	var workspace := StudioWorkspace.new()
	var embedded := EmbeddedStudioHost.new()
	add_child_autofree(embedded)
	await get_tree().process_frame
	embedded.attach_workspace(workspace)
	await get_tree().process_frame
	var identity := workspace.workspace_instance_id
	assert_true(workspace.get_parent() == embedded)
	for test_size in [
		Vector2(1280, 720), Vector2(1600, 900), Vector2(1920, 1080),
		Vector2(2560, 1440), Vector2(1280, 650),
	]:
		workspace.size = test_size
		workspace.arena_studio.size = Vector2(test_size.x, test_size.y - 72.0)
		workspace._apply_toolbar_responsive()
		workspace.arena_studio._apply_responsive_layout()
		await get_tree().process_frame
		assert_lte(
			workspace.detach_button.get_global_rect().end.x,
			workspace.get_global_rect().end.x + 1.0,
			"Le bouton de détachement doit rester visible à %s." % test_size
		)
	workspace.size = Vector2(1280, 720)
	workspace.arena_studio.size = Vector2(1280, 648)
	workspace.arena_studio.set_focus_map(true)
	await get_tree().process_frame
	var focus_ratio := workspace.arena_studio.canvas_occupation_ratio()
	assert_gte(focus_ratio.x, 0.75)
	assert_gte(focus_ratio.y, 0.75)
	workspace.arena_studio.set_focus_map(false)
	var window := NativeStudioWindowHost.new()
	add_child_autofree(window)
	await get_tree().process_frame
	window.attach_workspace(workspace)
	assert_true(workspace.get_parent() == window)
	assert_eq(window.workspace.workspace_instance_id, identity)
	assert_eq(window.min_size, NativeStudioWindowHost.MINIMUM_SIZE)
	var detached := window.detach_workspace()
	embedded.attach_workspace(detached)
	assert_true(workspace.get_parent() == embedded)
	assert_true(StudioUiStateService.save_state({
		"detached": true,
		"window": {"screen": 0, "position": [91, 73], "size": [1600, 950], "maximized": false},
		"workspace": {"preset": 2},
	}))
	var state := StudioUiStateService.load_state()
	assert_true(state.detached)
	assert_eq(Vector2i(state.window.size[0], state.window.size[1]), Vector2i(1600, 950))
	assert_eq(state.workspace.preset, 2)


func _modular_arena() -> ArenaDefinition:
	var arena := ArenaDefinition.new()
	arena.set_identity("Studio 1.2 Fixture", "studio_1_2_fixture")
	arena.visual_mode = ArenaDefinition.VisualMode.MODULAR
	arena.theme_id = &"dynamic_default"
	arena.modular_visual_profile = ArenaModularVisualProfile.new()
	arena.grid_size = Vector2i(12, 9)
	arena.grid_origin = Vector2(0, 0)
	arena.axis_x = Vector2(32, 16)
	arena.axis_y = Vector2(-32, 16)
	for y in range(arena.grid_size.y):
		for x in range(arena.grid_size.x):
			ArenaTerrainRegistry.configure_cell(arena.ensure_cell(Vector2i(x, y)), &"stone")
	ArenaEditingService.prepare_automatically(arena)
	var wall := ArenaObstacleDefinition.new()
	wall.obstacle_id = &"wall_fire_fixture"
	wall.cell = Vector2i(6, 4)
	wall.wall_id = &"fire"
	wall.wall_config = ArenaWallRegistry.config_for(&"fire")
	arena.obstacles.append(wall)
	var objective := ArenaObjectiveDefinition.new()
	objective.objective_id = &"capture_center"
	objective.cell = Vector2i(5, 4)
	arena.objectives.append(objective)
	ArenaRuntimeBridge.sync_runtime_resources(arena)
	return arena
