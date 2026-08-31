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
static func save(session: EncounterEditSession, options: Dictionary = {}) -> Dictionary:
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
	var transaction_nonce := directory.sha256_text().left(16)
	for entry_index in range(plan.entries.size()):
		var entry: Dictionary = plan.entries[entry_index]
		var path := str(entry.path)
		if _file_fingerprint(path) != entry.initial:
			return {"ok": false, "error": "external_conflict", "path": path}
		var extension := path.get_extension().to_lower()
		var backup := directory.path_join(
			"backup_%03d_%s.%s" % [entry_index, path.sha256_text().left(16), extension]
		)
		if bool(entry.initial.exists):
			var error := DirAccess.copy_absolute(
				ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(backup))
			if error != OK or _file_fingerprint(backup) != entry.initial:
				return {"ok": false, "error": "backup_failed", "path": path, "code": error}
		journal.append({
			"path": path,
			"backup": backup,
			"initial": entry.initial,
			"stage": directory.path_join(
				"stage_%03d_%s.%s" % [entry_index, path.sha256_text().left(16), extension]
			),
			"neighbor_stage": _neighbor_path(
				path, transaction_nonce, entry_index, "prepared"
			),
			"quarantine": _neighbor_path(
				path, transaction_nonce, entry_index, "original"
			),
			"rollback_stage": _neighbor_path(
				path, transaction_nonce, entry_index, "rollback"
			),
			"rollback_quarantine": _neighbor_path(
				path, transaction_nonce, entry_index, "owned"
			),
		})
	var publication := EncounterCopyService.copy_run(session.working_run)
	if publication.is_empty():
		return {"ok": false, "error": "publication_copy_failed"}
	var copies := publication.source_to_work as Dictionary
	var published := {}
	var staged_publication_paths := {}
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
	# Toutes les Resources sont d'abord sérialisées et vérifiées sous user://.
	# Aucune cible du catalogue n'est ouverte par ResourceSaver.
	for i in range(plan.entries.size()):
		var entry: Dictionary = plan.entries[i]
		var record := journal[i]
		if _file_fingerprint(entry.path) != record.initial:
			return {"ok": false, "error": "external_conflict", "path": entry.path}
		var resource := copies.get(entry.resource) as Resource
		if resource == null:
			return {"ok": false, "error": "publication_copy_missing", "path": entry.path}
		_set_staged_publication_paths(staged_publication_paths, true)
		_bind_publication_children(resource, published)
		var expected := session._document_value(resource, {})
		var references := _external_references(resource)
		# Pendant la vérification pré-commit, les parents référencent les stages
		# enfants déjà vérifiés. Leurs chemins seront remis au canonique dans le
		# texte du parent avant que celui-ci puisse être commité.
		_set_staged_publication_paths(staged_publication_paths, false)
		var error := ResourceSaver.save(resource, str(record.stage))
		if error != OK:
			_set_staged_publication_paths(staged_publication_paths, false)
			return _failed("resource_stage_failed", entry.path, [], recovery, error)
		var uid_result := _preserve_stage_uid(str(record.stage), record.initial, str(record.path))
		if not bool(uid_result.get("ok", false)):
			_set_staged_publication_paths(staged_publication_paths, false)
			return _failed("resource_stage_uid_failed", entry.path, [], recovery,
				int(uid_result.get("code", FAILED)))
		if not _set_staged_uid_mappings(staged_publication_paths, false):
			return _failed("stage_uid_mapping_failed", entry.path, [], recovery)
		var reloaded := ResourceLoader.load(
			str(record.stage), "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
		)
		var mappings_restored := _set_staged_uid_mappings(staged_publication_paths, true)
		var actual_references := _external_references(reloaded) if reloaded != null else {}
		var canonical_actual_references := _canonicalize_stage_references(
			actual_references, staged_publication_paths
		)
		if not mappings_restored or reloaded == null \
				or session._document_value(reloaded, {}) != expected \
				or canonical_actual_references != references:
			var verification := {"expected": expected,
				"actual": session._document_value(reloaded, {}),
				"expected_references": references,
				"actual_references": actual_references,
				"canonical_actual_references": canonical_actual_references,
				"uid_mappings_restored": mappings_restored}
			_set_staged_publication_paths(staged_publication_paths, false)
			var failure := _failed("resource_stage_verification_failed", entry.path, [], recovery)
			failure["verification"] = verification
			_write_json(directory.path_join("verification_failure.json"), verification)
			return failure
		_set_staged_publication_paths(staged_publication_paths, false)
		published[resource] = reloaded
		staged_publication_paths[reloaded] = {
			"target": str(entry.path),
			"stage": str(record.stage),
		}

	# L'ensemble du graphe est maintenant vérifié avec des références de stage.
	# Canonicaliser seulement ici préserve la vérification transitive des parents.
	for i in range(plan.entries.size()):
		var entry: Dictionary = plan.entries[i]
		var record := journal[i]
		if not _rewrite_staged_references(str(record.stage), staged_publication_paths):
			return _failed("stage_reference_rewrite_failed", entry.path, [], recovery)
		record["staged"] = _file_fingerprint(str(record.stage))
		var after_stage_hook := options.get("after_stage_hook", Callable()) as Callable
		if after_stage_hook.is_valid():
			var stage_hook_result: Variant = after_stage_hook.call(
				record.stage, entry.path, i + 1, record
			)
			if not _hook_succeeded(stage_hook_result):
				return _failed("injected_stage_hook_failure", entry.path, [], recovery)
	_set_staged_publication_paths(staged_publication_paths, true)

	# Le commit ne fait que déplacer des fichiers voisins déjà vérifiés. La cible
	# existante est d'abord mise en quarantaine et vérifiée avant toute publication.
	var touched: Array[Dictionary] = []
	for i in range(plan.entries.size()):
		var entry: Dictionary = plan.entries[i]
		var record := journal[i]
		touched.append(record)
		var commit := _commit_staged_record(record, i + 1, options)
		if not bool(commit.get("ok", false)):
			return _failed(
				str(commit.get("error", "resource_commit_failed")),
				entry.path, touched, recovery, int(commit.get("code", FAILED))
			)
		var after_write_hook := options.get("after_write_hook", Callable()) as Callable
		if after_write_hook.is_valid():
			var hook_result: Variant = after_write_hook.call(entry.path, touched.size(), record)
			if not _hook_succeeded(hook_result):
				return _failed("injected_write_hook_failure", entry.path, touched, recovery)
		if int(options.get("fail_after_write", -1)) == touched.size():
			return _failed("injected_write_failure", entry.path, touched, recovery)
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
	var recovery_root := session.recovery_root
	if not _is_safe_recovery_root(recovery_root):
		return {"ok": false, "error": "unsafe_recovery_root"}
	var stamp := "%d_%d" % [int(Time.get_unix_time_from_system() * 1000000.0), Time.get_ticks_usec()]
	var directory := recovery_root.path_join("save_" + stamp)
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


