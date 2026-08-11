@tool
class_name PaintedGridView
extends Node2D

## Facade visuelle commune aux salles peintes. Elle expose le meme contrat que
## IsoGridView, mais delegue exclusivement la conversion affine a la ressource
## PaintedMapVisualData. GridData reste l'unique grille de gameplay.

signal cell_hovered(grid_pos: Vector2i)
signal cell_clicked(grid_pos: Vector2i)

const INVALID_CELL := Vector2i(-1, -1)
const GRID_LINE_COLOR := Color(0.72, 0.94, 1.0, 0.42)
const CENTER_COLOR := Color(1.0, 0.86, 0.2, 0.95)
const HOVER_FILL_COLOR := Color(0.35, 0.88, 1.0, 0.32)
const HOVER_LINE_COLOR := Color(0.48, 0.94, 1.0, 1.0)
const SELECTED_FILL_COLOR := Color(1.0, 0.70, 0.18, 0.36)
const SELECTED_LINE_COLOR := Color(1.0, 0.78, 0.28, 1.0)
const TYPE_COLORS := {
	GridData.CellType.NORMAL: Color(0.18, 0.55, 0.34, 0.28),
	GridData.CellType.WALL: Color(0.85, 0.25, 0.18, 0.58),
	GridData.CellType.HOLE: Color(0.06, 0.08, 0.13, 0.72),
	GridData.CellType.LAVA: Color(1.0, 0.25, 0.04, 0.52),
	GridData.CellType.ICE: Color(0.22, 0.76, 1.0, 0.46),
	GridData.CellType.SHADOW: Color(0.28, 0.16, 0.48, 0.5),
	GridData.CellType.RUNE: Color(0.72, 0.25, 0.92, 0.5),
}

@export var visual_data: PaintedMapVisualData:
	set(value):
		visual_data = value
		queue_redraw()
@export var room_layout: RoomGridLayout:
	set(value):
		room_layout = value
		queue_redraw()

@export_group("Rendu production")
@export var draw_base_cells := false
@export var draw_grid_lines := false
@export var draw_cell_centers := false
@export var draw_map_bounds := false

@export_group("Debug calibration")
@export var draw_logic_types := false
@export var draw_void_cells := false
@export var draw_coordinates := false
@export var draw_spawns := false
@export var draw_calibration := false

var grid: GridData = null
var hero_spawn_cells: Array[Vector2i] = []
var enemy_spawn_cells: Array[Vector2i] = []
var _hovered_cell := INVALID_CELL
var _selected_cell := INVALID_CELL
var _highlights: Dictionary = {}


func configure(
		map_visual_data: PaintedMapVisualData,
		layout: RoomGridLayout,
		hero_spawns: Array[Vector2i] = [],
		enemy_spawns: Array[Vector2i] = []
	) -> void:
	visual_data = map_visual_data
	room_layout = layout
	hero_spawn_cells = hero_spawns.duplicate()
	enemy_spawn_cells = enemy_spawns.duplicate()
	queue_redraw()


func setup(grid_data: GridData) -> void:
	if grid_data == null:
		push_error("PaintedGridView.setup() requiert le GridData commun.")
		return
	grid = grid_data
	_hovered_cell = INVALID_CELL
	_selected_cell = INVALID_CELL
	_highlights.clear()
	queue_redraw()


func set_render_options(
		base_cells: bool,
		grid_lines: bool,
		cell_centers: bool,
		map_bounds: bool
	) -> void:
	draw_base_cells = base_cells
	draw_grid_lines = grid_lines
	draw_cell_centers = cell_centers
	draw_map_bounds = map_bounds
	queue_redraw()


func set_debug_layers(
		logic_types: bool,
		void_cells: bool,
		coordinates: bool,
		spawns: bool,
		calibration: bool
	) -> void:
	draw_logic_types = logic_types
	draw_void_cells = void_cells
	draw_coordinates = coordinates
	draw_spawns = spawns
	draw_calibration = calibration
	queue_redraw()


