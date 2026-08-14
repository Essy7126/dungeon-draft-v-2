class_name VFXFlipbookLabStage
extends Node2D

var light_background := false
var center := Vector2.ZERO
var cell_size := Vector2(96, 48)


func configure(stage_center: Vector2, use_light_background: bool) -> void:
	center = stage_center
	light_background = use_light_background
	queue_redraw()


func _draw() -> void:
	var backdrop := Color("dce6ef") if light_background else Color("101722")
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), backdrop)
	var fill_a := Color("b8c7d6") if light_background else Color("1b2938")
	var fill_b := Color("d2dce5") if light_background else Color("22364a")
	var line := Color("536b7e") if light_background else Color("41647d")
	for row in range(-3, 4):
		for column in range(-5, 6):
			var point := center + Vector2(
				(column - row) * cell_size.x * 0.5,
				(column + row) * cell_size.y * 0.5,
			)
			var diamond := PackedVector2Array([
				point + Vector2(0, -cell_size.y * 0.5),
				point + Vector2(cell_size.x * 0.5, 0),
				point + Vector2(0, cell_size.y * 0.5),
				point + Vector2(-cell_size.x * 0.5, 0),
			])
			var fill := fill_a if posmod(row + column, 2) == 0 else fill_b
			draw_colored_polygon(diamond, fill)
			draw_polyline(diamond + PackedVector2Array([diamond[0]]), line, 1.2, true)
