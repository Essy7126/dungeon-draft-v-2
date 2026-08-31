@tool
class_name StudioContextTransitionTransactionService
extends RefCounted

## Transaction déterministe multi-domaines. Tous les plans sont préparés puis
## stagés avant le premier commit. Les chemins sources annoncés dans les
## métadonnées dirty sont sauvegardés durablement. Un rollback ne remplace un
## fichier que si son empreinte correspond encore à celle écrite par le Studio.

const TRANSACTION_ROOT := "user://dungeon_draft_studio/context_transition_transactions"


static func execute(
		action: StringName,
		dirty_domains: Dictionary,
		handlers_by_domain: Dictionary,
		options := {}
	) -> Dictionary:
	var transaction := _begin_transaction(str(options.get("transaction_root", TRANSACTION_ROOT)))
	if not transaction.get("ok", false):
		return _failure(&"PREPARE", &"", str(transaction.get(
			"error", "La sauvegarde durable de la transaction a échoué."
		)), [], [], {}, transaction)
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
			_cleanup_transaction(transaction)
			return _failure(&"PREPARE", domain,
				"Le domaine ne possède aucun handler pour %s." % action,
				[], [], {}, transaction)
		var metadata := (dirty_domains.get(domain, {}) as Dictionary).duplicate(true)
		var captured := _capture_backups(metadata, transaction, domain)
		if not captured.get("ok", false):
			_cleanup_transaction(transaction)
			return _failure(&"PREPARE", domain, str(captured.get(
				"error", "La sauvegarde originale a échoué."
			)), plans, [], {}, transaction)
		var plan := {
			"domain": domain,
			"metadata": metadata,
			"commit": commit_handler,
			"prepare": handlers.get("prepare", Callable()) as Callable,
			"stage": handlers.get("stage", Callable()) as Callable,
			"rollback": handlers.get("rollback", Callable()) as Callable,
			"snapshot_handler": handlers.get("snapshot", Callable()) as Callable,
			"restore_handler": handlers.get("restore", Callable()) as Callable,
			"backups": captured.get("entries", []),
		}
		var transaction_backups := transaction.get("backups", []) as Array
		transaction_backups.append_array(plan.get("backups", []) as Array)
		if not _update_manifest(transaction, &"PREPARING"):
			_cleanup_transaction(transaction)
			return _failure(&"PREPARE", domain,
				"Le manifeste des sauvegardes originales n'a pas pu être vérifié.",
				plans, [], {}, transaction)
		plans.append(plan)
	for plan in plans:
		plan["domain_snapshot"] = _call_snapshot(plan.snapshot_handler)
	var prepared_plans: Array[Dictionary] = []
	for plan in plans:
		var prepared := _call_phase(plan.prepare, action, plan.metadata, plan)
		if not _outcome_ok(prepared):
			_cleanup_transaction(transaction)
			return _failure(&"PREPARE", plan.domain, _outcome_error(prepared),
				prepared_plans, [], {}, transaction)
		if prepared is Dictionary:
			plan["prepared"] = (prepared as Dictionary).duplicate(true)
		prepared_plans.append(plan)
	var staged: Array[Dictionary] = []
	for plan in plans:
		var outcome := _call_phase(plan.stage, action, plan.metadata, plan)
		if not _outcome_ok(outcome):
			var rollback_plans := staged.duplicate()
			rollback_plans.append(plan)
			var rollback := _rollback(rollback_plans, action, transaction)
			_finalize_failed_transaction(transaction, rollback)
			return _failure(&"STAGE", plan.domain, _outcome_error(outcome),
				plans, [], rollback, transaction)
		plan["staged"] = outcome
		staged.append(plan)
	var committed: Array[Dictionary] = []
	for plan in plans:
		var precondition := _verify_commit_preconditions(
			plan.get("backups", []) as Array, committed
		)
		if not precondition.get("ok", false):
			var rollback := _rollback(staged, action, transaction)
			_finalize_failed_transaction(transaction, rollback)
			return _failure(&"COMMIT", plan.domain,
				"Un fichier déclaré a changé avant le commit : %s" % precondition.get("path", ""),
				plans, committed, rollback, transaction)
		var outcome = (plan.commit as Callable).call()
		plan["commit_outcome"] = outcome
		# Un handler susceptible d'échouer après une mutation doit retourner les
		# états exacts qu'il a écrits :
		# {"ok": false, "owned_file_states": {path: {"exists": true,
		# "sha256": "..."}}}. Le service n'infère jamais cette propriété sur un
		# échec : une écriture non revendiquée reste donc une écriture tierce.
		var ownership := _apply_owned_state_contract(
			plan.get("backups", []) as Array, outcome
		)
		if not bool(ownership.get("ok", false)):
			var rollback := _rollback(staged, action, transaction)
			_finalize_failed_transaction(transaction, rollback)
			return _failure(&"COMMIT", plan.domain, str(ownership.get(
				"error", "Le contrat de propriété du handler est invalide."
			)), plans, committed, rollback, transaction)
		if not _outcome_ok(outcome):
			var rollback := _rollback(staged, action, transaction)
			_finalize_failed_transaction(transaction, rollback)
			return _failure(&"COMMIT", plan.domain, _outcome_error(outcome),
				plans, committed, rollback, transaction)
		plan["committed"] = outcome
		_capture_unclaimed_owned_states(plan.get("backups", []) as Array)
		committed.append(plan)
		if not _update_manifest(transaction, &"COMMITTING"):
			var rollback := _rollback(staged, action, transaction)
			_finalize_failed_transaction(transaction, rollback)
			return _failure(&"COMMIT", plan.domain,
				"L'état possédé après commit n'a pas pu être journalisé.",
				plans, committed, rollback, transaction)
	var cleaned := _cleanup_transaction(transaction)
	return {
		"ok": true,
		"status": &"COMMITTED",
		"action": action,
		"domain_order": domains,
		"prepared_count": plans.size(),
		"staged_count": staged.size(),
		"committed_count": committed.size(),
		"rolled_back": false,
		"transaction_retained": not cleaned,
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


static func _capture_backups(
		metadata: Dictionary,
		transaction: Dictionary,
		domain: StringName
	) -> Dictionary:
	var paths := PackedStringArray()
	_collect_paths(metadata, paths)
	paths.sort()
	var backups: Array[Dictionary] = []
	for path in paths:
		var original := _file_state(path)
		var backup_path := ""
		if bool(original.exists):
			backup_path = str(transaction.directory).path_join(
				"%s_%s.backup" % [str(domain).sha256_text().left(12), path.sha256_text()]
			)
			var copy_error := DirAccess.copy_absolute(
				ProjectSettings.globalize_path(path),
				ProjectSettings.globalize_path(backup_path)
			)
			if copy_error != OK or _file_state(backup_path) != original:
				return {
					"ok": false,
					"error": "Impossible de conserver la sauvegarde durable de %s." % path,
					"path": path,
					"code": copy_error,
				}
		backups.append({
			"path": path,
			"domain": domain,
			"original": original,
			"backup_path": backup_path,
			"owned": {},
		})
	return {"ok": true, "entries": backups}


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


static func _begin_transaction(root: String) -> Dictionary:
	if not root.begins_with("user://") or ".." in root or "\\" in root \
			or root.trim_prefix("user://").contains(":"):
		return {"ok": false, "error": "Racine transactionnelle non sûre."}
	var transaction_id := "%d_%d" % [
		int(Time.get_unix_time_from_system() * 1000000.0),
		Time.get_ticks_usec(),
	]
	var directory := root.path_join("transition_" + transaction_id)
	var error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	if error != OK:
		return {"ok": false, "error": "Répertoire transactionnel indisponible.", "code": error}
	var transaction := {
		"ok": true,
		"id": transaction_id,
		"directory": directory,
		"manifest_path": directory.path_join("manifest.json"),
		"status": &"PREPARING",
		"retained": false,
		"backups": [],
	}
	if not _update_manifest(transaction, &"PREPARING"):
		_remove_tree(directory)
		return {"ok": false, "error": "Manifeste transactionnel indisponible."}
	return transaction


static func _capture_unclaimed_owned_states(backups: Array) -> void:
	for backup_value in backups:
		var backup := backup_value as Dictionary
		if (backup.get("owned", {}) as Dictionary).is_empty():
			backup["owned"] = _file_state(str(backup.get("path", "")))


static func _apply_owned_state_contract(backups: Array, outcome: Variant) -> Dictionary:
	if not outcome is Dictionary:
		return {"ok": true, "claimed_count": 0}
	var outcome_dictionary := outcome as Dictionary
	if not outcome_dictionary.has("owned_file_states"):
		return {"ok": true, "claimed_count": 0}
	var claimed_value = outcome_dictionary.get("owned_file_states")
	if not claimed_value is Dictionary:
		return {"ok": false, "error": "owned_file_states doit être un Dictionary."}
	var claimed := claimed_value as Dictionary
	var backups_by_path := {}
	for backup_value in backups:
		var backup := backup_value as Dictionary
		backups_by_path[str(backup.get("path", ""))] = backup
	var normalized := {}
	for path_value in claimed:
		var path := str(path_value)
		if path.is_empty() or not backups_by_path.has(path):
			return {
				"ok": false,
				"error": "Le handler revendique un chemin non déclaré : %s." % path,
			}
		var state_value = claimed[path_value]
		if not state_value is Dictionary:
			return {
				"ok": false,
				"error": "L'état revendiqué pour %s est invalide." % path,
			}
		var state := state_value as Dictionary
		if not state.has("exists"):
			return {
				"ok": false,
				"error": "L'état revendiqué pour %s ne précise pas exists." % path,
			}
		var exists := bool(state.get("exists", false))
		var sha256 := str(state.get("sha256", ""))
		if exists and sha256.is_empty():
			return {
				"ok": false,
				"error": "L'état revendiqué pour %s ne précise pas sha256." % path,
			}
		normalized[path] = {
			"exists": exists,
			"sha256": sha256 if exists else "",
		}
	for path in normalized:
		(backups_by_path[path] as Dictionary)["owned"] = normalized[path]
	return {"ok": true, "claimed_count": normalized.size()}


static func _verify_commit_preconditions(
		backups: Array,
		committed: Array[Dictionary]
	) -> Dictionary:
	for backup_value in backups:
		var backup := backup_value as Dictionary
		var path := str(backup.get("path", ""))
		var current := _file_state(path)
		var allowed_states: Array[Dictionary] = [
			(backup.get("original", {}) as Dictionary),
		]
		for committed_plan in committed:
			for prior_value in committed_plan.get("backups", []) as Array:
				var prior := prior_value as Dictionary
				if str(prior.get("path", "")) != path:
					continue
				var owned := prior.get("owned", {}) as Dictionary
				if not owned.is_empty():
					allowed_states.append(owned)
		if not allowed_states.has(current):
			return {
				"ok": false,
				"path": path,
				"current": current,
				"allowed": allowed_states,
			}
	return {"ok": true}


static func _file_state(path: String) -> Dictionary:
	var exists := FileAccess.file_exists(path)
	return {
		"exists": exists,
		"sha256": FileAccess.get_sha256(path) if exists else "",
	}


static func _update_manifest(transaction: Dictionary, status: StringName) -> bool:
	transaction["status"] = status
	var serializable_backups: Array[Dictionary] = []
	for backup_value in transaction.get("backups", []) as Array:
		var backup := backup_value as Dictionary
		serializable_backups.append({
			"path": backup.get("path", ""),
			"domain": str(backup.get("domain", &"")),
			"original": backup.get("original", {}),
			"owned": backup.get("owned", {}),
			"backup_path": backup.get("backup_path", ""),
		})
	var file := FileAccess.open(str(transaction.manifest_path), FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify({
		"transaction_id": transaction.get("id", ""),
		"status": str(status),
		"backups": serializable_backups,
	}, "  "))
	file.flush()
	file.close()
	return true


static func _finalize_failed_transaction(
		transaction: Dictionary,
		rollback: Dictionary
	) -> void:
	if bool(rollback.get("ok", false)):
		_cleanup_transaction(transaction)
		return
	transaction["retained"] = true
	_update_manifest(transaction, StringName(rollback.get("status", &"ROLLBACK_FAILED")))


static func _cleanup_transaction(transaction: Dictionary) -> bool:
	var directory := str(transaction.get("directory", ""))
	if directory.is_empty():
		return true
	var cleaned := _remove_tree(directory)
	transaction["retained"] = not cleaned
	return cleaned


static func _remove_tree(path: String) -> bool:
	if path.is_empty() or not path.begins_with("user://") or ".." in path or "\\" in path \
			or path.trim_prefix("user://").contains(":"):
		return false
	var absolute := ProjectSettings.globalize_path(path)
	var directory := DirAccess.open(path)
	if directory == null:
		return not DirAccess.dir_exists_absolute(absolute)
	for file_name in directory.get_files():
		if DirAccess.remove_absolute(absolute.path_join(file_name)) != OK:
			return false
	for child_name in directory.get_directories():
		if not _remove_tree(path.path_join(child_name)):
			return false
	return DirAccess.remove_absolute(absolute) == OK


static func _public_transaction(transaction: Dictionary) -> Dictionary:
	if transaction.is_empty():
		return {}
	var public_backups: Array[Dictionary] = []
	for backup_value in transaction.get("backups", []) as Array:
		var backup := backup_value as Dictionary
		public_backups.append({
			"path": backup.get("path", ""),
			"domain": backup.get("domain", &""),
			"original": backup.get("original", {}),
			"owned": backup.get("owned", {}),
			"backup_path": backup.get("backup_path", ""),
		})
	return {
		"id": transaction.get("id", ""),
		"directory": transaction.get("directory", ""),
		"manifest_path": transaction.get("manifest_path", ""),
		"status": transaction.get("status", &""),
		"retained": transaction.get("retained", false),
		"backups": public_backups,
	}


static func _rollback(
		plans: Array[Dictionary],
		action: StringName,
		transaction: Dictionary
	) -> Dictionary:
	var reversed := plans.duplicate()
	reversed.reverse()
	var entries: Array[Dictionary] = []
	var ok := true
	var conflict := false
	for plan in reversed:
		# Vérifier et restaurer les cibles déclarées avant de déléguer au handler
		# de domaine. En présence d'une écriture tierce, aucun callback de rollback
		# potentiellement écrivant n'est exécuté sur ce domaine.
		var files := _restore_backups(plan.get("backups", []) as Array)
		var custom: Variant = {
			"ok": false,
			"skipped": true,
			"error": "rollback_handler_skipped_external_conflict",
		} if bool(files.get("conflict", false)) else _call_phase(
			plan.rollback, action, plan.metadata, plan
		)
		var restored := _call_restore(
			plan.get("restore_handler", Callable()) as Callable,
			plan.get("domain_snapshot"),
			StringName(plan.get("domain", &""))
		)
		var entry_ok := bool(files.get("ok", false)) and _outcome_ok(custom) \
			and _outcome_ok(restored)
		ok = ok and entry_ok
		var custom_dictionary := custom as Dictionary if custom is Dictionary else {}
		var custom_conflict := bool(custom_dictionary.get("conflict", false)) \
			or bool(custom_dictionary.get("rollback_conflict", false))
		conflict = conflict or bool(files.get("conflict", false)) or custom_conflict
		entries.append({
			"domain": plan.get("domain", &""),
			"ok": entry_ok,
			"custom": custom,
			"restore": restored,
			"files": files,
		})
	return {
		"ok": ok,
		"conflict": conflict,
		"status": &"ROLLBACK_CONFLICT" if conflict else (
			&"ROLLED_BACK" if ok else &"ROLLBACK_FAILED"
		),
		"entries": entries,
		"transaction_directory": transaction.get("directory", ""),
	}


static func _call_snapshot(callable: Callable) -> Variant:
	return callable.call() if callable.is_valid() else null


static func _call_restore(callable: Callable, snapshot: Variant, domain: StringName) -> Variant:
	if not callable.is_valid():
		return {"ok": false, "error": "restore_handler_missing"}
	if callable.get_argument_count() >= 2:
		return callable.call(snapshot, domain)
	if callable.get_argument_count() == 1:
		return callable.call(snapshot)
	return callable.call()


static func _restore_backups(backups: Array) -> Dictionary:
	var entries: Array[Dictionary] = []
	var ok := true
	var conflict := false
	for backup_value in backups:
		var backup := backup_value as Dictionary
		var path := str(backup.get("path", ""))
		if path.is_empty():
			continue
		var original := backup.get("original", {}) as Dictionary
		var owned := backup.get("owned", {}) as Dictionary
		var current := _file_state(path)
		var entry := {
			"path": path,
			"original": original,
			"owned": owned,
			"current_before": current,
			"backup_path": backup.get("backup_path", ""),
			"operation": &"NONE",
			"code": OK,
			"conflict": false,
		}
		if current == original:
			entry.operation = &"ALREADY_RESTORED"
		elif owned.is_empty() or current != owned:
			entry.operation = &"PRESERVE_EXTERNAL_CHANGE"
			entry.conflict = true
			entry.code = ERR_BUSY
			conflict = true
			ok = false
		else:
			# Dernier contrôle au bord exact de la mutation de rollback.
			var final_owned_check := _file_state(path)
			if final_owned_check != owned:
				entry.operation = &"PRESERVE_EXTERNAL_CHANGE"
				entry.conflict = true
				entry.code = ERR_BUSY
				conflict = true
				ok = false
			elif bool(original.get("exists", false)):
				var backup_path := str(backup.get("backup_path", ""))
				entry.operation = &"RESTORE_ORIGINAL"
				if backup_path.is_empty() or not FileAccess.file_exists(backup_path):
					entry.code = ERR_FILE_NOT_FOUND
				else:
					entry.code = DirAccess.copy_absolute(
						ProjectSettings.globalize_path(backup_path),
						ProjectSettings.globalize_path(path)
					)
			else:
				entry.operation = &"REMOVE_STUDIO_CREATED"
				entry.code = DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) \
					if FileAccess.file_exists(path) else OK
			entry["current_after"] = _file_state(path)
			if not bool(entry.conflict) and (
				int(entry.code) != OK or entry.current_after != original
			):
				ok = false
		entries.append(entry)
	return {"ok": ok, "conflict": conflict, "entries": entries}


static func _failure(
		phase: StringName,
		domain: StringName,
		error: String,
		plans: Array[Dictionary] = [],
		committed: Array[Dictionary] = [],
		rollback: Dictionary = {},
		transaction: Dictionary = {}
	) -> Dictionary:
	var rollback_conflict := bool(rollback.get("conflict", false))
	var rollback_failed := not rollback.is_empty() and not bool(rollback.get("ok", false))
	return {
		"ok": false,
		"status": &"ROLLBACK_CONFLICT" if rollback_conflict else (
			&"ROLLBACK_FAILED" if rollback_failed else &"TRANSACTION_FAILED"
		),
		"phase": phase,
		"domain": domain,
		"error": error,
		"prepared_count": plans.size(),
		"committed_count": committed.size(),
		"rolled_back": phase in [&"STAGE", &"COMMIT"],
		"rollback": rollback,
		"rollback_conflict": rollback_conflict,
		"transaction_retained": bool(transaction.get("retained", false)),
		"transaction": _public_transaction(transaction),
	}
