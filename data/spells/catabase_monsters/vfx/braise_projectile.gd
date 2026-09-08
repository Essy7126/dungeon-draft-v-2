extends "res://battle/vfx/skeleton_ranged_projectile_vfx.gd"
## Visual-only ember. The inherited tween travels in exactly travel_duration,
## matching the spell's impact delay at every distance, with watchdog cleanup.


func _draw() -> void:
	draw_circle(Vector2.ZERO, 13.0, Color(1.0, 0.24, 0.025, 0.13))
	draw_polygon(PackedVector2Array([
		Vector2(-25, 0), Vector2(-10, -5), Vector2(-14, -9),
		Vector2(5, -6), Vector2(12, 0), Vector2(5, 6),
		Vector2(-14, 9), Vector2(-10, 5),
	]), PackedColorArray([Color(0.95, 0.22, 0.025, 0.88)]))
	draw_circle(Vector2(3, 0), 6.5, Color(1.0, 0.55, 0.09, 1.0))
	draw_circle(Vector2(5, -0.5), 3.5, Color(1.0, 0.91, 0.52, 1.0))
	draw_line(Vector2(-20, -2), Vector2(-9, -1), Color(1.0, 0.63, 0.16, 0.7), 1.5, true)
	draw_line(Vector2(-17, 4), Vector2(-7, 2), Color(1.0, 0.4, 0.05, 0.7), 1.5, true)
