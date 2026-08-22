@tool
class_name GridAffineGizmo
extends Control

## Overlay purement visuel et de hit-test. Les transformations restent dans
## GridTransformService et la transaction dans ArenaStudioCanvas.

enum GridGizmoHandle {
	NONE = -1,
	TRANSLATE,
	AXIS_X,
	AXIS_Y,
	ROTATE,
	SCALE,
	ANGLE,
	PIVOT,
}

const HANDLE_CELL_DISTANCE := 2.5
const HANDLE_RADIUS := 9.0
const HIT_RADIUS := 14.0
const ANGLE_RADIUS := 58.0
const ROTATION_OFFSET := 68.0
const COLORS := {
	"outline": Color(0.28, 0.86, 1.0, 0.96),
	"axis_x": Color(0.12, 0.92, 0.96),
	"axis_y": Color(0.98, 0.28, 0.78),
	"rotation": Color(1.0, 0.58, 0.16),
	"scale": Color(0.34, 1.0, 0.48),
	"pivot": Color(1.0, 0.84, 0.14),
	"translate": Color(0.88, 0.95, 1.0),
	"angle": Color(0.72, 0.36, 1.0),
	"ghost": Color(0.72, 0.78, 0.86, 0.46),
}

var snapshot: GridTransformSnapshot = null
var ghost_snapshot: GridTransformSnapshot = null
var logical_size := Vector2i.ZERO
var pivot := Vector2.ZERO
var image_offset := Vector2.ZERO
var image_scale := Vector2.ONE
var pan := Vector2.ZERO
var zoom := 1.0
var angle_mode := GridTransformService.AngleMode.SYMMETRIC
var hovered_handle := GridGizmoHandle.NONE
var active_handle := GridGizmoHandle.NONE
var live_text := ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func configure(
		value: GridTransformSnapshot,
		value_size: Vector2i,
		value_pivot: Vector2,
		value_image_offset: Vector2,
		value_image_scale: Vector2,
		value_pan: Vector2,
		value_zoom: float,
		value_angle_mode: int,
		value_ghost: GridTransformSnapshot = null,
		value_active_handle := GridGizmoHandle.NONE,
		value_text := ""
	) -> void:
	snapshot = value.copy() if value != null else null
	logical_size = value_size
	pivot = value_pivot
	image_offset = value_image_offset
	image_scale = value_image_scale
	pan = value_pan
	zoom = value_zoom
	angle_mode = value_angle_mode
	ghost_snapshot = value_ghost.copy() if value_ghost != null else null
	active_handle = value_active_handle
	live_text = value_text
	queue_redraw()


func handle_positions() -> Dictionary:
	if snapshot == null:
		return {}
	var origin_screen := _to_screen(snapshot.origin)
	var center_screen := _to_screen(
		GridTransformService.logical_grid_center(snapshot, logical_size)
	)
	var far_corner := snapshot.origin \
		+ (float(logical_size.x) - 0.5) * snapshot.axis_x \
		+ (float(logical_size.y) - 0.5) * snapshot.axis_y
	var angle_direction := GridTransformService.interior_bisector(
		snapshot.axis_x, snapshot.axis_y
	)
	if angle_direction == Vector2.ZERO:
		angle_direction = snapshot.axis_y.normalized()
	var angle_screen_direction := (
		_to_screen(snapshot.origin + angle_direction) - origin_screen
	).normalized()
	return {
		GridGizmoHandle.AXIS_X: _to_screen(
			snapshot.origin + snapshot.axis_x * HANDLE_CELL_DISTANCE
		),
		GridGizmoHandle.AXIS_Y: _to_screen(
			snapshot.origin + snapshot.axis_y * HANDLE_CELL_DISTANCE
		),
		GridGizmoHandle.ROTATE: center_screen + Vector2(0.0, -ROTATION_OFFSET),
		GridGizmoHandle.SCALE: _to_screen(far_corner),
		GridGizmoHandle.ANGLE: origin_screen + angle_screen_direction * ANGLE_RADIUS,
		GridGizmoHandle.PIVOT: _to_screen(pivot),
	}


