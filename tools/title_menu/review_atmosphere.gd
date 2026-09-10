extends Node
## Deterministic visual review of the painting, independent of mouse/camera input.
const OUTPUT := "res://artifacts/dev/title-atmosphere-v2"
var _failures: Array[String] = []
var _checks := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	GameManager.set_reduced_motion_enabled(true)
	get_window().size = Vector2i(1280, 720)
	var title: Node = load("res://ui/TitreEcran.tscn").instantiate()
	add_child(title)
	await _settle()
	var material := title.get_node("Fond").material as ShaderMaterial
	material.set_shader_parameter("elapsed", 4.0)
	await _settle()
	var still := await _image()
	await _settle()
	_check(
		still.get_data() == (await _image()).get_data(),
		"Every new effect freezes with the shared clock",
	)
	_check(still.save_png(OUTPUT.path_join("atmosphere_1280.png")) == OK, "Save full menu")
	# Isolate each contribution at the same time and framing.
	material.set_shader_parameter("fire_strength", 0.0)
	await _settle()
	var no_fire := await _image()
	_check(no_fire.get_data() != still.get_data(), "Procedural fire contributes visible pixels")
	material.set_shader_parameter("fire_strength", 1.0)
	material.set_shader_parameter("fog_strength", 0.0)
	await _settle()
	_check(
		(await _image()).get_data() != still.get_data(),
		"Layered fog contributes visible pixels",
	)
	material.set_shader_parameter("fog_strength", 1.0)
	for index in range(96):
		material.set_shader_parameter("elapsed", 4.0 + float(index) / 24.0)
		await get_tree().process_frame
		var frame := await _image()
		_check(
			frame.save_jpg(OUTPUT.path_join("frame_%03d.jpg" % index), 0.92) == OK,
			"Export animation frame %d" % index,
		)
	get_window().size = Vector2i(1920, 1080)
	await _settle()
	_check(
		(await _image()).save_png(OUTPUT.path_join("atmosphere_1920.png")) == OK,
		"Save final full-resolution menu",
	)
	# Measure steady rendering without screenshot readback.
	title.set_process(true)
	for index in range(20):
		await get_tree().process_frame
	var started := Time.get_ticks_usec()
	for index in range(120):
		await get_tree().process_frame
	var average_frame_ms := float(Time.get_ticks_usec() - started) / 120000.0
	var report := FileAccess.open(OUTPUT.path_join("report.json"), FileAccess.WRITE)
	report.store_string(
		JSON.stringify(
			{
				"checks": _checks,
				"failures": _failures,
				"average_frame_ms_1920": average_frame_ms,
				"renderer": RenderingServer.get_current_rendering_method(),
			},
			"\t",
		)
	)
	report.close()
	print(
		"Atmosphere: %d checks, %d failures; %.2f ms/frame at 1920x1080"
		% [_checks, _failures.size(), average_frame_ms]
	)
	get_tree().quit(0 if _failures.is_empty() else 1)


func _settle() -> void:
	for index in range(6):
		await get_tree().process_frame


func _image() -> Image:
	await RenderingServer.frame_post_draw
	return get_viewport().get_texture().get_image()


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)
		printerr(label)
