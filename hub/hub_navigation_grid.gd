class_name HubNavigationGrid
extends RefCounted

## Autorite spatiale du hub. Cette grille reste independante du combat :
## aucun tour, PA, PM, sort ou GridData n'entre dans son contrat.

const IsoProjectionScript = preload("res://battle/iso/iso_projection.gd")
const INVALID_CELL := Vector2i(-1, -1)
const ORTHOGONAL_DIRECTIONS: Array[Vector2i] = [
	Vector2i.RIGHT,
	Vector2i.DOWN,
	Vector2i.LEFT,
	Vector2i.UP,
]
const DIAGONAL_DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 1),
	Vector2i(-1, 1),
	Vector2i(-1, -1),
	Vector2i(1, -1),
]
const DIAGONAL_COST := 1.41421356237

var grid_size := Vector2i(20, 20)
var tile_size := Vector2(128.0, 64.0)
var grid_origin := Vector2(1024.0, 640.0)

## Masque losange calibre manuellement sur la zone de sol visible.
var minimum_floor_sum := 3
var maximum_floor_sum := 33
var maximum_floor_axis_delta := 13
var blocked_cells: Array[Vector2i] = []

var _astar := AStarGrid2D.new()
var _projection: IsoProjection = null
var _blocked_lookup: Dictionary = {}
var _occupied_cells: Dictionary = {}
var _reserved_cells: Dictionary = {}


func rebuild() -> void:
	_blocked_lookup.clear()
	for cell in blocked_cells:
		if is_valid(cell):
			_blocked_lookup[cell] = true

	_astar = AStarGrid2D.new()
	_astar.region = Rect2i(Vector2i.ZERO, grid_size)
	_astar.cell_size = Vector2.ONE
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_astar.update()
	_refresh_astar_solids()