func get_hovered_cell() -> Vector2i:
	return _hovered_cell


func get_selected_cell() -> Vector2i:
	return _selected_cell


func set_selected_cell(cell: Vector2i) -> void:
	if grid == null or not grid.is_terrain_interactable(cell):
		return
	_selected_cell = cell
	queue_redraw()


func clear_selection() -> void:
	_selected_cell = INVALID_CELL
	queue_redraw()


func highlight(cells: Array, color: Color) -> void:
	if grid == null:
		return
	for cell in cells:
		if cell is Vector2i and grid.is_terrain_interactable(cell):
			_highlights[cell] = color
	queue_redraw()


func clear_highlights() -> void:
	_highlights.clear()
	queue_redraw()


func grid_to_local(cell: Vector2i) -> Vector2:
	return visual_data.cell_to_display(cell) if visual_data != null else Vector2.ZERO


func grid_to_world(cell: Vector2i) -> Vector2:
	return grid_to_local(cell)


func local_to_grid(local_position: Vector2) -> Vector2i:
	return visual_data.display_to_cell(local_position) if visual_data != null else INVALID_CELL


func world_to_grid(local_position: Vector2) -> Vector2i:
	return local_to_grid(local_position)


func get_cell_polygon(cell: Vector2i) -> PackedVector2Array:
	return visual_data.cell_polygon_display(cell) \
		if visual_data != null else PackedVector2Array()


func get_map_bounds() -> Rect2:
	return visual_data.image_rect() if visual_data != null else Rect2()


func get_logical_bounds() -> Rect2:
	return visual_data.grid_bounds_display() if visual_data != null else Rect2()


func get_pixel_size() -> Vector2:
	return get_map_bounds().size


func update_hover(local_position: Vector2) -> Vector2i:
	var cell := _valid_cell_at(local_position)
	if cell != _hovered_cell:
		_hovered_cell = cell
		queue_redraw()
		cell_hovered.emit(cell)
	return cell


func click_at(local_position: Vector2) -> Vector2i:
	var cell := _valid_cell_at(local_position)
	if cell != INVALID_CELL:
		set_selected_cell(cell)
		cell_clicked.emit(cell)
	return cell


func _unhandled_input(event: InputEvent) -> void:
	if grid == null or visual_data == null:
		return
	if event is InputEventMouseMotion:
		update_hover(get_local_mouse_position())
	elif event is InputEventMouseButton \
			and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		click_at(get_local_mouse_position())


func _valid_cell_at(local_position: Vector2) -> Vector2i:
	var candidate := local_to_grid(local_position)
	if grid != null and grid.is_terrain_interactable(candidate):
		return candidate
	return INVALID_CELL


