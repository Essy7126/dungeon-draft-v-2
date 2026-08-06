@tool
class_name ArenaLabTransferService
extends RefCounted

const ROOT := "user://dungeon_draft_studio/lab_transfers"
const MANIFEST_VERSION := 2


static func create_transfer(arena: ArenaDefinition, validation: ArenaValidationReport) -> Dictionary:
	if arena == null:
		return {"ok": false, "error": "arena_missing"}
	var fingerprint := ArenaEditSession.fingerprint(arena.to_snapshot())
	var transfer_id := "%s_%s" % [
		str(arena.arena_id),
		fingerprint.left(12),
	]
	var final_path := ROOT.path_join(transfer_id)
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(final_path)):
		transfer_id += "_%d" % Time.get_ticks_msec()
		final_path = ROOT.path_join(transfer_id)
	var temporary_path := ROOT.path_join(".%s.tmp" % transfer_id)
	var temporary_absolute := ProjectSettings.globalize_path(temporary_path)
	var final_absolute := ProjectSettings.globalize_path(final_path)
	if DirAccess.make_dir_recursive_absolute(temporary_absolute) != OK:
		return {"ok": false, "error": "temporary_directory_failed"}
	var transfer_arena := ArenaDefinition.new()
	if not transfer_arena.restore_snapshot(arena.to_snapshot()):
		return {"ok": false, "error": "snapshot_restore_failed"}
	ArenaRuntimeBridge.sync_runtime_resources(transfer_arena)
	var arena_path := temporary_path.path_join("arena.tres")
	var save_error := ResourceSaver.save(transfer_arena, arena_path)
	if save_error != OK:
		return {"ok": false, "error": error_string(save_error)}
	var terrain_counts := {}
	var terrain_total := 0
	var wall_count := 0
	var spawn_count := 0
	var objective_count := 0
	for definition in arena.cells:
		if definition == null or not definition.defined or definition.terrain_id == &"void":
			continue
		var terrain_key := str(definition.terrain_id)
		terrain_counts[terrain_key] = int(terrain_counts.get(terrain_key, 0)) + 1
		terrain_total += 1
	for obstacle in arena.obstacles:
		if obstacle != null and obstacle.wall_id != &"":
			wall_count += 1
	for spawn in arena.spawns:
		if spawn != null:
			spawn_count += 1
	for objective in arena.objectives:
		if objective != null:
			objective_count += 1
	var profile_fingerprint := ArenaEditSession.fingerprint(
		arena.modular_visual_profile.to_dict()
	) if arena.modular_visual_profile != null else ""
	var manifest := {
		"version": MANIFEST_VERSION,
		"schema_version": arena.schema_version,
		"transfer_id": transfer_id,
		"date": Time.get_datetime_string_from_system(true),
		# Les transferts doivent rester portables entre deux checkouts du projet.
		"source_project": "res://project.godot",
		"fingerprint": fingerprint,
		"arena_fingerprint": fingerprint,
		"resource_path": "arena.tres",
		"thumbnail_path": "thumbnail.png",
		"name": arena.display_name,
		"size": [arena.grid_size.x, arena.grid_size.y],
		"grid_size": [arena.grid_size.x, arena.grid_size.y],
		"visual_mode": arena.visual_mode,
		"theme_id": str(arena.theme_id),
		"terrain_count_total": terrain_total,
		"terrain_counts": terrain_counts,
		"wall_count": wall_count,
		"spawn_count": spawn_count,
		"objective_count": objective_count,
		"modular_profile_fingerprint": profile_fingerprint,
		"validation_status": "valid" if validation != null and validation.is_valid() else "invalid",
		"validation_verdict": validation.verdict() if validation != null else "INVALID",
	}
	var thumbnail := ArenaArtKitExporter._logic_image(arena, false)
	if thumbnail != null and not thumbnail.is_empty():
		thumbnail.save_png(ProjectSettings.globalize_path(
			temporary_path.path_join("thumbnail.png")
		))
	if not _write_json(temporary_path.path_join("manifest.json"), manifest):
		return {"ok": false, "error": "manifest_write_failed"}
	var validation_data := validation.to_dict() if validation != null else {
		"valid": false, "messages": [],
	}
	if not _write_json(temporary_path.path_join("validation.json"), validation_data):
		return {"ok": false, "error": "validation_write_failed"}
	var loaded := ResourceLoader.load(arena_path, "", ResourceLoader.CACHE_MODE_IGNORE) as ArenaDefinition
	if loaded == null or ArenaEditSession.fingerprint(loaded.to_snapshot()) != fingerprint:
		return {"ok": false, "error": "verification_failed"}
	if DirAccess.rename_absolute(temporary_absolute, final_absolute) != OK:
		return {"ok": false, "error": "atomic_rename_failed"}
	return {
		"ok": true,
		"transfer_id": transfer_id,
		"directory": final_path,
		"manifest": manifest,
	}


