extends Node


func _ready() -> void:
	var context := StudioProjectContext.new()
	var initialized := context.initialize("res://data/runs/first_run.tres", &"elf")
	if not initialized.get("ok", false):
		_fail("Contexte partagé impossible à initialiser.")
		return
	context.request_scope(StudioProjectContext.SCOPE_SHARED)
	var studio := DungeonDraftStudioMain.new()
	studio.setup(null, null, context, StudioReferenceGraphService.new())
	add_child(studio)
	studio.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await get_tree().process_frame
	await get_tree().process_frame
	if studio.tabs.get_tab_count() != 3 or studio.tabs.get_tab_title(2) != "OBJETS":
		_fail("L’onglet OBJETS n’est pas la troisième autorité du Studio.")
		return
	studio.tabs.current_tab = 2
	var item_studio := studio.item_studio
	var target := _entry(item_studio.catalog.entries(false), &"hache_executeur")
	if target.is_empty():
		_fail("Fixture hache_executeur absente du catalogue dynamique.")
		return
	item_studio._open_catalog_entry(target)
	await get_tree().process_frame
	var canonical := target.get("definition") as ItemDefinition
	var before := ItemFingerprintService.semantic_fingerprint(canonical)
	item_studio.document.record_edit(
		"Smoke : description",
		func(): item_studio.document.working_copy.description += " [working copy]"
	)
	var added_effect := ItemStatModifierData.new()
	added_effect.stat_id = &"initiative"
	added_effect.value = 1.0
	item_studio.document.record_edit(
		"Smoke : ajouter un effet",
		func(): item_studio.document.working_copy.stat_modifiers.append(added_effect)
	)
	if ItemFingerprintService.semantic_fingerprint(canonical) != before:
		_fail("La working copy a muté la ressource canonique.")
		return
	if not item_studio.history_undo() or not item_studio.history_redo():
		_fail("Historique Objets non fonctionnel.")
		return
	var draft_smoke := _draft_round_trip(canonical)
	if not draft_smoke.get("ok", false):
		_fail("Round-trip brouillon isolé : %s" % draft_smoke.get("error", "erreur"))
		return
	var validation := item_studio.validate_document()
	var analysis := item_studio.test_document()
	var state := studio.get_state_snapshot()
	if not state.has("items") or not validation.has("messages") or not analysis.get("ok", false):
		_fail("Validation, projection runtime ou persistance UI incomplète.")
		return
	print("ITEM_STUDIO_SMOKE_PASS|tabs=3|catalog=%d|item=%s|errors=%d|warnings=%d|runtime_heroes=%d|draft=%s" % [
		item_studio.catalog.production_definitions().size(),
		item_studio.document.working_copy.item_id,
		validation.get("errors", 0),
		validation.get("warnings", 0),
		(analysis.get("heroes", []) as Array).size(),
		draft_smoke.get("path", ""),
	])
	studio.prepare_for_close()
	studio.queue_free()
	await get_tree().process_frame
	get_tree().quit(0)


func _entry(entries: Array[Dictionary], item_id: StringName) -> Dictionary:
	for entry in entries:
		if StringName(entry.get("item_id", &"")) == item_id:
			return entry
	return {}


func _draft_round_trip(source: ItemDefinition) -> Dictionary:
	var root := "user://item_studio_smoke"
	var production := root + "/production"
	var drafts := root + "/drafts"
	var catalog_path := root + "/catalog.tres"
	for directory: String in [production, drafts]:
		var error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
		if error != OK:
			return {"ok": false, "error": error_string(error)}
	var catalog_resource := ItemCatalog.new()
	catalog_resource.auto_discovery_directories = PackedStringArray([production])
	var catalog_error := ResourceSaver.save(catalog_resource, catalog_path)
	if catalog_error != OK:
		return {"ok": false, "error": error_string(catalog_error)}
	var catalog := ItemStudioCatalogService.new()
	catalog.configure(catalog_path, drafts)
	if not catalog.rebuild().get("ok", false):
		return {"ok": false, "error": "catalogue fixture invalide"}
	var document := ItemStudioDocument.new()
	if not document.duplicate_as_new(source, &"smoke_draft", false):
		return {"ok": false, "error": "duplication impossible"}
	var result := ItemDraftService.new().save_draft(document, catalog)
	if not result.get("ok", false):
		return result
	var path := str(result.get("path", ""))
	var saved := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as ItemDefinition
	if saved == null or catalog.production_catalog.get_definition(&"smoke_draft") != null:
		return {"ok": false, "error": "brouillon découvert en production"}
	var fingerprint := ItemFingerprintService.semantic_fingerprint(saved)
	if fingerprint != str(result.get("fingerprint", "")):
		return {"ok": false, "error": "empreinte de relecture divergente"}
	return {"ok": true, "path": path, "fingerprint": fingerprint}


func _fail(message: String) -> void:
	push_error("ITEM_STUDIO_SMOKE_FAIL|%s" % message)
	get_tree().quit(1)
