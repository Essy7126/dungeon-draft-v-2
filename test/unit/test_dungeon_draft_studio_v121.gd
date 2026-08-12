extends GutTest


func test_integrated_lab_is_a_mode_on_the_same_canvas_session_document_and_history() -> void:
	var studio := ArenaStudioMain.new()
	studio.size = Vector2(1280, 680)
	add_child_autofree(studio)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_not_null(studio.edit_session)
	var session := studio.edit_session
	var document := studio.edit_session.working_arena
	var history := studio.edit_session.history
	var canvas := studio.canvas
	var selection := [Vector2i(3, 3), Vector2i(4, 3)]
	canvas.selected_cells.assign(selection)
	var view_children := studio.view_stack.get_child_count()
	var windows_before := _count_nodes_of_type(studio, "Window")
	var popups_before := _count_nodes_of_type(studio, "Popup")
	var subviewports_before := studio.find_children("*", "SubViewportContainer", true, false).size()
	var stroke_connections := canvas.stroke_started.get_connections().size()
	studio.show_dynamic_construction()
	if studio.arena.visual_mode == ArenaDefinition.VisualMode.PAINTED:
		studio._enter_painted_logic_only()
	assert_eq(studio.workspace_mode, ArenaStudioMain.WorkspaceMode.DYNAMIC_CONSTRUCTION)
	assert_true(studio.canvas.visible)
	assert_false(studio.runtime_preview.visible)
	assert_true(studio.dynamic_palette.visible)
	assert_true(studio.edit_session == session)
	assert_true(studio.edit_session.working_arena == document)
	assert_true(studio.edit_session.history == history)
	assert_true(studio.canvas == canvas)
	assert_eq(canvas.selected_cells, selection)
	assert_eq(studio.view_stack.get_child_count(), view_children)
	assert_eq(_count_nodes_of_type(studio, "Window"), windows_before)
	assert_eq(_count_nodes_of_type(studio, "Popup"), popups_before)
	assert_eq(studio.find_children("*", "DynamicArenaLab", true, false).size(), 0)
	assert_eq(
		studio.find_children("*", "SubViewportContainer", true, false).size(),
		subviewports_before
	)
	for duplicate in ["Nouvelle", "Ouvrir", "Sauver", "Annuler", "Rétablir", "Envoyer au Studio"]:
		assert_false(_button_texts(studio.dynamic_palette).has(duplicate), duplicate)
	for iteration in range(20):
		studio._show_editor_canvas(false)
		studio.show_dynamic_construction()
	assert_eq(studio.view_stack.get_child_count(), view_children)
	assert_eq(canvas.stroke_started.get_connections().size(), stroke_connections)
	assert_true(studio.edit_session == session)
	assert_true(studio.edit_session.history == history)


func test_dynamic_paint_wall_spawn_and_objective_use_one_canonical_history() -> void:
	var studio := ArenaStudioMain.new()
	studio.size = Vector2(1280, 680)
	add_child_autofree(studio)
	await get_tree().process_frame
	await get_tree().process_frame
	studio._set_arena(_fixture(), true, "v121_dynamic")
	studio.show_dynamic_construction()
	var session := studio.edit_session
	var cell := Vector2i(4, 4)
	var opening := ArenaEditSession.fingerprint(session.working_arena.to_snapshot())
	var initial_entries := session.history.get_history_entries().size()
	for option_index in range(studio.dynamic_terrain_option.item_count):
		if str(studio.dynamic_terrain_option.get_item_metadata(option_index)) == "ice":
			studio.dynamic_terrain_option.select(option_index)
			break
	studio._select_dynamic_tool(ArenaStudioCanvas.Tool.TERRAIN)
	studio._on_stroke_started("Peindre la glace")
	studio._on_cells_edit_requested([cell], false)
	studio._on_stroke_finished("Peindre la glace")
	assert_eq(str(session.working_arena.get_cell_definition(cell).terrain_id), "ice")
	assert_eq(session.history.get_history_entries().size(), initial_entries + 1)
	assert_true(session.history.undo())
	assert_eq(ArenaEditSession.fingerprint(session.working_arena.to_snapshot()), opening)
	assert_true(session.history.redo())
	studio.dynamic_wall_option.select(1) # feu
	studio._select_dynamic_tool(ArenaStudioCanvas.Tool.OBSTACLE)
	studio._on_stroke_started("Placer un mur feu")
	studio._on_cells_edit_requested([Vector2i(5, 4)], false)
	studio._on_stroke_finished("Placer un mur feu")
	var wall := session.working_arena.obstacle_at(Vector2i(5, 4))
	assert_not_null(wall)
	assert_eq(str(wall.wall_id), "fire")
	assert_true(wall.wall_config == ArenaWallRegistry.config_for(&"fire"))
	studio.dynamic_special_option.select(2) # objectif
	studio._select_dynamic_tool(ArenaStudioCanvas.Tool.SPAWN)
	studio._on_stroke_started("Placer un objectif")
	studio._on_cells_edit_requested([Vector2i(6, 4)], false)
	studio._on_stroke_finished("Placer un objectif")
	assert_eq(session.working_arena.objectives.size(), 1)
	assert_true(studio.canvas.input_router != null)
	assert_true(studio.canvas.dynamic_construction_mode)


