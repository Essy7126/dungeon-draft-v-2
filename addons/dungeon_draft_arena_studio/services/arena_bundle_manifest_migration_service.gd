@tool
class_name ArenaBundleManifestMigrationService
extends RefCounted

## Explicit, recoverable migration from a physically verified legacy manifest
## to the current logical-fingerprint contract. Payload Resources are read-only:
## only production_manifest.json may change.

const RECOVERY_ROOT := "user://dungeon_draft_studio/manifest_migrations"


static func plan(directory: String) -> Dictionary:
	var inspection := ArenaBundleInspectionService.inspect(directory)
	var state := StringName(inspection.get("state", ArenaBundleInspectionService.UNKNOWN))
	if state in [
		ArenaBundleInspectionService.OWNED_CLEAN,
		ArenaBundleInspectionService.REFERENCED_COMPLETE,
	]:
		return {
			"ok": true, "required": false, "directory": directory,
			"inspection": inspection, "reason": "manifest_already_current",
		}
	if state != ArenaBundleInspectionService.LEGACY_LOGICAL_FINGERPRINT:
		return {
			"ok": false, "required": false, "directory": directory,
			"inspection": inspection, "error": "bundle_not_physically_migratable",
		}
	if bool(inspection.get("transaction_active", false)):
		return {
			"ok": false, "required": true, "directory": directory,
			"inspection": inspection, "error": "bundle_transaction_active",
		}
	var manifest := (inspection.get("manifest", {}) as Dictionary).duplicate(true)
	var arena := ResourceLoader.load(
		directory.path_join("arena.tres"), "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as ArenaDefinition
	if arena == null:
		return {
			"ok": false, "required": true, "directory": directory,
			"inspection": inspection, "error": "arena_reload_failed",
		}
	var physical_hashes := _payload_hashes(inspection.get("files", {}))
	var logical_fingerprint := ArenaSnapshotService.arena_fingerprint(arena)
	var gameplay_fingerprint := ArenaSnapshotService.gameplay_fingerprint(arena)
	var migrated := manifest.duplicate(true)
	migrated.merge({
		"version": ArenaProductionService.MANIFEST_SCHEMA_VERSION,
		"manifest_schema_version": ArenaProductionService.MANIFEST_SCHEMA_VERSION,
		"generator_revision": ArenaProductionService.GENERATOR_REVISION,
		"generated_by": ArenaProductionService.GENERATED_BY,
		"complete": true,
		"fingerprint_algorithm_id": ArenaProductionService.FINGERPRINT_ALGORITHM_ID,
		"physical_file_hash": physical_hashes.duplicate(true),
		"logical_arena_fingerprint": logical_fingerprint,
		"gameplay_fingerprint": gameplay_fingerprint,
		# Compatibility aliases are updated together; older readers continue to
		# see the same produced Resource identity.
		"files": physical_hashes.duplicate(true),
		"produced_fingerprint": logical_fingerprint,
		"produced_gameplay_fingerprint": gameplay_fingerprint,
	}, true)
	return {
		"ok": true,
		"required": true,
		"directory": directory,
		"manifest_path": directory.path_join(ArenaProductionService.MANIFEST_FILE),
		"inspection": inspection,
		"physical_file_hash": physical_hashes,
		"logical_arena_fingerprint": logical_fingerprint,
		"gameplay_fingerprint": gameplay_fingerprint,
		"manifest": migrated,
	}


static func execute(directory: String, options: Dictionary = {}) -> Dictionary:
	var migration := plan(directory)
	if not bool(migration.get("ok", false)):
		return migration
	if not bool(migration.get("required", false)):
		migration["idempotent"] = true
		return migration
	var operation_id := "%s_%d" % [directory.get_file(), Time.get_ticks_usec()]
	var recovery := RECOVERY_ROOT.path_join(operation_id)
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(recovery)) != OK:
		return migration.merged({
			"ok": false, "error": "recovery_create_failed", "recovery": recovery,
		}, true)
	var manifest_path := str(migration.get("manifest_path", ""))
	var backup_path := recovery.path_join("production_manifest.before.json")
	if DirAccess.copy_absolute(
		ProjectSettings.globalize_path(manifest_path),
		ProjectSettings.globalize_path(backup_path)
	) != OK:
		return migration.merged({
			"ok": false, "error": "manifest_backup_failed", "recovery": recovery,
		}, true)
	var before_sha256 := FileAccess.get_sha256(backup_path)
	var candidate_path := recovery.path_join("production_manifest.candidate.json")
	var candidate := (migration.get("manifest", {}) as Dictionary).duplicate(true)
	candidate["manifest_migration"] = {
		"operation_id": operation_id,
		"migrated_at_utc": Time.get_datetime_string_from_system(true),
		"previous_manifest_sha256": before_sha256,
	}
	if not ArenaProductionService._write_json(candidate_path, candidate):
		return migration.merged({
			"ok": false, "error": "manifest_candidate_write_failed",
			"recovery": recovery,
		}, true)
	_write_report(recovery, operation_id, directory, "PREPARED", {
		"before_manifest_sha256": before_sha256,
		"candidate_manifest_sha256": FileAccess.get_sha256(candidate_path),
	})
	if DirAccess.copy_absolute(
		ProjectSettings.globalize_path(candidate_path),
		ProjectSettings.globalize_path(manifest_path)
	) != OK:
		return _rollback(
			migration, recovery, operation_id, backup_path,
			"manifest_publish_failed", before_sha256
		)
	if str(options.get("failure_step", "")) == "after_manifest_publish":
		return _rollback(
			migration, recovery, operation_id, backup_path,
			"injected_after_manifest_publish", before_sha256
		)
	var inspection := ArenaBundleInspectionService.inspect(directory)
	var final_state := StringName(inspection.get("state", ArenaBundleInspectionService.UNKNOWN))
	var payload_unchanged := _same_hashes(
		migration.get("physical_file_hash", {}),
		_payload_hashes(inspection.get("files", {}))
	)
	if final_state not in [
		ArenaBundleInspectionService.OWNED_CLEAN,
		ArenaBundleInspectionService.REFERENCED_COMPLETE,
	] or not payload_unchanged:
		return _rollback(
			migration, recovery, operation_id, backup_path,
			"post_migration_verification_failed", before_sha256,
			{"inspection": inspection, "payload_unchanged": payload_unchanged}
		)
	var after_sha256 := FileAccess.get_sha256(manifest_path)
	_write_report(recovery, operation_id, directory, "COMPLETED", {
		"before_manifest_sha256": before_sha256,
		"after_manifest_sha256": after_sha256,
		"physical_file_hash": migration.get("physical_file_hash", {}),
		"logical_arena_fingerprint": migration.get("logical_arena_fingerprint", ""),
		"gameplay_fingerprint": migration.get("gameplay_fingerprint", ""),
		"final_state": str(final_state),
	})
	return migration.merged({
		"ok": true,
		"status": "COMPLETED",
		"operation_id": operation_id,
		"recovery": recovery,
		"backup": backup_path,
		"before_manifest_sha256": before_sha256,
		"after_manifest_sha256": after_sha256,
		"payload_unchanged": true,
		"inspection": inspection,
		"manifest": candidate,
	}, true)