static func _hook_succeeded(result: Variant) -> bool:
	if result is Dictionary:
		return bool(result.get("ok", false))
	if result is bool:
		return bool(result)
	return true


static func _neighbor_path(
		target_path: String, nonce: String, index: int, role: String
	) -> String:
	var extension := target_path.get_extension().to_lower()
	var basename := target_path.get_file().trim_suffix("." + extension)
	return target_path.get_base_dir().path_join(
		".%s.encounter_%s_%03d_%s.%s" % [basename, nonce, index, role, extension]
	)


static func _preserve_stage_uid(
		stage_path: String, initial: Dictionary, target_path: String
	) -> Dictionary:
	if not bool(initial.get("exists", false)):
		return {"ok": true, "uid": str(_file_fingerprint(stage_path).get("uid", ""))}
	var uid_text := str(initial.get("uid", ""))
	if uid_text.is_empty():
		return {"ok": true, "uid": "", "policy": "legacy_uidless"}
	var uid := ResourceUID.text_to_id(uid_text)
	if uid == ResourceUID.INVALID_ID:
		return {"ok": false, "error": "invalid_canonical_uid"}
	var generated_uid := str(_file_fingerprint(stage_path).get("uid", ""))
	var error := ResourceSaver.set_uid(stage_path, uid)
	if error != OK:
		return {"ok": false, "error": "stage_set_uid_failed", "code": error}
	error = _write_serialized_uid(stage_path, uid_text)
	if error != OK:
		return {"ok": false, "error": "stage_uid_header_failed", "code": error}
	if not generated_uid.is_empty() and generated_uid != uid_text \
			and not _clear_uid_mapping_if_owned(stage_path, {"uid": generated_uid}):
		return {"ok": false, "error": "generated_stage_uid_cleanup_failed"}
	# set_uid peut enregistrer temporairement le chemin du stage. Tant que le
	# commit n'a pas abouti, le chemin canonique reste l'autorité du cache UID.
	if not _sync_uid_mapping(target_path, initial):
		return {"ok": false, "error": "canonical_uid_mapping_failed"}
	var actual_uid := str(_file_fingerprint(stage_path).get("uid", ""))
	return {"ok": actual_uid == uid_text, "uid": actual_uid, "expected_uid": uid_text}


