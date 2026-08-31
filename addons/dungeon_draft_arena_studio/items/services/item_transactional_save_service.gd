@tool
class_name ItemTransactionalSaveService
extends RefCounted

const TRANSACTION_ROOT := "user://dungeon_draft_studio/item_save_transactions"
const TRANSACTION_MANIFEST_FILE := "transaction_manifest.json"
const STAGED_RESOURCE_FILE := "staged_candidate.tres"
const ORIGINAL_RESOURCE_FILE := "original_before.tres"

var validation_service := ItemStudioValidationService.new()
var reference_service := ItemReferenceService.new()
var force_failure_after_write := false
var before_verification_hook := Callable()
var transaction_root := TRANSACTION_ROOT


func build_plan(
		document: ItemStudioDocument,
		target_path: String,
		target_status: StringName,
		catalog: ItemStudioCatalogService,
		reward_tag_changed := false
	) -> ItemSavePlan:
	var plan := ItemSavePlan.new()
	plan.catalog_path = catalog.catalog_path if catalog != null \
		else ItemStudioCatalogService.DEFAULT_CATALOG_PATH
	plan.reward_tag_changed = reward_tag_changed
	if document == null or document.working_copy == null:
		plan.conflicts.append(ItemSaveConflict.new().configure(
			&"DOCUMENT_MISSING", "Aucun objet à sauvegarder."
		))
		return plan
	if target_status == StudioProjectContext.SCOPE_RUN_SPECIFIC:
		plan.conflicts.append(ItemSaveConflict.new().configure(
			&"RUN_SPECIFIC_UNSUPPORTED",
			"La portée « propre à une partie » est différée : aucun catalogue par partie n’existe."
		))
		return plan
	var validation := validation_service.validate(
		document.working_copy, catalog, target_path, document.source_path,
		document.original_item_id \
			if document.status == ItemStudioDocument.STATUS_SHARED else &"",
	)
	var is_draft := target_status == ItemStudioDocument.STATUS_DRAFT
	var owned_draft_target := is_draft and _is_owned_draft_target(
		document, target_path, catalog
	)
	var updates_published_draft := target_status == ItemStudioDocument.STATUS_SHARED \
		and document.status == ItemStudioDocument.STATUS_DRAFT \
		and catalog != null \
		and catalog.is_path_auto_discovered(target_path) \
		and _is_same_item_target(document, target_path)
	for message_value in validation.get("messages", []) as Array:
		var message := message_value as Dictionary
		if int(message.get("severity", 0)) == ItemStudioValidationMessage.Severity.ERROR:
			var code := StringName(message.get("code", &"VALIDATION"))
			if is_draft and (code != &"PATH_COLLISION" or owned_draft_target):
				plan.warnings.append(
					"Brouillon non publiable : %s" \
					% message.get("message", "Validation incomplète.")
				)
			elif updates_published_draft \
					and code in [&"PATH_COLLISION", &"ITEM_ID_DUPLICATE"]:
				plan.warnings.append(
					"Mise à jour de la production existante : %s" \
					% message.get("message", "collision attendue")
				)
			else:
				plan.conflicts.append(ItemSaveConflict.new().configure(
					code,
					str(message.get("message", "Validation refusée.")),
					str(message.get("property_path", "")),
				))
		elif int(message.get("severity", 0)) \
				== ItemStudioValidationMessage.Severity.WARNING:
			plan.warnings.append(str(message.get("message", "")))

	var entry := ItemSavePlanEntry.new()
	entry.source_path = document.source_path
	entry.destination_path = target_path
	entry.source_fingerprint = document.original_fingerprint
	entry.source_sha256 = document.original_file_sha256
	var updates_source := target_path == document.source_path \
		and not document.source_path.is_empty() \
		and not document.original_fingerprint.is_empty()
	entry.operation = &"CREATE"
	if updates_source or owned_draft_target or updates_published_draft:
		entry.operation = &"UPDATE"
	entry.status = target_status
	entry.item_id = document.working_copy.item_id
	if updates_source:
		entry.old_fingerprint = document.original_fingerprint
		entry.old_sha256 = document.original_file_sha256
	elif owned_draft_target or updates_published_draft:
		entry.old_fingerprint = _disk_fingerprint(target_path)
		entry.old_sha256 = _file_sha256(target_path)
	if entry.operation == &"UPDATE" and FileAccess.file_exists(target_path):
		entry.target_uid = _uid_text(_resource_uid(target_path))
	entry.new_fingerprint = document.current_fingerprint()
	entry.subresource_count = document.working_copy.stat_modifiers.size() \
		+ document.working_copy.spell_modifiers.size()
	plan.entries.append(entry)
	plan.references = reference_service.incoming_references(document.source)
	return plan


