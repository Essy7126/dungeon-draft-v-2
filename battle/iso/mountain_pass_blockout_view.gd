@tool
class_name MountainPassBlockoutView
extends Node2D

## Rendu technique 2D du col enneige et facade de projection pour Battle.
## Le gameplay reste exclusivement dans GridData/Pathfinder ; ce noeud ne fait
## que convertir, dessiner et router les interactions de cellule.

signal cell_hovered(grid_pos: Vector2i)
signal cell_clicked(grid_pos: Vector2i)

enum RenderMode {
	REFERENCE,
	CLEAN,
	DEBUG,
	LOGIC_MASK,
	HEIGHT_GUIDE,
}

const INVALID_CELL := Vector2i(-1, -1)
const CANVAS_RECT := Rect2(0.0, 0.0, 2048.0, 2048.0)

const COLOR_BACKGROUND := Color("d8dde2")
const COLOR_SKY := Color("cbd3da")
const COLOR_SNOW := Color("edf1f3")
const COLOR_ROAD := Color("c9c4bc")
const COLOR_ICE := Color("badde8")
const COLOR_GRID := Color(0.19, 0.27, 0.34, 0.48)
const COLOR_CLIFF := Color("4b555e")
const COLOR_CLIFF_ALT := Color("59646e")
const COLOR_OBSTACLE := Color("65717a")
const COLOR_OBSTACLE_SIDE := Color("444d55")
const COLOR_LANDMARK := Color("59636c")
const COLOR_LANDMARK_SIDE := Color("394148")
const COLOR_ALLY := Color(0.20, 0.55, 0.92, 0.24)
const COLOR_ENEMY := Color(0.88, 0.30, 0.25, 0.24)

const LOGIC_COLORS := {
	MountainPassBlockoutData.NORMAL: Color("d9e0e4"),
	MountainPassBlockoutData.ICE: Color("78cde5"),
	MountainPassBlockoutData.BLOCKED: Color("48525b"),
	MountainPassBlockoutData.LANDMARK: Color("6d526f"),
	MountainPassBlockoutData.VOID: Color("222a31"),
	MountainPassBlockoutData.ALLY_SPAWN: Color("338ee8"),
	MountainPassBlockoutData.ENEMY_SPAWN: Color("dc5149"),
}

@export var blockout_data: MountainPassBlockoutData:
	set(value):
		blockout_data = value
		queue_redraw()

@export var render_mode := RenderMode.REFERENCE:
	set(value):
		render_mode = value
		queue_redraw()

@export_group("Calibration")
@export var grid_origin := Vector2(1024.0, 650.0):
	set(value):
		grid_origin = value
		queue_redraw()
@export_range(0.1, 2.0, 0.01) var preview_scale := 0.75:
	set(value):
		preview_scale = value
		queue_redraw()
@export var axis_x := Vector2(48.0, 24.0):
	set(value):
		axis_x = value
		queue_redraw()
@export var axis_y := Vector2(-48.0, 24.0):
	set(value):
		axis_y = value
		queue_redraw()
@export_range(0.0, 160.0, 1.0) var cliff_depth := 58.0:
	set(value):
		cliff_depth = value
		queue_redraw()
@export_range(0.0, 100.0, 1.0) var obstacle_height := 34.0:
	set(value):
		obstacle_height = value
		queue_redraw()
@export_range(0.0, 120.0, 1.0) var landmark_height := 50.0:
	set(value):
		landmark_height = value
		queue_redraw()
@export var camera_zoom := Vector2.ONE
@export var camera_offset := Vector2.ZERO

@export_group("Apercu")
@export var show_unit_preview := false:
	set(value):
		show_unit_preview = value
		queue_redraw()

var grid: GridData = null
var _hovered_cell := INVALID_CELL
var _selected_cell := INVALID_CELL
var _highlights: Dictionary = {}


func _ready() -> void:
	queue_redraw()


func setup(grid_data: GridData) -> void:
	grid = grid_data
	_hovered_cell = INVALID_CELL
	_selected_cell = INVALID_CELL
	_highlights.clear()
	queue_redraw()


func grid_to_local(cell: Vector2i) -> Vector2:
	return grid_origin + float(cell.x) * axis_x + float(cell.y) * axis_y


func grid_to_world(cell: Vector2i) -> Vector2:
	return grid_to_local(cell)


