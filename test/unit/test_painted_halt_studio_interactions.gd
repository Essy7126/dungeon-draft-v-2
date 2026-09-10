extends GutTest
## Real viewport picking, mouse gestures and keyboard routes. No production writes.

var viewport: SubViewport
var studio: PaintedHaltStudio
var canvas: PaintedHaltCanvas


func before_each() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(1600, 1000)
	add_child_autofree(viewport)
	studio = PaintedHaltStudio.new()
	studio.auto_load = false
	viewport.add_child(studio)
	studio.document.load_working_copy(_fixture())
	canvas = studio.canvas
	canvas.set_document(studio.document)
	await wait_process_frames(4)
	await _motion(Vector2(2, 2))


func after_each() -> void:
	await _mouse(Vector2(2, 2), false)
	studio.document.history.set_saved_fingerprint(studio.document.fingerprint())


func _fixture() -> Dictionary:
	return {
		"schema_version": 1,
		"id": "test_halt_v1",
		"title": "Halte de test",
		"kind": "sanctuary",
		"stage": "planning",
		"source": { },
		"world": {
			"width": 2200,
			"speed": 195,
			"player_scale": 0.52,
			"foot_clearance": 12,
			"spawn": [0.3, 0.8],
		},
		"navigation": {
			"outline": [[0.1, 0.1], [0.9, 0.1], [0.9, 0.9], [0.1, 0.9]],
			"obstacles": [],
		},
		"water": { "polygons": [], "exclusions": [], "regions": [], "tint": "#55aa99" },
		"cascades": [],
		"torches": [],
		"foliage": [],
		"bounce": [],
		"foreground": [],
		"landmarks": [],
		"mist": [],
		"review": { },
	}


func test_drag_is_one_undoable_gesture_and_toolbar_restores_it() -> void:
	var original: Array = studio.document.points("outline", 0)[0].duplicate()
	var start := _point(original)
	await _mouse(start, true)
	await _motion(_point([0.16, 0.18]), MOUSE_BUTTON_MASK_LEFT)
	await _motion(_point([0.18, 0.21]), MOUSE_BUTTON_MASK_LEFT)
	await _mouse(_point([0.18, 0.21]), false)
	assert_almost_eq(float(studio.document.points("outline", 0)[0][0]), 0.18, 0.00001)
	assert_eq(
		studio.history_current_index(),
		1,
		"A drag is one history entry regardless of frame count",
	)
	assert_true(studio.document.is_dirty())
	await _click(studio.undo_button)
	assert_eq(studio.document.points("outline", 0)[0], original)
	assert_false(studio.document.is_dirty(), "Undo to saved state clears dirty state")
	await _click(studio.redo_button)
	assert_almost_eq(float(studio.document.points("outline", 0)[0][1]), 0.21, 0.00001)


func test_polygon_drawing_finishes_via_enter_and_can_be_removed() -> void:
	await _click(_find_button("Obstacles"))
	assert_eq(canvas.layer, "obstacles")
	await _click(_find_button("+ Dessiner / placer"))
	for point: Array in [[0.4, 0.4], [0.6, 0.4], [0.5, 0.6]]:
		await _mouse(_point(point), true)
		await _mouse(_point(point), false)
	await _key(KEY_ENTER)
	assert_eq(studio.document.shapes("obstacles").size(), 1)
	assert_eq(studio.document.points("obstacles", 0).size(), 3)
	assert_false(canvas.drawing)
	await _click(_find_button("Supprimer"))
	assert_eq(studio.document.shapes("obstacles").size(), 0)
	await _click(studio.undo_button)
	assert_eq(studio.document.shapes("obstacles").size(), 1)


func test_double_click_inserts_an_edge_vertex_and_delete_preserves_minimum_polygon() -> void:
	await _mouse(_point([0.5, 0.1]), true, MOUSE_BUTTON_LEFT, true)
	await _mouse(_point([0.5, 0.1]), false)
	assert_eq(studio.document.points("outline", 0).size(), 5)
	await _key(KEY_DELETE)
	assert_eq(studio.document.points("outline", 0).size(), 4)
	await _mouse(_point([0.1, 0.1]), true)
	await _mouse(_point([0.1, 0.1]), false)
	await _key(KEY_DELETE)
	assert_eq(studio.document.points("outline", 0).size(), 3)
	await _mouse(_point([0.9, 0.1]), true)
	await _mouse(_point([0.9, 0.1]), false)
	await _key(KEY_DELETE)
	assert_eq(
		studio.document.points("outline", 0).size(),
		3,
		"An outline never becomes a two-point polygon",
	)