func execute(
		plan: ItemSavePlan,
		document: ItemStudioDocument,
		defer_finalize := false
	) -> Dictionary:
	if plan == null or document == null or document.working_copy == null \
			or not plan.is_valid():
		return {
			"ok": false,
			"error": "Plan de sauvegarde invalide.",
			"plan": plan.to_snapshot() if plan != null else {},
		}
	var entry := plan.entries[0]
	var target_path := entry.destination_path
	if entry.new_fingerprint != document.current_fingerprint():
		return _conflict_result(
			&"PLAN_STALE",
			"Le document a changé depuis la revue du plan ; reconstruisez le plan de sauvegarde.",
			target_path, plan,
		)
	var external_conflict := _detect_external_change(entry)
	if not external_conflict.is_empty():
		return _conflict_result(
			StringName(external_conflict.get("code", &"EXTERNAL_CHANGE")),
			str(external_conflict.get(
				"message", "Le fichier cible a changé hors du Studio."
			)),
			target_path, plan, external_conflict,
		)
	var directory_error := DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(target_path.get_base_dir())
	)
	if directory_error != OK:
		return {
			"ok": false,
			"error": "Dossier de destination inaccessible : %s" % directory_error,
		}

	var transaction := _begin_transaction(entry, Time.get_ticks_usec())
	if not bool(transaction.get("ok", false)):
		return {
			"ok": false,
			"code": transaction.get("code", &"RECOVERY_DIRECTORY_FAILED"),
			"error": transaction.get("error", "Transaction Item inaccessible."),
			"transaction": _transaction_snapshot(transaction),
		}
	var stage_path := str(transaction.get("stage_path", ""))
	var expected_fingerprint := document.current_fingerprint()
	var save_candidate := ItemDeepCopyService.new().duplicate_definition(
		document.working_copy
	)
	if save_candidate == null:
		_cleanup_transaction(transaction)
		return {
			"ok": false,
			"error": "La version en cours ne peut pas être dupliquée pour l’écriture.",
			"transaction": _transaction_snapshot(transaction),
		}
	var save_error := ResourceSaver.save(save_candidate, stage_path)
	if save_error != OK:
		_cleanup_transaction(transaction)
		return {
			"ok": false,
			"error": "ResourceSaver a refusé le staging : %s" % save_error,
			"transaction": _transaction_snapshot(transaction),
		}
	var generated_stage_uid := _uid_text(_resource_uid(stage_path))
	transaction["generated_stage_uid"] = generated_stage_uid
	if entry.operation == &"UPDATE" and not entry.target_uid.is_empty():
		var canonical_uid := ResourceUID.text_to_id(entry.target_uid)
		if canonical_uid == ResourceUID.INVALID_ID:
			_cleanup_transaction(transaction)
			return _stage_failure(
				&"CANONICAL_UID_INVALID",
				"L’UID canonique de l’objet est invalide.", transaction,
			)
		var uid_error := ResourceSaver.set_uid(stage_path, canonical_uid)
		if uid_error != OK:
			_cleanup_transaction(transaction)
			return _stage_failure(
				&"CANONICAL_UID_PRESERVE_FAILED",
				"L’UID canonique n’a pas pu être appliqué au staging : %s" % uid_error,
				transaction,
			)
		if not _ensure_serialized_text_uid(stage_path, canonical_uid):
			_cleanup_transaction(transaction)
			return _stage_failure(
				&"CANONICAL_UID_SERIALIZE_FAILED",
				"L’UID canonique n’a pas pu être garanti dans l’en-tête du staging.",
				transaction,
			)
		if generated_stage_uid != entry.target_uid:
			_remove_uid_mapping_for_path(stage_path, generated_stage_uid)
	var staged_uid := _uid_text(_resource_uid(stage_path))
	transaction["staged_uid"] = staged_uid
	var staged_resource := ResourceLoader.load(
		stage_path, "", ResourceLoader.CACHE_MODE_IGNORE
	) as ItemDefinition
	if staged_resource == null \
			or ItemFingerprintService.semantic_fingerprint(staged_resource) \
			!= expected_fingerprint \
			or (not entry.target_uid.is_empty() and staged_uid != entry.target_uid):
		_cleanup_transaction(transaction)
		return _stage_failure(
			&"STAGE_VERIFICATION_FAILED",
			"La relecture du staging ne conserve pas l’état ou l’UID attendu.",
			transaction,
		)
	var staged_sha256 := _file_sha256(stage_path)
	if staged_sha256.is_empty():
		_cleanup_transaction(transaction)
		return _stage_failure(
			&"STAGE_HASH_FAILED",
			"L’empreinte physique du staging est indisponible.", transaction,
		)
	transaction["staged_sha256"] = staged_sha256

	external_conflict = _detect_external_change(entry)
	if not external_conflict.is_empty():
		_record_transaction_status(
			transaction, &"ABORTED_EXTERNAL_CHANGE", external_conflict
		)
		_cleanup_transaction(transaction)
		var stage_conflict := _conflict_result(
			StringName(external_conflict.get("code", &"EXTERNAL_CHANGE")),
			str(external_conflict.get(
				"message", "Le fichier cible a changé hors du Studio."
			)),
			target_path, plan, external_conflict,
		)
		stage_conflict["transaction"] = _transaction_snapshot(transaction)
		return stage_conflict
	var prepared := _prepare_recovery(entry, transaction)
	if not bool(prepared.get("ok", false)):
		_cleanup_transaction(transaction)
		return {
			"ok": false,
			"code": prepared.get("code", &"RECOVERY_PREPARE_FAILED"),
			"error": prepared.get(
				"error",
				"La récupération n’a pas pu être préparée ; la cible est intacte."
			),
			"transaction": _transaction_snapshot(transaction),
		}
	external_conflict = _detect_post_recovery_change(entry, transaction)
	if not external_conflict.is_empty():
		_record_transaction_status(
			transaction, &"ABORTED_EXTERNAL_CHANGE", external_conflict
		)
		_cleanup_transaction(transaction)
		var recovery_conflict := _conflict_result(
			StringName(external_conflict.get("code", &"EXTERNAL_CHANGE")),
			str(external_conflict.get(
				"message", "Le fichier cible a changé hors du Studio."
			)),
			target_path, plan, external_conflict,
		)
		recovery_conflict["transaction"] = _transaction_snapshot(transaction)
		return recovery_conflict

	var target_existed := bool(transaction.get("target_existed", false))
	if target_existed:
		var remove_error := DirAccess.remove_absolute(
			ProjectSettings.globalize_path(target_path)
		)
		if remove_error != OK:
			_record_transaction_status(transaction, &"TARGET_REMOVE_FAILED", {
				"code": remove_error,
			})
			_cleanup_transaction(transaction)
			return {
				"ok": false,
				"code": &"TARGET_REMOVE_FAILED",
				"error": "La cible canonique n’a pas pu être libérée : %s" % remove_error,
				"transaction": _transaction_snapshot(transaction),
			}
		_record_transaction_status(transaction, &"TARGET_REMOVED", {
			"target_path": target_path,
		})
	if FileAccess.file_exists(target_path):
		var appeared_rollback := _conditional_rollback(
			target_path, target_existed, "", transaction
		)
		return {
			"ok": false,
			"code": &"EXTERNAL_TARGET_CREATED",
			"error": "Un fichier tiers est apparu avant l’écriture ; il a été préservé.",
			"rollback": appeared_rollback,
			"transaction": _transaction_snapshot(transaction),
		}
	if not _release_stage_uid_mapping(stage_path, staged_uid, target_path):
		var mapping_rollback := _conditional_rollback(
			target_path, target_existed, "", transaction
		)
		return {
			"ok": false,
			"code": &"STAGE_UID_MAPPING_CONFLICT",
			"error": "L’UID du staging est détenu par un autre chemin.",
			"rollback": mapping_rollback,
			"transaction": _transaction_snapshot(transaction),
		}
	var replace_error := DirAccess.copy_absolute(
		ProjectSettings.globalize_path(stage_path),
		ProjectSettings.globalize_path(target_path),
	)
	if replace_error != OK:
		# Une copie peut avoir créé ou tronqué la cible avant de signaler son
		# erreur. Cette photographie immédiate borne ce que le rollback est
		# autorisé à retirer ; une écriture ultérieure aura une autre empreinte.
		var observed_failed_write := _file_sha256(target_path)
		var replace_rollback := _conditional_rollback(
			target_path, target_existed, observed_failed_write, transaction
		)
		_resync_shared_instance(target_path)
		return {
			"ok": false,
			"code": &"TARGET_REPLACE_FAILED",
			"error": "Remplacement transactionnel impossible : %s" % replace_error,
			"rollback": replace_rollback,
			"transaction": _transaction_snapshot(transaction),
		}
	var written_sha256 := _file_sha256(target_path)
	if written_sha256 != staged_sha256:
		var physical_rollback := _conditional_rollback(
			target_path, target_existed, staged_sha256, transaction
		)
		_resync_shared_instance(target_path)
		return {
			"ok": false,
			"code": &"PHYSICAL_WRITE_MISMATCH",
			"error": "La cible ne correspond pas aux octets préparés.",
			"expected_sha256": staged_sha256,
			"actual_sha256": written_sha256,
			"rollback": physical_rollback,
			"transaction": _transaction_snapshot(transaction),
		}
	if not _sync_uid_mapping(target_path, staged_uid):
		var uid_rollback := _conditional_rollback(
			target_path, target_existed, written_sha256, transaction
		)
		return {
			"ok": false,
			"code": &"TARGET_UID_SYNC_FAILED",
			"error": "L’UID de la cible n’a pas pu être synchronisé.",
			"rollback": uid_rollback,
			"transaction": _transaction_snapshot(transaction),
		}
	if not _record_transaction_status(transaction, &"WRITTEN", {
		"target_path": target_path,
		"written_sha256": written_sha256,
		"uid": staged_uid,
	}):
		var journal_rollback := _conditional_rollback(
			target_path, target_existed, written_sha256, transaction
		)
		return {
			"ok": false,
			"code": &"WRITE_JOURNAL_FAILED",
			"error": "L’écriture n’a pas pu être journalisée ; elle a été annulée.",
			"rollback": journal_rollback,
			"transaction": _transaction_snapshot(transaction),
		}
	if before_verification_hook.is_valid():
		before_verification_hook.call(target_path)

	var physical_sha256 := _file_sha256(target_path)
	var reloaded: ItemDefinition = null
	var written: ItemDefinition = null
	if physical_sha256 == written_sha256:
		reloaded = ResourceLoader.load(
			target_path, "", ResourceLoader.CACHE_MODE_REPLACE
		) as ItemDefinition
		written = ResourceLoader.load(
			target_path, "", ResourceLoader.CACHE_MODE_IGNORE
		) as ItemDefinition
	var verified := not force_failure_after_write \
		and reloaded != null \
		and written != null \
		and physical_sha256 == staged_sha256 \
		and (written.is_valid() or entry.status == ItemStudioDocument.STATUS_DRAFT) \
		and ItemFingerprintService.semantic_fingerprint(written) == expected_fingerprint \
		and (entry.target_uid.is_empty() \
			or _uid_text(_resource_uid(target_path)) == entry.target_uid)
	if not verified:
		var verification_rollback := _conditional_rollback(
			target_path, target_existed, written_sha256, transaction
		)
		_resync_shared_instance(target_path)
		var verification_error := \
			"Vérification post-écriture échouée ; restauration effectuée."
		if bool(verification_rollback.get("skipped_external_change", false)):
			verification_error = (
				"Vérification post-écriture échouée ; le contenu tiers a été préservé "
				+ "et la récupération originale reste disponible."
			)
		return {
			"ok": false,
			"code": &"POST_WRITE_VERIFICATION_FAILED",
			"error": verification_error,
			"expected_sha256": staged_sha256,
			"actual_sha256": physical_sha256,
			"rollback": verification_rollback,
			"transaction": _transaction_snapshot(transaction),
		}
	var precommit_sha256 := _file_sha256(target_path)
	if precommit_sha256 != written_sha256:
		var precommit_rollback := _conditional_rollback(
			target_path, target_existed, written_sha256, transaction
		)
		_resync_shared_instance(target_path)
		return {
			"ok": false,
			"code": &"EXTERNAL_TARGET_MODIFIED",
			"error": "La cible a changé après vérification ; le contenu tiers est préservé.",
			"expected_sha256": written_sha256,
			"actual_sha256": precommit_sha256,
			"rollback": precommit_rollback,
			"transaction": _transaction_snapshot(transaction),
		}
	if not _record_transaction_status(transaction, &"COMMITTED", {
		"target_path": target_path,
		"written_sha256": written_sha256,
		"semantic_fingerprint": expected_fingerprint,
		"uid": staged_uid,
	}):
		var commit_journal_rollback := _conditional_rollback(
			target_path, target_existed, written_sha256, transaction
		)
		_resync_shared_instance(target_path)
		return {
			"ok": false,
			"code": &"COMMIT_JOURNAL_FAILED",
			"error": "Le commit n’a pas pu être journalisé ; la cible a été restaurée.",
			"rollback": commit_journal_rollback,
			"transaction": _transaction_snapshot(transaction),
		}
	_adopt_stored_properties(reloaded, written)
	if not defer_finalize:
		var finalized := finalize_commit(transaction)
		if finalized.get("code") == &"FINALIZE_EXTERNAL_CHANGE":
			_resync_shared_instance(target_path)
			return {
				"ok": false,
				"code": &"EXTERNAL_TARGET_MODIFIED",
				"error": finalized.get(
					"error", "La cible a changé avant finalisation."
				),
				"transaction": finalized.get(
					"transaction", _transaction_snapshot(transaction)
				),
			}
	return {
		"ok": true,
		"path": target_path,
		"resource": reloaded,
		"fingerprint": expected_fingerprint,
		"sha256": written_sha256,
		"uid": staged_uid,
		"plan": plan.to_snapshot(),
		"transaction": _transaction_snapshot(transaction),
		"transaction_pending_finalize": not bool(transaction.get("cleaned", false)),
	}


