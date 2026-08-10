extends "res://tools/labs/vfx_lab/components/vfx_lab_effect.gd"

const Factory = preload("res://tools/labs/vfx_lab/components/vfx_component_factory.gd")

@export_range(5, 32, 1) var lightning_segment_count := 15
@export_range(1.0, 36.0, 1.0) var jitter := 17.0

var _positions: Array[Vector2] = []
var _strike_offsets: Array[float] = []
var _struck: Array[bool] = []
var _bolts: Array[Node2D] = []
var _rings: Array[Node2D] = []
var _sparks: Array[Node2D] = []
var _charge_particles: Node2D = null
var _zone_center := Vector2.ZERO
var _zone_radius := 74.0
var _signature_parts: Array[String] = []


func _build_effect(parameters: Dictionary) -> void:
	lightning_segment_count = maxi(5, int(parameters.get("lightning_segment_count", lightning_segment_count)))
	jitter = maxf(1.0, float(parameters.get("jitter", jitter)))
	_positions.clear()
	for value in parameters.get("positions", [Vector2.ZERO]):
		_positions.append(value as Vector2)
	if _positions.is_empty():
		_positions.append(Vector2.ZERO)
	_zone_center = Vector2.ZERO
	for position in _positions:
		_zone_center += position
	_zone_center /= float(_positions.size())
	_strike_offsets.clear()
	var configured_offsets: Array = parameters.get("strike_offsets", []) as Array
	for index in _positions.size():
		_strike_offsets.append(
			float(configured_offsets[index]) if index < configured_offsets.size() else 0.68 + float(index) * 0.42
		)
	_struck.resize(_positions.size())
	_struck.fill(false)
	_bolts.resize(_positions.size())
	_rings.resize(_positions.size())
	_sparks.resize(_positions.size())
	_bolts.fill(null)
	_rings.fill(null)
	_sparks.fill(null)
	_signature_parts.clear()
	duration = float(parameters.get("duration", _strike_offsets.max() + 1.35))
	_charge_particles = Factory.add_particles(_visual_root, _zone_center + Vector2(0.0, -42.0), {
		"seed": visual_seed + 1700,
		"count": 48,
		"direction": Vector2.UP,
		"spread_degrees": 360.0,
		"speed_min": 12.0,
		"speed_max": 48.0,
		"size_min": 1.0,
		"size_max": 2.8,
		"lifetime_min": 0.55,
		"lifetime_max": 1.2,
		"streaks": true,
		"emission_radius": 80.0,
		"palette": [Color("ffffff"), Color("78d9ff"), Color("6d67ff")],
	})


func strike_now(index: int) -> void:
	if index < 0 or index >= _positions.size() or _struck[index]:
		return
	_struck[index] = true
	var target := _positions[index]
	var top := target + Vector2(_rng.randf_range(-34.0, 34.0), -250.0 - _rng.randf_range(0.0, 45.0))
	var bolt := Factory.add_lightning(_visual_root, top, target, {
		"seed": visual_seed + 1900 + index * 97,
		"segments": lightning_segment_count,
		"jitter": jitter,
		"duration": 0.32,
		"width": 3.3 * intensity,
		"color": Color("9ee8ff"),
	})
	_bolts[index] = bolt
	_signature_parts.append(str(bolt.call("get_signature")))
	var ring := Factory.add_ring(_visual_root, target, {
		"duration": 0.72,
		"start_radius": 7.0,
		"end_radius": 68.0,
		"aspect": 0.48,
		"width": 3.2,
		"color": Color("b6ecff"),
		"segmented": true,
	})
	_rings[index] = ring
	var sparks := Factory.add_particles(_visual_root, target, {
		"seed": visual_seed + 2100 + index * 71,
		"count": 34,
		"direction": Vector2.UP,
		"spread_degrees": 250.0,
		"speed_min": 52.0,
		"speed_max": 165.0,
		"size_min": 1.1,
		"size_max": 3.1,
		"lifetime_min": 0.3,
		"lifetime_max": 0.78,
		"gravity": Vector2(0.0, 115.0),
		"streaks": true,
		"palette": [Color("ffffff"), Color("79dcff"), Color("7668ff")],
	})
	_sparks[index] = sparks


func _update_effect(time: float, delta: float) -> void:
	_charge_particles.call("advance", delta)
	for index in _positions.size():
		if not _struck[index] and time >= _strike_offsets[index]:
			strike_now(index)
		if is_instance_valid(_bolts[index]):
			_bolts[index].call("advance", delta)
		if is_instance_valid(_rings[index]):
			_rings[index].call("advance", delta)
		if is_instance_valid(_sparks[index]):
			_sparks[index].call("advance", delta)
	queue_redraw()


func _clear_effect_state() -> void:
	_positions.clear()
	_strike_offsets.clear()
	_struck.clear()
	_bolts.clear()
	_rings.clear()
	_sparks.clear()
	_charge_particles = null
	_signature_parts.clear()


func get_procedural_signature() -> String:
	return "lightning:%d:%d:%s" % [visual_seed, _positions.size(), "#".join(_signature_parts)]


func _draw() -> void:
	if not active:
		return
	var zone_alpha := clampf(1.0 - elapsed / 0.58, 0.0, 1.0)
	if zone_alpha > 0.0:
		for position in _positions:
			var diamond := PackedVector2Array([
				position + Vector2(0.0, -18.0), position + Vector2(37.0, 0.0),
				position + Vector2(0.0, 18.0), position + Vector2(-37.0, 0.0),
				position + Vector2(0.0, -18.0),
			])
			draw_colored_polygon(diamond.slice(0, 4), Color(0.2, 0.55, 1.0, zone_alpha * 0.16))
			draw_polyline(diamond, Color(0.48, 0.8, 1.0, zone_alpha * 0.75), 2.0, true)
	var charge_alpha := clampf(elapsed / 0.35, 0.0, 1.0) * clampf((duration - elapsed) / 0.5, 0.0, 1.0)
	for cloud_index in 7:
		var angle := TAU * float(cloud_index) / 7.0
		var center := _zone_center + Vector2(cos(angle) * (34.0 + cloud_index * 3.0), -192.0 + sin(angle) * 18.0)
		var cloud_color := Color(0.16, 0.2, 0.38, charge_alpha * 0.46)
		draw_circle(center, 31.0 + float(cloud_index % 3) * 7.0, cloud_color)
		draw_arc(center, 25.0, PI * 0.1, PI * 0.9, 14, Color(0.42, 0.62, 0.88, charge_alpha * 0.35), 2.0, true)
	for index in _positions.size():
		if not _struck[index]:
			continue
		var strike_age := elapsed - _strike_offsets[index]
		if strike_age >= 0.0 and strike_age < 0.18:
			var flash := 1.0 - strike_age / 0.18
			var flash_color := Color(0.82, 0.95, 1.0, flash * 0.5)
			draw_circle(_positions[index], 18.0 + (1.0 - flash) * 31.0, flash_color)
