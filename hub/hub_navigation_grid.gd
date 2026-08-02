class_name HubNavigationGrid
extends Node

## Autorite logique minimale de la premiere carte de hub.
## Cette ressource ne connait ni les tours, ni les points d'action, ni le combat.

const INVALID_CELL := Vector2i(-1, -1)
const ORTHOGONAL_DIRECTIONS: Array[Vector2i] = [
	Vector2i.RIGHT,
	Vector2i.DOWN,
	Vector2i.LEFT,
	Vector2i.UP,
]

@export var grid_size := Vector2i(20, 20)

## Masque losange calibre manuellement sur la zone de sol visible.
## x + y suit la profondeur dans l'image ; x - y suit son axe horizontal.
@export var minimum_floor_sum := 3
@export var maximum_floor_sum := 33
@export var maximum_floor_axis_delta := 13

## Obstacles peints en coordonnees logiques dans StartHub.tscn.
@export var blocked_cells: Array[Vector2i] = []

var _blocked_lookup: Dictionary = {}


func _ready() -> void:
	rebuild()


func rebuild() -> void:
	_blocked_lookup.clear()
	for cell in blocked_cells:
		if is_valid(cell):
			_blocked_lookup[cell] = true


func is_valid(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < grid_size.x \
		and cell.y >= 0 and cell.y < grid_size.y


func is_walkable(cell: Vector2i) -> bool:
	return is_valid(cell) \
		and not _is_outside_visible_floor(cell) \
		and not _blocked_lookup.has(cell)


func is_blocked(cell: Vector2i) -> bool:
	return is_valid(cell) and not is_walkable(cell)


func get_orthogonal_neighbors(cell: Vector2i) -> Array[Vector2i]:
	var neighbors: Array[Vector2i] = []
	for direction in ORTHOGONAL_DIRECTIONS:
		var candidate := cell + direction
		if is_walkable(candidate):
			neighbors.append(candidate)
	return neighbors


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


func _is_outside_visible_floor(cell: Vector2i) -> bool:
	var depth := cell.x + cell.y
	var horizontal_axis := cell.x - cell.y
	return depth < minimum_floor_sum \
		or depth > maximum_floor_sum \
		or absi(horizontal_axis) > maximum_floor_axis_delta
