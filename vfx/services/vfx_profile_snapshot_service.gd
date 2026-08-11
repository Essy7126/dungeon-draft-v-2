class_name VFXProfileSnapshotService
extends RefCounted


static func to_dictionary(profile: VFXProfile) -> Dictionary:
	if profile == null:
		return {}
	var sequence_values: Array = []
	for sequence in profile.sequences:
		if sequence == null:
			continue
		var module_values: Array = []
		for module in sequence.modules:
			if module != null:
				module_values.append(_module_to_dictionary(module))
		sequence_values.append({
			"sequence_id": str(sequence.sequence_id),
			"display_name": sequence.display_name,
			"modules": module_values,
		})
	return {
		"schema_version": profile.schema_version,
		"profile_id": str(profile.profile_id),
		"display_name": profile.display_name,
		"category": str(profile.category),
		"render_policy": str(profile.render_policy),
		"art_status": str(profile.art_status),
		"tags": Array(profile.tags).map(func(value): return str(value)),
		"sequences": sequence_values,
		"exposed_parameters": _encode_variant(profile.exposed_parameters),
		"context_requirements": Array(profile.context_requirements).map(func(value): return str(value)),
		"maximum_duration": profile.maximum_duration,
		"quality_policy": str(profile.quality_policy),
	}


static func from_dictionary(snapshot: Dictionary) -> VFXProfile:
	if snapshot.is_empty():
		return null
	var profile := VFXProfile.new()
	profile.schema_version = int(snapshot.get("schema_version", 1))
	profile.profile_id = StringName(snapshot.get("profile_id", ""))
	profile.display_name = str(snapshot.get("display_name", "VFX Profile"))
	profile.category = StringName(snapshot.get("category", "SYSTEM"))
	profile.render_policy = StringName(snapshot.get("render_policy", "SYSTEM_PROCEDURAL"))
	profile.art_status = StringName(snapshot.get("art_status", "TECHNICAL_PLACEHOLDER"))
	profile.tags = _string_names(snapshot.get("tags", []))
	profile.exposed_parameters = _decode_variant(snapshot.get("exposed_parameters", {})) as Dictionary
	profile.context_requirements = _string_names(snapshot.get("context_requirements", []))
	profile.maximum_duration = float(snapshot.get("maximum_duration", 3.0))
	profile.quality_policy = StringName(snapshot.get("quality_policy", "SCALABLE"))
	var sequences: Array[VFXSequenceData] = []
	for sequence_value in snapshot.get("sequences", []) as Array:
		var sequence_snapshot := sequence_value as Dictionary
		var sequence := VFXSequenceData.new()
		sequence.sequence_id = StringName(sequence_snapshot.get("sequence_id", "play"))
		sequence.display_name = str(sequence_snapshot.get("display_name", "Play"))
		var modules: Array[VFXModuleData] = []
		for module_value in sequence_snapshot.get("modules", []) as Array:
			modules.append(_module_from_dictionary(module_value as Dictionary))
		sequence.modules = modules
		sequences.append(sequence)
	profile.sequences = sequences
	return profile


static func fingerprint(profile: VFXProfile) -> String:
	return JSON.stringify(to_dictionary(profile)).sha256_text()


static func _module_to_dictionary(module: VFXModuleData) -> Dictionary:
	return {
		"module_id": str(module.module_id),
		"module_type": str(module.module_type),
		"enabled": module.enabled,
		"start_offset": module.start_offset,
		"duration": module.duration,
		"anchor": str(module.anchor),
		"seed_offset": module.seed_offset,
		"minimum_quality": module.minimum_quality,
		"context_requirements": Array(module.context_requirements).map(func(value): return str(value)),
		"primary_color": _color_array(module.primary_color),
		"secondary_color": _color_array(module.secondary_color),
		"intensity": module.intensity,
		"curve": _curve_snapshot(module.response_curve),
		"gradient": _gradient_snapshot(module.color_gradient),
		"parameters": _encode_variant(module.parameters),
	}


