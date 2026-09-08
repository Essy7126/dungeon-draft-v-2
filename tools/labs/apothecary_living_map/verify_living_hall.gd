extends Node

## Run this scene after autoloads. Use a real renderer and -- --capture for
## framebuffer evidence; a headless run validates only the public preview API.
const SCENE_PATH := "res://tools/labs/apothecary_living_map/LivingHall.tscn"
const OUTPUT_DIR := "res://artifacts/living_hall"
const NATIVE_SIZE := Vector2(1376, 768)
const WATER_ROI := Rect2(580, 480, 28, 12)
const CHANNEL_ROI := Rect2(70, 507, 65, 25)
const STONE_ROI := Rect2(750, 580, 70, 35)
const FIRE_ROI := Rect2(334, 344, 16, 21)
const MAGIC_ROI := Rect2(948, 315, 27, 25)
const ATMOSPHERE_ROI := Rect2(330, 290, 760, 370)
const RIPPLE_ROI := Rect2(560, 461, 142, 48)
const WATER_POINT := Vector2(592, 487)
const CHANNEL_POINT := Vector2(96, 520)
const STONE_POINT := Vector2(785, 596)
const LAYERS: Array[StringName] = [&"water", &"fire", &"magic", &"atmosphere"]
const REQUIRED_METHODS: Array[StringName] = [
	&"is_ready_for_preview", &"set_effects_enabled", &"set_layer_enabled",
	&"set_effect_time", &"set_animation_paused", &"set_effect_strength",
	&"trigger_ripple", &"get_effect_state", &"native_to_viewport", &"set_chrome_visible",
]

var _root: Window
var _preview: Node
var _resolution := ""
var _expected_size := Vector2i.ZERO
var _checks: Array[Dictionary] = []
var _captures: Array[Dictionary] = []
var _measurements: Array[Dictionary] = []
var _failures: Array[String] = []
var _capture_enabled := false
var _started_ms := 0


func _ready() -> void:
	_root = get_tree().root
	_started_ms = Time.get_ticks_msec()
	_capture_enabled = "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless"
	_run.call_deferred()


func _run() -> void:
	var directory_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_check("artifact_directory_available", directory_error == OK, error_string(directory_error))
	var scene := load(SCENE_PATH) as PackedScene
	_check("scene_loads", scene != null, SCENE_PATH)
	if scene != null:
		for resolution: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
			_expected_size = resolution
			_resolution = "%dx%d" % [resolution.x, resolution.y]
			_root.mode = Window.MODE_WINDOWED
			_root.size = resolution
			await _settle()
			_preview = scene.instantiate()
			_root.add_child(_preview)
			var valid_api := true
			for method: StringName in REQUIRED_METHODS:
				var exists := _preview.has_method(method)
				_check("api_" + String(method), exists)
				valid_api = valid_api and exists
			if valid_api:
				var deadline := Time.get_ticks_msec() + 10000
				while not bool(_preview.call("is_ready_for_preview")) and Time.get_ticks_msec() < deadline:
					await get_tree().process_frame
				var ready := bool(_preview.call("is_ready_for_preview"))
				_check("ready_within_10_seconds", ready)
				if ready:
					await _exercise_api()
					if _capture_enabled:
						await _exercise_rendered_effects()
					await _exercise_ripple_input()
			_preview.queue_free()
			await _settle()
			_preview = null
	_write_report()
	for failure: String in _failures:
		push_error("LIVING_HALL: " + failure)
	var result := "FAIL" if not _failures.is_empty() else ("PASS_RENDERED" if _capture_enabled else "PASS_API_ONLY")
	print("LIVING_HALL: %s (%d checks; %d captures). Report: %s/verification.json" % [result, _checks.size(), _captures.size(), OUTPUT_DIR])
	get_tree().quit(0 if _failures.is_empty() else 1)


