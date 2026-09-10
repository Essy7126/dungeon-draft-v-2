extends Node
const CONFIG := "res://art/source/maps/cavern_sequence_v1/sequence.json"


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var configs: Array = JSON.parse_string(FileAccess.get_file_as_string(CONFIG))
	var importing := "--import-art" in OS.get_cmdline_user_args()
	var all_ok := true
	for config: Dictionary in configs:
		var selected := ""
		for argument: String in OS.get_cmdline_user_args():
			if argument.begins_with("--only="):
				selected = argument.trim_prefix("--only=")
		if not selected.is_empty() and config.id != selected:
			continue
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(config.work))
		var arena := (load(config.room) as ArenaDefinition).duplicate(true) as ArenaDefinition
		var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(config.manifest))
		arena.registered_terrain_plan_path = config.plan
		arena.background_path = ""
		arena.visual_mode = ArenaDefinition.VisualMode.MODULAR
		arena.grid_origin = Vector2(manifest.grid_origin[0], manifest.grid_origin[1])
		arena.axis_x = Vector2(manifest.axis_x[0], manifest.axis_x[1])
		arena.axis_y = Vector2(manifest.axis_y[0], manifest.axis_y[1])
		arena.calibration_pixels.clear()
		for cell: Vector2i in arena.calibration_cells:
			arena.calibration_pixels.append(
				arena.grid_origin + cell.x * arena.axis_x + cell.y * arena.axis_y
			)
		ArenaRuntimeBridge.sync_runtime_resources(arena)
		var result := { }
		if importing:
			var source := Image.load_from_file(
				ProjectSettings.globalize_path(config.asset + "/land.generated.png")
			)
			var original_size := source.get_size()
			source.resize(1920, 1200, Image.INTERPOLATE_LANCZOS)
			source.save_png(config.kit + "/background.png")
			var inspection := ArenaArtRoundTripService.inspect_reimport(arena, config.kit)
			result = {
				"inspection": inspection,
				"generated_size": [original_size.x, original_size.y],
				"native_size": [1920, 1200],
				"normalization": "Entire generated canvas resampled Lanczos; no crop; guide and grid not rescaled.",
			}
			if inspection.get("ok", false):
				result["import"] = ArenaArtRoundTripService.apply_reimport(
					arena,
					config.kit,
					config.asset + "/land.png",
					"background.png",
					ArenaModularVisualProfile.HybridFloorPolicy.ALL_DEFINED,
				)
				result["ok"] = result.import.get("ok", false)
				if result.ok:
					ArenaRuntimeBridge.sync_runtime_resources(arena)
					ResourceSaver.save(arena, config.work + "/imported_arena.tres")
					var fields := { }
					for key: String in [
						"registered_terrain_plan_path",
						"grid_origin",
						"axis_x",
						"axis_y",
						"calibration_pixels",
						"background_path",
					]:
						fields[key] = var_to_str(arena.get(key))
					result["fields"] = fields
			else:
				result["ok"] = false
		else:
			var validation := ArenaValidator.validate(arena, false)
			result = ArenaArtKitExporter.export_kit(arena, config.kit, validation)
			var plan: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(config.plan))
			var guide := Image.create(1920, 1200, false, Image.FORMAT_RGBA8)
			guide.fill(Color("163c3b"))
			var land := PackedVector2Array()
			for p: Array in plan.land_polygon:
				land.append(Vector2(p[0], p[1]))
			ArenaArtProjectionRenderer._fill_polygon(guide, land, Color("443c30"))
			ArenaArtProjectionRenderer._draw_gameplay(guide, arena)
			guide.save_png(config.kit.get_base_dir() + "/composition-guide.png")
		result["calibration_rms"] = arena.painted_map_visual_data.calibration_rms()
		var file := FileAccess.open(
			config.work + ("/import-report.json" if importing else "/export-report.json"),
			FileAccess.WRITE,
		)
		file.store_string(JSON.stringify(result, "  "))
		file.close()
		print(config.id, " ok=", result.get("ok", false), " rms=", result.calibration_rms)
		all_ok = all_ok and result.get("ok", false)
	get_tree().quit(0 if all_ok else 2)