func _draw() -> void:
	if grid == null or visual_data == null:
		return
	for y in range(grid.rows):
		for x in range(grid.cols):
			var cell := Vector2i(x, y)
			var polygon := get_cell_polygon(cell)
			var cell_type := grid.get_type(cell)
			# Une cellule HOLE peut recevoir un contour de diagnostic, jamais un
			# remplissage qui ressemble a une dalle tactique.
			if (draw_base_cells or draw_logic_types) \
					and cell_type != GridData.CellType.HOLE:
				draw_colored_polygon(polygon, TYPE_COLORS[cell_type])
			if _highlights.has(cell):
				draw_colored_polygon(polygon, _highlights[cell])
			var stored_effect = grid.get_effect(cell)
			if stored_effect != null:
				draw_colored_polygon(polygon, Color(1.0, 0.8, 0.2, 0.34))
			if draw_grid_lines and grid.is_terrain_interactable(cell):
				_draw_polygon_outline(polygon, GRID_LINE_COLOR, 1.0)
			if draw_void_cells and cell_type == GridData.CellType.HOLE:
				_draw_polygon_outline(polygon, Color(0.4, 0.5, 0.65, 0.85), 1.5)
			if draw_cell_centers:
				draw_circle(grid_to_local(cell), 2.0, CENTER_COLOR)
			if draw_coordinates:
				draw_string(
					ThemeDB.fallback_font,
					grid_to_local(cell) + Vector2(3.0, -3.0),
					"%d,%d" % [cell.x, cell.y],
					HORIZONTAL_ALIGNMENT_LEFT,
					-1.0,
					9,
					Color.WHITE
				)
			if draw_spawns and hero_spawn_cells.has(cell):
				draw_circle(grid_to_local(cell), 6.0, Color(0.2, 0.62, 1.0, 0.95))
			elif draw_spawns and enemy_spawn_cells.has(cell):
				draw_circle(grid_to_local(cell), 6.0, Color(1.0, 0.25, 0.2, 0.95))

	if grid.is_valid(_selected_cell):
		var selected_polygon := get_cell_polygon(_selected_cell)
		draw_colored_polygon(selected_polygon, SELECTED_FILL_COLOR)
		_draw_polygon_outline(selected_polygon, SELECTED_LINE_COLOR, 2.5)
	if grid.is_valid(_hovered_cell):
		var hovered_polygon := get_cell_polygon(_hovered_cell)
		draw_colored_polygon(hovered_polygon, HOVER_FILL_COLOR)
		_draw_polygon_outline(hovered_polygon, HOVER_LINE_COLOR, 2.0)
	if draw_map_bounds:
		draw_rect(get_map_bounds(), Color(1.0, 0.25, 0.75, 0.95), false, 2.0)
		draw_rect(get_logical_bounds(), Color(0.25, 1.0, 0.75, 0.95), false, 2.0)
	if draw_calibration:
		_draw_calibration()


func diagnostic_fill_cells() -> Array[String]:
	var result: Array[String] = []
	if grid == null or not (draw_base_cells or draw_logic_types):
		return result
	for y in range(grid.rows):
		for x in range(grid.cols):
			var cell := Vector2i(x, y)
			if grid.get_type(cell) != GridData.CellType.HOLE:
				result.append(ArenaTopologySignatureService.coordinate_key(cell))
	return result


func render_option_report() -> Dictionary:
	return {
		"draw_base_cells": draw_base_cells,
		"draw_logic_types": draw_logic_types,
		"draw_void_cells": draw_void_cells,
		"draw_grid_lines": draw_grid_lines,
		"filled_cells": diagnostic_fill_cells(),
	}


func _draw_calibration() -> void:
	var origin := visual_data.image_native_to_display(visual_data.grid_origin)
	draw_circle(origin, 5.0, Color.YELLOW)
	draw_line(
		origin,
		visual_data.image_native_to_display(
			visual_data.grid_origin + visual_data.axis_x * 2.0
		),
		Color(0.1, 1.0, 0.95), 3.0
	)
	draw_line(
		origin,
		visual_data.image_native_to_display(
			visual_data.grid_origin + visual_data.axis_y * 2.0
		),
		Color(1.0, 0.2, 0.9), 3.0
	)
	var errors := visual_data.anchor_errors()
	for index in range(mini(visual_data.calibration_cells.size(), errors.size())):
		var predicted := visual_data.cell_to_display(visual_data.calibration_cells[index])
		var measured := visual_data.image_native_to_display(
			visual_data.calibration_pixels[index]
		)
		draw_line(predicted, measured, Color.RED, 2.0)
		draw_circle(measured, 4.0, Color.WHITE)
		draw_string(
			ThemeDB.fallback_font,
			measured + Vector2(5.0, -4.0),
			"%.2f px" % errors[index],
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			10,
			Color.WHITE
		)


func _draw_polygon_outline(polygon: PackedVector2Array, color: Color, width: float) -> void:
	if polygon.is_empty():
		return
	var closed := PackedVector2Array(polygon)
	closed.append(polygon[0])
	draw_polyline(closed, color, width, true)