func finalize_commit(transaction: Dictionary) -> Dictionary:
	if str(transaction.get("last_status", "")) != "COMMITTED":
		return {
			"ok": false,
			"error": "Seule une transaction COMMITTED peut être finalisée.",
			"transaction": _transaction_snapshot(transaction),
		}
	var target_path := str(transaction.get("target_path", ""))
	var staged_sha256 := str(transaction.get("staged_sha256", ""))
	if _file_sha256(target_path) != staged_sha256:
		_reconcile_external_uid_mapping(
			target_path, str(transaction.get("staged_uid", ""))
		)
		return {
			"ok": false,
			"code": &"FINALIZE_EXTERNAL_CHANGE",
			"error": "La cible a changé avant la finalisation ; la récupération est conservée.",
			"transaction": _transaction_snapshot(transaction),
		}
	var cleaned := _cleanup_transaction(transaction)
	return {
		"ok": cleaned,
		"error": "Le dossier de transaction COMMITTED reste à nettoyer." \
			if not cleaned else "",
		"transaction": _transaction_snapshot(transaction),
	}


func rollback_committed(transaction: Dictionary) -> Dictionary:
	if str(transaction.get("last_status", "")) != "COMMITTED":
		return {
			"ok": false,
			"error": "La transaction n’est pas dans l’état COMMITTED.",
			"transaction": _transaction_snapshot(transaction),
		}
	var rollback := _conditional_rollback(
		str(transaction.get("target_path", "")),
		bool(transaction.get("target_existed", false)),
		str(transaction.get("staged_sha256", "")),
		transaction,
	)
	_resync_shared_instance(str(transaction.get("target_path", "")))
	rollback["transaction"] = _transaction_snapshot(transaction)
	return rollback


