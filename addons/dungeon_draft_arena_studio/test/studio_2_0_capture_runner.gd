extends Node

const OUTPUT_ROOT := "res://artifacts/studio_2_0/screenshots"

var context := StudioProjectContext.new()
var graph := StudioReferenceGraphService.new()


func _ready() -> void:
	var absolute := ProjectSettings.globalize_path(OUTPUT_ROOT)
	DirAccess.make_dir_recursive_absolute(absolute)
	context.initialize("res://data/runs/first_run.tres", &"elf")
	graph.scan(true)
	await _capture_workspace(Vector2i(1280, 720), "studio_2_0_arena_run_1280x720.png")
	await _capture_workspace(Vector2i(1920, 1080), "studio_2_0_arena_run_1920x1080.png")
	await _capture_grid_first(Vector2i(1280, 720), "studio_2_0_grid_first_surfaces_1280x720.png")
	await _capture_grid_first(Vector2i(1920, 1080), "studio_2_0_grid_first_surfaces_1920x1080.png")
	await _capture_skills(Vector2i(1280, 720), "studio_2_0_skills_profile_1280x720.png")
	await _capture_skills(Vector2i(1920, 1080), "studio_2_0_skills_profile_1920x1080.png")
	print("STUDIO_2_0_CAPTURE_COMPLETE|%s" % OUTPUT_ROOT)
	get_tree().quit(0)


func _capture_workspace(size: Vector2i, file_name: String) -> void:
	DisplayServer.window_set_size(size)
	await get_tree().process_frame
	var workspace := StudioWorkspace.new()
	workspace.setup(null, null, context, graph)
	add_child(workspace)
	workspace.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.4).timeout
	_save_viewport(file_name)
	remove_child(workspace)
	workspace.queue_free()
	await get_tree().process_frame


func _capture_skills(size: Vector2i, file_name: String) -> void:
	DisplayServer.window_set_size(size)
	await get_tree().process_frame
	var studio := SkillTreeStudioMain.new()
	studio.setup(null, null, context, graph)
	add_child(studio)
	studio.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.5).timeout
	_save_viewport(file_name)
	studio.prepare_for_close()
	studio.dispose_document()
	remove_child(studio)
	studio.queue_free()
	await get_tree().process_frame


func _capture_grid_first(size: Vector2i, file_name: String) -> void:
	DisplayServer.window_set_size(size)
	await get_tree().process_frame
	var studio := ArenaStudioMain.new()
	studio.setup(null, null, context, graph)
	add_child(studio)
	studio.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await get_tree().process_frame
	studio._set_arena(_grid_first_fixture(), false, "capture:grid_first")
	studio.set_preview_view(ArenaRuntimePreview.ViewMode.GAME)
	studio.runtime_preview.rebuild_now()
	studio.runtime_preview.update_runtime_surface(
		Vector2i(0, 0), CellSurfaceState.DynamicSurface.FIRE
	)
	await get_tree().process_frame
	await get_tree().create_timer(0.5).timeout
	_save_viewport(file_name)
	remove_child(studio)
	studio.queue_free()
	await get_tree().process_frame


func _grid_first_fixture() -> ArenaDefinition:
	var value := ArenaDefinition.new()
	value.set_identity("Sandbox grid-first · surfaces runtime", "studio_2_grid_first")
	value.visual_mode = ArenaDefinition.VisualMode.MODULAR
	value.theme_id = &"dynamic_default"
	value.modular_visual_profile = ArenaModularVisualProfile.new()
	value.grid_size = Vector2i(12, 8)
	value.source_image_size = Vector2i(1280, 720)
	value.grid_origin = Vector2(640, 96)
	value.axis_x = Vector2(42, 21)
	value.axis_y = Vector2(-42, 21)
	for y in range(value.grid_size.y):
		for x in range(value.grid_size.x):
			var terrain_index := (floori(float(x) / 3.0) + floori(float(y) / 2.0)) % 4
			var terrain_id: StringName = [&"stone", &"water", &"ice", &"lava"][terrain_index]
			ArenaTerrainRegistry.configure_cell(value.ensure_cell(Vector2i(x, y)), terrain_id)
	ArenaEditingService.prepare_automatically(value)
	for entry in [[Vector2i(5, 3), &"normal"], [Vector2i(7, 4), &"fire"], [Vector2i(8, 4), &"ice"]]:
		var wall := ArenaObstacleDefinition.new()
		wall.cell = entry[0]
		wall.wall_id = entry[1]
		wall.wall_config = ArenaWallRegistry.config_for(entry[1])
		value.obstacles.append(wall)
	ArenaRuntimeBridge.sync_runtime_resources(value)
	return value


func _save_viewport(file_name: String) -> void:
	var image := get_viewport().get_texture().get_image()
	var path := OUTPUT_ROOT.path_join(file_name)
	var error := image.save_png(ProjectSettings.globalize_path(path))
	print("STUDIO_2_0_CAPTURE|%s|%s|%s" % [file_name, image.get_size(), error_string(error)])
