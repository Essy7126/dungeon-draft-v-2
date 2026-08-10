@tool
class_name ArenaProductionAttachmentService
extends RefCounted

const RECOVERY_ROOT := "user://dungeon_draft_studio/room_integration/recovery"

const NONE := &"NONE"
const APPEND := &"APPEND"
const INSERT_BEFORE := &"INSERT_BEFORE"
const INSERT_AFTER := &"INSERT_AFTER"
const REPLACE := &"REPLACE"
const UPDATE := &"UPDATE"
const ACTIONS: Array[StringName] = [
	NONE, APPEND, INSERT_BEFORE, INSERT_AFTER, REPLACE, UPDATE,
]


static func plan(
		run_data: RunData,
		action: StringName,
		requested_index: int,
		arena_path := "",
		graph: StudioReferenceGraphService = null
	) -> Dictionary:
	if action not in ACTIONS:
		return {"ok": false, "error": "Action de rattachement inconnue."}
	if action == NONE:
		return {
			"ok": true, "action": NONE, "run_path": "", "target_index": -1,
			"before_count": run_data.rooms.size() if run_data != null else 0,
			"after_count": run_data.rooms.size() if run_data != null else 0,
		}
	if run_data == null or run_data.resource_path.is_empty():
		return {"ok": false, "error": "La run cible n'est pas canonique."}
	var before_count := run_data.rooms.size()
	var target := requested_index
	match action:
		APPEND:
			target = before_count
		INSERT_BEFORE:
			target = clampi(requested_index, 0, before_count)
		INSERT_AFTER:
			target = clampi(requested_index + 1, 0, before_count)
		REPLACE, UPDATE:
			if requested_index < 0 or requested_index >= before_count:
				return {"ok": false, "error": "L'index a remplacer est hors limites."}
	var target_room := run_data.rooms[target] as RoomData \
		if target >= 0 and target < before_count else null
	var shared := action == UPDATE and _is_shared_room(target_room, graph)
	var integrated_room_path := arena_path
	if action == UPDATE:
		if target_room == null or target_room.resource_path.is_empty():
			return {"ok": false, "error": "La salle cible n'est pas canonique."}
		integrated_room_path = _run_specific_update_path(arena_path, run_data) \
			if shared else target_room.resource_path
		if shared and integrated_room_path.is_empty():
			return {
				"ok": false,
				"error": "La copie spécifique à la run n'a pas de chemin sûr.",
			}
		if shared and ResourceLoader.exists(integrated_room_path) \
				and integrated_room_path != target_room.resource_path:
			return {
				"ok": false,
				"error": "Le chemin de copie spécifique existe déjà : %s" % integrated_room_path,
			}
	var after_count := before_count if action in [REPLACE, UPDATE] else before_count + 1
	var affected_files := PackedStringArray()
	if action == UPDATE:
		affected_files.append(integrated_room_path)
		if shared:
			affected_files.append(run_data.resource_path)
	elif action != NONE:
		affected_files.append(run_data.resource_path)
	return {
		"ok": true,
		"action": action,
		"run_path": run_data.resource_path,
		"arena_path": arena_path,
		"requested_index": requested_index,
		"target_index": target,
		"before_count": before_count,
		"after_count": after_count,
		"integrated_room_path": integrated_room_path,
		"shared": shared,
		"copy_on_write": shared,
		"run_will_change": action != UPDATE or shared,
		"preserves_gameplay": action == UPDATE,
		"affected_files": affected_files,
		"replaced_path": run_data.rooms[target].resource_path \
			if action in [REPLACE, UPDATE] and target < before_count else "",
	}


