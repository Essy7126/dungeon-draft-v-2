@tool
extends RefCounted

static func color(value: Variant, fallback: Color) -> Color:
	if value is Color:
		return value
	if value is Array and value.size() >= 3:
		return Color(float(value[0]),float(value[1]),float(value[2]),float(value[3]) if value.size() >= 4 else 1.0)
	return Color.from_string(str(value), fallback)

static func vector(value: Variant, fallback := Vector2.ONE) -> Vector2:
	if value is Vector2:
		return value
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]),float(value[1]))
	if value is float or value is int:
		return Vector2.ONE * float(value)
	return fallback

static func texture_scale(value: Variant) -> Vector2:
	var scale := vector(value)
	return Vector2(maxf(absf(scale.x),0.001),maxf(absf(scale.y),0.001))

static func shader_value(value: Variant) -> Variant:
	if value is String and value.begins_with("#"):
		return color(value, Color.WHITE)
	if value is Array:
		if value.size() == 2:
			return Vector2(float(value[0]),float(value[1]))
		if value.size() == 3:
			return Vector3(float(value[0]),float(value[1]),float(value[2]))
		if value.size() == 4:
			return Color(float(value[0]),float(value[1]),float(value[2]),float(value[3]))
	return value

static func apply_shader_parameters(material: ShaderMaterial, values: Dictionary) -> void:
	if material == null or material.shader == null:
		return
	var supported: Dictionary = {}
	for definition: Dictionary in material.shader.get_shader_uniform_list():
		supported[str(definition.name)] = true
	for key in values:
		if supported.has(str(key)):
			material.set_shader_parameter(str(key), shader_value(values[key]))
