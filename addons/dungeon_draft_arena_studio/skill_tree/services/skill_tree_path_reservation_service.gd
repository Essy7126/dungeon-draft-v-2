@tool
class_name SkillTreePathReservationService
extends RefCounted

enum Status {
	FREE,
	RESERVED_IN_SESSION,
	EXISTS_ON_DISK,
	EXISTS_IN_RESOURCE_CACHE_ONLY,
	EXISTS_AS_RECOGNIZED_RESOURCE,
	UNSAFE_PATH,
	TYPE_CONFLICT,
}

var allowed_roots := PackedStringArray(["res://data/"])
var _reserved := {}


func _init(roots: PackedStringArray = PackedStringArray(["res://data/"])) -> void:
	allowed_roots = roots.duplicate()


func inspect(path: String, expected_type: String = "") -> Dictionary:
	var safe := _safe_path(path)
	var on_disk := FileAccess.file_exists(path)
	var recognized := ResourceLoader.exists(path)
	var cached := ResourceLoader.has_cached(path)
	var reserved := _reserved.has(path)
	var loaded: Resource = null
	if (recognized or cached) and not expected_type.is_empty():
		loaded = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REUSE)
	var type_conflict := loaded != null and not _matches_expected_type(loaded, expected_type)
	var status := Status.FREE
	if not safe:
		status = Status.UNSAFE_PATH
	elif type_conflict:
		status = Status.TYPE_CONFLICT
	elif reserved:
		status = Status.RESERVED_IN_SESSION
	elif on_disk:
		status = Status.EXISTS_ON_DISK
	elif cached:
		status = Status.EXISTS_IN_RESOURCE_CACHE_ONLY
	elif recognized:
		status = Status.EXISTS_AS_RECOGNIZED_RESOURCE
	return {
		"path": path,
		"status": status,
		"status_name": Status.keys()[status],
		"safe": safe,
		"reserved": reserved,
		"file_exists": on_disk,
		"resource_loader_exists": recognized,
		"resource_cached": cached,
		"type_conflict": type_conflict,
		"loaded_resource": loaded,
	}


func reserve(path: String, owner: Variant = null, expected_type: String = "") -> Dictionary:
	var report := inspect(path, expected_type)
	if int(report.get("status", Status.UNSAFE_PATH)) == Status.FREE:
		_reserved[path] = owner
		report["reserved"] = true
	return report


func release(path: String) -> void:
	_reserved.erase(path)


func clear() -> void:
	_reserved.clear()


func is_reserved(path: String) -> bool:
	return _reserved.has(path)


func owner_for(path: String) -> Variant:
	return _reserved.get(path)


func reserved_paths() -> PackedStringArray:
	var result := PackedStringArray()
	for path_value in _reserved:
		result.append(str(path_value))
	result.sort()
	return result


func generate_unique_path(path: String, expected_type: String = "") -> String:
	if int(inspect(path, expected_type).get("status", Status.UNSAFE_PATH)) == Status.FREE:
		return path
	var extension := path.get_extension()
	var stem := path.trim_suffix("." + extension) if not extension.is_empty() else path
	var suffix := 2
	while suffix < 100000:
		var candidate := "%s_%d%s" % [
			stem,
			suffix,
			"." + extension if not extension.is_empty() else "",
		]
		if int(inspect(candidate, expected_type).get(
				"status", Status.UNSAFE_PATH
			)) == Status.FREE:
			return candidate
		suffix += 1
	return ""


func _safe_path(path: String) -> bool:
	if path.is_empty() or path.contains("..") \
			or path.get_extension().to_lower() not in ["tres", "res"]:
		return false
	for root in allowed_roots:
		if path.begins_with(root):
			return true
	return false


func _matches_expected_type(resource: Resource, expected_type: String) -> bool:
	if expected_type.is_empty() or resource.is_class(expected_type):
		return true
	var script := resource.get_script() as Script
	return script != null and script.get_global_name() == expected_type
