extends Node

## Real Hall controller, navigation server and Achilles sprite backend.
## Use -- --capture with an active renderer for occlusion/screenshots.
const SCENE_PATH := "res://tools/labs/apothecary_living_map/PlayableHall.tscn"
const LAYOUT_PATH := "res://tools/labs/apothecary_living_map/hall_walk_layout.json"
const OUTPUT_DIR := "res://artifacts/hall_walk"
const STEP := 1.0 / 60.0
const MAX_STEPS := 7200
const NATIVE_SIZE := Vector2(1376, 768)
const FOUNTAIN_FRONT := Vector2(646, 628)
const FOUNTAIN_BACK := Vector2(647, 414)
const FOUNTAIN_LEFT := Vector2(474, 548)
const FOUNTAIN_RIGHT := Vector2(814, 530)
const BEHIND_CAPTURE := Vector2(647, 478)
const FRONT_CAPTURE := Vector2(646, 610)
const BRIDGE_OUTER := Vector2(257, 684)
const BRIDGE_INNER := Vector2(431, 623)
const REQUIRED_METHODS: Array[StringName] = [
	&"is_ready_for_play", &"get_player_position", &"request_move", &"stop_movement",
	&"is_player_moving", &"get_player_visual_state", &"get_walk_state",
	&"set_chrome_visible", &"native_to_viewport", &"set_animation_paused",
	&"set_effect_time", &"get_navigation_service", &"advance_world",
]

var _root: Window
var _hall: Node
var _nav: RefCounted
var _layout: Dictionary = {}
var _resolution := ""
var _checks: Array[Dictionary] = []
var _captures: Array[Dictionary] = []
var _journeys: Array[Dictionary] = []
var _failures: Array[String] = []
var _capture_enabled := false
var _started_ms := 0
var _samples := 0
var _unsafe_samples := 0
var _maximum_step := 0.0


func _ready() -> void:
	_root = get_tree().root
	_started_ms = Time.get_ticks_msec()
	_capture_enabled = "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless"
	_run.call_deferred()


func _run() -> void:
	var directory_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_check("artifact_directory_available", directory_error == OK)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT_PATH))
	_check("layout_loads", parsed is Dictionary)
	if parsed is Dictionary:
		_layout = parsed
	var scene := load(SCENE_PATH) as PackedScene
	_check("scene_loads", scene != null)
	if scene != null and not _layout.is_empty():
		_root.mode = Window.MODE_WINDOWED
		_root.size = Vector2i(1280, 720)
		_resolution = "1280x720"
		_hall = scene.instantiate()
		_root.add_child(_hall)
		var valid_api := true
		for method: StringName in REQUIRED_METHODS:
			var exists := _hall.has_method(method)
			_check("api_" + String(method), exists)
			valid_api = valid_api and exists
		if valid_api:
			var deadline := Time.get_ticks_msec() + 20000
			while not bool(_hall.call("is_ready_for_play")) and Time.get_ticks_msec() < deadline:
				await get_tree().process_frame
			var ready := bool(_hall.call("is_ready_for_play"))
			_check("ready_within_20_seconds", ready)
			if ready:
				_hall.set_process(false)
				_nav = _hall.call("get_navigation_service")
				_check("real_navigation_service_available", _nav != null and _nav.has_method("is_walkable"))
				if _nav != null and _nav.has_method("is_walkable"):
					_hall.call("set_chrome_visible", false)
					await _exercise_resolution()
					await _resize_during_journey(Vector2i(1920, 1080))
					await _exercise_resolution()
					_check("every_movement_sample_walkable", _samples > 0 and _unsafe_samples == 0, {"samples": _samples, "unsafe": _unsafe_samples})
					_check("movement_has_no_teleport_steps", _maximum_step <= 20.0, {"maximum_native_distance_per_60hz_step": _maximum_step})
		_hall.queue_free()
		await _settle()
		_hall = null
	_write_report()
	for failure: String in _failures:
		push_error("HALL_WALK: " + failure)
	var result := "FAIL" if not _failures.is_empty() else ("PASS_WITH_CAPTURES" if _capture_enabled else "PASS_RUNTIME_ONLY")
	print("HALL_WALK: %s (%d checks; %d movement samples; %d captures). Report: %s/verification.json" % [result, _checks.size(), _samples, _captures.size(), OUTPUT_DIR])
	get_tree().quit(0 if _failures.is_empty() else 1)


