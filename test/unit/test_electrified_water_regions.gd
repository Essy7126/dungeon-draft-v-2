extends GutTest


func test_contiguous_cells_share_one_trigger() -> void:
	var fixture := _fixture([Vector2i(1, 0), Vector2i(2, 0)])
	_assert_forced_trigger(fixture, Vector2i(1, 0), true)
	fixture.unit.remove_status(&"shock")
	_move_neutral(fixture)
	_assert_forced_trigger(fixture, Vector2i(2, 0), false)


func test_disjoint_regions_can_each_trigger_in_the_same_round() -> void:
	var fixture := _fixture([Vector2i(1, 0), Vector2i(3, 0)])
	_assert_forced_trigger(fixture, Vector2i(1, 0), true)
	fixture.unit.remove_status(&"shock")
	_move_neutral(fixture)
	_assert_forced_trigger(fixture, Vector2i(3, 0), true)


func test_crossing_three_cells_of_one_region_triggers_once() -> void:
	var fixture := _fixture([
		Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0),
	])
	_assert_forced_trigger(fixture, Vector2i(1, 0), true)
	fixture.unit.remove_status(&"shock")
	_move_neutral(fixture)
	_assert_forced_trigger(fixture, Vector2i(2, 0), false)
	_move_neutral(fixture)
	_assert_forced_trigger(fixture, Vector2i(3, 0), false)


func test_exit_and_reentry_of_same_region_does_not_retrigger() -> void:
	var fixture := _fixture([Vector2i(1, 0)])
	_assert_forced_trigger(fixture, Vector2i(1, 0), true)
	fixture.unit.remove_status(&"shock")
	_move_neutral(fixture)
	_assert_forced_trigger(fixture, Vector2i(1, 0), false)


func test_new_disjoint_region_rearms_once() -> void:
	var fixture := _fixture([Vector2i(1, 0), Vector2i(4, 0)])
	_assert_forced_trigger(fixture, Vector2i(1, 0), true)
	fixture.unit.remove_status(&"shock")
	_move_neutral(fixture)
	_assert_forced_trigger(fixture, Vector2i(4, 0), true)


func test_new_round_rearms_the_same_region() -> void:
	var fixture := _fixture([Vector2i(1, 0)])
	_assert_forced_trigger(fixture, Vector2i(1, 0), true)
	fixture.unit.remove_status(&"shock")
	_move_neutral(fixture)
	fixture.runtime.terrain_effects.runtime_service.configure_resolution_context(77, 2)
	_assert_forced_trigger(fixture, Vector2i(1, 0), true)


func test_merged_regions_union_their_round_lineages() -> void:
	var resolver := ElectricalTerrainRegionResolver.new()
	resolver.begin_round(4)
	var left := resolver.resolve_region(Vector2i.ZERO, [
		Vector2i.ZERO, Vector2i(2, 0),
	])
	var right := resolver.resolve_region(Vector2i(2, 0), [
		Vector2i.ZERO, Vector2i(2, 0),
	])
	assert_ne(left.region_id, right.region_id)
	var merged := resolver.resolve_region(Vector2i(1, 0), [
		Vector2i.ZERO, Vector2i(1, 0), Vector2i(2, 0),
	])
	assert_eq((merged.lineage_tokens as PackedStringArray).size(), 2)
	assert_has(merged.lineage_tokens, str(left.region_id))
	assert_has(merged.lineage_tokens, str(right.region_id))


func test_split_regions_keep_the_parent_round_lineage() -> void:
	var resolver := ElectricalTerrainRegionResolver.new()
	resolver.begin_round(5)
	var parent := resolver.resolve_region(Vector2i(1, 0), [
		Vector2i.ZERO, Vector2i(1, 0), Vector2i(2, 0),
	])
	var split_cells: Array[Vector2i] = [Vector2i.ZERO, Vector2i(2, 0)]
	var left := resolver.resolve_region(Vector2i.ZERO, split_cells)
	var right := resolver.resolve_region(Vector2i(2, 0), split_cells)
	assert_eq(left.region_id, parent.region_id)
	assert_eq(right.region_id, parent.region_id)


