extends GutTest


func test_01_one_runtime_sync_per_logical_stroke() -> void:
	var arena := _fixture()
	ArenaRuntimeBridge.begin_instrumentation()
	var result := _paint(arena, _cells(100), &"water")
	var counters := ArenaRuntimeBridge.end_instrumentation()
	assert_eq(int(counters.sync_runtime_resources), 1)
	assert_eq(int(result.runtime_sync_calls), 1)


func test_02_visual_stone_to_neutral_skips_runtime_rebuild() -> void:
	var arena := _fixture()
	ArenaRuntimeBridge.begin_instrumentation()
	var result := _paint(arena, _cells(50), &"neutral")
	var counters := ArenaRuntimeBridge.end_instrumentation()
	assert_false(result.logical_change)
	assert_eq(int(counters.sync_runtime_resources), 0)


func test_03_duplicate_cells_are_deduplicated() -> void:
	var arena := _fixture()
	var batch := ArenaStrokeBatchService.new()
	batch.begin_stroke(arena)
	var repeated: Array[Vector2i] = [Vector2i(1, 1), Vector2i(1, 1), Vector2i(1, 1)]
	assert_eq(batch.apply_terrain_cells(repeated, &"water").size(), 1)
	var result := batch.finish()
	assert_eq(int(result.duplicate_cell_count), 2)


func test_04_unchanged_cells_are_ignored() -> void:
	var result := _paint(_fixture(&"water"), _cells(20), &"water")
	assert_false(result.changed)
	assert_eq(int(result.runtime_sync_calls), 0)


func test_05_rectangle_contains_each_cell_once() -> void:
	var cells := ArenaStrokeBatchService.rectangle_cells(Vector2i(2, 3), Vector2i(5, 7))
	assert_eq(cells.size(), 20)
	assert_eq(cells.duplicate().size(), cells.size())


func test_06_fill_follows_the_source_terrain_not_only_defined_state() -> void:
	var arena := _fixture()
	ArenaDynamicEditingService.paint_terrain_local(arena, Vector2i(2, 2), &"water")
	ArenaDynamicEditingService.paint_terrain_local(arena, Vector2i(3, 2), &"water")
	ArenaDynamicEditingService.paint_terrain_local(arena, Vector2i(3, 3), &"water")
	var cells := ArenaStrokeBatchService.contiguous_cells(arena, Vector2i(2, 2))
	assert_eq(cells.size(), 3)
	assert_false(cells.has(Vector2i(1, 2)))


func test_07_replacement_preview_and_commit_match() -> void:
	var arena := _fixture()
	var expected := ArenaStrokeBatchService.replacement_cells(arena, &"stone")
	var result := _paint(arena, expected, &"neutral")
	assert_eq(int(result.changed_cell_count), expected.size())


func test_08_snapshot_restores_the_whole_stroke() -> void:
	var arena := _fixture()
	var result := _paint(arena, _cells(50), &"poison")
	assert_eq(arena.get_cell_definition(Vector2i.ZERO).terrain_id, &"poison")
	assert_true(arena.restore_snapshot(result.before))
	assert_eq(arena.get_cell_definition(Vector2i.ZERO).terrain_id, &"stone")
	assert_true(arena.restore_snapshot(result.after))
	assert_eq(arena.get_cell_definition(Vector2i.ZERO).terrain_id, &"poison")


func test_09_one_hundred_cell_finalization_stays_bounded() -> void:
	var result := _paint(_fixture(), _cells(100), &"electrified_water")
	assert_lt(float(result.finalization_ms), 150.0)


func test_10_two_hundred_cells_on_32_square_stay_bounded() -> void:
	var result := _paint(_fixture(&"stone", 32), _cells(200, 32), &"water")
	assert_lt(float(result.finalization_ms), 300.0)


func test_11_batch_has_no_residual_cache_after_finish() -> void:
	var batch := ArenaStrokeBatchService.new()
	batch.begin_stroke(_fixture())
	batch.apply_terrain_cells(_cells(10), &"lava")
	batch.finish()
	assert_false(batch.is_active())
	assert_true(batch.changed_cells().is_empty())


func test_12_void_removes_a_cell_from_vortex_networks() -> void:
	var arena := _fixture()
	var network := ArenaVortexNetworkService.create_network(arena)
	assert_true(ArenaVortexNetworkService.add_cell(arena, network.network_id, Vector2i(1, 1)))
	_paint(arena, [Vector2i(1, 1)], &"void")
	assert_false(network.cells.has(Vector2i(1, 1)))


func test_13_logical_stroke_exposes_one_undo_payload() -> void:
	var result := _paint(_fixture(), _cells(10), &"ice")
	assert_true(result.changed)
	assert_false((result.before as Dictionary).is_empty())
	assert_false((result.after as Dictionary).is_empty())


func test_14_received_and_changed_metrics_are_exact() -> void:
	var result := _paint(_fixture(), _cells(50), &"steam")
	assert_eq(int(result.received_cell_count), 50)
	assert_eq(int(result.changed_cell_count), 50)


func _paint(arena: ArenaDefinition, cells: Array[Vector2i], terrain_id: StringName) -> Dictionary:
	var batch := ArenaStrokeBatchService.new()
	batch.begin_stroke(arena)
	batch.apply_terrain_cells(cells, terrain_id)
	return batch.finish()


func _fixture(default_id: StringName = &"stone", size := 14) -> ArenaDefinition:
	var arena := ArenaDefinition.new()
	arena.set_identity("Speed fixture", "speed_fixture")
	arena.grid_size = Vector2i(size, size)
	arena.visual_mode = ArenaDefinition.VisualMode.MODULAR
	arena.modular_visual_profile = ArenaModularVisualProfile.new()
	for cell in _cells(size * size, size):
		ArenaTerrainRegistry.configure_cell(arena.ensure_cell(cell), default_id)
	ArenaRuntimeBridge.sync_runtime_resources(arena)
	return arena


func _cells(count: int, width := 14) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for index in range(count):
		result.append(Vector2i(index % width, index / width))
	return result
