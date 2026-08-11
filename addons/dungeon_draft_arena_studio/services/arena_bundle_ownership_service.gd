@tool
class_name ArenaBundleOwnershipService
extends RefCounted

const ARCHIVE_ROOT := "user://dungeon_draft_studio/abandoned_productions"


static func inspect(
		directory: String,
		graph: StudioReferenceGraphService = null
	) -> Dictionary:
	return ArenaBundleInspectionService.inspect(directory, graph)


static func archive_unreferenced_incomplete(
		directory: String,
		reason: String,
		graph: StudioReferenceGraphService = null
	) -> Dictionary:
	var inspection := inspect(directory, graph)
	if inspection.state != ArenaBundleInspectionService.OWNED_INCOMPLETE \
			or bool(inspection.referenced):
		return {"ok": false, "error": "bundle_not_archivable", "inspection": inspection}
	return archive_unreferenced_bundle(
		directory, reason, graph, &"ARCHIVE_INCOMPLETE"
	)


static func archive_unreferenced_bundle(
		directory: String,
		reason: String,
		graph: StudioReferenceGraphService = null,
		operation: StringName = &"ARCHIVE"
	) -> Dictionary:
	var inspection := inspect(directory, graph)
	var references := inspection.get("reference_report", {}) as Dictionary
	if (inspection.get("files", {}) as Dictionary).is_empty():
		return {"ok": false, "error": "bundle_empty", "inspection": inspection}
	if bool(references.get("referenced", inspection.get("referenced", false))):
		return {"ok": false, "error": "bundle_referenced", "inspection": inspection}
	if bool(references.get("busy", false)):
		return {"ok": false, "error": "bundle_transaction_active", "inspection": inspection}
	if not _safe_archive_source(directory):
		return {"ok": false, "error": "unsafe_archive_source", "inspection": inspection}
	var archive_id := "%s_%d" % [directory.get_file(), Time.get_ticks_usec()]
	var archive := ARCHIVE_ROOT.path_join(archive_id)
	if not _copy_tree(directory, archive):
		_remove_tree(archive)
		return {"ok": false, "error": "archive_copy_failed"}
	var archived_files := ArenaBundleInspectionService._files(archive)
	if not _same_files(inspection.files, archived_files):
		_remove_tree(archive)
		return {"ok": false, "error": "archive_verification_failed"}
	var receipt := {
		"archive_id": archive_id,
		"original_destination": directory,
		"operation": str(operation),
		"source_state": str(inspection.get("state", &"UNKNOWN")),
		"reason": reason,
		"archived_at": Time.get_datetime_string_from_system(true),
		"files": archived_files,
		"reference_report": references,
	}
	_write_json(archive.path_join("archive_receipt.json"), receipt)
	if not _remove_tree(directory):
		return {"ok": false, "error": "destination_release_failed", "archive": archive}
	return {
		"ok": true,
		"archive": archive,
		"receipt": receipt,
		"restore_available": true,
		"source_removed_from_project": true,
	}


static func restore_archive(archive: String, destination: String) -> Dictionary:
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(destination)):
		return {"ok": false, "error": "destination_not_empty"}
	if not _copy_tree(archive, destination, {"archive_receipt.json": true}):
		_remove_tree(destination)
		return {"ok": false, "error": "restore_copy_failed"}
	return {"ok": true, "destination": destination}


static func _copy_tree(source: String, target: String, excluded := {}) -> bool:
	var source_absolute := ProjectSettings.globalize_path(source)
	var access := DirAccess.open(source_absolute)
	if access == null:
		return false
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(target)) != OK:
		return false
	for file_name in access.get_files():
		if excluded.has(file_name):
			continue
		if DirAccess.copy_absolute(
			source_absolute.path_join(file_name),
			ProjectSettings.globalize_path(target.path_join(file_name))
		) != OK:
			return false
	for child in access.get_directories():
		if not _copy_tree(source.path_join(child), target.path_join(child), excluded):
			return false
	return true


static func _same_files(left: Dictionary, right: Dictionary) -> bool:
	if left.size() != right.size():
		return false
	for path in left:
		if not right.has(path) or str((left[path] as Dictionary).sha256) \
				!= str((right[path] as Dictionary).sha256):
			return false
	return true


static func _safe_archive_source(path: String) -> bool:
	if path.is_empty() or path in ["res://", "user://"] or ".." in path:
		return false
	for protected_root in [
		ARCHIVE_ROOT,
		ArenaProductionTransactionService.TRANSACTION_ROOT,
		"user://dungeon_draft_studio/production_resolutions",
	]:
		if path == protected_root or path.begins_with(protected_root.trim_suffix("/") + "/"):
			return false
	return path.begins_with(ArenaProductionService.DEFAULT_ROOT.trim_suffix("/") + "/") \
		or path.begins_with("user://")


static func _write_json(path: String, value: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(value, "  "))
	file.close()
	return true


static func _remove_tree(path: String) -> bool:
	var absolute := ProjectSettings.globalize_path(path)
	var access := DirAccess.open(absolute)
	if access == null:
		return true
	for file_name in access.get_files():
		DirAccess.remove_absolute(absolute.path_join(file_name))
	for child in access.get_directories():
		_remove_tree(path.path_join(child))
	return DirAccess.remove_absolute(absolute) == OK
