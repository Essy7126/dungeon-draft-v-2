@tool
class_name SkillTreeSaveService
extends RefCounted

const RECOVERY_ROOT := "user://dungeon_draft_studio/skill_tree/recovery"


static func save(
		session: SkillTreeEditSession,
		editor_interface = null
	) -> Dictionary:
	if session == null or session.working_unit == null:
		return {"ok": false, "error": "Aucun personnage n’est ouvert."}
	if not session.is_dirty():
		return {"ok": true, "saved_paths": [], "message": "Aucun changement à sauvegarder."}
	var validation := SkillTreeEditorValidator.validate_unit(
		session.working_unit,
		false,
		SkillTreeCatalogService.discover_heroes()
	)
	if SkillTreeEditorValidator.has_errors(validation):
		return {
			"ok": false,
			"error": "L’arbre contient des erreurs bloquantes.",
			"validation": validation,
		}
	var plan := _save_plan(session)
	if plan.is_empty():
		session.mark_saved()
		return {"ok": true, "saved_paths": [], "message": "Aucun fichier logique n’a changé."}
	var conflicts := _external_conflicts(session, plan)
	if not conflicts.is_empty():
		return {
			"ok": false,
			"error": "Un fichier a été modifié en dehors du Skill Studio.",
			"conflicts": conflicts,
		}
	var recovery_dir := _new_recovery_directory()
	if recovery_dir.is_empty():
		return {"ok": false, "error": "Impossible de créer le point de récupération."}
	var backup_report := _backup_existing_files(plan, recovery_dir)
	if not backup_report.get("ok", false):
		return backup_report
	var recovery_resource_path := recovery_dir.path_join("working_character.tres")
	var recovery_copy := _recovery_copy(session.working_unit)
	var recovery_error := ResourceSaver.save(recovery_copy, recovery_resource_path) \
		if recovery_copy != null else ERR_CANT_CREATE
	if recovery_error != OK:
		return {
			"ok": false,
			"error": "Impossible d’enregistrer la copie de récupération.",
			"code": recovery_error,
		}
	var saved_paths := PackedStringArray()
	var created_paths := PackedStringArray()
	for entry in plan:
		var resource := entry.get("resource") as Resource
		var path := str(entry.get("path", ""))
		if resource == null or not _safe_path(path):
			_restore(backup_report, created_paths)
			return {"ok": false, "error": "Chemin de sauvegarde non autorisé.", "path": path}
		var absolute := ProjectSettings.globalize_path(path)
		var directory_error := DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
		if directory_error != OK:
			_restore(backup_report, created_paths)
			return {"ok": false, "error": "Impossible de créer le dossier.", "path": path}
		if not FileAccess.file_exists(path):
			created_paths.append(path)
		var error := ResourceSaver.save(resource, path)
		if error != OK:
			_restore(backup_report, created_paths)
			return {
				"ok": false,
				"error": "Échec de la sauvegarde d’une Resource.",
				"path": path,
				"code": error,
			}
		var reloaded := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if reloaded == null:
			_restore(backup_report, created_paths)
			return {
				"ok": false,
				"error": "La Resource sauvegardée ne peut pas être relue.",
				"path": path,
			}
		saved_paths.append(path)
	_write_manifest(recovery_dir, session, saved_paths, backup_report)
	if editor_interface != null:
		var filesystem = editor_interface.get_resource_filesystem()
		if filesystem != null:
			filesystem.scan_changes()
	if not session.reopen_from_disk():
		session.mark_saved()
	return {
		"ok": true,
		"saved_paths": saved_paths,
		"recovery_path": recovery_dir,
		"message": "%d fichier(s) sauvegardé(s)." % saved_paths.size(),
	}


static func _save_plan(session: SkillTreeEditSession) -> Array[Dictionary]:
	var plan: Array[Dictionary] = []
	for source_value in session.source_to_work:
		var source := source_value as Resource
		var work := session.source_to_work[source_value] as Resource
		if source == null or work == null or source.resource_path.is_empty() \
				or source.is_built_in():
			continue
		if SkillTreeSnapshotService.storage_fingerprint(source) \
				== SkillTreeSnapshotService.storage_fingerprint(work):
			continue
		plan.append({
			"resource": work,
			"source": source,
			"path": source.resource_path,
			"priority": _priority(work),
		})
	for resource_value in session.new_resource_paths:
		var resource := resource_value as Resource
		var path := str(session.new_resource_paths[resource_value])
		if resource == null or path.is_empty() \
				or not _is_reachable(session.working_unit, resource):
			continue
		if plan.any(func(entry: Dictionary) -> bool:
			return entry.get("resource") == resource
		):
			continue
		plan.append({
			"resource": resource,
			"source": null,
			"path": path,
			"priority": _priority(resource),
		})
	plan.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var priority_a := int(a.get("priority", 0))
		var priority_b := int(b.get("priority", 0))
		if priority_a == priority_b:
			return str(a.get("path", "")) < str(b.get("path", ""))
		return priority_a < priority_b
	)
	return plan


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
		"character_path": session.source_unit.resource_path,
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
	if resource is UnitData:
		return 60
	return 35


static func _is_reachable(root: Resource, searched: Resource) -> bool:
	if root == null or searched == null:
		return false
	if root == searched:
		return true
	if root is UnitData:
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
