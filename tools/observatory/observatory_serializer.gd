class_name ObservatorySerializer
extends RefCounted

const MAX_DEPTH := 12


static func sanitize(value: Variant, warnings: Array[String] = []) -> Variant:
	return _sanitize(value, warnings, 0, {})


static func explicit_resource(
		resource: Resource,
		allowed_properties: Array[StringName],
		warnings: Array[String] = []
	) -> Dictionary:
	if resource == null:
		return {}
	var result := {
		"resource_type": resource_type_name(resource),
		"resource_path": resource_path(resource),
	}
	var available := {}
	for property in resource.get_property_list():
		available[StringName(property.get("name", ""))] = true
	for property_name in allowed_properties:
		if not available.has(property_name):
			continue
		result[str(property_name)] = sanitize(resource.get(property_name), warnings)
	return result


static func resource_path(resource: Resource) -> String:
	if resource == null:
		return ""
	var path := resource.resource_path
	return path if path.begins_with("res://") else ""


static func resource_type_name(resource: Resource) -> String:
	if resource == null:
		return ""
	var script := resource.get_script() as Script
	if script != null:
		var global_name := script.get_global_name()
		if not global_name.is_empty():
			return global_name
	return resource.get_class()


static func is_forbidden_absolute_path(value: String) -> bool:
	if value.begins_with("res://") or value.begins_with("user://"):
		return false
	return value.is_absolute_path() or (
		value.length() >= 3
		and value[1] == ":"
		and value[2] in ["/", "\\"]
	)


static func _sanitize(
		value: Variant,
		warnings: Array[String],
		depth: int,
		seen: Dictionary
	) -> Variant:
	if depth > MAX_DEPTH:
		warnings.append("Profondeur maximale de sérialisation atteinte.")
		return {"truncated": true}
	if value == null or value is bool or value is int or value is float:
		return value
	if value is String or value is StringName:
		var text := str(value)
		if is_forbidden_absolute_path(text):
			warnings.append("Chemin absolu refusé pendant la sérialisation.")
			return null
		return text
	if value is Vector2i:
		return {"x": value.x, "y": value.y}
	if value is Vector2:
		return {"x": value.x, "y": value.y}
	if value is Color:
		return {"r": value.r, "g": value.g, "b": value.b, "a": value.a}
	if value is Array or value is PackedStringArray or value is PackedVector2Array:
		var result: Array = []
		for entry in value:
			result.append(_sanitize(entry, warnings, depth + 1, seen))
		return result
	if value is Dictionary:
		var dictionary := value as Dictionary
		var keys: Array[String] = []
		for key in dictionary:
			keys.append(str(key))
		keys.sort()
		var result := {}
		for key in keys:
			var original_key: Variant = key
			if not dictionary.has(original_key):
				for candidate in dictionary:
					if str(candidate) == key:
						original_key = candidate
						break
			result[key] = _sanitize(dictionary[original_key], warnings, depth + 1, seen)
		return result
	if value is Resource:
		var resource := value as Resource
		var instance_id := resource.get_instance_id()
		if seen.has(instance_id):
			warnings.append("Cycle de Resource détecté.")
			return {"cycle": true, "resource_type": resource_type_name(resource)}
		seen[instance_id] = true
		var resource_result := {
			"resource_type": resource_type_name(resource),
			"resource_path": resource_path(resource),
		}
		seen.erase(instance_id)
		return resource_result
	warnings.append("Type non sérialisable ignoré : %s." % type_string(typeof(value)))
	return null
