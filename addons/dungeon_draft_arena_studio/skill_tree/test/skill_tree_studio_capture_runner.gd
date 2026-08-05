extends Control

const OUTPUT := "res://artifacts/skill_tree_studio/screenshots"
const SIZES := [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440)]


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var metrics := {}
	var succeeded := true
	for requested_size in SIZES:
		get_window().size = requested_size
		var studio := SkillTreeStudioMain.new()
		studio.setup(null, null)
		studio.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(studio)
		for _frame in range(14):
			await get_tree().process_frame
		var key := "%dx%d" % [requested_size.x, requested_size.y]
		metrics[key] = {
			"characters": studio.heroes.size(),
			"discipline": str(studio.session.selected_discipline_id),
			"graph_nodes": studio.graph.get_children().filter(
				func(child): return child is GraphNode
			).size(),
			"catalog_width": studio.catalog.size.x,
			"inspector_width": studio.inspector.size.x,
			"bottom_height": studio.bottom.size.y,
		}
		var image := get_viewport().get_texture().get_image()
		var path := OUTPUT.path_join("skill_tree_studio_%s.png" % key)
		if image == null or image.is_empty() or image.save_png(
				ProjectSettings.globalize_path(path)
			) != OK:
			succeeded = false
		studio.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	var report := FileAccess.open(OUTPUT.path_join("capture_metrics.json"), FileAccess.WRITE)
	if report != null:
		report.store_string(JSON.stringify(metrics, "  "))
		report.close()
	else:
		succeeded = false
	get_tree().quit(0 if succeeded else 1)
