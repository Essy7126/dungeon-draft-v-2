@tool
class_name EncounterSaveService
extends RefCounted


## Le plan est dérivé du contenu atteignable, pas de la liste de callbacks dirty.
static func build_plan(session: EncounterEditSession) -> Dictionary:
	if session == null or session.working_run == null or session.room_draft_mode:
		return {"ok": false, "error": "room_draft_not_publishable"}
	if session.document_fingerprint() == session.opening_fingerprint:
		return {"ok": true, "entries": [], "paths": []}
	var resources: Array[Resource] = []
	for room in session.working_run.rooms:
		if room == null:
			continue
		if room.encounter_definition != null and not resources.has(room.encounter_definition):
			resources.append(room.encounter_definition)
		for wave in room.waves:
			if wave != null and wave.encounter_definition != null and not resources.has(wave.encounter_definition):
				resources.append(wave.encounter_definition)
	for room in session.working_run.rooms:
		if room != null and not resources.has(room):
			resources.append(room)
	resources.append(session.working_run)
	var entries: Array[Dictionary] = []
	var targets := {}
	for resource in resources:
		var source := session.source_for(resource)
		if source != null and session._document_value(resource, {}) == session._document_value(source, {}):
			continue
		var path := str(session.new_resource_paths.get(resource, ""))
		var is_new := not path.is_empty()
		if path.is_empty():
			path = source.resource_path if source != null else resource.resource_path
		if path.is_empty() or "::" in path:
			# Une sous-ressource est écrite par son parent.
			if resource != session.working_run:
				continue
		if not _is_safe_resource_path(path):
			return {"ok": false, "error": "unsafe_or_missing_path", "path": path}
		if targets.has(path) or (is_new and FileAccess.file_exists(path)):
			return {"ok": false, "error": "target_collision", "path": path}
		targets[path] = resource
		entries.append({"resource": resource, "path": path, "initial": _file_fingerprint(path)})
	return {"ok": true, "entries": entries, "paths": targets.keys()}


