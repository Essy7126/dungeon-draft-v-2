extends Node2D

var _cells: Array = []

func _ready() -> void:
	z_index = 5

func set_cells(cells: Array) -> void:
	_cells = cells.duplicate()
	queue_redraw()

func _draw() -> void:
	var view := get_parent()
	if view == null or not view.has_method("grid_to_world"):
		return
	for cell in _cells:
		var center: Vector2 = view.grid_to_world(cell)
		var axis_x: Vector2 = (view.grid_to_world(cell + Vector2i.RIGHT) - center) * 0.43
		var axis_y: Vector2 = (view.grid_to_world(cell + Vector2i.DOWN) - center) * 0.43
		var polygon := PackedVector2Array([center - axis_x - axis_y, center + axis_x - axis_y,
			center + axis_x + axis_y, center - axis_x + axis_y])
		draw_colored_polygon(polygon, Color(0.75, 0.58, 0.28, 0.30))
		var outline := polygon.duplicate()
		outline.append(polygon[0])
		draw_polyline(outline, Color(0.91, 0.77, 0.42, 0.9), 2.0, true)
		# A small shield silhouette remains readable over existing terrain art.
		var shield := PackedVector2Array([center + Vector2(-7, -10), center + Vector2(7, -10),
			center + Vector2(6, 0), center + Vector2(0, 6), center + Vector2(-6, 0)])
		draw_colored_polygon(shield, Color(0.95, 0.83, 0.56, 0.95))
