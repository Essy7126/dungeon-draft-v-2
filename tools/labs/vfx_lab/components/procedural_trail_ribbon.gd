extends Node2D

var lifetime := 0.42
var width := 12.0
var color_start := Color.WHITE
var color_end := Color(1.0, 1.0, 1.0, 0.0)
var _samples: Array[Dictionary] = []


func configure(config: Dictionary) -> void:
	lifetime = maxf(0.05, float(config.get("lifetime", 0.42)))
	width = float(config.get("width", 12.0))
	color_start = config.get("color_start", Color.WHITE) as Color
	color_end = config.get("color_end", Color(1.0, 1.0, 1.0, 0.0)) as Color
	_samples.clear()
	queue_redraw()


func push_point(point: Vector2) -> void:
	if not _samples.is_empty() and (point - (_samples.back()["position"] as Vector2)).length() < 3.0:
		return
	_samples.append({"position": point, "age": 0.0})
	if _samples.size() > 48:
		_samples.pop_front()
	queue_redraw()


func advance(delta: float) -> void:
	for sample in _samples:
		sample["age"] = float(sample["age"]) + maxf(0.0, delta)
	while not _samples.is_empty() and float(_samples.front()["age"]) > lifetime:
		_samples.pop_front()
	queue_redraw()


func get_points() -> Array[Dictionary]:
	return _samples.duplicate(true)


func _draw() -> void:
	if _samples.size() < 2:
		return
	for index in range(_samples.size() - 1):
		var first := _samples[index]
		var second := _samples[index + 1]
		var age_ratio := clampf(float(second["age"]) / lifetime, 0.0, 1.0)
		var line_color := color_start.lerp(color_end, age_ratio)
		var segment_width := maxf(0.5, width * pow(1.0 - age_ratio, 0.75))
		var glow := line_color
		glow.a *= 0.2
		draw_line(first["position"], second["position"], glow, segment_width * 2.8, true)
		draw_line(first["position"], second["position"], line_color, segment_width, true)
