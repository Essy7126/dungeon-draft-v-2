extends GutTest


class HistoryFixture:
	extends RefCounted
	var snapshot := {"value": 0}

	func apply(value: Dictionary) -> void:
		snapshot = value.duplicate(true)

	func fingerprint() -> String:
		return JSON.stringify(snapshot).sha256_text()


func test_transform_translation_rotation_scale_and_independent_axes() -> void:
	var initial := GridTransformSnapshot.new(
		Vector2(100, 50), Vector2(40, 20), Vector2(-36, 18)
	)
	var translated := GridTransformService.translate(initial, Vector2(12.5, -3.0))
	assert_almost_eq(translated.origin, Vector2(112.5, 47.0), Vector2(0.00001, 0.00001))
	assert_eq(translated.axis_x, initial.axis_x)
	assert_eq(translated.axis_y, initial.axis_y)
	var pivot := GridTransformService.logical_grid_center(initial, Vector2i(14, 14))
	var rotated := GridTransformService.rotate_around(initial, pivot, deg_to_rad(90.0))
	assert_almost_eq(rotated.axis_x.length(), initial.axis_x.length(), 0.0001)
	assert_almost_eq(rotated.axis_y.length(), initial.axis_y.length(), 0.0001)
	assert_almost_eq(
		GridTransformService.logical_grid_center(rotated, Vector2i(14, 14)),
		pivot, Vector2(0.0001, 0.0001)
	)
	var scaled := GridTransformService.scale_around(initial, pivot, 1.25)
	assert_almost_eq(scaled.axis_x.length(), initial.axis_x.length() * 1.25, 0.0001)
	assert_almost_eq(
		GridTransformService.logical_grid_center(scaled, Vector2i(14, 14)),
		pivot, Vector2(0.0001, 0.0001)
	)
	var adjusted_x := GridTransformService.set_axis_x(initial, Vector2(52, 11))
	assert_eq(adjusted_x.axis_x, Vector2(52, 11))
	assert_eq(adjusted_x.axis_y, initial.axis_y)
	var adjusted_y := GridTransformService.set_axis_y(initial, Vector2(-29, 25))
	assert_eq(adjusted_y.axis_x, initial.axis_x)
	assert_eq(adjusted_y.axis_y, Vector2(-29, 25))


func test_transform_validation_rejects_non_finite_null_and_near_collinear() -> void:
	var valid := GridTransformSnapshot.new(Vector2.ZERO, Vector2(40, 20), Vector2(-40, 20))
	assert_true(GridTransformService.validate_snapshot(valid).ok)
	var null_axis := valid.copy()
	null_axis.axis_x = Vector2.ZERO
	assert_false(GridTransformService.validate_snapshot(null_axis).ok)
	var nan_origin := valid.copy()
	nan_origin.origin = Vector2(NAN, 0)
	assert_false(GridTransformService.validate_snapshot(nan_origin).ok)
	var near_collinear := valid.copy()
	near_collinear.axis_y = Vector2(80, 40.000001)
	assert_false(GridTransformService.validate_snapshot(near_collinear).ok)
	var inverted := valid.copy()
	inverted.axis_y = -valid.axis_y
	assert_false(GridTransformService.validate_snapshot(
		inverted, GridTransformService.determinant(valid.axis_x, valid.axis_y)
	).ok)


