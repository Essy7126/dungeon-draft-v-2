extends Node2D

var age := 0.0
var duration := 0.22
var color := Color("b9e8ff")
var width := 3.0
var _points := PackedVector2Array()
var _branches: Array[PackedVector2Array] = []


func configure(from: Vector2, to: Vector2, config: Dictionary) -> void:
	age = 0.0
	duration = maxf(0.05, float(config.get("duration", 0.22)))
	color = config.get("color", Color("b9e8ff")) as Color
	width = float(config.get("width", 3.0))
	var segments := maxi(3, int(config.get("segments", 14)))
	var jitter := float(config.get("jitter", 18.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = int(config.get("seed", 1))
	_points.clear()
	_branches.clear()
	var direction := to - from
	var perpendicular := direction.normalized().orthogonal()
	for index in range(segments + 1):
		var t := float(index) / float(segments)
		var envelope := sin(t * PI)
		var offset := perpendicular * rng.randf_range(-jitter, jitter) * envelope
		_points.append(from.lerp(to, t) + offset)
	for index in range(3, segments - 1, 4):
		var start := _points[index]
		var branch_direction := (to - from).normalized().rotated(
			rng.randf_range(-0.9, 0.9)
		)
		var branch := PackedVector2Array([start])
		for branch_index in range(1, 4):
			branch.append(
				start
				+ branch_direction * float(branch_index) * rng.randf_range(8.0, 14.0)
				+ perpendicular * rng.randf_range(-5.0, 5.0)
			)
		_branches.append(branch)
	queue_redraw()


func advance(delta: float) -> void:
	age += maxf(0.0, delta)
	queue_redraw()


func get_signature() -> String:
	var values: Array[String] = []
	for point in _points.slice(0, mini(6, _points.size())):
		values.append("%.1f,%.1f" % [point.x, point.y])
	return "|".join(values)


func _draw() -> void:
	if _points.size() < 2 or age > duration:
		return
	var t := clampf(age / duration, 0.0, 1.0)
	var flicker := 0.78 + sin(age * 170.0) * 0.22
	var alpha := (1.0 - t) * flicker
	var glow := color
	glow.a *= alpha * 0.24
	var main := color
	main.a *= alpha
	var core := Color.WHITE
	core.a = alpha
	draw_polyline(_points, glow, width * 5.0, true)
	draw_polyline(_points, main, width * 2.1, true)
	draw_polyline(_points, core, maxf(1.0, width * 0.55), true)
	for branch in _branches:
		draw_polyline(branch, glow, width * 2.3, true)
		draw_polyline(branch, main, maxf(0.8, width * 0.65), true)
