extends GutTest

const SERIALIZATION_PATH := "user://dungeon_draft_studio/tests/removed_cell_topology/arena.tres"

var _direct_requests: Array[Dictionary] = []


func after_each() -> void:
	for request in _direct_requests:
		ArenaDirectTestService.cleanup_context(request)
	_direct_requests.clear()
	ArenaTerrainRenderPlanService.clear_cache()
	ArenaVisualAssembler.clear_inspection_cache()


func test_removed_void_border_blocked_and_playable_are_distinct_exact_sets() -> void:
	var arena := _full_arena(Vector2i(5, 4))
	var removed := Vector2i(0, 0)
	var explicit_void := Vector2i(2, 1)
	var border := Vector2i(4, 0)
	var blocked := Vector2i(3, 2)
	assert_true(ArenaEditingService.set_cell_state(arena, removed, &"remove"))
	assert_true(ArenaDynamicEditingService.paint_terrain(arena, explicit_void, &"void"))
	var border_definition := arena.get_cell_definition(border)
	border_definition.border = true
	border_definition.playable = false
	var obstacle := ArenaObstacleDefinition.new()
	obstacle.cell = blocked
	obstacle.apply_preset(ArenaObstacleDefinition.Preset.FULL_WALL)
	arena.obstacles.append(obstacle)
	var signature := ArenaTopologySignatureService.build(arena)
	assert_false(signature.declared_cells.has("0,0"))
	assert_true(signature.removed_cells.has("0,0"))
	assert_true(signature.void_cells.has("0,0"))
	assert_true(signature.declared_cells.has("2,1"))
	assert_false(signature.defined_cells.has("2,1"))
	assert_true(signature.void_cells.has("2,1"))
	assert_true(signature.border_cells.has("4,0"))
	assert_true(signature.visible_floor_cells.has("4,0"))
	assert_false(signature.playable_cells.has("4,0"))
	assert_true(signature.blocked_cells.has("3,2"))
	assert_true(signature.visible_floor_cells.has("3,2"))
	assert_false(signature.playable_cells.has("3,2"))
	assert_true(signature.playable_cells.has("1,1"))
	assert_eq(signature.hashes.visible_floor_cells, signature.visible_floor_hash)


func test_irregular_14_by_14_fixture_has_12_absent_8_void_and_20_borders() -> void:
	var fixture := _irregular_14_by_14()
	var arena := fixture.arena as ArenaDefinition
	var signature := ArenaTopologySignatureService.build(arena)
	assert_eq(signature.counts.removed_cells, 12)
	assert_eq(signature.counts.void_cells, 20)
	assert_eq(signature.counts.border_cells, 20)
	assert_eq(signature.counts.declared_cells, 184)
	for key in fixture.absent:
		assert_false(signature.declared_cells.has(key))
	for key in fixture.explicit_void:
		assert_true(signature.declared_cells.has(key))
		assert_true(signature.void_cells.has(key))
	assert_eq(arena.get_cell_definition(Vector2i(6, 6)).terrain_id, &"water")
	assert_false(signature.declared_cells.has("6,7"))


func test_remove_tool_rectangle_brush_and_right_click_contract_remove_definitions() -> void:
	var arena := _full_arena(Vector2i(6, 4))
	var tool_cell := Vector2i(1, 1)
	var rectangle := [Vector2i(2, 1), Vector2i(3, 1), Vector2i(2, 2), Vector2i(3, 2)]
	var brush := [Vector2i(4, 1), Vector2i(4, 2)]
	assert_true(ArenaEditingService.set_cell_state(arena, tool_cell, &"remove"))
	for cell in rectangle:
		assert_true(ArenaEditingService.set_cell_state(arena, cell, &"remove"))
	for cell in brush:
		assert_true(ArenaEditingService.set_cell_state(arena, cell, &"remove"))
	# L'inversion/clic droit de l'outil Ajouter emploie le meme etat "remove".
	var right_click := Vector2i(5, 2)
	assert_true(ArenaEditingService.set_cell_state(arena, right_click, &"remove"))
	for cell in [tool_cell, right_click] + rectangle + brush:
		assert_null(arena.get_cell_definition(cell))


