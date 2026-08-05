@tool
class_name ArenaStudioCanvas
extends Control

signal stroke_started(action_name: String)
signal cells_edit_requested(cells: Array[Vector2i], erase: bool)
signal stroke_finished(action_name: String)
signal stroke_cancelled
signal calibration_requested(origin: Vector2, axis_x: Vector2, axis_y: Vector2)
signal calibration_preview_requested(origin: Vector2, axis_x: Vector2, axis_y: Vector2)
signal anchors_preview_requested(cells: Array[Vector2i], pixels: Array[Vector2])
signal hovered_cell_changed(cell: Vector2i)
signal verification_cell_requested(cell: Vector2i)

enum Tool {
	SELECT,
	PAN,
	ADD_CELL,
	REMOVE_CELL,
	BORDER,
	OBSTACLE,
	TERRAIN,
	SPAWN,
	VERIFY,
	TRANSFORM_GRID,
	CALIBRATION_ANCHORS,
}

enum TransformHandle {
	NONE = -1,
	BODY,
	AXIS_X,
	AXIS_Y,
	ROTATE,
	SCALE,
	PIVOT,
	ANCHOR,
}

enum BrushShape {
	BRUSH,
	RECTANGLE,
	FILL,
	MULTI_SELECT,
}

const INVALID_CELL := GridTransformService.INVALID_CELL
const ZOOM_MIN := 0.08
const ZOOM_MAX := 8.0
const GRID_COLOR := Color(0.57, 0.86, 1.0, 0.62)
const COLORS := {
	"playable": Color(0.10, 0.62, 0.42, 0.22),
	"border": Color(0.60, 0.28, 0.86, 0.48),
	"blocked": Color(0.91, 0.23, 0.18, 0.55),
	"non_playable": Color(0.18, 0.22, 0.30, 0.58),
	"selected": Color(1.0, 0.72, 0.18, 0.55),
	"reachable": Color(0.18, 0.68, 1.0, 0.38),
	"path": Color(1.0, 0.78, 0.12, 0.70),
	"line_clear": Color(0.25, 1.0, 0.56, 0.68),
	"line_blocked": Color(1.0, 0.24, 0.20, 0.72),
}

var arena: ArenaDefinition = null
var active_tool := Tool.SELECT
var brush_shape := BrushShape.BRUSH
var zoom := 1.0
var pan := Vector2.ZERO
var show_grid := true
var show_spawns := true
var show_technical := false
var show_saved_comparison := false
var background_opacity := 1.0
var grid_opacity := 1.0
var calibration_active := false
var verification_kind := &"path"
var selected_cells: Array[Vector2i] = []
var reachable_cells: Array[Vector2i] = []
var path_cells: Array[Vector2i] = []
var line_cells: Array[Vector2i] = []
var line_blocked := false
var first_blocker := INVALID_CELL
var snap_enabled := true
var position_snap := 1.0
var angle_snap_degrees := 0.25
var scale_snap := 0.005
var fine_factor := 0.1
var lock_translation := false
var lock_rotation := false
var lock_scale := false
var lock_axis_x := false
var lock_axis_y := false
var preserve_axis_length := false
var mirror_axes := false
var layer_visibility := {
	"background": true,
	"calibration": true,
	"gameplay": true,
	"details": true,
	"spawns": true,
	"foreground": true,
}
var layer_locks := {
	"background": true,
	"calibration": false,
	"gameplay": false,
	"details": false,
	"spawns": false,
	"foreground": true,
}

var _texture: Texture2D = null
var _hovered := INVALID_CELL
var _panning := false
var _painting := false
var _rectangle_start := INVALID_CELL
var _rectangle_current := INVALID_CELL
var _painted_this_stroke := {}
var _calibration_points: Array[Vector2] = []
var _drag_handle := -1
var _drag_origin := Vector2.ZERO
var _drag_axis_x := Vector2.ZERO
var _drag_axis_y := Vector2.ZERO
var _drag_snapshot: GridTransformSnapshot = null
var _saved_transform: GridTransformSnapshot = null
var _drag_start_screen := Vector2.ZERO
var _drag_pivot := Vector2.ZERO
var _drag_start_angle := 0.0
var _drag_start_distance := 1.0
var _drag_changed := false
var _custom_pivot := Vector2.ZERO
var _custom_pivot_enabled := false
var _live_transform_text := ""
var _anchor_drag_index := -1
var _selected_anchor_index := -1


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	resized.connect(queue_redraw)
	focus_exited.connect(cancel_active_gesture)


func set_arena(value: ArenaDefinition) -> void:
	cancel_active_gesture()
	arena = value
	_texture = null
	selected_cells.clear()
	reachable_cells.clear()
	path_cells.clear()
	line_cells.clear()
	_hovered = INVALID_CELL
	if arena != null and ResourceLoader.exists(arena.background_path):
		_texture = load(arena.background_path) as Texture2D
	if arena != null and not _custom_pivot_enabled:
		_custom_pivot = GridTransformService.logical_grid_center(
			GridTransformSnapshot.from_arena(arena), arena.grid_size
		)
	queue_redraw()
	call_deferred("fit_to_image")