static func _commit_staged_record(
		record: Dictionary, commit_index: int, options: Dictionary
	) -> Dictionary:
	var path := str(record.path)
	var stage_path := str(record.stage)
	var neighbor_stage := str(record.neighbor_stage)
	var quarantine := str(record.quarantine)
	var initial := record.get("initial", {}) as Dictionary
	var staged := record.get("staged", {}) as Dictionary
	if staged.is_empty() or _file_fingerprint(stage_path) != staged:
		return {"ok": false, "error": "resource_stage_changed"}
	for sidecar in [neighbor_stage, quarantine]:
		if FileAccess.file_exists(sidecar) or DirAccess.dir_exists_absolute(
				ProjectSettings.globalize_path(sidecar)):
			return {"ok": false, "error": "commit_sidecar_collision", "path": sidecar}
	var copy_error := DirAccess.copy_absolute(
		ProjectSettings.globalize_path(stage_path),
		ProjectSettings.globalize_path(neighbor_stage)
	)
	if copy_error != OK or _file_fingerprint(neighbor_stage) != staged:
		return {"ok": false, "error": "neighbor_stage_failed", "code": copy_error}
	var hook_result := _run_commit_hook(
		options, path, commit_index, &"BEFORE_QUARANTINE", record
	)
	if not bool(hook_result.get("ok", false)):
		return hook_result
	if _file_fingerprint(path) != initial:
		return {"ok": false, "error": "external_conflict_before_commit", "code": ERR_BUSY}
	if bool(initial.get("exists", false)):
		# Une seconde lecture borde le renommage. La cible n'est jamais supprimée :
		# elle est déplacée vers un nom unique, puis ses octets sont vérifiés.
		if _file_fingerprint(path) != initial:
			return {"ok": false, "error": "external_conflict_before_quarantine", "code": ERR_BUSY}
		var quarantine_error := DirAccess.rename_absolute(
			ProjectSettings.globalize_path(path),
			ProjectSettings.globalize_path(quarantine)
		)
		if quarantine_error != OK:
			return {"ok": false, "error": "target_quarantine_failed", "code": quarantine_error}
		record["quarantined"] = true
		var quarantined_state := _file_fingerprint(quarantine)
		if quarantined_state != initial:
			_restore_quarantine_if_target_empty(quarantine, path, quarantined_state)
			return {"ok": false, "error": "external_conflict_during_quarantine", "code": ERR_BUSY}
	hook_result = _run_commit_hook(
		options, path, commit_index, &"AFTER_QUARANTINE", record
	)
	if not bool(hook_result.get("ok", false)):
		return hook_result
	# DirAccess.rename refuse une destination existante. La lecture explicite
	# permet en plus de classifier proprement une création tierce déterministe.
	if FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(
			ProjectSettings.globalize_path(path)):
		return {"ok": false, "error": "external_conflict_after_quarantine", "code": ERR_BUSY}
	hook_result = _run_commit_hook(
		options, path, commit_index, &"BEFORE_STAGE_RENAME", record
	)
	if not bool(hook_result.get("ok", false)):
		return hook_result
	# Sur Windows, rename_absolute peut remplacer une destination apparue entre
	# le contrôle précédent et le renommage. Revalider au bord de l'opération
	# empêche ce remplacement dans le chemin déterministe et protège la cible
	# tierce avant tout transfert de propriété du stage.
	if FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(
			ProjectSettings.globalize_path(path)):
		return {"ok": false, "error": "external_conflict_during_commit", "code": ERR_BUSY}
	var rename_error := DirAccess.rename_absolute(
		ProjectSettings.globalize_path(neighbor_stage),
		ProjectSettings.globalize_path(path)
	)
	if rename_error != OK:
		var destination_occupied := FileAccess.file_exists(path) \
			or DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(path))
		return {
			"ok": false,
			"error": "external_conflict_during_commit" if destination_occupied \
				else "stage_commit_rename_failed",
			"code": rename_error,
		}
	var actual := _file_fingerprint(path)
	if actual != staged:
		# Ne pas revendiquer une empreinte inattendue : un rollback ultérieur la
		# traitera comme externe et conservera les sauvegardes/quarantaines.
		return {"ok": false, "error": "resource_commit_verification_failed"}
	record["owned"] = staged
	if not _sync_uid_mapping(path, staged):
		return {"ok": false, "error": "resource_commit_uid_failed"}
	if bool(initial.get("exists", false)):
		if _file_fingerprint(quarantine) != initial:
			return {"ok": false, "error": "quarantine_changed_after_commit", "code": ERR_BUSY}
		var cleanup_error := DirAccess.remove_absolute(ProjectSettings.globalize_path(quarantine))
		if cleanup_error != OK:
			return {"ok": false, "error": "quarantine_cleanup_failed", "code": cleanup_error}
		record["quarantined"] = false
	return {"ok": true, "owned": staged}


