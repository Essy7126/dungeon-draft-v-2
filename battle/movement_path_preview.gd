class_name MovementPathPreview
extends Node2D

## Fleche tactique affichee pendant le choix d'un deplacement. Le chemin reste
## fourni par Pathfinder ; ce noeud ne contient aucune regle de deplacement.

const PATH_COLOR := Color(1.0, 1.0, 1.0, 0.96)
const ORIGIN_COLOR := Color(1.0, 1.0, 1.0, 0.78)
const DISENGAGEMENT_COLOR := Color(1.0, 0.66, 0.18, 1.0)
const COST_TEXT_COLOR := Color(1.0, 1.0, 1.0, 1.0)
const COST_BACKGROUND_COLOR := Color(0.06, 0.07, 0.10, 0.92)
const DOT_SPACING := 12.0
const DOT_RADIUS := 2.7
const ORIGIN_RADIUS := 5.5
const DISENGAGEMENT_RADIUS := 8.0
const ORIGIN_CLEARANCE := 12.0
const ARROW_CLEARANCE := 15.3
const ARROW_LENGTH := 11.9
const ARROW_HALF_WIDTH := 5.95
const ARROW_CORE_WIDTH := 3.4
const COST_FONT_SIZE := 15
const COST_BADGE_OFFSET := Vector2(0.0, -34.0)
const COST_BADGE_PADDING := Vector2(7.0, 4.0)

var _grid_view: Node2D = null
var _path_cells: Array[Vector2i] = []
var _disengagement_cost := 0
var _disengagement_cells: Array[Vector2i] = []


func setup(grid_view: Node2D) -> void:
	_grid_view = grid_view
	clear_path()


func set_path(path: Array, cost_breakdown: Dictionary = {}) -> void:
	_path_cells.clear()
	for cell in path:
		if cell is Vector2i:
			_path_cells.append(cell)
	_disengagement_cost = int(cost_breakdown.get("disengagement", 0))
	_disengagement_cells.clear()
	for cell_value in cost_breakdown.get("disengagement_cells", []):
		if cell_value is Vector2i:
			_disengagement_cells.append(cell_value)
	visible = _grid_view != null and _path_cells.size() >= 2
	queue_redraw()


func clear_path() -> void:
	_path_cells.clear()
	_disengagement_cost = 0
	_disengagement_cells.clear()
	visible = false
	queue_redraw()


func get_path_cells() -> Array[Vector2i]:
	return _path_cells.duplicate()


func get_path_points() -> PackedVector2Array:
	var points := PackedVector2Array()
	if _grid_view == null or not _grid_view.has_method("grid_to_local"):
		return points
	for cell in _path_cells:
		points.append(_cell_to_local(cell))
	return points


func get_cost_label() -> String:
	if _disengagement_cost <= 0:
		return ""
	return "-%d PM" % _disengagement_cost


func get_disengagement_points() -> PackedVector2Array:
	var result := PackedVector2Array()
	if _grid_view == null or not _grid_view.has_method("grid_to_local"):
		return result
	for cell in _disengagement_cells:
		result.append(_cell_to_local(cell))
	return result


func _cell_to_local(cell: Vector2i) -> Vector2:
	var grid_local: Vector2 = _grid_view.grid_to_local(cell)
	return to_local(_grid_view.to_global(grid_local))


func _draw() -> void:
	var points := get_path_points()
	if points.size() < 2:
		return
	_draw_origin_marker(points[0])
	_draw_disengagement_markers()
	_draw_dotted_path(points)
	_draw_arrow_head(points)
	_draw_cost_badge(points[-1])


func _draw_origin_marker(center: Vector2) -> void:
	draw_arc(center, ORIGIN_RADIUS, 0.0, TAU, 32, ORIGIN_COLOR, 2.0, true)


func _draw_disengagement_markers() -> void:
	for center in get_disengagement_points():
		draw_arc(
			center,
			DISENGAGEMENT_RADIUS,
			0.0,
			TAU,
			32,
			DISENGAGEMENT_COLOR,
			2.4,
			true,
		)


func _draw_dotted_path(points: PackedVector2Array) -> void:
	for center in get_dot_centers(points):
		_draw_path_dot(center)


func _draw_path_dot(center: Vector2) -> void:
	draw_circle(center, DOT_RADIUS, PATH_COLOR, true, -1.0, true)


func _draw_arrow_head(points: PackedVector2Array) -> void:
	var arrow := get_arrow_points(points)
	if arrow.size() != 3:
		return
	_draw_rounded_polyline(arrow, PATH_COLOR, ARROW_CORE_WIDTH)


func _draw_cost_badge(destination: Vector2) -> void:
	var label := get_cost_label()
	if label.is_empty():
		return
	var font := ThemeDB.fallback_font
	var text_size := font.get_string_size(
		label,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		COST_FONT_SIZE,
	)
	var badge_size := text_size + COST_BADGE_PADDING * 2.0
	var badge_position := destination + COST_BADGE_OFFSET \
		- Vector2(badge_size.x * 0.5, badge_size.y)
	var badge_rect := Rect2(badge_position, badge_size)
	draw_rect(badge_rect, COST_BACKGROUND_COLOR, true)
	var baseline := badge_position + Vector2(
		COST_BADGE_PADDING.x,
		COST_BADGE_PADDING.y + font.get_ascent(COST_FONT_SIZE),
	)
	draw_string(
		font,
		baseline,
		label,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		COST_FONT_SIZE,
		COST_TEXT_COLOR,
	)


func get_dot_centers(
		points: PackedVector2Array = PackedVector2Array()
	) -> PackedVector2Array:
	var source := points if not points.is_empty() else get_path_points()
	var result := PackedVector2Array()
	var total_length := _polyline_length(source)
	var last_distance := total_length - ARROW_CLEARANCE
	if source.size() < 2 or last_distance < ORIGIN_CLEARANCE:
		return result
	var distance := ORIGIN_CLEARANCE
	while distance <= last_distance + 0.001:
		result.append(_point_at_distance(source, distance))
		distance += DOT_SPACING
	return result


func get_arrow_points(
		points: PackedVector2Array = PackedVector2Array()
	) -> PackedVector2Array:
	var source := points if not points.is_empty() else get_path_points()
	if source.size() < 2:
		return PackedVector2Array()
	var destination := source[-1]
	var direction := (destination - source[-2]).normalized()
	if direction == Vector2.ZERO:
		return PackedVector2Array()
	var perpendicular := direction.orthogonal()
	var wing_center := destination - direction * ARROW_LENGTH
	return PackedVector2Array([
		wing_center + perpendicular * ARROW_HALF_WIDTH,
		destination,
		wing_center - perpendicular * ARROW_HALF_WIDTH,
	])


func _draw_rounded_polyline(
		points: PackedVector2Array,
		color: Color,
		width: float
	) -> void:
	draw_polyline(points, color, width, true)
	for point in points:
		draw_circle(point, width * 0.5, color, true, -1.0, true)


func _polyline_length(points: PackedVector2Array) -> float:
	var result := 0.0
	for index in range(points.size() - 1):
		result += points[index].distance_to(points[index + 1])
	return result


func _point_at_distance(points: PackedVector2Array, distance: float) -> Vector2:
	var remaining := maxf(distance, 0.0)
	for index in range(points.size() - 1):
		var from := points[index]
		var to := points[index + 1]
		var segment_length := from.distance_to(to)
		if segment_length <= 0.001:
			continue
		if remaining <= segment_length:
			return from.lerp(to, remaining / segment_length)
		remaining -= segment_length
	return points[-1] if not points.is_empty() else Vector2.ZERO
