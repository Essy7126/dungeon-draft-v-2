class_name IsoGridView
extends Node2D

## Facade de rendu entre GridData (logique) et TileMapLayer (projection).
## Toutes les positions exposees par cette classe sont locales a IsoGridView.

signal cell_hovered(grid_pos: Vector2i)
signal cell_clicked(grid_pos: Vector2i)

const FOOTPRINT := Vector2i(64, 32)
const INVALID_CELL := Vector2i(-1, -1)

const TYPE_COLORS := {
	GridData.CellType.NORMAL: Color(0.12, 0.16, 0.22, 0.94),
	GridData.CellType.WALL: Color(0.34, 0.30, 0.27, 0.94),
	GridData.CellType.HOLE: Color(0.035, 0.04, 0.07, 0.96),
	GridData.CellType.LAVA: Color(0.72, 0.22, 0.07, 0.94),
	GridData.CellType.ICE: Color(0.42, 0.70, 0.88, 0.94),
	GridData.CellType.SHADOW: Color(0.11, 0.09, 0.18, 0.94),
	GridData.CellType.RUNE: Color(0.43, 0.16, 0.62, 0.94),
}

const GRID_LINE_COLOR := Color(0.62, 0.72, 0.86, 0.62)
const CENTER_COLOR := Color(0.82, 0.92, 1.0, 0.85)
const BOUNDS_COLOR := Color(1.0, 0.28, 0.70, 0.95)
const HOVER_FILL_COLOR := Color(0.35, 0.88, 1.0, 0.32)
const HOVER_LINE_COLOR := Color(0.48, 0.94, 1.0, 1.0)
const SELECTED_FILL_COLOR := Color(1.0, 0.70, 0.18, 0.36)
const SELECTED_LINE_COLOR := Color(1.0, 0.78, 0.28, 1.0)

var grid: GridData = null
var debug_draw_enabled := true

var _geometry_layer: TileMapLayer = null
var _hovered_cell := INVALID_CELL
var _selected_cell := INVALID_CELL
var _highlights: Dictionary = {}


func setup(grid_data: GridData) -> void:
	if grid_data == null:
		push_error("IsoGridView.setup() requiert un GridData valide.")
		return
	grid = grid_data
	_ensure_geometry_layer()
	_hovered_cell = INVALID_CELL
	_selected_cell = INVALID_CELL
	_highlights.clear()
	queue_redraw()


func get_geometry_layer() -> TileMapLayer:
	return _ensure_geometry_layer()


func get_hovered_cell() -> Vector2i:
	return _hovered_cell


func get_selected_cell() -> Vector2i:
	return _selected_cell


func set_debug_draw_enabled(enabled: bool) -> void:
	debug_draw_enabled = enabled
	queue_redraw()


func set_selected_cell(cell: Vector2i) -> void:
	if grid == null or not grid.is_valid(cell):
		return
	if _selected_cell == cell:
		return
	_selected_cell = cell
	queue_redraw()


func clear_selection() -> void:
	if _selected_cell == INVALID_CELL:
		return
	_selected_cell = INVALID_CELL
	queue_redraw()


func highlight(cells: Array, color: Color) -> void:
	if grid == null:
		return
	for cell in cells:
		if cell is Vector2i and grid.is_valid(cell):
			_highlights[cell] = color
	queue_redraw()


func clear_highlights() -> void:
	_highlights.clear()
	queue_redraw()


func grid_to_local(cell: Vector2i) -> Vector2:
	var layer := _ensure_geometry_layer()
	var point_in_layer := layer.map_to_local(cell)
	return to_local(layer.to_global(point_in_layer))


func local_to_grid(local_position: Vector2) -> Vector2i:
	var layer := _ensure_geometry_layer()
	var point_in_layer := layer.to_local(to_global(local_position))
	return layer.local_to_map(point_in_layer)


## Alias de compatibilite avec battle.gd. La valeur retournee reste locale a
## IsoGridView ; ce nom ne signifie pas "coordonnees globales de la scene".
func grid_to_world(cell: Vector2i) -> Vector2:
	return grid_to_local(cell)


## Alias de compatibilite avec battle.gd. L'argument est local a IsoGridView.
func world_to_grid(local_position: Vector2) -> Vector2i:
	return local_to_grid(local_position)


func get_cell_polygon(cell: Vector2i) -> PackedVector2Array:
	var layer := _ensure_geometry_layer()
	var center_in_layer := layer.map_to_local(cell)
	var half_size := Vector2(FOOTPRINT) * 0.5
	var points_in_layer := PackedVector2Array([
		center_in_layer + Vector2(0.0, -half_size.y),
		center_in_layer + Vector2(half_size.x, 0.0),
		center_in_layer + Vector2(0.0, half_size.y),
		center_in_layer + Vector2(-half_size.x, 0.0),
	])
	var polygon := PackedVector2Array()
	for point in points_in_layer:
		polygon.append(to_local(layer.to_global(point)))
	return polygon


