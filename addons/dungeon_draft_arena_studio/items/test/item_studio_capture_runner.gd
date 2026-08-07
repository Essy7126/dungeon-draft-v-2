extends Node

const OUTPUT_ROOT := "res://artifacts/item_studio/captures"
const CASES := [
	{"size": Vector2i(1280, 720), "file": "item_studio_1280x720.png", "mode": &"spell"},
	{"size": Vector2i(1920, 1080), "file": "item_studio_1920x1080.png", "mode": &"spell"},
	{"size": Vector2i(1920, 1080), "file": "item_studio_stat_modifiers.png", "mode": &"stat"},
	{"size": Vector2i(1920, 1080), "file": "item_studio_consumable.png", "mode": &"consumable"},
	{"size": Vector2i(1280, 720), "file": "item_studio_creation_dialog.png", "mode": &"creation"},
	{"size": Vector2i(1920, 1080), "file": "item_studio_publication_plan.png", "mode": &"publication"},
	{"size": Vector2i(1920, 1080), "file": "item_studio_validation_errors.png", "mode": &"invalid"},
	{"size": Vector2i(1920, 1080), "file": "item_studio_comparison.png", "mode": &"comparison"},
]

var metrics := {"schema_version": 1, "captures": [], "valid": true}


func _ready() -> void:
	var error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_ROOT))
	if error != OK:
		push_error("ITEM_STUDIO_CAPTURE_FAIL|directory=%s" % error_string(error))
		get_tree().quit(1)
		return
	for capture_case in CASES:
		await _capture(capture_case as Dictionary)
	_write_metrics()
	print("ITEM_STUDIO_CAPTURE_COMPLETE|%s|valid=%s" % [OUTPUT_ROOT, metrics.valid])
	get_tree().quit(0 if metrics.valid else 1)


func _capture(capture_case: Dictionary) -> void:
	var requested_size := capture_case.get("size", Vector2i(1280, 720)) as Vector2i
	DisplayServer.window_set_size(requested_size)
	await get_tree().process_frame
	var context := StudioProjectContext.new()
	context.initialize("res://data/runs/first_run.tres", &"elf")
	context.request_scope(StudioProjectContext.SCOPE_SHARED)
	var studio := DungeonDraftStudioMain.new()
	studio.setup(null, null, context, StudioReferenceGraphService.new())
	add_child(studio)
	studio.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await get_tree().process_frame
	await get_tree().process_frame
	studio.tabs.current_tab = 2
	var item_studio := studio.item_studio
	var mode := StringName(capture_case.get("mode", &"spell"))
	var selected_id := &"hache_executeur"
	if mode == &"stat":
		selected_id = &"harnois"
	elif mode == &"consumable":
		selected_id = &"minor_healing_potion"
	_open_item(item_studio, selected_id)
	await get_tree().process_frame
	await get_tree().process_frame
	_configure_case(item_studio, mode)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.25).timeout
	var image := get_viewport().get_texture().get_image()
	var file_name := str(capture_case.get("file", "capture.png"))
	var output_path := OUTPUT_ROOT.path_join(file_name)
	var save_error := ERR_CANT_CREATE if image == null or image.is_empty() \
		else image.save_png(ProjectSettings.globalize_path(output_path))
	var validation := item_studio.validate_document()
	metrics.captures.append({
		"file": output_path,
		"mode": str(mode),
		"requested_size": [requested_size.x, requested_size.y],
		"image_size": [image.get_width(), image.get_height()] if image != null else [0, 0],
		"save_error": error_string(save_error),
		"tab_count": studio.tabs.get_tab_count(),
		"active_tab": studio.tabs.get_tab_title(studio.tabs.current_tab),
		"catalog_count": item_studio.catalog.production_definitions().size(),
		"selected_item_id": str(item_studio.document.working_copy.item_id),
		"validation_errors": validation.get("errors", 0),
		"validation_warnings": validation.get("warnings", 0),
	})
	metrics.valid = metrics.valid and save_error == OK \
		and image != null and image.get_size() == requested_size \
		and studio.tabs.get_tab_count() == 3
	studio.prepare_for_close()
	studio.queue_free()
	await get_tree().process_frame


func _open_item(studio: ItemStudioMain, item_id: StringName) -> void:
	for entry in studio.catalog.entries(false):
		if StringName(entry.get("item_id", &"")) == item_id:
			studio._open_catalog_entry(entry)
			return


func _configure_case(studio: ItemStudioMain, mode: StringName) -> void:
	match mode:
		&"creation":
			studio.creation_dialog.open_dialog()
		&"publication":
			var projection := studio.publication_service.eligibility_projection(studio.document, studio.catalog)
			studio.save_plan_dialog.show_plan(studio.publication_service.plan(
				studio.document, studio.catalog,
				bool(projection.get("requires_publication_confirmation", false)),
			))
		&"invalid":
			studio.document.record_edit("Capture invalide", func():
				studio.document.working_copy.item_id = &""
				studio.document.working_copy.display_name = ""
			)
			studio._queue_refresh()
		&"comparison":
			for index in range(studio.comparison_option.item_count):
				if str(studio.comparison_option.get_item_metadata(index)).ends_with("/excalibur.tres"):
					studio.comparison_option.select(index)
					break
			studio._queue_refresh()
	await get_tree().process_frame


func _write_metrics() -> void:
	var file := FileAccess.open(OUTPUT_ROOT.path_join("capture_metrics.json"), FileAccess.WRITE)
	if file == null:
		metrics.valid = false
		return
	file.store_string(JSON.stringify(metrics, "  "))
	file.close()