func test_escape_rolls_back_in_progress_drag_without_history() -> void:
	var before := studio.document.manifest.duplicate(true)
	await _mouse(_point([0.1, 0.1]), true)
	await _motion(_point([0.2, 0.2]), MOUSE_BUTTON_MASK_LEFT)
	await _key(KEY_ESCAPE)
	await _mouse(_point([0.2, 0.2]), false)
	assert_eq(studio.document.manifest, before)
	assert_eq(studio.history_current_index(), 0)
	assert_false(studio.document.is_dirty())


func test_zoom_at_pointer_and_pan_preserve_authored_geometry() -> void:
	var before := studio.document.manifest.duplicate(true)
	var cursor := _point([0.4, 0.4])
	await _mouse(cursor, true, MOUSE_BUTTON_WHEEL_UP)
	await _mouse(cursor, false, MOUSE_BUTTON_WHEEL_UP)
	assert_gt(canvas.zoom, 1.0)
	assert_almost_eq(_point([0.4, 0.4]), cursor, Vector2(0.01, 0.01), "Zoom stays under the cursor")
	await _mouse(cursor, true, MOUSE_BUTTON_MIDDLE)
	await _motion(cursor + Vector2(30, -15), MOUSE_BUTTON_MASK_MIDDLE, Vector2(30, -15))
	await _mouse(cursor + Vector2(30, -15), false, MOUSE_BUTTON_MIDDLE)
	assert_eq(studio.document.manifest, before)
	assert_almost_eq(_point([0.4, 0.4]), cursor + Vector2(30, -15), Vector2(0.01, 0.01))
	await _click(_find_button("Cadrer"))
	assert_eq(canvas.zoom, 1.0)
	assert_eq(canvas.pan, Vector2.ZERO)


func test_foreground_depth_anchor_is_editable_with_actual_pointer() -> void:
	studio.document.add_shape("foreground", [[0.4, 0.3], [0.6, 0.3], [0.6, 0.6], [0.4, 0.6]])
	studio.document.shapes("foreground")[0].anchor = [0.5, 0.6]
	await _click(_find_button("Premiers plans"))
	await _mouse(_point([0.5, 0.6]), true)
	await _motion(_point([0.5, 0.7]), MOUSE_BUTTON_MASK_LEFT)
	await _mouse(_point([0.5, 0.7]), false)
	assert_almost_eq(float(studio.document.shapes("foreground")[0].anchor[1]), 0.7, 0.00001)
	assert_eq(
		studio.document.points("foreground", 0)[2],
		[0.6, 0.6],
		"Depth anchor leaves image cutout vertices untouched",
	)


func test_blank_plan_accepts_spawn_before_an_illustration_exists() -> void:
	var plan := _fixture()
	plan.world.spawn = []
	plan.navigation.outline = []
	studio.document.load_working_copy(plan)
	canvas.set_document(studio.document)
	await wait_process_frames(2)
	await _click(_find_button("Arrivée"))
	await _click(_find_button("+ Dessiner / placer"))
	await _mouse(_point([0.25, 0.8]), true)
	await _mouse(_point([0.25, 0.8]), false)
	assert_almost_eq(float(studio.document.manifest.world.spawn[0]), 0.25, 0.00001)
	assert_false(canvas.drawing)
	assert_eq(studio.document.manifest.source, { }, "Planning requires no art or generated masks")


func _point(normalized: Array) -> Vector2:
	return canvas.global_position + canvas.to_canvas(normalized)


func _find_button(text_value: String) -> Button:
	for button: Button in studio.find_children("*", "Button", true, false):
		if button.text == text_value:
			return button
	assert_true(false, "Missing button: " + text_value)
	return null


func _click(button: Button) -> void:
	if button == null:
		return
	var point := button.get_global_rect().get_center()
	assert_true(
		Rect2(Vector2.ZERO, Vector2(viewport.size)).has_point(point),
		"Button inside viewport: " + button.text,
	)
	await _motion(point)
	await _mouse(point, true)
	await _mouse(point, false)


