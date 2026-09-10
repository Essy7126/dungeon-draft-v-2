extends Node
## Graphics-only isolated visit: no run configuration or checkpoint can be started.
## --output=res://artifacts/dev/<new-report> ; review points come from the manifest.
const ENTRY := preload("res://hub/catabase_threshold/CatabaseThreshold.tscn")
const REVIEW_KEYS := ["statue_right_behind", "statue_right_front", "statue_left_behind"]
var _output := "res://artifacts/dev/catabase-threshold-visual-%d" % int(
	Time.get_unix_time_from_system()
)
var _report: Dictionary = { "ok": false, "checks": [], "captures": [], "occlusion": { } }
var _viewport: SubViewport
var _hall
var _manager: IsolatedManager
var _motion_before := false
var _save_hash_before := ""
var _run_active_before := false
var _finished := false


class IsolatedManager extends Node:
	var start_attempts := 0


	func has_catabase_threshold_configuration() -> bool:
		return false


	func finish_catabase_threshold() -> Dictionary:
		start_attempts += 1
		return { "success": false, "pending": false }


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			_output = argument.trim_prefix("--output=")
	if not _output.begins_with("res://artifacts/") or ".." in _output:
		push_error("THRESHOLD_VISUAL_QA: output must be inside project artifacts")
		get_tree().quit(2)
		return
	if FileAccess.file_exists(_output.path_join("report.json")):
		push_error("THRESHOLD_VISUAL_QA: choose a new report directory; previous report preserved")
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_output))
	_motion_before = GameManager.is_reduced_motion_enabled()
	_save_hash_before = _save_hash()
	_run_active_before = GameManager.run_active
	_manager = IsolatedManager.new()
	add_child(_manager)
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1280, 720)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	_hall = ENTRY.instantiate()
	_hall.run_manager_override = _manager
	_hall.audio_enabled = false
	_viewport.add_child(_hall)
	for attempt in 300:
		if _hall.is_ready_for_play():
			break
		await get_tree().physics_frame
	if not _check(_hall.is_ready_for_play(), "navigation, source and actor ready"):
		_finish()
		return
	_hall.set_process(false)
	_hall.reduced = false
	_hall.clock = 12.0
	_hall.advance_world(0)
	_hall.set_paused(true)
	_report["manifest"] = _hall.manifest_path
	_report["manifest_sha256"] = _hall.Manifest.manifest_hash(_hall.manifest_path)
	_report["source_image"] = str(_hall.definition.source.image)
	_report["source_sha256"] = FileAccess.get_sha256(str(_hall.definition.source.image))
	_report["world"] = [float(_hall.world_size.x), float(_hall.world_size.y)]
	_report["actor_height_ratio"] = _hall.ScaleReference.height_ratio(_hall.definition)
	_check(not _hall.get_entry_state().configured, "direct scene visit has no configured adventure")
	_check(
		not _hall.depart().success and _manager.start_attempts == 0,
		"direct visit cannot start an arbitrary run",
	)
	for extent: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(1200, 896)]:
		await _resize(extent)
		await _capture("overview_%dx%d.png" % [extent.x, extent.y])
		var menu := _hall.find_child("ThresholdMenu", true, false) as Control
		_check(
			Rect2(Vector2.ZERO, Vector2(extent)).encloses(menu.get_global_rect()),
			"menu remains inside viewport %s" % extent,
		)
	await _resize(Vector2i(1280, 720))
	await _verify_pause()
	await _verify_fog_motion()
	await _verify_fire_motion()
	await _verify_original()
	await _verify_occlusion()
	await _verify_menu_and_reduced()
	_check(_manager.start_attempts == 0, "no start requested during isolated visual QA")
	_check(GameManager.run_active == _run_active_before, "live run state preserved")
	_check(_save_hash() == _save_hash_before, "existing checkpoint bytes preserved")
	_finish()


func _resize(extent: Vector2i) -> void:
	_viewport.size = extent
	await _frames(8)
	_hall._fit_world()
	await _frames(3)


func _verify_pause() -> void:
	_hall.clock = 12.0
	_hall.advance_world(0)
	_hall.set_paused(true)
	var before: Image = await _capture("paused_before.png")
	var before_clock: float = _hall.clock
	_hall.advance_world(4.0)
	await _frames(8)
	var after: Image = await _capture("paused_after.png")
	var same: bool = before.get_data() == after.get_data()
	_check(is_equal_approx(_hall.clock, before_clock), "paused world does not advance its clock")
	_check(
		same,
		"paused painting and fog are pixel-identical",
		{ "mean_absolute_rgb": _difference(before, after) },
	)


