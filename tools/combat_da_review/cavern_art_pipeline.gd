extends Node

const OUTPUT := "res://artifacts/dev/cavern-pipeline-v4"
const KIT := OUTPUT + "/art-kit"


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	if "--verify-output" in OS.get_cmdline_user_args():
		_verify_output()
		return
	var arena := (load("res://data/rooms/odyssey/room_01.tres") as ArenaDefinition).duplicate(true) as ArenaDefinition
	# A geometry-only art source keeps the old background out of the new guide.
	arena.background_path = ""
	arena.visual_mode = ArenaDefinition.VisualMode.MODULAR
	ArenaRuntimeBridge.sync_runtime_resources(arena)
	if "--import-art" in OS.get_cmdline_user_args():
		_import_art(arena)
		return
	var validation := ArenaValidator.validate(arena, false)
	var plan: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://data/arenas/catabase_cavern_v1/terrain_plan.json")
	)
	var composition := Image.create(1920, 1200, false, Image.FORMAT_RGBA8)
	composition.fill(Color("163c3b"))
	var land := PackedVector2Array()
	for point: Array in plan.land_polygon:
		land.append(Vector2(point[0], point[1]))
	ArenaArtProjectionRenderer._fill_polygon(composition, land, Color("443c30"))
	ArenaArtProjectionRenderer._draw_gameplay(composition, arena)
	composition.save_png(OUTPUT + "/composition-guide.png")
	var result := ArenaArtKitExporter.export_kit(arena, KIT, validation)
	var file := FileAccess.open(OUTPUT + "/export-report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "  "))
	file.close()
	print("CAVERN_KIT ", JSON.stringify(result))
	get_tree().quit(0 if result.get("ok", false) else 2)


func _import_art(arena: ArenaDefinition) -> void:
	var raw_path := "res://assets/catabase/combat/cavern_v1/land_v4.generated.png"
	var output_path := "res://assets/catabase/combat/cavern_v1/land_v4.png"
	var source := Image.load_from_file(raw_path)
	var original_size := source.get_size()
	# Explicit art delivery normalization; never rescale the grid or kit references.
	source.resize(1920, 1200, Image.INTERPOLATE_LANCZOS)
	assert(source.save_png(KIT + "/background.png") == OK)
	var inspection := ArenaArtRoundTripService.inspect_reimport(arena, KIT)
	var report := {
		"source": raw_path,
		"source_size": [original_size.x, original_size.y],
		"delivery_size": [1920, 1200],
		"normalization": "Full generated canvas resampled with Lanczos to 1920x1200; no crop. Grid and checked kit reference files unchanged. Requires visual layout review.",
		"inspection": inspection,
	}
	if inspection.get("ok", false):
		report["import"] = ArenaArtRoundTripService.apply_reimport(
			arena,
			KIT,
			output_path,
			"background.png",
			ArenaModularVisualProfile.HybridFloorPolicy.ALL_DEFINED,
		)
		report["ok"] = report.import.get("ok", false)
		if report.ok:
			ArenaRuntimeBridge.sync_runtime_resources(arena)
			ResourceSaver.save(arena, OUTPUT + "/imported_arena.tres")
			report["calibration_rms"] = arena.painted_map_visual_data.calibration_rms()
	else:
		report["ok"] = false
	var file := FileAccess.open(OUTPUT + "/reimport-report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("CAVERN_IMPORT ok=", report.get("ok", false), " rms=", report.get("calibration_rms", -1))
	get_tree().quit(0 if report.get("ok", false) else 2)


func _verify_output() -> void:
	var kit := ArenaArtRoundTripService.validate_kit(
		"res://art/source/maps/catabase_cavern_v4/art-kit"
	)
	var large: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string(OUTPUT + "/room-qa-1920x1080/room_01.json")
	)
	var small: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string(OUTPUT + "/room-qa-1200x896/room_01.json")
	)
	var compare := preload("res://tools/registered_terrain_validation/framing_proportion_checks.gd").compare_cross_resolution(
		small.production_qa.framing_before,
		large.production_qa.framing_before,
	)
	var report := {
		"kit": kit,
		"cross_resolution": compare,
		"ok": kit.get("ok", false) and compare.get("ok", false),
	}
	var file := FileAccess.open(OUTPUT + "/delivery-validation.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("CAVERN_DELIVERY ok=", report.ok, " cross_resolution=", compare)
	get_tree().quit(0 if report.ok else 2)