func test_native_screen_conversion_handles_offset_scale_pan_and_zoom() -> void:
	var native := Vector2(321.25, 178.5)
	var offset := Vector2(45, -18)
	var scale := Vector2(1.5, 1.5)
	var pan := Vector2(-120, 92)
	var zoom := 2.75
	var screen := GridTransformService.image_native_to_screen(
		native, offset, scale, pan, zoom
	)
	assert_almost_eq(
		GridTransformService.screen_to_image_native(screen, offset, scale, pan, zoom),
		native, Vector2(0.0001, 0.0001)
	)
	var screen_delta := Vector2(82.5, -41.25)
	assert_almost_eq(
		GridTransformService.image_native_delta_from_screen_delta(screen_delta, scale, zoom),
		Vector2(20, -10), Vector2(0.0001, 0.0001)
	)
	assert_almost_eq(
		GridTransformService.screen_handle_radius_to_image_radius(12.0, scale, zoom),
		12.0 / (1.5 * 2.75), 0.0001
	)
	var visual := PaintedMapVisualData.new()
	visual.source_image_size = Vector2i(1024, 768)
	visual.logical_grid_size = Vector2i(14, 14)
	visual.grid_origin = Vector2(410, 132)
	visual.axis_x = Vector2(31, 16)
	visual.axis_y = Vector2(-29, 17)
	visual.image_offset = offset
	visual.image_scale = scale
	var cell := Vector2i(7, 9)
	var native_center := visual.cell_to_image(cell)
	assert_almost_eq(
		visual.cell_to_display(cell), offset + native_center * scale,
		Vector2(0.0001, 0.0001)
	)
	assert_eq(visual.display_to_cell(visual.cell_to_display(cell)), cell)
	var runtime_view := PaintedGridView.new()
	runtime_view.visual_data = visual
	assert_almost_eq(
		runtime_view.grid_to_local(cell), visual.cell_to_display(cell),
		Vector2(0.0001, 0.0001)
	)
	assert_eq(runtime_view.local_to_grid(runtime_view.grid_to_local(cell)), cell)
	runtime_view.free()


func test_snap_and_mirror_are_deterministic_on_rotated_grid() -> void:
	assert_eq(GridTransformService.snap_position(Vector2(2.49, -3.51), 1.0), Vector2(2, -4))
	assert_almost_eq(
		GridTransformService.snap_angle(deg_to_rad(12.37), deg_to_rad(0.25)),
		deg_to_rad(12.25), 0.00001
	)
	assert_almost_eq(GridTransformService.snap_scale(1.023, 0.005), 1.025, 0.00001)
	var direction := Vector2(1, 0).rotated(0.63)
	var bisector := Vector2(0, 1).rotated(0.63)
	var mirrored := GridTransformService.mirror_axis_across_bisector(direction, bisector)
	assert_almost_eq(mirrored.length(), direction.length(), 0.00001)
	assert_almost_eq(mirrored.angle(), Vector2(-1, 0).rotated(0.63).angle(), 0.00001)


func test_affine_fit_exact_noisy_duplicate_and_collinear() -> void:
	var cells: Array[Vector2i] = [
		Vector2i.ZERO, Vector2i(8, 0), Vector2i(0, 8), Vector2i(8, 8),
		Vector2i(3, 5), Vector2i(6, 2), Vector2i(12, 11), Vector2i(1, 10),
	]
	var positions: Array[Vector2] = []
	for index in range(cells.size()):
		var position := GridTransformService.cell_to_position(
			cells[index], Vector2(688, 165), Vector2(34.4, 17.066667), Vector2(-34.4, 17.066667)
		)
		positions.append(position + Vector2(sin(float(index)) * 0.2, cos(float(index)) * 0.2))
	var first := GridTransformService.fit_affine(cells, positions)
	var second := GridTransformService.fit_affine(cells, positions)
	assert_true(first.ok)
	assert_eq(first, second)
	assert_lt(float(first.rms_error), 0.3)
	var duplicate_cells := cells.duplicate()
	duplicate_cells[1] = duplicate_cells[0]
	assert_false(GridTransformService.fit_affine(duplicate_cells, positions).ok)
	var line_cells: Array[Vector2i] = [Vector2i.ZERO, Vector2i.ONE, Vector2i(2, 2)]
	var line_positions: Array[Vector2] = [Vector2.ZERO, Vector2.ONE, Vector2(2, 2)]
	assert_false(GridTransformService.fit_affine(line_cells, line_positions).ok)
	var outside_cells: Array[Vector2i] = [
		Vector2i.ZERO, Vector2i(8, 0), Vector2i(0, 15),
	]
	var outside_positions: Array[Vector2] = [Vector2.ZERO, Vector2.RIGHT, Vector2.DOWN]
	var outside := GridTransformService.fit_affine(
		outside_cells, outside_positions, Vector2i(14, 14)
	)
	assert_false(outside.ok)
	assert_string_contains(str(outside.error), "hors de la grille")