func hit_test(screen_position: Vector2) -> int:
	if snapshot == null:
		return GridGizmoHandle.NONE
	var positions := handle_positions()
	for handle in [
		GridGizmoHandle.PIVOT,
		GridGizmoHandle.ROTATE,
		GridGizmoHandle.ANGLE,
		GridGizmoHandle.SCALE,
		GridGizmoHandle.AXIS_X,
		GridGizmoHandle.AXIS_Y,
	]:
		if positions.has(handle) \
				and (positions[handle] as Vector2).distance_to(screen_position) <= HIT_RADIUS:
			return handle
	var polygon := screen_polygon(snapshot)
	if polygon.size() >= 3 and Geometry2D.is_point_in_polygon(screen_position, polygon):
		return GridGizmoHandle.TRANSLATE
	return GridGizmoHandle.NONE


func screen_polygon(value: GridTransformSnapshot) -> PackedVector2Array:
	if value == null or logical_size.x <= 0 or logical_size.y <= 0:
		return PackedVector2Array()
	return PackedVector2Array([
		_to_screen(value.origin - 0.5 * value.axis_x - 0.5 * value.axis_y),
		_to_screen(value.origin + (float(logical_size.x) - 0.5) * value.axis_x - 0.5 * value.axis_y),
		_to_screen(value.origin + (float(logical_size.x) - 0.5) * value.axis_x \
			+ (float(logical_size.y) - 0.5) * value.axis_y),
		_to_screen(value.origin - 0.5 * value.axis_x \
			+ (float(logical_size.y) - 0.5) * value.axis_y),
	])


func set_hovered_handle(value: int) -> void:
	if hovered_handle == value:
		return
	hovered_handle = value
	queue_redraw()


func _to_screen(value: Vector2) -> Vector2:
	return GridTransformService.image_native_to_screen(
		value, image_offset, image_scale, pan, zoom
	)


func _draw() -> void:
	if snapshot == null:
		return
	if ghost_snapshot != null:
		_draw_dashed_polygon(screen_polygon(ghost_snapshot), COLORS.ghost)
	var outline := screen_polygon(snapshot)
	if outline.size() >= 3:
		var closed := PackedVector2Array(outline)
		closed.append(outline[0])
		draw_polyline(closed, COLORS.outline, 2.0, true)
	var positions := handle_positions()
	var origin_screen := _to_screen(snapshot.origin)
	_draw_axis(origin_screen, positions.get(GridGizmoHandle.AXIS_X, origin_screen), COLORS.axis_x, "X")
	_draw_axis(origin_screen, positions.get(GridGizmoHandle.AXIS_Y, origin_screen), COLORS.axis_y, "Y")
	_draw_angle_arc(origin_screen)
	_draw_origin(origin_screen)
	for handle in [
		GridGizmoHandle.ROTATE,
		GridGizmoHandle.SCALE,
		GridGizmoHandle.ANGLE,
		GridGizmoHandle.PIVOT,
	]:
		if positions.has(handle):
			_draw_handle(handle, positions[handle])
	if not live_text.is_empty():
		var width := minf(size.x - 44.0, 620.0)
		draw_rect(Rect2(22, 18, width, 34), Color(0.02, 0.06, 0.11, 0.92), true)
		draw_string(
			ThemeDB.fallback_font, Vector2(34, 41), live_text,
			HORIZONTAL_ALIGNMENT_LEFT, width - 24.0, 13, Color(0.90, 0.96, 1.0)
		)


func _draw_axis(from: Vector2, to: Vector2, color: Color, label: String) -> void:
	var highlighted := (
		label == "X" and hovered_handle == GridGizmoHandle.AXIS_X
	) or (
		label == "Y" and hovered_handle == GridGizmoHandle.AXIS_Y
	)
	var width := 4.0 if highlighted else 3.0
	draw_line(from, to, color, width, true)
	var direction := (to - from).normalized()
	var normal := Vector2(-direction.y, direction.x)
	draw_colored_polygon(PackedVector2Array([
		to,
		to - direction * 15.0 + normal * 7.0,
		to - direction * 15.0 - normal * 7.0,
	]), color)
	draw_circle(to, HANDLE_RADIUS + (2.0 if highlighted else 0.0), color)
	draw_string(
		ThemeDB.fallback_font, to + direction * 13.0 + Vector2(3, -5), label,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 16, color
	)


