class_name VFXModuleVisual
extends Node2D

var module_data: VFXModuleData
var context: VFXExecutionContext
var deterministic_seed := 0
var normalized_progress := 0.0
var _lightning_lines: Array[PackedVector2Array] = []
var _particle_rays: Array[Dictionary] = []


func configure(data: VFXModuleData, execution_context: VFXExecutionContext, seed: int) -> void:
	module_data = data
	context = execution_context
	deterministic_seed = seed
	_build_deterministic_geometry()
	visible = false
	queue_redraw()


func set_normalized_progress(value: float) -> void:
	normalized_progress = clampf(value, 0.0, 1.0)
	visible = true
	queue_redraw()


func _draw() -> void:
	if module_data == null or context == null:
		return
	var eased := _response(normalized_progress)
	match module_data.module_type:
		&"ShieldSurfaceModule":
			_draw_shield_surface(eased)
		&"ShieldRippleModule":
			_draw_shield_ripple(eased)
		&"LightningModule":
			_draw_lightning(eased)
		&"PathRibbonModule":
			_draw_path(eased)
		&"CellOverlayModule":
			_draw_cells(eased)
		&"ParticleBurstModule", &"FlashModule":
			_draw_burst(eased)


func _draw_shield_surface(progress: float) -> void:
	var center: Vector2 = context.get_value(&"target_world", Vector2.ZERO)
	var radius := float(module_data.parameters.get("radius", 54.0))
	var magnitude := clampf(float(context.get_value(&"magnitude", 1.0)), 0.0, 1.0)
	var alpha := sin(PI * minf(progress * 1.2, 1.0)) * module_data.primary_color.a
	var color := module_data.primary_color
	color.a = alpha * (0.55 + 0.45 * magnitude)
	draw_circle(center, radius * (0.92 + progress * 0.08), color)
	var rim := module_data.secondary_color
	rim.a *= 0.45 + 0.55 * (1.0 - progress)
	draw_arc(center, radius, -PI, PI, 64, rim, 3.0 * module_data.intensity, true)


func _draw_shield_ripple(progress: float) -> void:
	var center: Vector2 = context.get_value(&"target_world", Vector2.ZERO)
	var impact: Vector2 = context.get_value(&"target_world", center)
	var impacts = context.get_value(&"impact_world_points", PackedVector2Array())
	if impacts is PackedVector2Array and not impacts.is_empty():
		impact = impacts[0]
	var radius := lerpf(8.0, float(module_data.parameters.get("radius", 72.0)), progress)
	var color := module_data.primary_color
	color.a *= 1.0 - progress
	draw_arc(impact.lerp(center, 0.15), radius, -PI, PI, 40, color, 2.5, true)


func _draw_lightning(progress: float) -> void:
	var color := module_data.primary_color
	color.a *= 1.0 - maxf(0.0, progress - 0.72) / 0.28
	var glow := module_data.secondary_color
	glow.a *= color.a * 0.45
	for line in _lightning_lines:
		if line.size() < 2:
			continue
		var visible_count := clampi(ceili(float(line.size()) * minf(progress * 2.1, 1.0)), 2, line.size())
		var shown: PackedVector2Array = line.slice(0, visible_count)
		draw_polyline(shown, glow, 8.0 * module_data.intensity, true)
		draw_polyline(shown, color, 2.1 * module_data.intensity, true)
		if progress > 0.35:
			var impact_color := module_data.secondary_color
			impact_color.a *= 1.0 - progress
			draw_circle(line[-1], 7.0 + 13.0 * progress, impact_color)


func _draw_path(progress: float) -> void:
	var points: PackedVector2Array = context.get_value(&"path_world_points", PackedVector2Array())
	if points.size() < 2:
		return
	var valid := bool(context.get_value(&"path_valid", true))
	var color := module_data.primary_color if valid else Color(1.0, 0.25, 0.22, 0.9)
	color.a *= 0.65 + 0.35 * sin(progress * PI)
	var count := clampi(ceili(float(points.size()) * minf(progress * 2.4, 1.0)), 2, points.size())
	var shown: PackedVector2Array = points.slice(0, count)
	draw_polyline(shown, Color(color.r, color.g, color.b, color.a * 0.22), 13.0, true)
	draw_polyline(shown, color, 3.5 * module_data.intensity, true)


func _draw_cells(progress: float) -> void:
	var points: PackedVector2Array = context.get_value(&"path_world_points", PackedVector2Array())
	if points.is_empty():
		points = context.get_value(&"impact_world_points", PackedVector2Array())
	var color := module_data.primary_color
	color.a *= 0.2 + 0.5 * sin(progress * PI)
	for point in points:
		var diamond := PackedVector2Array([
			point + Vector2(0, -12), point + Vector2(24, 0),
			point + Vector2(0, 12), point + Vector2(-24, 0),
		])
		draw_colored_polygon(diamond, Color(color.r, color.g, color.b, color.a * 0.32))
		draw_polyline(diamond + PackedVector2Array([diamond[0]]), color, 1.5, true)


func _draw_burst(progress: float) -> void:
	var centers = context.get_value(&"impact_world_points", PackedVector2Array())
	if not centers is PackedVector2Array or centers.is_empty():
		centers = PackedVector2Array([context.get_value(&"target_world", Vector2.ZERO)])
	var color := module_data.primary_color
	color.a *= 1.0 - progress
	for center in centers:
		draw_circle(center, lerpf(3.0, 16.0, progress), Color(color.r, color.g, color.b, color.a * 0.35))
		for ray in _particle_rays:
			var direction: Vector2 = ray.direction
			var length := float(ray.length) * progress
			draw_line(center + direction * 5.0, center + direction * length, color, 2.0, true)


func _build_deterministic_geometry() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = deterministic_seed
	if module_data.module_type == &"LightningModule":
		var origin: Vector2 = context.get_value(&"origin_world", Vector2.ZERO)
		var impacts: PackedVector2Array = context.get_value(&"impact_world_points", PackedVector2Array())
		if impacts.is_empty():
			impacts = PackedVector2Array([context.get_value(&"target_world", origin)])
		var segments := clampi(int(module_data.parameters.get("segments", 12)), 4, 32)
		var jitter := float(module_data.parameters.get("jitter", 18.0))
		for target in impacts:
			var line := PackedVector2Array()
			var perpendicular: Vector2 = (target - origin).normalized().orthogonal()
			for index in range(segments + 1):
				var ratio := float(index) / float(segments)
				var falloff := sin(ratio * PI)
				line.append(origin.lerp(target, ratio) + perpendicular * rng.randf_range(-jitter, jitter) * falloff)
			_lightning_lines.append(line)
	if module_data.module_type in [&"ParticleBurstModule", &"FlashModule"]:
		var count := clampi(int(module_data.parameters.get("count", 10)), 3, 32)
		for _index in count:
			var angle := rng.randf_range(-PI, PI)
			_particle_rays.append({
				"direction": Vector2.from_angle(angle),
				"length": rng.randf_range(18.0, 42.0),
			})


func _response(value: float) -> float:
	if module_data.response_curve != null and module_data.response_curve.point_count > 0:
		return clampf(module_data.response_curve.sample(value), 0.0, 1.0)
	return value


func geometry_fingerprint() -> String:
	var serializable: Array = []
	for line in _lightning_lines:
		var points: Array = []
		for point in line:
			points.append([snappedf(point.x, 0.001), snappedf(point.y, 0.001)])
		serializable.append(points)
	serializable.append(_particle_rays)
	return JSON.stringify(serializable).sha256_text()