func is_valid(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < grid_size.x \
		and cell.y >= 0 and cell.y < grid_size.y


func is_walkable(cell: Vector2i, requester = null) -> bool:
	if not _is_base_walkable(cell):
		return false
	if _occupied_cells.has(cell) and _occupied_cells[cell] != requester:
		return false
	if _reserved_cells.has(cell) and _reserved_cells[cell] != requester:
		return false
	return true


func is_blocked(cell: Vector2i) -> bool:
	return is_valid(cell) and not is_walkable(cell)


func is_occupied(cell: Vector2i) -> bool:
	return _occupied_cells.has(cell)


func is_reserved(cell: Vector2i) -> bool:
	return _reserved_cells.has(cell)


func occupy(cell: Vector2i, occupant) -> bool:
	if not _is_base_walkable(cell):
		return false
	if _occupied_cells.has(cell) and _occupied_cells[cell] != occupant:
		return false
	if _reserved_cells.has(cell) and _reserved_cells[cell] != occupant:
		return false
	_occupied_cells[cell] = occupant
	_set_astar_solid(cell, true)
	return true


func vacate(cell: Vector2i, occupant = null) -> void:
	if not _occupied_cells.has(cell):
		return
	if occupant != null and _occupied_cells[cell] != occupant:
		return
	_occupied_cells.erase(cell)
	_sync_dynamic_solid(cell)


func reserve(cell: Vector2i, owner) -> bool:
	if owner == null or not is_walkable(cell, owner):
		return false
	if _reserved_cells.has(cell) and _reserved_cells[cell] != owner:
		return false
	_reserved_cells[cell] = owner
	_set_astar_solid(cell, true)
	return true


func release(cell: Vector2i, owner = null) -> void:
	if not _reserved_cells.has(cell):
		return
	if owner != null and _reserved_cells[cell] != owner:
		return
	_reserved_cells.erase(cell)
	_sync_dynamic_solid(cell)


func get_path(from_cell: Vector2i, to_cell: Vector2i, requester = null) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not _is_base_walkable(from_cell) or not is_walkable(to_cell, requester):
		return result

	var start_was_solid := _astar.is_point_solid(from_cell)
	var destination_was_solid := _astar.is_point_solid(to_cell)
	_astar.set_point_solid(from_cell, false)
	if _reserved_cells.get(to_cell, null) == requester:
		_astar.set_point_solid(to_cell, false)

	var ids := _astar.get_id_path(from_cell, to_cell, false)
	for id in ids:
		result.append(id)

	_astar.set_point_solid(from_cell, start_was_solid)
	_astar.set_point_solid(to_cell, destination_was_solid)
	return result


func get_orthogonal_neighbors(cell: Vector2i, requester = null) -> Array[Vector2i]:
	var neighbors: Array[Vector2i] = []
	for direction in ORTHOGONAL_DIRECTIONS:
		var candidate := cell + direction
		if is_walkable(candidate, requester):
			neighbors.append(candidate)
	return neighbors


func get_neighbors(cell: Vector2i, requester = null) -> Array[Vector2i]:
	var neighbors := get_orthogonal_neighbors(cell, requester)
	for direction in DIAGONAL_DIRECTIONS:
		var candidate := cell + direction
		if can_traverse(cell, candidate, requester):
			neighbors.append(candidate)
	return neighbors


func can_traverse(from_cell: Vector2i, to_cell: Vector2i, requester = null) -> bool:
	if not is_valid(from_cell) or not is_walkable(to_cell, requester):
		return false
	var delta := to_cell - from_cell
	if delta == Vector2i.ZERO or absi(delta.x) > 1 or absi(delta.y) > 1:
		return false
	if delta.x == 0 or delta.y == 0:
		return true
	return is_walkable(from_cell + Vector2i(delta.x, 0), requester) \
		and is_walkable(from_cell + Vector2i(0, delta.y), requester)


func get_path_cost(path: Array[Vector2i]) -> float:
	var cost := 0.0
	for index in range(1, path.size()):
		var delta := path[index] - path[index - 1]
		cost += DIAGONAL_COST if delta.x != 0 and delta.y != 0 else 1.0
	return cost


func get_blocked_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for x in range(grid_size.x):
		for y in range(grid_size.y):
			var cell := Vector2i(x, y)
			if is_blocked(cell):
				result.append(cell)
	return result


func get_walkable_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for x in range(grid_size.x):
		for y in range(grid_size.y):
			var cell := Vector2i(x, y)
			if is_walkable(cell):
				result.append(cell)
	return result


func cell_to_world(cell: Vector2i) -> Vector2:
	_ensure_projection()
	return _projection.grid_to_world(cell)


func world_to_cell(world_position: Vector2) -> Vector2i:
	_ensure_projection()
	return _projection.world_to_grid(world_position)


func _is_base_walkable(cell: Vector2i) -> bool:
	return is_valid(cell) \
		and not _is_outside_visible_floor(cell) \
		and not _blocked_lookup.has(cell)


func _is_outside_visible_floor(cell: Vector2i) -> bool:
	var depth := cell.x + cell.y
	var horizontal_axis := cell.x - cell.y
	return depth < minimum_floor_sum \
		or depth > maximum_floor_sum \
		or absi(horizontal_axis) > maximum_floor_axis_delta


func _refresh_astar_solids() -> void:
	for x in range(grid_size.x):
		for y in range(grid_size.y):
			var cell := Vector2i(x, y)
			_set_astar_solid(cell, not _is_base_walkable(cell) \
				or _occupied_cells.has(cell) or _reserved_cells.has(cell))


func _sync_dynamic_solid(cell: Vector2i) -> void:
	_set_astar_solid(cell, not _is_base_walkable(cell) \
		or _occupied_cells.has(cell) or _reserved_cells.has(cell))


func _set_astar_solid(cell: Vector2i, solid: bool) -> void:
	if is_valid(cell):
		_astar.set_point_solid(cell, solid)


func _ensure_projection() -> void:
	if _projection == null:
		_projection = IsoProjectionScript.new(tile_size.x, tile_size.y, grid_origin)
