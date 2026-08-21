class_name AchillesTheorycraftJson
extends RefCounted


static func canonicalize(value: Variant) -> Variant:
	if value is Dictionary:
		var source := value as Dictionary
		var keys: Array[String] = []
		for key in source.keys():
			keys.append(str(key))
		keys.sort()
		var result := {}
		for key in keys:
			var original_key: Variant = key
			if not source.has(original_key):
				for candidate in source.keys():
					if str(candidate) == key:
						original_key = candidate
						break
			result[key] = canonicalize(source.get(original_key))
		return result
	if value is Array:
		var result: Array = []
		for entry in value:
			result.append(canonicalize(entry))
		return result
	if value is PackedStringArray:
		return Array(value).map(func(entry): return str(entry))
	if value is PackedInt32Array or value is PackedInt64Array \
			or value is PackedFloat32Array or value is PackedFloat64Array:
		return Array(value)
	if value is StringName:
		return str(value)
	if value is Vector2i:
		return [value.x, value.y]
	if value is Vector2:
		return [value.x, value.y]
	if value is Vector3i:
		return [value.x, value.y, value.z]
	if value is Vector3:
		return [value.x, value.y, value.z]
	if value is Color:
		return value.to_html(true)
	return value


static func stringify(value: Variant) -> String:
	return JSON.stringify(canonicalize(value), "  ", true, true) + "\n"


static func fingerprint(value: Variant) -> String:
	return stringify(value).sha256_text()


static func safe_id(value: String) -> String:
	var result := ""
	for character in value.strip_edges().to_lower():
		if character >= "a" and character <= "z" \
				or character >= "0" and character <= "9":
			result += character
		elif character in ["_", "-"]:
			result += character
		elif character == " ":
			result += "_"
	while "__" in result:
		result = result.replace("__", "_")
	return result.trim_prefix("_").trim_suffix("_")