static func _run_commit_hook(
		options: Dictionary,
		path: String,
		commit_index: int,
		phase: StringName,
		record: Dictionary
	) -> Dictionary:
	var hook := options.get("before_commit_hook", Callable()) as Callable
	if not hook.is_valid():
		return {"ok": true}
	var result: Variant = hook.call(path, commit_index, phase, record)
	if _hook_succeeded(result):
		return {"ok": true}
	return {"ok": false, "error": "injected_commit_hook_failure", "phase": phase}


static func _restore_quarantine_if_target_empty(
		quarantine: String, target: String, expected: Dictionary
	) -> bool:
	if _file_fingerprint(quarantine) != expected or FileAccess.file_exists(target) \
			or DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(target)):
		return false
	if DirAccess.rename_absolute(
			ProjectSettings.globalize_path(quarantine),
			ProjectSettings.globalize_path(target)
		) != OK:
		return false
	return _file_fingerprint(target) == expected and _sync_uid_mapping(target, expected)


static func _file_fingerprint(path: String) -> Dictionary:
	var exists := FileAccess.file_exists(path)
	return {
		"exists": exists,
		"sha256": FileAccess.get_sha256(path) if exists else "",
		"uid": _resource_uid_text(path) if exists else "",
	}


static func _resource_uid_text(path: String) -> String:
	# Les stages et les fixtures sous user:// ne sont pas toujours inscrits dans
	# la table globale, bien que leur en-tête .tres porte un UID valide.
	var serialized := _serialized_resource_uid_text(path)
	if not serialized.is_empty():
		return serialized
	var uid := ResourceLoader.get_resource_uid(path)
	return "" if uid == ResourceUID.INVALID_ID else ResourceUID.id_to_text(uid)


static func _serialized_resource_uid_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var header := file.get_line()
	file.close()
	var marker := 'uid="'
	var marker_index := header.find(marker)
	if marker_index < 0:
		return ""
	var value_start := marker_index + marker.length()
	var value_end := header.find('"', value_start)
	if value_end <= value_start:
		return ""
	var uid_text := header.substr(value_start, value_end - value_start)
	return uid_text if ResourceUID.text_to_id(uid_text) != ResourceUID.INVALID_ID else ""


