extends SceneTree

const LAB_SCENE := preload("res://tools/labs/vfx_flipbook_foundation/VFXFlipbookFoundationLab.tscn")
const SCENARIOS := [
	{"name": "01_low_mix_dark", "quality": 0, "blend": "MIX", "progress": 0.08, "seed": 100},
	{"name": "02_medium_mix_light", "quality": 1, "blend": "MIX", "progress": 0.28, "seed": 101, "light_background": true},
	{"name": "03_high_add_dark", "quality": 2, "blend": "ADD", "progress": 0.52, "seed": 102},
	{"name": "04_medium_premult_light", "quality": 1, "blend": "PREMULTIPLIED", "progress": 0.72, "seed": 103, "light_background": true, "target_mode": "dark"},
	{"name": "05_four_instances", "quality": 2, "blend": "ADD", "progress": 0.42, "seed": 110, "instances": 4},
	{"name": "06_ten_instances", "quality": 1, "blend": "MIX", "progress": 0.6, "seed": 120, "instances": 10, "light_background": true},
	{"name": "07_variant_a", "quality": 2, "blend": "ADD", "progress": 0.38, "variant": "variant_a", "target_mode": "light"},
	{"name": "08_variant_b", "quality": 2, "blend": "ADD", "progress": 0.38, "variant": "variant_b", "target_mode": "dark"},
	{"name": "09_loop_midpoint", "quality": 1, "blend": "PREMULTIPLIED", "progress": 0.55, "seed": 140, "loop": true},
	{"name": "10_cancelled_clean", "quality": 2, "blend": "ADD", "progress": 0.5, "seed": 150, "cancel": true},
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var options := _options()
	var resolution := Vector2i(int(options.get("width", 1200)), int(options.get("height", 896)))
	var tag := str(options.get("tag", "%dx%d" % [resolution.x, resolution.y]))
	var output_root := str(options.get("output", "user://vfx_flipbook_foundation_v1"))
	var output_directory := output_root.path_join(tag)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_directory))
	DisplayServer.window_set_size(resolution)
	get_root().content_scale_size = resolution
	var lab: Node = LAB_SCENE.instantiate()
	get_root().add_child(lab)
	await process_frame
	await process_frame
	var metadata: Array = []
	for template in SCENARIOS:
		var scenario: Dictionary = template.duplicate(true)
		if scenario.has("variant"):
			scenario.seed = lab.seed_for_variant(StringName(scenario.variant))
		var inspection: Dictionary = lab.prepare_capture(scenario)
		if not bool(inspection.get("ok", false)):
			push_error("CAPTURE_SCENARIO_FAILED %s %s" % [scenario.name, JSON.stringify(inspection)])
			lab.clear()
			lab.free()
			quit(1)
			return
		await process_frame
		await process_frame
		RenderingServer.force_draw()
		var path := output_directory.path_join("%s.png" % scenario.name)
		var error := get_root().get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
		if error != OK:
			push_error("CAPTURE_FAILED %s %s" % [path, error_string(error)])
			quit(1)
			return
		inspection["capture"] = ProjectSettings.globalize_path(path)
		inspection["resolution"] = [resolution.x, resolution.y]
		inspection["progress"] = scenario.get("progress", 0.5)
		metadata.append(inspection)
		print("CAPTURE_OK %s" % ProjectSettings.globalize_path(path))
	var metadata_path := output_directory.path_join("capture_metadata.json")
	var file := FileAccess.open(metadata_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(metadata, "  "))
	file.close()
	var contact_sheet_path := output_directory.path_join("contact_sheet.png")
	var contact_sheet_error := _save_contact_sheet(output_directory, resolution, contact_sheet_path)
	if contact_sheet_error != OK:
		push_error("CONTACT_SHEET_FAILED %s %s" % [contact_sheet_path, error_string(contact_sheet_error)])
		quit(1)
		return
	lab.clear()
	lab.free()
	print("CONTACT_SHEET_OK %s" % ProjectSettings.globalize_path(contact_sheet_path))
	print("CAPTURE_SUITE_PASS resolution=%dx%d count=%d metadata=%s" % [
		resolution.x, resolution.y, metadata.size(), ProjectSettings.globalize_path(metadata_path),
	])
	quit(0)


func _save_contact_sheet(
		output_directory: String,
		resolution: Vector2i,
		contact_sheet_path: String
	) -> Error:
	const COLUMNS := 5
	const THUMBNAIL_WIDTH := 320
	var thumbnail_height := maxi(1, roundi(float(THUMBNAIL_WIDTH) * resolution.y / resolution.x))
	var rows := ceili(float(SCENARIOS.size()) / COLUMNS)
	var sheet := Image.create(
		COLUMNS * THUMBNAIL_WIDTH, rows * thumbnail_height, false, Image.FORMAT_RGBA8
	)
	sheet.fill(Color("111820"))
	for index in SCENARIOS.size():
		var source_path := output_directory.path_join("%s.png" % SCENARIOS[index].name)
		var source := Image.new()
		var load_error := source.load(ProjectSettings.globalize_path(source_path))
		if load_error != OK:
			return load_error
		if source.get_format() != Image.FORMAT_RGBA8:
			source.convert(Image.FORMAT_RGBA8)
		source.resize(THUMBNAIL_WIDTH, thumbnail_height, Image.INTERPOLATE_LANCZOS)
		var destination := Vector2i(
			(index % COLUMNS) * THUMBNAIL_WIDTH,
			(index / COLUMNS) * thumbnail_height,
		)
		sheet.blit_rect(source, Rect2i(Vector2i.ZERO, source.get_size()), destination)
	return sheet.save_png(ProjectSettings.globalize_path(contact_sheet_path))


func _options() -> Dictionary:
	var result := {}
	for argument in OS.get_cmdline_user_args():
		if not argument.begins_with("--") or not argument.contains("="):
			continue
		var separator := argument.find("=")
		result[argument.substr(2, separator - 2)] = argument.substr(separator + 1)
	return result
