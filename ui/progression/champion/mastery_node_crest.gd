class_name MasteryNodeCrest
extends Control
## Vector ornamentation remains sharp at every map zoom and never handles input.

var _kind := "mastery"
var _state := "locked"
var _selected := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)


func configure(kind: String, state: String, selected: bool) -> void:
	if _kind == kind and _state == state and _selected == selected:
		return
	_kind = kind
	_state = state
	_selected = selected
	queue_redraw()


func _draw() -> void:
	if _kind == "mastery":
		return
	var color := Color("b08e61")
	if _state == "acquired":
		color = Color("a9c5a3")
	elif _state == "excluded":
		color = Color("8d6158")
	elif _state == "locked":
		color = Color("86704f")
	if _selected:
		color = color.lightened(0.24)
	var left := 4.0
	var right := size.x - 4.0
	var bottom := size.y - 4.0
	match _kind:
		"capstone":
			for x: float in [left, right]:
				var inward := 1.0 if x == left else -1.0
				draw_polyline(PackedVector2Array([Vector2(x + inward * 13, 4), Vector2(x, 4), Vector2(x, 18)]), color, 2, true)
				draw_polyline(PackedVector2Array([Vector2(x, bottom - 14), Vector2(x, bottom), Vector2(x + inward * 13, bottom)]), color, 2, true)
			_diamond(Vector2(size.x * 0.5, 3), 3.0, color)
		"summit":
			for x: float in [left + 7, right - 7]:
				draw_polyline(PackedVector2Array([Vector2(x - 5, 10), Vector2(x, 3), Vector2(x + 5, 10)]), color, 1.5, true)
			draw_line(Vector2(left, bottom), Vector2(right, bottom), color, 1.5, true)
		"junction":
			_diamond(Vector2(size.x * 0.5 - 4, bottom + 1), 3.0, color)
			_diamond(Vector2(size.x * 0.5 + 4, bottom + 1), 3.0, color)
		"apotheosis":
			var frame := PackedVector2Array([Vector2(left + 9, 3), Vector2(right - 9, 3), Vector2(right, 12), Vector2(right, bottom - 9), Vector2(right - 9, bottom), Vector2(left + 9, bottom), Vector2(left, bottom - 9), Vector2(left, 12), Vector2(left + 9, 3)])
			draw_polyline(frame, color, 1.5, true)
			_diamond(Vector2(size.x * 0.5, 3), 3.0, color)
			draw_line(Vector2(left + 3, 18), Vector2(left + 3, bottom - 14), Color(color, 0.55), 1, true)
			draw_line(Vector2(right - 3, 18), Vector2(right - 3, bottom - 14), Color(color, 0.55), 1, true)


func _diamond(center: Vector2, radius: float, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([center + Vector2(0, -radius), center + Vector2(radius, 0), center + Vector2(0, radius), center + Vector2(-radius, 0)]), color)