func test_input_router_deduplicates_events_and_tracks_one_active_consumer() -> void:
	var canvas := ArenaStudioCanvas.new()
	canvas.size = Vector2(800, 600)
	add_child_autofree(canvas)
	await get_tree().process_frame
	canvas.set_arena(_fixture())
	canvas.set_tool(ArenaStudioCanvas.Tool.SELECT)
	var event := InputEventMouseMotion.new()
	event.position = Vector2(350, 250)
	assert_true(canvas.input_router.route_canvas_event(event, canvas))
	assert_false(canvas.input_router.route_canvas_event(event, canvas))
	assert_eq(canvas.input_router.processed_event_count, 1)
	assert_eq(canvas.input_router.consumed_event_count, 1)
	canvas.input_router.begin_gesture(ArenaInputRouter.ArenaInputMode.PAINT_TERRAIN, "terrain")
	assert_true(canvas.input_router.gesture_active)
	assert_eq(canvas.input_router.last_consumer, "terrain")
	canvas.input_router.cancel_gesture()
	assert_false(canvas.input_router.gesture_active)
	assert_eq(canvas.input_router.mode, ArenaInputRouter.ArenaInputMode.IDLE)


func test_affine_gizmo_has_clear_priority_constant_screen_handles_and_no_mouse_wall() -> void:
	var canvas := ArenaStudioCanvas.new()
	canvas.size = Vector2(1280, 720)
	add_child_autofree(canvas)
	await get_tree().process_frame
	canvas.set_arena(_fixture())
	canvas.set_tool(ArenaStudioCanvas.Tool.TRANSFORM_GRID)
	canvas.grid_selected = true
	assert_eq(canvas.affine_gizmo.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	for tested_zoom in [0.25, 0.5, 1.0, 2.0, 3.0]:
		canvas.zoom = tested_zoom
		canvas._sync_affine_gizmo()
		var positions := canvas.affine_gizmo.handle_positions()
		for handle in [
			ArenaStudioCanvas.TransformHandle.PIVOT,
			ArenaStudioCanvas.TransformHandle.ROTATE,
			ArenaStudioCanvas.TransformHandle.ANGLE,
			ArenaStudioCanvas.TransformHandle.SCALE,
			ArenaStudioCanvas.TransformHandle.AXIS_X,
			ArenaStudioCanvas.TransformHandle.AXIS_Y,
		]:
			assert_true(positions.has(handle), "zoom %s handle %s" % [tested_zoom, handle])
			assert_eq(canvas.affine_gizmo.hit_test(positions[handle]), handle)
	assert_eq(GridAffineGizmo.HANDLE_RADIUS, 9.0)
	assert_eq(GridAffineGizmo.HIT_RADIUS, 14.0)


func test_angle_math_supports_symmetric_preserve_x_preserve_y_and_safety_limits() -> void:
	var source := GridTransformSnapshot.new(
		Vector2(120, 80), Vector2(42, 18), Vector2(-31, 27)
	)
	var initial_orientation := signf(GridTransformService.determinant(source.axis_x, source.axis_y))
	var initial_bisector := GridTransformService.interior_bisector(source.axis_x, source.axis_y)
	for target_degrees in [35.0, 75.0, 125.0, 165.0]:
		var result := GridTransformService.set_grid_angle(
			source, deg_to_rad(target_degrees), GridTransformService.AngleMode.SYMMETRIC
		)
		assert_true(result.ok, str(result))
		var value := result.snapshot as GridTransformSnapshot
		assert_almost_eq(rad_to_deg(GridTransformService.angle_between_axes(value.axis_x, value.axis_y)), target_degrees, 0.001)
		assert_almost_eq(value.axis_x.length(), source.axis_x.length(), 0.0001)
		assert_almost_eq(value.axis_y.length(), source.axis_y.length(), 0.0001)
		assert_almost_eq(GridTransformService.interior_bisector(value.axis_x, value.axis_y).dot(initial_bisector), 1.0, 0.0001)
		assert_eq(signf(GridTransformService.determinant(value.axis_x, value.axis_y)), initial_orientation)
	var preserve_x := GridTransformService.set_grid_angle(
		source, deg_to_rad(80.0), GridTransformService.AngleMode.PRESERVE_X
	)
	assert_true(preserve_x.ok)
	assert_almost_eq((preserve_x.snapshot as GridTransformSnapshot).axis_x.distance_to(source.axis_x), 0.0, 0.0001)
	var preserve_y := GridTransformService.set_grid_angle(
		source, deg_to_rad(95.0), GridTransformService.AngleMode.PRESERVE_Y
	)
	assert_true(preserve_y.ok)
	assert_almost_eq((preserve_y.snapshot as GridTransformSnapshot).axis_y.distance_to(source.axis_y), 0.0, 0.0001)
	var minimum := GridTransformService.set_grid_angle(source, deg_to_rad(1.0))
	var maximum := GridTransformService.set_grid_angle(source, deg_to_rad(179.0))
	assert_almost_eq(rad_to_deg(float(minimum.angle)), 10.0, 0.001)
	assert_almost_eq(rad_to_deg(float(maximum.angle)), 170.0, 0.001)
	assert_false(GridTransformService.set_grid_angle(source, NAN).ok)
	var degenerate := GridTransformSnapshot.new(Vector2.ZERO, Vector2.RIGHT, Vector2.LEFT)
	assert_false(GridTransformService.set_grid_angle(degenerate, deg_to_rad(90.0)).ok)


func test_angle_gesture_commits_once_and_escape_right_click_and_pivot_do_not_dirty() -> void:
	var studio := ArenaStudioMain.new()
	studio.size = Vector2(1280, 680)
	add_child_autofree(studio)
	await get_tree().process_frame
	await get_tree().process_frame
	studio._set_arena(_fixture(), true, "v121_gesture")
	studio._select_tool_and_preset(ArenaStudioCanvas.Tool.TRANSFORM_GRID, 0)
	var canvas := studio.canvas
	var session := studio.edit_session
	var opening := ArenaEditSession.fingerprint(session.working_arena.to_snapshot())
	var history_count := session.history.get_history_entries().size()
	canvas._sync_affine_gizmo()
	var start: Vector2 = canvas._transform_handle_screen_positions()[ArenaStudioCanvas.TransformHandle.ANGLE]
	assert_true(canvas._begin_transform_handle(ArenaStudioCanvas.TransformHandle.ANGLE, start, false, false))
	var target_result := GridTransformService.set_grid_angle(
		GridTransformSnapshot.from_arena(session.working_arena), deg_to_rad(90.0)
	)
	var target := target_result.snapshot as GridTransformSnapshot
	var motion := InputEventMouseMotion.new()
	var start_direction := (canvas._screen_to_image_native(start) - target.origin).normalized()
	var opening_angle := GridTransformService.angle_between_axes(
		session.working_arena.axis_x, session.working_arena.axis_y
	)
	motion.position = canvas._image_native_to_screen(
		target.origin + start_direction.rotated((deg_to_rad(90.0) - opening_angle) * 0.5) * 80.0
	)
	canvas._update_transform_drag(motion)
	canvas._finish_pointer_gesture()
	assert_eq(session.history.get_history_entries().size(), history_count + 1)
	assert_almost_eq(rad_to_deg(GridTransformService.angle_between_axes(session.working_arena.axis_x, session.working_arena.axis_y)), 90.0, 0.01)
	assert_true(session.history.undo())
	assert_eq(ArenaEditSession.fingerprint(session.working_arena.to_snapshot()), opening)
	canvas._sync_affine_gizmo()
	start = canvas._transform_handle_screen_positions()[ArenaStudioCanvas.TransformHandle.ANGLE]
	assert_true(canvas._begin_transform_handle(ArenaStudioCanvas.TransformHandle.ANGLE, start, false, false))
	target_result = GridTransformService.set_grid_angle(
		GridTransformSnapshot.from_arena(session.working_arena), deg_to_rad(70.0)
	)
	target = target_result.snapshot as GridTransformSnapshot
	motion = InputEventMouseMotion.new()
	start_direction = (canvas._screen_to_image_native(start) - target.origin).normalized()
	opening_angle = GridTransformService.angle_between_axes(
		session.working_arena.axis_x, session.working_arena.axis_y
	)
	motion.position = canvas._image_native_to_screen(
		target.origin + start_direction.rotated((deg_to_rad(70.0) - opening_angle) * 0.5) * 80.0
	)
	canvas._update_transform_drag(motion)
	assert_true(canvas.cancel_active_gesture())
	assert_eq(ArenaEditSession.fingerprint(session.working_arena.to_snapshot()), opening)
	assert_eq(session.history.get_history_entries().size(), history_count + 1)
	assert_true(_begin_angle_drag(canvas, session.working_arena, 72.0))
	var escape := InputEventKey.new()
	escape.pressed = true
	escape.keycode = KEY_ESCAPE
	canvas._handle_key_input(escape)
	assert_false(canvas.has_active_gesture())
	assert_eq(ArenaEditSession.fingerprint(session.working_arena.to_snapshot()), opening)
	assert_true(_begin_angle_drag(canvas, session.working_arena, 74.0))
	var right_click := InputEventMouseButton.new()
	right_click.pressed = true
	right_click.button_index = MOUSE_BUTTON_RIGHT
	canvas._handle_mouse_button(right_click)
	assert_false(canvas.has_active_gesture())
	assert_eq(ArenaEditSession.fingerprint(session.working_arena.to_snapshot()), opening)
	assert_true(_begin_angle_drag(canvas, session.working_arena, 76.0))
	canvas.set_tool(ArenaStudioCanvas.Tool.SELECT)
	assert_false(canvas.has_active_gesture())
	assert_eq(ArenaEditSession.fingerprint(session.working_arena.to_snapshot()), opening)
	canvas.set_tool(ArenaStudioCanvas.Tool.TRANSFORM_GRID)
	assert_true(_begin_angle_drag(canvas, session.working_arena, 78.0))
	canvas.focus_exited.emit()
	assert_false(canvas.has_active_gesture())
	assert_eq(ArenaEditSession.fingerprint(session.working_arena.to_snapshot()), opening)
	assert_eq(session.history.get_history_entries().size(), history_count + 1)
	canvas._sync_affine_gizmo()
	var pivot_start: Vector2 = canvas._transform_handle_screen_positions()[ArenaStudioCanvas.TransformHandle.PIVOT]
	assert_true(canvas._begin_transform_handle(ArenaStudioCanvas.TransformHandle.PIVOT, pivot_start, false, false))
	var pivot_motion := InputEventMouseMotion.new()
	pivot_motion.position = pivot_start + Vector2(40, 25)
	canvas._update_transform_drag(pivot_motion)
	canvas._finish_pointer_gesture()
	assert_eq(ArenaEditSession.fingerprint(session.working_arena.to_snapshot()), opening)
	assert_eq(session.history.get_history_entries().size(), history_count + 1)


func test_twenty_detach_reintegrate_cycles_keep_the_same_dynamic_workspace_and_router() -> void:
	var embedded := EmbeddedStudioHost.new()
	add_child_autofree(embedded)
	var window := NativeStudioWindowHost.new()
	add_child_autofree(window)
	await get_tree().process_frame
	var workspace := StudioWorkspace.new()
	embedded.attach_workspace(workspace)
	await get_tree().process_frame
	workspace.arena_studio.show_dynamic_construction()
	if workspace.arena_studio.arena.visual_mode == ArenaDefinition.VisualMode.PAINTED:
		workspace.arena_studio._enter_painted_logic_only()
	workspace.arena_studio.canvas.selected_cells = [Vector2i(2, 2), Vector2i(3, 2)]
	var workspace_identity := workspace.workspace_instance_id
	var session_identity := workspace.arena_studio.edit_session.get_instance_id()
	var history_identity := workspace.arena_studio.edit_session.history.get_instance_id()
	var router_identity := workspace.arena_studio.canvas.input_router.get_instance_id()
	for iteration in range(20):
		window.attach_workspace(workspace)
		assert_true(workspace.get_parent() == window, "detach %d" % iteration)
		assert_eq(workspace.workspace_instance_id, workspace_identity)
		assert_eq(workspace.arena_studio.edit_session.get_instance_id(), session_identity)
		assert_eq(workspace.arena_studio.edit_session.history.get_instance_id(), history_identity)
		assert_eq(workspace.arena_studio.canvas.input_router.get_instance_id(), router_identity)
		assert_eq(workspace.arena_studio.workspace_mode, ArenaStudioMain.WorkspaceMode.DYNAMIC_CONSTRUCTION)
		embedded.attach_workspace(window.detach_workspace())
		assert_true(workspace.get_parent() == embedded, "reintegrate %d" % iteration)
		assert_eq(workspace.arena_studio.canvas.selected_cells, [Vector2i(2, 2), Vector2i(3, 2)])
	assert_eq(window.get_child_count(), 0)
	assert_eq(embedded.find_children("*", "StudioWorkspace", true, false).size(), 1)
	assert_false(workspace.arena_studio.canvas.has_active_gesture())


func test_standalone_lab_keeps_toolbar_and_uses_shared_router_and_editing_services() -> void:
	var scene := load("res://tools/labs/dynamic_arena/DynamicArenaLab.tscn") as PackedScene
	var lab := scene.instantiate() as DynamicArenaLab
	add_child_autofree(lab)
	await get_tree().process_frame
	lab.new_document(Vector2i(9, 7), "Standalone 1.2.1", "standalone_121")
	assert_false(lab._embedded_mode)
	assert_not_null(lab._document_controls)
	assert_true(lab._document_controls.visible)
	assert_not_null(lab.input_router)
	assert_true(lab.set_cell_surface(Vector2i(3, 3), DynamicCellState.Surface.WATER))
	assert_eq(str(lab.working_arena.get_cell_definition(Vector2i(3, 3)).terrain_id), "water")
	assert_not_null(lab.place_wall(Vector2i(4, 3), DynamicWall.WallVariant.ICE))
	assert_eq(str(lab.working_arena.obstacle_at(Vector2i(4, 3)).wall_id), "ice")
	assert_true(lab.edit_session.history.can_undo())
	assert_true(lab.edit_session.history.undo())
	assert_null(lab.working_arena.obstacle_at(Vector2i(4, 3)))


func test_forest_volcano_space_keep_runtime_projection_after_full_affine_changes() -> void:
	for arena_id in [&"room_01_forest", &"room_05_volcano", &"room_06_space"]:
		var arena := ArenaLegacyImporter.import_production(arena_id)
		assert_not_null(arena, str(arena_id))
		var original := GridTransformSnapshot.from_arena(arena)
		var pivot := GridTransformService.logical_grid_center(original, arena.grid_size)
		var changed := GridTransformService.translate(original, Vector2(17.0, -9.0))
		changed = GridTransformService.rotate_around(changed, pivot + Vector2(17.0, -9.0), deg_to_rad(7.0))
		changed = GridTransformService.scale_around(changed, pivot + Vector2(17.0, -9.0), 1.08)
		var angled := GridTransformService.set_grid_angle(changed, deg_to_rad(112.0))
		assert_true(angled.ok, str(arena_id))
		changed = angled.snapshot as GridTransformSnapshot
		changed.apply_to(arena)
		assert_true(ArenaRuntimeBridge.sync_runtime_resources(arena))
		var signature := ArenaRuntimeBridge.runtime_signature(arena)
		assert_false(signature.is_empty())
		for cell in [Vector2i.ZERO, Vector2i(arena.grid_size.x / 2, arena.grid_size.y / 2), arena.grid_size - Vector2i.ONE]:
			var key := "%d,%d" % [cell.x, cell.y]
			var center: Vector2 = signature.centers[key]
			assert_almost_eq(center.distance_to(GridTransformService.cell_to_position(cell, arena.grid_origin, arena.axis_x, arena.axis_y)), 0.0, 0.0001)
			assert_eq(arena.painted_map_visual_data.image_to_cell(center), cell)


func test_one_hundred_angle_cycles_have_no_drift_nan_inf_or_orientation_flip() -> void:
	var opening := GridTransformSnapshot.new(Vector2(300, 160), Vector2(38, 19), Vector2(-35, 21))
	var current := opening.copy()
	var orientation := signf(GridTransformService.determinant(current.axis_x, current.axis_y))
	for iteration in range(100):
		var opened := GridTransformService.set_grid_angle(current, deg_to_rad(150.0))
		assert_true(opened.ok, "open %d" % iteration)
		var restored := GridTransformService.set_grid_angle(opened.snapshot, GridTransformService.angle_between_axes(opening.axis_x, opening.axis_y))
		assert_true(restored.ok, "restore %d" % iteration)
		current = restored.snapshot
		assert_true(GridTransformService.is_vector_finite(current.axis_x))
		assert_true(GridTransformService.is_vector_finite(current.axis_y))
		assert_eq(signf(GridTransformService.determinant(current.axis_x, current.axis_y)), orientation)
	assert_almost_eq(current.origin.distance_to(opening.origin), 0.0, 0.0001)
	assert_almost_eq(current.axis_x.distance_to(opening.axis_x), 0.0, 0.001)
	assert_almost_eq(current.axis_y.distance_to(opening.axis_y), 0.0, 0.001)


func _fixture() -> ArenaDefinition:
	var arena := ArenaDefinition.new()
	arena.set_identity("Studio 1.2.1 Fixture", "studio_1_2_1_fixture")
	arena.visual_mode = ArenaDefinition.VisualMode.MODULAR
	arena.modular_visual_profile = ArenaModularVisualProfile.new()
	arena.grid_size = Vector2i(10, 8)
	arena.grid_origin = Vector2(420, 150)
	arena.axis_x = Vector2(36, 18)
	arena.axis_y = Vector2(-34, 21)
	for y in range(arena.grid_size.y):
		for x in range(arena.grid_size.x):
			ArenaTerrainRegistry.configure_cell(arena.ensure_cell(Vector2i(x, y)), &"stone")
	ArenaRuntimeBridge.sync_runtime_resources(arena)
	return arena


func _count_nodes_of_type(root: Node, requested_class: String) -> int:
	var count := 0
	for child in root.get_children():
		if child.is_class(requested_class):
			count += 1
		count += _count_nodes_of_type(child, requested_class)
	return count


func _button_texts(root: Node) -> Array[String]:
	var result: Array[String] = []
	for child in root.find_children("*", "Button", true, false):
		result.append((child as Button).text)
	return result


func _begin_angle_drag(
		canvas: ArenaStudioCanvas,
		arena: ArenaDefinition,
		target_degrees: float
	) -> bool:
	canvas._sync_affine_gizmo()
	var start: Vector2 = canvas._transform_handle_screen_positions()[
		ArenaStudioCanvas.TransformHandle.ANGLE
	]
	if not canvas._begin_transform_handle(
			ArenaStudioCanvas.TransformHandle.ANGLE, start, false, false
		):
		return false
	var opening_angle := GridTransformService.angle_between_axes(arena.axis_x, arena.axis_y)
	var start_direction := (
		canvas._screen_to_image_native(start) - arena.grid_origin
	).normalized()
	var motion := InputEventMouseMotion.new()
	motion.position = canvas._image_native_to_screen(
		arena.grid_origin
		+ start_direction.rotated((deg_to_rad(target_degrees) - opening_angle) * 0.5)
		* 80.0
	)
	canvas._update_transform_drag(motion)
	return true
