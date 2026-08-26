@tool
class_name ArenaProductionTransactionService
extends RefCounted

const TRANSACTION_ROOT := "user://dungeon_draft_studio/production_transactions"


static func produce(
		arena: ArenaDefinition,
		destination := "",
		provided_images := {},
		options := {}
	) -> Dictionary:
	var production_plan := ArenaProductionService.plan(
		arena, destination, options.get("reference_graph") as StudioReferenceGraphService
	)
	if not production_plan.get("ok", false):
		return production_plan
	if not production_plan.get("can_produce", false):
		return {"ok": false, "error": "validation_or_conflict", "plan": production_plan}
	destination = str(production_plan.destination)
	var reuse := _idempotent_reuse(arena, destination)
	if reuse.get("ok", false):
		return reuse
	var transaction_id := "%s_%d_%d" % [
		str(arena.arena_id), int(Time.get_unix_time_from_system() * 1000000.0),
		Time.get_ticks_usec(),
	]
	var transaction_directory := TRANSACTION_ROOT.path_join(transaction_id)
	var staging := destination.get_base_dir().path_join(
		".%s_%s.staging" % [destination.get_file(), transaction_id]
	)
	if DirAccess.make_dir_recursive_absolute(
			ProjectSettings.globalize_path(transaction_directory)
		) != OK:
		return {"ok": false, "error": "transaction_directory_failed"}
	var transaction := {
		"transaction_id": transaction_id,
		"transaction_directory": transaction_directory,
		"destination": destination,
		"staging": staging,
		"backup": transaction_directory.path_join("backup_bundle"),
		"destination_existed": DirAccess.dir_exists_absolute(
			ProjectSettings.globalize_path(destination)
		),
		"destination_before": ArenaBundleInspectionService._files(destination),
		"committed": false,
	}
	_write_report(transaction, &"PLANNED")
	_remove_tree(staging)
	var build_options := options.duplicate(true)
	build_options["compatibility_outputs"] = bool(production_plan.compatibility_outputs)
	var staged := ArenaProductionService.build_staged_bundle(
		arena, staging, destination, provided_images, build_options
	)
	if not staged.get("ok", false):
		_remove_tree(staging)
		_write_report(transaction, &"STAGING_FAILED", staged)
		return staged.merged({"transaction": transaction, "plan": production_plan}, true)
	var verification := _verify_bundle(staging, arena)
	if not verification.get("ok", false):
		_remove_tree(staging)
		_write_report(transaction, &"STAGING_VERIFICATION_FAILED", verification)
		return verification.merged({"transaction": transaction, "plan": production_plan}, true)
	if str(options.get("failure_step", "")) == "before_commit":
		_remove_tree(staging)
		var failure := ArenaProductionService._injected_failure("before_commit")
		_write_report(transaction, &"BEFORE_COMMIT_FAILED", failure)
		return failure.merged({"transaction": transaction, "plan": production_plan}, true)
	var backup := _prepare_backup(transaction)
	if not backup.get("ok", false):
		_remove_tree(staging)
		_write_report(transaction, &"BACKUP_FAILED", backup)
		return backup.merged({"transaction": transaction, "plan": production_plan}, true)
	transaction["backup_prepared"] = true
	var commit_error := DirAccess.rename_absolute(
		ProjectSettings.globalize_path(staging), ProjectSettings.globalize_path(destination)
	)
	if commit_error != OK:
		var commit_copy := _copy_tree(staging, destination)
		if commit_copy:
			_remove_tree(staging)
		else:
			var failed_commit := {"ok": false, "error": "commit_failed", "code": commit_error}
			_restore_previous(transaction)
			_write_report(transaction, &"COMMIT_FAILED", failed_commit)
			return failed_commit.merged({"transaction": transaction}, true)
	transaction["committed"] = true
	_write_marker(transaction_directory.path_join("commit.marker"), transaction_id)
	if str(options.get("failure_step", "")) == "after_commit":
		var injected := ArenaProductionService._injected_failure("after_commit")
		var rollback := _restore_previous(transaction)
		_write_report(transaction, &"ROLLED_BACK", injected.merged({"rollback": rollback}, true))
		return injected.merged({
			"transaction": transaction, "rollback": rollback, "plan": production_plan,
		}, true)
	var final_verification := _verify_bundle(destination, arena)
	if not final_verification.get("ok", false):
		var rollback := _restore_previous(transaction)
		_write_report(transaction, &"FINAL_VERIFICATION_ROLLBACK", {
			"verification": final_verification, "rollback": rollback,
		})
		return {
			"ok": false, "error": "final_verification_failed",
			"details": final_verification, "rollback": rollback,
			"transaction": transaction, "plan": production_plan,
		}
	var final_arena := ResourceLoader.load(
		destination.path_join("arena.tres"), "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as ArenaDefinition
	var manifest := ArenaProductionService._read_json(
		destination.path_join(ArenaProductionService.MANIFEST_FILE)
	)
	_write_report(transaction, &"COMMITTED", final_verification)
	return {
		"ok": true,
		"status": "SALLE_PRETE",
		"directory": destination,
		"arena_path": destination.path_join("arena.tres"),
		"validation": ArenaValidator.validate(final_arena, false),
		"manifest": manifest,
		"recovery": {
			"ok": true,
			"directory": str(transaction.backup) if bool(transaction.destination_existed) else "",
			"files": (transaction.destination_before as Dictionary).keys(),
		},
		"created": production_plan.creates,
		"modified": production_plan.modifies,
		"resources_reloaded": true,
		"direct_test_available": true,
		"visual_report": ArenaVisualAssembler.inspect(final_arena),
		"idempotent_reuse": false,
		"transaction": transaction,
	}


static func rollback_committed(transaction: Dictionary) -> Dictionary:
	if not bool(transaction.get("committed", false)):
		return {"ok": false, "error": "transaction_not_committed"}
	var result := _restore_previous(transaction)
	_write_report(transaction, &"ROLLED_BACK_BY_INTEGRATION", result)
	return result


static func finalize(transaction: Dictionary) -> Dictionary:
	if not bool(transaction.get("committed", false)):
		return {"ok": true, "finalized": false}
	var backup := str(transaction.get("backup", ""))
	if not backup.is_empty():
		_remove_tree(backup)
	_write_report(transaction, &"FINALIZED")
	return {"ok": true, "finalized": true}


static func _idempotent_reuse(arena: ArenaDefinition, destination: String) -> Dictionary:
	var inspection := ArenaBundleInspectionService.inspect(destination)
	if inspection.state not in [
		ArenaBundleInspectionService.OWNED_COMPLETE,
		ArenaBundleInspectionService.REFERENCED_COMPLETE,
	]:
		return {"ok": false}
	var manifest: Dictionary = inspection.manifest
	if str(manifest.get("generated_by", "")) != ArenaProductionService.GENERATED_BY \
			or int(manifest.get("generator_revision", 0)) != ArenaProductionService.GENERATOR_REVISION \
			or str(manifest.get("source_fingerprint", "")) != ArenaSnapshotService.arena_fingerprint(arena):
		return {"ok": false}
	var arena_path := destination.path_join("arena.tres")
	var existing := ResourceLoader.load(
		arena_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as ArenaDefinition
	var expected_logical_fingerprint := str(manifest.get(
		"logical_arena_fingerprint", manifest.get("produced_fingerprint", "")
	))
	if existing == null or ArenaSnapshotService.arena_fingerprint(existing) \
			!= expected_logical_fingerprint:
		return {"ok": false}
	var report := ArenaValidator.validate(existing, false)
	if not report.is_valid():
		return {"ok": false}
	return {
		"ok": true, "status": "SALLE_PRETE", "directory": destination,
		"arena_path": arena_path, "validation": report, "manifest": manifest,
		"recovery": {"ok": true, "directory": "", "files": []},
		"created": [], "modified": [], "resources_reloaded": true,
		"direct_test_available": true,
		"visual_report": ArenaVisualAssembler.inspect(existing),
		"idempotent_reuse": true, "transaction": {},
	}


static func _verify_bundle(directory: String, source: ArenaDefinition) -> Dictionary:
	var manifest := ArenaProductionService._read_json(
		directory.path_join(ArenaProductionService.MANIFEST_FILE)
	)
	if manifest.is_empty() or str(manifest.get("generated_by", "")) \
			!= ArenaProductionService.GENERATED_BY:
		return {"ok": false, "error": "manifest_invalid"}
	if int(manifest.get("manifest_schema_version", 0)) \
			!= ArenaProductionService.MANIFEST_SCHEMA_VERSION \
			or str(manifest.get("fingerprint_algorithm_id", "")) \
				!= ArenaProductionService.FINGERPRINT_ALGORITHM_ID \
			or not bool(manifest.get("complete", false)):
		return {"ok": false, "error": "manifest_contract_outdated"}
	var files: Variant = manifest.get(
		"physical_file_hash", manifest.get("files", {})
	)
	if not files is Dictionary:
		return {"ok": false, "error": "manifest_files_invalid"}
	for relative_path in files:
		var path := directory.path_join(str(relative_path))
		if not FileAccess.file_exists(path) \
				or FileAccess.get_sha256(path) != str(files[relative_path]):
			return {"ok": false, "error": "file_hash_mismatch", "file": relative_path}
	var arena_path := directory.path_join("arena.tres")
	var arena := ResourceLoader.load(
		arena_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as ArenaDefinition
	if arena == null:
		return {"ok": false, "error": "arena_reload_failed"}
	var actual_arena_fingerprint := ArenaSnapshotService.arena_fingerprint(arena)
	var expected_arena_fingerprint := str(manifest.get(
		"logical_arena_fingerprint", manifest.get("produced_fingerprint", "")
	))
	var actual_source_fingerprint := ArenaSnapshotService.arena_fingerprint(source)
	var expected_source_fingerprint := str(manifest.get("source_fingerprint", ""))
	var actual_gameplay_fingerprint := ArenaSnapshotService.gameplay_fingerprint(arena)
	var expected_gameplay_fingerprint := str(manifest.get(
		"gameplay_fingerprint",
		manifest.get(
			"produced_gameplay_fingerprint",
			ArenaSnapshotService.gameplay_fingerprint(source)
		)
	))
	if actual_arena_fingerprint != expected_arena_fingerprint \
			or expected_source_fingerprint != actual_source_fingerprint \
			or actual_gameplay_fingerprint != expected_gameplay_fingerprint:
		return {
			"ok": false, "error": "fingerprint_mismatch",
			"arena_actual": actual_arena_fingerprint,
			"arena_expected": expected_arena_fingerprint,
			"source_actual": actual_source_fingerprint,
			"source_expected": expected_source_fingerprint,
			"gameplay_actual": actual_gameplay_fingerprint,
			"gameplay_expected": expected_gameplay_fingerprint,
		}
	var arena_text := FileAccess.get_file_as_string(arena_path)
	# Le chemin publié du bundle est une référence res:// canonique attendue
	# (notamment pour assets/background.png). Seul un chemin de staging ayant
	# fui dans la Resource rend le bundle non portable.
	if ".staging" in arena_text:
		return {"ok": false, "error": "non_relative_staging_reference"}
	var visual := ArenaVisualAssembler.inspect(arena)
	var runtime := ArenaRuntimeProjectionService.build(arena)
	if not visual.valid or runtime == null:
		return {"ok": false, "error": "runtime_construction_failed"}
	return {
		"ok": true, "files": files.size(),
		"arena_fingerprint": ArenaSnapshotService.arena_fingerprint(arena),
		"gameplay_fingerprint": ArenaSnapshotService.gameplay_fingerprint(arena),
		"visual_report": visual.to_dict(),
	}


static func _prepare_backup(transaction: Dictionary) -> Dictionary:
	if not bool(transaction.destination_existed):
		return {"ok": true, "backup": ""}
	var destination := str(transaction.destination)
	var backup := str(transaction.backup)
	_remove_tree(backup)
	var rename_error := DirAccess.rename_absolute(
		ProjectSettings.globalize_path(destination), ProjectSettings.globalize_path(backup)
	)
	if rename_error == OK:
		return {"ok": true, "backup": backup, "mode": "rename"}
	if not _copy_tree(destination, backup):
		_remove_tree(backup)
		return {"ok": false, "error": "backup_copy_failed", "code": rename_error}
	if not _same_files(transaction.destination_before, ArenaBundleInspectionService._files(backup)):
		_remove_tree(backup)
		return {"ok": false, "error": "backup_verification_failed"}
	if not _remove_tree(destination):
		return {"ok": false, "error": "destination_release_failed"}
	return {"ok": true, "backup": backup, "mode": "copy"}


static func _restore_previous(transaction: Dictionary) -> Dictionary:
	var destination := str(transaction.get("destination", ""))
	var backup := str(transaction.get("backup", ""))
	_remove_tree(destination)
	if bool(transaction.get("destination_existed", false)):
		var restored := DirAccess.rename_absolute(
			ProjectSettings.globalize_path(backup), ProjectSettings.globalize_path(destination)
		) == OK
		if not restored:
			restored = _copy_tree(backup, destination)
		if not restored or not _same_files(
				transaction.get("destination_before", {}),
				ArenaBundleInspectionService._files(destination)
			):
			return {"ok": false, "error": "rollback_verification_failed"}
		var arena_path := destination.path_join("arena.tres")
		if FileAccess.file_exists(arena_path) and ResourceLoader.load(
				arena_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
			) == null:
			return {"ok": false, "error": "rollback_reload_failed"}
		return {"ok": true, "restored": true}
	return {
		"ok": not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(destination)),
		"restored": false,
	}


static func _copy_tree(source: String, target: String) -> bool:
	var access := DirAccess.open(ProjectSettings.globalize_path(source))
	if access == null:
		return false
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(target)) != OK:
		return false
	for file_name in access.get_files():
		if DirAccess.copy_absolute(
			ProjectSettings.globalize_path(source.path_join(file_name)),
			ProjectSettings.globalize_path(target.path_join(file_name))
		) != OK:
			return false
	for child in access.get_directories():
		if not _copy_tree(source.path_join(child), target.path_join(child)):
			return false
	return true


static func _remove_tree(path: String) -> bool:
	if path.is_empty() or path in ["res://", "user://"]:
		return false
	var absolute := ProjectSettings.globalize_path(path)
	var access := DirAccess.open(absolute)
	if access == null:
		return true
	for file_name in access.get_files():
		if DirAccess.remove_absolute(absolute.path_join(file_name)) != OK:
			return false
	for child in access.get_directories():
		if not _remove_tree(path.path_join(child)):
			return false
	return DirAccess.remove_absolute(absolute) == OK


static func _same_files(left: Dictionary, right: Dictionary) -> bool:
	if left.size() != right.size():
		return false
	for path in left:
		if not right.has(path) or str((left[path] as Dictionary).sha256) \
				!= str((right[path] as Dictionary).sha256):
			return false
	return true


static func _write_marker(path: String, value: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(value)
		file.close()


static func _write_report(
		transaction: Dictionary,
		status: StringName,
		details := {}
	) -> void:
	var directory := str(transaction.get("transaction_directory", ""))
	if directory.is_empty():
		return
	var serialized_details: Dictionary = details.duplicate(true) \
		if details is Dictionary else {}
	if details is Dictionary:
		var validation: Variant = serialized_details.get("validation")
		if validation is ArenaValidationReport:
			serialized_details["validation"] = validation.to_dict()
	var report := StudioVersion.metadata("arena_production_transaction")
	report.merge({
		"transaction_id": transaction.get("transaction_id", ""),
		"status": str(status),
		"destination": transaction.get("destination", ""),
		"staging": transaction.get("staging", ""),
		"backup": transaction.get("backup", ""),
		"details": serialized_details,
	}, true)
	ArenaProductionService._write_json(directory.path_join("transaction_report.json"), report)
	ArenaBundleReferenceService.invalidate_transaction_cache()
