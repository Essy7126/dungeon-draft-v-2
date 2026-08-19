@tool
class_name ArenaBundleOwnershipMigrationService
extends RefCounted

## Transactional migration of a RoomData that was incorrectly stored as
## foreign content inside a produced bundle. The room is materialized in the
## run-owned namespace first; the foreign file is archived and removed only
## after the run reloads with identical gameplay.

const RECOVERY_ROOT := "user://dungeon_draft_studio/bundle_ownership_migrations"


static func plan(
		bundle_directory: String,
		run_path: String,
		room_index: int
	) -> Dictionary:
	var inspection := ArenaBundleInspectionService.inspect(bundle_directory)
	if StringName(inspection.get("state", &"")) != ArenaBundleInspectionService.OWNED_DIRTY:
		return _plan_error(
			"bundle_not_owned_dirty", bundle_directory, run_path, room_index, inspection
		)
	if bool(inspection.get("transaction_active", false)):
		return _plan_error(
			"bundle_transaction_active", bundle_directory, run_path, room_index, inspection
		)
	if not (inspection.get("missing", []) as PackedStringArray).is_empty() \
			or not (inspection.get("dirty", []) as PackedStringArray).is_empty():
		return _plan_error(
			"owned_payload_not_physically_clean",
			bundle_directory, run_path, room_index, inspection
		)
	var run := ResourceLoader.load(
		run_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as RunData
	if run == null or room_index < 0 or room_index >= run.rooms.size():
		return _plan_error(
			"run_or_room_index_invalid", bundle_directory, run_path, room_index, inspection
		)
	var source_path := bundle_directory.path_join("arena.tres")
	var source := ResourceLoader.load(
		source_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as ArenaDefinition
	var target := run.rooms[room_index]
	if source == null or target == null or target.resource_path.is_empty():
		return _plan_error(
			"source_or_target_missing", bundle_directory, run_path, room_index, inspection
		)
	var bundle_prefix := bundle_directory.trim_suffix("/") + "/"
	if not target.resource_path.begins_with(bundle_prefix):
		return _plan_error(
			"target_is_not_foreign_bundle_room",
			bundle_directory, run_path, room_index, inspection
		)
	var target_relative := target.resource_path.trim_prefix(bundle_prefix)
	var foreign := inspection.get("foreign", PackedStringArray()) as PackedStringArray
	if not foreign.has(target_relative) or foreign.size() != 1:
		return _plan_error(
			"foreign_content_scope_ambiguous",
			bundle_directory, run_path, room_index, inspection
		)
	var destination_report := ArenaRunOwnedRoomPathPolicy.destination_report(
		run, room_index, target, source_path
	)
	if not bool(destination_report.get("ok", false)):
		return _plan_error(
			"run_owned_destination_invalid",
			bundle_directory, run_path, room_index, inspection
		)
	var destination := str(destination_report.get("path", ""))
	var encounter_path := target.encounter_definition.resource_path \
		if target.encounter_definition != null else ""
	return {
		"ok": true,
		"dry_run": true,
		"bundle_directory": bundle_directory,
		"run_path": run_path,
		"room_index": room_index,
		"room_count": run.rooms.size(),
		"source_arena_path": source_path,
		"foreign_room_path": target.resource_path,
		"foreign_room_relative_path": target_relative,
		"run_owned_room_path": destination,
		"run_owned_room_existed": FileAccess.file_exists(destination),
		"gameplay_fingerprint": RoomDataSnapshotService.gameplay_fingerprint(target),
		"encounter_path": encounter_path,
		"encounter_fingerprint": _encounter_fingerprint(
			target.encounter_definition
		),
		"run_sha256": FileAccess.get_sha256(run_path),
		"foreign_room_sha256": FileAccess.get_sha256(target.resource_path),
		"manifest_sha256": FileAccess.get_sha256(
			bundle_directory.path_join(ArenaProductionService.MANIFEST_FILE)
		),
		"bundle_files": inspection.get("files", {}).duplicate(true),
		"inspection": inspection,
		"destination_report": destination_report,
	}


static func execute(
		bundle_directory: String,
		run_path: String,
		room_index: int,
		options: Dictionary = {}
	) -> Dictionary:
	var migration_plan := plan(bundle_directory, run_path, room_index)
	if not bool(migration_plan.get("ok", false)):
		return migration_plan
	var operation_id := "%s_%d" % [bundle_directory.get_file(), Time.get_ticks_usec()]
	var recovery := RECOVERY_ROOT.path_join(operation_id)
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(recovery)) != OK:
		return migration_plan.merged({
			"ok": false, "error": "recovery_create_failed", "recovery": recovery,
		}, true)
	var backups := _create_backups(migration_plan, recovery)
	if not bool(backups.get("ok", false)):
		return migration_plan.merged(backups, true).merged({"recovery": recovery}, true)
	ArenaProductionService._write_json(
		recovery.path_join("ownership_migration_preflight.json"),
		migration_plan.merged({
			"operation_id": operation_id,
			"created_at_utc": Time.get_datetime_string_from_system(true),
		}, true)
	)
	var run := ResourceLoader.load(
		run_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as RunData
	var attachment := ArenaProductionAttachmentService.attach_and_save(
		str(migration_plan.get("source_arena_path", "")),
		run,
		ArenaProductionAttachmentService.UPDATE,
		room_index
	)
	if not bool(attachment.get("ok", false)):
		return _rollback(
			migration_plan, recovery, operation_id, backups, attachment,
			"run_owned_attachment_failed", {"attachment": attachment}
		)
	if not bool(attachment.get("materialized_run_owned", false)) \
			or str(attachment.get("integrated_room_path", "")) \
				!= str(migration_plan.get("run_owned_room_path", "")):
		return _rollback(
			migration_plan, recovery, operation_id, backups, attachment,
			"run_owned_attachment_contract_mismatch", {"attachment": attachment}
		)
	var verification := _verify_run(migration_plan)
	if not bool(verification.get("ok", false)):
		return _rollback(
			migration_plan, recovery, operation_id, backups, attachment,
			"run_verification_failed", verification
		)
	if str(options.get("failure_step", "")) == "after_run_update":
		return _rollback(
			migration_plan, recovery, operation_id, backups, attachment,
			"injected_after_run_update"
		)
	var foreign_path := str(migration_plan.get("foreign_room_path", ""))
	if DirAccess.remove_absolute(ProjectSettings.globalize_path(foreign_path)) != OK:
		return _rollback(
			migration_plan, recovery, operation_id, backups, attachment,
			"foreign_room_remove_failed"
		)
	if str(options.get("failure_step", "")) == "after_foreign_archive":
		return _rollback(
			migration_plan, recovery, operation_id, backups, attachment,
			"injected_after_foreign_archive"
		)
	var post_removal := ArenaBundleInspectionService.inspect(bundle_directory)
	if StringName(post_removal.get("state", &"")) \
			!= ArenaBundleInspectionService.LEGACY_LOGICAL_FINGERPRINT:
		return _rollback(
			migration_plan, recovery, operation_id, backups, attachment,
			"post_removal_bundle_not_legacy_clean", {"inspection": post_removal}
		)
	var manifest_migration := ArenaBundleManifestMigrationService.execute(
		bundle_directory
	)
	if not bool(manifest_migration.get("ok", false)):
		return _rollback(
			migration_plan, recovery, operation_id, backups, attachment,
			"manifest_migration_failed", {"manifest_migration": manifest_migration}
		)
	var final_inspection := ArenaBundleInspectionService.inspect(bundle_directory)
	var final_verification := _verify_run(migration_plan)
	if StringName(final_inspection.get("state", &"")) \
			!= ArenaBundleInspectionService.OWNED_CLEAN \
			or not bool(final_verification.get("ok", false)):
		return _rollback(
			migration_plan, recovery, operation_id, backups, attachment,
			"final_verification_failed", {
				"inspection": final_inspection,
				"run_verification": final_verification,
			}
		)
	var report := migration_plan.merged({
		"ok": true,
		"status": "COMPLETED",
		"dry_run": false,
		"operation_id": operation_id,
		"recovery": recovery,
		"backups": backups,
		"attachment": attachment,
		"manifest_migration": manifest_migration,
		"run_verification": final_verification,
		"final_inspection": final_inspection,
		"completed_at_utc": Time.get_datetime_string_from_system(true),
	}, true)
	ArenaProductionService._write_json(
		recovery.path_join("ownership_migration_report.json"), report
	)
	return report


static func _create_backups(migration_plan: Dictionary, recovery: String) -> Dictionary:
	var mapping := {
		"run": [migration_plan.get("run_path", ""), recovery.path_join("run.before.tres")],
		"foreign_room": [
			migration_plan.get("foreign_room_path", ""),
			recovery.path_join("foreign_room.before.tres"),
		],
		"manifest": [
			str(migration_plan.get("bundle_directory", "")).path_join(
				ArenaProductionService.MANIFEST_FILE
			),
			recovery.path_join("production_manifest.before.json"),
		],
	}
	var result := {"ok": true, "files": {}}
	for label in mapping:
		var pair := mapping[label] as Array
		var source := str(pair[0])
		var backup := str(pair[1])
		if source.is_empty() or not FileAccess.file_exists(source) \
				or DirAccess.copy_absolute(
					ProjectSettings.globalize_path(source),
					ProjectSettings.globalize_path(backup)
				) != OK:
			return {"ok": false, "error": "backup_failed", "file": source}
		result.files[label] = {
			"source": source,
			"backup": backup,
			"sha256": FileAccess.get_sha256(backup),
		}
	var run_owned_path := str(migration_plan.get("run_owned_room_path", ""))
	if FileAccess.file_exists(run_owned_path):
		var backup := recovery.path_join("run_owned_room.before.tres")
		if DirAccess.copy_absolute(
			ProjectSettings.globalize_path(run_owned_path),
			ProjectSettings.globalize_path(backup)
		) != OK:
			return {"ok": false, "error": "backup_failed", "file": run_owned_path}
		result.files["run_owned_room"] = {
			"source": run_owned_path,
			"backup": backup,
			"sha256": FileAccess.get_sha256(backup),
		}
	return result


static func _verify_run(migration_plan: Dictionary) -> Dictionary:
	var run := ResourceLoader.load(
		str(migration_plan.get("run_path", "")), "",
		ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as RunData
	var room_index := int(migration_plan.get("room_index", -1))
	if run == null or run.rooms.size() != int(migration_plan.get("room_count", -1)) \
			or room_index < 0 or room_index >= run.rooms.size():
		return {"ok": false, "error": "run_shape_mismatch"}
	var room := run.rooms[room_index]
	if room == null or room.resource_path \
			!= str(migration_plan.get("run_owned_room_path", "")):
		return {"ok": false, "error": "run_owned_reference_mismatch"}
	var gameplay := RoomDataSnapshotService.gameplay_fingerprint(room)
	var encounter_path := room.encounter_definition.resource_path \
		if room.encounter_definition != null else ""
	var encounter_fingerprint := _encounter_fingerprint(room.encounter_definition)
	var expected_encounter_path := str(migration_plan.get("encounter_path", ""))
	var external_encounter_path_matches := expected_encounter_path.is_empty() \
		or "::" in expected_encounter_path \
		or encounter_path == expected_encounter_path
	if gameplay != str(migration_plan.get("gameplay_fingerprint", "")) \
			or encounter_fingerprint \
				!= str(migration_plan.get("encounter_fingerprint", "")) \
			or not external_encounter_path_matches:
		return {
			"ok": false,
			"error": "gameplay_or_encounter_mismatch",
			"gameplay_expected": migration_plan.get("gameplay_fingerprint", ""),
			"gameplay_actual": gameplay,
			"encounter_expected": migration_plan.get("encounter_path", ""),
			"encounter_actual": encounter_path,
			"encounter_fingerprint_expected": migration_plan.get(
				"encounter_fingerprint", ""
			),
			"encounter_fingerprint_actual": encounter_fingerprint,
		}
	return {
		"ok": true,
		"run_path": run.resource_path,
		"room_count": run.rooms.size(),
		"room_index": room_index,
		"room_path": room.resource_path,
		"gameplay_fingerprint": gameplay,
		"encounter_path": encounter_path,
		"encounter_fingerprint": encounter_fingerprint,
	}


static func _encounter_fingerprint(encounter: EncounterDefinition) -> String:
	if encounter == null:
		return ""
	return JSON.stringify(
		RoomIntegrationFieldPolicy.stable_value(encounter), "", true
	).sha256_text()


static func _rollback(
		migration_plan: Dictionary,
		recovery: String,
		operation_id: String,
		backups: Dictionary,
		attachment: Dictionary,
		error: String,
		details: Dictionary = {}
	) -> Dictionary:
	var rollback_ok := true
	var files := backups.get("files", {}) as Dictionary
	for label in ["manifest", "foreign_room", "run"]:
		var record := files.get(label, {}) as Dictionary
		if record.is_empty():
			rollback_ok = false
			continue
		rollback_ok = DirAccess.copy_absolute(
			ProjectSettings.globalize_path(str(record.get("backup", ""))),
			ProjectSettings.globalize_path(str(record.get("source", "")))
		) == OK and rollback_ok
	var run_owned_path := str(migration_plan.get("run_owned_room_path", ""))
	if files.has("run_owned_room"):
		var owned_record := files.run_owned_room as Dictionary
		rollback_ok = DirAccess.copy_absolute(
			ProjectSettings.globalize_path(str(owned_record.backup)),
			ProjectSettings.globalize_path(run_owned_path)
		) == OK and rollback_ok
	elif FileAccess.file_exists(run_owned_path):
		var failed_copy := recovery.path_join("run_owned_room.failed.tres")
		rollback_ok = DirAccess.copy_absolute(
			ProjectSettings.globalize_path(run_owned_path),
			ProjectSettings.globalize_path(failed_copy)
		) == OK and rollback_ok
		rollback_ok = DirAccess.remove_absolute(
			ProjectSettings.globalize_path(run_owned_path)
		) == OK and rollback_ok
	var verification := plan(
		str(migration_plan.get("bundle_directory", "")),
		str(migration_plan.get("run_path", "")),
		int(migration_plan.get("room_index", -1))
	)
	rollback_ok = bool(verification.get("ok", false)) and rollback_ok
	var report := migration_plan.merged({
		"ok": false,
		"error": error,
		"status": "ROLLED_BACK" if rollback_ok else "ROLLBACK_FAILED",
		"operation_id": operation_id,
		"recovery": recovery,
		"backups": backups,
		"attachment": attachment,
		"rollback_ok": rollback_ok,
		"rollback_verification": verification,
		"details": details,
	}, true)
	ArenaProductionService._write_json(
		recovery.path_join("ownership_migration_report.json"), report
	)
	return report


static func _plan_error(
		error: String,
		bundle_directory: String,
		run_path: String,
		room_index: int,
		inspection: Dictionary
	) -> Dictionary:
	return {
		"ok": false,
		"dry_run": true,
		"error": error,
		"bundle_directory": bundle_directory,
		"run_path": run_path,
		"room_index": room_index,
		"inspection": inspection,
	}