func set_tool(value: int) -> void:
	if value != active_tool:
		cancel_active_gesture()
	active_tool = clampi(value, Tool.SELECT, Tool.CALIBRATION_ANCHORS)
	calibration_active = false
	queue_redraw()


func set_saved_transform(snapshot: GridTransformSnapshot) -> void:
	_saved_transform = snapshot.copy() if snapshot != null else null
	queue_redraw()


func set_layer_state(layer: String, visible: bool, locked: bool) -> void:
	if layer_visibility.has(layer):
		layer_visibility[layer] = visible
		layer_locks[layer] = locked
		queue_redraw()


func get_editor_state() -> Dictionary:
	return {
		"pivot_mode": "custom" if _custom_pivot_enabled else "center",
		"custom_pivot": [_custom_pivot.x, _custom_pivot.y],
		"snap_enabled": snap_enabled,
		"position_snap": position_snap,
		"angle_snap_degrees": angle_snap_degrees,
		"scale_snap": scale_snap,
		"fine_factor": fine_factor,
		"layers": layer_visibility.duplicate(true),
		"layer_locks": layer_locks.duplicate(true),
		"background_opacity": background_opacity,
		"grid_opacity": grid_opacity,
	}


func apply_editor_state(state: Dictionary) -> void:
	if state.is_empty():
		return
	_custom_pivot_enabled = str(state.get("pivot_mode", "center")) == "custom"
	var pivot_value = state.get("custom_pivot", [0.0, 0.0])
	if pivot_value is Array and pivot_value.size() >= 2:
		_custom_pivot = Vector2(float(pivot_value[0]), float(pivot_value[1]))
	snap_enabled = bool(state.get("snap_enabled", true))
	position_snap = maxf(float(state.get("position_snap", 1.0)), 0.0)
	angle_snap_degrees = maxf(float(state.get("angle_snap_degrees", 0.25)), 0.0)
	scale_snap = maxf(float(state.get("scale_snap", 0.005)), 0.0)
	fine_factor = clampf(float(state.get("fine_factor", 0.1)), 0.001, 1.0)
	var layers = state.get("layers", {})
	if layers is Dictionary:
		for key in layers:
			if layer_visibility.has(key):
				layer_visibility[key] = bool(layers[key])
	var locks = state.get("layer_locks", {})
	if locks is Dictionary:
		for key in locks:
			if layer_locks.has(key):
				layer_locks[key] = bool(locks[key])
	background_opacity = clampf(float(state.get("background_opacity", 1.0)), 0.1, 1.0)
	grid_opacity = clampf(float(state.get("grid_opacity", 1.0)), 0.1, 1.0)
	queue_redraw()


func is_transforming() -> bool:
	return _drag_handle != TransformHandle.NONE


func cancel_active_gesture() -> bool:
	var had_gesture := _drag_handle != TransformHandle.NONE or _painting
	if not had_gesture:
		_panning = false
		return false
	if _drag_snapshot != null and arena != null:
		calibration_preview_requested.emit(
			_drag_snapshot.origin, _drag_snapshot.axis_x, _drag_snapshot.axis_y
		)
	_drag_handle = TransformHandle.NONE
	_anchor_drag_index = -1
	_drag_snapshot = null
	_drag_changed = false
	_painting = false
	_rectangle_start = INVALID_CELL
	_rectangle_current = INVALID_CELL
	_painted_this_stroke.clear()
	_live_transform_text = "Geste annule"
	stroke_cancelled.emit()
	queue_redraw()
	return true


func begin_three_click_calibration() -> void:
	calibration_active = true
	_calibration_points.clear()
	active_tool = Tool.SELECT
	queue_redraw()


func calibration_step() -> int:
	return _calibration_points.size()


func fit_to_image() -> void:
	if arena == null or arena.source_image_size.x <= 0 or arena.source_image_size.y <= 0:
		return
	var image_size := Vector2(arena.source_image_size) * arena.image_scale
	var available := size - Vector2(48, 48)
	zoom = clampf(
		minf(available.x / maxf(image_size.x, 1.0), available.y / maxf(image_size.y, 1.0)),
		ZOOM_MIN,
		ZOOM_MAX
	)
	pan = size * 0.5 - (arena.image_offset + image_size * 0.5) * zoom
	queue_redraw()


func recenter_grid() -> void:
	if arena == null:
		return
	var center_cell := Vector2i(arena.grid_size.x / 2, arena.grid_size.y / 2)
	var image_position := GridTransformService.cell_to_position(
		center_cell, arena.grid_origin, arena.axis_x, arena.axis_y
	)
	pan = size * 0.5 - image_position * zoom
	queue_redraw()


func center_on_cell(cell: Vector2i) -> void:
	if arena == null or not arena.is_in_bounds(cell):
		return
	pan = size * 0.5 - GridTransformService.cell_to_position(
		cell, arena.grid_origin, arena.axis_x, arena.axis_y
	) * zoom
	selected_cells = [cell]
	queue_redraw()


