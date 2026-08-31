class_name VFXDraftService
extends RefCounted

const DRAFT_DIRECTORY := "user://dungeon_draft_studio/vfx_drafts"
const TRANSACTION_DIRECTORY := DRAFT_DIRECTORY + "/.transactions"
const RECOVERY_DIRECTORY := DRAFT_DIRECTORY + "/.recovery"

var force_failure_after_replace := false
var before_transaction_hook := Callable()
var before_verification_hook := Callable()


func save_draft(document: VFXStudioDocument) -> Dictionary:
	if document == null or document.working_copy == null:
		return {"ok": false, "error": "Aucun profil VFX ouvert."}
	var path_result := _draft_path(document.working_copy.profile_id)
	if not bool(path_result.get("ok", false)):
		return path_result
	var validation := VFXProfileValidator.validate(document.working_copy)
	var snapshot_errors := VFXProfileSnapshotService.validate_durable_snapshot(document.working_copy)
	if not snapshot_errors.is_empty():
		return {
			"ok": false,
			"error": "Draft non durable.",
			"snapshot_errors": snapshot_errors,
		}
	var directory_error := DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(DRAFT_DIRECTORY)
	)
	if directory_error != OK:
		return {"ok": false, "error": "Dossier de brouillons inaccessible.", "code": directory_error}
	var path := str(path_result.path)
	var baseline := _verify_document_baseline(document, path)
	if not bool(baseline.get("ok", false)):
		return baseline
	var expected_fingerprint := document.current_fingerprint()
	var nonce := Time.get_ticks_usec()
	var safe_id := str(path_result.profile_id)
	var temporary_path := DRAFT_DIRECTORY.path_join(".%s.%d.tmp" % [safe_id, nonce])
	var backup_path := DRAFT_DIRECTORY.path_join(".%s.%d.backup" % [safe_id, nonce])
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "error": "Impossible d’écrire le brouillon temporaire."}
	file.store_string(JSON.stringify(VFXProfileSnapshotService.to_dictionary(document.working_copy), "  "))
	file.flush()
	file.close()
	if not _verified_file(temporary_path, expected_fingerprint):
		_remove_file(temporary_path)
		return {"ok": false, "error": "La relecture temporaire du brouillon a échoué."}
	var staged_sha256 := FileAccess.get_sha256(temporary_path)
	if staged_sha256.is_empty():
		_remove_file(temporary_path)
		return {"ok": false, "error": "Empreinte du brouillon temporaire indisponible."}
	var target_existed := bool(baseline.get("expected_exists", false))
	var expected_original_sha256 := str(baseline.get("expected_sha256", ""))
	if before_transaction_hook.is_valid():
		before_transaction_hook.call(path)
	if FileAccess.file_exists(path) != target_existed \
			or (target_existed and FileAccess.get_sha256(path) \
			!= expected_original_sha256):
		_remove_file(temporary_path)
		return {
			"ok": false,
			"code": "external_change",
			"error": "Le brouillon a changé pendant la préparation de l’écriture.",
		}
	var transaction := _prepare_transaction(
		safe_id, nonce, path, backup_path, target_existed, staged_sha256,
		expected_original_sha256
	)
	if not bool(transaction.get("ok", false)):
		_remove_file(temporary_path)
		return {
			"ok": false,
			"error": transaction.get("error", "Récupération durable impossible."),
			"code": transaction.get("code", "recovery_prepare_failed"),
		}
	if FileAccess.file_exists(path) != target_existed \
			or (target_existed and FileAccess.get_sha256(path) \
			!= str(transaction.original_sha256)):
		_remove_file(temporary_path)
		return {
			"ok": false,
			"error": "Le brouillon a changé pendant la préparation du backup.",
			"code": "external_change",
			"transaction": _transaction_snapshot(transaction),
		}
	if target_existed:
		var backup_error := DirAccess.rename_absolute(
			ProjectSettings.globalize_path(path),
			ProjectSettings.globalize_path(backup_path),
		)
		if backup_error != OK:
			_remove_file(temporary_path)
			var backup_rollback := _conditional_rollback(
				path, backup_path, target_existed, "", transaction
			)
			return {
				"ok": false,
				"error": "Backup local du brouillon impossible.",
				"code": backup_error,
				"rolled_back": bool(backup_rollback.get("ok", false)),
				"rollback": backup_rollback,
				"transaction": _transaction_snapshot(transaction),
			}
		var moved_sha256 := FileAccess.get_sha256(backup_path)
		if moved_sha256 != str(transaction.original_sha256):
			var preserved_path := backup_path
			if not FileAccess.file_exists(path) and DirAccess.rename_absolute(
				ProjectSettings.globalize_path(backup_path),
				ProjectSettings.globalize_path(path),
			) == OK:
				preserved_path = path
			_remove_file(temporary_path)
			return {
				"ok": false,
				"error": "Le brouillon a changé au moment du remplacement ; il a été préservé.",
				"code": "external_change",
				"preserved_path": preserved_path,
				"transaction": _transaction_snapshot(transaction),
			}
	if FileAccess.file_exists(path):
		_remove_file(temporary_path)
		var appeared_rollback := _conditional_rollback(
			path, backup_path, target_existed, "", transaction
		)
		return {
			"ok": false,
			"error": "Un brouillon tiers est apparu juste avant le remplacement.",
			"code": "external_change",
			"rollback": appeared_rollback,
			"transaction": _transaction_snapshot(transaction),
		}
	var replace_error := DirAccess.rename_absolute(
		ProjectSettings.globalize_path(temporary_path),
		ProjectSettings.globalize_path(path),
	)
	if replace_error != OK:
		_remove_file(temporary_path)
		var replace_rollback := _conditional_rollback(
			path, backup_path, target_existed, "", transaction
		)
		return {
			"ok": false,
			"error": "Remplacement transactionnel impossible.",
			"code": replace_error,
			"rolled_back": bool(replace_rollback.get("ok", false)),
			"rollback": replace_rollback,
			"transaction": _transaction_snapshot(transaction),
		}
	var written_sha256 := FileAccess.get_sha256(path) \
		if FileAccess.file_exists(path) else ""
	if written_sha256 != staged_sha256:
		var physical_rollback := _conditional_rollback(
			path, backup_path, target_existed, staged_sha256, transaction
		)
		return {
			"ok": false,
			"error": "Les octets remplacés ne correspondent pas au brouillon préparé.",
			"code": "physical_write_mismatch",
			"rolled_back": bool(physical_rollback.get("ok", false)),
			"rollback": physical_rollback,
			"transaction": _transaction_snapshot(transaction),
		}
	if before_verification_hook.is_valid():
		before_verification_hook.call(path)
	var verified: bool = not force_failure_after_replace \
		and FileAccess.file_exists(path) \
		and FileAccess.get_sha256(path) == written_sha256 \
		and _verified_file(path, expected_fingerprint)
	if not verified:
		var rollback := _conditional_rollback(
			path, backup_path, target_existed, written_sha256, transaction
		)
		var failure_message := "Vérification finale échouée ; restauration du brouillon précédent."
		if bool(rollback.get("skipped_external_change", false)):
			failure_message = (
				"Vérification finale échouée ; le brouillon tiers a été préservé "
				+ "et le backup durable reste disponible."
			)
		return {
			"ok": false,
			"error": failure_message,
			"rolled_back": bool(rollback.get("ok", false)),
			"rollback": rollback,
			"transaction": _transaction_snapshot(transaction),
		}
	_remove_file(backup_path)
	_cleanup_transaction(transaction)
	document.mark_draft_saved(path, written_sha256)
	return {
		"ok": true,
		"path": path,
		"fingerprint": expected_fingerprint,
		"sha256": written_sha256,
		"valid": bool(validation.ok),
		"validation": validation,
	}


