extends GutTest

const ARENA_PATH := "res://data/rooms/odyssey/room_01.tres"


func test_repeated_signatures_release_their_temporary_terrain_graph() -> void:
	var arena := load(ARENA_PATH) as ArenaDefinition
	var plan := ArenaTerrainRenderPlanService.build(arena)
	var expected_cells: int = plan.render_entries.size()
	assert_gt(expected_cells, 0, "The regression must exercise an authored floor.")
	# Warm resource/script caches before measuring. No frame, timer or assertion
	# runs inside the measured interval; the helper retains no signature result.
	assert_true(_exercise_signatures(arena, plan, expected_cells, 2))
	var before := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var signatures_complete := _exercise_signatures(arena, plan, expected_cells, 4)
	var after := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	assert_true(signatures_complete)
	assert_eq(after, before, "Each signature must release its owned terrain and cells.")


func test_prepared_visual_data_keeps_the_callers_runtime_alive() -> void:
	var arena := load(ARENA_PATH) as ArenaDefinition
	var plan := ArenaTerrainRenderPlanService.build(arena)
	var runtime := ArenaRuntimeProjectionService.build(arena)
	assert_not_null(runtime)
	if runtime == null:
		return
	var source_fingerprint := RoomDataSnapshotService.room_fingerprint(arena)
	var terrain := runtime.terrain_effects
	var surface_runtime := terrain.runtime_service
	var captured_cells := surface_runtime.state_count()
	var prepared := ArenaVisualAssembler.expected_visual_signature(arena, plan, runtime.visual_data)
	var owned := ArenaVisualAssembler.expected_visual_signature(arena, plan)
	assert_eq(prepared, owned, "Disposal must preserve every computed visual entry.")
	assert_same(terrain.runtime_service, surface_runtime)
	assert_same(surface_runtime.grid, runtime.grid)
	assert_gt(captured_cells, 0)
	assert_eq(surface_runtime.state_count(), captured_cells)
	assert_eq(RoomDataSnapshotService.room_fingerprint(arena), source_fingerprint)
	# This test, rather than the assembler, owns the prepared runtime.
	terrain.dispose()


func _exercise_signatures(
	arena: ArenaDefinition,
	plan: Dictionary,
	expected_cells: int,
	repetitions: int,
) -> bool:
	for iteration in repetitions:
		if not _signature_has_cells(arena, plan, expected_cells):
			return false
	return true


func _signature_has_cells(arena: ArenaDefinition, plan: Dictionary, expected_cells: int) -> bool:
	var signature := ArenaVisualAssembler.expected_visual_signature(arena, plan)
	return signature.terrains.size() == expected_cells
