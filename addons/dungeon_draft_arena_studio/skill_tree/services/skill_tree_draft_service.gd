@tool
class_name SkillTreeDraftService
extends RefCounted

const SCHEMA_VERSION := 1
const DRAFT_ROOT := "user://dungeon_draft_studio/skill_tree/drafts"


static func write_draft(session: SkillTreeEditSession) -> Dictionary:
	if session == null or session.source_unit == null \
			or session.working_unit == null or not session.is_dirty():
		return {"ok": false, "error": "Aucun brouillon modifie a enregistrer."}
	var source_path := session.canonical_source_path()
	var character_root := DRAFT_ROOT.path_join(_source_key(source_path))
	var stamp := "%d_%d" % [
		int(Time.get_unix_time_from_system() * 1000000.0),
		Time.get_ticks_usec(),
	]
	var draft_dir := character_root.path_join("draft_" + stamp)
	var absolute_dir := ProjectSettings.globalize_path(draft_dir)
	var directory_error := DirAccess.make_dir_recursive_absolute(absolute_dir)
	if directory_error != OK:
		return {"ok": false, "error": "Impossible de creer le dossier du brouillon.", "code": directory_error}
	var content_path := draft_dir.path_join("working_character.tres")
	var recovery_copy := SkillTreeSaveService._recovery_copy(session.working_unit)
	var save_error := ResourceSaver.save(recovery_copy, content_path) \
		if recovery_copy != null else ERR_CANT_CREATE
	if save_error != OK:
		return {"ok": false, "error": "Impossible d'enregistrer le contenu du brouillon.", "code": save_error}
	var reloaded := ResourceLoader.load(
		content_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as UnitData
	if reloaded == null:
		return {"ok": false, "error": "Le brouillon ecrit ne peut pas etre relu."}
	var work_keys := SkillTreeCopyService.keys_by_resource(session.working_unit)
	var source_keys := SkillTreeCopyService.keys_by_resource(session.source_unit)
	var source_keys_by_work_key := {}
	for work_value in session.work_to_source:
		var work := work_value as Resource
		var source := session.work_to_source[work_value] as Resource
		if work_keys.has(work) and source_keys.has(source):
			source_keys_by_work_key[str(work_keys[work])] = str(source_keys[source])
	var new_paths_by_work_key := {}
	for work_value in session.new_resource_paths:
		var work := work_value as Resource
		if work_keys.has(work):
			new_paths_by_work_key[str(work_keys[work])] = str(
				session.new_resource_paths[work_value]
			)
	var metadata := {
		"schema_version": SCHEMA_VERSION,
		"source_path": source_path,
		"source_fingerprint": SkillTreeSnapshotService.storage_fingerprint(session.canonical_source()),
		"opening_fingerprint": session.saved_fingerprint,
		"working_fingerprint": session.current_fingerprint(),
		"created_at": Time.get_datetime_string_from_system(),
		"created_unix": Time.get_unix_time_from_system(),
		"content_path": content_path,
		"source_keys_by_work_key": source_keys_by_work_key,
		"new_paths_by_work_key": new_paths_by_work_key,
		"authority": "CHARACTER_PROGRESSION_PROFILE" if session.is_profile_authoritative() else "UNIT_DATA",
		"run_path": session.source_run.resource_path if session.source_run != null else "",
		"character_id": str(session.source_hero_profile.character_id) \
			if session.source_hero_profile != null else "",
	}
	var metadata_path := draft_dir.path_join("draft.json")
	if not _write_json(metadata_path, metadata):
		return {"ok": false, "error": "Impossible d'enregistrer le manifeste du brouillon.", "content_path": content_path}
	return {
		"ok": true,
		"draft_path": draft_dir,
		"metadata_path": metadata_path,
		"content_path": content_path,
		"metadata": metadata,
	}


static func drafts_for_source(source_path: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var root := DRAFT_ROOT.path_join(_source_key(source_path))
	var directory := DirAccess.open(root)
	if directory == null:
		return result
	for directory_name in directory.get_directories():
		var draft_dir := root.path_join(directory_name)
		var metadata_path := draft_dir.path_join("draft.json")
		var metadata := _read_json(metadata_path)
		if metadata.is_empty() or int(metadata.get("schema_version", -1)) != SCHEMA_VERSION:
			continue
		var content_path := str(metadata.get("content_path", ""))
		if content_path.is_empty() or not ResourceLoader.exists(content_path):
			continue
		metadata["draft_path"] = draft_dir
		metadata["metadata_path"] = metadata_path
		result.append(metadata)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("created_unix", 0.0)) > float(b.get("created_unix", 0.0))
	)
	return result


