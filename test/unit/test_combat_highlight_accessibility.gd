extends GutTest

const MARKER := preload("res://battle/combat_highlight_marker.gd")


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