func test_history_undo_redo_branch_jump_saved_fingerprint_and_limit() -> void:
	var fixture := HistoryFixture.new()
	var history := StudioHistoryController.new(3)
	history.configure(Callable(fixture, "apply"), Callable(fixture, "fingerprint"))
	history.set_saved_fingerprint(fixture.fingerprint())
	assert_false(history.can_undo())
	assert_false(history.can_redo())
	for value in range(1, 5):
		var before := fixture.snapshot.duplicate(true)
		fixture.snapshot = {"value": value}
		assert_true(history.record("Action %d" % value, before, fixture.snapshot, true))
	assert_eq(history.get_history_entries().size(), 3)
	assert_eq(history.get_undo_action_name(), "Action 4")
	assert_true(history.undo())
	assert_eq(fixture.snapshot.value, 3)
	assert_true(history.can_redo())
	assert_eq(history.get_redo_action_name(), "Action 4")
	assert_true(history.jump_to(0))
	assert_eq(fixture.snapshot.value, 1)
	assert_true(history.jump_to(3))
	assert_eq(fixture.snapshot.value, 4)
	assert_true(history.undo())
	var branch_before := fixture.snapshot.duplicate(true)
	fixture.snapshot = {"value": 99}
	assert_true(history.record("Nouvelle branche", branch_before, fixture.snapshot, true))
	assert_false(history.can_redo())
	assert_eq(history.get_undo_action_name(), "Nouvelle branche")


func test_arena_sessions_use_working_copies_and_isolated_histories() -> void:
	var forest := ArenaLegacyImporter.import_production(&"room_01_forest")
	var volcano := ArenaLegacyImporter.import_production(&"room_05_volcano")
	assert_not_null(forest)
	assert_not_null(volcano)
	var forest_source := forest.to_snapshot()
	var forest_session := ArenaEditSession.new()
	var volcano_session := ArenaEditSession.new()
	assert_true(forest_session.open(forest, "", false, "forest"))
	assert_true(volcano_session.open(volcano, "", false, "volcano"))
	var before := forest_session.working_arena.to_snapshot()
	forest_session.working_arena.grid_origin += Vector2(5, -2)
	assert_true(forest_session.commit(
		"Deplacer la grille", before, forest_session.working_arena.to_snapshot()
	))
	assert_eq(forest.to_snapshot(), forest_source)
	assert_true(forest_session.history.can_undo())
	assert_false(volcano_session.history.can_undo())
	assert_true(forest_session.is_dirty())
	assert_true(forest_session.history.undo())
	assert_false(forest_session.is_dirty())
	assert_eq(forest_session.working_arena.to_snapshot(), before)
	assert_true(forest_session.history.redo())
	assert_true(forest_session.is_dirty())


func test_import_and_runtime_bridge_preserve_foreground_and_occlusion() -> void:
	for arena_id in [&"room_01_forest", &"room_05_volcano", &"room_06_space"]:
		var arena := ArenaLegacyImporter.import_production(arena_id)
		assert_not_null(arena)
		var room := load(arena.source_room_path) as RoomData
		assert_not_null(room)
		var source_visual := room.painted_map_visual_data
		assert_eq(arena.source_visual_path, source_visual.resource_path)
		assert_eq(arena.foreground_path, source_visual.foreground_texture_path)
		assert_eq(arena.foreground_offset, source_visual.foreground_offset)
		assert_eq(arena.foreground_scale, source_visual.foreground_scale)
		assert_eq(
			arena.foreground_occluder_polygon,
			source_visual.foreground_occluder_polygon
		)
		assert_eq(
			arena.foreground_full_hide_rect,
			source_visual.foreground_full_hide_rect
		)
		assert_true(ArenaRuntimeBridge.sync_runtime_resources(arena))
		assert_eq(
			arena.painted_map_visual_data.foreground_occluder_polygon,
			source_visual.foreground_occluder_polygon
		)
		assert_eq(
			arena.painted_map_visual_data.foreground_full_hide_rect,
			source_visual.foreground_full_hide_rect
		)


