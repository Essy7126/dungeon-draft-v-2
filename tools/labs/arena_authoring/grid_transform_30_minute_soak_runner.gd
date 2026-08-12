extends Node

const OUTPUT := "res://artifacts/arena_authoring_speed/grid_transform_30_minute_soak.json"
const DURATION_SECONDS := 30.0 * 60.0
const GESTURE_COUNT := 100

var _canvas: ArenaStudioCanvas
var _arena: ArenaDefinition
var _session: ArenaEditSession
var _state := {"before": {}, "changed": false}
var _event_samples: Array[float] = []
var _release_samples: Array[float] = []
var _next_gesture := 0
var _started_msec := 0
var _baseline := {}
var _max_static_memory := 0.0
var _duration_seconds := DURATION_SECONDS
var _gesture_count := GESTURE_COUNT


func _ready() -> void:
	call_deferred("_start")


func _start() -> void:
	_apply_debug_overrides()
	_session = ArenaEditSession.new()
	if not _session.open(_fixture(), "", true, "grid_transform_30_minute_soak"):
		_finish({"ok": false, "error": "session_open_failed"})
		return
	_arena = _session.working_arena
	_canvas = ArenaStudioCanvas.new()
	_canvas.size = Vector2(1280, 720)
	add_child(_canvas)
	_canvas.set_arena(_arena)
	_canvas.set_tool(ArenaStudioCanvas.Tool.TRANSFORM_GRID)
	_canvas.stroke_started.connect(func(_action_name: String):
		_state.before = _arena.to_snapshot()
		_state.changed = false
	)
	_canvas.transform_commit_requested.connect(func(
			snapshot: GridTransformSnapshot,
			cells: Array[Vector2i],
			pixels: Array[Vector2]
		):
		snapshot.apply_to(_arena)
		_arena.calibration_cells = cells.duplicate()
		_arena.calibration_pixels = pixels.duplicate()
		ArenaRuntimeBridge.sync_runtime_resources(
			_arena, ArenaRuntimeBridge.SyncScope.GRID_TRANSFORM
		)
		_state.changed = true
	)
	_canvas.stroke_finished.connect(func(action_name: String):
		if _state.changed:
			var after: Dictionary = (_state.before as Dictionary).duplicate(false)
			after["grid_origin"] = [_arena.grid_origin.x, _arena.grid_origin.y]
			after["axis_x"] = [_arena.axis_x.x, _arena.axis_x.y]
			after["axis_y"] = [_arena.axis_y.x, _arena.axis_y.y]
			after["calibration_cells"] = _arena.calibration_cells.map(
				func(value): return [value.x, value.y]
			)
			after["calibration_pixels"] = _arena.calibration_pixels.map(
				func(value): return [value.x, value.y]
			)
			_session.commit(action_name, _state.before, after, true)
		_state.before = {}
		_state.changed = false
	)
	_canvas.stroke_cancelled.connect(func():
		_state.before = {}
		_state.changed = false
	)
	await get_tree().process_frame
	_baseline = _sample_state()
	_max_static_memory = float(_baseline.static_memory_bytes)
	_started_msec = Time.get_ticks_msec()
	var interval := _duration_seconds / float(_gesture_count)
	while _next_gesture < _gesture_count:
		await get_tree().create_timer(interval).timeout
		_perform_gesture(_next_gesture)
		_next_gesture += 1
		_max_static_memory = maxf(
			_max_static_memory,
			float(Performance.get_monitor(Performance.MEMORY_STATIC))
		)
	var elapsed := float(Time.get_ticks_msec() - _started_msec) / 1000.0
	while elapsed < _duration_seconds:
		await get_tree().create_timer(minf(1.0, _duration_seconds - elapsed)).timeout
		elapsed = float(Time.get_ticks_msec() - _started_msec) / 1000.0
	var final := _sample_state()
	var first_event: float = _event_samples.front() if not _event_samples.is_empty() else INF
	var last_event: float = _event_samples.back() if not _event_samples.is_empty() else INF
	var first_release: float = _release_samples.front() if not _release_samples.is_empty() else INF
	var last_release: float = _release_samples.back() if not _release_samples.is_empty() else INF
	_finish({
		"ok": _next_gesture == _gesture_count and elapsed >= _duration_seconds
			and int(final.nodes) == int(_baseline.nodes)
			and int(final.resources) == int(_baseline.resources)
			and int(final.signal_connections) == int(_baseline.signal_connections)
			and int(final.subviewports) == int(_baseline.subviewports)
			and last_event < 33.0 and last_release < 33.0,
		"duration_seconds": elapsed,
		"gesture_count": _next_gesture,
		"history_actions": _session.history.get_current_index(),
		"first_event_ms": first_event,
		"last_event_ms": last_event,
		"max_event_ms": _event_samples.max(),
		"first_release_ms": first_release,
		"last_release_ms": last_release,
		"max_release_ms": _release_samples.max(),
		"baseline": _baseline,
		"final": final,
		"max_static_memory_bytes": _max_static_memory,
		"static_memory_growth_bytes": int(final.static_memory_bytes) \
			- int(_baseline.static_memory_bytes),
	})


