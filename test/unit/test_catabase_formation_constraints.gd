extends GutTest


func test_flexible_guard_cannot_take_the_only_cell_of_a_constrained_hunter() -> void:
	var grid := GridData.new(11, 1)
	var definition := _encounter([
		_definition("a_guard", 3, 17),
		_definition("z_hunter", 10, 10),
	])
	var planner := EncounterFormationPlanner.new(grid, Pathfinder.new(grid))
	var plan := planner.build_plan(definition, [Vector2i.ZERO], [], 2401)
	assert_true(plan.valid)
	assert_eq(plan.placements.size(), 2)
	assert_eq(plan.placements[0].unit_data.unit_id, &"z_hunter")
	assert_eq(plan.placements[0].cell, Vector2i(10, 0))
	assert_ne(plan.placements[1].cell, Vector2i(10, 0))


func test_eight_body_mixed_pack_obeys_every_minimum_and_forbidden_cell() -> void:
	var grid := GridData.new(15, 1)
	var definition := _encounter([
		_definition("a_guard", 5, 20, 3),
		_definition("m_archer", 7, 20, 3),
		_definition("z_hunter", 11, 20, 2),
	])
	definition.forbidden_initial_spawn_cells.assign([Vector2i(9, 0), Vector2i(14, 0)])
	var planner := EncounterFormationPlanner.new(grid, Pathfinder.new(grid))
	for seed_value: int in [2401, 42, 777]:
		var plan := planner.build_plan(definition, [Vector2i.ZERO], [], seed_value)
		assert_true(plan.valid, "All eight fit without relaxing access")
		assert_eq(plan.placements.size(), 8)
		assert_true(planner.validate_plan(definition, plan, [Vector2i.ZERO]).valid)
		var signature: Array = plan.placements.map(func(entry: Dictionary): return entry.cell)
		var repeated := planner.build_plan(definition, [Vector2i.ZERO], [], seed_value)
		assert_eq(repeated.placements.map(func(entry: Dictionary): return entry.cell), signature)


func test_insufficient_capacity_stays_a_failure_instead_of_ignoring_safety() -> void:
	var grid := GridData.new(8, 1)
	var definition := _encounter([_definition("horde", 6, 10, 3)])
	var planner := EncounterFormationPlanner.new(grid, Pathfinder.new(grid))
	var plan := planner.build_plan(definition, [Vector2i.ZERO], [], 2401)
	assert_false(plan.valid)
	assert_eq(plan.reason, &"incomplete_roster")


func test_legacy_roster_order_remains_unchanged() -> void:
	var grid := GridData.new(15, 1)
	var guard := _definition("a_guard", 3, 8)
	var hunter := _definition("z_hunter", 8, 12)
	guard.data.tactical_role_id = &"other_guard"
	hunter.data.tactical_role_id = &"other_hunter"
	var definition := _encounter([guard, hunter])
	var planner := EncounterFormationPlanner.new(grid, Pathfinder.new(grid))
	var plan := planner.build_plan(definition, [Vector2i.ZERO], [], 2401)
	assert_true(plan.valid)
	assert_eq(plan.placements[0].unit_data.unit_id, &"a_guard")


func test_expansion_visibility_guard_uses_native_geometry_and_actual_foreground() -> void:
	var room := RoomData.new()
	var visual := PaintedMapVisualData.new()
	visual.grid_origin = Vector2(100, 100)
	visual.axis_x = Vector2(10, 0)
	visual.axis_y = Vector2(0, 10)
	visual.image_offset = Vector2(40, 30)
	visual.image_scale = Vector2(2, 2)
	visual.foreground_full_hide_rect = Rect2(90, 90, 20, 20)
	room.painted_map_visual_data = visual
	assert_true(ExpeditionRunFactory._initial_cell_is_occluded(room, Vector2i.ZERO))
	assert_false(ExpeditionRunFactory._initial_cell_is_occluded(room, Vector2i(2, 0)))
	visual.foreground_full_hide_rect = Rect2()
	visual.foreground_occluder_polygon = PackedVector2Array([
		Vector2(90, 90), Vector2(130, 90), Vector2(130, 130), Vector2(90, 130),
	])
	visual.foreground_occluder_sort_y = 110.0
	assert_true(ExpeditionRunFactory._initial_cell_is_occluded(room, Vector2i.ZERO))
	assert_false(ExpeditionRunFactory._initial_cell_is_occluded(room, Vector2i(0, 2)), "An actor in front of the y-sorted prop stays visible")
	var arena := ArenaDefinition.new()
	arena.grid_origin = Vector2(100, 100)
	arena.foreground_full_hide_rect = Rect2(90, 90, 20, 20)
	assert_true(ExpeditionRunFactory._initial_cell_is_occluded(arena, Vector2i.ZERO), "Authoring geometry is respected even before regenerating its visual resource")


func _definition(id: String, minimum: int, maximum: int, count: int = 1) -> Dictionary:
	var data := UnitData.new()
	data.unit_id = StringName(id)
	data.tactical_role_id = StringName("catabase_evolution_%s" % id)
	data.team = 1
	return {"data": data, "minimum": minimum, "maximum": maximum, "count": count}


func _encounter(entries: Array) -> EncounterDefinition:
	var result := EncounterDefinition.new()
	result.minimum_path_distance_by_role = {}
	result.maximum_path_distance_by_role = {}
	result.formation_profiles.assign([&"line"])
	for entry: Dictionary in entries:
		result.roster_units.append(entry.data)
		result.roster_counts.append(entry.count)
		result.minimum_path_distance_by_role[entry.data.tactical_role_id] = entry.minimum
		result.maximum_path_distance_by_role[entry.data.tactical_role_id] = entry.maximum
		result.living_enemy_cap += int(entry.count)
	return result