func test_production_calibration_save_updates_only_calibration_fields() -> void:
	var root := "user://dungeon_draft_studio/arena_studio/tests"
	var path := root.path_join("v11_visual_save_fixture.tres")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(root))
	var visual := PaintedMapVisualData.new()
	visual.map_id = &"v11_visual_save_fixture"
	visual.debug_name = "Unrelated field must survive"
	visual.background_texture_path = "res://art/backgrounds/forest.png"
	visual.foreground_texture_path = "res://art/foregrounds/tower.png"
	visual.foreground_offset = Vector2(17, -9)
	visual.foreground_scale = Vector2(1.25, 1.25)
	visual.foreground_occluder_polygon = PackedVector2Array([
		Vector2(1, 2), Vector2(30, 4), Vector2(12, 40),
	])
	visual.foreground_occluder_sort_y = 35.0
	visual.foreground_full_hide_rect = Rect2(4, 5, 20, 22)
	visual.camera_offset = Vector2(100, 55)
	visual.camera_zoom = 1.2
	visual.grid_origin = Vector2(10, 20)
	visual.axis_x = Vector2(30, 15)
	visual.axis_y = Vector2(-30, 15)
	assert_eq(ResourceSaver.save(visual, path), OK)

	var arena := ArenaDefinition.new()
	arena.set_identity("Fixture", "v11_visual_save_fixture")
	arena.grid_origin = Vector2(321.5, 88.25)
	arena.axis_x = Vector2(42.5, 19.75)
	arena.axis_y = Vector2(-39.25, 21.5)
	arena.calibration_cells = [Vector2i.ZERO, Vector2i(8, 0), Vector2i(0, 8)]
	arena.calibration_pixels = [Vector2(321.5, 88.25), Vector2(661.5, 246.25), Vector2(7.5, 260.25)]
	assert_eq(ArenaSerializer.save_production_calibration(arena, path), OK)
	assert_true(ArenaSerializer.production_visual_matches(arena, path))
	var saved := ResourceLoader.load(
		path, "", ResourceLoader.CACHE_MODE_IGNORE
	) as PaintedMapVisualData
	assert_not_null(saved)
	assert_eq(saved.debug_name, visual.debug_name)
	assert_eq(saved.background_texture_path, visual.background_texture_path)
	assert_eq(saved.foreground_texture_path, visual.foreground_texture_path)
	assert_eq(saved.foreground_offset, visual.foreground_offset)
	assert_eq(saved.foreground_scale, visual.foreground_scale)
	assert_eq(saved.foreground_occluder_polygon, visual.foreground_occluder_polygon)
	assert_eq(saved.foreground_full_hide_rect, visual.foreground_full_hide_rect)
	assert_eq(saved.camera_offset, visual.camera_offset)
	assert_eq(saved.camera_zoom, visual.camera_zoom)
	var absolute := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(absolute):
		DirAccess.remove_absolute(absolute)


func test_canvas_transform_gesture_is_one_action_and_escape_restores() -> void:
	var studio := ArenaStudioMain.new()
	add_child_autofree(studio)
	studio._on_tool_selected(ArenaStudioCanvas.Tool.TRANSFORM_GRID)
	var initial := studio.arena.to_snapshot()
	var start := GridTransformService.image_to_view(studio.arena.grid_origin, studio.canvas.pan, studio.canvas.zoom)
	assert_true(studio.canvas._begin_transform_handle(
		ArenaStudioCanvas.TransformHandle.BODY, start
	))
	for index in range(1, 101):
		var motion := InputEventMouseMotion.new()
		motion.position = start + Vector2(index * 0.2, index * -0.1)
		studio.canvas._handle_mouse_motion(motion)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = start + Vector2(20, -10)
	studio.canvas._handle_mouse_button(release)
	assert_eq(studio.edit_session.history.get_current_index(), 1)
	assert_ne(studio.arena.to_snapshot(), initial)
	var after_first := studio.arena.to_snapshot()
	assert_true(studio.canvas._begin_transform_handle(
		ArenaStudioCanvas.TransformHandle.BODY, start
	))
	var second_motion := InputEventMouseMotion.new()
	second_motion.position = start + Vector2(33, 12)
	studio.canvas._handle_mouse_motion(second_motion)
	assert_true(studio.cancel_active_gesture())
	assert_eq(studio.arena.to_snapshot(), after_first)
	assert_eq(studio.edit_session.history.get_current_index(), 1)
	assert_false(studio.canvas.is_transforming())
	ArenaSerializer.remove_recovery(studio.arena.arena_id)


