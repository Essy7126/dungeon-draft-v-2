extends Node

# Standalone visual review of any registered ArenaDefinition, using production
# assembly and the current Catabase hero profile. No campaign resource is saved.
var _capture_path := ""
var _room_path := ""


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--room="):
			_room_path = arg.trim_prefix("--room=")
		if arg.begins_with("--capture="):
			_capture_path = arg.trim_prefix("--capture=")
	_launch.call_deferred()


func _launch() -> void:
	var source := load(_room_path) as ArenaDefinition
	if source == null:
		push_error("MapPreview needs --room=res://... ArenaDefinition")
		get_tree().quit(2)
		return
	var arena := source.duplicate(true) as ArenaDefinition
	if not ArenaRuntimeBridge.sync_runtime_resources(arena):
		get_tree().quit(3)
		return
	var run := RunData.new()
	run.rooms = [arena]
	run.content_profile = load("res://data/runs/profiles/odyssey_content_profile.tres") as RunContentProfile
	run.randomize_seed_each_run = false
	run.default_seed = 2401
	var resolution := RunHeroResolver.resolve_runtime_hero_data(run, false)
	var options := ArenaDirectTestConfiguration.resolve(&"real_encounter")
	options["camera_mode"] = "PRODUCTION"
	get_tree().current_scene = null
	if (
		not resolution.is_valid()
		or not GameManager.start_direct_encounter_test(run, resolution.heroes, options)
	):
		get_tree().quit(4)
		return
	if _capture_path.is_empty():
		queue_free()
		return
	var battle: Node = null
	for _frame in range(1200):
		await get_tree().process_frame
		var candidate := get_tree().current_scene
		if candidate != null and bool(candidate.get("registered_terrain_ready")):
			battle = candidate
			break
	if battle == null:
		get_tree().quit(5)
		return
	var deployment := battle.get("_deployment") as DeploymentController
	if deployment != null and deployment.is_active():
		for cell: Vector2i in arena.hero_spawn_zone:
			if not deployment.is_active():
				break
			deployment.on_cell_clicked(cell)
	var requested_size := Vector2i(1600, 1000)
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--resolution="):
			var parts := argument.trim_prefix("--resolution=").split("x")
			if parts.size() == 2:
				requested_size = Vector2i(int(parts[0]), int(parts[1]))
	get_window().mode = Window.MODE_WINDOWED
	get_window().size = requested_size
	var pointer := InputEventMouseMotion.new()
	pointer.position = Vector2(2, 2)
	pointer.global_position = pointer.position
	Input.parse_input_event(pointer)
	await get_tree().create_timer(2.0).timeout
	# Clear transient hover UI for the visual review without changing production.
	var inspection := battle.get("inspect_panel") as CanvasLayer
	if inspection != null:
		inspection.hide()
	var review_grid := battle.get("grid_view") as Node2D
	if review_grid != null:
		review_grid.set("_hovered_cell", Vector2i(-999, -999))
		review_grid.queue_redraw()
	await RenderingServer.frame_post_draw
	var shot := get_viewport().get_texture().get_image()
	var destination := ProjectSettings.globalize_path(_capture_path)
	DirAccess.make_dir_recursive_absolute(destination.get_base_dir())
	var saved := shot.save_png(destination)
	print(
		"REGISTERED_MAP_PREVIEW "
		+ JSON.stringify({ "ok": saved == OK, "room": _room_path, "capture": destination })
	)
	var reports := { }
	if "--lethe-motion-review" in OS.get_cmdline_user_args():
		reports["motion"] = await preload("res://tools/lethe_map_review/motion_review.gd").run(
			battle,
			destination.get_base_dir(),
		)
	if "--motion-review" in OS.get_cmdline_user_args():
		reports["motion"] = await preload("res://tools/combat_da_review/cavern_motion_review.gd").run(
			battle,
			destination.get_base_dir(),
		)
	var valid: bool = saved == OK and reports.get("motion", { "ok": true }).get("ok", false)
	var picking_errors: Array[String] = []
	var picking_cells := 0
	if review_grid != null:
		var canvas_transform := review_grid.get_global_transform_with_canvas()
		for definition in arena.cells:
			if (
				definition == null or not definition.defined
				or definition.cell_type == GridData.CellType.HOLE
			):
				continue
			var local: Vector2 = review_grid.call("grid_to_local", definition.coordinate)
			var screen := canvas_transform * local
			var picked: Vector2i = review_grid.call(
				"local_to_grid",
				canvas_transform.affine_inverse() * screen,
			)
			picking_cells += 1
			if picked != definition.coordinate:
				picking_errors.append(str(definition.coordinate))
	valid = valid and picking_cells > 0 and picking_errors.is_empty()
	reports["screen_picking"] = {
		"cells": picking_cells,
		"errors": picking_errors,
		"ok": picking_cells > 0 and picking_errors.is_empty(),
	}
	for key in ["registered_terrain_initialization", "greek_combat_ground_band"]:
		var value: Dictionary = battle.get_meta(key, { })
		if key == "greek_combat_ground_band" and value.is_empty():
			var terrain := battle.get_node_or_null("GreekTerrainComposition")
			var plan: Dictionary = terrain.get("plan") if terrain != null else { }
			var band: Dictionary = plan.get("combat_ground_band", { })
			if band.get("enabled", true) == false and not battle.get("combat_band_active"):
				value = { "ok": true, "skipped": true, "reason": "explicitly disabled in plan" }
		reports[key] = value
		valid = valid and bool(value.get("ok", false))
	if "--production-qa" in OS.get_cmdline_user_args():
		var qa: Dictionary = await preload("res://tools/combat_da_review/registered_map_checks.gd").run(
			battle,
			destination,
			requested_size,
		)
		reports["production_qa"] = qa
		valid = valid and qa.get("ok", false)
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--compare-report="):
				var previous: Variant = JSON.parse_string(
					FileAccess.get_file_as_string(argument.trim_prefix("--compare-report="))
				)
				var comparison := { "ok": false, "errors": ["previous_report_invalid"] }
				if previous is Dictionary and previous.get("production_qa", { }).get("ok", false):
					comparison = preload(
						"res://tools/registered_terrain_validation/framing_proportion_checks.gd"
					).compare_cross_resolution(
						qa.framing_after,
						previous.production_qa.framing_after,
					)
				reports["cross_resolution"] = comparison
				valid = valid and comparison.ok
	reports["gameplay_fingerprint"] = ArenaSnapshotService.gameplay_fingerprint(source)
	reports["room"] = _room_path
	reports["capture"] = destination
	reports["ok"] = valid
	var report_file := FileAccess.open(destination.get_basename() + ".json", FileAccess.WRITE)
	report_file.store_string(JSON.stringify(reports, "\t"))
	report_file.close()
	var fixture_grid := battle.get("grid") as GridData
	var fixture_terrain := battle.get("terrain_effects") as TerrainEffects
	battle.queue_free()
	get_tree().current_scene = null
	for frame in range(6):
		await get_tree().process_frame
	preload("res://test/support/isolated_battlefield_cleanup.gd").dispose_grid(fixture_grid)
	if fixture_terrain != null:
		var service := fixture_terrain.runtime_service
		if service != null:
			for declaration: Dictionary in service.get_signal_list():
				var relay := Signal(service, StringName(declaration.name))
				for connection: Dictionary in relay.get_connections():
					relay.disconnect(connection.callable)
			service.grid = null
		fixture_terrain.runtime_service = null
		fixture_terrain._grid = null
	GameManager.cleanup_run_state()
	for frame in range(3):
		await get_tree().process_frame
	get_tree().quit.call_deferred(0 if valid else 6)
