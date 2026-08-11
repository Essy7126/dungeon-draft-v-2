@tool
class_name VFXComposerPreviewStage
extends Control

@export var dark_background := true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	queue_redraw()


func _draw() -> void:
	var background := Color("101927") if dark_background else Color("dbe6ef")
	draw_rect(Rect2(Vector2.ZERO, size), background)
	var grid_color := Color(0.28, 0.48, 0.62, 0.18) if dark_background \
		else Color(0.15, 0.3, 0.4, 0.17)
	var center := Vector2(size.x * 0.5, size.y * 0.52)
	for row in range(-8, 9):
		for column in range(-10, 11):
			var point := center + Vector2((column - row) * 24.0, (column + row) * 12.0)
			if point.x < -24.0 or point.x > size.x + 24.0 or point.y < -12.0 or point.y > size.y + 12.0:
				continue
			var diamond := PackedVector2Array([
				point + Vector2(0, -12), point + Vector2(24, 0),
				point + Vector2(0, 12), point + Vector2(-24, 0), point + Vector2(0, -12),
			])
			draw_polyline(diamond, grid_color, 1.0, true)