func load_draft(profile_id: StringName) -> Dictionary:
	var path_result := _draft_path(profile_id)
	if not bool(path_result.get("ok", false)):
		return path_result
	var path := str(path_result.path)
	if not FileAccess.file_exists(path):
		return {"ok": false, "error": "Draft introuvable : %s" % path}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "error": "Draft illisible."}
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		return {"ok": false, "error": "Draft JSON invalide."}
	var profile := VFXProfileSnapshotService.from_dictionary(parsed as Dictionary)
	if profile == null:
		return {"ok": false, "error": "Snapshot VFX impossible à reconstruire."}
	var validation := VFXProfileValidator.validate(profile)
	return {
		"ok": true,
		"valid": bool(validation.ok),
		"profile": profile,
		"path": path,
		"sha256": FileAccess.get_sha256(path),
		"validation": validation,
	}


## Écrit une copie versionnée sans toucher au brouillon canonique. Utilisée en
## dernier recours lors d'une fermeture non annulable ou d'un conflit externe.
func save_recovery(document: VFXStudioDocument) -> Dictionary:
	if document == null or document.working_copy == null:
		return {"ok": false, "error": "Aucun profil VFX à récupérer."}
	var path_result := _draft_path(document.working_copy.profile_id)
	if not bool(path_result.get("ok", false)):
		return path_result
	var snapshot_errors := VFXProfileSnapshotService.validate_durable_snapshot(
		document.working_copy
	)
	var directory_error := DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(RECOVERY_DIRECTORY)
	)
	if directory_error != OK:
		return {
			"ok": false,
			"error": "Dossier de récupération VFX inaccessible.",
			"code": directory_error,
		}
	var nonce := "%d_%d" % [
		int(Time.get_unix_time_from_system() * 1_000_000.0),
		Time.get_ticks_usec(),
	]
	var safe_id := str(path_result.profile_id)
	var resource_recovery := not snapshot_errors.is_empty()
	var extension := "tres" if resource_recovery else "json"
	var path := RECOVERY_DIRECTORY.path_join(
		"%s_%s.%s" % [safe_id, nonce, extension]
	)
	if FileAccess.file_exists(path):
		return {"ok": false, "error": "Collision de récupération VFX."}
	var fingerprint := document.current_fingerprint()
	if resource_recovery:
		var recovery_copy := VFXProfileCopyService.new().duplicate_profile(
			document.working_copy
		)
		if recovery_copy == null or ResourceSaver.save(recovery_copy, path) != OK:
			_remove_file(path)
			return {"ok": false, "error": "Écriture de récupération VFX impossible."}
		var restored := ResourceLoader.load(
			path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
		) as VFXProfile
		if restored == null \
				or VFXProfileSnapshotService.fingerprint(restored) != fingerprint:
			_remove_file(path)
			return {"ok": false, "error": "Vérification de récupération VFX impossible."}
	else:
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			return {"ok": false, "error": "Écriture de récupération VFX impossible."}
		file.store_string(JSON.stringify(
			VFXProfileSnapshotService.to_dictionary(document.working_copy), "  "
		))
		file.flush()
		file.close()
		if not _verified_file(path, fingerprint):
			_remove_file(path)
			return {"ok": false, "error": "Vérification de récupération VFX impossible."}
	return {
		"ok": true,
		"path": path,
		"fingerprint": fingerprint,
		"sha256": FileAccess.get_sha256(path),
		"recovery": true,
		"format": extension,
		"snapshot_errors": snapshot_errors,
	}