func set_verification_overlay(
		reachable: Array[Vector2i],
		path: Array[Vector2i],
		line: Array[Vector2i],
		blocked: bool,
		blocker: Vector2i
	) -> void:
	reachable_cells = reachable.duplicate()
	path_cells = path.duplicate()
	line_cells = line.duplicate()
	line_blocked = blocked
	first_blocker = blocker
	queue_redraw()


func clear_overlays() -> void:
	reachable_cells.clear()
	path_cells.clear()
	line_cells.clear()
	first_blocker = INVALID_CELL
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if arena == null:
		return
	if event is InputEventKey:
		_handle_key_input(event)
	elif event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event)


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed \
			and is_transforming():
		cancel_active_gesture()
		accept_event()
		return
	if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] \
			and event.pressed:
		var before := GridTransformService.view_to_image(event.position, pan, zoom)
		var factor := 1.12 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.12
		zoom = clampf(zoom * factor, ZOOM_MIN, ZOOM_MAX)
		pan = event.position - before * zoom
		queue_redraw()
		accept_event()
		return
	if event.button_index == MOUSE_BUTTON_MIDDLE \
			or (event.button_index == MOUSE_BUTTON_LEFT and active_tool == Tool.PAN):
		_panning = event.pressed
		accept_event()
		return
	if event.button_index not in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		return
	var cell := _cell_at(event.position)
	if event.pressed:
		grab_focus()
		if calibration_active and event.button_index == MOUSE_BUTTON_LEFT:
			_add_calibration_point(event.position)
			accept_event()
			return
		if active_tool == Tool.CALIBRATION_ANCHORS \
				and _handle_anchor_press(event.position, event.button_index):
			accept_event()
			return
		if event.button_index == MOUSE_BUTTON_LEFT and _try_begin_transform_drag(event.position):
			accept_event()
			return
		if cell == INVALID_CELL:
			return
		if active_tool == Tool.VERIFY:
			verification_cell_requested.emit(cell)
			accept_event()
			return
		if active_tool == Tool.SELECT or brush_shape == BrushShape.MULTI_SELECT:
			if not event.shift_pressed:
				selected_cells.clear()
			if selected_cells.has(cell):
				selected_cells.erase(cell)
			else:
				selected_cells.append(cell)
			queue_redraw()
			accept_event()
			return
		_painting = true
		_painted_this_stroke.clear()
		stroke_started.emit(_action_name())
		if brush_shape == BrushShape.RECTANGLE:
			_rectangle_start = cell
			_rectangle_current = cell
		elif brush_shape == BrushShape.FILL:
			_request_cells(_contiguous_cells(cell), event.button_index == MOUSE_BUTTON_RIGHT)
		else:
			_request_cells([cell], event.button_index == MOUSE_BUTTON_RIGHT)
		accept_event()
	else:
		if _drag_handle != TransformHandle.NONE:
			var action_name := _transform_action_name(_drag_handle)
			_drag_handle = TransformHandle.NONE
			_drag_snapshot = null
			_anchor_drag_index = -1
			if _drag_changed:
				stroke_finished.emit(action_name)
			else:
				stroke_cancelled.emit()
			_drag_changed = false
			_live_transform_text = ""
			accept_event()
			return
		if not _painting:
			return
		if brush_shape == BrushShape.RECTANGLE and _rectangle_start != INVALID_CELL:
			_request_cells(
				_rectangle_cells(_rectangle_start, _rectangle_current),
				event.button_index == MOUSE_BUTTON_RIGHT
			)
		stroke_finished.emit(_action_name())
		_painting = false
		_rectangle_start = INVALID_CELL
		_rectangle_current = INVALID_CELL
		_painted_this_stroke.clear()
		queue_redraw()
		accept_event()


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if _panning:
		pan += event.relative
		queue_redraw()
		accept_event()
		return
	if _drag_handle != TransformHandle.NONE:
		if _drag_handle == TransformHandle.ANCHOR:
			_update_anchor_drag(event.position)
		else:
			_update_transform_drag(event)
		queue_redraw()
		accept_event()
		return
	var cell := _cell_at(event.position)
	if cell != _hovered:
		_hovered = cell
		hovered_cell_changed.emit(cell)
		queue_redraw()
	if _painting and cell != INVALID_CELL:
		if brush_shape == BrushShape.RECTANGLE:
			_rectangle_current = cell
			queue_redraw()
		elif brush_shape == BrushShape.BRUSH:
			_request_cells([cell], false)


func _add_calibration_point(view_position: Vector2) -> void:
	_calibration_points.append(
		GridTransformService.view_to_image(view_position, pan, zoom)
	)
	if _calibration_points.size() == 3:
		var origin := _calibration_points[0]
		var axis_x := _calibration_points[1] - origin
		var axis_y := _calibration_points[2] - origin
		if GridTransformService.is_invertible(axis_x, axis_y):
			calibration_requested.emit(origin, axis_x, axis_y)
			calibration_active = false
		else:
			_calibration_points.clear()
	queue_redraw()


