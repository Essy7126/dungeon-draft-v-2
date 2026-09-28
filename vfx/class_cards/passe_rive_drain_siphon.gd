extends Node2D
## One clock, target-to-hand flow; never changes HP or invokes combat effects.
const LIFETIME := 0.42
var phase := 0.0
var start := Vector2.ZERO
var finish := Vector2.ZERO
var glint := false


func sample(elapsed: float, confirmed: bool, healed: bool, origin: Vector2, hand: Vector2) -> void:
	visible = confirmed and elapsed >= 0.0 and elapsed < LIFETIME
	phase = clampf(elapsed / LIFETIME, 0.0, 1.0)
	start = origin
	finish = hand
	glint = visible and healed and phase >= 0.42
	queue_redraw()


func _point(t: float) -> Vector2:
	return start.lerp(finish, t) + Vector2(0, -22.0 * sin(t * PI))


func _draw() -> void:
	if not visible:
		return
	var alpha := minf(phase * 8.0 + 0.15, 1.0) * (1.0 - phase)
	var points := PackedVector2Array()
	for i in 33:
		points.append(_point(i / 32.0))
	draw_polyline(points, Color(0.42, 0.3, 0.65, alpha * 0.35), 9.0, true)
	draw_polyline(points, Color(0.78, 0.67, 0.9, alpha), 2.5, true)
	for i in 3:
		var t := clampf(phase * 1.8 - i * 0.17, 0.0, 1.0)
		draw_circle(_point(t), 3.0, Color(0.84, 0.78, 0.95, alpha))
	if glint:
		var a := sin((phase - 0.42) / 0.58 * PI)
		var c := Color(0.9, 0.97, 0.77, a)
		draw_line(finish - Vector2(0, 13), finish + Vector2(0, 13), c, 3.0, true)
		draw_line(finish - Vector2(8, 0), finish + Vector2(8, 0), c, 3.0, true)
