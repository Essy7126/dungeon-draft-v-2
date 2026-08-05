class_name ArenaBoundaryService
extends RefCounted

const DIRECTIONS: Array[Vector2i] = [
	Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN,
]


## Detecte exclusivement le contour relie a l'exterieur. Un trou ferme n'est
## pas marque comme exterieur : le flood fill ne peut pas traverser les cellules
## definies qui l'entourent.
static func compute_outer_border(
		defined_cells: Array[Vector2i],
		logical_size: Vector2i,
		thickness := 1
	) -> Array[Vector2i]:
	var defined := {}
	for cell in defined_cells:
		if GridTransformService.is_cell_in_bounds(cell, logical_size):
			defined[cell] = true
	if defined.is_empty():
		return []
	var exterior := {}
	var start := Vector2i(-1, -1)
	var frontier: Array[Vector2i] = [start]
	exterior[start] = true
	var bounds := Rect2i(-1, -1, logical_size.x + 2, logical_size.y + 2)
	while not frontier.is_empty():
		var current: Vector2i = frontier.pop_front()
		for direction in DIRECTIONS:
			var neighbor: Vector2i = current + direction
			if not bounds.has_point(neighbor) or exterior.has(neighbor) \
					or defined.has(neighbor):
				continue
			exterior[neighbor] = true
			frontier.append(neighbor)

	var result := {}
	var current_layer: Array[Vector2i] = []
	for cell in defined:
		for direction in DIRECTIONS:
			if exterior.has(cell + direction):
				result[cell] = true
				current_layer.append(cell)
				break
	for _layer in range(1, maxi(1, thickness)):
		var next_layer: Array[Vector2i] = []
		for cell in defined:
			if result.has(cell):
				continue
			for direction in DIRECTIONS:
				if current_layer.has(cell + direction):
					result[cell] = true
					next_layer.append(cell)
					break
		current_layer = next_layer
		if current_layer.is_empty():
			break
	var ordered: Array[Vector2i] = []
	for cell in result:
		ordered.append(cell)
	ordered.sort_custom(func(a: Vector2i, b: Vector2i):
		return a.y < b.y or (a.y == b.y and a.x < b.x)
	)
	return ordered