static func _rollback(
		migration: Dictionary,
		recovery: String,
		operation_id: String,
		backup_path: String,
		error: String,
		before_sha256: String,
		details: Dictionary = {}
	) -> Dictionary:
	var manifest_path := str(migration.get("manifest_path", ""))
	var rollback_ok := DirAccess.copy_absolute(
		ProjectSettings.globalize_path(backup_path),
		ProjectSettings.globalize_path(manifest_path)
	) == OK
	rollback_ok = rollback_ok \
		and FileAccess.get_sha256(manifest_path) == before_sha256
	var report_details := details.duplicate(true)
	report_details.merge({
		"error": error,
		"rollback_ok": rollback_ok,
		"restored_manifest_sha256": FileAccess.get_sha256(manifest_path),
	}, true)
	_write_report(recovery, operation_id, str(migration.get("directory", "")), "ROLLED_BACK", report_details)
	return migration.merged({
		"ok": false,
		"error": error,
		"status": "ROLLED_BACK" if rollback_ok else "ROLLBACK_FAILED",
		"operation_id": operation_id,
		"recovery": recovery,
		"backup": backup_path,
		"rollback_ok": rollback_ok,
	}, true)


static func _payload_hashes(value: Variant) -> Dictionary:
	var files := value as Dictionary if value is Dictionary else {}
	var result := {}
	for relative_path in files:
		var path := str(relative_path)
		if path == ArenaProductionService.MANIFEST_FILE or path.ends_with(".import"):
			continue
		var metadata: Variant = files[relative_path]
		result[path] = str((metadata as Dictionary).get("sha256", "")) \
			if metadata is Dictionary else str(metadata)
	return result


static func _same_hashes(left_value: Variant, right_value: Variant) -> bool:
	if not left_value is Dictionary or not right_value is Dictionary:
		return false
	var left := left_value as Dictionary
	var right := right_value as Dictionary
	if left.size() != right.size():
		return false
	for path in left:
		if not right.has(path) or str(left[path]) != str(right[path]):
			return false
	return true


static func _write_report(
		recovery: String,
		operation_id: String,
		directory: String,
		status: String,
		details: Dictionary
	) -> void:
	ArenaProductionService._write_json(
		recovery.path_join("manifest_migration_report.json"), {
			"operation_id": operation_id,
			"status": status,
			"directory": directory,
			"updated_at_utc": Time.get_datetime_string_from_system(true),
			"details": details,
		}
	)
