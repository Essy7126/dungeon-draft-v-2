extends Control
## Resolution-independent ornament; never participates in hit testing.
var kind: StringName = &"divider"
var accent := Color("b99d77")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	var center := size * 0.5
	match kind:
		&"seal":
			var radius := minf(size.x, size.y) * 0.44
			draw_arc(center, radius, 0.0, TAU, 64, Color(accent, 0.7), 1.2, true)
			draw_arc(center, radius - 4.0, 0.0, TAU, 64, Color(accent, 0.25), 1.0, true)
			for side: float in [-1.0, 1.0]:
				for i in range(5):
					var y := center.y + radius * 0.45 - float(i) * radius * 0.24
					var x: float = center.x + side * (radius * 0.52 - absf(y - center.y) * 0.14)
					var a := Vector2(x, y)
					draw_colored_polygon(PackedVector2Array([a, a + Vector2(side * radius * 0.18, -radius * 0.2), a + Vector2(-side * radius * 0.08, -radius * 0.12)]), accent)
			_diamond(center, radius * 0.22, accent)
		&"shadow":
			for i in range(12, 0, -1):
				var points := PackedVector2Array()
				for step in range(65):
					var angle := TAU * step / 64.0
					points.append(center + Vector2(cos(angle) * size.x * 0.5, sin(angle) * size.y * 0.5) * float(i) / 12.0)
				draw_colored_polygon(points, Color(0.025, 0.04, 0.035, 0.028))
		&"corners":
			for x in [1.0, size.x - 1.0]:
				for y in [1.0, size.y - 1.0]:
					var sx := 1.0 if x < center.x else -1.0
					var sy := 1.0 if y < center.y else -1.0
					draw_line(Vector2(x, y + 13.0 * sy), Vector2(x, y), accent, 1.0, true)
					draw_line(Vector2(x, y), Vector2(x + 13.0 * sx, y), accent, 1.0, true)
		&"primary":
			var cut := 11.0
			var points := PackedVector2Array([Vector2(cut, 3), Vector2(size.x - cut, 3), Vector2(size.x - 3, cut), Vector2(size.x - 3, size.y - cut), Vector2(size.x - cut, size.y - 3), Vector2(cut, size.y - 3), Vector2(3, size.y - cut), Vector2(3, cut), Vector2(cut, 3)])
			draw_polyline(points, Color("bda27d"), 1.1, true)
			draw_line(Vector2(19, 7), Vector2(size.x - 19, 7), Color(0.88, 0.74, 0.53, 0.35), 1.0, true)
		_:
			draw_line(Vector2(0, center.y), Vector2(center.x - 12, center.y), Color(accent, 0.32), 1.0, true)
			draw_line(Vector2(center.x + 12, center.y), Vector2(size.x, center.y), Color(accent, 0.32), 1.0, true)
			_diamond(center, 4.0, accent)

func _diamond(center: Vector2, radius: float, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([center + Vector2(0, -radius), center + Vector2(radius, 0), center + Vector2(0, radius), center + Vector2(-radius, 0)]), color)
