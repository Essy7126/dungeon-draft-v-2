extends Node
## Deterministic visual review of the painting, independent of mouse/camera input.
const OUTPUT := "res://artifacts/dev/title-mythology-v4/atmosphere"
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
	# Freeze the camera and isolate cloth: temporal change must come from the
	# banners themselves, not the fire, fog or movement of the entire painting.
	material.set_shader_parameter("camera_strength", 0.0)
	material.set_shader_parameter("fire_strength", 0.0)
	material.set_shader_parameter("fog_strength", 0.0)
	await _settle()
	var wind_before := await _image()
	material.set_shader_parameter("elapsed", 6.0)
	await _settle()
	var wind_after := await _image()
	_check(
		_region_changed(wind_before, wind_after, Rect2(0.54, 0.0, 0.05, 0.40)),
		"Left banner flutters with a stationary camera",
	)
	_check(
		_region_changed(wind_before, wind_after, Rect2(0.91, 0.0, 0.09, 0.28)),
		"Right banner flutters with a stationary camera",
	)
	_check(
		_region_changed(wind_before, wind_after, Rect2(0.925, 0.035, 0.055, 0.115)),
		"Right gold embroidery moves with the fabric",
	)
	_check(wind_before.save_png(OUTPUT.path_join("wind_t4.png")) == OK, "Save wind start")
	_check(wind_after.save_png(OUTPUT.path_join("wind_t6.png")) == OK, "Save wind end")
	var stone_region := Rect2i(800, 130, 45, 100)
	_check(
		wind_before.get_region(stone_region).get_data()
		== wind_after.get_region(stone_region).get_data(),
		"Wind leaves the stone column stationary",
	)
	var right_hem_stone := Rect2i(1238, 172, 4, 4)
	_check(
		wind_before.get_region(right_hem_stone).get_data()
		== wind_after.get_region(right_hem_stone).get_data(),
		"Right banner does not pull the stone next to its inner hem",
	)
	material.set_shader_parameter("wind_strength", 0.0)
	await _settle()
	var wind_disabled := await _image()
	material.set_shader_parameter("elapsed", 9.0)
	await _settle()
	_check(
		wind_disabled.get_data() == (await _image()).get_data(),
		"Disabling all effects and camera restores a completely still painting",
	)
	material.set_shader_parameter("fog_strength", 1.0)
	material.set_shader_parameter("elapsed", 4.0)
	await _settle()
	var fog_before := await _image()
	material.set_shader_parameter("elapsed", 7.0)
	await _settle()
	var fog_after := await _image()
	_check(
		_region_changed(fog_before, fog_after, Rect2(0.43, 0.84, 0.50, 0.15)),
		"Foreground fog travels independently of the camera, wind and fire",
	)
	# Hide menu controls to inspect the left rock pockets underneath them.
	title.get_node("UI").hide()
	material.set_shader_parameter("rock_fog_strength", 0.0)
	await _settle()
	var no_rock_fog := await _image()
	material.set_shader_parameter("rock_fog_strength", 1.0)
	await _settle()
	var rock_fog := await _image()
	_check(
		_region_changed(no_rock_fog, rock_fog, Rect2(0.015, 0.48, 0.27, 0.30)),
		"Near-left rock pockets receive their own fog layer",
	)
	var foreground_rock := Rect2i(15, 610, 60, 55)
	_check(
		no_rock_fog.get_region(foreground_rock).get_data()
		== rock_fog.get_region(foreground_rock).get_data(),
		"Left fog respects the darkest foreground rock",
	)
	_check(rock_fog.save_png(OUTPUT.path_join("rock_fog_t7.png")) == OK, "Save rock fog start")
	material.set_shader_parameter("elapsed", 10.0)
	await _settle()
	var rock_fog_later := await _image()
	_check(
		_region_changed(rock_fog, rock_fog_later, Rect2(0.015, 0.48, 0.27, 0.30)),
		"Left rock mist drifts with the camera and wind disabled",
	)
	_check(rock_fog_later.save_png(OUTPUT.path_join("rock_fog_t10.png")) == OK, "Save rock fog end")
	title.get_node("UI").show()
	_check(fog_before.save_png(OUTPUT.path_join("fog_t4.png")) == OK, "Save isolated fog start")
	_check(fog_after.save_png(OUTPUT.path_join("fog_t7.png")) == OK, "Save isolated fog end")
	material.set_shader_parameter("wind_strength", 1.0)
	material.set_shader_parameter("fire_strength", 1.0)
	(title.get("_motion_toggle") as CheckButton).set_pressed_no_signal(true)
	# Keep the camera stationary in the sequence so local animation is reviewable.
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
	material.set_shader_parameter("camera_strength", 1.0)
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
	(title.get_node("AudioStreamPlayer") as AudioStreamPlayer).stop()
	title.queue_free()
	await _settle()
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


func _region_changed(before: Image, after: Image, region: Rect2) -> bool:
	var dimensions := Vector2(before.get_size())
	var bounds := Rect2i(region.position * dimensions, region.size * dimensions)
	var changed := 0
	var sampled := 0
	for y in range(bounds.position.y, bounds.end.y, 3):
		for x in range(bounds.position.x, bounds.end.x, 3):
			sampled += 1
			var first := before.get_pixel(x, y)
			var second := after.get_pixel(x, y)
			if absf(first.r - second.r) + absf(first.g - second.g) + absf(first.b - second.b) > 0.012:
				changed += 1
	return sampled > 0 and float(changed) / float(sampled) > 0.03