func test_canvas_display_transform_keyboard_grouping_and_pivot_cancel() -> void:
	var studio := ArenaStudioMain.new()
	add_child_autofree(studio)
	studio._on_tool_selected(ArenaStudioCanvas.Tool.TRANSFORM_GRID)
	studio.arena.image_offset = Vector2(47, -23)
	studio.arena.image_scale = Vector2(2, 2)
	studio.canvas.zoom = 1.5
	var original_origin := studio.arena.grid_origin
	var start := studio.canvas._image_native_to_screen(original_origin)
	assert_true(studio.canvas._begin_transform_handle(
		ArenaStudioCanvas.TransformHandle.BODY, start, false, true
	))
	var motion := InputEventMouseMotion.new()
	motion.position = start + Vector2(60, -30)
	studio.canvas._handle_mouse_motion(motion)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = motion.position
	studio.canvas._handle_mouse_button(release)
	assert_almost_eq(
		studio.arena.grid_origin, original_origin + Vector2(20, -10),
		Vector2(0.0001, 0.0001)
	)
	assert_eq(studio.edit_session.history.get_current_index(), 1)

	var before_keyboard := studio.arena.grid_origin
	for key_data in [
		[KEY_RIGHT, true, false, false],
		[KEY_RIGHT, true, false, true],
		[KEY_DOWN, false, true, false],
	]:
		var key := InputEventKey.new()
		key.keycode = key_data[0]
		key.pressed = true
		key.ctrl_pressed = key_data[1]
		key.shift_pressed = key_data[2]
		key.echo = key_data[3]
		studio.canvas._handle_key_input(key)
	assert_true(studio.canvas._commit_keyboard_nudge())
	assert_almost_eq(
		studio.arena.grid_origin, before_keyboard + Vector2(20, 0.1),
		Vector2(0.0001, 0.0001)
	)
	assert_eq(studio.edit_session.history.get_current_index(), 2)
	assert_string_contains(studio.history_undo_name(), "clavier")

	var editor_before := studio.canvas.get_editor_state()
	var pivot: Vector2 = studio.canvas._transform_handle_screen_positions()[
		ArenaStudioCanvas.TransformHandle.PIVOT
	]
	assert_true(studio.canvas._begin_transform_handle(
		ArenaStudioCanvas.TransformHandle.PIVOT, pivot
	))
	var pivot_motion := InputEventMouseMotion.new()
	pivot_motion.position = pivot + Vector2(70, -35)
	studio.canvas._handle_mouse_motion(pivot_motion)
	studio.canvas._process(0.0)
	assert_ne(studio.canvas.get_editor_state(), editor_before)
	assert_true(studio.cancel_active_gesture())
	assert_eq(studio.canvas.get_editor_state(), editor_before)
	assert_eq(studio.edit_session.history.get_current_index(), 2)

	var before_interrupted := studio.arena.to_snapshot()
	var body_start := studio.canvas._image_native_to_screen(studio.arena.grid_origin)
	assert_true(studio.canvas._begin_transform_handle(
		ArenaStudioCanvas.TransformHandle.BODY, body_start, false, true
	))
	var interrupted_motion := InputEventMouseMotion.new()
	interrupted_motion.position = body_start + Vector2(25, 11)
	studio.canvas._handle_mouse_motion(interrupted_motion)
	assert_eq(studio.arena.to_snapshot(), before_interrupted)
	studio.canvas.set_tool(ArenaStudioCanvas.Tool.SELECT)
	assert_eq(studio.arena.to_snapshot(), before_interrupted)
	assert_false(studio.canvas.has_active_gesture())
	assert_eq(studio.edit_session.history.get_current_index(), 2)
	ArenaSerializer.remove_recovery(studio.arena.arena_id)


