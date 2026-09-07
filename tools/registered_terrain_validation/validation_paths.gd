extends RefCounted

static func plan_path(arena: ArenaDefinition, battle: Node = null) -> String:
	if battle != null:
		var effective: Variant = battle.get("registered_terrain_plan_path")
		if effective is String and not effective.is_empty():
			return effective
	return str(arena.get("registered_terrain_plan_path")) if arena != null else ""

static func manifest_path(arena: ArenaDefinition, battle: Node = null) -> String:
	var path := plan_path(arena, battle)
	if path.is_empty() or not FileAccess.file_exists(path):
		return ""
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not value is Dictionary:
		return ""
	var manifest := str(value.get("geometry_manifest_path", "geometry_manifest.json"))
	return manifest if manifest.begins_with("res://") or manifest.is_absolute_path() else path.get_base_dir().path_join(manifest)
