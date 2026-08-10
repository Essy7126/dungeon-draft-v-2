@tool
class_name ArenaArtImportTransaction
extends RefCounted

const ROOT := "user://dungeon_draft_studio/art_import_transactions"


static func prepare(
		arena: ArenaDefinition,
		directory: String,
		image_file := "background.png"
	) -> Dictionary:
	var inspection := ArenaArtRoundTripService.inspect_reimport(
		arena, directory, image_file
	)
	if not bool(inspection.get("ok", false)):
		return inspection
	var transaction_id := "%s_%d" % [
		str(arena.arena_id), Time.get_ticks_usec(),
	]
	var transaction_root := ROOT.path_join(transaction_id)
	var staging := transaction_root.path_join("staging")
	if DirAccess.make_dir_recursive_absolute(
			ProjectSettings.globalize_path(staging)
		) != OK:
		return _failure("STAGING_FAILED", "Le staging d'import ne peut pas etre cree.")
	var staged := {}
	var sources := {
		"background": str(inspection.get("source_image", "")),
		"foreground": str(inspection.get("foreground_source", "")),
	}
	for role in sources:
		var source := str(sources[role])
		if source.is_empty() or not FileAccess.file_exists(source):
			continue
		var target := staging.path_join("%s.png" % role)
		var error := DirAccess.copy_absolute(
			ProjectSettings.globalize_path(source),
			ProjectSettings.globalize_path(target)
		)
		if error != OK:
			_remove_tree(transaction_root)
			return _failure("STAGING_COPY_FAILED", error_string(error))
		var source_hash := FileAccess.get_sha256(source)
		var target_hash := FileAccess.get_sha256(target)
		if source_hash != target_hash:
			_remove_tree(transaction_root)
			return _failure("STAGING_CHECKSUM_FAILED", "Le staging differe de la source.")
		staged[role] = {
			"source": source,
			"path": target,
			"sha256": target_hash,
		}
	return {
		"ok": true,
		"transaction_id": transaction_id,
		"transaction_root": transaction_root,
		"staging": staging,
		"staged": staged,
		"manifest": inspection.get("manifest", {}),
		"arena_fingerprint": ArenaSnapshotService.arena_fingerprint(arena),
		"room_fingerprint": ArenaSnapshotService.room_fingerprint(arena),
		"requires_alignment_confirmation": true,
		"alignment_modes": ["avant", "apres", "50/50", "clignotement", "grille_reelle"],
		"requires_recalibration": false,
	}


