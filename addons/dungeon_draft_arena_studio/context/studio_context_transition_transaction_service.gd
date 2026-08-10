@tool
class_name StudioContextTransitionTransactionService
extends RefCounted

## Transaction déterministe multi-domaines. Tous les plans sont préparés puis
## stagés avant le premier commit. Les chemins sources annoncés dans les
## métadonnées dirty sont sauvegardés en mémoire et restaurés sur échec.


static func execute(
		action: StringName,
		dirty_domains: Dictionary,
		handlers_by_domain: Dictionary
	) -> Dictionary:
	var domains := PackedStringArray()
	for domain_value in dirty_domains.keys():
		domains.append(str(domain_value))
	domains.sort()
	var plans: Array[Dictionary] = []
	for domain_text in domains:
		var domain := StringName(domain_text)
		var handlers := handlers_by_domain.get(domain, {}) as Dictionary
		var commit_handler := _action_handler(handlers, action)
		if not commit_handler.is_valid():
			return _failure(&"PREPARE", domain, "Le domaine ne possède aucun handler pour %s." % action)
		var metadata := (dirty_domains.get(domain, {}) as Dictionary).duplicate(true)
		var plan := {
			"domain": domain,
			"metadata": metadata,
			"commit": commit_handler,
			"prepare": handlers.get("prepare", Callable()) as Callable,
			"stage": handlers.get("stage", Callable()) as Callable,
			"rollback": handlers.get("rollback", Callable()) as Callable,
			"backups": _capture_backups(metadata),
		}
		var prepared := _call_phase(plan.prepare, action, metadata, plan)
		if not _outcome_ok(prepared):
			return _failure(&"PREPARE", domain, _outcome_error(prepared), plans)
		if prepared is Dictionary:
			plan["prepared"] = (prepared as Dictionary).duplicate(true)
		plans.append(plan)
	var staged: Array[Dictionary] = []
	for plan in plans:
		var outcome := _call_phase(plan.stage, action, plan.metadata, plan)
		if not _outcome_ok(outcome):
			_rollback(staged, action)
			return _failure(&"STAGE", plan.domain, _outcome_error(outcome), plans)
		plan["staged"] = outcome
		staged.append(plan)
	var committed: Array[Dictionary] = []
	for plan in plans:
		var outcome = (plan.commit as Callable).call()
		if not _outcome_ok(outcome):
			_rollback(staged, action)
			return _failure(&"COMMIT", plan.domain, _outcome_error(outcome), plans, committed)
		plan["committed"] = outcome
		committed.append(plan)
	return {
		"ok": true,
		"status": &"COMMITTED",
		"action": action,
		"domain_order": domains,
		"prepared_count": plans.size(),
		"staged_count": staged.size(),
		"committed_count": committed.size(),
		"rolled_back": false,
	}


static func _action_handler(handlers: Dictionary, action: StringName) -> Callable:
	var key := {
		StudioProjectContext.ACTION_SAVE: "save",
		StudioProjectContext.ACTION_DRAFT: "draft",
		StudioProjectContext.ACTION_DISCARD: "discard",
	}.get(action, "")
	return handlers.get(key, Callable()) as Callable


static func _call_phase(
		callable: Callable,
		action: StringName,
		metadata: Dictionary,
		plan: Dictionary
	) -> Variant:
	if not callable.is_valid():
		return {"ok": true, "skipped": true}
	var argument_count := callable.get_argument_count()
	if argument_count >= 3:
		return callable.call(action, metadata, plan)
	if argument_count == 2:
		return callable.call(action, metadata)
	if argument_count == 1:
		return callable.call(action)
	return callable.call()


static func _outcome_ok(outcome: Variant) -> bool:
	if outcome is bool:
		return bool(outcome)
	if outcome is Dictionary:
		return bool((outcome as Dictionary).get("ok", false))
	return outcome == null


static func _outcome_error(outcome: Variant) -> String:
	if outcome is Dictionary:
		return str((outcome as Dictionary).get("error", "Opération refusée."))
	return "Opération refusée."


static func _capture_backups(metadata: Dictionary) -> Array[Dictionary]:
	var paths := PackedStringArray()
	_collect_paths(metadata, paths)
	var backups: Array[Dictionary] = []
	for path in paths:
		var exists := FileAccess.file_exists(path)
		backups.append({
			"path": path,
			"existed": exists,
			"bytes": FileAccess.get_file_as_bytes(path) if exists else PackedByteArray(),
		})
	return backups


static func _collect_paths(value: Variant, paths: PackedStringArray) -> void:
	if value is String or value is StringName:
		var text := str(value)
		if (text.begins_with("res://") or text.begins_with("user://")) \
				and not paths.has(text):
			paths.append(text)
	elif value is Dictionary:
		for child in (value as Dictionary).values():
			_collect_paths(child, paths)
	elif value is Array:
		for child in value as Array:
			_collect_paths(child, paths)


static func _rollback(plans: Array[Dictionary], action: StringName) -> void:
	var reversed := plans.duplicate()
	reversed.reverse()
	for plan in reversed:
		_call_phase(plan.rollback, action, plan.metadata, plan)
		_restore_backups(plan.get("backups", []) as Array)


static func _restore_backups(backups: Array) -> void:
	for backup_value in backups:
		var backup := backup_value as Dictionary
		var path := str(backup.get("path", ""))
		if path.is_empty():
			continue
		if bool(backup.get("existed", false)):
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
			var file := FileAccess.open(path, FileAccess.WRITE)
			if file != null:
				file.store_buffer(backup.get("bytes", PackedByteArray()) as PackedByteArray)
				file.close()
		elif FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


static func _failure(
		phase: StringName,
		domain: StringName,
		error: String,
		plans: Array[Dictionary] = [],
		committed: Array[Dictionary] = []
	) -> Dictionary:
	return {
		"ok": false,
		"status": &"TRANSACTION_FAILED",
		"phase": phase,
		"domain": domain,
		"error": error,
		"prepared_count": plans.size(),
		"committed_count": committed.size(),
		"rolled_back": phase in [&"STAGE", &"COMMIT"],
	}