func _draw_origin(position: Vector2) -> void:
	draw_circle(position, 8.0, Color(0.04, 0.08, 0.13, 0.95))
	draw_arc(position, 8.0, 0.0, TAU, 24, COLORS.translate, 2.5, true)
	draw_string(
		ThemeDB.fallback_font, position + Vector2(11, -10), "O",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, COLORS.translate
	)


func _draw_handle(handle: int, position: Vector2) -> void:
	var color: Color = {
		GridGizmoHandle.ROTATE: COLORS.rotation,
		GridGizmoHandle.SCALE: COLORS.scale,
		GridGizmoHandle.ANGLE: COLORS.angle,
		GridGizmoHandle.PIVOT: COLORS.pivot,
	}.get(handle, Color.WHITE)
	var highlighted := handle == hovered_handle or handle == active_handle
	var radius := HANDLE_RADIUS + (2.0 if highlighted else 0.0)
	match handle:
		GridGizmoHandle.ROTATE:
			draw_arc(position, radius, 0.25, TAU - 0.35, 28, color, 3.0, true)
			draw_string(ThemeDB.fallback_font, position + Vector2(13, 5), "Rotation", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, color)
		GridGizmoHandle.SCALE:
			draw_rect(Rect2(position - Vector2.ONE * radius, Vector2.ONE * radius * 2.0), color, true)
			draw_string(ThemeDB.fallback_font, position + Vector2(13, -8), "Échelle", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, color)
		GridGizmoHandle.ANGLE:
			draw_circle(position, radius, color)
			draw_circle(position, maxf(2.0, radius - 4.0), Color(0.10, 0.06, 0.16))
			draw_string(ThemeDB.fallback_font, position + Vector2(13, -8), "Angle", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, color)
		GridGizmoHandle.PIVOT:
			draw_circle(position, radius - 2.0, Color(0.06, 0.08, 0.12))
			draw_line(position - Vector2(radius, 0), position + Vector2(radius, 0), color, 2.5)
			draw_line(position - Vector2(0, radius), position + Vector2(0, radius), color, 2.5)
			draw_string(ThemeDB.fallback_font, position + Vector2(13, 18), "Pivot", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, color)


func _draw_angle_arc(origin_screen: Vector2) -> void:
	var direction_x := (_to_screen(snapshot.origin + snapshot.axis_x.normalized()) - origin_screen).normalized()
	var direction_y := (_to_screen(snapshot.origin + snapshot.axis_y.normalized()) - origin_screen).normalized()
	var start := direction_x.angle()
	var delta := wrapf(direction_y.angle() - start, -PI, PI)
	var previous := origin_screen + Vector2.from_angle(start) * ANGLE_RADIUS
	for index in range(1, 25):
		var angle := start + delta * float(index) / 24.0
		var next := origin_screen + Vector2.from_angle(angle) * ANGLE_RADIUS
		draw_line(previous, next, COLORS.angle, 2.0, true)
		previous = next


func _draw_dashed_polygon(polygon: PackedVector2Array, color: Color) -> void:
	if polygon.size() < 2:
		return
	for index in range(polygon.size()):
		_draw_dashed_line(polygon[index], polygon[(index + 1) % polygon.size()], color)


func _draw_dashed_line(from: Vector2, to: Vector2, color: Color) -> void:
	var distance := from.distance_to(to)
	if distance <= 0.0:
		return
	var direction := (to - from) / distance
	var cursor := 0.0
	while cursor < distance:
		var end := minf(cursor + 7.0, distance)
		draw_line(from + direction * cursor, from + direction * end, color, 1.5, true)
		cursor += 12.0
