@tool
class_name MountainPassBlockoutData
extends Resource

## Autorite declarative du blockout du col enneige.
## La ressource ne contient aucune regle de combat : elle adapte seulement les
## symboles du layout vers les CellType deja geres par GridData.

const NORMAL := "."
const ICE := "~"
const BLOCKED := "#"
const LANDMARK := "R"
const VOID := "X"
const ALLY_SPAWN := "A"
const ENEMY_SPAWN := "E"
const ALLOWED_SYMBOLS := ".~#RXAE"

@export var map_id: StringName = &"mountain_pass_blockout"
@export var logical_size := Vector2i(14, 14)
@export var layout_rows := PackedStringArray()

@export_group("Calibration native")
@export var cell_native_size := Vector2(128.0, 64.0)
@export_range(0.1, 2.0, 0.01) var preview_scale := 0.75

@export_group("Calibration export 2048")
@export var canvas_size := Vector2i(2048, 2048)
@export var grid_origin := Vector2(1024.0, 650.0)
@export var axis_x := Vector2(48.0, 24.0)
@export var axis_y := Vector2(-48.0, 24.0)
@export_range(0.0, 160.0, 1.0) var cliff_depth := 58.0
@export_range(0.0, 100.0, 1.0) var obstacle_height := 34.0
@export_range(0.0, 120.0, 1.0) var landmark_height := 50.0
@export var camera_zoom := Vector2.ONE
@export var camera_offset := Vector2.ZERO

@export_group("Sol visuel uniquement")
@export var road_visual_cells: Array[Vector2i] = []


func symbol_at(cell: Vector2i) -> String:
	if cell.x < 0 or cell.y < 0 \
			or cell.x >= logical_size.x or cell.y >= logical_size.y \
			or cell.y >= layout_rows.size():
		return VOID
	var row := layout_rows[cell.y]
	if cell.x >= row.length():
		return VOID
	return row.substr(cell.x, 1)


func cells_for(symbol: String) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y in range(logical_size.y):
		for x in range(logical_size.x):
			var cell := Vector2i(x, y)
			if symbol_at(cell) == symbol:
				result.append(cell)
	return result


func walkable_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for symbol in [NORMAL, ICE, ALLY_SPAWN, ENEMY_SPAWN]:
		result.append_array(cells_for(symbol))
	return result


func blocked_cells() -> Array[Vector2i]:
	var result := cells_for(BLOCKED)
	result.append_array(cells_for(LANDMARK))
	return result


func void_cells() -> Array[Vector2i]:
	return cells_for(VOID)


func ice_cells() -> Array[Vector2i]:
	return cells_for(ICE)


func ally_spawn_cells() -> Array[Vector2i]:
	return cells_for(ALLY_SPAWN)


func enemy_spawn_cells() -> Array[Vector2i]:
	return cells_for(ENEMY_SPAWN)


func landmark_cells() -> Array[Vector2i]:
	return cells_for(LANDMARK)


func layout_counts() -> Dictionary:
	var counts := {
		NORMAL: 0,
		ICE: 0,
		BLOCKED: 0,
		LANDMARK: 0,
		VOID: 0,
		ALLY_SPAWN: 0,
		ENEMY_SPAWN: 0,
	}
	for y in range(logical_size.y):
		for x in range(logical_size.x):
			var symbol := symbol_at(Vector2i(x, y))
			counts[symbol] = int(counts.get(symbol, 0)) + 1
	return counts


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if layout_rows.size() != logical_size.y:
		errors.append("Le layout doit contenir %d lignes." % logical_size.y)
	for y in range(layout_rows.size()):
		var row := layout_rows[y]
		if row.length() != logical_size.x:
			errors.append("La ligne %d doit contenir %d caracteres." % [y, logical_size.x])
		for x in range(row.length()):
			var symbol := row.substr(x, 1)
			if ALLOWED_SYMBOLS.find(symbol) < 0:
				errors.append("Symbole inconnu '%s' en (%d, %d)." % [symbol, x, y])
	var determinant := axis_x.x * axis_y.y - axis_y.x * axis_x.y
	if is_zero_approx(determinant):
		errors.append("axis_x et axis_y ne doivent pas etre colineaires.")
	if not is_equal_approx(cell_native_size.x / cell_native_size.y, 2.0):
		errors.append("La cellule native doit conserver un ratio 2:1.")
	return errors


