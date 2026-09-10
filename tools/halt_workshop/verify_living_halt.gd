extends Node

const SCENE := preload("res://hub/painted_halt/LivingHalt.tscn")
const BackdropService := preload(
	"res://addons/dungeon_draft_arena_studio/services/arena_backdrop_transaction_service.gd"
)
const BackdropSource := preload(
	"res://addons/dungeon_draft_arena_studio/domain/arena_backdrop_source_definition.gd"
)
const Arena := preload("res://addons/dungeon_draft_arena_studio/domain/arena_definition.gd")
var output := "res://artifacts/emerald_sanctuary"
var hall: Node2D
var checks: Array[Dictionary] = []
var captures: Array[String] = []
var samples := 0
var unsafe := 0
var _rendered := false
var _resolution := ""
var _source_evidence := { }


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output-root="):
			output = arg.trim_prefix("--output-root=")
	DirAccess.make_dir_recursive_absolute(output)
	_rendered = DisplayServer.get_name() != "headless"
	for size: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		get_window().size = size
		_resolution = "%dx%d" % [size.x, size.y]
		hall = SCENE.instantiate()
		add_child(hall)
		for attempt in 180:
			if hall.is_ready_for_play():
				break
			await get_tree().process_frame
		_check("ready", hall.is_ready_for_play())
		if not hall.is_ready_for_play():
			hall.queue_free()
			await get_tree().process_frame
			continue
		hall.set_process(false)
		_source_evidence = {
			"manifest": hall.manifest_path,
			"manifest_sha256": FileAccess.get_sha256(hall.manifest_path),
			"source_sha256": FileAccess.get_sha256(str(hall.definition.source.image)),
			"build_sha256": FileAccess.get_sha256(
				str(hall.definition.build_dir).path_join("build.json")
			),
		}
		var source := BackdropSource.new()
		source.background_path = str(hall.definition.source.image)
		source.source_image_size = Vector2i(
			hall.definition.source.size[0],
			hall.definition.source.size[1],
		)
		var arena := Arena.new()
		arena.source_image_size = source.source_image_size
		var inspection := BackdropService.new().inspect(
			arena,
			source,
			BackdropService.CopyMode.BACKGROUND_ONLY,
		)
		_check("studio_backdrop_loadable", bool(inspection.get("ok", false)))
		_check(
			"studio_source_dimensions",
			inspection.get("actual_image_size", Vector2i.ZERO) == source.source_image_size,
		)
		await _capture("arrival")
		var frame: Dictionary = hall.player.get_visual_state()
		_check(
			"achilles_visual_ready",
			bool(frame.visible) if frame.has("visible") else hall.player.is_visual_ready(),
		)
		var start: Vector2 = hall.player.position
		for landmark: Dictionary in hall.definition.landmarks:
			await _walk(hall.point(landmark.point), str(landmark.id))
		await _walk(start, "return_bridge")
		for at: Array in hall.definition.review.forbidden_points:
			_check("blocked_destination", not hall.request_move(hall.point(at)))
		_check("redirect_start", hall.request_move(hall.point(hall.definition.landmarks[0].point)))
		for step in 20:
			hall.advance_world(1.0 / 60.0)
		var paused_at: Vector2 = hall.player.position
		var before_frame: Dictionary = hall.player.get_visual_state()
		var before_clock: float = hall.clock
		hall.set_paused(true)
		hall.advance_world(2.0)
		_check("pause_feet", hall.player.position == paused_at)
		_check("pause_walk_frame", hall.player.get_visual_state().frame == before_frame.frame)
		_check("pause_effect_clock", hall.clock == before_clock)
		_check("paused_input_rejected", not hall.request_move(start))
		await _capture("paused_walk")
		hall.set_paused(false)
		_check("redirect", hall.request_move(start))
		_check("redirect_no_teleport", hall.player.position == paused_at)
		hall.stop_movement()
		_check(
			"stop_idle",
			not hall.is_player_moving() and str(hall.player.get_visual_state().stem) == "idle",
		)
		hall.set_zoom(1.5)
		var screen: Vector2 = hall.world.to_global(hall.player.position)
		_check("zoom_coordinate_roundtrip", hall.world.to_local(screen).distance_to(
				hall.player.position
			) < 0.01)
		await _capture("zoom")
		hall.set_zoom(1.0)
		if _rendered:
			await _test_rendering()
		hall.queue_free()
		await get_tree().process_frame
	_check("all_movement_samples_safe", samples > 0 and unsafe == 0)
	if "--record" in OS.get_cmdline_user_args() and _rendered:
		await _record()
	var failures: Array[Dictionary] = []
	for check: Dictionary in checks:
		if not check.passed:
			failures.append(check)
	var report := {
		"passed": failures.is_empty(),
		"check_count": checks.size(),
		"checks": checks,
		"failures": failures,
		"captures": captures,
		"movement_samples": samples,
		"unsafe_samples": unsafe,
		"rendered": _rendered,
		"scene": "res://hub/painted_halt/LivingHalt.tscn",
		"date": Time.get_datetime_string_from_system(true),
		"source_evidence": _source_evidence,
	}
	var file := FileAccess.open(output.path_join("verification.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print(
		"LIVING_HALT_VERIFY: %s; %d checks, %d captures, %d movement samples, %d unsafe"
		% [failures.is_empty(), checks.size(), captures.size(), samples, unsafe]
	)
	get_tree().quit(0 if failures.is_empty() else 1)


func _walk(target: Vector2, label: String) -> void:
	_check("path_" + label, hall.request_move(target))
	for step in 2400:
		if not hall.is_player_moving():
			break
		var before: Vector2 = hall.player.position
		hall.advance_world(1.0 / 60.0)
		samples += 1
		if not hall.nav.is_walkable(hall.player.position) or before.distance_to(
				hall.player.position
			) > 5.0:
			unsafe += 1
	_check("arrival_" + label, hall.player.position.distance_to(target) < 0.3)
	await _capture(label)


func _check(label: String, passed: bool, details: Variant = null) -> void:
	checks.append({ "id": label, "resolution": _resolution, "passed": passed, "details": details })
	if not passed:
		push_error("HALT_CHECK: " + label + " " + str(details))


func _capture(label: String) -> void:
	if not _rendered:
		return
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := output.path_join(_resolution + "_" + label + ".png")
	_check("capture_" + label, image.save_png(ProjectSettings.globalize_path(path)) == OK)
	captures.append(path)


func _image_at(time: float) -> Image:
	hall.clock = time
	hall.advance_world(0.0)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	return get_viewport().get_texture().get_image()


func _difference(a: Image, b: Image, normalized: Array, radius := 12) -> float:
	var center: Vector2 = hall.world.to_global(hall.point(normalized))
	var total := 0.0
	var count := 0
	for y in range(maxi(0, int(center.y) - radius), mini(a.get_height(), int(center.y) + radius)):
		for x in range(maxi(0, int(center.x) - radius), mini(a.get_width(), int(center.x) + radius)):
			var p := a.get_pixel(x, y)
			var q := b.get_pixel(x, y)
			total += absf(p.r - q.r) + absf(p.g - q.g) + absf(p.b - q.b)
			count += 3
	return total / maxf(count, 1)


func _test_rendering() -> void:
	hall.set_chrome_visible(false)
	hall.player.hide()
	for id: String in hall.layers:
		hall.set_layer(id, false)
	hall.set_layer("water", true)
	var first := await _image_at(1.0)
	var second := await _image_at(2.1)
	var change := _difference(first, second, hall.definition.review.water_pixel)
	_check("water_moves", change > 0.001, change)
	change = _difference(first, second, hall.definition.review.waterfall_pixel)
	_check("cascade_moves", change > 0.001, change)
	change = _difference(first, second, hall.definition.review.stable_pixel, 5)
	_check("dry_stone_stable_water_only", change < 0.001, change)
	_check(
		"water_click_ripple",
		hall.trigger_ripple(hall.point(hall.definition.review.water_pixel)),
	)
	_check(
		"stone_rejects_ripple",
		not hall.trigger_ripple(hall.point(hall.definition.review.stable_pixel)),
	)
	hall.set_layer("water", false)
	hall.set_layer("fire", true)
	first = await _image_at(3.0)
	second = await _image_at(3.7)
	change = _difference(first, second, hall.definition.review.fire_pixel)
	_check("torch_moves", change > 0.001, change)
	if hall.definition.review.has("foliage_pixel"):
		hall.set_layer("fire", false)
		hall.set_layer("foliage", true)
		first = await _image_at(1.0)
		second = await _image_at(3.0)
		change = _difference(first, second, hall.definition.review.foliage_pixel)
		_check("foliage_moves", change > 0.001, change)
		hall.set_layer("foliage", false)
	hall.set_layer("atmosphere", true)
	hall.set_layer("water", true)
	# Same material clock isolates atmosphere from the painting beneath it.
	hall.clock = 7.0
	hall.advance_world(0.0)
	hall.atmosphere.set_state(1.0, 1.0, true, true, true)
	await RenderingServer.frame_post_draw
	first = get_viewport().get_texture().get_image()
	hall.atmosphere.set_state(5.0, 1.0, true, true, true)
	await RenderingServer.frame_post_draw
	second = get_viewport().get_texture().get_image()
	change = 0.0
	if not hall.definition.cascades.is_empty():
		change = _difference(first, second, hall.definition.cascades[0].splash, 35)
	_check("atmosphere_spray_moves", change > 0.0001, change)
	for id: String in hall.layers:
		hall.set_layer(id, true)
	hall.set_paused(true)
	first = await _image_at(8.0)
	hall.advance_world(2.0)
	await RenderingServer.frame_post_draw
	second = get_viewport().get_texture().get_image()
	_check("paused_render_stable", first.get_data() == second.get_data())
	hall.set_paused(false)
	hall.reduced = true
	hall.advance_world(0.0)
	_check(
		"reduced_effect_strength",
		is_equal_approx(float(hall.effect_material.get_shader_parameter("strength")), 0.28),
	)
	hall.reduced = false
	hall.set_original(true)
	first = await _image_at(4.0)
	second = await _image_at(6.0)
	_check(
		"original_water_stable",
		_difference(first, second, hall.definition.review.water_pixel) == 0.0,
	)
	_check(
		"original_fire_stable",
		_difference(first, second, hall.definition.review.fire_pixel) == 0.0,
	)
	await _capture("original")
	hall.set_original(false)
	hall.player.show()
	await _capture("living_clean")
	hall.nav.debug_enabled = true
	await _capture("navigation")
	hall.nav.debug_enabled = false
	hall.set_chrome_visible(true)


func _record() -> void:
	get_window().size = Vector2i(1920, 1080)
	hall = SCENE.instantiate()
	add_child(hall)
	for attempt in 180:
		if hall.is_ready_for_play():
			break
		await get_tree().process_frame
	if not hall.is_ready_for_play():
		return
	hall.set_process(false)
	hall.set_chrome_visible(false)
	var frames := output.path_join("frames")
	DirAccess.make_dir_recursive_absolute(frames)
	var target_index := mini(1, hall.definition.landmarks.size() - 1)
	for frame in 336:
		if frame > 12 and not hall.is_player_moving():
			hall.request_move(hall.point(hall.definition.landmarks[target_index].point))
			target_index = (target_index + 1) % hall.definition.landmarks.size()
		hall.advance_world(1.0 / 24.0)
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		if image.save_jpg(
			ProjectSettings.globalize_path(frames.path_join("frame_%04d.jpg" % frame)),
			0.95,
		) != OK:
			_check("recording_frame", false)
			break
	print("LIVING_HALT_RECORD: 336 real Godot frames, 1920x1080, 24 FPS")
	hall.queue_free()
	await get_tree().process_frame