func _verify_document_baseline(
		document: VFXStudioDocument,
		path: String
	) -> Dictionary:
	var exists := FileAccess.file_exists(path)
	if not document.saved_as_draft:
		if exists:
			return {
				"ok": false,
				"code": "draft_exists_not_loaded",
				"error": (
					"Un brouillon existe déjà pour ce profil. Rechargez-le avant "
					+ "de l’écraser."
				),
			}
		return {
			"ok": true,
			"expected_exists": false,
			"expected_sha256": "",
		}
	if document.draft_path != path or document.draft_sha256.is_empty():
		return {
			"ok": false,
			"code": "draft_baseline_missing",
			"error": "La version de référence du brouillon est inconnue ; rechargez-le.",
		}
	var actual_sha256 := FileAccess.get_sha256(path) if exists else ""
	if not exists or actual_sha256 != document.draft_sha256:
		return {
			"ok": false,
			"code": "external_change",
			"error": "Le brouillon a changé hors du Studio ; rechargez-le avant d’enregistrer.",
			"expected_sha256": document.draft_sha256,
			"actual_sha256": actual_sha256,
		}
	return {
		"ok": true,
		"expected_exists": true,
		"expected_sha256": document.draft_sha256,
	}


func draft_path_for(profile_id: StringName) -> String:
	var result := _draft_path(profile_id)
	return str(result.get("path", "")) if bool(result.get("ok", false)) else ""