func apply_to_grid(grid: GridData) -> void:
	if grid == null:
		return
	for y in range(mini(grid.rows, logical_size.y)):
		for x in range(mini(grid.cols, logical_size.x)):
			var cell := Vector2i(x, y)
			match symbol_at(cell):
				VOID:
					grid.set_type(cell, GridData.CellType.HOLE)
				BLOCKED, LANDMARK:
					grid.set_type(cell, GridData.CellType.WALL)
				ICE:
					grid.set_type(cell, GridData.CellType.ICE)
				_:
					grid.set_type(cell, GridData.CellType.NORMAL)


func cell_to_screen(cell: Vector2i) -> Vector2:
	return grid_origin + float(cell.x) * axis_x + float(cell.y) * axis_y


func screen_to_cell(screen_position: Vector2) -> Vector2i:
	var local := screen_position - grid_origin
	var determinant := axis_x.x * axis_y.y - axis_y.x * axis_x.y
	if is_zero_approx(determinant):
		return Vector2i(-1, -1)
	var raw_x := (local.x * axis_y.y - axis_y.x * local.y) / determinant
	var raw_y := (axis_x.x * local.y - local.x * axis_x.y) / determinant
	return Vector2i(roundi(raw_x), roundi(raw_y))


func cell_polygon(cell: Vector2i) -> PackedVector2Array:
	var center := cell_to_screen(cell)
	var half_width := absf(axis_x.x - axis_y.x) * 0.5
	var half_height := absf(axis_x.y + axis_y.y) * 0.5
	return PackedVector2Array([
		center + Vector2(0.0, -half_height),
		center + Vector2(half_width, 0.0),
		center + Vector2(0.0, half_height),
		center + Vector2(-half_width, 0.0),
	])


func logical_bounds() -> Rect2:
	return _bounds_for_cells(_all_logical_cells())


func platform_bounds() -> Rect2:
	var cells: Array[Vector2i] = []
	for cell in _all_logical_cells():
		if symbol_at(cell) != VOID:
			cells.append(cell)
	return _bounds_for_cells(cells)


func cliff_edges() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var directions: Array[Vector2i] = [
		Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT,
	]
	for cell in _all_logical_cells():
		if symbol_at(cell) == VOID:
			continue
		for direction in directions:
			var neighbor: Vector2i = cell + direction
			if symbol_at(neighbor) == VOID:
				result.append({"cell": cell, "direction": direction})
	return result


func obstacle_groups() -> Array:
	var groups: Array = []
	groups.append_array(_connected_groups(cells_for(BLOCKED)))
	var ruin := cells_for(LANDMARK)
	if not ruin.is_empty():
		groups.append(ruin)
	return groups


func is_road_cell(cell: Vector2i) -> bool:
	return road_visual_cells.has(cell) and symbol_at(cell) != VOID


func _all_logical_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y in range(logical_size.y):
		for x in range(logical_size.x):
			result.append(Vector2i(x, y))
	return result


func _bounds_for_cells(cells: Array[Vector2i]) -> Rect2:
	if cells.is_empty():
		return Rect2(grid_origin, Vector2.ZERO)
	var first := cell_polygon(cells[0])[0]
	var minimum := first
	var maximum := first
	for cell in cells:
		for point in cell_polygon(cell):
			minimum = minimum.min(point)
			maximum = maximum.max(point)
	return Rect2(minimum, maximum - minimum)


func _connected_groups(source_cells: Array[Vector2i]) -> Array:
	var remaining := {}
	for cell in source_cells:
		remaining[cell] = true
	var result: Array = []
	while not remaining.is_empty():
		var seed: Vector2i = remaining.keys()[0]
		var group: Array[Vector2i] = []
		var frontier: Array[Vector2i] = [seed]
		remaining.erase(seed)
		while not frontier.is_empty():
			var current: Vector2i = frontier.pop_front()
			group.append(current)
			var directions: Array[Vector2i] = [
				Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT,
			]
			for direction in directions:
				var neighbor: Vector2i = current + direction
				if remaining.has(neighbor):
					remaining.erase(neighbor)
					frontier.append(neighbor)
		result.append(group)
	return result
