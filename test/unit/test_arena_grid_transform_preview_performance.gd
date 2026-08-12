extends GutTest


func test_preview_session_is_independent_from_arena_definition() -> void:
	var arena := _fixture()
	var opening := ArenaEditSession.fingerprint(arena.to_snapshot())
	var session := GridTransformPreviewSession.new()
	assert_true(session.begin(arena, ArenaStudioCanvas.TransformHandle.BODY))
	var candidate := GridTransformService.translate(session.base_snapshot, Vector2(17.5, -8.25))
	assert_true(session.set_transform(candidate))
	var pixels := session.anchor_pixels()
	pixels[0] += Vector2(3, 4)
	assert_true(session.set_anchors(session.anchor_cells(), pixels))
	assert_eq(ArenaEditSession.fingerprint(arena.to_snapshot()), opening)
	assert_true(session.dirty)
	assert_eq(session.previews_applied, 2)


func test_500_mouse_events_are_coalesced_without_canonical_mutation() -> void:
	var harness := _harness("preview_mouse")
	var canvas: ArenaStudioCanvas = harness.canvas
	var arena: ArenaDefinition = harness.arena
	var session: ArenaEditSession = harness.session
	canvas.set_tool(ArenaStudioCanvas.Tool.TRANSFORM_GRID)
	var opening := ArenaEditSession.fingerprint(arena.to_snapshot())
	var opening_layout := arena.grid_layout
	var opening_visual := arena.painted_map_visual_data
	var start := canvas._image_native_to_screen(arena.grid_origin)
	assert_true(canvas._begin_transform_handle(
		ArenaStudioCanvas.TransformHandle.BODY, start, false, true
	))
	ArenaRuntimeBridge.begin_instrumentation()
	var last_position := start
	for index in range(1, 501):
		last_position = start + Vector2(index * 0.08, index * -0.035)
		var motion := InputEventMouseMotion.new()
		motion.position = last_position
		canvas._handle_mouse_motion(motion)
	assert_eq(ArenaEditSession.fingerprint(arena.to_snapshot()), opening)
	assert_eq(canvas.precision_preview_metrics().previews_applied, 0)
	canvas._process(0.0)
	var during := ArenaRuntimeBridge.end_instrumentation()
	assert_eq(int(during.sync_runtime_resources), 0)
	assert_eq(canvas.precision_preview_metrics().previews_applied, 1)
	assert_eq(canvas.precision_preview_metrics().coalesced_events, 499)
	assert_true(canvas.precision_preview_metrics().simplified_rendering)
	assert_eq(ArenaEditSession.fingerprint(arena.to_snapshot()), opening)
	ArenaRuntimeBridge.begin_instrumentation()
	_release(canvas, last_position)
	var release := ArenaRuntimeBridge.end_instrumentation()
	assert_eq(int(release.sync_runtime_resources), 1)
	assert_eq(session.history.get_current_index(), 1)
	assert_true(arena.grid_layout == opening_layout)
	assert_true(arena.painted_map_visual_data == opening_visual)
	assert_eq(arena.painted_map_visual_data.grid_origin, arena.grid_origin)
	assert_lt(canvas._image_native_to_screen(arena.grid_origin).distance_to(last_position), 0.5)
	assert_false(canvas.is_precision_preview_active())


