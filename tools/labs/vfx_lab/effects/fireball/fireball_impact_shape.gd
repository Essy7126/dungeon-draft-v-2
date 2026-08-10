extends Node2D

var _age := -1.0
var _rng := RandomNumberGenerator.new()
var _lobes: Array[Dictionary] = []
var _arcs: Array[Dictionary] = []
var _radius := 92.0
var _edge_color := Color("ed3e15")
var _body_color := Color("ff8d24")
var _core_color := Color("fff1ae")
var _smoke_color := Color("351014")
var _arc_color := Color("ffb14a")


func configure(config: Dictionary) -> void:
	_age = -1.0
	_rng.seed = int(config.get("seed", 1))
	_radius = float(config.get("radius", 92.0))
	_edge_color = config.get("edge_color", _edge_color) as Color
	_body_color = config.get("body_color", _body_color) as Color
	_core_color = config.get("core_color", _core_color) as Color
	_smoke_color = config.get("smoke_color", _smoke_color) as Color
	_arc_color = config.get("arc_color", _arc_color) as Color
	_lobes.clear()
	_arcs.clear()
	var lobe_count := int(config.get("lobe_count", 7))
	for index in lobe_count:
		var angle := _rng.randf_range(-PI * 0.98, PI * 0.12)
		if index == 0:
			angle = -PI * 0.5
		_lobes.append({
			"angle": angle,
			"size": _rng.randf_range(0.28, 0.48) * _radius,
			"stretch": _rng.randf_range(1.08, 1.76),
			"distance": _rng.randf_range(0.24, 0.58) * _radius,
			"delay": _rng.randf_range(0.0, 0.10),
			"phase": _rng.randf_range(0.0, TAU),
		})
	for _index in 3:
		_arcs.append({
			"start": _rng.randf_range(-PI * 0.95, PI * 0.75),
			"length": _rng.randf_range(0.55, 1.35),
			"radius": _rng.randf_range(0.54, 0.95) * _radius,
			"delay": _rng.randf_range(0.025, 0.12),
			"phase": _rng.randf_range(0.0, TAU),
		})
	queue_redraw()


func start() -> void:
	_age = 0.0
	queue_redraw()


func advance(delta: float) -> void:
	if _age >= 0.0:
		_age += maxf(0.0, delta)
		queue_redraw()


func get_signature() -> String:
	var values: Array[String] = []
	for lobe in _lobes.slice(0, mini(5, _lobes.size())):
		values.append("%.2f:%.2f" % [float(lobe["angle"]), float(lobe["size"])])
	return "|".join(values)


func _draw() -> void:
	if _age < 0.0 or _age > 0.92:
		return
	var contact_fade := clampf(1.0 - _age / 0.14, 0.0, 1.0)
	if contact_fade > 0.0:
		_draw_irregular_lobe(Vector2.ZERO, 9.0 + _age * 115.0, 1.35, -0.35, 0.0, _core_color, contact_fade)
	for lobe in _lobes:
		var local_age := _age - float(lobe["delay"])
		if local_age < 0.0 or local_age > 0.72:
			continue
		var t := clampf(local_age / 0.72, 0.0, 1.0)
		var impulse := 1.0 - pow(1.0 - minf(1.0, t * 2.4), 3.0)
		var fade := pow(1.0 - t, 1.22)
		var angle := float(lobe["angle"])
		var center := Vector2.from_angle(angle) * float(lobe["distance"]) * impulse
		center.y -= sin(t * PI) * float(lobe["size"]) * 0.24
		var size := float(lobe["size"]) * (0.22 + sin(minf(1.0, t * 1.25) * PI) * 0.78)
		var phase := float(lobe["phase"])
		_draw_irregular_lobe(center, size * 1.08, float(lobe["stretch"]), angle, phase, _smoke_color, fade * 0.26)
		_draw_irregular_lobe(center, size, float(lobe["stretch"]) * 0.82, angle, phase + 1.7, _edge_color, fade * 0.66)
		_draw_irregular_lobe(center * 0.82, size * 0.62, float(lobe["stretch"]) * 0.68, angle, phase + 3.1, _body_color, fade * 0.78)
		if t < 0.48:
			_draw_irregular_lobe(center * 0.55, size * 0.28, 1.25, angle, phase + 4.3, _core_color, fade)
	for arc in _arcs:
		var arc_age := _age - float(arc["delay"])
		if arc_age < 0.0 or arc_age > 0.48:
			continue
		var t := arc_age / 0.48
		var radius := float(arc["radius"]) * (0.18 + (1.0 - pow(1.0 - t, 3.0)) * 0.95)
		var points := PackedVector2Array()
		var steps := 22
		for index in range(steps + 1):
			var u := float(index) / float(steps)
			var angle := float(arc["start"]) + float(arc["length"]) * u
			var jitter := sin(u * 17.0 + float(arc["phase"])) * radius * 0.035
			points.append(Vector2(cos(angle) * (radius + jitter), sin(angle) * (radius + jitter) * 0.56))
		var arc_color := _arc_color
		arc_color.a *= pow(1.0 - t, 1.55) * 0.66
		var glow := arc_color
		glow.a *= 0.18
		draw_polyline(points, glow, 8.0 * (1.0 - t) + 1.0, true)
		draw_polyline(points, arc_color, 2.2 * (1.0 - t) + 0.6, true)


func _draw_irregular_lobe(
		center: Vector2,
		size: float,
		stretch: float,
		angle: float,
		phase: float,
		color: Color,
		alpha: float
) -> void:
	if size <= 0.2 or alpha <= 0.001:
		return
	var tangent := Vector2.from_angle(angle)
	var normal := tangent.orthogonal()
	var points := PackedVector2Array()
	var steps := 19
	for index in steps:
		var theta := TAU * float(index) / float(steps)
		var irregular := 1.0 + sin(theta * 3.0 + phase) * 0.13 + sin(theta * 7.0 - phase * 0.7) * 0.07
		points.append(
			center
			+ tangent * cos(theta) * size * stretch * irregular
			+ normal * sin(theta) * size * irregular
		)
	var draw_color := color
	draw_color.a *= alpha
	draw_colored_polygon(points, draw_color)
