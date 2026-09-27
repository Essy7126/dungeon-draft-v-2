extends Node2D
## Hand-bound bronze arc; timing is sampled by the body, never a second game clock.
const LIFETIME := 0.24
var phase := 0.0


func sample(elapsed: float, confirmed: bool) -> void:
	visible = confirmed and elapsed >= 0.0 and elapsed < LIFETIME
	phase = clampf(elapsed / LIFETIME, 0.0, 1.0)
	queue_redraw()


func _draw() -> void:
	if not visible:
		return
	var points := PackedVector2Array()
	var growth := 0.75 + 0.25 * minf(phase * 3.0, 1.0)
	for i in 25:
		var angle := lerpf(-PI * 0.56, PI * 0.56, i / 24.0)
		points.append(Vector2(cos(angle) * 30.0, sin(angle) * 62.0) * growth)
	var alpha := 1.0 - phase
	draw_polyline(points, Color(0.75, 0.55, 0.22, alpha * 0.6), 8.0, true)
	draw_polyline(points, Color(1.0, 0.88, 0.58, alpha), 3.0, true)