static func _module_from_dictionary(snapshot: Dictionary) -> VFXModuleData:
	var module := VFXModuleData.new()
	module.module_id = StringName(snapshot.get("module_id", "module"))
	module.module_type = StringName(snapshot.get("module_type", ""))
	module.enabled = bool(snapshot.get("enabled", true))
	module.start_offset = float(snapshot.get("start_offset", 0.0))
	module.duration = float(snapshot.get("duration", 0.5))
	module.anchor = StringName(snapshot.get("anchor", "WORLD"))
	module.seed_offset = int(snapshot.get("seed_offset", 0))
	module.minimum_quality = int(snapshot.get("minimum_quality", 0))
	module.context_requirements = _string_names(snapshot.get("context_requirements", []))
	module.primary_color = _color_from(snapshot.get("primary_color", [0.35, 0.8, 1.0, 0.9]))
	module.secondary_color = _color_from(snapshot.get("secondary_color", [0.9, 0.98, 1.0, 0.75]))
	module.intensity = float(snapshot.get("intensity", 1.0))
	module.response_curve = _curve_from(snapshot.get("curve", {}) as Dictionary)
	module.color_gradient = _gradient_from(snapshot.get("gradient", {}) as Dictionary)
	module.parameters = _decode_variant(snapshot.get("parameters", {})) as Dictionary
	return module


static func _curve_snapshot(curve: Curve) -> Dictionary:
	if curve == null:
		return {}
	var points: Array = []
	for index in curve.point_count:
		var point := curve.get_point_position(index)
		points.append({
			"x": point.x, "y": point.y,
			"left": curve.get_point_left_tangent(index),
			"right": curve.get_point_right_tangent(index),
			"left_mode": curve.get_point_left_mode(index),
			"right_mode": curve.get_point_right_mode(index),
		})
	return {"min": curve.min_value, "max": curve.max_value, "points": points}


static func _curve_from(snapshot: Dictionary) -> Curve:
	if snapshot.is_empty():
		return null
	var curve := Curve.new()
	curve.min_value = float(snapshot.get("min", 0.0))
	curve.max_value = float(snapshot.get("max", 1.0))
	for point_value in snapshot.get("points", []) as Array:
		var point := point_value as Dictionary
		curve.add_point(
			Vector2(float(point.get("x", 0.0)), float(point.get("y", 0.0))),
			float(point.get("left", 0.0)), float(point.get("right", 0.0)),
			int(point.get("left_mode", Curve.TANGENT_FREE)),
			int(point.get("right_mode", Curve.TANGENT_FREE)),
		)
	return curve


static func _gradient_snapshot(gradient: Gradient) -> Dictionary:
	if gradient == null:
		return {}
	var colors: Array = []
	for color in gradient.colors:
		colors.append(_color_array(color))
	return {"offsets": Array(gradient.offsets), "colors": colors}


static func _gradient_from(snapshot: Dictionary) -> Gradient:
	if snapshot.is_empty():
		return null
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array(snapshot.get("offsets", [0.0, 1.0]))
	var colors := PackedColorArray()
	for value in snapshot.get("colors", []) as Array:
		colors.append(_color_from(value))
	gradient.colors = colors
	return gradient


static func _color_array(color: Color) -> Array:
	return [color.r, color.g, color.b, color.a]


static func _color_from(value) -> Color:
	var values := value as Array
	return Color(
		float(values[0]) if values.size() > 0 else 1.0,
		float(values[1]) if values.size() > 1 else 1.0,
		float(values[2]) if values.size() > 2 else 1.0,
		float(values[3]) if values.size() > 3 else 1.0,
	)


static func _string_names(values) -> Array[StringName]:
	var result: Array[StringName] = []
	for value in values as Array:
		result.append(StringName(value))
	return result


static func _encode_variant(value):
	if value is int:
		return {"__vfx_type": "int", "value": value}
	if value is Color:
		return {"__vfx_type": "Color", "value": _color_array(value)}
	if value is Vector2:
		return {"__vfx_type": "Vector2", "value": [value.x, value.y]}
	if value is Vector2i:
		return {"__vfx_type": "Vector2i", "value": [value.x, value.y]}
	if value is StringName:
		return {"__vfx_type": "StringName", "value": str(value)}
	if value is Dictionary:
		var result := {}
		for key in value:
			result[str(key)] = _encode_variant(value[key])
		return result
	if value is Array:
		return value.map(func(item): return _encode_variant(item))
	return value


static func _decode_variant(value):
	if value is Dictionary:
		var dictionary := value as Dictionary
		match str(dictionary.get("__vfx_type", "")):
			"int":
				return int(dictionary.get("value", 0))
			"Color":
				return _color_from(dictionary.get("value", []))
			"Vector2":
				var vector := dictionary.get("value", []) as Array
				return Vector2(float(vector[0]), float(vector[1]))
			"Vector2i":
				var vector := dictionary.get("value", []) as Array
				return Vector2i(int(vector[0]), int(vector[1]))
			"StringName":
				return StringName(dictionary.get("value", ""))
		var result := {}
		for key in dictionary:
			result[key] = _decode_variant(dictionary[key])
		return result
	if value is Array:
		return value.map(func(item): return _decode_variant(item))
	return value