func _try_begin_transform_drag(view_position: Vector2) -> bool:
	if arena == null or bool(layer_locks.get("calibration", false)):
		return false
	var allow_legacy_handles := show_technical or active_tool == Tool.SELECT
	if active_tool != Tool.TRANSFORM_GRID and not allow_legacy_handles:
		return false
	var positions := _transform_handle_screen_positions()
	var priority := [
		TransformHandle.PIVOT, TransformHandle.ROTATE, TransformHandle.SCALE,
		TransformHandle.AXIS_X, TransformHandle.AXIS_Y,
	]
	for handle in priority:
		if positions.has(handle) and (positions[handle] as Vector2).distance_to(view_position) <= 13.0:
			return _begin_transform_handle(handle, view_position)
	if active_tool == Tool.TRANSFORM_GRID and _cell_at(view_position) != INVALID_CELL:
		return _begin_transform_handle(TransformHandle.BODY, view_position)
	return false


func _begin_transform_handle(handle: int, view_position: Vector2) -> bool:
	if handle == TransformHandle.BODY and lock_translation:
		return false
	if handle == TransformHandle.AXIS_X and lock_axis_x:
		return false
	if handle == TransformHandle.AXIS_Y and lock_axis_y:
		return false
	if handle == TransformHandle.ROTATE and lock_rotation:
		return false
	if handle == TransformHandle.SCALE and lock_scale:
		return false
	_drag_handle = handle
	_drag_snapshot = GridTransformSnapshot.from_arena(arena)
	_drag_origin = arena.grid_origin
	_drag_axis_x = arena.axis_x
	_drag_axis_y = arena.axis_y
	_drag_start_screen = view_position
	_drag_pivot = _current_pivot()
	var pivot_screen := GridTransformService.image_to_view(_drag_pivot, pan, zoom)
	_drag_start_angle = (view_position - pivot_screen).angle()
	_drag_start_distance = maxf(view_position.distance_to(pivot_screen), 0.001)
	_drag_changed = false
	_live_transform_text = _transform_action_name(handle)
	stroke_started.emit(_transform_action_name(handle))
	return true


func _update_transform_drag(event: InputEventMouseMotion) -> void:
	if _drag_snapshot == null:
		return
	var use_snap := snap_enabled != event.ctrl_pressed
	var fine := fine_factor if event.shift_pressed else 1.0
	var pointer_image := GridTransformService.view_to_image(event.position, pan, zoom)
	var candidate := _drag_snapshot.copy()
	match _drag_handle:
		TransformHandle.BODY:
			var delta := GridTransformService.image_native_delta_from_screen_delta(
				event.position - _drag_start_screen, Vector2.ONE, zoom
			) * fine
			candidate = GridTransformService.translate(_drag_snapshot, delta)
			if use_snap:
				candidate.origin = GridTransformService.snap_position(candidate.origin, position_snap)
			_live_transform_text = "Deplacement  %+0.2f, %+0.2f px" % [delta.x, delta.y]
		TransformHandle.AXIS_X:
			var target_x := _drag_snapshot.origin \
				+ (pointer_image - _drag_snapshot.origin) * fine \
				+ _drag_snapshot.axis_x * (1.0 - fine)
			candidate = GridTransformService.transform_axis_x_from_handle(
				_drag_snapshot, target_x, preserve_axis_length
			)
			if use_snap:
				candidate.axis_x = GridTransformService.snap_position(candidate.axis_x, 0.1)
			if mirror_axes:
				var bisector_x := (_drag_snapshot.axis_x + _drag_snapshot.axis_y).normalized()
				candidate.axis_y = GridTransformService.mirror_axis_across_bisector(
					candidate.axis_x, bisector_x
				)
			_live_transform_text = "Axe droit  %.2f px  %.2f deg" % [
				candidate.axis_x.length(), rad_to_deg(candidate.axis_x.angle())
			]
		TransformHandle.AXIS_Y:
			var target_y := _drag_snapshot.origin \
				+ (pointer_image - _drag_snapshot.origin) * fine \
				+ _drag_snapshot.axis_y * (1.0 - fine)
			candidate = GridTransformService.transform_axis_y_from_handle(
				_drag_snapshot, target_y, preserve_axis_length
			)
			if use_snap:
				candidate.axis_y = GridTransformService.snap_position(candidate.axis_y, 0.1)
			if mirror_axes:
				var bisector_y := (_drag_snapshot.axis_x + _drag_snapshot.axis_y).normalized()
				candidate.axis_x = GridTransformService.mirror_axis_across_bisector(
					candidate.axis_y, bisector_y
				)
			_live_transform_text = "Axe gauche  %.2f px  %.2f deg" % [
				candidate.axis_y.length(), rad_to_deg(candidate.axis_y.angle())
			]
		TransformHandle.ROTATE:
			var pivot_screen := GridTransformService.image_to_view(_drag_pivot, pan, zoom)
			var angle := ((event.position - pivot_screen).angle() - _drag_start_angle) * fine
			if use_snap:
				angle = GridTransformService.snap_angle(angle, deg_to_rad(angle_snap_degrees))
			candidate = GridTransformService.rotate_around(_drag_snapshot, _drag_pivot, angle)
			_live_transform_text = "Rotation  %+0.2f deg" % rad_to_deg(angle)
		TransformHandle.SCALE:
			var pivot_screen := GridTransformService.image_to_view(_drag_pivot, pan, zoom)
			var factor := event.position.distance_to(pivot_screen) / _drag_start_distance
			factor = 1.0 + (factor - 1.0) * fine
			if use_snap:
				factor = GridTransformService.snap_scale(factor, scale_snap)
			candidate = GridTransformService.scale_around(_drag_snapshot, _drag_pivot, factor)
			_live_transform_text = "Echelle  %0.2f %%" % (factor * 100.0)
		TransformHandle.PIVOT:
			_custom_pivot = pointer_image
			_custom_pivot_enabled = true
			_drag_changed = _custom_pivot.distance_to(_drag_pivot) > 0.00001
			_live_transform_text = "Pivot  %.2f, %.2f" % [_custom_pivot.x, _custom_pivot.y]
			return
	var validation := GridTransformService.validate_snapshot(
		candidate, GridTransformService.determinant(_drag_snapshot.axis_x, _drag_snapshot.axis_y)
	)
	if not bool(validation.get("ok", false)):
		_live_transform_text = "Transformation refusee : %s" % validation.get("error", "invalide")
		return
	_drag_changed = not candidate.is_equal_to(_drag_snapshot)
	calibration_preview_requested.emit(candidate.origin, candidate.axis_x, candidate.axis_y)


