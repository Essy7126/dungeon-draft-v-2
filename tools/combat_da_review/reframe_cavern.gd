extends Node


func _ready() -> void:
	_reframe.call_deferred()


func _reframe() -> void:
	var arena := load("res://data/rooms/odyssey/room_01.tres") as ArenaDefinition
	var manifest: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://data/arenas/catabase_cavern_v1/geometry_manifest.json")
	)
	arena.registered_terrain_plan_path = "res://data/arenas/catabase_cavern_v1/terrain_plan.json"
	arena.grid_origin = Vector2(manifest.grid_origin[0], manifest.grid_origin[1])
	arena.axis_x = Vector2(manifest.axis_x[0], manifest.axis_x[1])
	arena.axis_y = Vector2(manifest.axis_y[0], manifest.axis_y[1])
	arena.calibration_pixels.clear()
	for cell: Vector2i in arena.calibration_cells:
		arena.calibration_pixels.append(
			arena.grid_origin + cell.x * arena.axis_x + cell.y * arena.axis_y
		)
	if not ArenaRuntimeBridge.sync_runtime_resources(
		arena,
		ArenaRuntimeBridge.SyncScope.GRID_TRANSFORM,
	):
		get_tree().quit(2)
		return
	var visual := arena.painted_map_visual_data
	var valid := visual.validation_errors().is_empty() and visual.calibration_rms() < 0.001
	var fields := { }
	for key: String in [
		"registered_terrain_plan_path",
		"grid_origin",
		"axis_x",
		"axis_y",
		"calibration_pixels",
	]:
		fields[key] = var_to_str(arena.get(key))
	var result := { "ok": valid, "fields": fields, "calibration_rms": visual.calibration_rms() }
	var file := FileAccess.open(
		"res://artifacts/dev/cavern-inset-v1/projection.json",
		FileAccess.WRITE,
	)
	file.store_string(JSON.stringify(result, "\t"))
	file.close()
	print("CAVERN_PROJECTION ", JSON.stringify(result))
	get_tree().quit(0 if valid else 3)
