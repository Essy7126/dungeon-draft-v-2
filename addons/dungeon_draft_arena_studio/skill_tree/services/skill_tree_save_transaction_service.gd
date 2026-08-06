@tool
class_name SkillTreeSaveTransactionService
extends RefCounted


static func build_plan(
		session: SkillTreeEditSession,
		options: Dictionary = {}
	) -> SkillTreeSavePlan:
	var plan := SkillTreeSavePlan.new()
	if session == null or session.working_unit == null:
		return plan
	plan.source_character_path = session.source_unit.resource_path \
		if session.source_unit != null else ""
	plan.opening_fingerprint = session.saved_fingerprint
	plan.working_fingerprint = session.current_fingerprint()
	var roots := _allowed_roots(options)
	var reservations := SkillTreePathReservationService.new(roots)
	var work_keys := SkillTreeCopyService.keys_by_resource(session.working_unit)
	var candidates: Array[Resource] = []
	for source_value in session.source_to_work:
		var source := source_value as Resource
		var work := session.source_to_work[source_value] as Resource
		if source == null or work == null or source.resource_path.is_empty() \
				or source.is_built_in():
			continue
		candidates.append(work)
		var reachable := SkillTreeSaveService._is_reachable(session.working_unit, work)
		var source_fingerprint := SkillTreeSnapshotService.storage_fingerprint(source)
		var work_fingerprint := SkillTreeSnapshotService.storage_fingerprint(work)
		if not reachable:
			var detach := _entry(
				work, source, source.resource_path,
				SkillTreeSavePlanEntry.Operation.DETACH_REFERENCE,
				false, work_keys
			)
			detach.source_fingerprint = source_fingerprint
			detach.working_fingerprint = work_fingerprint
			detach.warnings.append("La référence logique est retirée ; le fichier externe est conservé.")
			plan.add_entry(detach)
			var orphan := _entry(
				work, source, source.resource_path,
				SkillTreeSavePlanEntry.Operation.ORPHANED,
				false, work_keys
			)
			orphan.source_fingerprint = source_fingerprint
			orphan.working_fingerprint = work_fingerprint
			orphan.warnings.append("Resource externe devenue inaccessible ; elle ne sera pas réécrite.")
			plan.add_entry(orphan)
			continue
		if source_fingerprint == work_fingerprint:
			continue
		var update := _entry(
			work, source, source.resource_path,
			SkillTreeSavePlanEntry.Operation.UPDATE,
			true, work_keys
		)
		update.source_fingerprint = source_fingerprint
		update.working_fingerprint = work_fingerprint
		update.changes = _property_changes(source, work)
		plan.add_entry(update)
	for resource_value in session.new_resource_paths:
		var resource := resource_value as Resource
		var path := str(session.new_resource_paths[resource_value])
		if resource == null or path.is_empty():
			continue
		var reachable := SkillTreeSaveService._is_reachable(session.working_unit, resource)
		if not reachable:
			var orphan := _entry(
				resource, null, path,
				SkillTreeSavePlanEntry.Operation.ORPHANED,
				false, work_keys
			)
			orphan.warnings.append("Nouvelle Resource non rattachée ; aucune écriture n'est planifiée.")
			plan.add_entry(orphan)
			continue
		var create := _entry(
			resource, null, path,
			SkillTreeSavePlanEntry.Operation.CREATE,
			true, work_keys
		)
		create.working_fingerprint = SkillTreeSnapshotService.storage_fingerprint(resource)
		var reservation_report := reservations.inspect(path, _resource_type_name(resource))
		var status := int(reservation_report.get(
			"status", SkillTreePathReservationService.Status.UNSAFE_PATH
		))
		if status != SkillTreePathReservationService.Status.FREE:
			create.conflict = _path_conflict(path, status, reservation_report)
		else:
			reservations.reserve(path, resource, _resource_type_name(resource))
		plan.add_entry(create)
	plan.entries.sort_custom(func(a: SkillTreeSavePlanEntry, b: SkillTreeSavePlanEntry) -> bool:
		if a.write_order == b.write_order:
			return a.target_path < b.target_path
		return a.write_order < b.write_order
	)
	# Le ChangeSet est reconstruit après le tri pour refléter l'ordre de revue.
	plan.change_set = SkillTreeChangeSet.new()
	for entry in plan.entries:
		plan.change_set.add_entry(entry)
	for conflict in _external_conflicts(plan.writable_entries()):
		plan.conflicts.append(conflict)
		for entry in plan.entries:
			if entry.target_path == conflict.path:
				entry.conflict = conflict
				break
	return plan