func _exercise_api() -> void:
	_preview.call("set_animation_paused", true)
	_preview.call("set_effect_time", 0.25)
	_preview.call("set_effect_strength", 0.65)
	_preview.call("set_effects_enabled", false)
	_preview.call("set_chrome_visible", false)
	var state := _state()
	_check("pause_api", bool(state.get("paused", false)), state)
	_check("time_api", is_equal_approx(float(state.get("effect_time", -1.0)), 0.25))
	_check("strength_api", is_equal_approx(float(state.get("strength", -1.0)), 0.65))
	_check("original_toggle_api", state.has("effects_enabled") and not bool(state.effects_enabled))
	_check("chrome_hidden_api", state.has("chrome_visible") and not bool(state.chrome_visible))
	for layer: StringName in LAYERS:
		_preview.call("set_layer_enabled", layer, false)
		state = _state()
		var layers: Dictionary = state.get("layers", {})
		_check("disable_" + String(layer), layers.has(layer) and not bool(layers[layer]))
		_preview.call("set_layer_enabled", layer, true)
		state = _state()
		layers = state.get("layers", {})
		_check("enable_" + String(layer), bool(layers.get(layer, false)))
	_preview.call("set_effects_enabled", true)
	_preview.call("set_effect_strength", 1.0)
	state = _state()
	_check("effects_reenabled_api", bool(state.get("effects_enabled", false)))
	_preview.call("set_animation_paused", false)
	await get_tree().create_timer(0.06).timeout
	var advanced_time := float(_state().get("effect_time", -1.0))
	_check("clock_advances_when_playing", advanced_time > 0.25, advanced_time)
	_preview.call("set_animation_paused", true)
	await get_tree().create_timer(0.06).timeout
	_check("clock_stops_when_paused", is_equal_approx(float(_state().get("effect_time", -1.0)), advanced_time))
	await _key(KEY_SPACE)
	_check("space_resumes_animation", not bool(_state().get("paused", true)))
	await _key(KEY_SPACE)
	_check("space_pauses_animation", bool(_state().get("paused", false)))
	await _key(KEY_TAB)
	_check("tab_shows_original", not bool(_state().get("effects_enabled", true)))
	await _key(KEY_TAB)
	_check("tab_restores_effects", bool(_state().get("effects_enabled", false)))
	_preview.call("set_effect_time", 0.25)
	var origin: Vector2 = _preview.call("native_to_viewport", Vector2.ZERO)
	var corner: Vector2 = _preview.call("native_to_viewport", NATIVE_SIZE)
	_check("map_fits_viewport", origin.x >= -1.0 and origin.y >= -1.0 and corner.x <= _root.size.x + 1.0 and corner.y <= _root.size.y + 1.0, {"origin": [origin.x, origin.y], "corner": [corner.x, corner.y]})
	var scale_x := (corner.x - origin.x) / NATIVE_SIZE.x
	var scale_y := (corner.y - origin.y) / NATIVE_SIZE.y
	_check("map_aspect_preserved", scale_x > 0.0 and absf(scale_x - scale_y) < 0.002)


func _exercise_rendered_effects() -> void:
	_preview.call("set_chrome_visible", true)
	await _capture("preview_with_controls")
	_preview.call("set_chrome_visible", false)
	_preview.call("set_effects_enabled", false)
	_preview.call("set_effect_time", 0.25)
	var original_a := await _capture("original_t025")
	_preview.call("set_effect_time", 1.55)
	var original_b := await _capture("original_t155")
	_assert_still("original_stays_unchanged", original_a, original_b, Rect2(Vector2.ZERO, NATIVE_SIZE))

	_preview.call("set_effects_enabled", true)
	_set_layers([&"water"])
	_preview.call("set_effect_time", 0.25)
	var water_a := await _capture("water_only_t025")
	_preview.call("set_effect_time", 1.55)
	var water_b := await _capture("water_only_t155")
	_assert_motion("water_animates_in_fountain", water_a, water_b, WATER_ROI)
	_assert_motion("water_animates_in_channel", water_a, water_b, CHANNEL_ROI)
	_assert_still("water_does_not_deform_stone", water_a, water_b, STONE_ROI)
	var paused := await _capture("water_paused_repeat")
	_assert_still("paused_shader_stays_unchanged", water_b, paused, WATER_ROI)

	_set_layers([&"fire"])
	_preview.call("set_effect_time", 0.25)
	var fire_a := await _capture("fire_only_t025")
	_preview.call("set_effect_time", 1.55)
	var fire_b := await _capture("fire_only_t155")
	_assert_motion("lantern_light_flickers", fire_a, fire_b, FIRE_ROI)

	_set_layers([&"magic"])
	_preview.call("set_effect_time", 0.25)
	var magic_a := await _capture("magic_only_t025")
	_preview.call("set_effect_time", 1.55)
	var magic_b := await _capture("magic_only_t155")
	_assert_motion("orb_glow_pulses", magic_a, magic_b, MAGIC_ROI)

	_set_layers([&"atmosphere"])
	_preview.call("set_effect_time", 0.25)
	var atmosphere_a := await _capture("atmosphere_only_t025")
	_preview.call("set_effect_time", 1.55)
	var atmosphere_b := await _capture("atmosphere_only_t155")
	_assert_motion("atmosphere_moves", atmosphere_a, atmosphere_b, ATMOSPHERE_ROI)

	_set_layers([&"water", &"fire", &"magic"])
	_preview.call("set_effect_time", 0.25)
	var localized_a := await _capture("effects_without_atmosphere_t025")
	_preview.call("set_effect_time", 1.55)
	var localized_b := await _capture("effects_without_atmosphere_t155")
	# Local lantern light may illuminate stone. The water-only assertion above
	# checks deformation isolation; report full-light variation without rejecting it.
	var lit_stone := _measure(localized_a, localized_b, STONE_ROI)
	lit_stone["id"] = "stone_with_local_lighting_observation"
	_measurements.append(lit_stone)

	_set_layers(LAYERS)
	_preview.call("set_effect_time", 0.25)
	await _capture("living_map_t025")
	_preview.call("set_effect_time", 1.55)
	await _capture("living_map_t155")
	_preview.call("set_effect_strength", 0.0)
	var strength_zero := await _capture("strength_zero")
	_assert_still("zero_strength_restores_artwork", original_b, strength_zero, Rect2(Vector2.ZERO, NATIVE_SIZE))
	_preview.call("set_effect_strength", 1.0)


