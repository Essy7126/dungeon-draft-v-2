extends "res://tools/labs/vfx_lab/components/vfx_lab_effect.gd"

const Factory = preload("res://tools/labs/vfx_lab/components/vfx_component_factory.gd")

@export_range(1, 18, 1) var crystal_count := 9
@export_range(0.2, 1.0, 0.05) var opacity := 0.72

var _positions: Array[Vector2] = []
var _crystals: Array[Dictionary] = []
var _fragment_fields: Array[Node2D] = []
var _signature := ""


func _build_effect(parameters: Dictionary) -> void:
	duration = float(parameters.get("duration", 3.45))
	crystal_count = maxi(3, int(parameters.get("crystal_count", crystal_count)))
	opacity = clampf(float(parameters.get("opacity", opacity)), 0.1, 0.95)
	_positions.clear()
	for value in parameters.get("positions", [Vector2.ZERO]):
		_positions.append(value as Vector2)
	_generate_crystals()
	for index in _positions.size():
		var fragments := Factory.add_particles(_visual_root, _positions[index], {
			"seed": visual_seed + 500 + index * 31,
			"count": 14,
			"direction": Vector2.UP,
			"spread_degrees": 110.0,
			"speed_min": 28.0,
			"speed_max": 92.0,
			"size_min": 1.2,
			"size_max": 3.4,
			"lifetime_min": 0.45,
			"lifetime_max": 0.92,
			"gravity": Vector2(0.0, 90.0),
			"streaks": true,
			"delay_max": 0.42 + float(index) * 0.08,
			"palette": [Color("dffcff"), Color("66d8f5"), Color("2d8dbf")],
		})
		_fragment_fields.append(fragments)


func _generate_crystals() -> void:
	_crystals.clear()
	var signature_parts: Array[String] = []
	var per_cell := maxi(2, ceili(float(crystal_count) / float(maxi(1, _positions.size()))))
	for cell_index in _positions.size():
		for local_index in per_cell:
			if _crystals.size() >= crystal_count:
				break
			var lateral := lerpf(-19.0, 19.0, (float(local_index) + 0.5) / float(per_cell))
			var base := _positions[cell_index] + Vector2(lateral, lateral * 0.22)
			var height := _rng.randf_range(42.0, 91.0) * (1.08 if local_index == per_cell / 2 else 1.0)
			var half_width := _rng.randf_range(7.0, 15.0)
			var lean := _rng.randf_range(-12.0, 12.0)
			var delay := float(cell_index) * 0.12 + float(local_index) * 0.055
			var hue := _rng.randf_range(0.48, 0.56)
			_crystals.append({
				"base": base,
				"height": height,
				"width": half_width,
				"lean": lean,
				"delay": delay,
				"hue": hue,
			})
			signature_parts.append("%.1f/%.1f/%.1f" % [height, half_width, lean])
	_signature = "ice:%d:%s" % [visual_seed, "|".join(signature_parts)]


func _update_effect(_time: float, delta: float) -> void:
	for fragments in _fragment_fields:
		fragments.call("advance", delta)
	queue_redraw()


func _clear_effect_state() -> void:
	_positions.clear()
	_crystals.clear()
	_fragment_fields.clear()


func get_procedural_signature() -> String:
	return _signature


func _draw() -> void:
	if not active:
		return
	for position in _positions:
		var diamond := PackedVector2Array([
			position + Vector2(0.0, -18.0),
			position + Vector2(37.0, 0.0),
			position + Vector2(0.0, 18.0),
			position + Vector2(-37.0, 0.0),
			position + Vector2(0.0, -18.0),
		])
		var footprint := Color("4bdcf6")
		footprint.a = 0.18
		draw_colored_polygon(diamond.slice(0, 4), footprint)
		draw_polyline(diamond, Color(0.4, 0.92, 1.0, 0.72), 1.5, true)
	for crystal in _crystals:
		var local_time := elapsed - float(crystal["delay"])
		if local_time < 0.0:
			continue
		var appear := _ease_out_cubic(local_time / 0.42)
		var settle := sin(minf(local_time, 0.52) / 0.52 * PI) * 5.0
		var base := crystal["base"] as Vector2
		var height := float(crystal["height"]) * appear
		var half_width := float(crystal["width"]) * (0.55 + appear * 0.45)
		var lean := float(crystal["lean"]) * appear
		base.y += settle
		var tip := base + Vector2(lean, -height)
		var left := base + Vector2(-half_width, 0.0)
		var right := base + Vector2(half_width, 0.0)
		var inner_left := base + Vector2(-half_width * 0.15, -height * 0.18)
		var front_color := Color.from_hsv(float(crystal["hue"]), 0.46, 0.94, opacity * appear)
		var side_color := Color.from_hsv(float(crystal["hue"]) + 0.025, 0.68, 0.57, opacity * 0.82 * appear)
		var light_color := Color(0.82, 0.98, 1.0, opacity * 0.75 * appear)
		draw_colored_polygon(PackedVector2Array([left, inner_left, tip]), side_color)
		draw_colored_polygon(PackedVector2Array([inner_left, right, tip]), front_color)
		draw_polyline(PackedVector2Array([left, tip, right]), light_color, 1.6, true)
		draw_line(inner_left, tip, Color(0.88, 1.0, 1.0, opacity * appear), 1.0, true)
		var shine_t := fmod(elapsed * 0.7 + float(crystal["height"]) * 0.013, 1.0)
		var shine_start := left.lerp(tip, shine_t * 0.7)
		draw_line(shine_start, shine_start + Vector2(half_width * 0.55, -height * 0.08), Color(0.9, 1.0, 1.0, 0.52 * appear), 1.2, true)