static func save(
		session: SkillTreeEditSession,
		editor_interface = null,
		options: Dictionary = {}
	) -> Dictionary:
	if session == null or session.working_unit == null:
		return _failure("SESSION", "Aucun personnage n'est ouvert.")
	if not session.is_dirty():
		return {"ok": true, "saved_paths": [], "message": "Aucun changement à sauvegarder."}
	var validation := SkillTreeEditorValidator.validate_unit(
		session.working_unit,
		false,
		SkillTreeCatalogService.discover_heroes(),
		_allowed_roots(options)
	)
	if SkillTreeEditorValidator.has_errors(validation):
		return {
			"ok": false,
			"step": "VALIDATION",
			"error": "L'arbre contient des erreurs bloquantes.",
			"validation": validation,
		}
	var plan := build_plan(session, options)
	if plan.has_blocking_conflicts():
		return {
			"ok": false,
			"step": "PLAN",
			"error": "Le plan de sauvegarde contient des conflits bloquants.",
			"plan": plan,
			"conflicts": plan.conflicts,
		}
	var writable := plan.writable_entries()
	if writable.is_empty():
		return {
			"ok": false,
			"step": "PLAN",
			"error": "Le document est modifié mais aucun fichier atteignable ne peut être écrit.",
			"plan": plan,
		}
	var external_conflicts := _external_conflicts(writable)
	if not external_conflicts.is_empty():
		return {
			"ok": false,
			"step": "EXTERNAL_CONFLICT",
			"error": "Un fichier a été modifié en dehors du Skill Studio.",
			"plan": plan,
			"conflicts": external_conflicts,
		}
	if _injected(options, &"before_recovery"):
		return _failure("BEFORE_RECOVERY", "Panne injectée avant le point de récupération.", plan)
	var recovery_dir := SkillTreeSaveService._new_recovery_directory()
	if recovery_dir.is_empty():
		return _failure("RECOVERY_DIRECTORY", "Impossible de créer le point de récupération.", plan)
	plan.recovery_path = recovery_dir
	var planned_manifest := _manifest(plan, "PLANNED", [], [])
	if _injected(options, &"manifest") \
			or not _write_json(recovery_dir.path_join("manifest.json"), planned_manifest):
		return _failure("MANIFEST_PLANNED", "Impossible d'écrire le manifeste planifié.", plan, recovery_dir)
	var recovery_copy := SkillTreeSaveService._recovery_copy(session.working_unit)
	var recovery_path := recovery_dir.path_join("working_character.tres")
	var recovery_error := ERR_CANT_CREATE
	if not _injected(options, &"working_copy") and recovery_copy != null:
		recovery_error = ResourceSaver.save(recovery_copy, recovery_path)
	if recovery_error != OK:
		return _failure("WORKING_COPY", "Impossible d'enregistrer la copie de travail complète.", plan, recovery_dir, recovery_error)
	if ResourceLoader.load(
			recovery_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
		) as UnitData == null:
		return _failure("WORKING_COPY_RELOAD", "La copie de travail de récupération est illisible.", plan, recovery_dir)
	var stage_report := _stage(writable, recovery_dir, options)
	if not stage_report.get("ok", false):
		stage_report["plan"] = plan
		stage_report["recovery_path"] = recovery_dir
		return stage_report
	if _injected(options, &"backup"):
		return _failure("BACKUP", "Panne injectée avant la sauvegarde des fichiers existants.", plan, recovery_dir)
	var backup_report := SkillTreeSaveService._backup_existing_files(
		_entries_as_dictionaries(writable), recovery_dir
	)
	if not backup_report.get("ok", false):
		backup_report["step"] = "BACKUP"
		backup_report["plan"] = plan
		backup_report["recovery_path"] = recovery_dir
		return backup_report
	var saved_paths := PackedStringArray()
	var created_paths := PackedStringArray()
	for index in range(writable.size()):
		var entry := writable[index]
		if _injected(options, StringName("apply_%d" % index)) \
				or _injected(options, &"apply"):
			return _rollback_failure(
				"APPLY_%d" % index, "Panne injectée pendant l'application.",
				plan, recovery_dir, backup_report, created_paths
			)
		var path := entry.target_path
		if not _safe_path(path, _allowed_roots(options)):
			return _rollback_failure(
				"SAFE_PATH_%d" % index, "Chemin de sauvegarde non autorisé.",
				plan, recovery_dir, backup_report, created_paths, path
			)
		var absolute := ProjectSettings.globalize_path(path)
		var directory_error := DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
		if directory_error != OK:
			return _rollback_failure(
				"CREATE_DIRECTORY_%d" % index, "Impossible de créer le dossier cible.",
				plan, recovery_dir, backup_report, created_paths, path, directory_error
			)
		if not FileAccess.file_exists(path):
			created_paths.append(path)
		var error := ResourceSaver.save(entry.resource, path)
		if error != OK:
			return _rollback_failure(
				"WRITE_%d" % index, "Échec de l'écriture d'une Resource.",
				plan, recovery_dir, backup_report, created_paths, path, error
			)
		if _injected(options, StringName("reload_%d" % index)) \
				or _injected(options, &"reload"):
			return _rollback_failure(
				"RELOAD_%d" % index, "Panne injectée pendant la relecture.",
				plan, recovery_dir, backup_report, created_paths, path
			)
		var reloaded := ResourceLoader.load(
			path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
		) as Resource
		if reloaded == null or SkillTreeSnapshotService.storage_fingerprint(reloaded) \
				!= entry.working_fingerprint:
			return _rollback_failure(
				"VERIFY_%d" % index, "La Resource écrite ne correspond pas au plan.",
				plan, recovery_dir, backup_report, created_paths, path
			)
		saved_paths.append(path)
	var applied_manifest := _manifest(
		plan, "APPLIED_PENDING_RELOAD", saved_paths,
		backup_report.get("backups", []) as Array
	)
	if _injected(options, &"manifest_applied") \
			or not _write_json(recovery_dir.path_join("manifest.json"), applied_manifest):
		return _rollback_failure(
			"MANIFEST_APPLIED", "Impossible de mettre à jour le manifeste.",
			plan, recovery_dir, backup_report, created_paths
		)
	if editor_interface != null:
		var filesystem = editor_interface.get_resource_filesystem()
		if filesystem != null:
			filesystem.scan_changes()
	if _injected(options, &"final_reload") or not session.reopen_from_disk():
		return _rollback_failure(
			"FINAL_RELOAD", "Le rechargement final du document a échoué.",
			plan, recovery_dir, backup_report, created_paths
		)
	SkillTreeDraftService.clear_for_source(plan.source_character_path)
	_write_json(
		recovery_dir.path_join("manifest.json"),
		_manifest(plan, "COMPLETED", saved_paths, backup_report.get("backups", []) as Array)
	)
	return {
		"ok": true,
		"step": "COMPLETED",
		"saved_paths": saved_paths,
		"recovery_path": recovery_dir,
		"plan": plan,
		"message": "%d fichier(s) sauvegardé(s)." % saved_paths.size(),
	}


