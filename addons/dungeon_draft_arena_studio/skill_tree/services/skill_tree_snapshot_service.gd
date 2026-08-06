@tool
class_name SkillTreeSnapshotService
extends RefCounted


static func fingerprint(resource: Resource) -> String:
	return JSON.stringify(snapshot(resource)).sha256_text()


static func snapshot(resource: Resource) -> Variant:
	var visited := {}
	return _encode(resource, visited)


static func storage_fingerprint(resource: Resource) -> String:
	var visited := {}
	return JSON.stringify(_encode_storage(resource, visited, true)).sha256_text()


static func _encode(value: Variant, visited: Dictionary) -> Variant:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING:
			return value
		TYPE_STRING_NAME:
			return str(value)
		TYPE_VECTOR2:
			return [value.x, value.y]
		TYPE_VECTOR2I:
			return [value.x, value.y]
		TYPE_VECTOR3:
			return [value.x, value.y, value.z]
		TYPE_VECTOR3I:
			return [value.x, value.y, value.z]
		TYPE_COLOR:
			return [value.r, value.g, value.b, value.a]
		TYPE_RECT2:
			return [value.position.x, value.position.y, value.size.x, value.size.y]
		TYPE_ARRAY:
			var encoded_array: Array = []
			for item in value:
				encoded_array.append(_encode(item, visited))
			return encoded_array
		TYPE_DICTIONARY:
			var encoded_dictionary := {}
			var keys: Array[String] = []
			for key in value:
				keys.append(str(key))
			keys.sort()
			for key in keys:
				encoded_dictionary[key] = _encode(_dictionary_value(value, key), visited)
			return encoded_dictionary
		TYPE_OBJECT:
			return _encode_object(value, visited)
		_:
			return str(value)


static func _encode_object(value: Object, visited: Dictionary) -> Variant:
	if value == null:
		return null
	if not value is Resource:
		return {"class": value.get_class()}
	var resource := value as Resource
	if not _is_editable_resource(resource):
		return {
			"class": resource.get_class(),
			"path": resource.resource_path,
			"instance": resource.get_instance_id(),
		}
	var instance_id := resource.get_instance_id()
	if visited.has(instance_id):
		return {"reference": visited[instance_id]}
	var reference_index := visited.size()
	visited[instance_id] = reference_index
	var properties := {}
	for property in resource.get_property_list():
		var property_name := StringName(property.get("name", &""))
		var usage := int(property.get("usage", 0))
		if property_name in [&"script", &"resource_name", &"resource_path", &"resource_local_to_scene"]:
			continue
		if usage & PROPERTY_USAGE_STORAGE == 0:
			continue
		properties[str(property_name)] = _encode(resource.get(property_name), visited)
	return {
		"reference_index": reference_index,
		"class": resource.get_script().get_global_name() \
			if resource.get_script() is Script else resource.get_class(),
		"source_path": resource.resource_path,
		"properties": properties,
	}


static func _encode_storage(
		value: Variant,
		visited: Dictionary,
		is_root := false
	) -> Variant:
	if value is Resource:
		var resource := value as Resource
		if not is_root and not resource.resource_path.is_empty() \
				and not resource.is_built_in():
			return {
				"external_class": resource.get_class(),
				"external_path": resource.resource_path,
			}
		if not _is_editable_resource(resource):
			return _encode_object(resource, visited)
		var instance_id := resource.get_instance_id()
		if visited.has(instance_id):
			return {"reference": visited[instance_id]}
		var reference_index := visited.size()
		visited[instance_id] = reference_index
		var properties := {}
		for property in resource.get_property_list():
			var property_name := StringName(property.get("name", &""))
			var usage := int(property.get("usage", 0))
			if property_name in [&"script", &"resource_name", &"resource_path", &"resource_local_to_scene"]:
				continue
			if usage & PROPERTY_USAGE_STORAGE == 0:
				continue
			properties[str(property_name)] = _encode_storage(
				resource.get(property_name), visited, false
			)
		return {
			"reference_index": reference_index,
			"class": resource.get_script().get_global_name() \
				if resource.get_script() is Script else resource.get_class(),
			"properties": properties,
		}
	if value is Array:
		var encoded_array: Array = []
		for item in value:
			encoded_array.append(_encode_storage(item, visited, false))
		return encoded_array
	if value is Dictionary:
		var encoded_dictionary := {}
		var keys: Array[String] = []
		for key in value:
			keys.append(str(key))
		keys.sort()
		for key in keys:
			encoded_dictionary[key] = _encode_storage(
				_dictionary_value(value, key), visited, false
			)
		return encoded_dictionary
	return _encode(value, visited)


static func _is_editable_resource(resource: Resource) -> bool:
	return resource is CharacterProgressionProfile \
		or resource is UnitData \
		or resource is DisciplineData \
		or resource is DisciplineRankData \
		or resource is SkillUpgradeData \
		or resource is Spell \
		or resource is SpellModifier


static func _dictionary_value(dictionary: Dictionary, text_key: String) -> Variant:
	if dictionary.has(text_key):
		return dictionary[text_key]
	var string_name := StringName(text_key)
	if dictionary.has(string_name):
		return dictionary[string_name]
	for key in dictionary:
		if str(key) == text_key:
			return dictionary[key]
	return null