func _verify_fog_motion() -> void:
	var actors := _hall.world.get_node("DepthSortedActors") as Node2D
	actors.hide()
	_hall.atmosphere.hide()
	_hall.landmarks_fx.hide()
	_hall._interface.hide()
	_hall.reduced = false
	_hall.clock = 0.0
	_hall.advance_world(0)
	# The base painting is held original here, so every changed pixel is fog.
	_hall.effect_material.set_shader_parameter("strength", 0.0)
	var before: Image = await _capture("fog_00s.png")
	for sample_time: float in [3.0, 6.0]:
		_hall.clock = sample_time
		_hall.advance_world(0)
		_hall.effect_material.set_shader_parameter("strength", 0.0)
		var sample: Image = await _capture("fog_%02ds.png" % int(sample_time))
		_check(
			_difference(before, sample) > 0.00001,
			"fog evolves at %s seconds" % sample_time,
			{ "mean_absolute_rgb": _difference(before, sample) },
		)
	_hall.clock = 24.0
	_hall.advance_world(0)
	_hall.effect_material.set_shader_parameter("strength", 0.0)
	var after: Image = await _capture("fog_24s.png")
	var difference: float = _difference(before, after)
	_check(_hall._fog.configured, "density fog is configured")
	_check(
		difference > 0.00001,
		"fog changes over 24 seconds with the underlying painting fixed",
		{ "mean_absolute_rgb": difference },
	)
	_report["fog_clock"] = _hall._fog._material.get_shader_parameter("effect_time")
	actors.show()
	_hall.atmosphere.show()
	_hall.landmarks_fx.show()
	_hall._interface.show()
	_hall.clock = 12.0
	_hall.advance_world(0)


func _verify_fire_motion() -> void:
	var actors := _hall.world.get_node("DepthSortedActors") as Node2D
	actors.hide()
	_hall.atmosphere.hide()
	_hall.landmarks_fx.hide()
	_hall._interface.hide()
	_hall._fog.hide()
	_hall.clock = 0.0
	_hall.advance_world(0)
	var before: Image = await _capture("fire_00s.png")
	_hall.clock = 0.37
	_hall.advance_world(0)
	var after: Image = await _capture("fire_037s.png")
	_check(
		_difference(before, after) > 0.000001,
		"painted flames and their local illumination animate",
		{ "mean_absolute_rgb": _difference(before, after) },
	)
	actors.show()
	_hall.atmosphere.show()
	_hall.landmarks_fx.show()
	_hall._interface.show()
	_hall._fog.show()
	_hall.clock = 12.0
	_hall.advance_world(0)


func _verify_original() -> void:
	_hall.set_original(true)
	await _capture("original.png")
	_check(
		is_zero_approx(float(_hall.effect_material.get_shader_parameter("strength"))),
		"original view disables painted material effects",
	)
	_check(not _hall._fog._panel.visible, "original view hides foreground fog")
	_hall.set_original(false)
	_hall.advance_world(0)


func _verify_occlusion() -> void:
	var review: Dictionary = _hall.definition.get("review", { }).get("occlusion_points", { })
	var actors := _hall.world.get_node("DepthSortedActors") as Node2D
	var cutouts: Array[Polygon2D] = []
	for child in actors.get_children():
		if child is Polygon2D:
			cutouts.append(child)
	_check(
		actors.y_sort_enabled and not cutouts.is_empty(),
		"actor and foreground cutouts share depth sorting",
	)
	for key: String in REVIEW_KEYS:
		var normalized: Array = review.get(key, [])
		if not _check(normalized.size() == 2, "review point exists: " + key):
			continue
		var position_native: Vector2 = _hall.point(normalized)
		var walkable: bool = _hall.nav.is_walkable(position_native)
		_check(walkable, "review point is walkable: " + key)
		# Direct placement is explicit: these are controlled visual depth probes.
		_hall.stop_movement()
		_hall.player.position = position_native
		_hall.player.play_idle()
		_hall.advance_world(0)
		var with_actor: Image = await _capture("hero_" + key + ".png")
		_hall.player.hide()
		var background: Image = await _capture("background_" + key + ".png")
		_hall.player.show()
		for cutout: Polygon2D in cutouts:
			cutout.hide()
		var unoccluded: Image = await _capture("no_cutouts_" + key + ".png")
		_hall.player.hide()
		var bare_background: Image = await _capture("bare_background_" + key + ".png")
		_hall.player.show()
		for cutout: Polygon2D in cutouts:
			cutout.show()
		var metrics: Dictionary = _actor_visibility(
			with_actor,
			background,
			unoccluded,
			bare_background,
		)
		metrics["normalized_ground"] = normalized
		metrics["walkable"] = walkable
		metrics["placement"] = "direct visual probe; no gameplay state mutation"
		_report.occlusion[key] = metrics
		_check(
			int(metrics.actor_pixels) > 100,
			"actor produces a measurable silhouette: " + key,
			metrics,
		)
		if key.ends_with("_behind"):
			_check(
				float(metrics.occluded_fraction) > 0.015,
				"foreground visibly covers the actor behind the statue: " + key,
				metrics,
			)
		else:
			_check(
				float(metrics.occluded_fraction) < 0.015,
				"actor remains in front of the statue: " + key,
				metrics,
			)
	_hall.player.position = _hall.point(_hall.definition.world.spawn)
	_hall.advance_world(0)