func _transform_action_name(handle: int) -> String:
	return {
		TransformHandle.BODY: "Deplacer la grille",
		TransformHandle.AXIS_X: "Modifier l'inclinaison droite",
		TransformHandle.AXIS_Y: "Modifier l'inclinaison gauche",
		TransformHandle.ROTATE: "Faire pivoter la grille",
		TransformHandle.SCALE: "Redimensionner la grille",
		TransformHandle.PIVOT: "Deplacer le pivot",
		TransformHandle.ANCHOR: "Deplacer une ancre de calibration",
	}.get(handle, "Transformer la grille")


func _handle_anchor_press(view_position: Vector2, button_index: int) -> bool:
	var hit := _anchor_at(view_position)
	if button_index == MOUSE_BUTTON_RIGHT:
		if hit < 0:
			return false
		stroke_started.emit("Supprimer une ancre de calibration")
		var cells := arena.calibration_cells.duplicate()
		var pixels := arena.calibration_pixels.duplicate()
		cells.remove_at(hit)
		pixels.remove_at(hit)
		anchors_preview_requested.emit(cells, pixels)
		stroke_finished.emit("Supprimer une ancre de calibration")
		_selected_anchor_index = -1
		return true
	if hit >= 0:
		_drag_handle = TransformHandle.ANCHOR
		_anchor_drag_index = hit
		_selected_anchor_index = hit
		_drag_changed = false
		_live_transform_text = "Deplacer l'ancre %d" % (hit + 1)
		stroke_started.emit("Deplacer une ancre de calibration")
		return true
	var cell := _cell_at(view_position)
	if cell == INVALID_CELL or arena.calibration_cells.has(cell):
		_live_transform_text = "Ancre refusee : cellule invalide ou deja utilisee"
		queue_redraw()
		return true
	stroke_started.emit("Ajouter une ancre de calibration")
	var cells := arena.calibration_cells.duplicate()
	var pixels := arena.calibration_pixels.duplicate()
	cells.append(cell)
	pixels.append(GridTransformService.view_to_image(view_position, pan, zoom))
	anchors_preview_requested.emit(cells, pixels)
	_selected_anchor_index = cells.size() - 1
	stroke_finished.emit("Ajouter une ancre de calibration")
	return true


func _update_anchor_drag(view_position: Vector2) -> void:
	if _anchor_drag_index < 0 or _anchor_drag_index >= arena.calibration_pixels.size():
		return
	var pixels := arena.calibration_pixels.duplicate()
	var next_position := GridTransformService.view_to_image(view_position, pan, zoom)
	if not GridTransformService.is_vector_finite(next_position):
		return
	_drag_changed = pixels[_anchor_drag_index].distance_to(next_position) > 0.00001
	pixels[_anchor_drag_index] = next_position
	anchors_preview_requested.emit(arena.calibration_cells.duplicate(), pixels)
	_live_transform_text = "Ancre %d  %.2f, %.2f px" % [
		_anchor_drag_index + 1, next_position.x, next_position.y
	]


func _anchor_at(view_position: Vector2) -> int:
	for index in range(arena.calibration_pixels.size()):
		var screen := GridTransformService.image_to_view(
			arena.calibration_pixels[index], pan, zoom
		)
		if screen.distance_to(view_position) <= 11.0:
			return index
	return -1


func _current_pivot() -> Vector2:
	return _custom_pivot if _custom_pivot_enabled else GridTransformService.logical_grid_center(
		GridTransformSnapshot.from_arena(arena), arena.grid_size
	)