func local_to_grid(local_position: Vector2) -> Vector2i:
	var local := local_position - grid_origin
	var determinant := axis_x.x * axis_y.y - axis_y.x * axis_x.y
	if is_zero_approx(determinant):
		return INVALID_CELL
	var raw_x := (local.x * axis_y.y - axis_y.x * local.y) / determinant
	var raw_y := (axis_x.x * local.y - local.x * axis_x.y) / determinant
	return Vector2i(roundi(raw_x), roundi(raw_y))


func world_to_grid(local_position: Vector2) -> Vector2i:
	return local_to_grid(local_position)


func get_cell_polygon(cell: Vector2i) -> PackedVector2Array:
	var center := grid_to_local(cell)
	var half_width := absf(axis_x.x - axis_y.x) * 0.5
	var half_height := absf(axis_x.y + axis_y.y) * 0.5
	return PackedVector2Array([
		center + Vector2(0.0, -half_height),
		center + Vector2(half_width, 0.0),
		center + Vector2(0.0, half_height),
		center + Vector2(-half_width, 0.0),
	])


func get_map_bounds() -> Rect2:
	return CANVAS_RECT


func get_platform_bounds() -> Rect2:
	if blockout_data == null:
		return Rect2()
	var cells: Array[Vector2i] = []
	for y in range(blockout_data.logical_size.y):
		for x in range(blockout_data.logical_size.x):
			var cell := Vector2i(x, y)
			if blockout_data.symbol_at(cell) != MountainPassBlockoutData.VOID:
				cells.append(cell)
	return _bounds_for_cells(cells)


func get_logical_bounds() -> Rect2:
	if blockout_data == null:
		return Rect2()
	var cells: Array[Vector2i] = []
	for y in range(blockout_data.logical_size.y):
		for x in range(blockout_data.logical_size.x):
			cells.append(Vector2i(x, y))
	return _bounds_for_cells(cells)


func get_pixel_size() -> Vector2:
	return CANVAS_RECT.size


func highlight(cells: Array, color: Color) -> void:
	for cell in cells:
		if cell is Vector2i and _is_logical_cell(cell):
			_highlights[cell] = color
	queue_redraw()


func clear_highlights() -> void:
	_highlights.clear()
	queue_redraw()


func set_selected_cell(cell: Vector2i) -> void:
	if not _is_interactable(cell):
		return
	_selected_cell = cell
	queue_redraw()


func clear_selection() -> void:
	_selected_cell = INVALID_CELL
	queue_redraw()


func get_hovered_cell() -> Vector2i:
	return _hovered_cell


func get_selected_cell() -> Vector2i:
	return _selected_cell


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
	if grid == null:
		return
	if event is InputEventMouseMotion:
		update_hover(get_local_mouse_position())
	elif event is InputEventMouseButton \
			and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		click_at(get_local_mouse_position())


func _draw() -> void:
	draw_rect(CANVAS_RECT, COLOR_BACKGROUND)
	if blockout_data == null:
		return
	if render_mode == RenderMode.LOGIC_MASK:
		_draw_logic_mask()
		return
	if render_mode == RenderMode.HEIGHT_GUIDE:
		_draw_height_guide()
		return

	_draw_environment_back(false)
	_draw_cliffs(false)
	_draw_ground()
	_draw_obstacles(false)
	_draw_environment_front(false)
	_draw_runtime_overlays()
	if show_unit_preview:
		_draw_unit_previews()
	if render_mode == RenderMode.DEBUG:
		_draw_debug_overlay()


func _draw_environment_back(height_guide: bool) -> void:
	var ridge_color := Color("7f8991") if not height_guide else Color(0.32, 0.32, 0.32)
	var snow_color := Color("e2e7e9") if not height_guide else Color(0.42, 0.42, 0.42)
	draw_colored_polygon(PackedVector2Array([
		Vector2(80, 560), Vector2(250, 405), Vector2(420, 490),
		Vector2(600, 295), Vector2(790, 480), Vector2(940, 370),
		Vector2(1120, 500), Vector2(1320, 315), Vector2(1510, 470),
		Vector2(1690, 380), Vector2(1968, 570), Vector2(1968, 625),
		Vector2(80, 625),
	]), ridge_color)
	draw_colored_polygon(PackedVector2Array([
		Vector2(105, 558), Vector2(250, 430), Vector2(420, 510),
		Vector2(600, 330), Vector2(790, 510), Vector2(940, 405),
		Vector2(1120, 525), Vector2(1320, 350), Vector2(1510, 500),
		Vector2(1690, 415), Vector2(1940, 580), Vector2(1940, 622),
		Vector2(105, 622),
	]), snow_color)
	# Epaules laterales : elles restent hors des centres jouables.
	draw_colored_polygon(PackedVector2Array([
		Vector2(90, 720), Vector2(260, 650), Vector2(430, 720),
		Vector2(390, 1010), Vector2(180, 1110), Vector2(70, 980),
	]), ridge_color.darkened(0.08))
	draw_colored_polygon(PackedVector2Array([
		Vector2(1958, 720), Vector2(1780, 650), Vector2(1615, 735),
		Vector2(1655, 1030), Vector2(1870, 1110), Vector2(1980, 975),
	]), ridge_color.darkened(0.05))