static func commit(
		arena: ArenaDefinition,
		plan: Dictionary,
		destination_path: String,
		alignment_confirmed: bool,
		hybrid_floor_policy := -1,
		failure_step := ""
	) -> Dictionary:
	if arena == null or not bool(plan.get("ok", false)):
		return _failure("PLAN_INVALID", "Le plan d'import est invalide.")
	if not alignment_confirmed:
		return _failure(
			"ALIGNMENT_CONFIRMATION_REQUIRED",
			"Confirmez visuellement l'alignement avant l'import."
		).merged({"plan": plan}, true)
	if ArenaSnapshotService.arena_fingerprint(arena) \
			!= str(plan.get("arena_fingerprint", "")):
		return _failure("SOURCE_CHANGED", "L'arene a change depuis l'inspection.")
	if not _valid_destination(destination_path):
		return _failure("DESTINATION_INVALID", "La destination PNG n'est pas autorisee.")
	var snapshot := ArenaSnapshotService.capture(arena)
	var transaction_root := str(plan.get("transaction_root", ""))
	var backup_root := transaction_root.path_join("backup")
	var staged := plan.get("staged", {}) as Dictionary
	var outputs := {
		"background": destination_path,
	}
	if staged.has("foreground"):
		outputs["foreground"] = destination_path.get_base_dir().path_join("foreground.png")
	var backups := {}
	var created := PackedStringArray()
	for role in outputs:
		var output := str(outputs[role])
		if FileAccess.file_exists(output):
			var backup := backup_root.path_join("%s.png" % role)
			DirAccess.make_dir_recursive_absolute(
				ProjectSettings.globalize_path(backup.get_base_dir())
			)
			var backup_error := DirAccess.copy_absolute(
				ProjectSettings.globalize_path(output),
				ProjectSettings.globalize_path(backup)
			)
			if backup_error != OK:
				return _failure("BACKUP_FAILED", error_string(backup_error))
			backups[role] = backup
		else:
			created.append(output)
	if failure_step == "before_commit":
		return _rollback(
			arena, snapshot, outputs, backups, created,
			"INJECTED_BEFORE_COMMIT"
		)
	var copied := PackedStringArray()
	for role in outputs:
		if not staged.has(role):
			continue
		var output := str(outputs[role])
		var absolute := ProjectSettings.globalize_path(output)
		if DirAccess.make_dir_recursive_absolute(absolute.get_base_dir()) != OK:
			return _rollback(
				arena, snapshot, outputs, backups, copied,
				"DIRECTORY_FAILED"
			)
		var staged_entry := staged[role] as Dictionary
		var copy_error := DirAccess.copy_absolute(
			ProjectSettings.globalize_path(str(staged_entry.path)), absolute
		)
		if copy_error != OK:
			return _rollback(
				arena, snapshot, outputs, backups, copied,
				"COPY_FAILED"
			)
		copied.append(output)
		if FileAccess.get_sha256(output) != str(staged_entry.sha256):
			return _rollback(
				arena, snapshot, outputs, backups, copied,
				"COMMIT_CHECKSUM_FAILED"
			)
		if failure_step == "after_background" and role == "background":
			return _rollback(
				arena, snapshot, outputs, backups, copied,
				"INJECTED_AFTER_BACKGROUND"
			)
	arena.background_path = destination_path
	if outputs.has("foreground"):
		arena.foreground_path = str(outputs.foreground)
	arena.visual_mode = ArenaDefinition.VisualMode.HYBRID
	if arena.modular_visual_profile == null:
		arena.modular_visual_profile = ArenaModularVisualProfile.new()
		arena.modular_visual_profile.theme_id = arena.theme_id
	if hybrid_floor_policy >= ArenaModularVisualProfile.HybridFloorPolicy.NONE:
		arena.modular_visual_profile.hybrid_floor_policy = clampi(
			hybrid_floor_policy,
			ArenaModularVisualProfile.HybridFloorPolicy.NONE,
			ArenaModularVisualProfile.HybridFloorPolicy.ALL_DEFINED
		)
	var receipt := {
		"transaction_id": str(plan.get("transaction_id", "")),
		"status": "COMMITTED",
		"alignment_confirmed": true,
		"destination_path": destination_path,
		"files": outputs,
		"arena_fingerprint_before": str(plan.get("arena_fingerprint", "")),
		"arena_fingerprint_after": ArenaSnapshotService.arena_fingerprint(arena),
		"committed_at": Time.get_datetime_string_from_system(true),
	}
	_write_json(transaction_root.path_join("import_receipt.json"), receipt)
	_remove_tree(str(plan.get("staging", "")))
	_remove_tree(backup_root)
	return {
		"ok": true,
		"destination_path": destination_path,
		"receipt": receipt,
		"transaction_root": transaction_root,
		"requires_recalibration": false,
	}


static func cancel(plan: Dictionary) -> bool:
	return _remove_tree(str(plan.get("transaction_root", "")))


static func _rollback(
		arena: ArenaDefinition,
		snapshot: Dictionary,
		outputs: Dictionary,
		backups: Dictionary,
		copied: PackedStringArray,
		code: String
	) -> Dictionary:
	for role in outputs:
		var output := str(outputs[role])
		if backups.has(role):
			DirAccess.copy_absolute(
				ProjectSettings.globalize_path(str(backups[role])),
				ProjectSettings.globalize_path(output)
			)
		elif copied.has(output) and FileAccess.file_exists(output):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(output))
	ArenaSnapshotService.restore(arena, snapshot)
	return _failure(code, "L'import a ete annule et restaure.").merged({
		"rolled_back": true,
		"room_fingerprint": ArenaSnapshotService.room_fingerprint(arena),
	}, true)


static func _valid_destination(path: String) -> bool:
	return not path.is_empty() and ".." not in path \
		and path.get_extension().to_lower() == "png" \
		and (path.begins_with("res://") or path.begins_with("user://"))


static func _write_json(path: String, value: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(value, "  "))
	file.close()
	return true


static func _failure(code: String, message: String) -> Dictionary:
	return {"ok": false, "code": code, "error": message}


static func _remove_tree(path: String) -> bool:
	if path.is_empty():
		return true
	var absolute := ProjectSettings.globalize_path(path)
	var directory := DirAccess.open(absolute)
	if directory == null:
		return true
	for file_name in directory.get_files():
		DirAccess.remove_absolute(absolute.path_join(file_name))
	for child in directory.get_directories():
		_remove_tree(path.path_join(child))
	return DirAccess.remove_absolute(absolute) == OK