func _verify_menu_and_reduced() -> void:
	_hall.set_paused(false)
	await _click(_hall.find_child("ThresholdMenu", true, false) as Control)
	_check(
		_hall.get_entry_state().menu_open and _hall.paused,
		"menu opens through pointer input and pauses movement",
	)
	await _capture("menu.png")
	var toggles: Array[Node] = _hall._dialogue_content.find_children(
		"*",
		"CheckButton",
		true,
		false,
	)
	if not _check(toggles.size() == 1, "menu exposes the existing reduced-motion preference"):
		return
	var toggle := toggles[0] as CheckButton
	if toggle.button_pressed:
		await _click(toggle)
	await _click(toggle)
	_check(
		GameManager.is_reduced_motion_enabled() and _hall.reduced,
		"reduced motion applied by the real menu control",
	)
	await _capture("menu_reduced.png")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	_viewport.push_input(escape, true)
	await _frames(4)
	_check(not _hall.get_entry_state().menu_open, "Escape closes the menu")
	_hall.set_paused(true)
	var held: float = float(_hall._fog._material.get_shader_parameter("effect_time"))
	_hall.clock += 24.0
	_hall.advance_world(0)
	_check(
		is_equal_approx(float(_hall._fog._material.get_shader_parameter("effect_time")), held),
		"reduced fog holds its phase while world time changes",
	)
	await _capture("reduced_world.png")


func _actor_visibility(
	actual: Image,
	background: Image,
	without_cutouts: Image,
	bare_background: Image,
) -> Dictionary:
	var actor_pixels := 0
	var occluded_pixels := 0
	for y in actual.get_height():
		for x in actual.get_width():
			var baseline: Color = background.get_pixel(x, y)
			var exposed: Color = without_cutouts.get_pixel(x, y)
			var bare: Color = bare_background.get_pixel(x, y)
			if _distance(bare, exposed) <= 0.025:
				continue
			actor_pixels += 1
			var shown: Color = actual.get_pixel(x, y)
			if _distance(shown, baseline) + 0.01 < _distance(exposed, bare):
				occluded_pixels += 1
	return {
		"actor_pixels": actor_pixels,
		"occluded_pixels": occluded_pixels,
		"occluded_fraction": float(occluded_pixels) / maxi(actor_pixels, 1),
	}


func _distance(a: Color, b: Color) -> float:
	return maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b)))


func _difference(a: Image, b: Image) -> float:
	if a.get_size() != b.get_size():
		return INF
	var total := 0.0
	var samples := 0
	for y in range(0, a.get_height(), 2):
		for x in range(0, a.get_width(), 2):
			var first: Color = a.get_pixel(x, y)
			var second: Color = b.get_pixel(x, y)
			total += absf(first.r - second.r) + absf(first.g - second.g) + absf(first.b - second.b)
			samples += 3
	return total / maxi(samples, 1)


func _click(control: Control) -> void:
	if not _check(
		is_instance_valid(control) and control.is_visible_in_tree(),
		"requested control is visible",
	):
		return
	var at: Vector2 = control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = at
	_viewport.push_input(motion, true)
	await _frames(2)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = at
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		_viewport.push_input(event, true)
		await _frames(2)


func _capture(file_name: String) -> Image:
	await _frames(3)
	await RenderingServer.frame_post_draw
	var image: Image = _viewport.get_texture().get_image()
	var path: String = _output.path_join(file_name)
	var result: int = image.save_png(ProjectSettings.globalize_path(path))
	_check(result == OK, "capture saved: " + file_name)
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(image.get_data())
	_report.captures.append(
		{
			"path": path,
			"width": image.get_width(),
			"height": image.get_height(),
			"pixel_sha256": hash.finish().hex_encode(),
		}
	)
	return image


func _frames(count: int) -> void:
	for index in count:
		await get_tree().process_frame


func _check(passed: bool, label: String, details: Dictionary = { }) -> bool:
	_report.checks.append({ "passed": passed, "label": label, "details": details })
	return passed


func _save_hash() -> String:
	return (
		FileAccess.get_sha256(GameManager.expedition_save_path)
		if FileAccess.file_exists(GameManager.expedition_save_path)
		else "absent"
	)


func _finish() -> void:
	if _finished:
		return
	_finished = true
	GameManager.set_reduced_motion_enabled(_motion_before)
	_report["ok"] = not _report.checks.is_empty() and _report.checks.all(
			func(check: Dictionary):
				return bool(check.passed),
		)
	var file := FileAccess.open(_output.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(_report, "  "))
	file.close()
	print("CATABASE_THRESHOLD_VISUAL_%s report=%s" % ["PASS" if _report.ok else "FAIL", _output])
	_hall.queue_free()
	await _frames(3)
	# The audio mixer releases stopped, previously paused loop playbacks on its next tick.
	await get_tree().create_timer(0.20, true, false, true).timeout
	get_tree().quit(0 if _report.ok else 2)
