extends Node2D
## Project room intentions onto the current arena's actual cell polygons.
var runtime: Node


func _process(_delta: float) -> void:
	visible = (
		is_instance_valid(runtime) and not runtime.battle._battle_over
		and not runtime.battle._closing
	)
	if visible:
		queue_redraw()


func _draw() -> void:
	if not is_instance_valid(runtime) or runtime.room_rules == null:
		return
	var rules = runtime.room_rules
	var view: Node2D = get_parent()
	for cell in rules.danger_cells():
		var polygon: PackedVector2Array = view.get_cell_polygon(cell)
		draw_colored_polygon(polygon, Color(1.0, .28, .08, .24))
		var outline := polygon.duplicate()
		outline.append(polygon[0])
		draw_polyline(outline, Color(1.0, .55, .28, .9), 1.5, true)
		_label(polygon, "!", Color("ffd4af"))
	for cell in rules.markers():
		var polygon: PackedVector2Array = view.get_cell_polygon(cell)
		draw_colored_polygon(polygon, Color(.1, .65, .62, .24))
		_label(polygon, str(rules.markers()[cell]), Color("fff0ad"))
	if rules.room_id == "hourglass" and rules.active():
		var clock: Vector2i = Vector2i(rules.state.clock[0], rules.state.clock[1])
		_label(view.get_cell_polygon(clock), "C", Color("ffe1a9"))


func _label(polygon: PackedVector2Array, text: String, tint: Color) -> void:
	var center := Vector2.ZERO
	for point in polygon:
		center += point
	center /= maxi(1, polygon.size())
	var font := ThemeDB.fallback_font
	var size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
	draw_string(
		font,
		center + Vector2(-size.x * .5, 4),
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		13,
		tint,
	)
