extends Node2D

var _particles: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
var _default_palette: Array[Color] = [Color("fff0a8"), Color("ff9d32"), Color("ec3a16")]


func configure(seed: int, palette: Array) -> void:
	_particles.clear()
	_rng.seed = seed
	_default_palette.clear()
	for color in palette:
		_default_palette.append(color as Color)
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = additive
	queue_redraw()


func emit_burst(origin: Vector2, config: Dictionary) -> void:
	var count := maxi(1, int(config.get("count", 1)))
	var direction := (config.get("direction", Vector2.UP) as Vector2).normalized()
	var spread := deg_to_rad(float(config.get("spread_degrees", 180.0)))
	var base_angle := direction.angle()
	var speed_min := float(config.get("speed_min", 30.0))
	var speed_max := float(config.get("speed_max", 90.0))
	var size_min := float(config.get("size_min", 1.4))
	var size_max := float(config.get("size_max", 4.2))
	var lifetime_min := float(config.get("lifetime_min", 0.24))
	var lifetime_max := float(config.get("lifetime_max", 0.62))
	var radius_min := float(config.get("radius_min", 0.0))
	var radius_max := float(config.get("radius_max", 4.0))
	var delay_max := float(config.get("delay_max", 0.0))
	var gravity := config.get("gravity", Vector2.ZERO) as Vector2
	var inward := bool(config.get("inward", false))
	for _index in count:
		var offset_angle := _rng.randf_range(0.0, TAU)
		var offset := Vector2.from_angle(offset_angle) * _rng.randf_range(radius_min, radius_max)
		var velocity_angle := base_angle + _rng.randf_range(-spread * 0.5, spread * 0.5)
		var velocity := Vector2.from_angle(velocity_angle) * _rng.randf_range(speed_min, speed_max)
		if inward and offset.length_squared() > 0.01:
			velocity = -offset.normalized() * _rng.randf_range(speed_min, speed_max)
		_particles.append({
			"position": origin + offset,
			"velocity": velocity,
			"gravity": gravity,
			"age": -_rng.randf_range(0.0, delay_max),
			"lifetime": _rng.randf_range(lifetime_min, lifetime_max),
			"size": _rng.randf_range(size_min, size_max),
			"aspect": _rng.randf_range(1.1, 3.4),
			"rotation": _rng.randf_range(0.0, TAU),
			"spin": _rng.randf_range(-7.0, 7.0),
			"kind": _rng.randi_range(0, 2),
			"color": _default_palette[_rng.randi_range(0, _default_palette.size() - 1)],
		})
	queue_redraw()


func advance(delta: float) -> void:
	for particle in _particles:
		particle["age"] = float(particle["age"]) + maxf(0.0, delta)
		if float(particle["age"]) < 0.0:
			continue
		var velocity := particle["velocity"] as Vector2
		velocity += (particle["gravity"] as Vector2) * delta
		particle["velocity"] = velocity
		particle["position"] = (particle["position"] as Vector2) + velocity * delta
		particle["rotation"] = float(particle["rotation"]) + float(particle["spin"]) * delta
	for index in range(_particles.size() - 1, -1, -1):
		if float(_particles[index]["age"]) > float(_particles[index]["lifetime"]):
			_particles.remove_at(index)
	queue_redraw()


func get_live_count() -> int:
	return _particles.size()


func get_signature() -> String:
	var values: Array[String] = []
	for particle in _particles.slice(0, mini(8, _particles.size())):
		var velocity := particle["velocity"] as Vector2
		values.append("%d:%.1f:%.1f" % [int(particle["kind"]), velocity.x, velocity.y])
	return "|".join(values)


func _draw() -> void:
	for particle in _particles:
		var age := float(particle["age"])
		var lifetime := float(particle["lifetime"])
		if age < 0.0 or age > lifetime:
			continue
		var t := age / lifetime
		var fade := pow(1.0 - t, 1.45)
		var color := particle["color"] as Color
		color.a *= fade
		var position := particle["position"] as Vector2
		var velocity := particle["velocity"] as Vector2
		var angle := velocity.angle() if velocity.length_squared() > 0.01 else float(particle["rotation"])
		var tangent := Vector2.from_angle(angle)
		var normal := tangent.orthogonal()
		var size := float(particle["size"]) * (0.45 + fade * 0.55)
		match int(particle["kind"]):
			0:
				var length := size * float(particle["aspect"])
				var points := PackedVector2Array([
					position + tangent * length,
					position + normal * size * 0.65,
					position - tangent * length * 0.65,
					position - normal * size * 0.65,
				])
				draw_colored_polygon(points, color)
			1:
				var tail := position - tangent * size * float(particle["aspect"])
				var glow := color
				glow.a *= 0.22
				draw_line(tail, position, glow, size * 2.8, true)
				draw_line(tail, position, color, maxf(0.8, size * 0.72), true)
			2:
				var glow := color
				glow.a *= 0.2
				draw_circle(position, size * 2.0, glow)
				draw_circle(position, size, color)
				var core := Color.WHITE
				core.a = color.a * 0.72
				draw_circle(position - tangent * size * 0.25, size * 0.28, core)
