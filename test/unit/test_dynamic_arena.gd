extends GutTest

const CellStateScript := preload("res://tools/labs/dynamic_arena/dynamic_cell_state.gd")
const LabScene := preload("res://tools/labs/dynamic_arena/DynamicArenaLab.tscn")
const NORMALIZED_DIR := "res://tools/labs/dynamic_arena/assets/normalized"
const SURFACES := [
	DynamicCellState.Surface.STONE,
	DynamicCellState.Surface.WATER,
	DynamicCellState.Surface.ICE,
	DynamicCellState.Surface.LAVA,
]
const FILE_NAMES := ["stone.png", "water.png", "ice.png", "lava.png"]


func test_normalized_tiles_are_exact_rgba_256_by_128() -> void:
	for file_name in FILE_NAMES:
		var image := _load_png(file_name)
		assert_false(image.is_empty(), file_name)
		assert_eq(image.get_size(), Vector2i(256, 128), file_name)
		assert_eq(image.get_format(), Image.FORMAT_RGBA8, file_name)


func test_normalized_tiles_are_transparent_outside_the_exact_diamond() -> void:
	for file_name in FILE_NAMES:
		var image := _load_png(file_name)
		var opaque_outside: Array[Vector2i] = []
		for y in range(image.get_height()):
			for x in range(image.get_width()):
				if _inside_diamond(x, y):
					continue
				if image.get_pixel(x, y).a > 0.0 and opaque_outside.size() < 12:
					opaque_outside.append(Vector2i(x, y))
		assert_eq(opaque_outside, [], file_name)


func test_four_normalized_tiles_share_the_same_alpha_bounding_box() -> void:
	var expected := Rect2i(0, 0, 256, 128)
	for file_name in FILE_NAMES:
		assert_eq(_alpha_bounds(_load_png(file_name)), expected, file_name)


func test_dynamic_state_uses_an_eight_by_eight_griddata() -> void:
	var grid := GridData.new(8, 8)
	var states := CellStateScript.new() as DynamicCellState
	states.configure(grid)
	assert_eq(grid.cols, 8)
	assert_eq(grid.rows, 8)
	assert_eq(states.state_count(), 64)


func test_surface_changes_are_logical_and_cycle_in_the_required_order() -> void:
	var grid := GridData.new(2, 2)
	var states := CellStateScript.new() as DynamicCellState
	states.configure(grid)
	var cell := Vector2i(1, 1)
	assert_eq(states.get_surface(cell), DynamicCellState.Surface.STONE)
	assert_eq(states.cycle_surface(cell), DynamicCellState.Surface.WATER)
	assert_eq(states.cycle_surface(cell), DynamicCellState.Surface.ICE)
	assert_eq(states.cycle_surface(cell), DynamicCellState.Surface.LAVA)
	assert_eq(states.cycle_surface(cell), DynamicCellState.Surface.STONE)


func test_lab_walkability_rules_do_not_change_griddata_production_rules() -> void:
	var grid := GridData.new(4, 1)
	var states := CellStateScript.new() as DynamicCellState
	states.configure(grid)
	for x in range(3):
		states.set_surface(Vector2i(x, 0), SURFACES[x])
		assert_true(states.is_effectively_walkable(Vector2i(x, 0)))
		assert_true(grid.is_walkable(Vector2i(x, 0)))
	states.set_surface(Vector2i(3, 0), DynamicCellState.Surface.LAVA)
	assert_false(states.is_effectively_walkable(Vector2i(3, 0)))
	assert_false(grid.is_walkable(Vector2i(3, 0)))
	assert_true(
		GridData.PROPERTIES[GridData.CellType.LAVA]["walkable"],
		"La regle LAVA de production doit rester intacte."
	)


func test_path_recalculates_around_lava_and_never_crosses_blocked_cells() -> void:
	var grid := GridData.new(5, 3)
	var states := CellStateScript.new() as DynamicCellState
	states.configure(grid)
	var pathfinder := Pathfinder.new(grid)
	for y in range(3):
		states.set_surface(Vector2i(2, y), DynamicCellState.Surface.LAVA)
	assert_eq(pathfinder.find_path(Vector2i(0, 1), Vector2i(4, 1)), [])
	states.set_surface(Vector2i(2, 1), DynamicCellState.Surface.STONE)
	var restored := pathfinder.find_path(Vector2i(0, 1), Vector2i(4, 1))
	assert_eq(restored.size(), 5)
	for cell in restored:
		assert_true(grid.is_walkable(cell), str(cell))


func test_dynamic_wall_blocks_then_restores_the_existing_pathfinder() -> void:
	var grid := GridData.new(3, 1)
	var states := CellStateScript.new() as DynamicCellState
	states.configure(grid)
	var pathfinder := Pathfinder.new(grid)
	assert_eq(pathfinder.find_path(Vector2i(0, 0), Vector2i(2, 0)).size(), 3)
	assert_true(states.set_blocker(Vector2i(1, 0), true))
	assert_eq(pathfinder.find_path(Vector2i(0, 0), Vector2i(2, 0)), [])
	assert_true(states.set_blocker(Vector2i(1, 0), false))
	assert_eq(pathfinder.find_path(Vector2i(0, 0), Vector2i(2, 0)).size(), 3)


