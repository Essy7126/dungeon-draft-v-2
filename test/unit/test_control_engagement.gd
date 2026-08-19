extends GutTest

const Factory = preload("res://test/support/factory.gd")
const MovementPathPreviewScript = preload("res://battle/movement_path_preview.gd")
const InspectPanelScript = preload("res://ui/inspect_panel.gd")
const BattleScript = preload("res://battle/battle.gd")
const GridViewScript = preload("res://battle/grid_view.gd")


class GridViewFixture:
	extends Node2D

	func grid_to_local(cell: Vector2i) -> Vector2:
		return Vector2(cell.x * 64.0, cell.y * 64.0)


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


func _horizontal_path(from_x: int, to_x: int, y: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for x in range(from_x, to_x + 1):
		result.append(Vector2i(x, y))
	return result


func _panel_content_text(panel) -> String:
	var content := panel.get("_content") as VBoxContainer
	var lines: Array[String] = []
	for child in content.get_children():
		if child is RichTextLabel:
			lines.append((child as RichTextLabel).get_parsed_text())
		elif child is Label:
			lines.append(str(child.get("text")))
	return "\n".join(lines)


func test_control_level_is_copied_from_unit_data() -> void:
	var data := UnitData.new()
	data.control_level = UnitData.ControlLevel.HEAVY_CONTROL
	var unit := Unit.from_data(data)

	assert_eq(unit.control_level, UnitData.ControlLevel.HEAVY_CONTROL)
	assert_true(unit.can_exert_control())
	assert_eq(unit.get_control_cost(), 2)


func test_01_no_control_keeps_the_base_cost() -> void:
	var grid := GridData.new(4, 4)
	var mover := _place(grid, _unit("Mover", 0), Vector2i(1, 1))
	_place(grid, _unit("Neutral", 1), Vector2i(1, 0))
	var pathfinder := Pathfinder.new(grid)

	assert_eq(
		pathfinder.get_movement_cost(mover, Vector2i(1, 1), Vector2i(2, 1)),
		1,
	)


func test_02_entering_control_has_no_surcharge() -> void:
	var grid := GridData.new(5, 3)
	var mover := _place(grid, _unit("Mover", 0), Vector2i(0, 1))
	_place(
		grid,
		_unit("Controller", 1, UnitData.ControlLevel.CONTROL),
		Vector2i(2, 1),
	)
	var pathfinder := Pathfinder.new(grid)

	assert_eq(
		pathfinder.get_movement_cost(mover, Vector2i(0, 1), Vector2i(1, 1)),
		1,
	)


func test_03_leaving_control_costs_one_extra_mp() -> void:
	var grid := GridData.new(4, 4)
	var mover := _place(grid, _unit("Mover", 0), Vector2i(1, 1))
	_place(
		grid,
		_unit("Controller", 1, UnitData.ControlLevel.CONTROL),
		Vector2i(1, 0),
	)
	var pathfinder := Pathfinder.new(grid)

	assert_eq(
		pathfinder.get_movement_cost(mover, Vector2i(1, 1), Vector2i(2, 1)),
		2,
	)


func test_04_leaving_heavy_control_costs_two_extra_mp() -> void:
	var grid := GridData.new(4, 4)
	var mover := _place(grid, _unit("Mover", 0), Vector2i(1, 1))
	_place(
		grid,
		_unit("Heavy", 1, UnitData.ControlLevel.HEAVY_CONTROL),
		Vector2i(1, 0),
	)
	var pathfinder := Pathfinder.new(grid)

	assert_eq(
		pathfinder.get_movement_cost(mover, Vector2i(1, 1), Vector2i(2, 1)),
		3,
	)


func test_05_remaining_adjacent_to_the_same_controller_is_free() -> void:
	var grid := GridData.new(4, 4)
	var mover := _place(grid, _unit("Mover", 0), Vector2i(1, 0))
	_place(
		grid,
		_unit("Controller", 1, UnitData.ControlLevel.CONTROL),
		Vector2i(1, 1),
	)
	var pathfinder := Pathfinder.new(grid)

	assert_eq(
		pathfinder.get_movement_cost(mover, Vector2i(1, 0), Vector2i(0, 1)),
		1,
	)


func test_diagonal_cells_are_not_controlled() -> void:
	var grid := GridData.new(4, 4)
	var mover := _place(grid, _unit("Mover", 0), Vector2i(1, 1))
	_place(
		grid,
		_unit("Diagonal", 1, UnitData.ControlLevel.HEAVY_CONTROL),
		Vector2i(0, 0),
	)
	var pathfinder := Pathfinder.new(grid)

	assert_eq(
		pathfinder.get_movement_cost(mover, Vector2i(1, 1), Vector2i(2, 1)),
		1,
	)


func test_06_two_control_costs_do_not_stack() -> void:
	var grid := GridData.new(5, 5)
	var mover := _place(grid, _unit("Mover", 0), Vector2i(2, 2))
	_place(
		grid,
		_unit("Left", 1, UnitData.ControlLevel.CONTROL),
		Vector2i(1, 2),
	)
	_place(
		grid,
		_unit("Top", 1, UnitData.ControlLevel.CONTROL),
		Vector2i(2, 1),
	)
	var pathfinder := Pathfinder.new(grid)

	assert_eq(
		pathfinder.get_disengagement_cost(
			mover, Vector2i(2, 2), Vector2i(2, 3)
		),
		1,
	)


func test_07_control_and_heavy_control_use_only_the_highest_cost() -> void:
	var grid := GridData.new(5, 5)
	var mover := _place(grid, _unit("Mover", 0), Vector2i(2, 2))
	_place(
		grid,
		_unit("Control", 1, UnitData.ControlLevel.CONTROL),
		Vector2i(1, 2),
	)
	_place(
		grid,
		_unit("Heavy", 1, UnitData.ControlLevel.HEAVY_CONTROL),
		Vector2i(2, 1),
	)
	var pathfinder := Pathfinder.new(grid)

	assert_eq(
		pathfinder.get_disengagement_cost(
			mover, Vector2i(2, 2), Vector2i(2, 3)
		),
		2,
	)


func test_leaving_one_controller_still_costs_while_remaining_with_another() -> void:
	var grid := GridData.new(5, 5)
	var mover := _place(grid, _unit("Mover", 0), Vector2i(2, 1))
	_place(
		grid,
		_unit("Left behind", 1, UnitData.ControlLevel.CONTROL),
		Vector2i(3, 1),
	)
	_place(
		grid,
		_unit("Still adjacent", 1, UnitData.ControlLevel.HEAVY_CONTROL),
		Vector2i(2, 2),
	)
	var pathfinder := Pathfinder.new(grid)

	assert_eq(
		pathfinder.get_disengagement_cost(
			mover, Vector2i(2, 1), Vector2i(1, 2)
		),
		1,
	)


func test_08_forced_movement_ignores_control_and_spends_no_mp() -> void:
	var field := Factory.make_battlefield(5, 3)
	var controller := _place(
		field.grid,
		_unit("Controller", 1, UnitData.ControlLevel.CONTROL),
		Vector2i(1, 1),
	)
	var mover := _place(field.grid, _unit("Mover", 0), Vector2i(2, 1))
	mover.current_mp = 1
	var initial_ap := mover.current_ap

	assert_eq(
		field.pathfinder.get_movement_cost(
			mover,
			Vector2i(2, 1),
			Vector2i(3, 1),
			Pathfinder.MovementType.FORCED,
		),
		1,
	)
	var result := field.caster._push_unit(controller, mover, 1)
	assert_true(result.pushed)
	assert_eq(mover.grid_pos, Vector2i(3, 1))
	assert_eq(mover.current_mp, 1)
	assert_eq(mover.current_ap, initial_ap)


func test_09_teleport_ignores_control_and_spends_no_mp() -> void:
	var field := Factory.make_battlefield(5, 3)
	var mover := _place(field.grid, _unit("Mover", 0), Vector2i(1, 1))
	var controller := _place(
		field.grid,
		_unit("Controller", 1, UnitData.ControlLevel.HEAVY_CONTROL),
		Vector2i(2, 1),
	)
	mover.current_mp = 1

	assert_eq(
		field.pathfinder.get_movement_cost(
			mover,
			Vector2i(1, 1),
			Vector2i(3, 1),
			Pathfinder.MovementType.TELEPORT,
		),
		1,
	)
	assert_true(field.caster._teleport_behind_target(mover, controller))
	assert_eq(mover.grid_pos, Vector2i(3, 1))
	assert_eq(mover.current_mp, 1)


func test_10_dead_controller_immediately_stops_controlling() -> void:
	var grid := GridData.new(4, 4)
	var mover := _place(grid, _unit("Mover", 0), Vector2i(1, 1))
	var controller := _place(
		grid,
		_unit("Controller", 1, UnitData.ControlLevel.CONTROL),
		Vector2i(1, 0),
	)
	controller.is_alive = false
	var pathfinder := Pathfinder.new(grid)

	assert_false(controller.can_exert_control())
	assert_eq(
		pathfinder.get_movement_cost(mover, Vector2i(1, 1), Vector2i(2, 1)),
		1,
	)


func test_11_allies_and_the_unit_itself_never_control_the_mover() -> void:
	var grid := GridData.new(4, 4)
	var mover := _place(
		grid,
		_unit("Mover", 0, UnitData.ControlLevel.HEAVY_CONTROL),
		Vector2i(1, 1),
	)
	_place(
		grid,
		_unit("Ally", 0, UnitData.ControlLevel.HEAVY_CONTROL),
		Vector2i(1, 0),
	)
	var pathfinder := Pathfinder.new(grid)

	assert_eq(
		pathfinder.get_movement_cost(mover, Vector2i(1, 1), Vector2i(2, 1)),
		1,
	)


func test_12_insufficient_mp_makes_the_destination_unreachable() -> void:
	var grid := GridData.new(4, 4)
	var mover := _place(grid, _unit("Mover", 0), Vector2i(1, 1))
	_place(
		grid,
		_unit("Controller", 1, UnitData.ControlLevel.CONTROL),
		Vector2i(1, 0),
	)
	mover.current_mp = 1
	var pathfinder := Pathfinder.new(grid)
	var destination := Vector2i(2, 1)
	var cost := pathfinder.get_movement_cost(mover, mover.grid_pos, destination)

	assert_eq(cost, 2)
	assert_false(pathfinder.get_reachable(mover.grid_pos, mover.current_mp, mover).has(
		destination
	))
	assert_false(mover.spend_mp(cost))
	assert_eq(mover.current_mp, 1)


func test_engagement_range_keeps_real_cells_green_and_lost_edge_cells_red() -> void:
	var grid := GridData.new(7, 7)
	var mover := _place(grid, _unit("Mover", 0), Vector2i(3, 3))
	var controller := _place(
		grid,
		_unit("Controller", 1, UnitData.ControlLevel.CONTROL),
		Vector2i(3, 2),
	)
	var battle = BattleScript.new()
	battle.pathfinder = Pathfinder.new(grid)
	var grid_view = GridViewScript.new()
	grid_view.setup(grid)
	battle.add_child(grid_view)
	battle.grid_view = grid_view
	battle.turn_queue = TurnQueue.new()
	battle.turn_queue.setup([mover])
	battle.turn_queue.start()
	mover.current_mp = 3

	var layers := battle._movement_range_layers(mover)
	assert_true((layers.reachable as Array).has(Vector2i(5, 3)))
	assert_false((layers.reachable as Array).has(Vector2i(6, 3)))
	assert_true((layers.control_limited as Array).has(Vector2i(6, 3)))
	for cell in layers.control_limited:
		assert_false((layers.reachable as Array).has(cell))

	battle._on_request_show_move_range()
	var highlights := grid_view.get("_highlights") as Dictionary
	assert_eq(highlights.get(Vector2i(5, 3)), BattleScript.MOVE_COLOR)
	assert_eq(
		highlights.get(Vector2i(6, 3)),
		BattleScript.CONTROL_LIMITED_MOVE_COLOR,
	)

	controller.is_alive = false
	var released_layers := battle._movement_range_layers(mover)
	assert_true((released_layers.control_limited as Array).is_empty())
	assert_true((released_layers.reachable as Array).has(Vector2i(6, 3)))
	battle.free()


func test_13_pathfinding_can_prefer_a_longer_path_without_disengagements() -> void:
	var grid := GridData.new(7, 3)
	var mover := _place(grid, _unit("Mover", 0), Vector2i(0, 1))
	for x in [2, 3, 4]:
		_place(
			grid,
			_unit("Controller %d" % x, 1, UnitData.ControlLevel.CONTROL),
			Vector2i(x, 0),
		)
	var pathfinder := Pathfinder.new(grid)
	var short_path := _horizontal_path(0, 6, 1)
	var chosen_path := pathfinder.find_path(mover.grid_pos, Vector2i(6, 1), mover)

	assert_eq(pathfinder.path_movement_cost(short_path, mover), 9)
	assert_eq(pathfinder.path_movement_cost(chosen_path, mover), 8)
	assert_gt(chosen_path.size(), short_path.size())
	assert_eq(
		pathfinder.path_cost_breakdown(chosen_path, mover).disengagement,
		0,
	)


func test_14_distinct_successive_disengagements_each_apply_once() -> void:
	var grid := GridData.new(8, 3)
	var mover := _place(grid, _unit("Mover", 0), Vector2i(0, 1))
	for x in [2, 5]:
		_place(
			grid,
			_unit("Controller %d" % x, 1, UnitData.ControlLevel.CONTROL),
			Vector2i(x, 0),
		)
	var pathfinder := Pathfinder.new(grid)
	var breakdown := pathfinder.path_cost_breakdown(
		_horizontal_path(0, 7, 1), mover
	)

	assert_eq(breakdown.base, 7)
	assert_eq(breakdown.disengagement, 2)
	assert_eq(breakdown.total, 9)
	assert_eq(
		breakdown.disengagement_cells,
		[Vector2i(2, 1), Vector2i(5, 1)],
	)


func test_ai_uses_a_strictly_affordable_path_prefix() -> void:
	var field := Factory.make_battlefield(5, 5)
	var enemy := _place(field.grid, _unit("Enemy", 1), Vector2i(2, 2))
	var controller := _place(
		field.grid,
		_unit("Hero", 0, UnitData.ControlLevel.CONTROL),
		Vector2i(2, 1),
	)
	var ai := EnemyAI.new(field.grid, field.pathfinder, field.caster)
	enemy.current_mp = 1

	assert_true(ai._decide_flee(enemy, [enemy, controller]).is_empty())
	enemy.current_mp = 2
	var plan := ai._decide_flee(enemy, [enemy, controller])
	assert_false(plan.is_empty())
	assert_lte(
		field.pathfinder.path_movement_cost(plan[0].path, enemy),
		enemy.current_mp,
	)


func test_path_preview_exposes_only_disengagement_cost_and_cell() -> void:
	var grid_view := GridViewFixture.new()
	add_child_autofree(grid_view)
	var preview := MovementPathPreviewScript.new() as MovementPathPreview
	grid_view.add_child(preview)
	preview.setup(grid_view)
	preview.set_path(
		[Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1)],
		{
			"total": 3,
			"base": 2,
			"disengagement": 1,
			"disengagement_cells": [Vector2i(1, 1)],
		},
	)

	assert_eq(preview.get_cost_label(), "-1 PM")
	assert_eq(
		preview.get_disengagement_points(),
		PackedVector2Array([Vector2(64.0, 64.0)]),
	)


