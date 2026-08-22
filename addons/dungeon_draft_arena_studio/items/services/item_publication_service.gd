@tool
class_name ItemPublicationService
extends RefCounted

var path_service := ItemIdPathService.new()
var save_service := ItemTransactionalSaveService.new()


func plan(
		document: ItemStudioDocument,
		catalog: ItemStudioCatalogService,
		reward_tag_changed := false
	) -> ItemSavePlan:
	var target := document.destination_path
	if target.is_empty() or not catalog.is_path_auto_discovered(target):
		target = path_service.shared_path(document.working_copy.item_id, catalog)
	return save_service.build_plan(document, target, ItemStudioDocument.STATUS_SHARED, catalog, reward_tag_changed)


func publish(
		document: ItemStudioDocument,
		catalog: ItemStudioCatalogService,
		reward_tag_changed := false
	) -> Dictionary:
	var save_plan := plan(document, catalog, reward_tag_changed)
	var result := save_service.execute(save_plan, document)
	if not result.get("ok", false):
		return result
	var rebuilt := catalog.rebuild()
	if not rebuilt.get("ok", false):
		return {"ok": false, "error": "Le catalogue est invalide après publication."}
	var reloaded := result.get("resource") as ItemDefinition
	var occurrences := 0
	for definition in catalog.production_definitions():
		if definition != null and definition.item_id == reloaded.item_id:
			occurrences += 1
	if occurrences != 1:
		return {"ok": false, "error": "L’objet publié apparaît %d fois au catalogue." % occurrences}
	document.mark_saved(reloaded, ItemStudioDocument.STATUS_SHARED, reloaded.resource_path)
	result["catalog_occurrences"] = occurrences
	result["reward_eligible"] = catalog.reward_eligible(reloaded)
	result["draft_removed"] = _remove_stale_draft(reloaded, catalog)
	return result


func _remove_stale_draft(published: ItemDefinition, catalog: ItemStudioCatalogService) -> bool:
	# Une fois publié, l'objet existe en production ; son brouillon éventuel
	# (même item_id, sous le dossier de brouillons) ne sert plus qu'à provoquer
	# ITEM_ID_DUPLICATE à la prochaine ouverture. On le retire du disque.
	var draft_directory := catalog.draft_directory if catalog != null else ItemStudioCatalogService.DRAFT_DIRECTORY
	var draft_path := path_service.draft_path(published.item_id, draft_directory)
	if draft_path == published.resource_path or not FileAccess.file_exists(draft_path):
		return false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(draft_path))
	return true


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
