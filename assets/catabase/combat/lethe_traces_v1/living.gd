extends Node2D
var effect_time := 0.0
var _material: ShaderMaterial
var _reduced := false


func _ready() -> void:
	_material = get_parent().get_node("Land").material as ShaderMaterial
	_material.set_shader_parameter("water_flow", _build_water_flow())
	_reduced = GameManager.is_reduced_motion_enabled()
	GameManager.reduced_motion_changed.connect(_on_reduced_motion)
	seek_for_review(0.0)


func _process(delta: float) -> void:
	if not _reduced:
		seek_for_review(effect_time + delta)


func _on_reduced_motion(value: bool) -> void:
	_reduced = value


func seek_for_review(seconds: float) -> void:
	effect_time = seconds
	_material.set_shader_parameter("effect_time", effect_time)


func _polygon(points: Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point in points:
		result.append(Vector2(point[0], point[1]))
	return result


func _build_water_flow() -> ImageTexture:
	# These authored visual masks never define collision or tactical geometry.
	var path := "res://assets/catabase/combat/lethe_traces_v1/water_flow.json"
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var shore := _polygon(data.water_outline)
	var exclusions: Array[PackedVector2Array] = []
	for points in data.exclusions:
		exclusions.append(_polygon(points))
	var center := Vector2(data.flow_center[0], data.flow_center[1])
	var mask := Image.create(
		int(data.image_size[0]) / 2,
		int(data.image_size[1]) / 2,
		false,
		Image.FORMAT_RGBA8,
	)
	for y in mask.get_height():
		for x in mask.get_width():
			var p := Vector2(x * 2, y * 2)
			var water := Geometry2D.is_point_in_polygon(p, shore)
			if water:
				for polygon in exclusions:
					if Geometry2D.is_point_in_polygon(p, polygon):
						water = false
						break
			var flow := Vector2(
				-(p.y - center.y),
				(p.x - center.x) * float(data.flow_vertical_scale),
			).normalized()
			mask.set_pixel(x, y, Color(flow.x * 0.5 + 0.5, flow.y * 0.5 + 0.5, float(water), 1.0))
	return ImageTexture.create_from_image(mask)