func test_path_preview_hides_normal_movement_cost() -> void:
	var grid_view := GridViewFixture.new()
	add_child_autofree(grid_view)
	var preview := MovementPathPreviewScript.new() as MovementPathPreview
	grid_view.add_child(preview)
	preview.setup(grid_view)
	preview.set_path(
		[Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1)],
		{
			"total": 2,
			"base": 2,
			"disengagement": 0,
			"disengagement_cells": [],
		},
	)

	assert_eq(preview.get_cost_label(), "")


func test_inspect_panel_displays_current_engagement() -> void:
	var grid := GridData.new(4, 4)
	var elf := _place(grid, _unit("Elfe", 0), Vector2i(1, 1))
	var skeleton := _place(
		grid,
		_unit("Squelette", 1, UnitData.ControlLevel.CONTROL),
		Vector2i(1, 0),
	)
	var pathfinder := Pathfinder.new(grid)
	var panel = InspectPanelScript.new()
	add_child_autofree(panel)
	panel.setup(pathfinder, grid)
	panel.show_unit(elf)
	var content := _panel_content_text(panel)

	assert_eq(pathfinder.get_engaging_controllers(elf), [skeleton])
	assert_string_contains(content, "Engagement")
	assert_string_contains(content, "Engagé par")
	assert_string_contains(content, "Squelette")
	assert_string_contains(content, "-1 PM supplémentaire")

	assert_true(grid.relocate_unit(skeleton, Vector2i(3, 0)))
	await get_tree().process_frame
	assert_false(_panel_content_text(panel).contains("Engagement"))
