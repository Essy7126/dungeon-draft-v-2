extends GutTest


func test_dynamic_wall_reference_grid_keeps_native_scale() -> void:
	assert_almost_eq(
		ArenaVisualAssembler.wall_scale_for_axes(
			Vector2(32.0, 16.0), Vector2(-32.0, 16.0)
		),
		1.0,
		0.0001
	)


func test_historical_painted_grid_keeps_unit_scale() -> void:
	assert_almost_eq(
		ArenaVisualAssembler.painted_unit_scale_for_axes(
			Vector2(34.4, 17.066667), Vector2(-34.4, 17.066667)
		),
		1.0,
		0.0001
	)


func test_large_author_grid_scales_walls_and_units_with_its_cells() -> void:
	var axis_x := Vector2(-98.8079, 66.06052)
	var axis_y := Vector2(-165.0148, -56.386574)
	var footprint := ArenaVisualAssembler.cell_footprint_for_axes(axis_x, axis_y)
	assert_almost_eq(footprint.x, 263.8227, 0.001)
	assert_almost_eq(footprint.y, 122.447094, 0.001)
	assert_gt(ArenaVisualAssembler.wall_scale_for_axes(axis_x, axis_y), 3.8)
	assert_gt(
		ArenaVisualAssembler.painted_unit_scale_for_axes(axis_x, axis_y), 3.5
	)


func test_invalid_footprint_falls_back_without_hiding_visuals() -> void:
	assert_eq(
		ArenaVisualAssembler.wall_scale_for_axes(Vector2.ZERO, Vector2.ZERO),
		1.0
	)
