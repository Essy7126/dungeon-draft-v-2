@tool
class_name ArenaRestorePointService
extends RefCounted

const ROOT := "user://dungeon_draft_studio/arena_restore_points"
const SCHEMA_VERSION := 1
const MAX_POINTS_PER_ARENA := 30


static func create_point(
		arena: ArenaDefinition,
		name: String,
		source_fingerprint := ""
	) -> Dictionary:
	if arena == null:
		return {"ok": false, "error": "Aucune map ouverte."}
	var safe_name := name.strip_edges()
	if safe_name.is_empty():
		safe_name = "Calibration %s" % Time.get_datetime_string_from_system(false, true)
	var timestamp := Time.get_unix_time_from_system()
	var identifier := "%d_%s" % [int(timestamp * 1000.0), _safe_file_name(safe_name)]
	var path := _arena_root(arena.arena_id).path_join(identifier + ".json")
	var absolute := ProjectSettings.globalize_path(path)
	var error := DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	if error != OK:
		return {"ok": false, "error": error_string(error)}
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "error": error_string(FileAccess.get_open_error())}
	var transform := GridTransformSnapshot.from_arena(arena)
	file.store_string(JSON.stringify({
		"schema_version": SCHEMA_VERSION,
		"map_id": str(arena.arena_id),
		"name": safe_name,
		"created_unix": timestamp,
		"source_fingerprint": source_fingerprint,
		"transform": transform.to_dictionary(),
	}, "  "))
	_prune(arena.arena_id)
	return {"ok": true, "path": path, "name": safe_name}


static func list_points(arena_id: StringName) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var directory := DirAccess.open(_arena_root(arena_id))
	if directory == null:
		return result
	for file_name in directory.get_files():
		if not file_name.ends_with(".json"):
			continue
		var path := _arena_root(arena_id).path_join(file_name)
		var data := _read(path)
		if not data.is_empty() and int(data.get("schema_version", 0)) == SCHEMA_VERSION:
			data["path"] = path
			result.append(data)
	result.sort_custom(func(a, b): return float(a.get("created_unix", 0.0)) > float(b.get("created_unix", 0.0)))
	return result


static func load_point(path: String, expected_arena_id: StringName) -> Dictionary:
	var data := _read(path)
	if data.is_empty():
		return {"ok": false, "error": "Le point est illisible."}
	if int(data.get("schema_version", 0)) != SCHEMA_VERSION:
		return {"ok": false, "error": "Version de point incompatible."}
	if str(data.get("map_id", "")) != str(expected_arena_id):
		return {"ok": false, "error": "Ce point appartient a une autre map."}
	var transform_data = data.get("transform", {})
	if not transform_data is Dictionary:
		return {"ok": false, "error": "La calibration du point est absente."}
	var snapshot := GridTransformSnapshot.from_dictionary(transform_data)
	var validation := GridTransformService.validate_snapshot(snapshot)
	if not bool(validation.get("ok", false)):
		return {"ok": false, "error": validation.get("error", "Calibration invalide.")}
	return {"ok": true, "snapshot": snapshot, "metadata": data}


static func rename_point(path: String, name: String) -> Error:
	var data := _read(path)
	if data.is_empty() or name.strip_edges().is_empty():
		return ERR_INVALID_PARAMETER
	data["name"] = name.strip_edges()
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data, "  "))
	return OK


static func delete_point(path: String) -> Error:
	if not path.begins_with(ROOT + "/") or not FileAccess.file_exists(path):
		return ERR_INVALID_PARAMETER
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


static func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


static func _arena_root(arena_id: StringName) -> String:
	return ROOT.path_join(_safe_file_name(str(arena_id)))


static func _safe_file_name(value: String) -> String:
	var safe := value.to_lower().strip_edges()
	for character in [" ", "/", "\\", ":", "*", "?", "\"", "<", ">", "|"]:
		safe = safe.replace(character, "_")
	return safe if not safe.is_empty() else "arena"


static func _prune(arena_id: StringName) -> void:
	var points := list_points(arena_id)
	for index in range(MAX_POINTS_PER_ARENA, points.size()):
		delete_point(str(points[index].get("path", "")))