static func attach_and_save(
		arena_path: String,
		run_data: RunData,
		action: StringName,
		requested_index: int,
		graph: StudioReferenceGraphService = null
	) -> Dictionary:
	var attachment_plan := plan(run_data, action, requested_index, arena_path, graph)
	if not attachment_plan.get("ok", false) or action == NONE:
		return attachment_plan.merged({"saved": action == NONE}, true)
	var produced := ResourceLoader.load(
		arena_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as ArenaDefinition
	if produced == null:
		return {"ok": false, "error": "L'ArenaDefinition produite ne peut pas etre relue.", "plan": attachment_plan}
	var canonical_run := ResourceLoader.load(
		run_data.resource_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as RunData
	if canonical_run == null:
		return {"ok": false, "error": "La RunData cible ne peut pas etre relue.", "plan": attachment_plan}
	if action == UPDATE:
		return _update_and_save(produced, canonical_run, attachment_plan, graph)
	var session := ArenaRunAuthoringService.new()
	if not session.open(canonical_run, graph):
		return {"ok": false, "error": "La session de run ne peut pas etre ouverte.", "plan": attachment_plan}
	var target := int(attachment_plan.target_index)
	var operation := session.replace_room(target, produced) \
		if action == REPLACE else session.insert_room(target, produced)
	if not operation.get("ok", false):
		return operation.merged({"plan": attachment_plan}, true)
	var save_result := session.save()
	if not save_result.get("ok", false):
		session.undo()
		return {
			"ok": false,
			"error": str(save_result.get("error", "Le rattachement n'a pas pu etre sauvegarde.")),
			"plan": attachment_plan,
			"operation": operation,
		}
	var verified_run := ResourceLoader.load(
		run_data.resource_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as RunData
	if verified_run == null or target < 0 or target >= verified_run.rooms.size() \
			or verified_run.rooms[target].resource_path != arena_path:
		_rollback_run(save_result, run_data.resource_path)
		return {
			"ok": false,
			"error": "La verification du rattachement a l'index exact a echoue.",
			"plan": attachment_plan,
		}
	var run_errors := verified_run.validation_errors()
	if not run_errors.is_empty():
		_rollback_run(save_result, run_data.resource_path)
		return {
			"ok": false,
			"error": "L'intégration rendrait la run invalide.",
			"validation_errors": run_errors,
			"plan": attachment_plan,
		}
	return {
		"ok": true,
		"saved": true,
		"run_path": verified_run.resource_path,
		"arena_path": arena_path,
		"target_index": target,
		"before_count": int(attachment_plan.before_count),
		"after_count": verified_run.rooms.size(),
		"action": action,
		"backup_path": save_result.get("backup_path", ""),
		"reloaded_run": verified_run,
		"reloaded_room": verified_run.rooms[target],
		"integrated_room_path": arena_path,
		"run_saved": true,
		"preserved_gameplay": false,
	}


static func rollback_attachment(attachment: Dictionary) -> Dictionary:
	if not attachment.get("ok", false):
		return {"ok": false, "error": "attachment_not_committed"}
	var run_path := str(attachment.get("run_path", ""))
	var backup_path := str(attachment.get("backup_path", ""))
	if not backup_path.is_empty() and FileAccess.file_exists(backup_path):
		if DirAccess.copy_absolute(
				ProjectSettings.globalize_path(backup_path),
				ProjectSettings.globalize_path(run_path)
			) != OK:
			return {"ok": false, "error": "run_rollback_failed"}
	var room_recovery = attachment.get("room_recovery", {})
	if room_recovery is Dictionary and not room_recovery.is_empty():
		_rollback_room(
			room_recovery, str(attachment.get("integrated_room_path", ""))
		)
	var reloaded_run := ResourceLoader.load(
		run_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as RunData if not run_path.is_empty() else null
	if not run_path.is_empty() and reloaded_run == null:
		return {"ok": false, "error": "run_rollback_reload_failed"}
	return {"ok": true, "reloaded_run": reloaded_run}


static func _update_and_save(
		produced: ArenaDefinition,
		canonical_run: RunData,
		attachment_plan: Dictionary,
		graph: StudioReferenceGraphService
	) -> Dictionary:
	var target := int(attachment_plan.get("target_index", -1))
	if target < 0 or target >= canonical_run.rooms.size():
		return {"ok": false, "error": "L'index de mise à jour est hors limites."}
	var target_room := canonical_run.rooms[target] as RoomData
	var policy_coverage := RoomIntegrationFieldPolicy.coverage_report(produced)
	var target_coverage := RoomIntegrationFieldPolicy.coverage_report(target_room)
	if not policy_coverage.get("ok", false) or not target_coverage.get("ok", false):
		return {
			"ok": false,
			"error": "Une propriété de salle n'a pas de politique d'intégration.",
			"source_unknown": policy_coverage.get("unknown", []),
			"target_unknown": target_coverage.get("unknown", []),
			"plan": attachment_plan,
		}
	var gameplay_before := RoomIntegrationFieldPolicy.signature(
		target_room, RoomIntegrationFieldPolicy.GAMEPLAY_OWNED
	)
	var identity_before := RoomIntegrationFieldPolicy.signature(
		target_room, RoomIntegrationFieldPolicy.IDENTITY_OWNED
	)
	var merged := RoomIntegrationFieldPolicy.merge_arena_into_room(produced, target_room)
	if merged == null:
		return {"ok": false, "error": "La fusion Arena/Gameplay a échoué.", "plan": attachment_plan}
	var integrated_path := str(attachment_plan.get("integrated_room_path", ""))
	if integrated_path.is_empty() or not integrated_path.begins_with("res://data/") \
			and not integrated_path.begins_with("res://artifacts/"):
		return {"ok": false, "error": "Le chemin intégré est hors périmètre sûr."}
	var recovery := _create_room_recovery(integrated_path, canonical_run.resource_path)
	if not recovery.get("ok", false):
		return recovery.merged({"plan": attachment_plan}, true)
	var staging_path := str(recovery.get("directory", "")).path_join("staged_room.tres")
	if ResourceSaver.save(merged, staging_path) != OK:
		return {"ok": false, "error": "Le staging de la salle fusionnée a échoué.", "plan": attachment_plan}
	var staged := ResourceLoader.load(
		staging_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as ArenaDefinition
	var staged_gameplay := RoomIntegrationFieldPolicy.signature(
		staged, RoomIntegrationFieldPolicy.GAMEPLAY_OWNED
	) if staged != null else {}
	if staged == null or staged_gameplay != gameplay_before:
		return {
			"ok": false,
			"error": "Le staging ne préserve pas le gameplay.",
			"gameplay_before": gameplay_before,
			"gameplay_after": staged_gameplay,
			"plan": attachment_plan,
		}
	if DirAccess.make_dir_recursive_absolute(
			ProjectSettings.globalize_path(integrated_path.get_base_dir())
		) != OK or ResourceSaver.save(merged, integrated_path) != OK:
		_rollback_room(recovery, integrated_path)
		return {"ok": false, "error": "L'écriture de la salle intégrée a échoué.", "plan": attachment_plan}
	var integrated := ResourceLoader.load(
		integrated_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as ArenaDefinition
	var identity_after := RoomIntegrationFieldPolicy.signature(
		integrated, RoomIntegrationFieldPolicy.IDENTITY_OWNED
	) if integrated != null else {}
	if integrated == null \
			or RoomIntegrationFieldPolicy.signature(
				integrated, RoomIntegrationFieldPolicy.GAMEPLAY_OWNED
			) != gameplay_before \
			or not RoomIntegrationFieldPolicy.preserves_signature(
				identity_before, identity_after
			):
		_rollback_room(recovery, integrated_path)
		return {"ok": false, "error": "La vérification Arena/Gameplay a échoué.", "plan": attachment_plan}
	var save_result := {"ok": true, "backup_path": "", "saved_paths": []}
	if bool(attachment_plan.get("copy_on_write", false)):
		var session := ArenaRunAuthoringService.new()
		if not session.open(canonical_run, graph):
			_rollback_room(recovery, integrated_path)
			return {"ok": false, "error": "La session de run ne peut pas être ouverte."}
		var operation := session.replace_room(target, integrated)
		if not operation.get("ok", false):
			_rollback_room(recovery, integrated_path)
			return operation.merged({"plan": attachment_plan}, true)
		save_result = session.save()
		if not save_result.get("ok", false):
			_rollback_room(recovery, integrated_path)
			return save_result.merged({"plan": attachment_plan}, true)
	var verified_run := ResourceLoader.load(
		canonical_run.resource_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as RunData
	if verified_run == null or target >= verified_run.rooms.size() \
			or verified_run.rooms[target].resource_path != integrated_path:
		_rollback_run(save_result, canonical_run.resource_path)
		_rollback_room(recovery, integrated_path)
		return {"ok": false, "error": "La salle mise à jour n'est pas à l'index attendu."}
	var verified_room := verified_run.rooms[target]
	if RoomIntegrationFieldPolicy.signature(
			verified_room, RoomIntegrationFieldPolicy.GAMEPLAY_OWNED
		) != gameplay_before or not verified_run.validation_errors().is_empty():
		_rollback_run(save_result, canonical_run.resource_path)
		_rollback_room(recovery, integrated_path)
		return {
			"ok": false,
			"error": "Les invariants gameplay de la run ne sont pas préservés.",
		}
	if graph != null:
		graph.invalidate(canonical_run.resource_path)
		graph.invalidate(integrated_path)
		graph.scan(true)
	return {
		"ok": true,
		"saved": true,
		"run_path": verified_run.resource_path,
		"arena_path": produced.resource_path,
		"integrated_room_path": integrated_path,
		"target_index": target,
		"before_count": int(attachment_plan.get("before_count", 0)),
		"after_count": verified_run.rooms.size(),
		"action": UPDATE,
		"backup_path": save_result.get("backup_path", ""),
		"room_recovery_path": recovery.get("directory", ""),
		"room_recovery": recovery,
		"reloaded_run": verified_run,
		"reloaded_room": verified_room,
		"run_saved": bool(attachment_plan.get("copy_on_write", false)),
		"preserved_gameplay": true,
		"copy_on_write": bool(attachment_plan.get("copy_on_write", false)),
	}


static func _create_room_recovery(room_path: String, run_path: String) -> Dictionary:
	var directory := RECOVERY_ROOT.path_join(
		"integration_%d_%d" % [
			int(Time.get_unix_time_from_system() * 1000000.0), Time.get_ticks_usec(),
		]
	)
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory)) != OK:
		return {"ok": false, "error": "Le recovery d'intégration ne peut pas être créé."}
	var result := {
		"ok": true,
		"directory": directory,
		"room_existed": FileAccess.file_exists(room_path),
		"room_backup": "",
		"run_path": run_path,
	}
	if bool(result.room_existed):
		var backup := directory.path_join("room_before.tres")
		if DirAccess.copy_absolute(
				ProjectSettings.globalize_path(room_path), ProjectSettings.globalize_path(backup)
			) != OK:
			return {"ok": false, "error": "La salle cible ne peut pas être sauvegardée avant écriture."}
		result["room_backup"] = backup
	return result


static func _rollback_room(recovery: Dictionary, room_path: String) -> void:
	var backup := str(recovery.get("room_backup", ""))
	if not backup.is_empty() and FileAccess.file_exists(backup):
		DirAccess.copy_absolute(
			ProjectSettings.globalize_path(backup), ProjectSettings.globalize_path(room_path)
		)
	elif not bool(recovery.get("room_existed", false)) and FileAccess.file_exists(room_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(room_path))


static func _rollback_run(save_result: Dictionary, run_path: String) -> void:
	var backup := str(save_result.get("backup_path", ""))
	if not backup.is_empty() and FileAccess.file_exists(backup):
		DirAccess.copy_absolute(
			ProjectSettings.globalize_path(backup), ProjectSettings.globalize_path(run_path)
		)


static func _is_shared_room(
		room: RoomData,
		graph: StudioReferenceGraphService
	) -> bool:
	if room == null or room.resource_path.is_empty():
		return false
	if graph != null and graph.is_shared(room):
		return true
	var usages := 0
	for run_data in RunContentCatalogService.discover_runs():
		for candidate in run_data.rooms:
			if candidate != null and candidate.resource_path == room.resource_path:
				usages += 1
				if usages > 1:
					return true
	return false


static func _run_specific_update_path(arena_path: String, run_data: RunData) -> String:
	if arena_path.is_empty() or run_data == null:
		return ""
	var run_id := ArenaDefinition.sanitize_id(run_data.run_name)
	return arena_path.get_base_dir().path_join("arena_%s.tres" % run_id)