static func _entry(
		resource: Resource,
		source: Resource,
		path: String,
		operation: SkillTreeSavePlanEntry.Operation,
		reachable: bool,
		work_keys: Dictionary
	) -> SkillTreeSavePlanEntry:
	var entry := SkillTreeSavePlanEntry.new()
	entry.resource = resource
	entry.source = source
	entry.source_path = source.resource_path if source != null else ""
	entry.target_path = path
	entry.operation = operation
	entry.reachable = reachable
	entry.write_order = SkillTreeSaveService._priority(resource)
	entry.logical_owner = str(work_keys.get(resource, ""))
	entry.dependencies = _dependencies(source, resource)
	return entry


static func _path_conflict(
		path: String,
		status: int,
		report: Dictionary
	) -> SkillTreeSaveConflict:
	var kind := SkillTreeSaveConflict.Kind.PATH_COLLISION
	if status == SkillTreePathReservationService.Status.TYPE_CONFLICT:
		kind = SkillTreeSaveConflict.Kind.TYPE_CONFLICT
	elif status == SkillTreePathReservationService.Status.UNSAFE_PATH:
		kind = SkillTreeSaveConflict.Kind.UNSAFE_PATH
	elif status == SkillTreePathReservationService.Status.EXISTS_IN_RESOURCE_CACHE_ONLY:
		kind = SkillTreeSaveConflict.Kind.CACHE_ONLY_COLLISION
	return SkillTreeSaveConflict.create(
		kind,
		path,
		"Une nouvelle Resource ne peut pas remplacer implicitement ce chemin (%s)." \
			% SkillTreePathReservationService.Status.keys()[status],
		report
	)


