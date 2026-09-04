extends GutTest

const MARKER := preload("res://battle/combat_highlight_marker.gd")
const PAINTED_VISUAL := preload(
	"res://data/maps/painted/room_01_forest_visual.tres"
)
const CURSOR_VIEW_SCRIPTS := [
	"res://battle/grid_view.gd",
	"res://battle/painted/painted_grid_view.gd",
]
const INVALID_CELL := Vector2i(-1, -1)


func test_same_color_keeps_distinct_non_color_semantics() -> void:
	var view := Node2D.new()
	view.set_script(load("res://battle/grid_view.gd"))
	var grid := GridData.new(5, 1)
	view.setup(grid)
	var shared_color := Color(0.4, 0.6, 0.8, 0.4)
	var markers: Array[StringName] = [
		MARKER.MOVE,
		MARKER.CONTROL_LIMITED,
		MARKER.ATTACK,
		MARKER.SPELL,
		MARKER.AOE,
	]
	for index in markers.size():
		view.highlight([Vector2i(index, 0)], shared_color, markers[index])
	var snapshot: Dictionary = view.get_highlight_snapshot()
	assert_eq(snapshot.size(), markers.size())
	for index in markers.size():
		var entry: Dictionary = snapshot[Vector2i(index, 0)]
		assert_eq(entry["color"], shared_color)
		assert_eq(entry["marker"], markers[index])
	view.free()


func test_iso_and_painted_views_preserve_the_semantic_marker_contract() -> void:
	var grid := GridData.new(2, 2)
	var cases := [
		{
			"script": "res://battle/iso/iso_grid_view.gd",
			"marker": MARKER.ATTACK,
		},
		{
			"script": "res://battle/painted/painted_grid_view.gd",
			"marker": MARKER.SPELL,
		},
	]
	for case in cases:
		var view := Node2D.new()
		view.set_script(load(case["script"]))
		view.setup(grid)
		view.highlight([Vector2i(0, 0)], Color.WHITE, case["marker"])
		var snapshot: Dictionary = view.get_highlight_snapshot()
		assert_eq(snapshot[Vector2i(0, 0)]["marker"], case["marker"])
		view.free()


func test_legacy_two_argument_highlight_remains_supported() -> void:
	var view := Node2D.new()
	view.set_script(load("res://battle/grid_view.gd"))
	view.setup(GridData.new(1, 1))
	view.highlight([Vector2i.ZERO], Color.RED)
	var entry: Dictionary = view.get_highlight_snapshot()[Vector2i.ZERO]
	assert_eq(entry["color"], Color.RED)
	assert_eq(entry["marker"], &"")
	view.free()


func test_square_and_painted_views_share_an_independent_cursor_contract() -> void:
	for script_path in CURSOR_VIEW_SCRIPTS:
		var view := _make_cursor_view(script_path)
		var grid := view.get("grid") as GridData
		var selected_cell := Vector2i(0, 0)
		var cursor_cell := Vector2i(1, 0)
		var hover_cell := Vector2i(0, 1)
		var blocked_cell := Vector2i(2, 1)
		grid.set_type(blocked_cell, GridData.CellType.WALL)

		assert_true(view.has_method("set_cursor_cell"), script_path)
		assert_true(view.has_method("clear_cursor"), script_path)
		assert_true(view.has_method("get_cursor_cell"), script_path)
		assert_eq(view.get_cursor_cell(), INVALID_CELL, script_path)

		view.set_selected_cell(selected_cell)
		view.update_hover(view.grid_to_world(hover_cell))
		assert_true(view.set_cursor_cell(cursor_cell), script_path)
		view.highlight([cursor_cell], Color(0.3, 0.55, 1.0, 0.4), MARKER.SPELL)
		view.set_cell_feedback_marker(cursor_cell, true)

		assert_eq(view.get_selected_cell(), selected_cell, script_path)
		assert_eq(view.get_hovered_cell(), hover_cell, script_path)
		assert_eq(view.get_cursor_cell(), cursor_cell, script_path)
		assert_false(view.set_cursor_cell(blocked_cell), script_path)
		assert_eq(
			view.get_cursor_cell(), cursor_cell,
			"Une destination invalide ne doit pas effacer le curseur : %s" % script_path,
		)

		view.clear_highlights()
		assert_eq(view.get_cursor_cell(), cursor_cell, script_path)
		assert_eq(view.get_selected_cell(), selected_cell, script_path)
		assert_eq(view.get_cell_feedback_snapshot().size(), 1, script_path)
		view.clear_cell_feedback_markers()
		assert_eq(view.get_cursor_cell(), cursor_cell, script_path)
		view.clear_selection()
		assert_eq(view.get_cursor_cell(), cursor_cell, script_path)

		view.clear_cursor()
		view.clear_cursor()
		assert_eq(view.get_cursor_cell(), INVALID_CELL, script_path)
		view.setup(GridData.new(1, 1))
		assert_eq(view.get_cursor_cell(), INVALID_CELL, script_path)
		assert_eq(view.get_selected_cell(), INVALID_CELL, script_path)
		assert_eq(view.get_hovered_cell(), INVALID_CELL, script_path)
		assert_true(view.get_highlight_snapshot().is_empty(), script_path)
		assert_true(view.get_cell_feedback_snapshot().is_empty(), script_path)
		view.free()


