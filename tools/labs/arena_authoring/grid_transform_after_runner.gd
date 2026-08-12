extends Node

const OUTPUT := "res://artifacts/arena_authoring_speed/grid_transform_after.json"
const EVENT_COUNT := 500
const GESTURE_COUNT := 100


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var studio := ArenaStudioMain.new()
	studio.size = Vector2(1280, 720)
	add_child(studio)
	await get_tree().process_frame
	await get_tree().process_frame
	studio._on_tool_selected(ArenaStudioCanvas.Tool.TRANSFORM_GRID)
	var canvas := studio.canvas
	var arena := studio.arena
	var fingerprint_before := ArenaEditSession.fingerprint(arena.to_snapshot())
	var start := canvas._image_native_to_screen(arena.grid_origin)
	if not canvas._begin_transform_handle(
		ArenaStudioCanvas.TransformHandle.BODY, start, false, true
	):
		_finish({"ok": false, "error": "drag_start_failed"})
		return
	var last_position := start
	ArenaRuntimeBridge.begin_instrumentation()
	var started := Time.get_ticks_usec()
	var max_event_usec := 0
	for index in range(1, EVENT_COUNT + 1):
		last_position = start + Vector2(index * 0.08, index * -0.035)
		var motion := InputEventMouseMotion.new()
		motion.position = last_position
		var event_started := Time.get_ticks_usec()
		canvas._handle_mouse_motion(motion)
		max_event_usec = maxi(max_event_usec, Time.get_ticks_usec() - event_started)
	var drag_usec := Time.get_ticks_usec() - started
	var queued_metrics := canvas.precision_preview_metrics()
	canvas._process(0.0)
	var applied_metrics := canvas.precision_preview_metrics()
	var during_metrics := ArenaRuntimeBridge.end_instrumentation()
	var fingerprint_during := ArenaEditSession.fingerprint(arena.to_snapshot())
	var nodes_before := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var resources_before := int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
	var subviewports_before := _subviewport_count(studio)
	var release_trace := {"started": 0, "projection_done": 0, "history_done": 0}
	canvas.transform_commit_requested.connect(func(
			_snapshot: GridTransformSnapshot,
			_cells: Array[Vector2i],
			_pixels: Array[Vector2]
		):
		if int(release_trace.started) > 0 and int(release_trace.projection_done) == 0:
			release_trace.projection_done = Time.get_ticks_usec()
	)
	canvas.stroke_finished.connect(func(_action_name: String):
		if int(release_trace.started) > 0 and int(release_trace.history_done) == 0:
			release_trace.history_done = Time.get_ticks_usec()
	)
	var signals_before := _connection_count(canvas)
	ArenaRuntimeBridge.begin_instrumentation()
	var release_started := Time.get_ticks_usec()
	release_trace.started = release_started
	_release(canvas, last_position)
	var release_usec := Time.get_ticks_usec() - release_started
	var release_metrics := ArenaRuntimeBridge.end_instrumentation()
	var final_pointer_error := canvas._image_native_to_screen(arena.grid_origin).distance_to(
		last_position
	)
	var max_stress_event_usec := 0
	for gesture_index in range(1, GESTURE_COUNT):
		start = canvas._image_native_to_screen(arena.grid_origin)
		if not canvas._begin_transform_handle(
			ArenaStudioCanvas.TransformHandle.BODY, start, false, true
		):
			_finish({"ok": false, "error": "stress_drag_start_failed", "gesture": gesture_index})
			return
		last_position = start + Vector2(2.5, -1.25)
		var motion := InputEventMouseMotion.new()
		motion.position = last_position
		var stress_event_started := Time.get_ticks_usec()
		canvas._handle_mouse_motion(motion)
		max_stress_event_usec = maxi(
			max_stress_event_usec, Time.get_ticks_usec() - stress_event_started
		)
		_release(canvas, last_position)
	await get_tree().process_frame
	await get_tree().process_frame
	var nodes_after := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var resources_after := int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
	var signals_after := _connection_count(canvas)
	var subviewports_after := _subviewport_count(studio)
	var report := {
		"ok": fingerprint_during == fingerprint_before
			and int(during_metrics.get("sync_runtime_resources", 0)) == 0
			and int(release_metrics.get("sync_runtime_resources", 0)) == 1
			and int(queued_metrics.get("previews_applied", -1)) == 0
			and int(applied_metrics.get("previews_applied", -1)) == 1
			and final_pointer_error < 0.5
			and nodes_after == nodes_before
			and signals_after == signals_before
			and subviewports_after == subviewports_before,
		"phase": "after_independent_preview",
		"event_count": EVENT_COUNT,
		"gesture_count": GESTURE_COUNT,
		"total_drag_ms": snappedf(float(drag_usec) / 1000.0, 0.001),
		"max_event_ms": snappedf(float(max_event_usec) / 1000.0, 0.001),
		"max_stress_event_ms": snappedf(float(max_stress_event_usec) / 1000.0, 0.001),
		"release_ms": snappedf(float(release_usec) / 1000.0, 0.001),
		"runtime_projection_commit_ms": snappedf(
			float(int(release_trace.projection_done) - release_started) / 1000.0, 0.001
		),
		"history_refresh_ms": snappedf(
			float(int(release_trace.history_done) - int(release_trace.projection_done)) / 1000.0,
			0.001
		),
		"runtime_syncs_during_drag": int(during_metrics.get("sync_runtime_resources", 0)),
		"runtime_syncs_on_release": int(release_metrics.get("sync_runtime_resources", 0)),
		"arena_mutated_during_drag": fingerprint_during != fingerprint_before,
		"queued_metrics": queued_metrics,
		"applied_metrics": applied_metrics,
		"last_pointer_error_px": snappedf(final_pointer_error, 0.001),
		"history_actions": studio.edit_session.history.get_current_index(),
		"nodes_before": nodes_before,
		"nodes_after": nodes_after,
		"resources_before": resources_before,
		"resources_after": resources_after,
		"signal_connections_before": signals_before,
		"signal_connections_after": signals_after,
		"subviewports_before": subviewports_before,
		"subviewports_after": subviewports_after,
	}
	_finish(report)


func _release(canvas: ArenaStudioCanvas, position: Vector2) -> void:
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = position
	canvas._handle_mouse_button(release)


func _connection_count(canvas: ArenaStudioCanvas) -> int:
	var total := 0
	for signal_name in [
		&"stroke_started", &"stroke_finished", &"stroke_cancelled",
		&"calibration_preview_requested", &"anchors_preview_requested",
		&"transform_commit_requested",
	]:
		total += canvas.get_signal_connection_list(signal_name).size()
	return total


func _subviewport_count(root: Node) -> int:
	var total := 1 if root is SubViewport else 0
	for child in root.get_children():
		total += _subviewport_count(child)
	return total


func _finish(report: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT.get_base_dir()))
	var file := FileAccess.open(OUTPUT, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "  "))
		file.close()
	print("GRID_TRANSFORM_AFTER=", JSON.stringify(report))
	get_tree().quit(0 if bool(report.get("ok", false)) else 1)
