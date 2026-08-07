@tool
class_name ItemDraftService
extends RefCounted

var path_service := ItemIdPathService.new()
var save_service := ItemTransactionalSaveService.new()


func plan(document: ItemStudioDocument, catalog: ItemStudioCatalogService) -> ItemSavePlan:
	var target := document.destination_path
	var draft_directory := catalog.draft_directory if catalog != null else ItemStudioCatalogService.DRAFT_DIRECTORY
	var normalized_draft_directory := draft_directory.trim_suffix("/")
	if target.is_empty() or not (target == normalized_draft_directory or target.begins_with(normalized_draft_directory + "/")):
		target = draft_directory.path_join("%s.tres" % document.working_copy.item_id)
	return save_service.build_plan(document, target, ItemStudioDocument.STATUS_DRAFT, catalog)


func save_draft(document: ItemStudioDocument, catalog: ItemStudioCatalogService) -> Dictionary:
	var save_plan := plan(document, catalog)
	var result := save_service.execute(save_plan, document)
	if not result.get("ok", false):
		return result
	var reloaded := result.get("resource") as ItemDefinition
	var rebuilt := catalog.rebuild()
	var discovered_in_production := catalog.production_definitions().any(func(definition):
		return definition != null and definition.resource_path == reloaded.resource_path
	)
	if not rebuilt.get("ok", false) or discovered_in_production:
		return {"ok": false, "error": "Le brouillon a été découvert par le catalogue de production."}
	document.mark_saved(reloaded, ItemStudioDocument.STATUS_DRAFT, reloaded.resource_path)
	result["not_in_production_catalog"] = true
	return result