func test_shared_toolbar_exposes_contextual_undo_redo_and_history() -> void:
	var studio := DungeonDraftStudioMain.new()
	add_child_autofree(studio)
	assert_not_null(studio.undo_button)
	assert_not_null(studio.redo_button)
	assert_not_null(studio.history_button)
	assert_true(studio.undo_button.disabled)
	assert_true(studio.redo_button.disabled)
	var arena_main := studio.arena_studio
	var before := arena_main.arena.to_snapshot()
	arena_main.arena.grid_origin += Vector2(2, 1)
	arena_main._commit_change("Deplacer la grille", before, arena_main.arena.to_snapshot())
	studio._refresh_history_controls()
	assert_false(studio.undo_button.disabled)
	assert_string_contains(studio.undo_button.tooltip_text, "Deplacer la grille")
	studio._rebuild_history_menu()
	var popup := studio.history_button.get_popup()
	var history_text := ""
	for index in range(popup.item_count):
		history_text += popup.get_item_text(index) + "\n"
	assert_string_contains(history_text, "sauvegardée")
	studio._undo_active()
	assert_false(studio.redo_button.disabled)
	assert_string_contains(studio.redo_button.tooltip_text, "Deplacer la grille")
	ArenaSerializer.remove_recovery(arena_main.arena.arena_id)


func test_anchor_edit_and_auto_fit_are_single_undoable_actions() -> void:
	var studio := ArenaStudioMain.new()
	add_child_autofree(studio)
	studio._on_tool_selected(ArenaStudioCanvas.Tool.CALIBRATION_ANCHORS)
	var original := studio.arena.to_snapshot()
	var index := 0
	var anchor_screen := GridTransformService.image_to_view(
		studio.arena.calibration_pixels[index], studio.canvas.pan, studio.canvas.zoom
	)
	assert_true(studio.canvas._handle_anchor_press(anchor_screen, MOUSE_BUTTON_LEFT))
	var motion := InputEventMouseMotion.new()
	motion.position = anchor_screen + Vector2(8, -4)
	studio.canvas._handle_mouse_motion(motion)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = motion.position
	studio.canvas._handle_mouse_button(release)
	assert_eq(studio.edit_session.history.get_current_index(), 1)
	assert_ne(studio.arena.to_snapshot(), original)
	studio.fit_multipoint_calibration()
	assert_eq(studio.edit_session.history.get_current_index(), 2)
	assert_string_contains(studio.history_undo_name(), "ancres")
	assert_true(studio.history_undo())
	assert_eq(studio.edit_session.history.get_current_index(), 1)
	assert_true(studio.history_undo())
	assert_eq(studio.arena.to_snapshot(), original)
	ArenaSerializer.remove_recovery(studio.arena.arena_id)


