@tool
class_name ItemPublicationService
extends RefCounted

var path_service := ItemIdPathService.new()
var save_service := ItemTransactionalSaveService.new()
var before_draft_cleanup_hook := Callable()
var force_postcondition_failure := false


func plan(
		document: ItemStudioDocument,
		catalog: ItemStudioCatalogService,
		reward_tag_changed := false
	) -> ItemSavePlan:
	var target := target_path(document, catalog)
	return save_service.build_plan(document, target, ItemStudioDocument.STATUS_SHARED, catalog, reward_tag_changed)


func target_path(
		document: ItemStudioDocument,
		catalog: ItemStudioCatalogService
	) -> String:
	var target := document.destination_path if document != null else ""
	if document != null and document.working_copy != null \
			and (target.is_empty() or not catalog.is_path_auto_discovered(target)):
		target = path_service.shared_path(document.working_copy.item_id, catalog)
	return target


func publish(
		document: ItemStudioDocument,
		catalog: ItemStudioCatalogService,
		reward_tag_changed := false,
		confirmed_plan: ItemSavePlan = null,
		defer_finalize := false
	) -> Dictionary:
	var draft_source_path := ""
	var draft_source_sha256 := ""
	var draft_source_fingerprint := ""
	if document != null and document.status == ItemStudioDocument.STATUS_DRAFT:
		draft_source_path = document.source_path
		draft_source_sha256 = document.original_file_sha256
		draft_source_fingerprint = document.original_fingerprint
	var save_plan := confirmed_plan if confirmed_plan != null \
		else plan(document, catalog, reward_tag_changed)
	var result := save_service.execute(save_plan, document, true)
	if not result.get("ok", false):
		return result
	result["draft_source_path"] = draft_source_path
	result["draft_source_sha256"] = draft_source_sha256
	result["draft_source_fingerprint"] = draft_source_fingerprint
	var rebuilt := catalog.rebuild()
	if force_postcondition_failure or not rebuilt.get("ok", false):
		return _abort_publication(
			result, document, catalog,
			"Le catalogue est invalide après publication."
		)
	var reloaded := result.get("resource") as ItemDefinition
	if reloaded == null:
		return _abort_publication(
			result, document, catalog,
			"La ressource publiée n’a pas pu être relue."
		)
	var occurrences := 0
	for definition in catalog.production_definitions():
		if definition != null and definition.item_id == reloaded.item_id:
			occurrences += 1
	if occurrences != 1:
		return _abort_publication(
			result, document, catalog,
			"L’objet publié apparaît %d fois au catalogue." % occurrences
		)
	if not defer_finalize:
		var finalized := save_service.finalize_commit(
			result.get("transaction", {}) as Dictionary
		)
		result["transaction"] = finalized.get(
			"transaction", result.get("transaction", {})
		)
		result["transaction_pending_finalize"] = not finalized.get("ok", false)
		if finalized.get("code") == &"FINALIZE_EXTERNAL_CHANGE":
			return _abort_publication(
				result, document, catalog,
				str(finalized.get("error", "La cible a changé avant finalisation."))
			)
	document.mark_saved(reloaded, ItemStudioDocument.STATUS_SHARED, reloaded.resource_path)
	result["catalog_occurrences"] = occurrences
	result["reward_eligible"] = catalog.reward_eligible(reloaded)
	result["draft_removed"] = false
	result["draft_cleanup_deferred"] = defer_finalize and not draft_source_path.is_empty()
	if not defer_finalize:
		if before_draft_cleanup_hook.is_valid():
			before_draft_cleanup_hook.call(draft_source_path)
		result["draft_removed"] = _remove_stale_draft(
			reloaded, catalog, draft_source_path,
			draft_source_sha256, draft_source_fingerprint,
		)
		result["draft_preserved_external_change"] = not draft_source_path.is_empty() \
			and FileAccess.file_exists(draft_source_path) \
			and not result.get("draft_removed", false)
	return result


func cleanup_deferred_draft(
		result: Dictionary,
		catalog: ItemStudioCatalogService
	) -> bool:
	var published := result.get("resource") as ItemDefinition
	if published == null:
		return false
	var draft_source_path := str(result.get("draft_source_path", ""))
	if before_draft_cleanup_hook.is_valid():
		before_draft_cleanup_hook.call(draft_source_path)
	return _remove_stale_draft(
		published,
		catalog,
		draft_source_path,
		str(result.get("draft_source_sha256", "")),
		str(result.get("draft_source_fingerprint", "")),
	)