static func _is_owned_draft_target(
		document: ItemStudioDocument,
		target_path: String,
		catalog: ItemStudioCatalogService
	) -> bool:
	if document == null or document.working_copy == null \
			or target_path.is_empty() or not FileAccess.file_exists(target_path):
		return false
	var draft_directory := catalog.draft_directory if catalog != null \
		else ItemStudioCatalogService.DRAFT_DIRECTORY
	if not ItemStudioCatalogService.path_is_within_directory(
		target_path, draft_directory
	):
		return false
	return _is_same_item_target(document, target_path)


static func _is_same_item_target(
		document: ItemStudioDocument,
		target_path: String
	) -> bool:
	if document == null or document.working_copy == null \
			or target_path.is_empty() or not FileAccess.file_exists(target_path):
		return false
	var existing := ResourceLoader.load(
		target_path, "", ResourceLoader.CACHE_MODE_IGNORE
	) as ItemDefinition
	return existing != null and existing.item_id == document.working_copy.item_id


func _detect_external_change(entry: ItemSavePlanEntry) -> Dictionary:
	var target_path := entry.destination_path
	var target_exists := FileAccess.file_exists(target_path)
	if entry.operation == &"CREATE":
		if target_exists:
			return {
				"code": &"EXTERNAL_TARGET_CREATED",
				"message": "La cible a été créée hors du Studio depuis la revue du plan.",
				"actual_fingerprint": _disk_fingerprint(target_path),
				"actual_sha256": _file_sha256(target_path),
			}
		return {}
	if entry.operation != &"UPDATE":
		return {
			"code": &"SAVE_OPERATION_UNKNOWN",
			"message": "L’opération de sauvegarde n’est pas reconnue.",
		}
	if not target_exists:
		return {
			"code": &"EXTERNAL_TARGET_DELETED",
			"message": "La cible a été supprimée hors du Studio depuis son ouverture.",
		}
	var actual_fingerprint := _disk_fingerprint(target_path)
	if actual_fingerprint.is_empty():
		return {
			"code": &"EXTERNAL_TARGET_UNREADABLE",
			"message": "La cible existe mais ne peut plus être relue comme ItemDefinition.",
		}
	var actual_sha256 := _file_sha256(target_path)
	if not entry.old_sha256.is_empty() and actual_sha256 != entry.old_sha256:
		return {
			"code": &"EXTERNAL_TARGET_MODIFIED",
			"message": "Les octets de la cible ont changé hors du Studio ; rechargez-la.",
			"expected_sha256": entry.old_sha256,
			"actual_sha256": actual_sha256,
		}
	if actual_fingerprint != entry.old_fingerprint:
		return {
			"code": &"EXTERNAL_TARGET_MODIFIED",
			"message": "La cible a été modifiée hors du Studio ; rechargez-la.",
			"expected_fingerprint": entry.old_fingerprint,
			"actual_fingerprint": actual_fingerprint,
		}
	var actual_uid := _uid_text(_resource_uid(target_path))
	if not entry.target_uid.is_empty() and actual_uid != entry.target_uid:
		return {
			"code": &"EXTERNAL_TARGET_UID_CHANGED",
			"message": "L’UID canonique de la cible a changé hors du Studio.",
			"expected_uid": entry.target_uid,
			"actual_uid": actual_uid,
		}
	return {}