func _draw_environment_front(height_guide: bool) -> void:
	var rock := Color("68737c") if not height_guide else Color(0.26, 0.26, 0.26)
	var snow := Color("e7ebed") if not height_guide else Color(0.38, 0.38, 0.38)
	for polygon in [
		PackedVector2Array([Vector2(80, 1290), Vector2(255, 1200), Vector2(390, 1305), Vector2(320, 1435), Vector2(100, 1455)]),
		PackedVector2Array([Vector2(1968, 1280), Vector2(1780, 1195), Vector2(1650, 1315), Vector2(1735, 1440), Vector2(1950, 1455)]),
	]:
		draw_colored_polygon(polygon, rock)
	draw_colored_polygon(PackedVector2Array([
		Vector2(92, 1292), Vector2(255, 1220), Vector2(370, 1308),
		Vector2(300, 1360), Vector2(120, 1368),
	]), snow)
	draw_colored_polygon(PackedVector2Array([
		Vector2(1955, 1285), Vector2(1785, 1218), Vector2(1670, 1318),
		Vector2(1750, 1365), Vector2(1930, 1370),
	]), snow)


func _draw_cliffs(height_guide: bool) -> void:
	var edges := _cliff_edges()
	edges.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _edge_midpoint(a).y < _edge_midpoint(b).y)
	for edge in edges:
		var pair := _edge_points(edge["cell"], edge["direction"])
		var extrusion := Vector2(0.0, cliff_depth)
		var face := PackedVector2Array([pair[0], pair[1], pair[1] + extrusion, pair[0] + extrusion])
		var color := Color(0.18, 0.18, 0.18) if height_guide else (
			COLOR_CLIFF if edge["direction"] in [Vector2i.RIGHT, Vector2i.DOWN]
			else COLOR_CLIFF_ALT
		)
		draw_colored_polygon(face, color)
		if not height_guide:
			_draw_outline(face, Color(0.15, 0.18, 0.21, 0.75), 1.0)


func _draw_ground() -> void:
	var cells := _platform_cells()
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var pa := grid_to_local(a)
		var pb := grid_to_local(b)
		return pa.x < pb.x if is_equal_approx(pa.y, pb.y) else pa.y < pb.y)
	for cell in cells:
		var symbol := blockout_data.symbol_at(cell)
		var color := COLOR_SNOW
		if symbol == MountainPassBlockoutData.ICE:
			color = COLOR_ICE
		elif blockout_data.is_road_cell(cell):
			color = COLOR_ROAD
		var polygon := get_cell_polygon(cell)
		draw_colored_polygon(polygon, color)
		if symbol == MountainPassBlockoutData.ALLY_SPAWN:
			draw_colored_polygon(polygon, COLOR_ALLY)
		elif symbol == MountainPassBlockoutData.ENEMY_SPAWN:
			draw_colored_polygon(polygon, COLOR_ENEMY)
		if render_mode != RenderMode.CLEAN:
			_draw_outline(polygon, COLOR_GRID, 1.0)


func _draw_obstacles(height_guide: bool) -> void:
	var groups := blockout_data.obstacle_groups()
	groups.sort_custom(func(a: Array, b: Array) -> bool:
		return _group_depth(a) < _group_depth(b))
	for group in groups:
		var landmark := blockout_data.symbol_at(group[0]) == MountainPassBlockoutData.LANDMARK
		var height := landmark_height if landmark else obstacle_height
		var points := PackedVector2Array()
		for cell in group:
			points.append_array(get_cell_polygon(cell))
		var base := Geometry2D.convex_hull(points)
		if base.size() > 1 and base[0] == base[base.size() - 1]:
			base.resize(base.size() - 1)
		var centroid := Vector2.ZERO
		for point in base:
			centroid += point
		centroid /= float(maxi(base.size(), 1))
		var top := PackedVector2Array()
		for point in base:
			top.append(centroid + (point - centroid) * 0.78 + Vector2(0.0, -height))
		var side_color := Color(0.25, 0.25, 0.25) if height_guide else (
			COLOR_LANDMARK_SIDE if landmark else COLOR_OBSTACLE_SIDE
		)
		for index in range(base.size()):
			var next := (index + 1) % base.size()
			var side := PackedVector2Array([base[index], base[next], top[next], top[index]])
			draw_colored_polygon(side, side_color)
		var top_color := Color(0.52, 0.52, 0.52) if height_guide else (
			COLOR_LANDMARK if landmark else COLOR_OBSTACLE
		)
		draw_colored_polygon(top, top_color)
		if not height_guide:
			_draw_outline(base, Color(0.16, 0.19, 0.22, 0.86), 1.5)
			_draw_outline(top, Color(0.88, 0.92, 0.94, 0.42), 1.0)