static func _write_serialized_uid(path: String, uid_text: String) -> int:
	if path.get_extension().to_lower() != "tres" \
			or ResourceUID.text_to_id(uid_text) == ResourceUID.INVALID_ID:
		return ERR_INVALID_PARAMETER
	var contents := FileAccess.get_file_as_string(path)
	var line_end := contents.find("\n")
	if line_end < 0:
		return ERR_FILE_CORRUPT
	var header := contents.substr(0, line_end)
	if not header.begins_with("[gd_resource"):
		return ERR_FILE_UNRECOGNIZED
	var marker := 'uid="'
	var marker_index := header.find(marker)
	if marker_index >= 0:
		var value_start := marker_index + marker.length()
		var value_end := header.find('"', value_start)
		if value_end <= value_start:
			return ERR_FILE_CORRUPT
		header = header.substr(0, value_start) + uid_text + header.substr(value_end)
	else:
		var bracket_index := header.rfind("]")
		if bracket_index < 0:
			return ERR_FILE_CORRUPT
		header = header.insert(bracket_index, ' uid="%s"' % uid_text)
	var output := header + contents.substr(line_end)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(output)
	file.flush()
	file.close()
	return OK if _serialized_resource_uid_text(path) == uid_text else ERR_FILE_CORRUPT


static func _sync_uid_mapping(path: String, state: Dictionary) -> bool:
	if not bool(state.get("exists", false)):
		return true
	var uid_text := str(state.get("uid", ""))
	if uid_text.is_empty():
		return true
	var uid := ResourceUID.text_to_id(uid_text)
	if uid == ResourceUID.INVALID_ID:
		return false
	if ResourceUID.has_id(uid):
		ResourceUID.set_id(uid, path)
	else:
		ResourceUID.add_id(uid, path)
	return ResourceUID.get_id_path(uid) == path


static func _clear_uid_mapping_if_owned(path: String, owned: Dictionary) -> bool:
	var uid_text := str(owned.get("uid", ""))
	if uid_text.is_empty():
		return true
	var uid := ResourceUID.text_to_id(uid_text)
	if uid == ResourceUID.INVALID_ID:
		return false
	if ResourceUID.has_id(uid) and ResourceUID.get_id_path(uid) == path:
		ResourceUID.remove_id(uid)
	return not ResourceUID.has_id(uid) or ResourceUID.get_id_path(uid) != path


static func _failed(
		error: String, path: String, touched: Array[Dictionary],
		recovery: Dictionary, code := FAILED
	) -> Dictionary:
	var rollback := _restore_backups(touched)
	var cleanup := _cleanup_owned_sidecars(touched)
	var rollback_complete := bool(rollback.get("ok", false)) \
		and bool(cleanup.get("ok", false))
	var rollback_report_path := ""
	if not bool(rollback.get("ok", false)) or not bool(cleanup.get("ok", false)):
		rollback_report_path = str(recovery.path).get_base_dir().path_join("rollback_report.json")
		_write_json(rollback_report_path, {
			"error": error,
			"failed_path": path,
			"status": str(rollback.get("status", &"ROLLBACK_FAILED")),
			"rollback": rollback,
			"cleanup": cleanup,
		})
	return {
		"ok": false,
		"error": error,
		"status": &"ROLLBACK_CONFLICT" if bool(rollback.get("conflict", false)) else (
			&"ROLLED_BACK" if rollback_complete else &"ROLLBACK_FAILED"
		),
		"path": path,
		"code": code,
		"rollback": rollback,
		"cleanup": cleanup,
		"rollback_complete": rollback_complete,
		"rollback_conflict": bool(rollback.get("conflict", false)),
		"recovery_path": recovery.path,
		"recovery_manifest": recovery.manifest,
		"rollback_report": rollback_report_path,
	}