func _exercise_ripple_input() -> void:
	_preview.call("set_chrome_visible", false)
	_preview.call("set_effects_enabled", true)
	_set_layers([&"water"])
	_preview.call("set_effect_time", 2.35)
	var before: Image = null
	if _capture_enabled:
		before = await _capture("water_before_ripple")
	_preview.call("set_effect_time", 2.0)
	_check("ripple_rejects_stone", not bool(_preview.call("trigger_ripple", STONE_POINT)))
	_check("ripple_accepts_fountain", bool(_preview.call("trigger_ripple", WATER_POINT)))
	_preview.call("set_effect_time", 2.35)
	if _capture_enabled:
		var after := await _capture("water_after_ripple")
		_assert_motion("ripple_changes_water_at_same_time", before, after, RIPPLE_ROI)
	var count_before := int(_state().get("ripple_count", -1))
	var screen_point: Vector2 = _preview.call("native_to_viewport", WATER_POINT)
	await _click(screen_point)
	var count_after := int(_state().get("ripple_count", -1))
	_check("mouse_click_triggers_water_ripple", count_before >= 0 and count_after > count_before, {"before": count_before, "after": count_after})
	count_before = count_after
	screen_point = _preview.call("native_to_viewport", STONE_POINT)
	await _click(screen_point)
	count_after = int(_state().get("ripple_count", -1))
	_check("mouse_click_on_stone_adds_no_ripple", count_after == count_before)
	_check("ripple_accepts_channel", bool(_preview.call("trigger_ripple", CHANNEL_POINT)))


func _set_layers(enabled: Array[StringName]) -> void:
	for layer: StringName in LAYERS:
		_preview.call("set_layer_enabled", layer, layer in enabled)


func _state() -> Dictionary:
	return _preview.call("get_effect_state")


func _key(code: Key) -> void:
	var press := InputEventKey.new()
	press.keycode = code
	press.pressed = true
	Input.parse_input_event(press)
	await get_tree().process_frame
	var release := InputEventKey.new()
	release.keycode = code
	Input.parse_input_event(release)
	await _settle()


