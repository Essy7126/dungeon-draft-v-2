@tool
class_name SkillTreeSaveService
extends RefCounted

const RECOVERY_ROOT := "user://dungeon_draft_studio/skill_tree/recovery"


static func save(
		session: SkillTreeEditSession,
		editor_interface = null,
		options: Dictionary = {}
	) -> Dictionary:
	return SkillTreeSaveTransactionService.save(
		session, editor_interface, options
	)


static func _save_plan(session: SkillTreeEditSession) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in SkillTreeSaveTransactionService.build_plan(session).writable_entries():
		result.append(entry.to_dictionary())
	return result


static func _external_conflicts(
		session: SkillTreeEditSession,
		plan: Array[Dictionary]
	) -> PackedStringArray:
	var conflicts := PackedStringArray()
	for entry in plan:
		var source := entry.get("source") as Resource
		var path := str(entry.get("path", ""))
		if source == null or not ResourceLoader.exists(path):
			continue
		var disk := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as Resource
		if disk == null or SkillTreeSnapshotService.storage_fingerprint(disk) \
				!= SkillTreeSnapshotService.storage_fingerprint(source):
			conflicts.append(path)
	return conflicts


static func _new_recovery_directory() -> String:
	var stamp := "%d_%d" % [
		int(Time.get_unix_time_from_system() * 1000000.0),
		Time.get_ticks_usec(),
	]
	var path := RECOVERY_ROOT.path_join("save_" + stamp)
	var error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))
	return path if error == OK else ""


static func _backup_existing_files(
		plan: Array[Dictionary],
		recovery_dir: String
	) -> Dictionary:
	var backups: Array[Dictionary] = []
	for index in range(plan.size()):
		var path := str(plan[index].get("path", ""))
		if not FileAccess.file_exists(path):
			continue
		var backup_path := recovery_dir.path_join(
			"%03d_%s.bak" % [index, path.get_file()]
		)
		var error := DirAccess.copy_absolute(
			ProjectSettings.globalize_path(path),
			ProjectSettings.globalize_path(backup_path)
		)
		if error != OK:
			return {
				"ok": false,
				"error": "Impossible de sauvegarder le fichier avant modification.",
				"path": path,
				"code": error,
			}
		backups.append({"source": path, "backup": backup_path})
	return {"ok": true, "backups": backups}


static func _restore(
		backup_report: Dictionary,
		created_paths: PackedStringArray
	) -> void:
	for backup_value in backup_report.get("backups", []):
		var backup := backup_value as Dictionary
		DirAccess.copy_absolute(
			ProjectSettings.globalize_path(str(backup.get("backup", ""))),
			ProjectSettings.globalize_path(str(backup.get("source", "")))
		)
	for path in created_paths:
		var absolute := ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(absolute):
			DirAccess.remove_absolute(absolute)


static func _write_manifest(
		recovery_dir: String,
		session: SkillTreeEditSession,
		saved_paths: PackedStringArray,
		backup_report: Dictionary
	) -> void:
	var manifest := {
		"character_path": session.canonical_source_path(),
		"saved_paths": saved_paths,
		"backups": backup_report.get("backups", []),
		"created_at": Time.get_datetime_string_from_system(),
	}
	var file := FileAccess.open(recovery_dir.path_join("manifest.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(manifest, "  "))


static func _recovery_copy(unit: UnitData) -> UnitData:
	var copied := SkillTreeCopyService.copy_unit(unit)
	var result := copied.get("work") as UnitData
	_clear_editable_paths(result, {})
	return result


static func _clear_editable_paths(resource: Resource, visited: Dictionary) -> void:
	if resource == null or visited.has(resource.get_instance_id()):
		return
	visited[resource.get_instance_id()] = true
	resource.set_path_cache("")
	if resource is UnitData:
		_clear_editable_paths(resource.animation_set, visited)
		for spell in resource.spells:
			_clear_editable_paths(spell, visited)
		for discipline in resource.disciplines:
			_clear_editable_paths(discipline, visited)
	elif resource is DisciplineData:
		for rank_data in resource.ranks:
			_clear_editable_paths(rank_data, visited)
	elif resource is DisciplineRankData:
		for node in resource.choices:
			_clear_editable_paths(node, visited)
	elif resource is SkillUpgradeData:
		for modifier in resource.spell_modifiers:
			_clear_editable_paths(modifier, visited)
	elif resource is Spell:
		for modifier in resource.modifiers:
			_clear_editable_paths(modifier, visited)


static func _priority(resource: Resource) -> int:
	if resource is SpellModifier:
		return 10
	if resource is SkillUpgradeData:
		return 20
	if resource is DisciplineRankData:
		return 30
	if resource is Spell:
		return 40
	if resource is DisciplineData:
		return 50
	# La fiche d'animations s'ecrit avant l'UnitData qui la reference.
	if resource is CharacterAnimationSetData:
		return 55
	if resource is CharacterProgressionProfile:
		return 60
	if resource is UnitData:
		return 60
	return 35


static func _is_reachable(root: Resource, searched: Resource) -> bool:
	if root == null or searched == null:
		return false
	if root == searched:
		return true
	if root is UnitData:
		if root.animation_set != null and _is_reachable(root.animation_set, searched):
			return true
		for spell in root.spells:
			if _is_reachable(spell, searched):
				return true
		for discipline in root.disciplines:
			if _is_reachable(discipline, searched):
				return true
	elif root is DisciplineData:
		for rank_data in root.ranks:
			if _is_reachable(rank_data, searched):
				return true
	elif root is DisciplineRankData:
		for node in root.choices:
			if _is_reachable(node, searched):
				return true
	elif root is SkillUpgradeData:
		for modifier in root.spell_modifiers:
			if _is_reachable(modifier, searched):
				return true
	elif root is Spell:
		for modifier in root.modifiers:
			if _is_reachable(modifier, searched):
				return true
	return false


static func _safe_path(path: String) -> bool:
	return path.begins_with("res://data/") \
		and path.get_extension().to_lower() in ["tres", "res"] \
		and not path.contains("..")
