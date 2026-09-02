extends GutTest

const MARKER := preload("res://battle/combat_highlight_marker.gd")
const VIEW_SCRIPTS := [
	"res://battle/grid_view.gd",
	"res://battle/painted/painted_grid_view.gd",
	"res://battle/iso/iso_grid_view.gd",
]


func test_valid_and_invalid_feedback_keep_distinct_shapes_with_same_color() -> void:
	var shared_color := Color(0.74, 0.74, 0.74, 0.96)
	var valid_entry := MARKER.feedback_entry(true, shared_color)
	var invalid_entry := MARKER.feedback_entry(false, shared_color)

	assert_eq(MARKER.color_of(valid_entry), MARKER.color_of(invalid_entry))
	assert_eq(MARKER.marker_of(valid_entry), MARKER.TARGET_VALID)
	assert_eq(MARKER.marker_of(invalid_entry), MARKER.TARGET_INVALID)
	assert_eq(MARKER.shape_of(valid_entry), MARKER.SHAPE_RING_CHECK)
	assert_eq(MARKER.shape_of(invalid_entry), MARKER.SHAPE_BARRED_CIRCLE)
	assert_ne(MARKER.shape_of(valid_entry), MARKER.shape_of(invalid_entry))


func test_all_grid_views_expose_the_same_cell_feedback_api() -> void:
	var shared_color := Color(0.82, 0.82, 0.82, 0.95)
	for script_path in VIEW_SCRIPTS:
		var view := Node2D.new()
		view.set_script(load(script_path))
		view.setup(GridData.new(2, 2))

		assert_true(view.has_method("set_cell_feedback_marker"), script_path)
		assert_true(view.has_method("clear_cell_feedback_marker"), script_path)
		assert_true(view.has_method("clear_cell_feedback_markers"), script_path)
		assert_true(view.has_method("get_cell_feedback_snapshot"), script_path)

		view.set_cell_feedback_marker(Vector2i.ZERO, true, shared_color)
		view.set_cell_feedback_marker(Vector2i.ONE, false, shared_color)
		var snapshot: Dictionary = view.get_cell_feedback_snapshot()
		assert_eq(snapshot.size(), 2, script_path)
		assert_eq(snapshot[Vector2i.ZERO]["shape"], MARKER.SHAPE_RING_CHECK)
		assert_eq(snapshot[Vector2i.ONE]["shape"], MARKER.SHAPE_BARRED_CIRCLE)
		assert_eq(snapshot[Vector2i.ZERO]["color"], snapshot[Vector2i.ONE]["color"])

		view.clear_cell_feedback_marker(Vector2i.ZERO)
		assert_false(view.get_cell_feedback_snapshot().has(Vector2i.ZERO))
		view.clear_cell_feedback_markers()
		assert_true(view.get_cell_feedback_snapshot().is_empty())
		view.free()


func test_out_of_bounds_feedback_is_ignored_without_mutating_highlights() -> void:
	var view := Node2D.new()
	view.set_script(load("res://battle/grid_view.gd"))
	view.setup(GridData.new(1, 1))
	view.highlight([Vector2i.ZERO], Color.GRAY, MARKER.SPELL)
	view.set_cell_feedback_marker(Vector2i(4, 4), false, Color.GRAY)

	assert_true(view.get_cell_feedback_snapshot().is_empty())
	assert_eq(view.get_highlight_snapshot()[Vector2i.ZERO]["marker"], MARKER.SPELL)
	view.free()


func test_battle_replaces_hover_feedback_and_clears_it_with_selection() -> void:
	var view := Node2D.new()
	view.set_script(load("res://battle/grid_view.gd"))
	view.setup(GridData.new(2, 2))
	var battle = load("res://battle/battle.gd").new()
	battle.grid_view = view

	battle.call("_set_target_hover_feedback", Vector2i.ZERO, true)
	var snapshot: Dictionary = view.get_cell_feedback_snapshot()
	assert_eq(snapshot.size(), 1)
	assert_eq(snapshot[Vector2i.ZERO]["shape"], MARKER.SHAPE_RING_CHECK)

	battle.call("_set_target_hover_feedback", Vector2i.ONE, false)
	snapshot = view.get_cell_feedback_snapshot()
	assert_eq(snapshot.size(), 1, "Le nouveau survol remplace le précédent.")
	assert_false(snapshot.has(Vector2i.ZERO))
	assert_eq(snapshot[Vector2i.ONE]["shape"], MARKER.SHAPE_BARRED_CIRCLE)

	battle.call("_clear_target_hover_feedback")
	assert_true(view.get_cell_feedback_snapshot().is_empty())
	battle.free()
	view.free()
