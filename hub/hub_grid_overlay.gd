class_name HubGridOverlay
extends Node2D

## Rendu debug et facade de projection de la grille du hub.
## Le footprint reste en 2:1 ; il est double par rapport au combat afin de
## correspondre au decor de 2048 px sans changer les coordonnees logiques.

signal cell_hovered(
	cell: Vector2i,
	screen_position: Vector2,
	world_position: Vector2,
	snapped_world_position: Vector2
)
const IsoProjectionScript = preload("res://battle/iso/iso_projection.gd")
const INVALID_CELL := Vector2i(-1, -1)

const WALKABLE_FILL := Color(0.12, 0.88, 0.44, 0.18)
const WALKABLE_LINE := Color(0.32, 1.0, 0.62, 0.66)
const BLOCKED_FILL := Color(0.94, 0.16, 0.12, 0.25)
const BLOCKED_LINE := Color(1.0, 0.34, 0.28, 0.72)
const COORDINATE_COLOR := Color(0.96, 0.98, 1.0, 0.92)
const HOVER_FILL := Color(0.18, 0.78, 1.0, 0.48)
const HOVER_LINE := Color(0.72, 0.96, 1.0, 1.0)

@export var tile_size := Vector2(128.0, 64.0)
@export var grid_origin := Vector2(1024.0, 640.0)
@export var debug_visible := false
@export_range(8, 32, 1) var coordinate_font_size := 18

var navigation_grid: HubNavigationGrid = null
var _projection: IsoProjection = null
var _hovered_cell := INVALID_CELL
var _technical_markers: Array[HubTechnicalMarker] = []


func setup(grid: HubNavigationGrid) -> void:
	navigation_grid = grid
	_projection = IsoProjectionScript.new(tile_size.x, tile_size.y, grid_origin)
	queue_redraw()


func set_debug_visible(enabled: bool) -> void:
	debug_visible = enabled
	if not debug_visible:
		_hovered_cell = INVALID_CELL
	queue_redraw()


func set_technical_markers(markers: Array[HubTechnicalMarker]) -> void:
	_technical_markers = markers
	queue_redraw()


func cell_to_world(cell: Vector2i) -> Vector2:
	_ensure_projection()
	return _projection.grid_to_world(cell)


func world_to_cell(world_position: Vector2) -> Vector2i:
	_ensure_projection()
	return _projection.world_to_grid(world_position)


func screen_to_cell(screen_position: Vector2) -> Vector2i:
	var canvas_position := get_viewport().get_canvas_transform().affine_inverse() * screen_position
	return world_to_cell(to_local(canvas_position))


func get_cell_polygon(cell: Vector2i) -> PackedVector2Array:
	_ensure_projection()
	return _projection.get_cell_polygon(cell)


func get_hovered_cell() -> Vector2i:
	return _hovered_cell


func update_hover_at_world(
		world_position: Vector2,
		screen_position := Vector2.ZERO
	) -> Vector2i:
	var candidate := world_to_cell(world_position)
	if navigation_grid == null or not navigation_grid.is_valid(candidate):
		candidate = INVALID_CELL
	if candidate != _hovered_cell:
		_hovered_cell = candidate
		queue_redraw()
	var snapped := cell_to_world(candidate) if candidate != INVALID_CELL else Vector2.ZERO
	cell_hovered.emit(candidate, screen_position, world_position, snapped)
	return candidate


func _unhandled_input(event: InputEvent) -> void:
	if not debug_visible or navigation_grid == null:
		return
	if event is InputEventMouseMotion:
		_update_hover(event.position)


func _update_hover(screen_position: Vector2) -> void:
	var local_world := to_local(get_global_mouse_position())
	update_hover_at_world(local_world, screen_position)


func _ensure_projection() -> void:
	if _projection == null:
		_projection = IsoProjectionScript.new(tile_size.x, tile_size.y, grid_origin)


func _draw() -> void:
	if not debug_visible or navigation_grid == null:
		return
	var font := ThemeDB.fallback_font
	for x in range(navigation_grid.grid_size.x):
		for y in range(navigation_grid.grid_size.y):
			var cell := Vector2i(x, y)
			var polygon := get_cell_polygon(cell)
			var walkable := navigation_grid.is_walkable(cell)
			draw_colored_polygon(polygon, WALKABLE_FILL if walkable else BLOCKED_FILL)
			_draw_outline(polygon, WALKABLE_LINE if walkable else BLOCKED_LINE, 1.4)
			var label := "%d,%d" % [x, y]
			var center := cell_to_world(cell)
			draw_string(
				font,
				center + Vector2(-30.0, 5.0),
				label,
				HORIZONTAL_ALIGNMENT_CENTER,
				60.0,
				coordinate_font_size,
				COORDINATE_COLOR
			)

	for marker in _technical_markers:
		if not is_instance_valid(marker):
			continue
		var center := cell_to_world(marker.cell)
		draw_circle(center, 9.0, marker.debug_color)
		draw_circle(center, 12.0, marker.debug_color, false, 2.0, true)
		var marker_label := "%s (%d,%d)" % [marker.name, marker.cell.x, marker.cell.y]
		draw_string(
			font,
			center + Vector2(-100.0, -20.0),
			marker_label,
			HORIZONTAL_ALIGNMENT_CENTER,
			200.0,
			20,
			marker.debug_color
		)

	_draw_archivist_facing_guide()

	if navigation_grid.is_valid(_hovered_cell):
		var hovered_polygon := get_cell_polygon(_hovered_cell)
		draw_colored_polygon(hovered_polygon, HOVER_FILL)
		_draw_outline(hovered_polygon, HOVER_LINE, 3.0)


func _draw_outline(polygon: PackedVector2Array, color: Color, width: float) -> void:
	var closed := PackedVector2Array(polygon)
	closed.append(polygon[0])
	draw_polyline(closed, color, width, true)


func _draw_archivist_facing_guide() -> void:
	var archivist_cell := _find_marker(&"ArchivistCell")
	var look_target := _find_marker(&"ArchivistLookTarget")
	if archivist_cell == null or look_target == null:
		return
	var origin := cell_to_world(archivist_cell.cell)
	var target := cell_to_world(look_target.cell)
	var direction := origin.direction_to(target)
	draw_dashed_line(origin, target, look_target.debug_color, 4.0, 16.0, true)
	draw_line(
		target,
		target - direction.rotated(0.55) * 26.0,
		look_target.debug_color,
		4.0,
		true
	)
	draw_line(
		target,
		target - direction.rotated(-0.55) * 26.0,
		look_target.debug_color,
		4.0,
		true
	)


func _find_marker(marker_name: StringName) -> HubTechnicalMarker:
	for marker in _technical_markers:
		if is_instance_valid(marker) and marker.name == marker_name:
			return marker
	return null