func _draft_path(profile_id: StringName) -> Dictionary:
	var value := str(profile_id).strip_edges()
	if not _is_safe_profile_id(value):
		return {"ok": false, "error": "Identifiant VFX dangereux ou invalide.", "code": "unsafe_profile_id"}
	return {
		"ok": true,
		"profile_id": value,
		"path": DRAFT_DIRECTORY.path_join("%s.json" % value),
	}


func _is_safe_profile_id(value: String) -> bool:
	if value.is_empty() or value.length() > 128 or value in [".", ".."]:
		return false
	var windows_stem: String = value.get_slice(".", 0).to_upper()
	if windows_stem in ["CON", "PRN", "AUX", "NUL"] \
			or windows_stem in [
				"COM1", "COM2", "COM3", "COM4", "COM5",
				"COM6", "COM7", "COM8", "COM9",
				"LPT1", "LPT2", "LPT3", "LPT4", "LPT5",
				"LPT6", "LPT7", "LPT8", "LPT9",
			]:
		return false
	for byte in value.to_ascii_buffer():
		var allowed: bool = byte >= 48 and byte <= 57 \
			or byte >= 65 and byte <= 90 \
			or byte >= 97 and byte <= 122 \
			or byte in [45, 46, 95]
		if not allowed:
			return false
	return true


func _verified_file(path: String, expected_fingerprint: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		return false
	var profile := VFXProfileSnapshotService.from_dictionary(parsed as Dictionary)
	return profile != null \
		and VFXProfileSnapshotService.fingerprint(profile) == expected_fingerprint


func _prepare_transaction(
		safe_id: String,
		nonce: int,
		path: String,
		local_backup_path: String,
		target_existed: bool,
		staged_sha256: String,
		expected_original_sha256: String
	) -> Dictionary:
	var transaction_id := "%s_%d" % [safe_id, nonce]
	var directory := TRANSACTION_DIRECTORY.path_join(transaction_id)
	var directory_error := DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(directory)
	)
	if directory_error != OK:
		return {"ok": false, "code": directory_error, "error": "Dossier de récupération inaccessible."}
	var durable_backup_path := ""
	var original_sha256 := ""
	if target_existed:
		original_sha256 = FileAccess.get_sha256(path)
		if original_sha256 != expected_original_sha256:
			return {
				"ok": false,
				"code": "external_change",
				"error": "Le brouillon a changé avant la copie de secours.",
			}
		durable_backup_path = directory.path_join("original.json")
		var copy_error := DirAccess.copy_absolute(
			ProjectSettings.globalize_path(path),
			ProjectSettings.globalize_path(durable_backup_path)
		)
		if copy_error != OK \
				or FileAccess.get_sha256(durable_backup_path) != original_sha256 \
				or FileAccess.get_sha256(path) != original_sha256 \
				or original_sha256 != expected_original_sha256:
			return {
				"ok": false,
				"code": "durable_backup_failed",
				"error": "Le backup durable du brouillon n’a pas pu être vérifié.",
			}
	var manifest_path := directory.path_join("manifest.json")
	var transaction := {
		"ok": true,
		"id": transaction_id,
		"directory": directory,
		"manifest_path": manifest_path,
		"backup_path": durable_backup_path,
		"local_backup_path": local_backup_path,
		"target_path": path,
		"target_existed": target_existed,
		"original_sha256": original_sha256,
		"staged_sha256": staged_sha256,
	}
	var manifest := transaction.duplicate(true)
	manifest["schema_version"] = 1
	manifest["status"] = "PREPARED"
	manifest["local_backup_path"] = local_backup_path
	manifest["created_at"] = Time.get_datetime_string_from_system(true)
	if not _write_json_record(manifest_path, manifest):
		_cleanup_transaction(transaction)
		return {
			"ok": false,
			"code": "recovery_manifest_failed",
			"error": "Le manifeste de récupération n’a pas pu être vérifié.",
		}
	return transaction


