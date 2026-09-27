extends Node
const Content := preload("res://core/expedition/consumable_cards_content.gd")
const Catalog := preload("res://core/expedition/consumable_card_catalog.gd")
const ROOT := "res://data/cards/consumable_v2"


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var failures: Array = []
	var maps := 0
	var items := 0
	for id in Catalog.data().maps:
		var arena := Content.arena(id, true)
		var report := ArenaValidator.validate(arena, false)
		if not report.is_valid():
			for message in report.messages:
				if message.severity == ArenaValidationMessage.Severity.ERROR:
					failures.append("%s: %s" % [id, message.message])
			continue
		if ArenaSerializer.save_canonical(arena, ROOT.path_join("maps/cc2_" + str(id) + ".tres")) != OK:
			failures.append("map_write:" + str(id))
		else:
			maps += 1
	var catalog := Content.items(true)
	if catalog == null:
		failures.append("catalog_invalid")
	else:
		var saved := ItemCatalog.new()
		var writer := ItemTransactionalSaveService.new()
		for definition in catalog.get_definitions():
			var path := ROOT.path_join("items/" + str(definition.item_id) + ".tres")
			var document := ItemStudioDocument.new()
			if ResourceLoader.exists(path):
				document.open_definition(load(path))
				document.working_copy = ItemDeepCopyService.new().duplicate_definition(definition)
			else:
				document.create_new(definition)
			var plan := writer.build_plan(document, path, ItemStudioDocument.STATUS_SHARED, null)
			var result := writer.execute(plan, document)
			document.history.configure(Callable(), Callable())
			for signal_name in ["history_changed", "dirty_state_changed"]:
				for connection in document.history.get_signal_connection_list(signal_name):
					document.history.disconnect(signal_name, connection.callable)
			document.history.clear()
			document.history.undo_redo.free()
			if not result.get("ok", false):
				failures.append("%s: %s" % [definition.item_id, result.get("error", "save_failed")])
			else:
				items += 1
				saved.definitions.append(
					ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
				)
		if items == 26 and ResourceSaver.save(saved, ROOT.path_join("item_catalog.tres")) != OK:
			failures.append("catalog_write")
	var output := {
		"maps": maps,
		"items": items,
		"failures": failures,
		"passed": failures.is_empty() and maps == 7 and items == 26,
	}
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path("res://artifacts/consumable_cards_v2")
	)
	var file := FileAccess.open(
		"res://artifacts/consumable_cards_v2/content_publication.json",
		FileAccess.WRITE,
	)
	file.store_string(JSON.stringify(output, "\t"))
	print(JSON.stringify(output))
	ArenaValidator.clear_cache()
	ArenaVisualAssembler.clear_inspection_cache()
	Content._arenas.clear()
	Content._items = null
	await get_tree().process_frame
	get_tree().quit(0 if output.passed else 1)