func _click(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	Input.parse_input_event(motion)
	var press := InputEventMouseButton.new()
	press.position = point
	press.global_position = point
	press.button_index = MOUSE_BUTTON_LEFT
	press.button_mask = MOUSE_BUTTON_MASK_LEFT
	press.pressed = true
	Input.parse_input_event(press)
	await get_tree().process_frame
	var release := InputEventMouseButton.new()
	release.position = point
	release.global_position = point
	release.button_index = MOUSE_BUTTON_LEFT
	Input.parse_input_event(release)
	await _settle()


func _settle() -> void:
	for frame in range(3):
		await get_tree().process_frame


func _capture(label: String) -> Image:
	await _settle()
	await RenderingServer.frame_post_draw
	var image := _root.get_texture().get_image()
	var valid := image != null and not image.is_empty()
	var path := OUTPUT_DIR.path_join(_resolution + "_" + label + ".png")
	var error := image.save_png(ProjectSettings.globalize_path(path)) if valid else ERR_CANT_CREATE
	_check("capture_" + label, error == OK)
	_check("capture_size_" + label, valid and image.get_size() == _expected_size, {"expected": [_expected_size.x, _expected_size.y], "actual": [image.get_width(), image.get_height()] if valid else []})
	_captures.append({"label": label, "resolution": _resolution, "path": path, "saved": error == OK, "state": _state()})
	return image if valid else null


func _measure(before: Image, after: Image, native_roi: Rect2) -> Dictionary:
	var result := {"resolution": _resolution, "native_roi": [native_roi.position.x, native_roi.position.y, native_roi.size.x, native_roi.size.y], "samples": 0, "changed_samples": 0, "mean_rgb_delta": 0.0, "max_rgb_delta": 0.0, "changed_fraction": 0.0}
	if before == null or after == null or before.get_size() != after.get_size():
		return result
	var top_left: Vector2 = _preview.call("native_to_viewport", native_roi.position)
	var bottom_right: Vector2 = _preview.call("native_to_viewport", native_roi.end)
	var x_start := clampi(ceili(top_left.x), 0, before.get_width())
	var x_end := clampi(floori(bottom_right.x), 0, before.get_width())
	var y_start := clampi(ceili(top_left.y), 0, before.get_height())
	var y_end := clampi(floori(bottom_right.y), 0, before.get_height())
	# Sample the complete small ROIs. A whole-map comparison uses a 3 px grid.
	var stride := 3 if native_roi.size.x > 500.0 else 1
	var delta_sum := 0.0
	for y in range(y_start, y_end, stride):
		for x in range(x_start, x_end, stride):
			var a := before.get_pixel(x, y)
			var b := after.get_pixel(x, y)
			var delta := maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b)))
			result.samples += 1
			delta_sum += delta
			result.max_rgb_delta = maxf(float(result.max_rgb_delta), delta)
			if delta > 1.5 / 255.0:
				result.changed_samples += 1
	if int(result.samples) > 0:
		result.mean_rgb_delta = delta_sum / float(result.samples)
		result.changed_fraction = float(result.changed_samples) / float(result.samples)
	return result


func _assert_motion(id: String, before: Image, after: Image, roi: Rect2) -> void:
	var measurement := _measure(before, after, roi)
	measurement["id"] = id
	_measurements.append(measurement)
	_check(id, int(measurement.samples) > 0 and int(measurement.changed_samples) >= 4 and float(measurement.max_rgb_delta) > 2.0 / 255.0, measurement)


func _assert_still(id: String, before: Image, after: Image, roi: Rect2) -> void:
	var measurement := _measure(before, after, roi)
	measurement["id"] = id
	_measurements.append(measurement)
	_check(id, int(measurement.samples) > 0 and int(measurement.changed_samples) == 0, measurement)


func _check(id: String, passed: bool, details: Variant = null) -> void:
	_checks.append({"id": id, "resolution": _resolution, "passed": passed, "details": details})
	if not passed:
		_failures.append("%s [%s]" % [id, _resolution])


func _write_report() -> void:
	var report := {
		"scene": SCENE_PATH,
		"created_utc": Time.get_datetime_string_from_system(true),
		"elapsed_ms": Time.get_ticks_msec() - _started_ms,
		"godot_version": Engine.get_version_info().string,
		"display_server": DisplayServer.get_name(),
		"rendering_method": RenderingServer.get_current_rendering_method(),
		"capture_requested": "--capture" in OS.get_cmdline_user_args(),
		"capture_enabled": _capture_enabled,
		"shaders_validated": _capture_enabled and not _measurements.is_empty() and _failures.is_empty(),
		"result": "FAIL" if not _failures.is_empty() else ("PASS_RENDERED" if _capture_enabled else "PASS_API_ONLY"),
		"check_count": _checks.size(),
		"failures": _failures,
		"checks": _checks,
		"measurements": _measurements,
		"captures": _captures,
		"method": "Instantiates the real preview scene after autoloads. Public API and mouse-event smoke tests run at 1280x720 and 1920x1080. With --capture and an active renderer, fixed effect times 0.25/1.55 produce framebuffer comparisons in independent native image regions: fountain, channel, lantern, orb, atmosphere and stone. Ripple comparison holds shader time equal. Shader validation is never claimed for headless runs.",
		"pixel_threshold": "Motion: at least four samples differ by >1.5/255 and one by >2/255 in any RGB channel. Still regions: no sample differs by >1.5/255. Native ROIs are transformed with the scene's public native_to_viewport API.",
	}
	var report_path := OUTPUT_DIR.path_join("verification.json")
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	if file == null:
		_failures.append("Cannot write " + report_path)
		return
	file.store_string(JSON.stringify(report, "\t"))