func _abort_publication(
		result: Dictionary,
		document: ItemStudioDocument,
		catalog: ItemStudioCatalogService,
		error: String
	) -> Dictionary:
	var transaction := result.get("transaction", {}) as Dictionary
	var rollback := save_service.rollback_committed(transaction)
	catalog.rebuild()
	var response := {
		"ok": false,
		"error": error,
		"rollback": rollback,
		"transaction": rollback.get("transaction", transaction),
	}
	if not rollback.get("ok", false):
		var target_path := str(result.get("path", ""))
		var owned_sha256 := str(result.get("sha256", ""))
		if not owned_sha256.is_empty() \
				and FileAccess.file_exists(target_path) \
				and FileAccess.get_sha256(target_path) == owned_sha256:
			# Le coordinateur multi-domaine peut alors restaurer ce chemin sans
			# confondre l’écriture Item avec une écriture externe.
			response["owned_file_states"] = {
				target_path: {"exists": true, "sha256": owned_sha256},
			}
			var adopted := ResourceLoader.load(
				target_path, "", ResourceLoader.CACHE_MODE_REPLACE
			) as ItemDefinition
			if adopted != null \
					and ItemFingerprintService.semantic_fingerprint(adopted) \
					== str(result.get("fingerprint", "")):
				document.mark_saved(
					adopted, ItemStudioDocument.STATUS_SHARED, target_path
				)
				response["adopted"] = true
	return response


func _remove_stale_draft(
		published: ItemDefinition,
		catalog: ItemStudioCatalogService,
		draft_source_path := "",
		expected_sha256 := "",
		expected_fingerprint := ""
	) -> bool:
	# Une fois publié, seul le brouillon effectivement ouvert est retiré. Les
	# autres récupérations du même objet peuvent être des versions concurrentes.
	var directories := catalog.draft_directories() if catalog != null \
		else PackedStringArray([ItemStudioCatalogService.DRAFT_DIRECTORY])
	if draft_source_path.is_empty() or draft_source_path == published.resource_path \
			or not FileAccess.file_exists(draft_source_path):
		return false
	var is_known_draft_path := false
	for draft_directory in directories:
		if ItemStudioCatalogService.path_is_within_directory(
			draft_source_path, str(draft_directory)
		):
			is_known_draft_path = true
			break
	if not is_known_draft_path:
		return false
	if expected_sha256.is_empty() \
			or FileAccess.get_sha256(draft_source_path) != expected_sha256:
		return false
	var draft := ResourceLoader.load(
		draft_source_path, "", ResourceLoader.CACHE_MODE_IGNORE
	) as ItemDefinition
	if draft == null or draft.item_id != published.item_id \
			or expected_fingerprint.is_empty() \
			or ItemFingerprintService.semantic_fingerprint(draft) \
			!= expected_fingerprint:
		return false
	return DirAccess.remove_absolute(
		ProjectSettings.globalize_path(draft_source_path)
	) == OK


func set_reward_eligibility(document: ItemStudioDocument, enabled: bool) -> bool:
	if document == null or document.working_copy == null \
			or not (document.working_copy.is_equippable() or document.working_copy.is_relic()):
		return false
	return document.record_edit(
		"Ajouter aux récompenses" if enabled else "Retirer des récompenses",
		func():
			if enabled and not document.working_copy.tags.has(FirstRunEquipmentRewardService.POOL_TAG):
				document.working_copy.tags.append(FirstRunEquipmentRewardService.POOL_TAG)
			elif not enabled:
				document.working_copy.tags.erase(FirstRunEquipmentRewardService.POOL_TAG)
	)


func eligibility_projection(document: ItemStudioDocument, catalog: ItemStudioCatalogService) -> Dictionary:
	var before := catalog.reward_eligible(document.source)
	var after := catalog.reward_eligible(document.working_copy)
	return {
		"before": before, "after": after,
		"tag": str(FirstRunEquipmentRewardService.POOL_TAG),
		"compatible_character_ids": document.working_copy.compatible_character_ids.duplicate(),
		"slot": int(document.working_copy.equipment_slot),
		"requires_publication_confirmation": before != after,
	}