func _exercise_resolution() -> void:
	_hall.call("set_animation_paused", false)
	_hall.call("set_chrome_visible", false)
	var spawn := _point(_layout.get("spawn", []))
	if _position().distance_to(spawn) > 2.0:
		await _move_and_arrive(spawn, "return_to_spawn")
	_check("spawn_matches_layout", _position().distance_to(spawn) <= 2.0)
	_check("spawn_walkable", _walkable(_position()))
	_check("navigation_reports_ready", bool(_walk_state().get("navigation_ready", false)))
	_validate_backend("idle", "spawn")
	_hall.call("set_chrome_visible", true)
	await _capture("spawn_with_controls")
	_hall.call("set_chrome_visible", false)
	await _capture("spawn_clean")
	_validate_map_fit()
	await _exercise_pointer_controls()
	await _exercise_pause()
	await _exercise_invalid_destinations()

	await _move_and_arrive(BRIDGE_OUTER, "bridge_outer")
	await _move_and_arrive(BRIDGE_INNER, "bridge_crossing")
	await _capture("bridge_arrival")
	await _move_and_arrive(FOUNTAIN_FRONT, "fountain_front_start")
	await _move_and_arrive(FOUNTAIN_LEFT, "fountain_left_side")
	await _move_and_arrive(FOUNTAIN_BACK, "fountain_left_to_back")
	await _move_and_arrive(BEHIND_CAPTURE, "fountain_behind_overlap")
	await _capture("behind_fountain")
	await _move_and_arrive(FOUNTAIN_RIGHT, "fountain_right_side")
	await _move_and_arrive(FRONT_CAPTURE, "fountain_right_to_front")
	await _capture("in_front_of_fountain")
	# This direct target is blocked by the fountain in a straight line: the
	# navigation server must produce a longer route with safe intermediate points.
	var direct_start := _position()
	if _request(FOUNTAIN_BACK, "automatic_fountain_detour"):
		var route := _current_path()
		var route_length := _path_length(route)
		_check("fountain_forces_detour", route.size() >= 3 and route_length > direct_start.distance_to(FOUNTAIN_BACK) + 25.0, {"vertices": route.size(), "path_length": route_length, "straight_distance": direct_start.distance_to(FOUNTAIN_BACK)})
		await _advance_to(FOUNTAIN_BACK, "automatic_fountain_detour")

	for landmark: Dictionary in _layout.get("landmarks", []):
		var id := String(landmark.get("id", "unnamed"))
		var destination := _point(landmark.get("approach", []))
		await _move_and_arrive(destination, "visit_" + id)
		_validate_backend("idle", id + "_arrival")
		await _capture("at_" + id)
	_check("three_stall_approaches_present", (_layout.get("landmarks", []) as Array).size() == 3)
	await _move_and_arrive(spawn, "return_from_stalls")


func _exercise_pointer_controls() -> void:
	var initial := _position()
	await _click_native(FOUNTAIN_FRONT)
	_check("left_click_starts_path", _moving())
	_check("left_click_does_not_teleport", _position().distance_to(initial) < 0.01)
	_check("left_click_target_in_native_coordinates", _target().distance_to(FOUNTAIN_FRONT) < 1.0)
	_validate_path("left_click")
	var observed_frames: Dictionary = {}
	for step in range(24):
		_advance_sample()
		var state := _visual_state()
		observed_frames[str(state.get("frame", -1))] = true
	_validate_backend("walk", "during_walk")
	_check("real_walk_frames_advance", observed_frames.size() >= 2, observed_frames.keys())
	_check("walk_moves_player", _position().distance_to(initial) > 4.0)
	await _capture("walking")
	var before_redirect := _position()
	await _click_native(FOUNTAIN_LEFT)
	_check("new_click_replaces_destination", _target().distance_to(FOUNTAIN_LEFT) < 1.0)
	_check("redirect_does_not_teleport", _position().distance_to(before_redirect) < 0.01)
	_validate_path("redirect")
	for step in range(12):
		_advance_sample()
	await _click_native(_position(), MOUSE_BUTTON_RIGHT)
	var stopped := _position()
	_check("right_click_stops_movement", not _moving())
	for step in range(20):
		_advance_sample()
	_check("right_click_stop_persists", _position().distance_to(stopped) < 0.01)
	_validate_backend("idle", "right_click_stop")


