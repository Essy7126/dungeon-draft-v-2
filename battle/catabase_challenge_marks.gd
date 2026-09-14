extends Node2D
var controller: Node


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if not is_instance_valid(controller) or not is_instance_valid(controller.battle):
		return
	if controller.battle._battle_over or controller.state.contract != "seal":
		return
	if controller.seal.x < 0 or controller.state.sabotaged:
		return
	var cell: Vector2i = controller.seal
	var center: Vector2 = to_local(controller.battle.grid_cell_to_global(cell))
	var x_axis: Vector2 = to_local(controller.battle.grid_cell_to_global(cell + Vector2i.RIGHT)) - center
	var y_axis: Vector2 = to_local(controller.battle.grid_cell_to_global(cell + Vector2i.DOWN)) - center
	var polygon := PackedVector2Array(
		[
			center - x_axis * 0.44 - y_axis * 0.44,
			center + x_axis * 0.44 - y_axis * 0.44,
			center + x_axis * 0.44 + y_axis * 0.44,
			center - x_axis * 0.44 + y_axis * 0.44,
		]
	)
	var color := Color("67d1c1")
	draw_colored_polygon(polygon, Color(color, 0.23))
	polygon.append(polygon[0])
	draw_polyline(polygon, color, 2.0, true)
	draw_string(
		ThemeDB.fallback_font,
		center + Vector2(-34, -12),
		"SCEAU · 2 PA",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		12,
		color,
	)