func _transform_handle_screen_positions() -> Dictionary:
	if arena == null:
		return {}
	var snapshot := GridTransformSnapshot.from_arena(arena)
	var center := GridTransformService.logical_grid_center(snapshot, arena.grid_size)
	var center_screen := GridTransformService.image_to_view(center, pan, zoom)
	var far_corner := snapshot.origin \
		+ (float(arena.grid_size.x) - 0.5) * snapshot.axis_x \
		+ (float(arena.grid_size.y) - 0.5) * snapshot.axis_y
	return {
		TransformHandle.AXIS_X: GridTransformService.image_to_view(snapshot.origin + snapshot.axis_x, pan, zoom),
		TransformHandle.AXIS_Y: GridTransformService.image_to_view(snapshot.origin + snapshot.axis_y, pan, zoom),
		TransformHandle.ROTATE: center_screen + Vector2(0.0, -62.0),
		TransformHandle.SCALE: GridTransformService.image_to_view(far_corner, pan, zoom),
		TransformHandle.PIVOT: GridTransformService.image_to_view(_current_pivot(), pan, zoom),
	}


func _handle_key_input(event: InputEventKey) -> void:
	if not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE and cancel_active_gesture():
		accept_event()
		return
	if active_tool != Tool.TRANSFORM_GRID or is_transforming() or lock_translation:
		return
	var direction := Vector2.ZERO
	match event.keycode:
		KEY_LEFT: direction = Vector2.LEFT
		KEY_RIGHT: direction = Vector2.RIGHT
		KEY_UP: direction = Vector2.UP
		KEY_DOWN: direction = Vector2.DOWN
		_: return
	var before := GridTransformSnapshot.from_arena(arena)
	var amount := fine_factor if event.shift_pressed else 1.0
	var after := GridTransformService.translate(before, direction * amount)
	stroke_started.emit("Deplacer la grille au clavier")
	calibration_preview_requested.emit(after.origin, after.axis_x, after.axis_y)
	stroke_finished.emit("Deplacer la grille au clavier")
	accept_event()


func _cell_at(view_position: Vector2) -> Vector2i:
	return GridTransformService.view_to_cell(
		view_position, pan, zoom, arena.grid_origin, arena.axis_x, arena.axis_y,
		arena.grid_size
	)


func _request_cells(cells: Array[Vector2i], erase: bool) -> void:
	var fresh: Array[Vector2i] = []
	for cell in cells:
		if not _painted_this_stroke.has(cell):
			_painted_this_stroke[cell] = true
			fresh.append(cell)
	if not fresh.is_empty():
		cells_edit_requested.emit(fresh, erase)