func _draw_runtime_overlays() -> void:
	for cell in _highlights:
		draw_colored_polygon(get_cell_polygon(cell), _highlights[cell])
	if _is_logical_cell(_selected_cell):
		_draw_outline(get_cell_polygon(_selected_cell), Color("ffc44d"), 3.0)
	if _is_logical_cell(_hovered_cell):
		_draw_outline(get_cell_polygon(_hovered_cell), Color("72e6ff"), 2.0)


func _draw_unit_previews() -> void:
	var ally_cells := blockout_data.ally_spawn_cells()
	var enemy_cells := blockout_data.enemy_spawn_cells()
	for index in range(mini(3, ally_cells.size())):
		_draw_unit_silhouette(ally_cells[index], Color("3c8fd9"))
	for index in range(mini(3, enemy_cells.size())):
		_draw_unit_silhouette(enemy_cells[index], Color("c8534f"))


func _draw_unit_silhouette(cell: Vector2i, color: Color) -> void:
	var feet := grid_to_local(cell)
	_draw_ellipse_shape(feet + Vector2(0, -2), Vector2(22, 8), Color(0.05, 0.08, 0.10, 0.36))
	draw_colored_polygon(PackedVector2Array([
		feet + Vector2(-17, -2), feet + Vector2(-13, -42),
		feet + Vector2(-7, -62), feet + Vector2(0, -69),
		feet + Vector2(7, -62), feet + Vector2(13, -42),
		feet + Vector2(17, -2),
	]), color)
	draw_circle(feet + Vector2(0, -74), 10.0, color.lightened(0.12))


func _draw_debug_overlay() -> void:
	var font := ThemeDB.fallback_font
	for y in range(blockout_data.logical_size.y):
		for x in range(blockout_data.logical_size.x):
			var cell := Vector2i(x, y)
			var symbol := blockout_data.symbol_at(cell)
			var polygon := get_cell_polygon(cell)
			var overlay: Color = LOGIC_COLORS[symbol]
			overlay.a = 0.28 if symbol != MountainPassBlockoutData.VOID else 0.68
			draw_colored_polygon(polygon, overlay)
			_draw_outline(polygon, Color(0.08, 0.12, 0.16, 0.62), 0.8)
			var center := grid_to_local(cell)
			draw_circle(center, 2.5, Color("17212a"))
			var label := "%d,%d %s" % [x, y, symbol]
			draw_string(font, center + Vector2(-20, -5), label, HORIZONTAL_ALIGNMENT_CENTER, 40, 10, Color("17212a"))

	var logical := get_logical_bounds()
	var platform := get_platform_bounds()
	draw_rect(logical, Color("e83c91"), false, 2.0)
	draw_rect(platform, Color("37d59b"), false, 3.0)
	draw_circle(grid_origin, 7.0, Color("ffcf4a"))
	_draw_arrow(grid_origin, grid_origin + axis_x * 2.0, Color("f09a37"))
	_draw_arrow(grid_origin, grid_origin + axis_y * 2.0, Color("52b9ed"))
	draw_string(font, grid_origin + Vector2(12, -9), "ORIGIN", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("17212a"))
	draw_string(font, grid_origin + axis_x * 2.0 + Vector2(6, -4), "axis_x", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("7b4212"))
	draw_string(font, grid_origin + axis_y * 2.0 + Vector2(-54, -4), "axis_y", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("185979"))
	for edge in _cliff_edges():
		var pair := _edge_points(edge["cell"], edge["direction"])
		draw_line(pair[0], pair[1], Color(0.05, 0.85, 0.72, 0.90), 2.0)
	for group in blockout_data.obstacle_groups():
		for cell in group:
			_draw_outline(get_cell_polygon(cell), Color("ff7b39"), 2.0)