static func _restore_backups(touched: Array[Dictionary]) -> Dictionary:
	var entries: Array[Dictionary] = []
	var ok := true
	var conflict := false
	var reversed := touched.duplicate()
	reversed.reverse()
	# Chaque restauration suit le même protocole que le commit : préparer un
	# voisin, mettre l'état possédé en quarantaine, vérifier, puis renommer. Une
	# empreinte tierce n'est jamais supprimée ni écrasée.
	for rollback_index in range(reversed.size()):
		var entry := _restore_record(reversed[rollback_index], rollback_index)
		entries.append(entry)
		ok = ok and bool(entry.get("ok", false))
		conflict = conflict or bool(entry.get("conflict", false))
	return {
		"ok": ok,
		"conflict": conflict,
		"skipped_external_change": conflict,
		"status": &"ROLLBACK_CONFLICT" if conflict else (
			&"ROLLED_BACK" if ok else &"ROLLBACK_FAILED"
		),
		"entries": entries,
		"touched_paths": touched.map(func(entry): return entry.path),
	}


static func _restore_record(record: Dictionary, rollback_index: int) -> Dictionary:
	var path := str(record.path)
	var initial := record.get("initial", {}) as Dictionary
	var owned := record.get("owned", {}) as Dictionary
	var current := _file_fingerprint(path)
	var operation := &"NONE"
	var error := OK
	var external_change := false
	var quarantine := str(record.get("quarantine", ""))
	# Échec entre la mise en quarantaine de l'original et le commit du stage.
	if bool(initial.get("exists", false)) and not quarantine.is_empty() \
			and _file_fingerprint(quarantine) == initial and not bool(current.get("exists", false)):
		operation = &"RESTORE_COMMIT_QUARANTINE"
		if not _restore_quarantine_if_target_empty(quarantine, path, initial):
			error = ERR_CANT_CREATE
		current = _file_fingerprint(path)
	if error == OK and current == initial:
		if operation == &"NONE":
			operation = &"ALREADY_RESTORED"
	elif error == OK and (owned.is_empty() or current != owned):
		operation = &"PRESERVE_EXTERNAL_CHANGE"
		error = ERR_BUSY
		external_change = true
	else:
		var restore_result := _replace_owned_with_initial(
			record, rollback_index, path, current, owned, initial
		)
		operation = restore_result.get("operation", &"RESTORE_FAILED")
		error = int(restore_result.get("code", FAILED))
		external_change = bool(restore_result.get("conflict", false))
	var actual := _file_fingerprint(path)
	var reloaded := true
	if not external_change and bool(initial.get("exists", false)) and actual == initial:
		reloaded = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) != null
	var entry_ok := not external_change and error == OK and actual == initial and reloaded
	return {
		"path": path,
		"existed": initial.get("exists", false),
		"backup": record.get("backup", ""),
		"quarantine": quarantine,
		"operation": operation,
		"code": error,
		"expected": initial,
		"owned": owned,
		"current_before": current,
		"actual": actual,
		"reloaded": reloaded,
		"conflict": external_change,
		"ok": entry_ok,
	}