func _begin_transaction(entry: ItemSavePlanEntry, nonce: int) -> Dictionary:
	var safe_root := transaction_root.trim_suffix("/")
	if not _is_safe_transaction_root(safe_root):
		return {
			"ok": false,
			"code": &"RECOVERY_ROOT_INVALID",
			"error": "Le dossier des transactions Item n’est pas un user:// canonique.",
		}
	var root_error := DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(safe_root)
	)
	if root_error != OK:
		return {
			"ok": false,
			"code": &"RECOVERY_ROOT_FAILED",
			"error": "Le dossier racine des transactions est inaccessible : %s" % root_error,
		}
	var safe_id := str(entry.item_id).validate_filename()
	if safe_id.is_empty():
		safe_id = "item"
	var transaction_id := "%s_%d" % [safe_id, nonce]
	var directory := safe_root.path_join(transaction_id)
	var suffix := 0
	while DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(directory)):
		suffix += 1
		transaction_id = "%s_%d_%d" % [safe_id, nonce, suffix]
		directory = safe_root.path_join(transaction_id)
	var directory_error := DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(directory)
	)
	if directory_error != OK:
		return {
			"ok": false,
			"code": &"RECOVERY_DIRECTORY_FAILED",
			"error": "Le dossier de transaction est inaccessible : %s" % directory_error,
			"directory": directory,
		}
	return {
		"ok": true,
		"id": transaction_id,
		"transaction_root": safe_root,
		"directory": directory,
		"manifest_path": directory.path_join(TRANSACTION_MANIFEST_FILE),
		"stage_path": directory.path_join(STAGED_RESOURCE_FILE),
		"target_path": entry.destination_path,
		"target_existed": entry.operation == &"UPDATE",
		"original_sha256": "",
		"original_uid": entry.target_uid,
		"staged_sha256": "",
		"staged_uid": "",
		"generated_stage_uid": "",
		"backup_path": "",
		"status_sequence": 0,
		"last_status": "OPEN",
		"last_status_path": "",
		"cleaned": false,
	}


func _prepare_recovery(
		entry: ItemSavePlanEntry,
		transaction: Dictionary
	) -> Dictionary:
	var target_path := entry.destination_path
	var target_existed := FileAccess.file_exists(target_path)
	if target_existed != (entry.operation == &"UPDATE"):
		return {
			"ok": false,
			"code": &"EXTERNAL_STATE_CHANGED",
			"error": "La présence de la cible a changé pendant le staging.",
		}
	var original_sha256 := ""
	var durable_backup_path := ""
	if target_existed:
		original_sha256 = _file_sha256(target_path)
		if original_sha256.is_empty() \
				or (not entry.old_sha256.is_empty() \
				and original_sha256 != entry.old_sha256):
			return {
				"ok": false,
				"code": &"RECOVERY_SOURCE_CHANGED",
				"error": "L’original a changé avant sa copie de récupération.",
			}
		durable_backup_path = str(transaction.get("directory", "")).path_join(
			ORIGINAL_RESOURCE_FILE
		)
		var copy_error := DirAccess.copy_absolute(
			ProjectSettings.globalize_path(target_path),
			ProjectSettings.globalize_path(durable_backup_path),
		)
		if copy_error != OK \
				or _file_sha256(durable_backup_path) != original_sha256 \
				or _file_sha256(target_path) != original_sha256:
			return {
				"ok": false,
				"code": &"RECOVERY_BACKUP_FAILED",
				"error": "La copie durable de l’original n’a pas pu être vérifiée.",
			}
	transaction["target_existed"] = target_existed
	transaction["original_sha256"] = original_sha256
	transaction["original_uid"] = _uid_text(_resource_uid(target_path)) \
		if target_existed else ""
	transaction["backup_path"] = durable_backup_path
	var manifest := {
		"schema_version": 2,
		"transaction_id": transaction.get("id", ""),
		"status": "PREPARED",
		"created_at": Time.get_datetime_string_from_system(true),
		"target_path": target_path,
		"operation": str(entry.operation),
		"target_existed": target_existed,
		"original_sha256": original_sha256,
		"original_uid": transaction.get("original_uid", ""),
		"staged_sha256": transaction.get("staged_sha256", ""),
		"staged_uid": transaction.get("staged_uid", ""),
		"backup_path": durable_backup_path,
		"stage_path": transaction.get("stage_path", ""),
		"source_path": entry.source_path,
		"source_sha256": entry.source_sha256,
	}
	if not _store_json_record(
		str(transaction.get("manifest_path", "")), manifest
	):
		return {
			"ok": false,
			"code": &"RECOVERY_MANIFEST_FAILED",
			"error": "Le manifeste PREPARED n’a pas pu être écrit et relu.",
		}
	transaction["last_status"] = "PREPARED"
	transaction["last_status_path"] = transaction.get("manifest_path", "")
	return {"ok": true}