func _apply_debug_overrides() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--soak-seconds="):
			_duration_seconds = maxf(
				float(argument.trim_prefix("--soak-seconds=")), 0.1
			)
		elif argument.begins_with("--soak-gestures="):
			_gesture_count = maxi(
				int(argument.trim_prefix("--soak-gestures=")), 1
			)


func _perform_gesture(index: int) -> void:
	var start := _canvas._image_native_to_screen(_arena.grid_origin)
	if not _canvas._begin_transform_handle(
		ArenaStudioCanvas.TransformHandle.BODY, start, false, true
	):
		return
	var sign_value := 1.0 if index % 2 == 0 else -1.0
	var last_position := start
	var event_started := Time.get_ticks_usec()
	for step in range(1, 11):
		last_position = start + Vector2(3.0, -1.25) * sign_value * float(step) / 10.0
		var motion := InputEventMouseMotion.new()
		motion.position = last_position
		_canvas._handle_mouse_motion(motion)
	_canvas._process(0.0)
	_event_samples.append(float(Time.get_ticks_usec() - event_started) / 1000.0)
	var release_started := Time.get_ticks_usec()
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = last_position
	_canvas._handle_mouse_button(release)
	_release_samples.append(float(Time.get_ticks_usec() - release_started) / 1000.0)


func _sample_state() -> Dictionary:
	return {
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"resources": int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),
		"signal_connections": _connection_count(),
		"subviewports": _subviewport_count(self),
		"static_memory_bytes": int(Performance.get_monitor(Performance.MEMORY_STATIC)),
	}


func _connection_count() -> int:
	var total := 0
	for signal_name in [
		&"stroke_started", &"stroke_finished", &"stroke_cancelled",
		&"calibration_preview_requested", &"anchors_preview_requested",
		&"transform_commit_requested",
	]:
		total += _canvas.get_signal_connection_list(signal_name).size()
	return total


func _subviewport_count(root: Node) -> int:
	var total := 1 if root is SubViewport else 0
	for child in root.get_children():
		total += _subviewport_count(child)
	return total


func _fixture() -> ArenaDefinition:
	var arena := ArenaDefinition.new()
	arena.set_identity("30 minute soak", "grid_transform_30_minute_soak")
	arena.grid_size = Vector2i(14, 14)
	arena.source_image_size = Vector2i(1024, 768)
	arena.background_path = "res://addons/gut/icon.png"
	arena.grid_origin = Vector2(512, 120)
	arena.axis_x = Vector2(32, 16)
	arena.axis_y = Vector2(-32, 16)
	arena.calibration_cells = [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.DOWN]
	arena.calibration_pixels = [
		arena.grid_origin,
		arena.grid_origin + arena.axis_x,
		arena.grid_origin + arena.axis_y,
	]
	for y in range(arena.grid_size.y):
		for x in range(arena.grid_size.x):
			var definition := arena.ensure_cell(Vector2i(x, y))
			definition.defined = true
			definition.playable = true
			definition.terrain_id = &"neutral"
	ArenaRuntimeBridge.sync_runtime_resources(arena)
	return arena


func _finish(report: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT.get_base_dir()))
	var file := FileAccess.open(OUTPUT, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "  "))
		file.close()
	print("GRID_TRANSFORM_30_MINUTE_SOAK=", JSON.stringify(report))
	get_tree().quit(0 if bool(report.get("ok", false)) else 1)