func test_cancel_anchor_and_keyboard_share_the_preview_contract() -> void:
	var harness := _harness("preview_other_inputs")
	var canvas: ArenaStudioCanvas = harness.canvas
	var arena: ArenaDefinition = harness.arena
	var session: ArenaEditSession = harness.session
	canvas.set_tool(ArenaStudioCanvas.Tool.TRANSFORM_GRID)
	var opening := ArenaEditSession.fingerprint(arena.to_snapshot())
	var start := canvas._image_native_to_screen(arena.grid_origin)
	assert_true(canvas._begin_transform_handle(
		ArenaStudioCanvas.TransformHandle.BODY, start, false, true
	))
	var motion := InputEventMouseMotion.new()
	motion.position = start + Vector2(30, -12)
	canvas._update_transform_drag(motion)
	ArenaRuntimeBridge.begin_instrumentation()
	assert_true(canvas.cancel_active_gesture())
	var cancel_metrics := ArenaRuntimeBridge.end_instrumentation()
	assert_eq(int(cancel_metrics.sync_runtime_resources), 0)
	assert_eq(ArenaEditSession.fingerprint(arena.to_snapshot()), opening)
	assert_eq(session.history.get_current_index(), 0)

	canvas.set_tool(ArenaStudioCanvas.Tool.CALIBRATION_ANCHORS)
	var anchor_start := canvas._image_native_to_screen(arena.calibration_pixels[0])
	assert_true(canvas._handle_anchor_press(anchor_start, MOUSE_BUTTON_LEFT))
	motion = InputEventMouseMotion.new()
	motion.position = anchor_start + Vector2(8, -4)
	ArenaRuntimeBridge.begin_instrumentation()
	canvas._handle_mouse_motion(motion)
	canvas._process(0.0)
	var anchor_during := ArenaRuntimeBridge.end_instrumentation()
	assert_eq(int(anchor_during.sync_runtime_resources), 0)
	assert_eq(ArenaEditSession.fingerprint(arena.to_snapshot()), opening)
	ArenaRuntimeBridge.begin_instrumentation()
	_release(canvas, motion.position)
	var anchor_release := ArenaRuntimeBridge.end_instrumentation()
	assert_eq(int(anchor_release.sync_runtime_resources), 1)
	assert_eq(session.history.get_current_index(), 1)

	canvas.set_tool(ArenaStudioCanvas.Tool.TRANSFORM_GRID)
	var before_keyboard := ArenaEditSession.fingerprint(arena.to_snapshot())
	var key := InputEventKey.new()
	key.pressed = true
	key.keycode = KEY_RIGHT
	ArenaRuntimeBridge.begin_instrumentation()
	canvas._handle_key_input(key)
	var keyboard_during := ArenaRuntimeBridge.end_instrumentation()
	assert_eq(int(keyboard_during.sync_runtime_resources), 0)
	assert_eq(ArenaEditSession.fingerprint(arena.to_snapshot()), before_keyboard)
	ArenaRuntimeBridge.begin_instrumentation()
	assert_true(canvas._commit_keyboard_nudge())
	var keyboard_release := ArenaRuntimeBridge.end_instrumentation()
	assert_eq(int(keyboard_release.sync_runtime_resources), 1)
	assert_eq(session.history.get_current_index(), 2)


func test_preview_session_does_not_grow_nodes_or_signal_connections() -> void:
	var canvas := ArenaStudioCanvas.new()
	canvas.size = Vector2(960, 640)
	add_child_autofree(canvas)
	canvas.set_arena(_fixture())
	canvas.set_tool(ArenaStudioCanvas.Tool.TRANSFORM_GRID)
	var nodes_before := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var connections_before := canvas.transform_commit_requested.get_connections().size()
	for index in range(100):
		var start := canvas._image_native_to_screen(canvas.arena.grid_origin)
		assert_true(canvas._begin_transform_handle(
			ArenaStudioCanvas.TransformHandle.BODY, start, false, true
		))
		var motion := InputEventMouseMotion.new()
		motion.position = start + Vector2(3, -1)
		canvas._handle_mouse_motion(motion)
		canvas.cancel_active_gesture()
	assert_eq(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), nodes_before)
	assert_eq(canvas.transform_commit_requested.get_connections().size(), connections_before)
	assert_false(canvas.is_precision_preview_active())


func _harness(key: String) -> Dictionary:
	var session := ArenaEditSession.new()
	assert_true(session.open(_fixture(), "", true, key))
	var arena := session.working_arena
	var canvas := ArenaStudioCanvas.new()
	canvas.size = Vector2(1280, 720)
	add_child_autofree(canvas)
	canvas.set_arena(arena)
	var state := {"before": {}, "action": "", "changed": false}
	canvas.stroke_started.connect(func(action_name: String):
		state.before = arena.to_snapshot()
		state.action = action_name
		state.changed = false
	)
	canvas.transform_commit_requested.connect(func(
			snapshot: GridTransformSnapshot,
			cells: Array[Vector2i],
			pixels: Array[Vector2]
		):
		snapshot.apply_to(arena)
		arena.calibration_cells = cells.duplicate()
		arena.calibration_pixels = pixels.duplicate()
		ArenaRuntimeBridge.sync_runtime_resources(
			arena, ArenaRuntimeBridge.SyncScope.GRID_TRANSFORM
		)
		state.changed = true
	)
	canvas.stroke_finished.connect(func(action_name: String):
		if state.changed:
			session.commit(action_name, state.before, arena.to_snapshot())
		state.before = {}
		state.changed = false
	)
	canvas.stroke_cancelled.connect(func():
		state.before = {}
		state.changed = false
	)
	return {"session": session, "arena": arena, "canvas": canvas, "state": state}


func _release(canvas: ArenaStudioCanvas, position: Vector2) -> void:
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = position
	canvas._handle_mouse_button(release)


func _fixture() -> ArenaDefinition:
	var arena := ArenaDefinition.new()
	arena.set_identity("Grid preview fixture", "grid_preview_fixture")
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