func test_pathfinder_can_recalculate_without_resyncing_an_unchanged_walkability_graph() -> void:
	var grid := GridData.new(3, 1)
	var pathfinder := Pathfinder.new(grid)
	assert_eq(
		pathfinder.find_path(Vector2i(0, 0), Vector2i(2, 0), null, false).size(),
		3
	)
	grid.set_type(Vector2i(1, 0), GridData.CellType.WALL)
	# Sans synchronisation explicite, le graphe AStar conserve son etat courant.
	assert_eq(
		pathfinder.find_path(Vector2i(0, 0), Vector2i(2, 0), null, false).size(),
		3
	)
	pathfinder.sync()
	assert_eq(pathfinder.find_path(Vector2i(0, 0), Vector2i(2, 0), null, false), [])


func test_reset_restores_stone_walkability_and_removes_blockers() -> void:
	var grid := GridData.new(3, 2)
	var states := CellStateScript.new() as DynamicCellState
	states.configure(grid)
	states.set_surface(Vector2i(1, 1), DynamicCellState.Surface.LAVA)
	states.set_blocker(Vector2i(2, 1), true)
	states.reset()
	for x in range(grid.cols):
		for y in range(grid.rows):
			var cell := Vector2i(x, y)
			assert_eq(states.get_surface(cell), DynamicCellState.Surface.STONE)
			assert_false(states.has_blocker(cell))
			assert_true(grid.is_walkable(cell))


func test_lab_scene_has_required_layers_one_grid_and_sixty_four_tiles() -> void:
	var lab := LabScene.instantiate() as DynamicArenaLab
	add_child_autofree(lab)
	for path in [
		"FloorLayer", "SurfaceVFXLayer", "DynamicObjectLayer", "UnitLayer",
		"GridDebugLayer", "Camera2D", "CanvasLayer/Toolbar",
	]:
		assert_not_null(lab.get_node_or_null(path), path)
	assert_not_null(lab.grid)
	assert_not_null(lab.pathfinder)
	assert_eq(lab.grid.cols, 8)
	assert_eq(lab.grid.rows, 8)
	assert_eq(lab.get_node("FloorLayer").get_child_count(), 64)


func test_lab_mutations_recalculate_path_and_wall_removal_restores_cell() -> void:
	var lab := LabScene.instantiate() as DynamicArenaLab
	add_child_autofree(lab)
	var count_before := lab.path_recalculation_count
	lab.set_cell_surface(Vector2i(3, 3), DynamicCellState.Surface.LAVA)
	assert_gt(lab.path_recalculation_count, count_before)
	assert_false(lab.is_cell_walkable(Vector2i(3, 3)))
	assert_true(lab.toggle_wall_at(Vector2i(2, 3)))
	assert_true(lab.has_wall(Vector2i(2, 3)))
	assert_false(lab.toggle_wall_at(Vector2i(2, 3)))
	assert_false(lab.has_wall(Vector2i(2, 3)))
	assert_true(lab.is_cell_walkable(Vector2i(2, 3)))
	lab.reset_lab()
	assert_eq(lab.get_cell_surface(Vector2i(3, 3)), DynamicCellState.Surface.STONE)


func test_cell_screen_cell_round_trip_and_foot_anchor_do_not_drift() -> void:
	var lab := LabScene.instantiate() as DynamicArenaLab
	add_child_autofree(lab)
	var grid_view := lab.get_node("GridDebugLayer") as IsoGridView
	for x in range(8):
		for y in range(8):
			var cell := Vector2i(x, y)
			assert_eq(grid_view.local_to_grid(grid_view.grid_to_local(cell)), cell)
	var unit_cell := Vector2i(5, 6)
	lab.set_start_cell(unit_cell)
	var unit_layer := lab.get_node("UnitLayer") as Node2D
	var marker := lab.get_node("UnitLayer/TestUnit") as Node2D
	var expected := unit_layer.to_local(grid_view.to_global(grid_view.grid_to_local(unit_cell)))
	assert_eq(marker.position, expected)


func _load_png(file_name: String) -> Image:
	return Image.load_from_file(ProjectSettings.globalize_path(NORMALIZED_DIR.path_join(file_name)))


func _inside_diamond(x: int, y: int) -> bool:
	if y <= 64:
		return (
			float(x) >= 128.0 - float(y) * 2.0
			and float(x) <= 128.0 + float(y) * (127.0 / 64.0)
		)
	var lower_y := float(y - 64)
	return (
		float(x) >= lower_y * (128.0 / 63.0)
		and float(x) <= 255.0 - lower_y * (127.0 / 63.0)
	)


func _alpha_bounds(image: Image) -> Rect2i:
	var minimum := Vector2i(image.get_width(), image.get_height())
	var maximum := Vector2i(-1, -1)
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a <= 0.0:
				continue
			minimum.x = mini(minimum.x, x)
			minimum.y = mini(minimum.y, y)
			maximum.x = maxi(maximum.x, x)
			maximum.y = maxi(maximum.y, y)
	return Rect2i(minimum, maximum - minimum + Vector2i.ONE)
