class_name PremiumPanelOrnament
extends Control
## Filets, coins et diamant central dessines en vectoriel pour rester nets.

@export_enum("screen", "panel", "header", "card") var variant := "panel"
@export var accent_alpha := 0.9

const GOLD := Color(0.76, 0.56, 0.31, 1.0)
const GOLD_HOT := Color(1.0, 0.72, 0.22, 1.0)
const BRONZE_DARK := Color(0.24, 0.16, 0.12, 1.0)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	queue_redraw()


func _draw() -> void:
	if size.x < 12.0 or size.y < 12.0:
		return
	var inset := 5.0 if variant in ["screen", "card"] else 3.0
	var outer := Rect2(Vector2(inset, inset), size - Vector2.ONE * inset * 2.0)
	draw_rect(outer, Color(GOLD, accent_alpha * 0.5), false, 1.0)
	if variant in ["screen", "card"] and size.x > 80.0 and size.y > 60.0:
		var inner := outer.grow(-5.0)
		draw_rect(inner, Color(BRONZE_DARK, accent_alpha), false, 1.0)
	_draw_corners(outer)
	if variant in ["screen", "header"]:
		_draw_center_diamond(outer)


func _draw_corners(rect: Rect2) -> void:
	var length := 20.0 if variant == "screen" else 12.0
	var color := Color(GOLD_HOT, accent_alpha)
	var points := [
		[rect.position + Vector2(length, 0), rect.position,
			rect.position + Vector2(0, length)],
		[Vector2(rect.end.x - length, rect.position.y),
			Vector2(rect.end.x, rect.position.y),
			Vector2(rect.end.x, rect.position.y + length)],
		[Vector2(rect.position.x, rect.end.y - length),
			Vector2(rect.position.x, rect.end.y),
			Vector2(rect.position.x + length, rect.end.y)],
		[Vector2(rect.end.x - length, rect.end.y), rect.end,
			Vector2(rect.end.x, rect.end.y - length)],
	]
	for corner in points:
		draw_polyline(PackedVector2Array(corner), color, 2.0, true)


func _draw_center_diamond(rect: Rect2) -> void:
	if rect.size.x < 140.0:
		return
	var center := Vector2(rect.get_center().x, rect.position.y)
	var radius := 5.0 if variant == "header" else 6.0
	var diamond := PackedVector2Array([
		center + Vector2(0, -radius),
		center + Vector2(radius, 0),
		center + Vector2(0, radius),
		center + Vector2(-radius, 0),
	])
	draw_colored_polygon(diamond, Color(GOLD_HOT, accent_alpha))
	draw_polyline(diamond + PackedVector2Array([diamond[0]]), BRONZE_DARK, 1.0, true)
