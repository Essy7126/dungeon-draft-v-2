extends Control

const OUTPUT := "res://artifacts/studio_2_0/stone_floor_visibility_fix"
const FOREST_PATH := "res://data/arenas/room_01_forest.tres"
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
		await _wait_frames(5)
		var studio := ArenaStudioMain.new()
		studio.name = "StoneFloorVisibilityStudio"
		studio.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(studio)
		await _wait_frames(12)

		studio._set_arena(_forest_working_copy(
			ArenaModularVisualProfile.HybridFloorPolicy.NON_BASE_TERRAINS
		), false, "capture_non_base_%dx%d" % [requested_size.x, requested_size.y])
		studio.show_dynamic_construction()
		await _wait_frames(8)
		succeeded = await _capture(
			studio, "01_non_base_stone_hidden", requested_size
		) and succeeded

		if not studio.set_hybrid_floor_policy(
				ArenaModularVisualProfile.HybridFloorPolicy.ALL_DEFINED
		):
			succeeded = false
		await _wait_frames(8)
		var plan := ArenaTerrainRenderPlanService.build(studio.arena)
		succeeded = await _capture(
			studio, "02_all_tactical_canvas", requested_size
		) and succeeded

		studio.set_preview_view(ArenaRuntimePreview.ViewMode.ART)
		var art_ok := studio.runtime_preview.rebuild_now()
		await _wait_frames(10)
		succeeded = await _capture(
			studio, "03_all_tactical_art", requested_size
		) and succeeded

		studio.set_preview_view(ArenaRuntimePreview.ViewMode.GAME)
		var game_ok := studio.runtime_preview.rebuild_now()
		await _wait_frames(12)
		succeeded = await _capture(
			studio, "04_all_tactical_game", requested_size
		) and succeeded
		var visual_report := studio.runtime_preview.assembly.get("report") \
			as ArenaVisualAssemblyReport
		metrics["%dx%d" % [requested_size.x, requested_size.y]] = {
			"plan_count": int(plan.expected_terrain_cell_count),
			"normal_count": int(plan.expected_by_terrain_id.get("normal", 0)),
			"stone_path": str(ArenaTerrainRegistry.get_entry(&"normal").get("visual", "")),
			"art_ok": art_ok,
			"game_ok": game_ok,
			"rendered_count": visual_report.rendered_terrain_node_count \
				if visual_report != null else -1,
			"walls": visual_report.rendered_wall_count if visual_report != null else -1,
		}
		studio.queue_free()
		await _wait_frames(4)

	var report := FileAccess.open(OUTPUT.path_join("capture_metrics.json"), FileAccess.WRITE)
	if report == null:
		succeeded = false
	else:
		report.store_string(JSON.stringify(metrics, "  "))
		report.close()
	print("ARENA_STONE_FLOOR_CAPTURE_COMPLETE %s" % JSON.stringify({
		"ok": succeeded,
		"captures": SIZES.size() * 4,
		"metrics": metrics,
	}))
	get_tree().quit(0 if succeeded else 1)


func _forest_working_copy(policy: int) -> ArenaDefinition:
	var source := load(FOREST_PATH) as ArenaDefinition
	var working := ArenaDefinition.new()
	working.restore_snapshot(source.to_snapshot())
	working.visual_mode = ArenaDefinition.VisualMode.HYBRID
	working.modular_visual_profile = ArenaModularVisualProfile.new()
	working.modular_visual_profile.theme_id = working.theme_id
	working.modular_visual_profile.base_terrain_id = &"stone"
	working.modular_visual_profile.hybrid_floor_policy = policy
	for cell in [Vector2i(5, 4), Vector2i(6, 4), Vector2i(5, 5)]:
		ArenaDynamicEditingService.paint_terrain(working, cell, &"water")
	for cell in [Vector2i(6, 5), Vector2i(7, 5), Vector2i(6, 6)]:
		ArenaDynamicEditingService.paint_terrain(working, cell, &"ice")
	for cell in [Vector2i(7, 6), Vector2i(8, 6), Vector2i(7, 7)]:
		ArenaDynamicEditingService.paint_terrain(working, cell, &"lava")
	ArenaDynamicEditingService.place_wall(working, Vector2i(4, 7), &"normal")
	ArenaDynamicEditingService.place_wall(working, Vector2i(5, 7), &"fire")
	ArenaDynamicEditingService.place_wall(working, Vector2i(6, 7), &"ice")
	ArenaRuntimeBridge.sync_runtime_resources(working)
	return working


func _capture(studio: ArenaStudioMain, prefix: String, size: Vector2i) -> bool:
	studio.queue_redraw()
	await _wait_frames(3)
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		return false
	var path := OUTPUT.path_join("%s_%dx%d.png" % [prefix, size.x, size.y])
	return image.save_png(ProjectSettings.globalize_path(path)) == OK


func _wait_frames(count: int) -> void:
	for _frame in range(count):
		await get_tree().process_frame
