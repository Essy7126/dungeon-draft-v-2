extends "res://tools/labs/vfx_lab/components/vfx_lab_effect.gd"

const Factory = preload("res://tools/labs/vfx_lab/components/vfx_component_factory.gd")
const SHIELD_SHADER = preload("res://tools/labs/vfx_lab/shaders/shield_surface.gdshader")

@export_range(0.05, 0.95, 0.05) var shield_opacity := 0.48
@export_range(0.2, 3.0, 0.05) var pulse_speed := 1.0

var _target := Vector2.ZERO
var _shield: ColorRect = null
var _orbit_ring: Node2D = null
var _impact_ring: Node2D = null
var _impact_particles: Node2D = null
var _impact_age := -1.0
var _automatic_impact_time := 1.05
var _impact_point := Vector2.ZERO


func _build_effect(parameters: Dictionary) -> void:
	duration = float(parameters.get("duration", 2.85))
	_target = parameters.get("target", Vector2.ZERO) as Vector2
	shield_opacity = clampf(float(parameters.get("shield_opacity", shield_opacity)), 0.05, 0.95)
	pulse_speed = maxf(0.2, float(parameters.get("pulse_speed", pulse_speed)))
	_automatic_impact_time = float(parameters.get("impact_time", 1.05))
	_shield = Factory.add_shader_rect(
		_visual_root,
		_target + Vector2(0.0, -34.0),
		Vector2(144.0, 178.0),
		SHIELD_SHADER,
		{
			"shield_color": parameters.get("color", Color("4bc6ff")),
			"opacity": shield_opacity,
			"pulse": 0.0,
			"intensity": intensity,
		}
	)
	_shield.pivot_offset = _shield.size * 0.5
	_shield.scale = Vector2(0.2, 0.05)
	_orbit_ring = Factory.add_ring(_visual_root, _target + Vector2(0.0, 4.0), {
		"duration": duration,
		"start_radius": 48.0,
		"end_radius": 58.0,
		"aspect": 0.38,
		"width": 2.2,
		"color": Color("67d8ff"),
		"segmented": true,
	})
	_impact_ring = Factory.add_ring(_visual_root, _target + Vector2(0.0, -28.0), {
		"duration": 0.72,
		"start_radius": 8.0,
		"end_radius": 86.0,
		"aspect": 0.86,
		"width": 3.5,
		"color": Color("d7f6ff"),
	})
	_impact_ring.visible = false
	_impact_particles = Factory.add_particles(_visual_root, _target + Vector2(0.0, -34.0), {
		"seed": visual_seed + 1400,
		"count": 34,
		"direction": Vector2.UP,
		"spread_degrees": 360.0,
		"speed_min": 38.0,
		"speed_max": 118.0,
		"size_min": 1.0,
		"size_max": 3.2,
		"lifetime_min": 0.3,
		"lifetime_max": 0.72,
		"streaks": true,
		"palette": [Color("ffffff"), Color("9cecff"), Color("2d9dde")],
	})
	_impact_particles.visible = false
	_impact_age = -1.0


func trigger_impact(local_point: Vector2 = Vector2.ZERO) -> void:
	if not active:
		return
	_impact_age = 0.0
	_impact_point = local_point
	if is_instance_valid(_impact_ring):
		_impact_ring.position = _target + Vector2(0.0, -28.0) + local_point * 0.2
		_impact_ring.call("configure", {
			"duration": 0.72, "start_radius": 8.0, "end_radius": 86.0,
			"aspect": 0.86, "width": 3.5, "color": Color("d7f6ff")
		})
		_impact_ring.visible = true
	if is_instance_valid(_impact_particles):
		_impact_particles.position = _target + Vector2(0.0, -34.0) + local_point * 0.25
		_impact_particles.visible = true


func _update_effect(time: float, delta: float) -> void:
	_orbit_ring.call("advance", delta)
	var appear := _ease_out_cubic(time / 0.35)
	var disappear := clampf((duration - time) / 0.55, 0.0, 1.0)
	var scale_factor := minf(appear, disappear)
	_shield.scale = Vector2(0.75 + scale_factor * 0.25, scale_factor)
	_shield.modulate.a = scale_factor
	if _impact_age < 0.0 and time >= _automatic_impact_time:
		trigger_impact(Vector2(26.0, -18.0))
	if _impact_age >= 0.0:
		_impact_age += delta
		_impact_ring.call("advance", delta)
		_impact_particles.call("advance", delta)
		var pulse_value := clampf(_impact_age * pulse_speed, 0.0, 1.0)
		(_shield.material as ShaderMaterial).set_shader_parameter("pulse", pulse_value)
		var hit_scale := 1.0 + sin(minf(_impact_age / 0.42, 1.0) * PI) * 0.1 * intensity
		_shield.scale *= Vector2.ONE * hit_scale
	queue_redraw()


func _clear_effect_state() -> void:
	_shield = null
	_orbit_ring = null
	_impact_ring = null
	_impact_particles = null
	_impact_age = -1.0


func get_procedural_signature() -> String:
	return "guard:%d:%.2f:%.2f" % [visual_seed, shield_opacity, pulse_speed]


func _draw() -> void:
	if not active:
		return
	var stable_alpha := minf(clampf(elapsed / 0.3, 0.0, 1.0), clampf((duration - elapsed) / 0.55, 0.0, 1.0))
	var center := _target + Vector2(0.0, -34.0)
	var radius := 63.0
	var points := PackedVector2Array()
	for index in 7:
		var angle := -PI * 0.5 + TAU * float(index) / 6.0
		points.append(center + Vector2(cos(angle) * radius, sin(angle) * radius * 1.25))
	var frame := Color(0.42, 0.88, 1.0, 0.48 * stable_alpha)
	draw_polyline(points, frame, 2.2, true)
	for index in 6:
		var node_color := Color(0.8, 0.98, 1.0, 0.82 * stable_alpha)
		draw_circle(points[index], 2.6, node_color)
	if _impact_age >= 0.0 and _impact_age < 0.48:
		var flash := 1.0 - _impact_age / 0.48
		var point := center + _impact_point * 0.25
		draw_circle(point, 7.0 + (1.0 - flash) * 18.0, Color(0.9, 1.0, 1.0, flash * 0.52))