func test_direct_test_serializes_working_copy_without_saving_source() -> void:
	var studio := ArenaStudioMain.new()
	add_child_autofree(studio)
	var stale_request := ProjectSettings.globalize_path(ArenaStudioMain.TEST_REQUEST)
	if FileAccess.file_exists(stale_request):
		DirAccess.remove_absolute(stale_request)
	var source_snapshot := studio.edit_session.source_arena.to_snapshot()
	studio.prepare_automatically()
	var before := studio.arena.to_snapshot()
	studio.arena.grid_origin += Vector2(7, -3)
	studio._commit_change("Deplacer la grille", before, studio.arena.to_snapshot())
	assert_true(studio.dirty)
	studio.test_arena()
	var request_exists := FileAccess.file_exists(ArenaStudioMain.TEST_REQUEST)
	assert_true(
		request_exists,
		studio.status_label.text + "\n" + (
			studio.validation_report.to_markdown() if studio.validation_report != null else "sans rapport"
		)
	)
	if not request_exists:
		ArenaSerializer.remove_recovery(studio.arena.arena_id)
		return
	var request = JSON.parse_string(FileAccess.get_file_as_string(ArenaStudioMain.TEST_REQUEST))
	assert_true(request is Dictionary)
	var test_path := str(request.get("arena_path", ""))
	assert_true(test_path.begins_with(ArenaStudioMain.TEST_WORK_ROOT + "/"))
	assert_true(FileAccess.file_exists(test_path))
	var test_copy := load(test_path) as ArenaDefinition
	assert_not_null(test_copy)
	assert_eq(test_copy.grid_origin, studio.arena.grid_origin)
	assert_eq(studio.edit_session.source_arena.to_snapshot(), source_snapshot)
	assert_true(studio.dirty)
	var test_absolute := ProjectSettings.globalize_path(test_path)
	if test_path.begins_with(ArenaStudioMain.TEST_WORK_ROOT + "/") \
			and FileAccess.file_exists(test_absolute):
		DirAccess.remove_absolute(test_absolute)
	var request_absolute := ProjectSettings.globalize_path(ArenaStudioMain.TEST_REQUEST)
	if FileAccess.file_exists(request_absolute):
		DirAccess.remove_absolute(request_absolute)
	ArenaSerializer.remove_recovery(studio.arena.arena_id)


func test_forest_volcano_space_transform_roundtrip_and_runtime_projection_parity() -> void:
	for arena_id in [&"room_01_forest", &"room_05_volcano", &"room_06_space"]:
		var arena := ArenaLegacyImporter.import_production(arena_id)
		assert_not_null(arena)
		var session := ArenaEditSession.new()
		assert_true(session.open(arena, "", false, str(arena_id)))
		var initial := session.working_arena.to_snapshot()
		var transform := GridTransformSnapshot.from_arena(session.working_arena)
		var center := GridTransformService.logical_grid_center(
			transform, session.working_arena.grid_size
		)
		transform = GridTransformService.translate(transform, Vector2(3.25, -1.75))
		transform = GridTransformService.rotate_around(transform, center, deg_to_rad(0.75))
		transform = GridTransformService.scale_around(transform, center, 1.015)
		transform.axis_x += Vector2(0.2, -0.1)
		assert_true(GridTransformService.validate_snapshot(transform).ok)
		transform.apply_to(session.working_arena)
		ArenaRuntimeBridge.sync_runtime_resources(session.working_arena)
		assert_true(session.commit(
			"Regression transform", initial, session.working_arena.to_snapshot()
		))
		# La working copy metier ne porte plus painted_map_visual_data : la
		# parite de projection se verifie sur ArenaEditSession.runtime_projection().
		assert_null(session.working_arena.painted_map_visual_data)
		var projection := session.runtime_projection()
		assert_not_null(projection)
		for y in range(session.working_arena.grid_size.y):
			for x in range(session.working_arena.grid_size.x):
				var cell := Vector2i(x, y)
				var expected := GridTransformService.cell_to_position(
					cell, session.working_arena.grid_origin,
					session.working_arena.axis_x, session.working_arena.axis_y
				)
				assert_almost_eq(
					projection.painted_map_visual_data.cell_to_image(cell),
					expected, Vector2(0.0001, 0.0001)
				)
				assert_eq(
					projection.painted_map_visual_data.image_to_cell(expected), cell
				)
		var transformed := session.working_arena.to_snapshot()
		assert_true(session.history.undo())
		assert_eq(session.working_arena.to_snapshot(), initial)
		assert_true(session.history.redo())
		assert_eq(session.working_arena.to_snapshot(), transformed)


func test_space_uid_background_is_a_valid_project_resource() -> void:
	var arena := ArenaLegacyImporter.import_production(&"room_06_space")
	assert_not_null(arena)
	assert_true(arena.background_path.begins_with("uid://"))
	assert_true(ResourceLoader.exists(arena.background_path))
	var report := ArenaValidator.validate(arena, false)
	for message in report.messages:
		assert_ne(message.code, &"absolute_background_path")
