extends GutTest

const Factory = preload("res://test/support/factory.gd")
const SKELETON_MELEE_DATA = preload("res://data/units/ennemie/skeleton_melee.tres")


class CountingPathfinder:
	extends Pathfinder

	var movement_map_build_count := 0
	var cost_field_build_count := 0
	var direct_find_path_count := 0

	func build_movement_map(
			from: Vector2i,
			max_cost: int = -1,
			ignore_unit = null,
			movement_type: Pathfinder.MovementType = Pathfinder.MovementType.VOLUNTARY,
			synchronize_grid := true
		) -> Dictionary:
		movement_map_build_count += 1
		return super.build_movement_map(
			from,
			max_cost,
			ignore_unit,
			movement_type,
			synchronize_grid,
		)

	func build_cost_field_to(
			destination_cells: Array,
			unit: Unit = null,
			movement_type: Pathfinder.MovementType = Pathfinder.MovementType.VOLUNTARY,
			synchronize_grid := true
		) -> Dictionary:
		cost_field_build_count += 1
		return super.build_cost_field_to(
			destination_cells,
			unit,
			movement_type,
			synchronize_grid,
		)

	func find_path(
			from: Vector2i,
			to: Vector2i,
			ignore_unit = null,
			synchronize_grid := true,
			movement_type: Pathfinder.MovementType = Pathfinder.MovementType.VOLUNTARY
		) -> Array:
		direct_find_path_count += 1
		return super.find_path(
			from,
			to,
			ignore_unit,
			synchronize_grid,
			movement_type,
		)


func _unit(
		name: String,
		team: int,
		control_level: UnitData.ControlLevel = UnitData.ControlLevel.NONE
	) -> Unit:
	var unit := Unit.new(name, team, 100, 10, 6, 6, 20)
	unit.control_level = control_level
	return unit


func _place(grid: GridData, unit: Unit, cell: Vector2i) -> Unit:
	assert_true(grid.place_unit(unit, cell))
	return unit


func _target_edges(grid: GridData, target: Unit, mover: Unit) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for direction in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
		var cell := target.grid_pos + direction
		if grid.is_walkable(cell, mover):
			result.append(cell)
	return result


func test_movement_map_reuses_the_same_weighted_paths_and_reachability() -> void:
	var grid := GridData.new(7, 3)
	var mover := _place(grid, _unit("Mover", 0), Vector2i(0, 1))
	for x in [2, 3, 4]:
		_place(
			grid,
			_unit("Controller %d" % x, 1, UnitData.ControlLevel.CONTROL),
			Vector2i(x, 0),
		)
	var pathfinder := Pathfinder.new(grid)
	var destination := Vector2i(6, 1)
	var direct_path := pathfinder.find_path(mover.grid_pos, destination, mover)
	var direct_reachable := pathfinder.get_reachable(mover.grid_pos, 6, mover)

	var movement_map := pathfinder.build_movement_map(mover.grid_pos, -1, mover)
	var reused_path := pathfinder.path_from_movement_map(
		mover.grid_pos,
		destination,
		movement_map,
	)
	var reused_reachable := pathfinder.get_reachable_from_movement_map(
		mover.grid_pos,
		movement_map,
		6,
	)

	assert_eq(reused_path, direct_path)
	assert_eq(reused_reachable, direct_reachable)
	assert_eq(
		pathfinder.path_movement_cost(reused_path, mover),
		pathfinder.path_movement_cost(direct_path, mover),
	)


func test_reverse_cost_field_matches_reference_paths_with_control() -> void:
	var grid := GridData.new(7, 5)
	var mover := _place(grid, _unit("Mover", 0), Vector2i(0, 2))
	var target := _place(grid, _unit("Target", 1), Vector2i(6, 2))
	_place(
		grid,
		_unit("Controller", 1, UnitData.ControlLevel.HEAVY_CONTROL),
		Vector2i(2, 1),
	)
	grid.set_type(Vector2i(3, 2), GridData.CellType.WALL)
	var pathfinder := Pathfinder.new(grid)
	var edges := _target_edges(grid, target, mover)
	var cost_field := pathfinder.build_cost_field_to(edges, mover)

	for cell in [
		Vector2i(0, 2),
		Vector2i(1, 2),
		Vector2i(2, 3),
		Vector2i(4, 3),
		Vector2i(5, 2),
	]:
		var expected := 999999
		for edge in edges:
			var path := pathfinder.find_path(cell, edge, mover)
			if not path.is_empty():
				expected = mini(
					expected,
					pathfinder.path_movement_cost(path, mover),
				)
		assert_eq(int(cost_field.get(cell, 999999)), expected, str(cell))


func test_formation_ai_reuses_bounded_path_queries_for_one_decision() -> void:
	var grid := GridData.new(14, 14)
	var pathfinder := CountingPathfinder.new(grid)
	var terrain := TerrainEffects.new(grid)
	var caster := SpellCaster.new(grid, pathfinder, terrain)
	var skeleton := _place(
		grid,
		Unit.from_data(SKELETON_MELEE_DATA),
		Vector2i(1, 7),
	)
	var heroes: Array[Unit] = [
		_place(grid, Factory.make_unit("Hero A", 0), Vector2i(11, 3)),
		_place(grid, Factory.make_unit("Hero B", 0), Vector2i(12, 7)),
		_place(grid, Factory.make_unit("Hero C", 0), Vector2i(10, 11)),
	]
	skeleton.current_mp = 5
	var units: Array = [skeleton]
	units.append_array(heroes)
	var ai := EnemyAI.new(grid, pathfinder, caster)

	var plan := ai.decide(skeleton, units)

	assert_false(plan.is_empty())
	assert_eq(pathfinder.movement_map_build_count, 1)
	assert_lte(pathfinder.cost_field_build_count, heroes.size())
	assert_eq(pathfinder.direct_find_path_count, 0)