static func _external_conflicts(
		entries: Array[SkillTreeSavePlanEntry]
	) -> Array[SkillTreeSaveConflict]:
	var result: Array[SkillTreeSaveConflict] = []
	for entry in entries:
		if entry.operation != SkillTreeSavePlanEntry.Operation.UPDATE \
				or entry.source == null:
			continue
		var disk := ResourceLoader.load(
			entry.source_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
		) as Resource
		if disk == null or SkillTreeSnapshotService.storage_fingerprint(disk) \
				!= entry.source_fingerprint:
			result.append(SkillTreeSaveConflict.create(
				SkillTreeSaveConflict.Kind.EXTERNAL_MODIFICATION,
				entry.source_path,
				"Le fichier source diffère de son empreinte d'ouverture.",
				{"deep_uncached_reload": true}
			))
	return result


static func _stage(
		entries: Array[SkillTreeSavePlanEntry],
		recovery_dir: String,
		options: Dictionary
	) -> Dictionary:
	var staging_dir := recovery_dir.path_join("staging")
	if DirAccess.make_dir_recursive_absolute(
			ProjectSettings.globalize_path(staging_dir)
		) != OK:
		return _failure("STAGING_DIRECTORY", "Impossible de créer le staging.")
	for index in range(entries.size()):
		if _injected(options, StringName("stage_%d" % index)) \
				or _injected(options, &"stage"):
			return _failure("STAGE_%d" % index, "Panne injectée pendant le staging.")
		var entry := entries[index]
		var stage_path := staging_dir.path_join(
			"%03d_%s" % [index, entry.target_path.get_file()]
		)
		var error := ResourceSaver.save(entry.resource, stage_path)
		if error != OK:
			return _failure("STAGE_WRITE_%d" % index, "Impossible d'écrire une Resource stagée.", null, stage_path, error)
		var reloaded := ResourceLoader.load(
			stage_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
		) as Resource
		if reloaded == null or SkillTreeSnapshotService.storage_fingerprint(reloaded) \
				!= entry.working_fingerprint:
			return _failure("STAGE_VERIFY_%d" % index, "Une Resource stagée est invalide.", null, stage_path)
	return {"ok": true, "step": "STAGED", "staging_path": staging_dir}


static func _rollback_failure(
		step: String,
		message: String,
		plan: SkillTreeSavePlan,
		recovery_dir: String,
		backup_report: Dictionary,
		created_paths: PackedStringArray,
		path := "",
		code := OK
	) -> Dictionary:
	SkillTreeSaveService._restore(backup_report, created_paths)
	var verification := _verify_rollback(backup_report, created_paths)
	var manifest := _manifest(
		plan, "ROLLED_BACK" if verification.get("ok", false) else "ROLLBACK_FAILED",
		[], backup_report.get("backups", []) as Array
	)
	manifest["failed_step"] = step
	manifest["rollback_verification"] = verification
	_write_json(recovery_dir.path_join("manifest.json"), manifest)
	return {
		"ok": false,
		"step": step,
		"error": message,
		"path": path,
		"code": code,
		"plan": plan,
		"recovery_path": recovery_dir,
		"rolled_back": verification.get("ok", false),
		"rollback_verification": verification,
	}


