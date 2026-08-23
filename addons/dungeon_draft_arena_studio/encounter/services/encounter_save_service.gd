@tool
class_name EncounterSaveService
extends RefCounted


static func save(session: EncounterEditSession) -> Dictionary:
	if session == null or not session.is_dirty():
		return {"ok": true, "saved_paths": [], "message": "Aucun changement."}
	var conflict := session.conflict_report()
	if conflict.get("conflict", false):
		return {"ok": false, "error": "external_conflict", "details": conflict}
	var validation := EncounterValidationService.validate_session(
		session, session.working_run.default_seed
	)
	if EncounterValidationService.has_errors(validation):
		return {
			"ok": false,
			"error": "validation_failed",
			"validation": validation.map(func(message): return message.to_dictionary()),
		}
	# Le timestamp en microsecondes reste ordonnable entre deux processus. Les
	# ticks departagent deux sauvegardes creees dans la meme microseconde.
	var stamp := "%d_%d" % [
		int(Time.get_unix_time_from_system() * 1000000.0), Time.get_ticks_usec()
	]
	var recovery_dir := EncounterEditSession.RECOVERY_ROOT.path_join("save_" + stamp)
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(recovery_dir)) != OK:
		return {"ok": false, "error": "recovery_directory_failed"}
	var recovery_path := recovery_dir.path_join("working_run.tres")
	var recovery_error := ResourceSaver.save(session.working_run, recovery_path)
	if recovery_error != OK:
		return {"ok": false, "error": "recovery_save_failed", "code": recovery_error}
	var manifest_path := recovery_dir.path_join("session.json")
	if not _write_json(manifest_path, _recovery_manifest(session)):
		return {"ok": false, "error": "recovery_manifest_failed"}
	var existing_paths := session.affected_paths()
	for path in existing_paths:
		if not path.begins_with("res://") or not FileAccess.file_exists(path):
			continue
		var backup := recovery_dir.path_join(path.get_file())
		var copy_error := DirAccess.copy_absolute(
			ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(backup)
		)
		if copy_error != OK:
			return {"ok": false, "error": "backup_failed", "path": path, "code": copy_error}
	var saved := PackedStringArray()
	var ordered_resources: Array[Resource] = []
	for resource_value in session.new_resource_paths:
		ordered_resources.append(resource_value)
	for resource_value in session.dirty_resources:
		if resource_value is EncounterDefinition and not ordered_resources.has(resource_value):
			ordered_resources.append(resource_value)
	for resource_value in session.dirty_resources:
		if resource_value is RoomData and not ordered_resources.has(resource_value):
			ordered_resources.append(resource_value)
	for resource_value in session.dirty_resources:
		if resource_value is RunData and not ordered_resources.has(resource_value):
			ordered_resources.append(resource_value)
	var parents_rebound := false
	for resource in ordered_resources:
		if resource is RoomWaveData:
			continue
		if not parents_rebound and (resource is RoomData or resource is RunData):
			_rebind_parent_encounters(session)
			parents_rebound = true
		var path := str(session.new_resource_paths.get(resource, ""))
		if path.is_empty():
			var source := session.source_for(resource)
			path = source.resource_path if source != null else resource.resource_path
		if not _is_safe_resource_path(path):
			_restore_backups(existing_paths, recovery_dir)
			return {"ok": false, "error": "unsafe_or_missing_path", "path": path}
		var error := ResourceSaver.save(resource, path)
		if error != OK:
			_restore_backups(existing_paths, recovery_dir)
			return {"ok": false, "error": "resource_save_failed", "path": path, "code": error}
		var reloaded := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if reloaded == null:
			_restore_backups(existing_paths, recovery_dir)
			return {"ok": false, "error": "resource_reload_failed", "path": path}
		saved.append(path)
	var report := {
		"ok": true,
		"saved_paths": saved,
		"recovery_path": recovery_path,
		"recovery_manifest": manifest_path,
		"timestamp": Time.get_datetime_string_from_system(),
	}
	var selected_room := session.selected_room_index
	var selected_wave := session.selected_wave_index
	var reopened := ResourceLoader.load(
		session.source_run_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as RunData if not session.source_run_path.is_empty() else null
	if reopened != null and session.open(reopened, session.source_run_path):
		session.select(selected_room, selected_wave)
	else:
		session.mark_clean()
	session.last_save_report = report
	return report


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
	var recovered := ResourceLoader.load(
		recovery_path, "", ResourceLoader.CACHE_MODE_IGNORE
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
		and not path.contains("..")


static func _recovery_manifest(session: EncounterEditSession) -> Dictionary:
	var dirty_rooms := []
	var dirty_encounter_usages := []
	for room_index in range(session.working_run.rooms.size()):
		var room := session.working_run.rooms[room_index]
		if room == null:
			continue
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


static func _rebind_parent_encounters(session: EncounterEditSession) -> void:
	if session == null or session.working_run == null:
		return
	var replacements := {}
	for room_value in session.working_run.rooms:
		var room := room_value as RoomData
		if room == null:
			continue
		room.encounter_definition = _external_encounter(
			session, room.encounter_definition, replacements
		)
		for wave in room.waves:
			if wave != null:
				wave.encounter_definition = _external_encounter(
					session, wave.encounter_definition, replacements
				)


static func _external_encounter(
		session: EncounterEditSession,
		encounter: EncounterDefinition,
		replacements: Dictionary
	) -> EncounterDefinition:
	if encounter == null:
		return null
	if replacements.has(encounter):
		return replacements[encounter] as EncounterDefinition
	var path := str(session.new_resource_paths.get(encounter, ""))
	if path.is_empty():
		var source := session.source_for(encounter)
		path = source.resource_path if source != null else encounter.resource_path
	if not _is_safe_resource_path(path) or not FileAccess.file_exists(path):
		return encounter
	var external := ResourceLoader.load(
		path, "", ResourceLoader.CACHE_MODE_IGNORE
	) as EncounterDefinition
	if external == null:
		return encounter
	replacements[encounter] = external
	return external


static func _restore_backups(paths: PackedStringArray, recovery_dir: String) -> void:
	for path in paths:
		var backup := recovery_dir.path_join(path.get_file())
		if FileAccess.file_exists(backup):
			DirAccess.copy_absolute(
				ProjectSettings.globalize_path(backup),
				ProjectSettings.globalize_path(path),
			)