func get_map_bounds() -> Rect2:
	if grid == null or grid.cols <= 0 or grid.rows <= 0:
		return Rect2()

	var first_polygon := get_cell_polygon(Vector2i.ZERO)
	var minimum := first_polygon[0]
	var maximum := first_polygon[0]
	for x in range(grid.cols):
		for y in range(grid.rows):
			for point in get_cell_polygon(Vector2i(x, y)):
				minimum = minimum.min(point)
				maximum = maximum.max(point)
	return Rect2(minimum, maximum - minimum)


## Alias de compatibilite : la position des bounds n'est pas necessairement zero.
func get_pixel_size() -> Vector2:
	return get_map_bounds().size


## Point d'entree testable du survol, exprime dans le repere d'IsoGridView.
func update_hover(local_position: Vector2) -> Vector2i:
	var cell := _valid_cell_at(local_position)
	if cell != _hovered_cell:
		_hovered_cell = cell
		queue_redraw()
		cell_hovered.emit(cell)
	return cell


## Point d'entree testable du clic, exprime dans le repere d'IsoGridView.
func click_at(local_position: Vector2) -> Vector2i:
	var cell := _valid_cell_at(local_position)
	if cell != INVALID_CELL:
		set_selected_cell(cell)
		cell_clicked.emit(cell)
	return cell


func _unhandled_input(event: InputEvent) -> void:
	if grid == null:
		return
	if event is InputEventMouseMotion:
		update_hover(get_local_mouse_position())
	elif event is InputEventMouseButton \
			and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		click_at(get_local_mouse_position())


func _valid_cell_at(local_position: Vector2) -> Vector2i:
	var candidate := local_to_grid(local_position)
	if grid != null and grid.is_valid(candidate):
		return candidate
	return INVALID_CELL


func _ensure_geometry_layer() -> TileMapLayer:
	if is_instance_valid(_geometry_layer):
		_configure_tile_set(_geometry_layer)
		return _geometry_layer

	_geometry_layer = get_node_or_null("Geometry") as TileMapLayer
	if _geometry_layer == null:
		_geometry_layer = TileMapLayer.new()
		_geometry_layer.name = "Geometry"
		add_child(_geometry_layer)
	_configure_tile_set(_geometry_layer)
	return _geometry_layer


func _configure_tile_set(layer: TileMapLayer) -> void:
	if layer.tile_set == null:
		layer.tile_set = TileSet.new()
	var tile_set := layer.tile_set
	tile_set.tile_size = FOOTPRINT
	tile_set.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	tile_set.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
	tile_set.tile_offset_axis = TileSet.TILE_OFFSET_AXIS_HORIZONTAL


func _draw() -> void:
	if grid == null:
		return

	for x in range(grid.cols):
		for y in range(grid.rows):
			var cell := Vector2i(x, y)
			var polygon := get_cell_polygon(cell)
			var fill_color: Color = TYPE_COLORS.get(
				grid.get_type(cell), TYPE_COLORS[GridData.CellType.NORMAL]
			)
			draw_colored_polygon(polygon, fill_color)
			if _highlights.has(cell):
				draw_colored_polygon(polygon, _highlights[cell])
			if debug_draw_enabled:
				_draw_polygon_outline(polygon, GRID_LINE_COLOR, 1.0)
				draw_circle(grid_to_local(cell), 1.7, CENTER_COLOR)

	if grid.is_valid(_selected_cell):
		var selected_polygon := get_cell_polygon(_selected_cell)
		draw_colored_polygon(selected_polygon, SELECTED_FILL_COLOR)
		_draw_polygon_outline(selected_polygon, SELECTED_LINE_COLOR, 2.5)

	if grid.is_valid(_hovered_cell):
		var hovered_polygon := get_cell_polygon(_hovered_cell)
		draw_colored_polygon(hovered_polygon, HOVER_FILL_COLOR)
		_draw_polygon_outline(hovered_polygon, HOVER_LINE_COLOR, 2.0)

	if debug_draw_enabled:
		draw_rect(get_map_bounds(), BOUNDS_COLOR, false, 2.0)


func _draw_polygon_outline(
		polygon: PackedVector2Array,
		color: Color,
		width: float
	) -> void:
	var closed_polygon := PackedVector2Array(polygon)
	closed_polygon.append(polygon[0])
	draw_polyline(closed_polygon, color, width, true)
