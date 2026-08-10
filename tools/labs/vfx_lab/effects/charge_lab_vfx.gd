extends "res://tools/labs/vfx_lab/components/vfx_lab_effect.gd"

const Factory = preload("res://tools/labs/vfx_lab/components/vfx_component_factory.gd")

@export_range(0.3, 2.0, 0.05) var movement_duration := 0.9
@export_range(4.0, 32.0, 1.0) var trail_width := 18.0

var _actor: Node2D = null
var _start := Vector2.ZERO
var _target := Vector2(260.0, 0.0)
var _trail: Node2D = null
var _launch_dust: Node2D = null
var _impact_dust: Node2D = null
var _impact_ring: Node2D = null
var _impact_started := false
var _afterimages: Array[Dictionary] = []
var _direction := Vector2.RIGHT


func _build_effect(parameters: Dictionary) -> void:
	_actor = parameters.get("actor") as Node2D
	_start = parameters.get("start", _actor.position if is_instance_valid(_actor) else Vector2.ZERO) as Vector2
	_target = parameters.get("target", Vector2(260.0, 0.0)) as Vector2
	movement_duration = float(parameters.get("movement_duration", movement_duration))
	trail_width = float(parameters.get("trail_width", trail_width))
	duration = float(parameters.get("duration", movement_duration + 1.35))
	_direction = (_target - _start).normalized()
	if is_instance_valid(_actor):
		_actor.position = _start
	_trail = Factory.add_trail(_visual_root, {
		"lifetime": 0.5,
		"width": trail_width,
		"color_start": Color("d5f1ff"),
		"color_end": Color(0.2, 0.55, 0.8, 0.0),
	})
	_launch_dust = Factory.add_particles(_visual_root, _start + Vector2(0.0, 10.0), {
		"seed": visual_seed + 1000,
		"count": 28,
		"direction": -_direction + Vector2(0.0, -0.25),
		"spread_degrees": 80.0,
		"speed_min": 28.0,
		"speed_max": 105.0,
		"size_min": 2.2,
		"size_max": 6.2,
		"lifetime_min": 0.4,
		"lifetime_max": 0.88,
		"gravity": Vector2(0.0, 65.0),
		"drag": 1.5,
		"palette": [Color("d7c09a"), Color("927354"), Color("544436")],
	})
	_impact_dust = Factory.add_particles(_visual_root, _target + Vector2(0.0, 10.0), {
		"seed": visual_seed + 1100,
		"count": 36,
		"direction": Vector2.UP,
		"spread_degrees": 145.0,
		"speed_min": 45.0,
		"speed_max": 155.0,
		"size_min": 2.0,
		"size_max": 6.8,
		"lifetime_min": 0.45,
		"lifetime_max": 0.95,
		"gravity": Vector2(0.0, 105.0),
		"drag": 1.0,
		"streaks": true,
		"palette": [Color("f5d49c"), Color("b78a57"), Color("6c4a35")],
	})
	_impact_dust.visible = false
	_impact_ring = Factory.add_ring(_visual_root, _target, {
		"duration": 0.72,
		"start_radius": 8.0,
		"end_radius": 78.0,
		"aspect": 0.48,
		"width": 4.0,
		"color": Color("e6f6ff"),
		"segmented": true,
	})
	_impact_ring.visible = false
	_impact_started = false
	_afterimages.clear()


func _update_effect(time: float, delta: float) -> void:
	_launch_dust.call("advance", delta)
	_trail.call("advance", delta)
	for afterimage in _afterimages:
		afterimage["age"] = float(afterimage["age"]) + delta
	while not _afterimages.is_empty() and float(_afterimages.front()["age"]) > 0.34:
		_afterimages.pop_front()
	if time < movement_duration:
		var raw := clampf(time / movement_duration, 0.0, 1.0)
		var acceleration := raw * raw * (3.0 - 2.0 * raw)
		var position := _start.lerp(_target, acceleration)
		position.y -= sin(raw * PI) * 7.0
		if is_instance_valid(_actor):
			_actor.position = position
		_trail.call("push_point", position)
		if _afterimages.is_empty() or (position - (_afterimages.back()["position"] as Vector2)).length() > 34.0:
			_afterimages.append({"position": position, "age": 0.0})
	else:
		_start_impact_once()
		_impact_dust.call("advance", delta)
		_impact_ring.call("advance", delta)
	queue_redraw()


func _start_impact_once() -> void:
	if _impact_started:
		return
	_impact_started = true
	if is_instance_valid(_actor):
		_actor.position = _target
	_impact_dust.visible = true
	_impact_ring.visible = true


func _before_clear() -> void:
	if is_instance_valid(_actor):
		_actor.position = _start


func _clear_effect_state() -> void:
	_actor = null
	_trail = null
	_launch_dust = null
	_impact_dust = null
	_impact_ring = null
	_afterimages.clear()
	_impact_started = false


func get_procedural_signature() -> String:
	return "charge:%d:%.1f:%.1f:%.1f:%.1f" % [visual_seed, _start.x, _start.y, _target.x, _target.y]


func _draw() -> void:
	if not active:
		return
	for afterimage in _afterimages:
		var fade := 1.0 - clampf(float(afterimage["age"]) / 0.34, 0.0, 1.0)
		var position := afterimage["position"] as Vector2
		var silhouette := Color(0.35, 0.8, 1.0, fade * 0.19)
		draw_circle(position + Vector2(0.0, -33.0), 12.0, silhouette)
		draw_colored_polygon(PackedVector2Array([
			position + Vector2(-15.0, -24.0), position + Vector2(15.0, -24.0),
			position + Vector2(11.0, 8.0), position + Vector2(-11.0, 8.0),
		]), silhouette)
	if elapsed < movement_duration:
		var progress := clampf(elapsed / movement_duration, 0.0, 1.0)
		var actor_position := _actor.position if is_instance_valid(_actor) else _start.lerp(_target, progress)
		var perpendicular := _direction.orthogonal()
		for index in 7:
			var offset := perpendicular * (float(index - 3) * 7.0)
			var length := 18.0 + float((index * 13 + visual_seed) % 24)
			var speed_color := Color(0.62, 0.9, 1.0, 0.12 + progress * 0.35)
			draw_line(actor_position - _direction * (30.0 + length) + offset, actor_position - _direction * 20.0 + offset, speed_color, 1.4, true)
	if _impact_started and elapsed - movement_duration < 0.26:
		var flash := 1.0 - (elapsed - movement_duration) / 0.26
		var color := Color(0.88, 0.97, 1.0, flash * 0.52)
		draw_circle(_target, 18.0 + (1.0 - flash) * 24.0, color)