func _detect_post_recovery_change(
		entry: ItemSavePlanEntry,
		transaction: Dictionary
	) -> Dictionary:
	var semantic_conflict := _detect_external_change(entry)
	if not semantic_conflict.is_empty():
		return semantic_conflict
	var target_path := entry.destination_path
	var expected_exists := bool(transaction.get("target_existed", false))
	var actual_exists := FileAccess.file_exists(target_path)
	if actual_exists != expected_exists:
		return {
			"code": &"EXTERNAL_STATE_CHANGED",
			"message": "La présence de la cible a changé pendant la récupération.",
			"expected_exists": expected_exists,
			"actual_exists": actual_exists,
		}
	if actual_exists:
		var actual_sha256 := _file_sha256(target_path)
		var expected_sha256 := str(transaction.get("original_sha256", ""))
		if actual_sha256 != expected_sha256:
			return {
				"code": &"EXTERNAL_TARGET_MODIFIED",
				"message": "Les octets de la cible ont changé pendant la récupération.",
				"expected_sha256": expected_sha256,
				"actual_sha256": actual_sha256,
			}
	return {}


func _conditional_rollback(
		target_path: String,
		target_existed: bool,
		owned_written_sha256: String,
		transaction: Dictionary
	) -> Dictionary:
	var original_sha256 := str(transaction.get("original_sha256", ""))
	var durable_backup_path := str(transaction.get("backup_path", ""))
	var current_sha256 := _file_sha256(target_path)
	if target_existed and not current_sha256.is_empty() \
			and current_sha256 == original_sha256:
		var recorded_already := _record_transaction_status(
			transaction, &"ROLLED_BACK", {"action": "original_already_present"}
		)
		if recorded_already:
			_cleanup_transaction(transaction)
		return {
			"ok": true,
			"restored": true,
			"action": "original_already_present",
			"cleaned": bool(transaction.get("cleaned", false)),
		}
	if not current_sha256.is_empty():
		if owned_written_sha256.is_empty() or current_sha256 != owned_written_sha256:
			_reconcile_external_uid_mapping(
				target_path, str(transaction.get("staged_uid", ""))
			)
			_record_transaction_status(
				transaction, &"ROLLBACK_SKIPPED_EXTERNAL_CHANGE", {
					"target_path": target_path,
					"expected_owned_sha256": owned_written_sha256,
					"actual_sha256": current_sha256,
				}
			)
			return {
				"ok": false,
				"restored": false,
				"skipped_external_change": true,
				"expected_owned_sha256": owned_written_sha256,
				"actual_sha256": current_sha256,
				"recovery_path": durable_backup_path,
			}
		var remove_error := DirAccess.remove_absolute(
			ProjectSettings.globalize_path(target_path)
		)
		if remove_error != OK:
			_record_transaction_status(transaction, &"ROLLBACK_FAILED", {
				"step": "remove_owned_write", "code": remove_error,
			})
			return {
				"ok": false,
				"restored": false,
				"error": "La cible écrite par le Studio n’a pas pu être retirée.",
				"recovery_path": durable_backup_path,
			}
		_clear_owned_uid_mapping(
			target_path,
			str(transaction.get("staged_uid", "")),
			str(transaction.get("original_uid", "")),
		)
	if FileAccess.file_exists(target_path):
		_reconcile_external_uid_mapping(
			target_path, str(transaction.get("staged_uid", ""))
		)
		_record_transaction_status(
			transaction, &"ROLLBACK_SKIPPED_EXTERNAL_CHANGE", {
				"target_path": target_path,
				"actual_sha256": _file_sha256(target_path),
			}
		)
		return {
			"ok": false,
			"restored": false,
			"skipped_external_change": true,
			"recovery_path": durable_backup_path,
		}
	if target_existed:
		if durable_backup_path.is_empty() \
				or _file_sha256(durable_backup_path) != original_sha256:
			_record_transaction_status(transaction, &"ROLLBACK_FAILED", {
				"step": "durable_backup_verification",
			})
			return {
				"ok": false,
				"restored": false,
				"error": "La récupération originale est indisponible ou altérée.",
				"recovery_path": durable_backup_path,
			}
		var restore_error := DirAccess.copy_absolute(
			ProjectSettings.globalize_path(durable_backup_path),
			ProjectSettings.globalize_path(target_path),
		)
		var restored_sha256 := _file_sha256(target_path)
		if restore_error != OK or restored_sha256 != original_sha256:
			var external_appeared := not restored_sha256.is_empty() \
				and restored_sha256 != original_sha256
			_record_transaction_status(
				transaction,
				&"ROLLBACK_SKIPPED_EXTERNAL_CHANGE" \
					if external_appeared else &"ROLLBACK_FAILED",
				{
					"step": "restore_original",
					"code": restore_error,
					"actual_sha256": restored_sha256,
				},
			)
			return {
				"ok": false,
				"restored": false,
				"skipped_external_change": external_appeared,
				"error": "L’original n’a pas pu être restauré sans ambiguïté.",
				"actual_sha256": restored_sha256,
				"recovery_path": durable_backup_path,
			}
		if not _sync_uid_mapping(
			target_path, str(transaction.get("original_uid", ""))
		):
			_record_transaction_status(transaction, &"ROLLBACK_FAILED", {
				"step": "restore_uid",
			})
			return {
				"ok": false,
				"restored": false,
				"error": "L’UID original n’a pas pu être restauré.",
				"recovery_path": durable_backup_path,
			}
	var recorded := _record_transaction_status(transaction, &"ROLLED_BACK", {
		"target_path": target_path,
		"restored_sha256": _file_sha256(target_path),
	})
	if recorded:
		_cleanup_transaction(transaction)
	return {
		"ok": true,
		"restored": target_existed,
		"removed_created_target": not target_existed,
		"cleaned": bool(transaction.get("cleaned", false)),
		"recovery_path": "" if bool(transaction.get("cleaned", false)) \
			else durable_backup_path,
	}