func test_erase_cell_cleans_obstacle_spawns_objective_and_decoration() -> void:
	var arena := _full_arena(Vector2i(4, 4))
	var cell := Vector2i(2, 2)
	var obstacle := ArenaObstacleDefinition.new()
	obstacle.cell = cell
	arena.obstacles.append(obstacle)
	var hero := ArenaSpawnDefinition.new()
	hero.kind = ArenaSpawnDefinition.Kind.HERO_1
	hero.cell = cell
	arena.spawns.append(hero)
	var enemy := ArenaSpawnDefinition.new()
	enemy.kind = ArenaSpawnDefinition.Kind.ENEMY
	enemy.cell = cell
	arena.spawns.append(enemy)
	var objective := ArenaObjectiveDefinition.new()
	objective.cell = cell
	arena.objectives.append(objective)
	var decoration := ArenaDecorationDefinition.new()
	decoration.cell = cell
	arena.decorations.append(decoration)
	assert_true(arena.erase_cell(cell))
	assert_null(arena.get_cell_definition(cell))
	assert_null(arena.obstacle_at(cell))
	assert_true(arena.spawns_at(cell).is_empty())
	assert_true(arena.objectives.all(func(value): return value.cell != cell))
	assert_true(arena.decorations.all(func(value): return value.cell != cell))


func test_snapshot_restore_keeps_exactly_120_cells_in_14_by_14() -> void:
	var arena := _empty_modular_arena(Vector2i(14, 14))
	for index in range(120):
		var cell := Vector2i(index % 14, index / 14)
		ArenaTerrainRegistry.configure_cell(arena.ensure_cell(cell), &"stone")
	var snapshot := arena.to_snapshot()
	assert_eq((snapshot.cells as Array).size(), 120)
	var before := ArenaTopologySignatureService.build(arena)
	var restored := ArenaDefinition.new()
	assert_true(restored.restore_snapshot(snapshot))
	var after := ArenaTopologySignatureService.build(restored)
	assert_eq(restored.cells.size(), 120)
	assert_eq(before.declared_cells, after.declared_cells)
	assert_eq(before.topology_hash, after.topology_hash)
	assert_eq(after.counts.removed_cells, 76)