static func pending_transfers(include_imported := false) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var directory := DirAccess.open(ROOT)
	if directory == null:
		return result
	for directory_name in directory.get_directories():
		if directory_name.begins_with("."):
			continue
		var transfer_path := ROOT.path_join(directory_name)
		var manifest_path := transfer_path.path_join("manifest.json")
		var arena_path := transfer_path.path_join("arena.tres")
		if not FileAccess.file_exists(manifest_path) or not ResourceLoader.exists(arena_path):
			continue
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
		if parsed is Dictionary:
			var entry: Dictionary = (parsed as Dictionary).duplicate(true)
			if not include_imported and bool(entry.get("imported", false)):
				continue
			entry["directory"] = transfer_path
			entry["arena_path"] = arena_path
			result.append(entry)
	result.sort_custom(func(a, b): return str(a.get("date", "")) > str(b.get("date", "")))
	return result


static func load_transfer(transfer_id: String) -> Dictionary:
	if transfer_id.is_empty() or "/" in transfer_id or "\\" in transfer_id:
		return {"ok": false, "error": "invalid_transfer_id"}
	var directory := ROOT.path_join(transfer_id)
	var manifest_path := directory.path_join("manifest.json")
	var arena_path := directory.path_join("arena.tres")
	if not FileAccess.file_exists(manifest_path) or not ResourceLoader.exists(arena_path):
		return {"ok": false, "error": "transfer_incomplete"}
	var manifest = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	var arena := ResourceLoader.load(arena_path, "", ResourceLoader.CACHE_MODE_IGNORE) as ArenaDefinition
	if not manifest is Dictionary or arena == null:
		return {"ok": false, "error": "transfer_corrupt"}
	var fingerprint := ArenaEditSession.fingerprint(arena.to_snapshot())
	var expected_fingerprint := str(manifest.get(
		"arena_fingerprint", manifest.get("fingerprint", "")
	))
	if fingerprint != expected_fingerprint:
		return {"ok": false, "error": "fingerprint_mismatch"}
	var expected_profile := str(manifest.get("modular_profile_fingerprint", ""))
	if not expected_profile.is_empty():
		var actual_profile := ArenaEditSession.fingerprint(
			arena.modular_visual_profile.to_dict()
		) if arena.modular_visual_profile != null else ""
		if actual_profile != expected_profile:
			return {"ok": false, "error": "modular_profile_fingerprint_mismatch"}
	return {"ok": true, "arena": arena, "manifest": manifest, "directory": directory}


static func delete_transfer(transfer_id: String) -> bool:
	if transfer_id.is_empty() or "/" in transfer_id or "\\" in transfer_id:
		return false
	var directory := ROOT.path_join(transfer_id)
	var absolute := ProjectSettings.globalize_path(directory)
	var root_absolute := ProjectSettings.globalize_path(ROOT)
	if not absolute.begins_with(root_absolute) or not DirAccess.dir_exists_absolute(absolute):
		return false
	return _remove_directory_contents(absolute) and DirAccess.remove_absolute(absolute) == OK


static func mark_imported(transfer_id: String) -> bool:
	if transfer_id.is_empty() or "/" in transfer_id or "\\" in transfer_id:
		return false
	var path := ROOT.path_join(transfer_id).path_join("manifest.json")
	if not FileAccess.file_exists(path):
		return false
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		return false
	var manifest := parsed as Dictionary
	manifest["imported"] = true
	manifest["imported_at"] = Time.get_datetime_string_from_system(true)
	return _write_json(path, manifest)


static func _write_json(path: String, value: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(value, "  "))
	file.close()
	return true


static func _remove_directory_contents(absolute: String) -> bool:
	var directory := DirAccess.open(absolute)
	if directory == null:
		return false
	for file_name in directory.get_files():
		if DirAccess.remove_absolute(absolute.path_join(file_name)) != OK:
			return false
	for directory_name in directory.get_directories():
		var child := absolute.path_join(directory_name)
		if not _remove_directory_contents(child) or DirAccess.remove_absolute(child) != OK:
			return false
	return true