func _record_transaction_status(
		transaction: Dictionary,
		status: StringName,
		details := {}
	) -> bool:
	var sequence := int(transaction.get("status_sequence", 0)) + 1
	var status_text := str(status)
	var filename := "status_%03d_%s.json" % [
		sequence, status_text.to_lower().validate_filename(),
	]
	var status_path := str(transaction.get("directory", "")).path_join(filename)
	var record := {
		"schema_version": 2,
		"transaction_id": transaction.get("id", ""),
		"sequence": sequence,
		"status": status_text,
		"recorded_at": Time.get_datetime_string_from_system(true),
		"details": details,
	}
	if not _store_json_record(status_path, record):
		return false
	transaction["status_sequence"] = sequence
	transaction["last_status"] = status_text
	transaction["last_status_path"] = status_path
	return true


func _cleanup_transaction(transaction: Dictionary) -> bool:
	if bool(transaction.get("cleaned", false)):
		return true
	var safe_root := str(transaction.get("transaction_root", "")).trim_suffix("/")
	var directory := str(transaction.get("directory", ""))
	if not _is_safe_transaction_root(safe_root) \
			or directory.is_empty() \
			or directory.get_base_dir() != safe_root \
			or not directory.begins_with(safe_root + "/"):
		return false
	var absolute_directory := ProjectSettings.globalize_path(directory)
	_remove_uid_mapping_for_path(
		str(transaction.get("stage_path", "")),
		str(transaction.get("generated_stage_uid", "")),
	)
	_remove_uid_mapping_for_path(
		str(transaction.get("stage_path", "")),
		str(transaction.get("staged_uid", "")),
	)
	if not DirAccess.dir_exists_absolute(absolute_directory):
		transaction["cleaned"] = true
		return true
	var access := DirAccess.open(directory)
	if access == null or not access.get_directories().is_empty():
		return false
	for filename in access.get_files():
		var path := directory.path_join(filename)
		if DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) != OK:
			return false
	if DirAccess.remove_absolute(absolute_directory) != OK:
		return false
	transaction["cleaned"] = true
	return true


static func _store_json_record(path: String, record: Dictionary) -> bool:
	if path.is_empty() or FileAccess.file_exists(path):
		return false
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(record, "  "))
	file.flush()
	file.close()
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed is Dictionary \
		and str((parsed as Dictionary).get("transaction_id", "")) \
		== str(record.get("transaction_id", "")) \
		and str((parsed as Dictionary).get("status", "")) \
		== str(record.get("status", ""))


static func _is_safe_transaction_root(path: String) -> bool:
	return path.begins_with("user://") \
		and path != "user://" \
		and not path.contains("\\") \
		and path == path.simplify_path()


static func _disk_fingerprint(path: String) -> String:
	var disk_resource := ResourceLoader.load(
		path, "", ResourceLoader.CACHE_MODE_IGNORE
	) as ItemDefinition
	return ItemFingerprintService.semantic_fingerprint(disk_resource) \
		if disk_resource != null else ""


static func _file_sha256(path: String) -> String:
	return FileAccess.get_sha256(path) if not path.is_empty() \
		and FileAccess.file_exists(path) else ""


static func _resource_uid(path: String) -> int:
	if path.is_empty() or not FileAccess.file_exists(path):
		return ResourceUID.INVALID_ID
	# L'en-tête est l'autorité pour les .tres. ResourceLoader peut conserver une
	# valeur négative ou antérieure après set_uid(), notamment sous user://.
	var serialized_uid := _serialized_text_uid(path)
	if serialized_uid != ResourceUID.INVALID_ID:
		return serialized_uid
	return ResourceLoader.get_resource_uid(path)


static func _serialized_text_uid(path: String) -> int:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ResourceUID.INVALID_ID
	var header := file.get_line()
	file.close()
	var marker := "uid=\""
	var marker_index := header.find(marker)
	if marker_index < 0:
		return ResourceUID.INVALID_ID
	var value_start := marker_index + marker.length()
	var value_end := header.find("\"", value_start)
	if value_end < 0:
		return ResourceUID.INVALID_ID
	return ResourceUID.text_to_id(header.substr(
		value_start, value_end - value_start
	))


static func _ensure_serialized_text_uid(path: String, uid: int) -> bool:
	if uid == ResourceUID.INVALID_ID or not FileAccess.file_exists(path):
		return false
	var content := FileAccess.get_file_as_string(path)
	var line_end := content.find("\n")
	var header := content.substr(0, line_end) if line_end >= 0 else content
	if not header.begins_with("[gd_resource"):
		return false
	var uid_text := ResourceUID.id_to_text(uid)
	var marker := "uid=\""
	var marker_index := header.find(marker)
	if marker_index >= 0:
		var value_start := marker_index + marker.length()
		var value_end := header.find("\"", value_start)
		if value_end < 0:
			return false
		header = header.substr(0, value_start) + uid_text + header.substr(value_end)
	else:
		var closing_bracket := header.rfind("]")
		if closing_bracket < 0:
			return false
		header = header.substr(0, closing_bracket) \
			+ " uid=\"%s\"" % uid_text \
			+ header.substr(closing_bracket)
	var rewritten := header + content.substr(line_end) \
		if line_end >= 0 else header
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(rewritten)
	file.flush()
	file.close()
	return _serialized_text_uid(path) == uid