func _exercise_pause() -> void:
	if not _request(FOUNTAIN_FRONT, "pause_journey"):
		return
	for step in range(10):
		_advance_sample()
	_hall.call("set_animation_paused", true)
	var frozen_position := _position()
	var frozen_visual := _visual_state()
	for step in range(30):
		_advance_sample()
	_check("pause_freezes_position", _position().distance_to(frozen_position) < 0.01)
	_check("pause_freezes_sprite_frame", _same_visual_time(frozen_visual, _visual_state()))
	_check("pause_reported", bool(_walk_state().get("paused", false)))
	await _capture("paused_mid_walk")
	_hall.call("set_animation_paused", false)
	for step in range(10):
		_advance_sample()
	_check("resume_continues_path", _position().distance_to(frozen_position) > 1.0)
	await _advance_to(FOUNTAIN_FRONT, "resumed_journey")
	_validate_backend("idle", "paused_journey_arrival")


func _exercise_invalid_destinations() -> void:
	var invalid: Array[Dictionary] = [
		{"id": "fountain", "point": Vector2(630, 540)},
		{"id": "left_water", "point": Vector2(170, 581)},
		{"id": "right_water", "point": Vector2(1138, 610)},
		{"id": "bottom_water", "point": Vector2(647, 755)},
		{"id": "relic_counter", "point": Vector2(448, 393)},
		{"id": "arcane_counter", "point": Vector2(1030, 430)},
		{"id": "amphorae", "point": Vector2(851, 361)},
	]
	_hall.call("stop_movement")
	for item: Dictionary in invalid:
		var destination: Vector2 = item.point
		var before := _position()
		_check("navigation_rejects_" + String(item.id), not _walkable(destination))
		_check("move_rejects_" + String(item.id), not bool(_hall.call("request_move", destination)))
		_check("invalid_move_keeps_position_" + String(item.id), _position().distance_to(before) < 0.01)
		await _click_native(destination)
		_check("invalid_click_starts_no_movement_" + String(item.id), not _moving())
		_check("invalid_click_keeps_position_" + String(item.id), _position().distance_to(before) < 0.01)


func _resize_during_journey(size: Vector2i) -> void:
	if _request(FOUNTAIN_FRONT, "resize_journey"):
		for step in range(12):
			_advance_sample()
	var before := _position()
	var target_before := _target()
	var path_before := _current_path()
	var moving_before := _moving()
	_root.size = size
	_resolution = "%dx%d" % [size.x, size.y]
	await _settle()
	_check("resize_preserves_native_position", _position().distance_to(before) < 0.01)
	_check("resize_preserves_native_target", _target().distance_to(target_before) < 0.01)
	_check("resize_preserves_path", _current_path() == path_before)
	_check("resize_preserves_movement_state", _moving() == moving_before)
	_validate_map_fit()
	await _capture("resized_mid_walk")
	if moving_before:
		await _advance_to(target_before, "resize_journey_finishes")


func _move_and_arrive(destination: Vector2, label: String) -> void:
	if _position().distance_to(destination) <= 1.0:
		_check(label + "_already_at_destination", _walkable(_position()))
		return
	if _request(destination, label):
		await _advance_to(destination, label)


func _request(destination: Vector2, label: String) -> bool:
	var before := _position()
	var accepted := bool(_hall.call("request_move", destination))
	_check(label + "_accepted", accepted, {"from": _pair(before), "target": _pair(destination)})
	_check(label + "_request_does_not_teleport", _position().distance_to(before) < 0.01)
	if accepted:
		_validate_path(label)
	return accepted


