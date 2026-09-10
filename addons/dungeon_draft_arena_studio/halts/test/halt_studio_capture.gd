extends SceneTree
## Real-render authoring proof, separate from headless gesture tests.
## --output=res://artifacts/dev/<run>/editor --map=res://data/halts/<id>.json


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var output := "res://artifacts/dev/halt_editor_capture"
	var map := "res://data/halts/emerald_sanctuary_v1.json"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
		elif argument.begins_with("--map="):
			map = argument.trim_prefix("--map=")
	root.size = Vector2i(1600, 1000)
	var studio = load("res://addons/dungeon_draft_arena_studio/halts/painted_halt_studio.gd").new()
	studio.auto_load = false
	root.add_child(studio)
	if not studio.open_manifest(map):
		push_error(studio.status.text)
		quit(1)
		return
	for frame in 10:
		await process_frame
	studio.canvas.fit()
	studio._refresh_material_preview()
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var directory_error := DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(output)
	)
	var error := image.save_png(output.path_join("editor_overview.png")) if directory_error == OK else directory_error
	studio.canvas.set_layer("landmarks")
	studio._refresh_selection()
	for frame in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var inspector_image := root.get_texture().get_image()
	var inspector_error := inspector_image.save_png(output.path_join("editor_interactions.png"))
	# Compare interior samples with the original: a loaded-but-hidden TextureRect
	# must not pass merely because the source and shader objects exist.
	var painting_rect: Rect2 = studio.canvas.image_rect()
	var source: Image = studio._image
	var deviation := 0.0
	var samples := 0
	for y in range(1, 18):
		for x in range(1, 32):
			var uv := Vector2(x / 32.0, y / 18.0)
			var screen: Vector2 = studio.canvas.global_position + painting_rect.position + uv * painting_rect.size
			var actual := inspector_image.get_pixel(int(screen.x), int(screen.y))
			var expected := source.get_pixel(
				int(uv.x * (source.get_width() - 1)),
				int(uv.y * (source.get_height() - 1)),
			)
			deviation += (
				absf(actual.r - expected.r) + absf(actual.g - expected.g)
				+ absf(actual.b - expected.b)
			) / 3.0
			samples += 1
	deviation /= maxf(samples, 1)
	var report := {
		"passed": error == OK and inspector_error == OK and deviation < 0.10,
		"painting_mean_absolute_error": deviation,
		"painting_samples": samples,
		"map": map,
		"resolution": [image.get_width(), image.get_height()],
		"source_loaded": studio.canvas.texture != null,
		"shader_loaded": studio.canvas._painting.material is ShaderMaterial,
		"maps": studio.catalog.item_count,
		"editor": "res://addons/dungeon_draft_arena_studio/halts/HalteStudio.tscn",
	}
	var file := FileAccess.open(output.path_join("capture.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "  "))
		file.close()
	print("HALT_EDITOR_CAPTURE: " + JSON.stringify(report))
	studio.prepare_for_close()
	studio.queue_free()
	for frame in 3:
		await process_frame
	quit(0 if bool(report.passed) else 1)
