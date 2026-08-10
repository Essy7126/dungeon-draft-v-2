extends Node2D

## Particules CPU dessinees par primitives. Aucun sprite ni texture externe.

var _particles: Array[Dictionary] = []
var _age := 0.0
var _gravity := Vector2.ZERO
var _drag := 0.0
var _streaks := false
var _additive := true


func configure(config: Dictionary) -> void:
	_particles.clear()
	_age = 0.0
	_gravity = config.get("gravity", Vector2.ZERO) as Vector2
	_drag = float(config.get("drag", 0.0))
	_streaks = bool(config.get("streaks", false))
	_additive = bool(config.get("additive", true))
	var rng := RandomNumberGenerator.new()
	rng.seed = int(config.get("seed", 1))
	var count := maxi(1, int(config.get("count", 20)))
	var direction := (config.get("direction", Vector2.UP) as Vector2).normalized()
	var base_angle := direction.angle()
	var spread := deg_to_rad(float(config.get("spread_degrees", 180.0)))
	var speed_min := float(config.get("speed_min", 30.0))
	var speed_max := float(config.get("speed_max", 110.0))
	var size_min := float(config.get("size_min", 1.5))
	var size_max := float(config.get("size_max", 4.5))
	var lifetime_min := float(config.get("lifetime_min", 0.35))
	var lifetime_max := float(config.get("lifetime_max", 0.8))
	var emission_radius := float(config.get("emission_radius", 3.0))
	var delay_max := float(config.get("delay_max", 0.08))
	var palette: Array = config.get("palette", [Color.WHITE]) as Array
	for index in count:
		var angle := base_angle + rng.randf_range(-spread * 0.5, spread * 0.5)
		var velocity := Vector2.from_angle(angle) * rng.randf_range(speed_min, speed_max)
		var offset := Vector2.from_angle(rng.randf_range(0.0, TAU)) * rng.randf_range(0.0, emission_radius)
		_particles.append({
			"position": offset,
			"velocity": velocity,
			"size": rng.randf_range(size_min, size_max),
			"lifetime": rng.randf_range(lifetime_min, lifetime_max),
			"delay": rng.randf_range(0.0, delay_max),
			"color": palette[index % palette.size()],
			"phase": rng.randf_range(0.0, TAU),
		})
	queue_redraw()


func advance(delta: float) -> void:
	_age += maxf(0.0, delta)
	for particle in _particles:
		if _age < float(particle["delay"]):
			continue
		var velocity := particle["velocity"] as Vector2
		velocity += _gravity * delta
		velocity *= maxf(0.0, 1.0 - _drag * delta)
		particle["velocity"] = velocity
		particle["position"] = (particle["position"] as Vector2) + velocity * delta
	queue_redraw()


func get_signature() -> String:
	var values: Array[String] = []
	for particle in _particles.slice(0, mini(8, _particles.size())):
		var velocity := particle["velocity"] as Vector2
		values.append("%.2f,%.2f" % [velocity.x, velocity.y])
	return "|".join(values)


func _draw() -> void:
	for particle in _particles:
		var local_age := _age - float(particle["delay"])
		var lifetime := float(particle["lifetime"])
		if local_age < 0.0 or local_age > lifetime:
			continue
		var progress := local_age / lifetime
		var fade := pow(1.0 - progress, 1.4)
		var pulse := 0.82 + sin(local_age * 18.0 + float(particle["phase"])) * 0.18
		var radius := float(particle["size"]) * pulse * (0.6 + fade * 0.4)
		var color := particle["color"] as Color
		color.a *= fade
		var position := particle["position"] as Vector2
		if _streaks:
			var velocity := particle["velocity"] as Vector2
			var tail := position - velocity.normalized() * radius * 3.2
			var outer := color
			outer.a *= 0.28
			draw_line(tail, position, outer, radius * 2.2, true)
			draw_line(tail, position, color, maxf(1.0, radius * 0.65), true)
		else:
			var glow := color
			glow.a *= 0.22 if _additive else 0.12
			draw_circle(position, radius * 2.3, glow)
			draw_circle(position, radius, color)
			var core := Color.WHITE
			core.a = color.a * 0.75
			draw_circle(position, maxf(0.6, radius * 0.32), core)