static func _uid_text(uid: int) -> String:
	return ResourceUID.id_to_text(uid) if uid != ResourceUID.INVALID_ID else ""


static func _release_stage_uid_mapping(
		stage_path: String,
		uid_text: String,
		target_path: String
	) -> bool:
	if uid_text.is_empty():
		return true
	var uid := ResourceUID.text_to_id(uid_text)
	if uid == ResourceUID.INVALID_ID:
		return false
	if not ResourceUID.has_id(uid):
		return true
	var mapped_path := ResourceUID.get_id_path(uid)
	if mapped_path == target_path:
		return true
	if mapped_path != stage_path:
		return false
	ResourceUID.remove_id(uid)
	return not ResourceUID.has_id(uid)


static func _sync_uid_mapping(path: String, uid_text: String) -> bool:
	if uid_text.is_empty():
		return _resource_uid(path) == ResourceUID.INVALID_ID
	var uid := ResourceUID.text_to_id(uid_text)
	if uid == ResourceUID.INVALID_ID:
		return false
	if ResourceUID.has_id(uid):
		ResourceUID.set_id(uid, path)
	else:
		ResourceUID.add_id(uid, path)
	return _resource_uid(path) == uid and ResourceUID.get_id_path(uid) == path


static func _clear_owned_uid_mapping(
		path: String,
		owned_uid_text: String,
		restored_uid_text: String
	) -> void:
	if owned_uid_text.is_empty() or owned_uid_text == restored_uid_text:
		return
	var uid := ResourceUID.text_to_id(owned_uid_text)
	if uid != ResourceUID.INVALID_ID \
			and ResourceUID.has_id(uid) \
			and ResourceUID.get_id_path(uid) == path:
		ResourceUID.remove_id(uid)


static func _remove_uid_mapping_for_path(path: String, uid_text: String) -> void:
	if path.is_empty() or uid_text.is_empty():
		return
	var uid := ResourceUID.text_to_id(uid_text)
	if uid != ResourceUID.INVALID_ID \
			and ResourceUID.has_id(uid) \
			and ResourceUID.get_id_path(uid) == path:
		ResourceUID.remove_id(uid)


static func _reconcile_external_uid_mapping(
		path: String,
		owned_uid_text: String
	) -> void:
	var actual_uid := _resource_uid(path)
	var owned_uid := ResourceUID.text_to_id(owned_uid_text) \
		if not owned_uid_text.is_empty() else ResourceUID.INVALID_ID
	if owned_uid != ResourceUID.INVALID_ID \
			and owned_uid != actual_uid \
			and ResourceUID.has_id(owned_uid) \
			and ResourceUID.get_id_path(owned_uid) == path:
		ResourceUID.remove_id(owned_uid)
	if actual_uid == ResourceUID.INVALID_ID:
		return
	if ResourceUID.has_id(actual_uid):
		ResourceUID.set_id(actual_uid, path)
	else:
		ResourceUID.add_id(actual_uid, path)


static func _transaction_snapshot(transaction: Dictionary) -> Dictionary:
	var backup_path := str(transaction.get("backup_path", ""))
	return {
		"id": transaction.get("id", ""),
		"transaction_root": transaction.get("transaction_root", ""),
		"directory": transaction.get("directory", ""),
		"manifest_path": transaction.get("manifest_path", ""),
		"stage_path": transaction.get("stage_path", ""),
		"recovery_path": backup_path if not backup_path.is_empty() \
			else transaction.get("directory", ""),
		"backup_path": backup_path,
		"target_path": transaction.get("target_path", ""),
		"target_existed": transaction.get("target_existed", false),
		"original_sha256": transaction.get("original_sha256", ""),
		"original_uid": transaction.get("original_uid", ""),
		"staged_sha256": transaction.get("staged_sha256", ""),
		"staged_uid": transaction.get("staged_uid", ""),
		"generated_stage_uid": transaction.get("generated_stage_uid", ""),
		"status_sequence": transaction.get("status_sequence", 0),
		"last_status": transaction.get("last_status", ""),
		"last_status_path": transaction.get("last_status_path", ""),
		"cleaned": transaction.get("cleaned", false),
	}


static func _conflict_result(
		code: StringName,
		message: String,
		path: String,
		plan: ItemSavePlan,
		details := {}
	) -> Dictionary:
	var conflict := {
		"code": code,
		"message": message,
		"path": path,
	}
	conflict.merge(details, true)
	return {
		"ok": false,
		"code": code,
		"error": message,
		"conflict": conflict,
		"plan": plan.to_snapshot() if plan != null else {},
	}


static func _stage_failure(
		code: StringName,
		message: String,
		transaction: Dictionary
	) -> Dictionary:
	return {
		"ok": false,
		"code": code,
		"error": message,
		"transaction": _transaction_snapshot(transaction),
	}


static func _resync_shared_instance(target_path: String) -> void:
	if target_path.is_empty() or not FileAccess.file_exists(target_path):
		return
	var cached := ResourceLoader.load(
		target_path, "", ResourceLoader.CACHE_MODE_REPLACE
	)
	var restored := ResourceLoader.load(
		target_path, "", ResourceLoader.CACHE_MODE_IGNORE
	)
	if cached != null and restored != null:
		_adopt_stored_properties(cached, restored)


static func _adopt_stored_properties(target: Resource, source: Resource) -> void:
	if target == null or source == null or target == source:
		return
	for property_value in source.get_property_list():
		var property := property_value as Dictionary
		var property_name := str(property.get("name", ""))
		if property_name in [
			"resource_local_to_scene", "resource_name", "resource_path", "script",
		] or not (int(property.get("usage", 0)) & PROPERTY_USAGE_STORAGE):
			continue
		target.set(property_name, source.get(property_name))