## Les options d'injection servent uniquement aux régressions ciblées.
static func save(session: EncounterEditSession, options := {}) -> Dictionary:
	if session != null and session.room_draft_mode:
		return {"ok": false, "error": "room_draft_not_publishable",
			"message": "Utilisez « Intégrer à la partie » pour publier ce brouillon."}
	if session == null or session.working_run == null:
		return {"ok": true, "saved_paths": [], "message": "Aucun changement."}
	var plan := build_plan(session)
	if not plan.get("ok", false):
		return plan
	if plan.entries.is_empty():
		return {"ok": true, "saved_paths": [], "message": "Aucun changement."}
	var conflict := session.conflict_report()
	if conflict.get("conflict", false):
		return {"ok": false, "error": "external_conflict", "details": conflict}
	var validation := EncounterValidationService.validate_session(session, session.working_run.default_seed)
	if EncounterValidationService.has_errors(validation):
		return {"ok": false, "error": "validation_failed",
			"validation": validation.map(func(message): return message.to_dictionary())}
	var recovery := _write_recovery(session)
	if not recovery.get("ok", false):
		return recovery
	var directory := str(recovery.path).get_base_dir()
	var journal: Array[Dictionary] = []
	for entry in plan.entries:
		var path := str(entry.path)
		if _file_fingerprint(path) != entry.initial:
			return {"ok": false, "error": "external_conflict", "path": path}
		var backup := directory.path_join(path.sha256_text() + "." + path.get_extension())
		if bool(entry.initial.exists):
			var error := DirAccess.copy_absolute(
				ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(backup))
			if error != OK or _file_fingerprint(backup) != entry.initial:
				return {"ok": false, "error": "backup_failed", "path": path, "code": error}
		journal.append({"path": path, "backup": backup, "initial": entry.initial})
	var publication := EncounterCopyService.copy_run(session.working_run)
	if publication.is_empty():
		return {"ok": false, "error": "publication_copy_failed"}
	var copies := publication.source_to_work as Dictionary
	var published := {}
	var planned := {}
	for entry in plan.entries:
		planned[entry.resource] = true
	# Conserver les références externes inchangées, sans charger ni modifier
	# les Resources canoniques dans la working copy.
	for work in copies:
		var source := session.source_for(work)
		if not planned.has(work) and source != null and _is_safe_resource_path(source.resource_path):
			var external := ResourceLoader.load(source.resource_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
			if external == null:
				return {"ok": false, "error": "external_reload_failed", "path": source.resource_path}
			published[copies[work]] = external
	var touched: Array[Dictionary] = []
	for i in range(plan.entries.size()):
		var entry: Dictionary = plan.entries[i]
		var record := journal[i]
		if _file_fingerprint(entry.path) != record.initial:
			return _failed("external_conflict", entry.path, touched, recovery)
		var resource := copies.get(entry.resource) as Resource
		if resource == null:
			return _failed("publication_copy_missing", entry.path, touched, recovery)
		_bind_publication_children(resource, published)
		var expected := session._document_value(resource, {})
		var references := _external_references(resource)
		# Inscrire avant l'appel : une écriture échouée peut avoir tronqué la cible.
		touched.append(record)
		var error := ResourceSaver.save(resource, entry.path)
		if error != OK:
			return _failed("resource_save_failed", entry.path, touched, recovery, error)
		if int(options.get("fail_after_write", -1)) == touched.size():
			return _failed("injected_write_failure", entry.path, touched, recovery)
		var reloaded := ResourceLoader.load(entry.path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
		if reloaded == null or session._document_value(reloaded, {}) != expected \
				or _external_references(reloaded) != references:
			var failure := _failed("resource_verification_failed", entry.path, touched, recovery)
			failure["verification"] = {"expected": expected,
				"actual": session._document_value(reloaded, {}),
				"expected_references": references,
				"actual_references": _external_references(reloaded) if reloaded != null else {}}
			_write_json(directory.path_join("verification_failure.json"), failure.verification)
			return failure
		published[resource] = reloaded
	var reopened := ResourceLoader.load(session.source_run_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as RunData
	var candidate := EncounterEditSession.new()
	if bool(options.get("fail_reopen", false)) or reopened == null \
			or not candidate.open(reopened, session.source_run_path):
		return _failed("working_copy_reopen_failed", session.source_run_path, touched, recovery)
	var expected_session := EncounterEditSession.new()
	expected_session.working_run = session.working_run
	if candidate.document_fingerprint() != expected_session.document_fingerprint():
		return _failed("working_copy_verification_failed", session.source_run_path, touched, recovery)
	var room_index := session.selected_room_index
	var wave_index := session.selected_wave_index
	if not session.open(reopened, session.source_run_path):
		return _failed("working_copy_reopen_failed", session.source_run_path, touched, recovery)
	session.select(room_index, wave_index)
	var report := {"ok": true, "saved_paths": plan.paths,
		"recovery_path": recovery.path, "recovery_manifest": recovery.manifest,
		"journal": journal, "timestamp": Time.get_datetime_string_from_system()}
	session.last_save_report = report
	return report


static func save_draft(session: EncounterEditSession) -> Dictionary:
	if session == null or session.working_run == null or session.room_draft_mode:
		return {"ok": false, "error": "canonical_session_required"}
	var result := _write_recovery(session)
	if result.get("ok", false):
		session.confirm_draft_saved()
	return result


## Même format récupérable pour DRAFT et pour la récupération avant publication.
static func _write_recovery(session: EncounterEditSession) -> Dictionary:
	if not _is_safe_resource_path(session.source_run_path) \
			or not _portable_document(session._document_value(session.working_run, {})):
		return {"ok": false, "error": "unsafe_recovery_path"}
	var stamp := "%d_%d" % [int(Time.get_unix_time_from_system() * 1000000.0), Time.get_ticks_usec()]
	var directory := EncounterEditSession.RECOVERY_ROOT.path_join("save_" + stamp)
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory)) != OK:
		return {"ok": false, "error": "recovery_directory_failed"}
	var path := directory.path_join("working_run.tres")
	var error := ResourceSaver.save(session.working_run, path)
	if error != OK:
		return {"ok": false, "error": "recovery_save_failed", "code": error}
	var manifest := _recovery_manifest(session)
	manifest["verified"] = false
	var manifest_path := directory.path_join("session.json")
	if not _write_json(manifest_path, manifest):
		return {"ok": false, "error": "recovery_manifest_failed"}
	var reloaded := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as RunData
	var verified := EncounterEditSession.new()
	if reloaded == null or not verified.restore_recovery(
			reloaded, session.source_run, session.source_run_path, manifest):
		return {"ok": false, "error": "recovery_reload_failed"}
	if verified.document_fingerprint() != session.document_fingerprint() \
			or JSON.parse_string(FileAccess.get_file_as_string(manifest_path)) != JSON.parse_string(JSON.stringify(manifest)):
		return {"ok": false, "error": "recovery_verification_failed"}
	manifest["verified"] = true
	if not _write_json(manifest_path, manifest) or JSON.parse_string(
			FileAccess.get_file_as_string(manifest_path)) != JSON.parse_string(JSON.stringify(manifest)):
		return {"ok": false, "error": "recovery_confirmation_failed"}
	return {"ok": true, "path": path, "manifest": manifest_path}


static func _portable_document(value: Variant) -> bool:
	if value is Dictionary:
		if value.has("external"):
			var path := str(value.external)
			if not (path.begins_with("res://") or path.begins_with("user://")) \
					or ".." in path or "\\" in path:
				return false
		if not str(value.get("publication_path", "")).is_empty() \
				and not _is_safe_resource_path(str(value.publication_path)):
			return false
		for child in value.values():
			if not _portable_document(child):
				return false
	elif value is Array:
		for child in value:
			if not _portable_document(child):
				return false
	return true


static func _file_fingerprint(path: String) -> Dictionary:
	return {"exists": FileAccess.file_exists(path),
		"md5": FileAccess.get_md5(path) if FileAccess.file_exists(path) else ""}


static func _failed(
		error: String, path: String, touched: Array[Dictionary],
		recovery: Dictionary, code := FAILED
	) -> Dictionary:
	return {"ok": false, "error": error, "path": path, "code": code,
		"rollback": _restore_backups(touched), "recovery_path": recovery.path,
		"recovery_manifest": recovery.manifest}


static func _restore_backups(touched: Array[Dictionary]) -> Dictionary:
	var entries: Array[Dictionary] = []
	var ok := true
	var reversed := touched.duplicate()
	reversed.reverse()
	# Restaurer d'abord tous les octets, puis relire les parents et enfants.
	for record in reversed:
		var path := str(record.path)
		var error := OK
		if bool(record.initial.exists):
			if not FileAccess.file_exists(record.backup):
				error = ERR_FILE_NOT_FOUND
			else:
				error = DirAccess.copy_absolute(ProjectSettings.globalize_path(record.backup),
					ProjectSettings.globalize_path(path))
		elif FileAccess.file_exists(path):
			error = DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		entries.append({"path": path, "existed": record.initial.exists,
			"backup": record.backup, "operation": "restore" if record.initial.exists else "remove_created",
			"code": error, "expected": record.initial})
	for entry in entries:
		entry["actual"] = _file_fingerprint(entry.path)
		entry["reloaded"] = not entry.existed or ResourceLoader.load(
			entry.path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) != null
		entry["ok"] = entry.code == OK and entry.actual == entry.expected and entry.reloaded
		ok = ok and bool(entry.ok)
	return {"ok": ok, "entries": entries, "touched_paths": touched.map(func(entry): return entry.path)}


static func _bind_publication_children(resource: Resource, published: Dictionary) -> void:
	for property in RoomIntegrationFieldPolicy.stored_property_names(resource):
		var value: Variant = resource.get(property)
		if value is Resource and published.has(value):
			resource.set(property, published[value])
		elif value is RoomWaveData:
			_bind_publication_children(value, published)
		elif value is Array:
			for i in range(value.size()):
				if published.has(value[i]):
					value[i] = published[value[i]]
				elif value[i] is RoomData or value[i] is RoomWaveData:
					_bind_publication_children(value[i], published)


static func _external_references(resource: Resource, prefix := "") -> Dictionary:
	var result := {}
	for property in RoomIntegrationFieldPolicy.stored_property_names(resource):
		if property == &"script":
			continue
		var value: Variant = resource.get(property)
		var key := prefix + str(property)
		if value is Resource:
			if _is_safe_resource_path(value.resource_path):
				result[key] = value.resource_path
			elif value is RoomWaveData or value is RoomData or value is EncounterDefinition:
				result.merge(_external_references(value, key + "."))
		elif value is Array:
			for i in range(value.size()):
				if value[i] is Resource:
					var child := value[i] as Resource
					var child_key := "%s[%d]" % [key, i]
					if _is_safe_resource_path(child.resource_path):
						result[child_key] = child.resource_path
					elif child is RoomWaveData or child is RoomData or child is EncounterDefinition:
						result.merge(_external_references(child, child_key + "."))
	return result


static func latest_recovery_path() -> String:
	var directory := DirAccess.open(EncounterEditSession.RECOVERY_ROOT)
	if directory == null:
		return ""
	var latest := ""
	var latest_stamp := -1
	var latest_ticks := -1
	for folder in directory.get_directories():
		var path := EncounterEditSession.RECOVERY_ROOT.path_join(folder).path_join(
			"working_run.tres"
		)
		if FileAccess.file_exists(path):
			var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(
				path.get_base_dir().path_join("session.json")))
			if not manifest is Dictionary or not bool(manifest.get("verified", true)):
				continue
			var stamp_parts := folder.trim_prefix("save_").split("_", false)
			var folder_stamp := int(stamp_parts[0]) if stamp_parts.size() >= 1 else 0
			var folder_ticks := int(stamp_parts[1]) if stamp_parts.size() >= 2 else 0
			if folder_stamp <= 0:
				folder_stamp = FileAccess.get_modified_time(path)
			if folder_stamp > latest_stamp or (
				folder_stamp == latest_stamp and folder_ticks > latest_ticks
			):
				latest_stamp = folder_stamp
				latest_ticks = folder_ticks
				latest = path
	return latest