static func _verify_rollback(
		backup_report: Dictionary,
		created_paths: PackedStringArray
	) -> Dictionary:
	var missing_restorations := PackedStringArray()
	var remaining_created := PackedStringArray()
	for backup_value in backup_report.get("backups", []):
		var backup := backup_value as Dictionary
		var source := str(backup.get("source", ""))
		var backup_path := str(backup.get("backup", ""))
		if not FileAccess.file_exists(source) or not FileAccess.file_exists(backup_path) \
				or FileAccess.get_file_as_bytes(source) != FileAccess.get_file_as_bytes(backup_path):
			missing_restorations.append(source)
	for path in created_paths:
		if FileAccess.file_exists(path):
			remaining_created.append(path)
	return {
		"ok": missing_restorations.is_empty() and remaining_created.is_empty(),
		"missing_restorations": missing_restorations,
		"remaining_created": remaining_created,
	}


static func _manifest(
		plan: SkillTreeSavePlan,
		status: String,
		saved_paths: PackedStringArray,
		backups: Array
	) -> Dictionary:
	return {
		"schema_version": 2,
		"status": status,
		"created_at": Time.get_datetime_string_from_system(),
		"source_character_path": plan.source_character_path,
		"opening_fingerprint": plan.opening_fingerprint,
		"working_fingerprint": plan.working_fingerprint,
		"recovery_path": plan.recovery_path,
		"saved_paths": saved_paths,
		"backups": backups,
		"plan": plan.to_dictionary(),
	}


static func _entries_as_dictionaries(
		entries: Array[SkillTreeSavePlanEntry]
	) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in entries:
		result.append({
			"resource": entry.resource,
			"source": entry.source,
			"path": entry.target_path,
			"priority": entry.write_order,
		})
	return result


static func _dependencies(source: Resource, resource: Resource) -> PackedStringArray:
	var path := source.resource_path if source != null else resource.resource_path
	return ResourceLoader.get_dependencies(path) if not path.is_empty() \
		and ResourceLoader.exists(path) else PackedStringArray()


static func _property_changes(source: Resource, work: Resource) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if source == null or work == null:
		return result
	for info_value in work.get_property_list():
		var info := info_value as Dictionary
		var property_name := StringName(info.get("name", &""))
		if property_name in [&"script", &"resource_path", &"resource_name", &"resource_local_to_scene"] \
				or int(info.get("usage", 0)) & PROPERTY_USAGE_STORAGE == 0:
			continue
		var before: Variant = source.get(property_name)
		var after: Variant = work.get(property_name)
		if JSON.stringify(_review_value(before)) == JSON.stringify(_review_value(after)):
			continue
		result.append({
			"property": property_name,
			"before": _review_value(before),
			"after": _review_value(after),
		})
	return result


static func _review_value(value: Variant) -> Variant:
	if value is Resource:
		return SkillTreeSnapshotService.snapshot(value)
	if value is Array or value is Dictionary:
		return value.duplicate(true)
	return value


static func _resource_type_name(resource: Resource) -> String:
	if resource != null and resource.get_script() is Script:
		var global_name := (resource.get_script() as Script).get_global_name()
		if not global_name.is_empty():
			return global_name
	return resource.get_class() if resource != null else "Resource"


static func _safe_path(path: String, roots: PackedStringArray) -> bool:
	return int(SkillTreePathReservationService.new(roots).inspect(path).get(
		"status", SkillTreePathReservationService.Status.UNSAFE_PATH
	)) != SkillTreePathReservationService.Status.UNSAFE_PATH


static func _allowed_roots(options: Dictionary) -> PackedStringArray:
	var roots_value: Variant = options.get("allowed_roots")
	if roots_value is PackedStringArray:
		return (roots_value as PackedStringArray).duplicate()
	var result := PackedStringArray()
	if roots_value is Array:
		for value in roots_value:
			result.append(str(value))
	return result if not result.is_empty() else PackedStringArray(["res://data/"])


static func _injected(options: Dictionary, step: StringName) -> bool:
	var requested: Variant = options.get("fail_step", &"")
	if requested is Array:
		return requested.has(step) or requested.has(str(step))
	return StringName(requested) == step


static func _write_json(path: String, data: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data, "  "))
	file.flush()
	return file.get_error() == OK


static func _failure(
		step: String,
		message: String,
		plan: SkillTreeSavePlan = null,
		path := "",
		code := OK
	) -> Dictionary:
	return {
		"ok": false,
		"step": step,
		"error": message,
		"plan": plan,
		"path": path,
		"code": code,
	}