func _advance_to(destination: Vector2, label: String) -> void:
	var start := _position()
	var traveled := 0.0
	var unsafe_before := _unsafe_samples
	var steps := 0
	while _moving() and steps < MAX_STEPS:
		traveled += _advance_sample()
		steps += 1
		if steps % 120 == 0:
			await get_tree().process_frame
	var arrived := not _moving() and _position().distance_to(destination) <= 2.0
	_check(label + "_arrives", arrived, {"position": _pair(_position()), "target": _pair(destination), "steps": steps})
	_check(label + "_all_steps_walkable", _unsafe_samples == unsafe_before)
	_journeys.append({"id": label, "resolution": _resolution, "from": _pair(start), "target": _pair(destination), "final": _pair(_position()), "traveled_native_pixels": traveled, "simulation_steps": steps, "unsafe_samples": _unsafe_samples - unsafe_before, "arrived": arrived})
	if not arrived:
		_hall.call("stop_movement")


func _advance_sample() -> float:
	var before := _position()
	_hall.call("advance_world", STEP)
	var after := _position()
	_samples += 1
	if not _walkable(after):
		_unsafe_samples += 1
	var distance := before.distance_to(after)
	_maximum_step = maxf(_maximum_step, distance)
	return distance


func _validate_path(label: String) -> void:
	var path := _current_path()
	var samples := 0
	var unsafe := 0
	for point: Vector2 in path:
		samples += 1
		if not _walkable(point):
			unsafe += 1
	for index in range(1, path.size()):
		var count := maxi(1, ceili(path[index - 1].distance_to(path[index]) / 3.0))
		for step in range(count + 1):
			var point := path[index - 1].lerp(path[index], float(step) / float(count))
			samples += 1
			if not _walkable(point):
				unsafe += 1
	_check(label + "_path_remains_walkable", samples > 0 and unsafe == 0, {"vertices": path.size(), "samples": samples, "unsafe": unsafe})


func _validate_backend(expected_stem: String, label: String) -> void:
	var state := _visual_state()
	_check(label + "_uses_real_achilles_backend", String(state.get("backend", "")) == "achilles_sprite_2d" and bool(state.get("visible", false)) and bool(state.get("manual_clock", false)), state)
	_check(label + "_animation_" + expected_stem, String(state.get("stem", "")) == expected_stem and String(state.get("animation", "")).begins_with(expected_stem + "_"), state)
	_check(label + "_sprite_frame_available", int(state.get("frame", -1)) >= 0)
	if expected_stem == "walk":
		_check(label + "_distance_driven_stride", bool(state.get("distance_driven_move", false)))


func _validate_map_fit() -> void:
	var origin: Vector2 = _hall.call("native_to_viewport", Vector2.ZERO)
	var corner: Vector2 = _hall.call("native_to_viewport", NATIVE_SIZE)
	_check("native_map_fits_viewport", origin.x >= -1.0 and origin.y >= -1.0 and corner.x <= _root.size.x + 1.0 and corner.y <= _root.size.y + 1.0)
	var scale_x := (corner.x - origin.x) / NATIVE_SIZE.x
	var scale_y := (corner.y - origin.y) / NATIVE_SIZE.y
	_check("native_map_preserves_aspect", scale_x > 0.0 and absf(scale_x - scale_y) < 0.002)


func _same_visual_time(before: Dictionary, after: Dictionary) -> bool:
	return before.get("animation", "") == after.get("animation", "") and int(before.get("frame", -1)) == int(after.get("frame", -2)) and is_equal_approx(float(before.get("frame_progress", -1.0)), float(after.get("frame_progress", -2.0)))


func _position() -> Vector2:
	return _hall.call("get_player_position")


func _moving() -> bool:
	return bool(_hall.call("is_player_moving"))


func _walk_state() -> Dictionary:
	return _hall.call("get_walk_state")


func _visual_state() -> Dictionary:
	return _hall.call("get_player_visual_state")


func _walkable(point: Vector2) -> bool:
	return bool(_nav.call("is_walkable", point))


func _target() -> Vector2:
	return _point(_walk_state().get("target", []))


