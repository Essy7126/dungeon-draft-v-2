@tool
class_name ArenaSerializer
extends RefCounted

const CANONICAL_ROOT := "res://data/arenas"
const RECOVERY_ROOT := "user://arena_studio/recovery"


static func suggested_path(arena: ArenaDefinition) -> String:
	return CANONICAL_ROOT.path_join(str(arena.arena_id) + ".tres")


static func save_canonical(arena: ArenaDefinition, path := "") -> Error:
	if arena == null:
		return ERR_INVALID_PARAMETER
	if path.is_empty():
		path = suggested_path(arena)
	if not path.begins_with("res://") or not path.ends_with(".tres"):
		return ERR_INVALID_PARAMETER
	ArenaRuntimeBridge.sync_runtime_resources(arena)
	var absolute := ProjectSettings.globalize_path(path)
	var directory_error := DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	if directory_error != OK:
		return directory_error
	var save_error := ResourceSaver.save(arena, path)
	if save_error == OK:
		remove_recovery(arena.arena_id)
	return save_error


static func load_canonical(path: String) -> ArenaDefinition:
	if not ResourceLoader.exists(path):
		return null
	var arena := load(path) as ArenaDefinition
	if arena != null:
		ArenaRuntimeBridge.sync_runtime_resources(arena)
	return arena


static func save_recovery(arena: ArenaDefinition) -> Error:
	if arena == null:
		return ERR_INVALID_PARAMETER
	var path := recovery_path(arena.arena_id)
	var absolute := ProjectSettings.globalize_path(path)
	var directory_error := DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	if directory_error != OK:
		return directory_error
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(arena.to_snapshot(), "  "))
	return OK


static func load_recovery(path: String) -> ArenaDefinition:
	if not FileAccess.file_exists(path):
		return null
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		return null
	var arena := ArenaDefinition.new()
	if not arena.restore_snapshot(parsed):
		return null
	ArenaRuntimeBridge.sync_runtime_resources(arena)
	return arena


static func recovery_path(arena_id: StringName) -> String:
	return RECOVERY_ROOT.path_join(str(arena_id) + ".json")


static func recovery_files() -> PackedStringArray:
	var result := PackedStringArray()
	var directory := DirAccess.open(RECOVERY_ROOT)
	if directory == null:
		return result
	for file_name in directory.get_files():
		if file_name.ends_with(".json"):
			result.append(RECOVERY_ROOT.path_join(file_name))
	result.sort()
	return result


static func remove_recovery(arena_id: StringName) -> void:
	var absolute := ProjectSettings.globalize_path(recovery_path(arena_id))
	if FileAccess.file_exists(absolute):
		DirAccess.remove_absolute(absolute)
