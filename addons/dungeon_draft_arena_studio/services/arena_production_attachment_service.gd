@tool
class_name ArenaProductionAttachmentService
extends RefCounted

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
		arena_path := ""
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
	var after_count := before_count if action in [REPLACE, UPDATE] else before_count + 1
	return {
		"ok": true,
		"action": action,
		"run_path": run_data.resource_path,
		"arena_path": arena_path,
		"requested_index": requested_index,
		"target_index": target,
		"before_count": before_count,
		"after_count": after_count,
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
	var attachment_plan := plan(run_data, action, requested_index, arena_path)
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
	var session := ArenaRunAuthoringService.new()
	if not session.open(canonical_run, graph):
		return {"ok": false, "error": "La session de run ne peut pas etre ouverte.", "plan": attachment_plan}
	var target := int(attachment_plan.target_index)
	var operation := session.replace_room(target, produced) \
		if action in [REPLACE, UPDATE] else session.insert_room(target, produced)
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
		return {
			"ok": false,
			"error": "La verification du rattachement a l'index exact a echoue.",
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
	}