static func _replace_owned_with_initial(
		record: Dictionary,
		rollback_index: int,
		path: String,
		current: Dictionary,
		owned: Dictionary,
		initial: Dictionary
	) -> Dictionary:
	if current != owned or _file_fingerprint(path) != owned:
		return {"operation": &"PRESERVE_EXTERNAL_CHANGE", "code": ERR_BUSY, "conflict": true}
	var rollback_quarantine := str(record.get("rollback_quarantine", ""))
	if rollback_quarantine.is_empty():
		rollback_quarantine = _neighbor_path(
			path, ("rollback_%d_%d" % [Time.get_ticks_usec(), rollback_index]).sha256_text().left(16),
			rollback_index, "owned"
		)
	if FileAccess.file_exists(rollback_quarantine):
		return {"operation": &"ROLLBACK_SIDECAR_COLLISION", "code": ERR_ALREADY_EXISTS}
	var rollback_stage := str(record.get("rollback_stage", ""))
	if bool(initial.get("exists", false)):
		var backup := str(record.get("backup", ""))
		if not FileAccess.file_exists(backup) or _file_fingerprint(backup) != initial:
			return {"operation": &"BACKUP_INVALID", "code": ERR_FILE_NOT_FOUND}
		if rollback_stage.is_empty():
			rollback_stage = _neighbor_path(
				path, ("restore_%d_%d" % [Time.get_ticks_usec(), rollback_index]).sha256_text().left(16),
				rollback_index, "rollback"
			)
		if FileAccess.file_exists(rollback_stage):
			return {"operation": &"ROLLBACK_SIDECAR_COLLISION", "code": ERR_ALREADY_EXISTS}
		var copy_error := DirAccess.copy_absolute(
			ProjectSettings.globalize_path(backup),
			ProjectSettings.globalize_path(rollback_stage)
		)
		if copy_error != OK or _file_fingerprint(rollback_stage) != initial:
			return {"operation": &"ROLLBACK_STAGE_FAILED", "code": copy_error}
	var quarantine_error := DirAccess.rename_absolute(
		ProjectSettings.globalize_path(path),
		ProjectSettings.globalize_path(rollback_quarantine)
	)
	if quarantine_error != OK:
		return {"operation": &"OWNED_QUARANTINE_FAILED", "code": quarantine_error}
	var moved := _file_fingerprint(rollback_quarantine)
	if moved != owned:
		_restore_quarantine_if_target_empty(rollback_quarantine, path, moved)
		return {"operation": &"PRESERVE_EXTERNAL_CHANGE", "code": ERR_BUSY, "conflict": true}
	if FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(
			ProjectSettings.globalize_path(path)):
		# Une création concurrente devient la nouvelle autorité. Seule la
		# quarantaine dont l'empreinte est possédée peut être supprimée.
		if _file_fingerprint(rollback_quarantine) == owned:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(rollback_quarantine))
		return {"operation": &"PRESERVE_EXTERNAL_CHANGE", "code": ERR_BUSY, "conflict": true}
	if bool(initial.get("exists", false)):
		var rename_error := DirAccess.rename_absolute(
			ProjectSettings.globalize_path(rollback_stage),
			ProjectSettings.globalize_path(path)
		)
		if rename_error != OK:
			_restore_quarantine_if_target_empty(rollback_quarantine, path, owned)
			return {
				"operation": &"PRESERVE_EXTERNAL_CHANGE" if FileAccess.file_exists(path) \
					else &"RESTORE_RENAME_FAILED",
				"code": rename_error,
				"conflict": FileAccess.file_exists(path),
			}
		if _file_fingerprint(path) != initial:
			return {"operation": &"RESTORE_VERIFY_FAILED", "code": ERR_FILE_CORRUPT}
		if not _sync_uid_mapping(path, initial):
			return {"operation": &"RESTORE_UID_FAILED", "code": FAILED}
	else:
		if not _clear_uid_mapping_if_owned(path, owned):
			return {"operation": &"REMOVE_CREATED_UID_FAILED", "code": FAILED}
	if _file_fingerprint(rollback_quarantine) != owned:
		return {"operation": &"OWNED_QUARANTINE_CHANGED", "code": ERR_BUSY, "conflict": true}
	var cleanup_error := DirAccess.remove_absolute(
		ProjectSettings.globalize_path(rollback_quarantine)
	)
	return {
		"operation": &"RESTORE_ORIGINAL" if bool(initial.get("exists", false)) \
			else &"REMOVE_STUDIO_CREATED",
		"code": cleanup_error,
		"conflict": false,
	}