func test_voluntary_entry_consumes_only_the_current_activation() -> void:
	var fixture := _fixture([Vector2i(1, 0)])
	fixture.unit.current_ap = 2
	fixture.unit.current_mp = 4
	fixture.runtime.terrain_effects.begin_unit_resolution(fixture.unit, &"movement")
	assert_true(fixture.runtime.grid.relocate_unit(fixture.unit, Vector2i(1, 0)))
	var result: Dictionary = fixture.runtime.terrain_effects.consume_last_entry_result(
		fixture.unit
	)
	assert_true(result.shock_applied)
	assert_true(result.current_activation_consumed)
	assert_eq(fixture.unit.current_ap, 0)
	assert_eq(fixture.unit.current_mp, 0)
	assert_false(fixture.unit.has_status(&"shock"))


func test_forced_entry_applies_exactly_one_shock_status() -> void:
	var fixture := _fixture([Vector2i(1, 0)])
	_assert_forced_trigger(fixture, Vector2i(1, 0), true)
	assert_eq(_status_count(fixture.unit, &"shock"), 1)


func test_repeated_entries_cannot_create_an_infinite_stun_chain() -> void:
	var fixture := _fixture([Vector2i(1, 0), Vector2i(2, 0)])
	_assert_forced_trigger(fixture, Vector2i(1, 0), true)
	for index in range(12):
		fixture.unit.remove_status(&"shock")
		_move_neutral(fixture)
		_assert_forced_trigger(
			fixture, Vector2i(1 + index % 2, 0), false
		)
	assert_eq(_status_count(fixture.unit, &"shock"), 0)


func test_region_identity_is_coordinate_deterministic_and_order_independent() -> void:
	var first := ElectricalTerrainRegionResolver.new()
	var second := ElectricalTerrainRegionResolver.new()
	first.begin_round(1)
	second.begin_round(99)
	var ordered: Array[Vector2i] = [
		Vector2i(1, 1), Vector2i(2, 1), Vector2i(2, 2),
	]
	var reversed := ordered.duplicate()
	reversed.reverse()
	var a := first.resolve_region(Vector2i(2, 1), ordered)
	var b := second.resolve_region(Vector2i(2, 1), reversed)
	assert_eq(a.region_id, b.region_id)


func _fixture(electrical_cells: Array[Vector2i]) -> Dictionary:
	var arena := ArenaDefinition.new()
	arena.set_identity("Electrical regions", "electrical_regions")
	arena.grid_size = Vector2i(5, 3)
	for y in range(arena.grid_size.y):
		for x in range(arena.grid_size.x):
			ArenaTerrainRegistry.configure_cell(
				arena.ensure_cell(Vector2i(x, y)), &"neutral"
			)
	for cell in electrical_cells:
		ArenaDynamicEditingService.paint_terrain_local(
			arena, cell, &"electrified_water"
		)
	ArenaRuntimeBridge.sync_runtime_resources(arena)
	var runtime := ArenaRuntimeProjectionService.build(arena)
	runtime.terrain_effects.runtime_service.configure_resolution_context(77, 1)
	var unit := Unit.new("Shock", 0, 5000)
	unit.unit_id = &"regional_shock_unit"
	assert_true(runtime.grid.place_unit(unit, Vector2i(0, 2)))
	return {"runtime": runtime, "unit": unit}


func _assert_forced_trigger(
	fixture: Dictionary,
	cell: Vector2i,
	expected: bool
	) -> void:
	fixture.runtime.terrain_effects.begin_unit_resolution(fixture.unit, &"push")
	assert_true(fixture.runtime.grid.relocate_unit(fixture.unit, cell))
	var result: Dictionary = fixture.runtime.terrain_effects.consume_last_entry_result(
		fixture.unit
	)
	assert_eq(bool(result.get("shock_applied", false)), expected, str(result))
	assert_eq(fixture.unit.has_status(&"shock"), expected, str(result))


func _move_neutral(fixture: Dictionary) -> void:
	fixture.runtime.terrain_effects.begin_unit_resolution(fixture.unit, &"push")
	assert_true(fixture.runtime.grid.relocate_unit(fixture.unit, Vector2i(0, 2)))
	fixture.runtime.terrain_effects.consume_last_entry_result(fixture.unit)


func _status_count(unit: Unit, status_id: StringName) -> int:
	return unit.active_statuses.filter(func(entry):
		var data := entry.get("data") as StatusData
		return data != null and data.get_effective_status_id() == status_id
	).size()