func test_only_real_mouse_motion_releases_the_spatial_cursor() -> void:
	for script_path in CURSOR_VIEW_SCRIPTS:
		var view := _make_cursor_view(script_path)
		add_child_autofree(view)
		var cursor_cell := Vector2i(1, 0)
		var releases: Array[bool] = []
		view.spatial_cursor_released.connect(
			func() -> void: releases.append(true)
		)
		assert_true(view.set_cursor_cell(cursor_cell), script_path)

		var stationary := InputEventMouseMotion.new()
		stationary.relative = Vector2.ZERO
		view._unhandled_input(stationary)
		assert_eq(view.get_cursor_cell(), cursor_cell, script_path)
		assert_true(releases.is_empty(), script_path)

		var moving := InputEventMouseMotion.new()
		moving.relative = Vector2(2.0, 0.0)
		view._unhandled_input(moving)
		assert_eq(view.get_cursor_cell(), INVALID_CELL, script_path)
		assert_eq(releases.size(), 1, script_path)


func test_range_fill_is_subordinate_to_outlines_and_target_feedback() -> void:
	var source_color := Color(0.3, 0.55, 1.0, 0.5)
	for script_path in CURSOR_VIEW_SCRIPTS:
		var view := _make_cursor_view(script_path)
		view.highlight([Vector2i.ZERO], source_color, MARKER.SPELL)
		var entry: Dictionary = view.get_highlight_snapshot()[Vector2i.ZERO]
		var fill: Color = view.call("_range_fill_color", entry)
		var outline: Color = view.call("_range_outline_color", entry)
		var constants := (view.get_script() as Script).get_script_constant_map()

		assert_eq(entry["color"], source_color, script_path)
		assert_eq(entry["marker"], MARKER.SPELL, script_path)
		assert_lt(fill.a, source_color.a, script_path)
		assert_lte(fill.a, float(constants["RANGE_FILL_ALPHA_MAX"]), script_path)
		assert_gt(outline.a, fill.a, script_path)
		assert_gt(
			float(constants["TARGET_OUTLINE_WIDTH"]),
			float(constants["RANGE_OUTLINE_WIDTH"]),
			script_path,
		)
		assert_ne(
			constants["CURSOR_LINE_COLOR"], constants["HOVER_LINE_COLOR"],
			"Le curseur spatial doit rester distinct du hover : %s" % script_path,
		)
		view.free()


func _make_cursor_view(script_path: String) -> Node2D:
	var view := Node2D.new()
	view.set_script(load(script_path))
	if script_path.contains("painted_grid_view"):
		view.configure(PAINTED_VISUAL, null)
	view.setup(GridData.new(3, 2))
	return view