static func _cleanup_owned_sidecars(records: Array[Dictionary]) -> Dictionary:
	var entries := []
	var ok := true
	for record in records:
		var staged := record.get("staged", {}) as Dictionary
		var initial := record.get("initial", {}) as Dictionary
		var owned := record.get("owned", {}) as Dictionary
		var quarantine := str(record.get("quarantine", ""))
		if not quarantine.is_empty() and FileAccess.file_exists(quarantine) \
				and _file_fingerprint(str(record.path)) == initial \
				and _file_fingerprint(quarantine) == initial:
			var quarantine_code := DirAccess.remove_absolute(
				ProjectSettings.globalize_path(quarantine)
			)
			entries.append({
				"path": quarantine,
				"removed": quarantine_code == OK,
				"code": quarantine_code,
			})
			ok = ok and quarantine_code == OK
		for candidate in [
			{"path": str(record.get("neighbor_stage", "")), "state": staged},
			{"path": str(record.get("rollback_stage", "")), "state": initial},
			{"path": str(record.get("rollback_quarantine", "")), "state": owned},
		]:
			var sidecar := str(candidate.path)
			var expected := candidate.state as Dictionary
			if sidecar.is_empty() or expected.is_empty() or not FileAccess.file_exists(sidecar):
				continue
			var removed := false
			var code := ERR_BUSY
			if _file_fingerprint(sidecar) == expected:
				code = DirAccess.remove_absolute(ProjectSettings.globalize_path(sidecar))
				removed = code == OK
			entries.append({"path": sidecar, "removed": removed, "code": code})
			ok = ok and removed
	return {"ok": ok, "entries": entries}


static func _set_staged_publication_paths(paths: Dictionary, canonical: bool) -> void:
	for resource_value in paths:
		var resource := resource_value as Resource
		var mapping := paths[resource_value] as Dictionary
		if resource != null:
			resource.set_path_cache(str(mapping.target if canonical else mapping.stage))


static func _set_staged_uid_mappings(paths: Dictionary, canonical: bool) -> bool:
	for resource_value in paths:
		var mapping := paths[resource_value] as Dictionary
		var uid_text := _serialized_resource_uid_text(str(mapping.get("stage", "")))
		if uid_text.is_empty():
			continue
		var uid := ResourceUID.text_to_id(uid_text)
		if uid == ResourceUID.INVALID_ID:
			return false
		var authority := str(mapping.get("target" if canonical else "stage", ""))
		if authority.is_empty():
			return false
		if ResourceUID.has_id(uid):
			ResourceUID.set_id(uid, authority)
		else:
			ResourceUID.add_id(uid, authority)
		if ResourceUID.get_id_path(uid) != authority:
			return false
	return true


static func _canonicalize_stage_references(
		references: Dictionary, paths: Dictionary
	) -> Dictionary:
	var stage_to_target := {}
	for resource_value in paths:
		var mapping := paths[resource_value] as Dictionary
		stage_to_target[str(mapping.get("stage", ""))] = str(mapping.get("target", ""))
	var result := references.duplicate(true)
	for key in result:
		var path := str(result[key])
		if stage_to_target.has(path):
			result[key] = stage_to_target[path]
	return result


static func _rewrite_staged_references(path: String, paths: Dictionary) -> bool:
	var contents := FileAccess.get_file_as_string(path)
	if contents.is_empty():
		return false
	var rewritten := contents
	for resource_value in paths:
		var mapping := paths[resource_value] as Dictionary
		var stage_path := str(mapping.get("stage", ""))
		var target_path := str(mapping.get("target", ""))
		if stage_path.is_empty() or target_path.is_empty():
			return false
		rewritten = rewritten.replace(stage_path, target_path)
	if rewritten == contents:
		return true
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(rewritten)
	file.flush()
	file.close()
	return FileAccess.get_file_as_string(path) == rewritten


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


static func latest_recovery_path(
		recovery_root := EncounterEditSession.RECOVERY_ROOT
	) -> String:
	if not _is_safe_recovery_root(recovery_root):
		return ""
	var directory := DirAccess.open(recovery_root)
	if directory == null:
		return ""
	var latest := ""
	var latest_stamp := -1
	var latest_ticks := -1
	for folder in directory.get_directories():
		var path := recovery_root.path_join(folder).path_join(
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
	var recovery_path := latest_recovery_path(
		session.recovery_root if session != null else EncounterEditSession.RECOVERY_ROOT
	)
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


static func _is_safe_recovery_root(path: String) -> bool:
	return path.begins_with("user://") and not path.contains("..") \
		and not path.contains("\\") and not path.trim_prefix("user://").contains(":")


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
	file.flush()
	file.close()
	return true