func _rectangle_cells(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y in range(mini(from.y, to.y), maxi(from.y, to.y) + 1):
		for x in range(mini(from.x, to.x), maxi(from.x, to.x) + 1):
			result.append(Vector2i(x, y))
	return result


func _contiguous_cells(start: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var start_definition := arena.get_cell_definition(start)
	var start_defined := start_definition != null and start_definition.defined
	var visited := {start: true}
	var frontier: Array[Vector2i] = [start]
	while not frontier.is_empty():
		var current: Vector2i = frontier.pop_front()
		result.append(current)
		for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var neighbor: Vector2i = current + direction
			if visited.has(neighbor) or not arena.is_in_bounds(neighbor):
				continue
			var neighbor_definition := arena.get_cell_definition(neighbor)
			var neighbor_defined := neighbor_definition != null and neighbor_definition.defined
			if neighbor_defined != start_defined:
				continue
			visited[neighbor] = true
			frontier.append(neighbor)
	return result


func _action_name() -> String:
	return [
		"Selectionner des cases", "Deplacer la vue", "Ajouter des cases",
		"Retirer des cases", "Definir une bordure", "Peindre des obstacles",
		"Peindre un terrain", "Placer des spawns", "Verifier la map",
	][active_tool]


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("111722"), true)
	if arena == null:
		draw_string(
			ThemeDB.fallback_font, size * 0.5 - Vector2(150, 0),
			"Ouvrez ou creez une arene", HORIZONTAL_ALIGNMENT_CENTER, 300, 20,
			Color(0.75, 0.82, 0.9)
		)
		return
	draw_set_transform(pan, 0.0, Vector2.ONE * zoom)
	if _texture != null and bool(layer_visibility.get("background", true)):
		draw_texture_rect(
			_texture,
			Rect2(arena.image_offset, Vector2(arena.source_image_size) * arena.image_scale),
			false,
			Color(1.0, 1.0, 1.0, background_opacity)
		)
	if bool(layer_visibility.get("gameplay", true)):
		_draw_cells()
	_draw_overlays()
	if bool(layer_visibility.get("spawns", true)):
		_draw_spawns()
	if bool(layer_visibility.get("calibration", true)):
		_draw_saved_grid_comparison()
		_draw_calibration()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if bool(layer_visibility.get("calibration", true)):
		_draw_transform_gizmo_screen()
	_draw_hud()


func _draw_cells() -> void:
	for y in range(arena.grid_size.y):
		for x in range(arena.grid_size.x):
			var cell := Vector2i(x, y)
			var definition := arena.get_cell_definition(cell)
			var polygon := GridTransformService.cell_polygon(
				cell, arena.grid_origin, arena.axis_x, arena.axis_y
			)
			if definition != null and definition.defined:
				var color: Color = COLORS.playable
				if definition.border:
					color = COLORS.border
				elif not definition.playable:
					color = COLORS.non_playable
				elif arena.obstacle_at(cell) != null:
					color = COLORS.blocked
				draw_colored_polygon(polygon, color)
			if selected_cells.has(cell):
				draw_colored_polygon(polygon, COLORS.selected)
			if show_grid:
				_draw_outline(
					polygon, Color(GRID_COLOR, GRID_COLOR.a * grid_opacity), 1.0 / zoom
				)
	if _rectangle_start != INVALID_CELL and _rectangle_current != INVALID_CELL:
		for cell in _rectangle_cells(_rectangle_start, _rectangle_current):
			draw_colored_polygon(
				GridTransformService.cell_polygon(
					cell, arena.grid_origin, arena.axis_x, arena.axis_y
				),
				Color(1.0, 0.75, 0.2, 0.24)
			)
	if _hovered != INVALID_CELL:
		_draw_outline(
			GridTransformService.cell_polygon(
				_hovered, arena.grid_origin, arena.axis_x, arena.axis_y
			),
			Color.WHITE,
			2.0 / zoom
		)


func _draw_overlays() -> void:
	for cell in reachable_cells:
		draw_colored_polygon(_polygon(cell), COLORS.reachable)
	for cell in path_cells:
		draw_colored_polygon(_polygon(cell), COLORS.path)
	var line_color: Color = COLORS.line_blocked if line_blocked else COLORS.line_clear
	for cell in line_cells:
		draw_colored_polygon(_polygon(cell), line_color)
	if first_blocker != INVALID_CELL:
		_draw_outline(_polygon(first_blocker), Color.WHITE, 4.0 / zoom)


func _draw_spawns() -> void:
	if not show_spawns:
		return
	for spawn in arena.spawns:
		if spawn == null:
			continue
		var center := GridTransformService.cell_to_position(
			spawn.cell, arena.grid_origin, arena.axis_x, arena.axis_y
		)
		var color := Color(0.22, 0.68, 1.0, 0.96) if spawn.is_hero() \
			else Color(1.0, 0.29, 0.20, 0.96)
		draw_circle(center, 8.0 / sqrt(zoom), color)
		draw_string(
			ThemeDB.fallback_font, center + Vector2(10, -7) / sqrt(zoom),
			spawn.display_label(), HORIZONTAL_ALIGNMENT_LEFT, -1,
			maxi(8, int(11.0 / sqrt(zoom))), Color.WHITE
		)


func _draw_calibration() -> void:
	var origin := arena.grid_origin
	draw_line(origin, origin + arena.axis_x, Color(0.16, 0.95, 0.86, 0.9), 2.0 / zoom)
	draw_line(origin, origin + arena.axis_y, Color(1.0, 0.30, 0.78, 0.9), 2.0 / zoom)
	for index in range(mini(arena.calibration_cells.size(), arena.calibration_pixels.size())):
		var measured: Vector2 = arena.calibration_pixels[index]
		var predicted := GridTransformService.cell_to_position(
			arena.calibration_cells[index], arena.grid_origin, arena.axis_x, arena.axis_y
		)
		draw_line(predicted, measured, Color(1.0, 0.25, 0.18, 0.9), 2.0 / zoom)
		draw_circle(
			measured, (6.0 if index == _selected_anchor_index else 4.0) / zoom,
			Color(1.0, 0.82, 0.2) if index == _selected_anchor_index else Color.WHITE
		)
		if show_technical:
			draw_string(
				ThemeDB.fallback_font, measured + Vector2(6.0, -5.0) / zoom,
				"%.2f px" % predicted.distance_to(measured),
				HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(8, int(10.0 / zoom)), Color.WHITE
			)
	for point in _calibration_points:
		draw_circle(point, 6.0 / zoom, Color.WHITE)


func _draw_saved_grid_comparison() -> void:
	if arena == null:
		return
	if _drag_snapshot != null and _drag_handle != TransformHandle.PIVOT:
		_draw_snapshot_grid(_drag_snapshot, Color(0.82, 0.90, 1.0, 0.35))
	if not show_saved_comparison or _saved_transform == null:
		return
	_draw_snapshot_grid(_saved_transform, Color(1.0, 0.76, 0.18, 0.42))


func _draw_snapshot_grid(snapshot: GridTransformSnapshot, color: Color) -> void:
	for y in range(arena.grid_size.y):
		for x in range(arena.grid_size.x):
			_draw_outline(
				GridTransformService.cell_polygon(
					Vector2i(x, y), snapshot.origin,
					snapshot.axis_x, snapshot.axis_y
				),
				color, 1.0 / zoom
			)


func _draw_transform_gizmo_screen() -> void:
	if arena == null or active_tool != Tool.TRANSFORM_GRID:
		return
	var snapshot := GridTransformSnapshot.from_arena(arena)
	var corners := [
		snapshot.origin - 0.5 * snapshot.axis_x - 0.5 * snapshot.axis_y,
		snapshot.origin + (float(arena.grid_size.x) - 0.5) * snapshot.axis_x - 0.5 * snapshot.axis_y,
		snapshot.origin + (float(arena.grid_size.x) - 0.5) * snapshot.axis_x \
			+ (float(arena.grid_size.y) - 0.5) * snapshot.axis_y,
		snapshot.origin - 0.5 * snapshot.axis_x \
			+ (float(arena.grid_size.y) - 0.5) * snapshot.axis_y,
	]
	var outline := PackedVector2Array()
	for point in corners:
		outline.append(GridTransformService.image_to_view(point, pan, zoom))
	outline.append(outline[0])
	draw_polyline(outline, Color(0.35, 0.88, 1.0, 0.9), 2.0, true)
	var positions := _transform_handle_screen_positions()
	var colors := {
		TransformHandle.AXIS_X: Color(0.16, 0.95, 0.86),
		TransformHandle.AXIS_Y: Color(1.0, 0.30, 0.78),
		TransformHandle.ROTATE: Color(0.55, 0.80, 1.0),
		TransformHandle.SCALE: Color(0.35, 1.0, 0.52),
		TransformHandle.PIVOT: Color(1.0, 0.85, 0.18),
	}
	var labels := {
		TransformHandle.AXIS_X: "Inclinaison droite",
		TransformHandle.AXIS_Y: "Inclinaison gauche",
		TransformHandle.ROTATE: "Rotation",
		TransformHandle.SCALE: "Echelle",
		TransformHandle.PIVOT: "Pivot",
	}
	for handle in positions:
		var handle_position: Vector2 = positions[handle]
		var color: Color = colors.get(handle, Color.WHITE)
		if int(handle) == TransformHandle.ROTATE:
			draw_arc(handle_position, 10.0, 0.2, TAU - 0.4, 24, color, 3.0, true)
		elif int(handle) == TransformHandle.SCALE:
			draw_rect(Rect2(handle_position - Vector2(7, 7), Vector2(14, 14)), color, true)
		elif int(handle) == TransformHandle.PIVOT:
			draw_circle(handle_position, 7.0, Color(0.08, 0.11, 0.16))
			draw_line(handle_position - Vector2(10, 0), handle_position + Vector2(10, 0), color, 2.0)
			draw_line(handle_position - Vector2(0, 10), handle_position + Vector2(0, 10), color, 2.0)
		else:
			draw_circle(handle_position, 8.0, color)
		if show_technical or is_transforming():
			draw_string(
				ThemeDB.fallback_font, handle_position + Vector2(12, -9),
				str(labels.get(handle, "")), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE
			)


func _draw_hud() -> void:
	var coordinate_text := "Cellule : —"
	if _hovered != INVALID_CELL:
		coordinate_text = "Cellule : %d, %d" % [_hovered.x, _hovered.y]
	draw_string(
		ThemeDB.fallback_font, Vector2(14, size.y - 14),
		"%s    Zoom : %d %%" % [coordinate_text, roundi(zoom * 100.0)],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.92, 0.95, 1.0)
	)
	if active_tool in [Tool.TRANSFORM_GRID, Tool.CALIBRATION_ANCHORS]:
		var snap_text := "Aimantation active" if snap_enabled else "Aimantation inactive"
		var text := _live_transform_text if not _live_transform_text.is_empty() \
			else "Glissez la grille ou une poignee  |  Shift : fin  |  Ctrl : inverse %s" % snap_text
		var width := minf(size.x - 36.0, 720.0)
		draw_rect(Rect2(18, 18, width, 40), Color(0.02, 0.06, 0.11, 0.90), true)
		draw_string(
			ThemeDB.fallback_font, Vector2(32, 44), text,
			HORIZONTAL_ALIGNMENT_LEFT, width - 28.0, 14, Color(0.88, 0.95, 1.0)
		)
	if calibration_active:
		var instructions: String = [
			"1/3 — Cliquez le centre d'une case de reference",
			"2/3 — Cliquez la voisine en bas a droite",
			"3/3 — Cliquez la voisine en bas a gauche",
		][_calibration_points.size()]
		draw_rect(Rect2(18, 18, minf(size.x - 36, 520), 42), Color(0.02, 0.06, 0.11, 0.92), true)
		draw_string(
			ThemeDB.fallback_font, Vector2(34, 45), instructions,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(1.0, 0.88, 0.3)
		)


func _polygon(cell: Vector2i) -> PackedVector2Array:
	return GridTransformService.cell_polygon(
		cell, arena.grid_origin, arena.axis_x, arena.axis_y
	)


func _draw_outline(polygon: PackedVector2Array, color: Color, width: float) -> void:
	var closed := PackedVector2Array(polygon)
	if not polygon.is_empty():
		closed.append(polygon[0])
		draw_polyline(closed, color, width, true)