func _mouse(
	point: Vector2,
	pressed: bool,
	button := MOUSE_BUTTON_LEFT,
	double_click := false,
) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = button
	event.pressed = pressed
	event.double_click = double_click
	viewport.push_input(event, true)
	await wait_process_frames(2)


func _motion(point: Vector2, buttons := 0, relative := Vector2.ZERO) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.button_mask = buttons
	event.relative = relative
	viewport.push_input(event, true)
	await wait_process_frames(2)


func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	viewport.push_input(event, true)
	await wait_process_frames(2)


func test_pool_edits_and_deletion_preserve_the_matching_current_regardless_of_order() -> void:
	var first := [[0.3, 0.3], [0.45, 0.3], [0.45, 0.45], [0.3, 0.45]]
	var second := [[0.55, 0.55], [0.7, 0.55], [0.7, 0.7], [0.55, 0.7]]
	var value := _fixture()
	value.water.polygons = [first.duplicate(true), second.duplicate(true)]
	value.water.regions = [
		{ "polygon": second.duplicate(true), "direction": [0, 1], "speed": 0.3 },
		{ "polygon": first.duplicate(true), "direction": [1, 0], "speed": 0.9 },
	]
	studio.document.load_working_copy(value)
	canvas.set_document(studio.document)
	await wait_process_frames(2)
	await _click(_find_button("Eau"))
	assert_eq(
		studio.document.water_region_index(0),
		1,
		"Current association is geometric, not a parallel array assumption",
	)
	await _mouse(_point([0.3, 0.3]), true)
	await _motion(_point([0.28, 0.28]), MOUSE_BUTTON_MASK_LEFT)
	await _mouse(_point([0.28, 0.28]), false)
	assert_eq(studio.document.manifest.water.regions[1].polygon, studio.document.shapes("water")[0])
	await _mouse(_point([0.36, 0.36]), true)
	await _mouse(_point([0.36, 0.36]), false)
	await _click(_find_button("Supprimer"))
	assert_eq(studio.document.manifest.water.regions.size(), 1)
	assert_eq(studio.document.manifest.water.regions[0].polygon, second)
	assert_eq(studio.document.shapes("water")[0], second)
	await _click(studio.undo_button)
	assert_eq(studio.document.manifest.water.regions.size(), 2)
	assert_eq(studio.document.water_region_index(0), 1)


func test_reparenting_the_studio_preserves_undo_history_and_the_working_copy() -> void:
	var before: Array = studio.document.points("outline", 0)[0].duplicate()
	await _mouse(_point([0.1, 0.1]), true)
	await _motion(_point([0.18, 0.18]), MOUSE_BUTTON_MASK_LEFT)
	await _mouse(_point([0.18, 0.18]), false)
	viewport.remove_child(studio)
	viewport.add_child(studio)
	await wait_process_frames(3)
	assert_true(
		studio.history_can_undo(),
		"Detaching/reintegrating the Studio preserves the existing UndoRedo",
	)
	assert_eq(studio.history_current_index(), 1)
	assert_true(studio.document.is_dirty())
	await _click(studio.undo_button)
	assert_eq(studio.document.points("outline", 0)[0], before)
	assert_false(studio.document.is_dirty())


func test_shared_shell_snapshot_before_opening_a_map_keeps_an_empty_bound_canvas() -> void:
	var unopened := PaintedHaltStudio.new()
	unopened.auto_load = false
	viewport.add_child(unopened)
	await wait_process_frames(2)
	assert_same(unopened.canvas.document, unopened.document)
	var state: Dictionary = unopened.get_state_snapshot()
	assert_eq(state.path, "")
	unopened.apply_state_snapshot(state)
	assert_eq(unopened.canvas.layer, "outline")
	assert_eq(unopened.canvas.selected_shape, -1)
	unopened.apply_state_snapshot({ "path": "", "layer": "water" })
	assert_eq(unopened.canvas.layer, "water")
	assert_eq(unopened.canvas.selected_shape, -1)
	assert_true(
		unopened.document.manifest.is_empty(),
		"Restoring UI state does not create map content",
	)
	unopened.queue_free()
	await wait_process_frames(2)
