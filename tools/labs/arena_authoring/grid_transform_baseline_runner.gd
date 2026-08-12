extends Node

const OUTPUT := "res://artifacts/arena_authoring_speed/grid_transform_baseline.json"


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
	ArenaRuntimeBridge.begin_instrumentation()
	var started := Time.get_ticks_usec()
	var max_event_usec := 0
	for index in range(1, 101):
		var motion := InputEventMouseMotion.new()
		motion.position = start + Vector2(index * 0.4, index * -0.175)
		var event_started := Time.get_ticks_usec()
		canvas._handle_mouse_motion(motion)
		max_event_usec = maxi(max_event_usec, Time.get_ticks_usec() - event_started)
	var drag_usec := Time.get_ticks_usec() - started
	var during_metrics := ArenaRuntimeBridge.end_instrumentation()
	var fingerprint_during := ArenaEditSession.fingerprint(arena.to_snapshot())
	ArenaRuntimeBridge.begin_instrumentation()
	var release_started := Time.get_ticks_usec()
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = start + Vector2(40.0, -17.5)
	canvas._handle_mouse_button(release)
	var release_usec := Time.get_ticks_usec() - release_started
	var release_metrics := ArenaRuntimeBridge.end_instrumentation()
	_finish({
		"ok": true,
		"phase": "before_independent_preview",
		"event_count": 100,
		"total_drag_ms": snappedf(float(drag_usec) / 1000.0, 0.001),
		"max_event_ms": snappedf(float(max_event_usec) / 1000.0, 0.001),
		"release_ms": snappedf(float(release_usec) / 1000.0, 0.001),
		"runtime_syncs_during_drag": int(during_metrics.get("sync_runtime_resources", 0)),
		"runtime_syncs_on_release": int(release_metrics.get("sync_runtime_resources", 0)),
		"arena_mutated_during_drag": fingerprint_during != fingerprint_before,
		"history_actions": studio.edit_session.history.get_current_index(),
	})


func _finish(report: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(OUTPUT.get_base_dir())
	)
	var file := FileAccess.open(OUTPUT, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "  "))
	print("GRID_TRANSFORM_BASELINE=", JSON.stringify(report))
	get_tree().quit(0 if bool(report.get("ok", false)) else 1)