func test_save_reload_ignore_deep_preserves_sparse_topology_and_fingerprint() -> void:
	var arena := _full_arena(Vector2i(7, 5))
	var removed := Vector2i(3, 2)
	arena.erase_cell(removed)
	var absolute := ProjectSettings.globalize_path(SERIALIZATION_PATH)
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	assert_eq(ResourceSaver.save(arena, SERIALIZATION_PATH), OK)
	var reloaded := ResourceLoader.load(
		SERIALIZATION_PATH, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as ArenaDefinition
	assert_not_null(reloaded)
	assert_null(reloaded.get_cell_definition(removed))
	assert_eq(
		ArenaTopologySignatureService.build(arena).topology_hash,
		ArenaTopologySignatureService.build(reloaded).topology_hash
	)
	assert_eq(
		ArenaSnapshotService.arena_fingerprint(arena),
		ArenaSnapshotService.arena_fingerprint(reloaded)
	)


func test_runtime_projection_maps_removed_and_void_to_noninteractive_holes_without_surfaces() -> void:
	var arena := _full_arena(Vector2i(6, 4))
	var removed := Vector2i(1, 1)
	var explicit_void := Vector2i(4, 2)
	arena.erase_cell(removed)
	ArenaDynamicEditingService.paint_terrain(arena, explicit_void, &"void")
	ArenaRuntimeBridge.sync_runtime_resources(arena)
	var state := ArenaRuntimeProjectionService.build(arena)
	assert_not_null(state)
	for cell in [removed, explicit_void]:
		assert_eq(state.layout.symbol_at(cell), RoomGridLayout.VOID)
		assert_eq(state.grid.get_type(cell), GridData.CellType.HOLE)
		assert_false(state.grid.is_walkable(cell))
		assert_false(state.grid.is_terrain_interactable(cell))
		assert_false(state.surface_service.has_state(cell))
		assert_false(state.hero_spawns.has(cell))
		assert_false(state.enemy_spawns.has(cell))
	var parity := ArenaRuntimeProjectionService.parity_report(arena, state)
	assert_true(parity.ok, str(parity))
	assert_true(parity.runtime_hole_cells.has("1,1"))
	assert_true(parity.runtime_hole_cells.has("4,2"))
	assert_true(parity.unexpected_surface_cells.is_empty())


func test_render_plan_never_falls_back_to_stone_for_removed_or_void_cells() -> void:
	var arena := _full_arena(Vector2i(6, 4))
	var removed := Vector2i(1, 1)
	var explicit_void := Vector2i(2, 1)
	var border := Vector2i(0, 0)
	var blocked := Vector2i(3, 1)
	arena.erase_cell(removed)
	ArenaDynamicEditingService.paint_terrain(arena, explicit_void, &"void")
	arena.get_cell_definition(border).border = true
	arena.get_cell_definition(border).playable = false
	arena.get_cell_definition(blocked).playable = false
	var plan := ArenaTerrainRenderPlanService.build(arena)
	assert_true(plan.ok, str(plan.errors))
	assert_false(plan.expected_floor_cells.has("1,1"))
	assert_false(plan.expected_floor_cells.has("2,1"))
	assert_true(plan.expected_floor_cells.has("0,0"))
	assert_true(plan.expected_floor_cells.has("3,1"))
	assert_eq(
		ArenaTerrainRenderPlanService.entry_for(arena, removed).skip_reason,
		&"cell_undefined"
	)
	var void_entry := ArenaTerrainRenderPlanService.entry_for(arena, explicit_void)
	assert_false(void_entry.visible)
	assert_eq(void_entry.skip_reason, &"cell_void")
	assert_eq(void_entry.resolved_texture_path, "")
	assert_true(void_entry.source_definition_present)
	assert_eq(void_entry.topology_state, &"void")


func test_incremental_renderer_removes_old_minus_new_and_clears_coordinate_cache() -> void:
	var arena := _full_arena(Vector2i(5, 4))
	var removed := Vector2i(2, 2)
	ArenaRuntimeBridge.sync_runtime_resources(arena)
	var grid := ArenaRuntimeBridge.build_grid(arena)
	var owner := Node2D.new()
	add_child_autofree(owner)
	var grid_view := PaintedGridView.new()
	grid_view.configure(
		arena.painted_map_visual_data, arena.grid_layout,
		arena.hero_spawn_zone, arena.enemy_spawn_zone
	)
	grid_view.setup(grid)
	owner.add_child(grid_view)
	var floor := Node2D.new()
	floor.name = "ArenaTilesLayer"
	owner.add_child(floor)
	var renderer := ArenaTerrainVisualRenderer.new()
	owner.add_child(renderer)
	renderer.configure(grid_view, floor)
	renderer.render_plan(ArenaTerrainRenderPlanService.build(arena))
	assert_not_null(renderer.node_for_cell(removed))
	arena.erase_cell(removed)
	var next_plan := ArenaTerrainRenderPlanService.build(arena)
	renderer.update_cells(next_plan.entries)
	assert_null(renderer.node_for_cell(removed))
	var actual := renderer.actual_render_report()
	assert_false(actual.cells.has("2,2"))
	assert_false(actual.cache_cells.has("2,2"))
	assert_eq(actual.rendered_terrain_node_count, next_plan.expected_floor_cells.size())
	for value in actual.cells.values():
		assert_eq(value.renderer_role, "arena_floor")
		assert_eq(value.topology_hash, next_plan.topology_hash)
	renderer.clear()
	assert_eq(renderer.actual_render_report().texture_cache_size, 0)


func test_logic_overlay_outlines_holes_without_filling_removed_cells() -> void:
	var arena := _full_arena(Vector2i(5, 4))
	var removed := Vector2i(1, 1)
	arena.erase_cell(removed)
	ArenaRuntimeBridge.sync_runtime_resources(arena)
	var view := PaintedGridView.new()
	add_child_autofree(view)
	view.configure(
		arena.painted_map_visual_data, arena.grid_layout,
		arena.hero_spawn_zone, arena.enemy_spawn_zone
	)
	view.setup(ArenaRuntimeBridge.build_grid(arena))
	view.set_render_options(false, true, false, false)
	view.set_debug_layers(true, true, true, false, false)
	var report := view.render_option_report()
	assert_true(report.draw_logic_types)
	assert_true(report.draw_void_cells)
	assert_true(report.draw_grid_lines)
	assert_false(report.filled_cells.has("1,1"))


func test_art_and_game_preview_remove_a_tile_after_first_rebuild_in_same_viewport() -> void:
	var arena := _full_arena(Vector2i(5, 4))
	var removed := Vector2i(2, 2)
	var preview := ArenaRuntimePreview.new()
	preview.size = Vector2(960, 540)
	add_child_autofree(preview)
	await wait_process_frames(2)
	preview.set_arena(arena)
	preview.set_view_mode(ArenaRuntimePreview.ViewMode.ART)
	assert_true(preview.rebuild_now())
	assert_true((preview.preview_signature.terrains as Dictionary).has("2,2"))
	arena.erase_cell(removed)
	assert_true(preview.rebuild_now())
	assert_false((preview.preview_signature.terrains as Dictionary).has("2,2"))
	assert_true(preview.preview_signature.removed_cells_rendered.is_empty())
	preview.set_view_mode(ArenaRuntimePreview.ViewMode.GAME)
	assert_true(preview.rebuild_now())
	assert_false((preview.preview_signature.terrains as Dictionary).has("2,2"))
	assert_true(preview.preview_signature.unexpected_cells.is_empty())


func test_floor_parity_compares_coordinates_not_only_equal_counts() -> void:
	var report := ArenaTopologyParityReport.compare_floor_sets(
		["0,0", "1,0"], ["0,0", "2,0"], ["2,0"]
	)
	assert_false(report.valid)
	assert_eq(report.missing_cells, ["1,0"])
	assert_eq(report.unexpected_cells, ["2,0"])
	assert_eq(report.removed_cells_rendered, ["2,0"])
	assert_ne(report.expected_floor_hash, report.rendered_floor_hash)


func test_direct_test_uses_new_generation_and_identical_topology_hashes() -> void:
	var arena := _full_arena(Vector2i(6, 4))
	arena.erase_cell(Vector2i(2, 2))
	var first := ArenaDirectTestService.prepare(arena, null, &"no_characters")
	assert_true(first.ok, str(first))
	if not first.get("ok", false):
		return
	_direct_requests.append(first.request)
	assert_eq(first.request.contract_version, 3)
	assert_eq(first.working_topology_hash, first.temporary_topology_hash)
	assert_eq(first.working_topology_hash, first.runtime_topology_hash)
	assert_eq(first.expected_floor_hash, ArenaTopologySignatureService.hash_keys(
		first.expected_floor_cells
	))
	assert_false(first.expected_floor_cells.has("2,2"))
	assert_true(first.removed_cells.has("2,2"))
	var first_path := str(first.arena_path)
	var second := ArenaDirectTestService.prepare(arena, null, &"no_characters")
	assert_true(second.ok, str(second))
	if not second.get("ok", false):
		return
	_direct_requests.append(second.request)
	assert_ne(first.generation_id, second.generation_id)
	assert_ne(first.arena_path, second.arena_path)
	assert_false(FileAccess.file_exists(first_path))
	assert_true(FileAccess.file_exists(second.arena_path))
	assert_false(str(second.arena_path).begins_with("res://data/arenas/produced/"))
	var runner: Node = (load(
		"res://addons/dungeon_draft_arena_studio/test/arena_studio_test_runner.gd"
	) as GDScript).new()
	var consumed := runner.call("_load_request") as Dictionary
	assert_eq(consumed.generation_id, second.generation_id)
	assert_true(consumed.request_consumed_once)
	assert_false(FileAccess.file_exists(ArenaDirectTestService.REQUEST_PATH))
	assert_true((runner.call("_load_request") as Dictionary).is_empty())
	runner.free()


func test_edit_session_generation_invalidates_certificates_across_undo_redo() -> void:
	var source := _full_arena(Vector2i(5, 4))
	var session := ArenaEditSession.new()
	assert_true(session.open(source, "", false, "topology_generation"))
	var before := session.working_arena.to_snapshot()
	assert_true(session.working_arena.erase_cell(Vector2i(2, 2)))
	var after := session.working_arena.to_snapshot()
	assert_true(session.commit("Retirer", before, after))
	assert_eq(session.topology_generation, 1)
	assert_true(session.topology_invalidation_report().runtime_test_obsolete)
	assert_true(session.history.undo())
	assert_eq(session.topology_generation, 2)
	assert_not_null(session.working_arena.get_cell_definition(Vector2i(2, 2)))
	assert_true(session.history.redo())
	assert_eq(session.topology_generation, 3)
	assert_null(session.working_arena.get_cell_definition(Vector2i(2, 2)))


func test_production_certificate_topology_gate_blocks_any_set_divergence() -> void:
	var certificate := ArenaProductionReadinessCertificate.new()
	certificate.preview_logic_valid = true
	certificate.preview_art_valid = true
	certificate.preview_game_valid = true
	certificate.runtime_test_valid = true
	certificate.expected_tiles = 1
	certificate.rendered_tiles = 1
	certificate.expected_walls = 0
	certificate.rendered_walls = 0
	certificate.pathfinding_valid = true
	certificate.spawn_contract_valid = true
	certificate.art_alignment_confirmed = true
	certificate.coverage_gate_valid = true
	certificate.destination_conflict_state = &"EMPTY"
	certificate.canonical_topology_hash = "same"
	certificate.temporary_topology_hash = "same"
	certificate.runtime_topology_hash = "same"
	certificate.expected_floor_hash = "floor"
	certificate.rendered_floor_hash = "floor"
	certificate.topology_gate_valid = true
	assert_true(certificate.recompute_ready())
	certificate.unexpected_cells = ["4,4"]
	assert_false(certificate.recompute_ready())


func _empty_modular_arena(size: Vector2i) -> ArenaDefinition:
	var arena := ArenaDefinition.new()
	arena.set_identity("Removed topology fixture", "removed_topology_fixture")
	arena.visual_mode = ArenaDefinition.VisualMode.MODULAR
	arena.theme_id = &"dynamic_default"
	arena.modular_visual_profile = ArenaModularVisualProfile.new()
	arena.modular_visual_profile.theme_id = arena.theme_id
	arena.modular_visual_profile.base_terrain_id = &"stone"
	arena.grid_size = size
	arena.grid_origin = Vector2.ZERO
	arena.axis_x = Vector2(32, 16)
	arena.axis_y = Vector2(-32, 16)
	return arena


func _full_arena(size: Vector2i) -> ArenaDefinition:
	var arena := _empty_modular_arena(size)
	for y in range(size.y):
		for x in range(size.x):
			ArenaTerrainRegistry.configure_cell(
				arena.ensure_cell(Vector2i(x, y)), &"stone"
			)
	ArenaRuntimeBridge.sync_runtime_resources(arena)
	return arena


func _irregular_14_by_14() -> Dictionary:
	var arena := _empty_modular_arena(Vector2i(14, 14))
	var absent := [
		"0,0", "13,0", "1,2", "11,2", "3,4", "9,4",
		"5,6", "6,7", "8,8", "2,10", "12,11", "0,13",
	]
	var explicit_void := [
		"4,3", "7,3", "2,5", "10,5", "4,9", "7,9", "3,12", "9,12",
	]
	for y in range(14):
		for x in range(14):
			var cell := Vector2i(x, y)
			var key := ArenaTopologySignatureService.coordinate_key(cell)
			if absent.has(key):
				continue
			var terrain_id: StringName = [&"stone", &"water", &"ice", &"lava"][(x + y) % 4]
			ArenaTerrainRegistry.configure_cell(arena.ensure_cell(cell), terrain_id)
	for key in explicit_void:
		ArenaDynamicEditingService.paint_terrain(
			arena, ArenaTopologySignatureService.key_to_coordinate(key), &"void"
		)
	# Cellule d'eau reconnaissable dont la voisine sud est retiree.
	ArenaDynamicEditingService.paint_terrain(arena, Vector2i(6, 6), &"water")
	var border_count := 0
	for definition in arena.cells:
		if border_count >= 20:
			break
		if ArenaTopologySignatureService.is_void_definition(definition):
			continue
		if definition.coordinate.x in [0, 13] or definition.coordinate.y in [0, 13]:
			definition.border = true
			definition.playable = false
			border_count += 1
	var obstacle := ArenaObstacleDefinition.new()
	obstacle.cell = Vector2i(5, 5)
	obstacle.apply_preset(ArenaObstacleDefinition.Preset.FULL_WALL)
	arena.obstacles.append(obstacle)
	var hero := ArenaSpawnDefinition.new()
	hero.kind = ArenaSpawnDefinition.Kind.HERO_1
	hero.cell = Vector2i(1, 1)
	arena.spawns.append(hero)
	var enemy := ArenaSpawnDefinition.new()
	enemy.kind = ArenaSpawnDefinition.Kind.ENEMY
	enemy.cell = Vector2i(12, 12)
	arena.spawns.append(enemy)
	var objective := ArenaObjectiveDefinition.new()
	objective.cell = Vector2i(7, 7)
	arena.objectives.append(objective)
	ArenaRuntimeBridge.sync_runtime_resources(arena)
	return {
		"arena": arena,
		"absent": absent,
		"explicit_void": explicit_void,
	}
