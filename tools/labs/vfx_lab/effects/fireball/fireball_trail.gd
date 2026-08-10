extends Node2D

var _samples: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
var _lifetime := 0.46
var _width := 18.0
var _fragment_chance := 0.14
var _strand_offset := 0.0
var _edge_color := Color("e93612")
var _body_color := Color("ff932d")
var _core_color := Color("ffe8a3")


func configure(config: Dictionary) -> void:
	_samples.clear()
	_rng.seed = int(config.get("seed", 1))
	_lifetime = maxf(0.08, float(config.get("lifetime", 0.46)))
	_width = maxf(2.0, float(config.get("width", 18.0)))
	_fragment_chance = clampf(float(config.get("fragment_chance", 0.14)), 0.0, 0.6)
	_strand_offset = maxf(0.0, float(config.get("strand_offset", 0.0)))
	_edge_color = config.get("edge_color", _edge_color) as Color
	_body_color = config.get("body_color", _body_color) as Color
	_core_color = config.get("core_color", _core_color) as Color
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = additive
	queue_redraw()


func push_point(point: Vector2) -> void:
	if not _samples.is_empty() \
		and point.distance_to(_samples.back()["position"] as Vector2) < 3.0:
		return
	var direction := Vector2.RIGHT
	if not _samples.is_empty():
		direction = (point - (_samples.back()["position"] as Vector2)).normalized()
	var normal := direction.orthogonal()
	var offset := normal * _rng.randf_range(-2.8, 2.8)
	_samples.append({
		"position": point + offset,
		"age": 0.0,
		"width_factor": _rng.randf_range(0.68, 1.28),
		"cut": _rng.randf() < _fragment_chance,
		"phase": _rng.randf_range(0.0, TAU),
	})
	if _samples.size() > 72:
		_samples.pop_front()
	queue_redraw()


func advance(delta: float) -> void:
	for sample in _samples:
		sample["age"] = float(sample["age"]) + maxf(0.0, delta)
	while not _samples.is_empty() and float(_samples.front()["age"]) > _lifetime:
		_samples.pop_front()
	queue_redraw()


func get_signature() -> String:
	var values: Array[String] = []
	for sample in _samples.slice(0, mini(6, _samples.size())):
		values.append("%.2f:%.2f" % [float(sample["width_factor"]), float(sample["phase"])])
	return "|".join(values)


func _draw() -> void:
	if _samples.size() < 2:
		return
	_draw_ribbon_layer(1.0, _edge_color, -_strand_offset, 0.34)
	if _strand_offset > 0.0:
		_draw_ribbon_layer(1.0, _edge_color, _strand_offset, 0.34)
	_draw_ribbon_layer(0.52, _body_color, -_strand_offset, 0.82)
	if _strand_offset > 0.0:
		_draw_ribbon_layer(0.52, _body_color, _strand_offset, 0.82)
	_draw_filament()


func _draw_ribbon_layer(
		width_scale: float,
		base_color: Color,
		strand_offset: float,
		alpha_scale: float
) -> void:
	var run: Array[Dictionary] = []
	for index in _samples.size():
		var sample := _samples[index]
		if bool(sample["cut"]) and index < _samples.size() - 4 and run.size() >= 2:
			_draw_ribbon_run(run, width_scale, base_color, strand_offset, alpha_scale)
			run = []
		run.append(sample)
	if run.size() >= 2:
		_draw_ribbon_run(run, width_scale, base_color, strand_offset, alpha_scale)


func _draw_ribbon_run(
		run: Array[Dictionary],
		width_scale: float,
		base_color: Color,
		strand_offset: float,
		alpha_scale: float
) -> void:
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var left_colors := PackedColorArray()
	var right_colors := PackedColorArray()
	for index in run.size():
		var previous := run[maxi(0, index - 1)]["position"] as Vector2
		var following := run[mini(run.size() - 1, index + 1)]["position"] as Vector2
		var tangent := (following - previous).normalized()
		if tangent == Vector2.ZERO:
			tangent = Vector2.RIGHT
		var normal := tangent.orthogonal()
		var sample := run[index]
		var fade := pow(clampf(1.0 - float(sample["age"]) / _lifetime, 0.0, 1.0), 1.35)
		var width_value := _width * float(sample["width_factor"]) * (0.18 + fade * 0.82) * width_scale
		var center := (sample["position"] as Vector2) + normal * strand_offset
		left.append(center + normal * width_value * 0.5)
		right.append(center - normal * width_value * 0.5)
		var color := base_color
		color.a *= fade * alpha_scale
		left_colors.append(color)
		right_colors.append(color)
	for index in range(left.size() - 1):
		draw_primitive(
			PackedVector2Array([left[index], left[index + 1], right[index + 1]]),
			PackedColorArray([left_colors[index], left_colors[index + 1], right_colors[index + 1]]),
			PackedVector2Array()
		)
		draw_primitive(
			PackedVector2Array([left[index], right[index + 1], right[index]]),
			PackedColorArray([left_colors[index], right_colors[index + 1], right_colors[index]]),
			PackedVector2Array()
		)


func _draw_filament() -> void:
	for index in range(_samples.size() - 1):
		var first := _samples[index]
		var second := _samples[index + 1]
		if bool(first["cut"]) and index < _samples.size() - 4:
			continue
		var fade_a := pow(clampf(1.0 - float(first["age"]) / _lifetime, 0.0, 1.0), 1.35)
		var fade_b := pow(clampf(1.0 - float(second["age"]) / _lifetime, 0.0, 1.0), 1.35)
		var width_a := _width * float(first["width_factor"]) * (0.18 + fade_a * 0.82)
		var width_b := _width * float(second["width_factor"]) * (0.18 + fade_b * 0.82)
		var color := _core_color
		color.a *= (fade_a + fade_b) * 0.5 * 0.88
		var line_width := maxf(0.75, (width_a + width_b) * 0.075)
		draw_line(first["position"], second["position"], color, line_width, true)
		draw_circle(second["position"], line_width * 0.48, color)