static func restore_latest(session: EncounterEditSession) -> Dictionary:
	var recovery_path := latest_recovery_path()
	if recovery_path.is_empty():
		return {"ok": false, "error": "recovery_missing"}
	var manifest_path := recovery_path.get_base_dir().path_join("session.json")
	if not FileAccess.file_exists(manifest_path):
		return {"ok": false, "error": "recovery_manifest_missing"}
	var manifest = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	if not manifest is Dictionary:
		return {"ok": false, "error": "recovery_manifest_invalid"}
	var source_path := str(manifest.get("source_run_path", ""))
	if not _is_safe_resource_path(source_path):
		return {"ok": false, "error": "unsafe_recovery_source"}
	var recovered := ResourceLoader.load(
		recovery_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as RunData
	var canonical := ResourceLoader.load(
		source_path, "", ResourceLoader.CACHE_MODE_IGNORE
	) as RunData if not source_path.is_empty() else null
	if recovered == null or canonical == null:
		return {"ok": false, "error": "recovery_resource_missing"}
	if not session.restore_recovery(recovered, canonical, source_path, manifest):
		return {"ok": false, "error": "recovery_restore_failed"}
	return {
		"ok": true,
		"recovery_path": recovery_path,
		"source_run_path": source_path,
	}


static func _is_safe_resource_path(path: String) -> bool:
	return (path.begins_with("res://") or path.begins_with("user://")) \
		and path.get_extension().to_lower() in ["tres", "res"] \
		and not path.contains("..") \
		and not path.contains("\\") and not path.contains("::") \
		and not path.trim_prefix("res://").trim_prefix("user://").contains(":")


static func _recovery_manifest(session: EncounterEditSession) -> Dictionary:
	var dirty_rooms := []
	var dirty_encounter_usages := []
	var room_sources := []
	var encounter_sources := {}
	for room_index in range(session.working_run.rooms.size()):
		var room := session.working_run.rooms[room_index]
		var source_room := session.source_for(room)
		room_sources.append(source_room.resource_path if source_room != null else "")
		if room == null:
			continue
		for wave_index in range(-1, room.waves.size()):
			var encounter := room.encounter_definition if wave_index == -1 else room.get_encounter_for_wave(wave_index)
			var source := session.source_for(encounter)
			encounter_sources[session._usage_key(room_index, wave_index)] = source.resource_path if source != null else ""
		if session.dirty_resources.has(room):
			dirty_rooms.append(room_index)
		_append_dirty_usage(
			dirty_encounter_usages, session, room.encounter_definition,
			room_index, -1
		)
		for wave_index in range(room.waves.size()):
			var wave := room.waves[wave_index]
			if wave != null:
				_append_dirty_usage(
					dirty_encounter_usages, session, wave.encounter_definition,
					room_index, wave_index
				)
	var new_encounters := []
	for encounter_value in session.new_resource_paths:
		var encounter := encounter_value as EncounterDefinition
		if encounter == null:
			continue
		var usages := []
		for room_index in range(session.working_run.rooms.size()):
			var room := session.working_run.rooms[room_index]
			if room == null:
				continue
			if room.encounter_definition == encounter:
				usages.append({"room": room_index, "wave": -1})
			for wave_index in range(room.waves.size()):
				if room.get_encounter_for_wave(wave_index) == encounter:
					usages.append({"room": room_index, "wave": wave_index})
		new_encounters.append({
			"path": str(session.new_resource_paths[encounter]),
			"usages": usages,
		})
	return {
		"room_sources": room_sources,
		"encounter_sources": encounter_sources,
		"source_run_path": session.source_run_path,
		"selected_room": session.selected_room_index,
		"selected_wave": session.selected_wave_index,
		"dirty_rooms": dirty_rooms,
		"dirty_encounter_usages": dirty_encounter_usages,
		"dirty_run": session.dirty_resources.has(session.working_run),
		"new_encounters": new_encounters,
		"source_fingerprints": session.source_fingerprints.duplicate(true),
		"created_at": Time.get_datetime_string_from_system(),
	}


static func _append_dirty_usage(
		usages: Array,
		session: EncounterEditSession,
		encounter: EncounterDefinition,
		room_index: int,
		wave_index: int
	) -> void:
	if encounter != null and session.dirty_resources.has(encounter):
		usages.append({"room": room_index, "wave": wave_index})


static func _write_json(path: String, value: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(value, "  "))
	return true