func _conditional_rollback(
		path: String,
		local_backup_path: String,
		target_existed: bool,
		owned_sha256: String,
		transaction: Dictionary
	) -> Dictionary:
	var original_sha256 := str(transaction.get("original_sha256", ""))
	var durable_backup_path := str(transaction.get("backup_path", ""))
	var current_sha256 := FileAccess.get_sha256(path) \
		if FileAccess.file_exists(path) else ""
	if target_existed and current_sha256 == original_sha256:
		_remove_file(local_backup_path)
		_cleanup_transaction(transaction)
		return {"ok": true, "restored": true, "action": "original_already_present"}
	if not current_sha256.is_empty():
		if owned_sha256.is_empty() or current_sha256 != owned_sha256:
			return {
				"ok": false,
				"skipped_external_change": true,
				"actual_sha256": current_sha256,
				"recovery_path": durable_backup_path,
			}
		var remove_error := DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		if remove_error != OK:
			return {"ok": false, "code": remove_error, "recovery_path": durable_backup_path}
	if FileAccess.file_exists(path):
		return {
			"ok": false,
			"skipped_external_change": true,
			"actual_sha256": FileAccess.get_sha256(path),
			"recovery_path": durable_backup_path,
		}
	if target_existed:
		if durable_backup_path.is_empty() \
				or not FileAccess.file_exists(durable_backup_path) \
				or FileAccess.get_sha256(durable_backup_path) != original_sha256:
			return {"ok": false, "error": "Backup durable absent ou altéré."}
		var restore_error := DirAccess.copy_absolute(
			ProjectSettings.globalize_path(durable_backup_path),
			ProjectSettings.globalize_path(path)
		)
		var restored_sha256 := FileAccess.get_sha256(path) \
			if FileAccess.file_exists(path) else ""
		if restore_error != OK or restored_sha256 != original_sha256:
			return {
				"ok": false,
				"skipped_external_change": not restored_sha256.is_empty() \
					and restored_sha256 != original_sha256,
				"actual_sha256": restored_sha256,
				"recovery_path": durable_backup_path,
			}
	_remove_file(local_backup_path)
	_cleanup_transaction(transaction)
	return {"ok": true, "restored": target_existed}


static func _write_json_record(path: String, record: Dictionary) -> bool:
	if FileAccess.file_exists(path):
		return false
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(record, "  "))
	file.flush()
	file.close()
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed is Dictionary \
		and str((parsed as Dictionary).get("id", "")) == str(record.get("id", "")) \
		and str((parsed as Dictionary).get("status", "")) == "PREPARED"


static func _transaction_snapshot(transaction: Dictionary) -> Dictionary:
	var backup_path := str(transaction.get("backup_path", ""))
	return {
		"id": transaction.get("id", ""),
		"directory": transaction.get("directory", ""),
		"manifest_path": transaction.get("manifest_path", ""),
		"backup_path": backup_path,
		"local_backup_path": transaction.get("local_backup_path", ""),
		"recovery_path": backup_path if not backup_path.is_empty() \
			else transaction.get("directory", ""),
		"original_sha256": transaction.get("original_sha256", ""),
		"staged_sha256": transaction.get("staged_sha256", ""),
	}


func _cleanup_transaction(transaction: Dictionary) -> void:
	_remove_file(str(transaction.get("manifest_path", "")))
	_remove_file(str(transaction.get("backup_path", "")))
	var directory := str(transaction.get("directory", ""))
	if not directory.is_empty() and DirAccess.dir_exists_absolute(
		ProjectSettings.globalize_path(directory)
	):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(directory))


func _remove_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
