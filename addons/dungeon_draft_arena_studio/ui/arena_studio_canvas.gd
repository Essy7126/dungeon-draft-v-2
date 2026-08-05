@tool
class_name ArenaStudioCanvas
extends Control

signal stroke_started(action_name: String)
signal cells_edit_requested(cells: Array[Vector2i], erase: bool)
signal stroke_finished(action_name: String)
signal calibration_requested(origin: Vector2, axis_x: Vector2, axis_y: Vector2)
signal calibration_preview_requested(origin: Vector2, axis_x: Vector2, axis_y: Vector2)
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
var calibration_active := false
var verification_kind := &"path"
var selected_cells: Array[Vector2i] = []
var reachable_cells: Array[Vector2i] = []
var path_cells: Array[Vector2i] = []
var line_cells: Array[Vector2i] = []
var line_blocked := false
var first_blocker := INVALID_CELL

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


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	resized.connect(queue_redraw)


func set_arena(value: ArenaDefinition) -> void:
	arena = value
	_texture = null
	selected_cells.clear()
	reachable_cells.clear()
	path_cells.clear()
	line_cells.clear()
	_hovered = INVALID_CELL
	if arena != null and ResourceLoader.exists(arena.background_path):
		_texture = load(arena.background_path) as Texture2D
	queue_redraw()
	call_deferred("fit_to_image")


func set_tool(value: int) -> void:
	active_tool = clampi(value, Tool.SELECT, Tool.VERIFY)
	calibration_active = false
	queue_redraw()


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
	if event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event)


func _handle_mouse_button(event: InputEventMouseButton) -> void:
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
		if event.button_index == MOUSE_BUTTON_LEFT and _try_begin_handle_drag(event.position):
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
		if _drag_handle >= 0:
			_drag_handle = -1
			stroke_finished.emit("Ajuster la calibration")
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
	if _drag_handle >= 0:
		var image_position := GridTransformService.view_to_image(event.position, pan, zoom)
		var origin := _drag_origin
		var axis_x := _drag_axis_x
		var axis_y := _drag_axis_y
		match _drag_handle:
			0:
				origin = image_position
			1:
				axis_x = image_position - origin
			2:
				axis_y = image_position - origin
		calibration_preview_requested.emit(origin, axis_x, axis_y)
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


func _try_begin_handle_drag(view_position: Vector2) -> bool:
	if arena == null or (not show_technical and active_tool != Tool.SELECT):
		return false
	var handles := [
		arena.grid_origin,
		arena.grid_origin + arena.axis_x,
		arena.grid_origin + arena.axis_y,
	]
	for index in range(handles.size()):
		var position := GridTransformService.image_to_view(handles[index], pan, zoom)
		if position.distance_to(view_position) <= 11.0:
			_drag_handle = index
			_drag_origin = arena.grid_origin
			_drag_axis_x = arena.axis_x
			_drag_axis_y = arena.axis_y
			stroke_started.emit("Ajuster la calibration")
			return true
	return false


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
	if _texture != null:
		draw_texture_rect(
			_texture,
			Rect2(arena.image_offset, Vector2(arena.source_image_size) * arena.image_scale),
			false
		)
	_draw_cells()
	_draw_overlays()
	_draw_spawns()
	_draw_calibration()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
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
				_draw_outline(polygon, GRID_COLOR, 1.0 / zoom)
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
	var handles := [
		[arena.grid_origin, Color(1.0, 0.85, 0.18), "Origine"],
		[arena.grid_origin + arena.axis_x, Color(0.16, 0.95, 0.86), "Droite"],
		[arena.grid_origin + arena.axis_y, Color(1.0, 0.30, 0.78), "Gauche"],
	]
	for handle in handles:
		draw_circle(handle[0], 7.0 / zoom, handle[1])
		if show_technical:
			draw_string(
				ThemeDB.fallback_font, handle[0] + Vector2(9, -8) / zoom,
				handle[2], HORIZONTAL_ALIGNMENT_LEFT, -1, int(11.0 / zoom),
				Color.WHITE
			)
	for point in _calibration_points:
		draw_circle(point, 6.0 / zoom, Color.WHITE)


func _draw_hud() -> void:
	var coordinate_text := "Cellule : —"
	if _hovered != INVALID_CELL:
		coordinate_text = "Cellule : %d, %d" % [_hovered.x, _hovered.y]
	draw_string(
		ThemeDB.fallback_font, Vector2(14, size.y - 14),
		"%s    Zoom : %d %%" % [coordinate_text, roundi(zoom * 100.0)],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.92, 0.95, 1.0)
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
