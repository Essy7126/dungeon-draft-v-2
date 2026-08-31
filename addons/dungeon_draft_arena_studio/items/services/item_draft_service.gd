@tool
class_name ItemDraftService
extends RefCounted

var path_service := ItemIdPathService.new()
var save_service := ItemTransactionalSaveService.new()


func plan(document: ItemStudioDocument, catalog: ItemStudioCatalogService) -> ItemSavePlan:
	return save_service.build_plan(
		document, target_path(document, catalog), ItemStudioDocument.STATUS_DRAFT, catalog
	)


func target_path(document: ItemStudioDocument, catalog: ItemStudioCatalogService) -> String:
	var target := document.destination_path if document != null else ""
	var draft_directory := catalog.draft_directory if catalog != null else ItemStudioCatalogService.DRAFT_DIRECTORY
	if target.is_empty() or not ItemStudioCatalogService.path_is_within_directory(
		target, draft_directory
	):
		var item_id := document.working_copy.item_id \
			if document != null and document.working_copy != null else &""
		var safe_stem := path_service.normalize_item_id(str(item_id))
		if safe_stem.is_empty():
			safe_stem = "objet_sans_identifiant"
		target = draft_directory.path_join("%s.tres" % safe_stem)
	return target


func save_draft(
		document: ItemStudioDocument,
		catalog: ItemStudioCatalogService,
		confirmed_plan: ItemSavePlan = null,
		defer_finalize := false
	) -> Dictionary:
	var save_plan := confirmed_plan if confirmed_plan != null else plan(document, catalog)
	var result := save_service.execute(save_plan, document, true)
	if not result.get("ok", false):
		return result
	return _complete_saved_draft(
		result, document, catalog, defer_finalize
	)


func save_recovery_draft(
		document: ItemStudioDocument,
		catalog: ItemStudioCatalogService,
		defer_finalize := false
	) -> Dictionary:
	if document == null or document.working_copy == null:
		return {"ok": false, "error": "Aucun objet à récupérer."}
	var draft_directory := catalog.draft_directory if catalog != null \
		else ItemStudioCatalogService.DRAFT_DIRECTORY
	var stem := path_service.normalize_item_id(str(document.working_copy.item_id))
	if stem.is_empty():
		stem = "objet_sans_identifiant"
	var nonce := "%d_%d" % [int(Time.get_unix_time_from_system()), Time.get_ticks_usec()]
	var target := draft_directory.path_join("%s_recovery_%s.tres" % [stem, nonce])
	var save_plan := save_service.build_plan(
		document, target, ItemStudioDocument.STATUS_DRAFT, catalog
	)
	var result := save_service.execute(save_plan, document, true)
	if not result.get("ok", false):
		return result
	result["recovery"] = true
	return _complete_saved_draft(
		result, document, catalog, defer_finalize
	)


func _complete_saved_draft(
		result: Dictionary,
		document: ItemStudioDocument,
		catalog: ItemStudioCatalogService,
		defer_finalize := false
	) -> Dictionary:
	var reloaded := result.get("resource") as ItemDefinition
	if reloaded == null:
		return _failure_after_rollback(
			result, "Le brouillon écrit n’a pas pu être relu."
		)
	var rebuilt := catalog.rebuild()
	var discovered_in_production := catalog.production_definitions().any(func(definition):
		return definition != null and definition.resource_path == reloaded.resource_path
	)
	if not rebuilt.get("ok", false) or discovered_in_production:
		var failure := _failure_after_rollback(
			result,
			"Le brouillon a été découvert par le catalogue de production.",
		)
		catalog.rebuild()
		return failure
	if not defer_finalize:
		var finalized := save_service.finalize_commit(
			result.get("transaction", {}) as Dictionary
		)
		result["transaction"] = finalized.get(
			"transaction", result.get("transaction", {})
		)
		result["transaction_pending_finalize"] = not finalized.get("ok", false)
		if finalized.get("code") == &"FINALIZE_EXTERNAL_CHANGE":
			return _failure_after_rollback(
				result,
				str(finalized.get(
					"error", "La cible a changé avant finalisation."
				)),
			)
	document.mark_saved(reloaded, ItemStudioDocument.STATUS_DRAFT, reloaded.resource_path)
	result["not_in_production_catalog"] = true
	return result


func _failure_after_rollback(result: Dictionary, error: String) -> Dictionary:
	var transaction := result.get("transaction", {}) as Dictionary
	var rollback := save_service.rollback_committed(transaction)
	var response := {
		"ok": false,
		"error": error,
		"rollback": rollback,
		"transaction": rollback.get("transaction", transaction),
	}
	if rollback.get("ok", false):
		return response
	var target_path := str(result.get("path", ""))
	var owned_sha256 := str(result.get("sha256", ""))
	if not target_path.is_empty() \
			and not owned_sha256.is_empty() \
			and FileAccess.file_exists(target_path) \
			and FileAccess.get_sha256(target_path) == owned_sha256:
		response["owned_file_states"] = {
			target_path: {"exists": true, "sha256": owned_sha256},
		}
	return response