func _draw_logic_mask() -> void:
	for y in range(blockout_data.logical_size.y):
		for x in range(blockout_data.logical_size.x):
			var cell := Vector2i(x, y)
			var symbol := blockout_data.symbol_at(cell)
			var polygon := get_cell_polygon(cell)
			draw_colored_polygon(polygon, LOGIC_COLORS[symbol])
			_draw_outline(polygon, Color(0.04, 0.06, 0.08, 0.55), 1.0)


func _draw_height_guide() -> void:
	draw_rect(CANVAS_RECT, Color(0.92, 0.92, 0.92))
	_draw_environment_back(true)
	_draw_cliffs(true)
	for cell in _platform_cells():
		draw_colored_polygon(get_cell_polygon(cell), Color(0.72, 0.72, 0.72))
	_draw_obstacles(true)
	_draw_environment_front(true)


func _platform_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y in range(blockout_data.logical_size.y):
		for x in range(blockout_data.logical_size.x):
			var cell := Vector2i(x, y)
			if blockout_data.symbol_at(cell) != MountainPassBlockoutData.VOID:
				result.append(cell)
	return result


func _cliff_edges() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for cell in _platform_cells():
		for direction in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
			if blockout_data.symbol_at(cell + direction) == MountainPassBlockoutData.VOID:
				result.append({"cell": cell, "direction": direction})
	return result


func _edge_points(cell: Vector2i, direction: Vector2i) -> PackedVector2Array:
	var polygon := get_cell_polygon(cell)
	match direction:
		Vector2i.UP:
			return PackedVector2Array([polygon[0], polygon[1]])
		Vector2i.RIGHT:
			return PackedVector2Array([polygon[1], polygon[2]])
		Vector2i.DOWN:
			return PackedVector2Array([polygon[2], polygon[3]])
		_:
			return PackedVector2Array([polygon[3], polygon[0]])


func _edge_midpoint(edge: Dictionary) -> Vector2:
	var points := _edge_points(edge["cell"], edge["direction"])
	return (points[0] + points[1]) * 0.5


func _group_depth(group: Array) -> float:
	var depth := -INF
	for cell in group:
		depth = maxf(depth, grid_to_local(cell).y)
	return depth


func _bounds_for_cells(cells: Array[Vector2i]) -> Rect2:
	if cells.is_empty():
		return Rect2(grid_origin, Vector2.ZERO)
	var minimum := get_cell_polygon(cells[0])[0]
	var maximum := minimum
	for cell in cells:
		for point in get_cell_polygon(cell):
			minimum = minimum.min(point)
			maximum = maximum.max(point)
	return Rect2(minimum, maximum - minimum)


func _valid_cell_at(local_position: Vector2) -> Vector2i:
	var candidate := local_to_grid(local_position)
	return candidate if _is_interactable(candidate) else INVALID_CELL


func _is_interactable(cell: Vector2i) -> bool:
	if grid != null:
		return grid.is_terrain_interactable(cell)
	if not _is_logical_cell(cell):
		return false
	return blockout_data.symbol_at(cell) in [
		MountainPassBlockoutData.NORMAL,
		MountainPassBlockoutData.ICE,
		MountainPassBlockoutData.ALLY_SPAWN,
		MountainPassBlockoutData.ENEMY_SPAWN,
	]


func _is_logical_cell(cell: Vector2i) -> bool:
	return blockout_data != null \
		and cell.x >= 0 and cell.y >= 0 \
		and cell.x < blockout_data.logical_size.x \
		and cell.y < blockout_data.logical_size.y


func _draw_outline(polygon: PackedVector2Array, color: Color, width: float) -> void:
	if polygon.is_empty():
		return
	var closed := PackedVector2Array(polygon)
	closed.append(polygon[0])
	draw_polyline(closed, color, width, true)


func _draw_arrow(from: Vector2, to: Vector2, color: Color) -> void:
	draw_line(from, to, color, 4.0)
	var direction := (to - from).normalized()
	var normal := Vector2(-direction.y, direction.x)
	draw_colored_polygon(PackedVector2Array([
		to, to - direction * 15.0 + normal * 7.0, to - direction * 15.0 - normal * 7.0,
	]), color)


func _draw_ellipse_shape(center: Vector2, radii: Vector2, color: Color, segments: int = 28) -> void:
	var polygon := PackedVector2Array()
	for index in range(segments):
		var angle := TAU * float(index) / float(segments)
		polygon.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(polygon, color)
