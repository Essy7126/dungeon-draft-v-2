extends "res://tools/labs/vfx_lab/components/vfx_lab_effect.gd"

const Factory = preload("res://tools/labs/vfx_lab/components/vfx_component_factory.gd")

@export_range(0.08, 0.8, 0.02) var propagation_speed := 0.24
@export_range(0.0, 16.0, 0.5) var lift_height := 7.0

var _positions: Array[Vector2] = []
var _cracks: Array[PackedVector2Array] = []
var _dust: Array[Node2D] = []
var _rings: Array[Node2D] = []
var _activated: Array[bool] = []
var _signature := ""


func _build_effect(parameters: Dictionary) -> void:
	propagation_speed = maxf(0.05, float(parameters.get("propagation_speed", propagation_speed)))
	lift_height = float(parameters.get("lift_height", lift_height))
	_positions.clear()
	for value in parameters.get("positions", [Vector2.ZERO]):
		_positions.append(value as Vector2)
	duration = float(parameters.get("duration", 0.5 + _positions.size() * propagation_speed + 1.25))
	_generate_cracks()
	_activated.resize(_positions.size())
	_activated.fill(false)
	for index in _positions.size():
		var dust := Factory.add_particles(_visual_root, _positions[index], {
			"seed": visual_seed + 800 + index * 17,
			"count": 18,
			"direction": Vector2.UP,
			"spread_degrees": 125.0,
			"speed_min": 18.0,
			"speed_max": 68.0,
			"size_min": 2.0,
			"size_max": 5.8,
			"lifetime_min": 0.42,
			"lifetime_max": 0.88,
			"gravity": Vector2(0.0, 75.0),
			"drag": 1.2,
			"palette": [Color("d2b184"), Color("8b6a4c"), Color("544236")],
		})
		dust.visible = false
		_dust.append(dust)
		var ring := Factory.add_ring(_visual_root, _positions[index], {
			"duration": 0.55,
			"start_radius": 6.0,
			"end_radius": 46.0,
			"aspect": 0.48,
			"width": 2.1,
			"color": Color("e2b16a"),
			"segmented": true,
		})
		ring.visible = false
		_rings.append(ring)


func _generate_cracks() -> void:
	_cracks.clear()
	var signature_parts: Array[String] = []
	for index in _positions.size():
		var center := _positions[index]
		var points := PackedVector2Array()
		points.append(center + Vector2(-35.0, _rng.randf_range(-5.0, 5.0)))
		for segment in range(1, 6):
			var ratio := float(segment) / 6.0
			points.append(center + Vector2(lerpf(-35.0, 35.0, ratio), _rng.randf_range(-11.0, 11.0)))
		points.append(center + Vector2(35.0, _rng.randf_range(-5.0, 5.0)))
		_cracks.append(points)
		signature_parts.append("%.1f" % points[3].y)
	_signature = "seismic:%d:%d:%s" % [visual_seed, _positions.size(), "|".join(signature_parts)]


func _update_effect(time: float, delta: float) -> void:
	for index in _positions.size():
		var trigger_time := 0.22 + float(index) * propagation_speed
		if time >= trigger_time:
			if not _activated[index]:
				_activated[index] = true
				_dust[index].visible = true
				_rings[index].visible = true
			_dust[index].call("advance", delta)
			_rings[index].call("advance", delta)
	queue_redraw()


func _clear_effect_state() -> void:
	_positions.clear()
	_cracks.clear()
	_dust.clear()
	_rings.clear()
	_activated.clear()


func get_procedural_signature() -> String:
	return _signature


func _draw() -> void:
	if not active:
		return
	for index in _positions.size():
		var local_time := elapsed - (0.22 + float(index) * propagation_speed)
		if local_time < 0.0:
			continue
		var reveal := clampf(local_time / 0.22, 0.0, 1.0)
		var settle := clampf(local_time / 0.68, 0.0, 1.0)
		var lift := sin(settle * PI) * lift_height
		var center := _positions[index] + Vector2(0.0, -lift)
		var diamond := PackedVector2Array([
			center + Vector2(0.0, -18.0), center + Vector2(37.0, 0.0),
			center + Vector2(0.0, 18.0), center + Vector2(-37.0, 0.0),
		])
		var ground_color := Color(0.44, 0.28, 0.16, 0.22 * (1.0 - settle * 0.55))
		draw_colored_polygon(diamond, ground_color)
		var crack := _cracks[index]
		var visible_count := clampi(ceili(reveal * float(crack.size())), 2, crack.size())
		var visible_points := PackedVector2Array()
		for point_index in visible_count:
			visible_points.append(crack[point_index] + Vector2(0.0, -lift))
		draw_polyline(visible_points, Color(0.16, 0.07, 0.025, 0.9), 5.0, true)
		draw_polyline(visible_points, Color(1.0, 0.54, 0.16, 0.72 * (1.0 - clampf(local_time / 1.1, 0.0, 0.8))), 1.6, true)
		for debris_index in 4:
			var angle := float(debris_index) * 1.57 + float(index) * 0.8
			var debris_pos := center + Vector2.from_angle(angle) * (13.0 + debris_index * 4.0) + Vector2(0.0, -sin(settle * PI) * (12.0 + debris_index * 3.0))
			var size := 2.5 + float((index + debris_index) % 3)
			draw_colored_polygon(PackedVector2Array([
				debris_pos + Vector2(-size, size), debris_pos + Vector2(0.0, -size), debris_pos + Vector2(size, size)
			]), Color("806147"))
