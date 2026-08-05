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
		for y in range(session.working_arena.grid_size.y):
			for x in range(session.working_arena.grid_size.x):
				var cell := Vector2i(x, y)
				var expected := GridTransformService.cell_to_position(
					cell, session.working_arena.grid_origin,
					session.working_arena.axis_x, session.working_arena.axis_y
				)
				assert_almost_eq(
					session.working_arena.painted_map_visual_data.cell_to_image(cell),
					expected, Vector2(0.0001, 0.0001)
				)
				assert_eq(
					session.working_arena.painted_map_visual_data.image_to_cell(expected), cell
				)
		var transformed := session.working_arena.to_snapshot()
		assert_true(session.history.undo())
		assert_eq(session.working_arena.to_snapshot(), initial)
		assert_true(session.history.redo())
		assert_eq(session.working_arena.to_snapshot(), transformed)