func _current_path() -> PackedVector2Array:
	var result := PackedVector2Array()
	for value: Variant in _walk_state().get("path", []):
		result.append(_point(value))
	return result


func _path_length(path: PackedVector2Array) -> float:
	var length := 0.0
	for index in range(1, path.size()):
		length += path[index - 1].distance_to(path[index])
	return length


func _point(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return Vector2.INF


func _pair(point: Vector2) -> Array[float]:
	return [point.x, point.y]


func _click_native(point: Vector2, button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	var viewport_point: Vector2 = _hall.call("native_to_viewport", point)
	var motion := InputEventMouseMotion.new()
	motion.position = viewport_point
	motion.global_position = viewport_point
	Input.parse_input_event(motion)
	var press := InputEventMouseButton.new()
	press.position = viewport_point
	press.global_position = viewport_point
	press.button_index = button
	press.pressed = true
	Input.parse_input_event(press)
	await get_tree().process_frame
	var release := InputEventMouseButton.new()
	release.position = viewport_point
	release.global_position = viewport_point
	release.button_index = button
	Input.parse_input_event(release)
	await _settle()


func _settle() -> void:
	for frame in range(3):
		await get_tree().process_frame


func _capture(label: String) -> void:
	if not _capture_enabled:
		return
	var was_paused := bool(_walk_state().get("paused", false))
	_hall.call("set_animation_paused", true)
	_hall.call("set_effect_time", 0.8)
	await _settle()
	await RenderingServer.frame_post_draw
	var image := _root.get_texture().get_image()
	var valid := image != null and not image.is_empty()
	var path := OUTPUT_DIR.path_join(_resolution + "_" + label + ".png")
	var error := image.save_png(ProjectSettings.globalize_path(path)) if valid else ERR_CANT_CREATE
	_check("capture_" + label, error == OK)
	_check("capture_size_" + label, valid and image.get_size() == _root.size)
	_captures.append({"id": label, "resolution": _resolution, "path": path, "saved": error == OK, "player_position": _pair(_position()), "walk_state": _walk_state(), "visual_state": _visual_state()})
	_hall.call("set_animation_paused", was_paused)


func _check(id: String, passed: bool, details: Variant = null) -> void:
	_checks.append({"id": id, "resolution": _resolution, "passed": passed, "details": details})
	if not passed:
		_failures.append("%s [%s]" % [id, _resolution])


func _write_report() -> void:
	var report := {
		"scene": SCENE_PATH, "layout": LAYOUT_PATH,
		"created_utc": Time.get_datetime_string_from_system(true),
		"elapsed_ms": Time.get_ticks_msec() - _started_ms,
		"godot_version": Engine.get_version_info().string,
		"display_server": DisplayServer.get_name(),
		"rendering_method": RenderingServer.get_current_rendering_method(),
		"capture_enabled": _capture_enabled,
		"result": "FAIL" if not _failures.is_empty() else ("PASS_WITH_CAPTURES" if _capture_enabled else "PASS_RUNTIME_ONLY"),
		"check_count": _checks.size(), "failures": _failures,
		"movement_samples": _samples, "unsafe_movement_samples": _unsafe_samples,
		"maximum_native_step": _maximum_step,
		"checks": _checks, "journeys": _journeys, "captures": _captures,
		"method": "Real PlayableHall scene after autoloads, production navigation service and Achilles sprite backend. Mouse events exercise movement/redirect/stop. Public advance_world runs 60 Hz deterministic steps; every player step and path edge is checked for walkability. No fixture teleports. Fountain is circumnavigated via both sides and direct navigation detour; both bridge endpoints and three stalls are visited. A live in-progress journey survives resize from 1280x720 to 1920x1080. Rendered captures are optional and never claimed in headless mode.",
		"occlusion_review": "Screenshots behind_fountain at native (647,478) and in_front_of_fountain at (646,610) intentionally overlap the fountain silhouette. Layer appearance requires visual review of these renderer captures; structural navigation checks alone do not claim pixel occlusion correctness.",
	}
	var path := OUTPUT_DIR.path_join("verification.json")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_failures.append("Cannot write " + path)
		return
	file.store_string(JSON.stringify(report, "\t"))