static func latest_for_source(source_path: String) -> Dictionary:
	var drafts := drafts_for_source(source_path)
	return drafts[0] if not drafts.is_empty() else {}


static func load_draft(metadata: Dictionary) -> UnitData:
	var content_path := str(metadata.get("content_path", ""))
	if content_path.is_empty():
		return null
	return ResourceLoader.load(
		content_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as UnitData


static func restore(session: SkillTreeEditSession, metadata: Dictionary) -> Dictionary:
	if session == null:
		return {"ok": false, "error": "Session absente."}
	var source_path := str(metadata.get("source_path", ""))
	var draft := load_draft(metadata)
	if draft == null:
		return {"ok": false, "error": "Contenu du brouillon introuvable."}
	var restored := false
	var source: Resource = null
	if str(metadata.get("authority", "UNIT_DATA")) == "CHARACTER_PROGRESSION_PROFILE":
		source = ResourceLoader.load(
			source_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
		) as CharacterProgressionProfile
		restored = source != null and session.restore_profile_draft(
			draft,
			metadata.get("source_keys_by_work_key", {}) as Dictionary,
			metadata.get("new_paths_by_work_key", {}) as Dictionary
		)
	else:
		source = ResourceLoader.load(
			source_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
		) as UnitData
		restored = source != null and session.restore_draft(
			source as UnitData, draft,
			metadata.get("source_keys_by_work_key", {}) as Dictionary,
			metadata.get("new_paths_by_work_key", {}) as Dictionary
		)
	return {"ok": restored, "source": source, "draft": draft, "metadata": metadata}


static func abandon(metadata: Dictionary) -> bool:
	var draft_path := str(metadata.get("draft_path", ""))
	if draft_path.is_empty() or not draft_path.begins_with(DRAFT_ROOT + "/"):
		return false
	return _remove_tree(draft_path)


static func clear_for_source(source_path: String) -> bool:
	var root := DRAFT_ROOT.path_join(_source_key(source_path))
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(root)):
		return true
	return _remove_tree(root)


static func compare(metadata: Dictionary) -> Dictionary:
	var source_path := str(metadata.get("source_path", ""))
	var source := ResourceLoader.load(
		source_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as Resource
	var draft := load_draft(metadata)
	if source == null or draft == null:
		return {"ok": false, "error": "Comparaison impossible."}
	return {
		"ok": true,
		"source_path": source_path,
		"source_fingerprint": SkillTreeSnapshotService.storage_fingerprint(source),
		"opening_fingerprint": str(metadata.get("opening_fingerprint", "")),
		"draft_fingerprint": SkillTreeSnapshotService.fingerprint(draft),
		"source_changed": SkillTreeSnapshotService.storage_fingerprint(source) \
			!= str(metadata.get("source_fingerprint", "")),
	}


static func _source_key(source_path: String) -> String:
	return source_path.sha256_text().substr(0, 24)


static func _write_json(path: String, value: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(value, "  "))
	file.flush()
	return file.get_error() == OK


static func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed as Dictionary if parsed is Dictionary else {}


static func _remove_tree(path: String) -> bool:
	var absolute := ProjectSettings.globalize_path(path)
	var directory := DirAccess.open(absolute)
	if directory == null:
		return not DirAccess.dir_exists_absolute(absolute)
	for file_name in directory.get_files():
		if DirAccess.remove_absolute(absolute.path_join(file_name)) != OK:
			return false
	for directory_name in directory.get_directories():
		if not _remove_tree(path.path_join(directory_name)):
			return false
	return DirAccess.remove_absolute(absolute) == OK
