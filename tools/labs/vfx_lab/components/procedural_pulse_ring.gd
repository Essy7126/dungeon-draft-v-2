extends Node2D

var age := 0.0
var duration := 0.7
var start_radius := 5.0
var end_radius := 60.0
var aspect := 0.5
var width := 3.0
var color := Color.WHITE
var segmented := false


func configure(config: Dictionary) -> void:
	age = 0.0
	duration = maxf(0.05, float(config.get("duration", 0.7)))
	start_radius = float(config.get("start_radius", 5.0))
	end_radius = float(config.get("end_radius", 60.0))
	aspect = float(config.get("aspect", 0.5))
	width = float(config.get("width", 3.0))
	color = config.get("color", Color.WHITE) as Color
	segmented = bool(config.get("segmented", false))
	queue_redraw()


func advance(delta: float) -> void:
	age += maxf(0.0, delta)
	queue_redraw()


func _draw() -> void:
	if age < 0.0 or age > duration:
		return
	var t := clampf(age / duration, 0.0, 1.0)
	var eased := 1.0 - pow(1.0 - t, 3.0)
	var radius := lerpf(start_radius, end_radius, eased)
	var alpha := pow(1.0 - t, 1.6)
	var points := PackedVector2Array()
	var steps := 64
	for index in range(steps + 1):
		var angle := TAU * float(index) / float(steps)
		if segmented and int(float(index) / 5.0) % 2 == 1:
			continue
		points.append(Vector2(cos(angle) * radius, sin(angle) * radius * aspect))
	var glow := color
	glow.a *= alpha * 0.2
	var main := color
	main.a *= alpha
	if not segmented:
		draw_polyline(points, glow, width * 3.2, true)
		draw_polyline(points, main, width, true)
	else:
		for segment in range(0, points.size() - 1, 4):
			var finish := mini(segment + 3, points.size() - 1)
			for point_index in range(segment, finish):
				draw_line(points[point_index], points[point_index + 1], glow, width * 3.0, true)
				draw_line(points[point_index], points[point_index + 1], main, width, true)
