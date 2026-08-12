# core/pathfinder.gd
# ============================================================
# PATHFINDER — Calcul de chemins et de zones accessibles.
# Logique pure. S'appuie sur AStarGrid2D (natif Godot 4).
#
# NOTE : on évite le nom "get_path" car il entre en collision avec
# une méthode native des Nodes. On utilise "find_path" à la place.
# ============================================================

class_name Pathfinder
extends RefCounted

var _grid: GridData
var _astar: AStarGrid2D

func _init(grid_data: GridData) -> void:
	_grid = grid_data
	_setup_astar()

func _setup_astar() -> void:
	_astar = AStarGrid2D.new()
	_astar.region = Rect2i(0, 0, _grid.cols, _grid.rows)
	_astar.cell_size = Vector2(1, 1)
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	_astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	_astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	_astar.update()
	sync()

# ============================================================
# SYNCHRONISATION
# Marque les cases non marchables comme "solides".
# ============================================================

func sync(ignore_unit = null) -> void:
	for x in _grid.cols:
		for y in _grid.rows:
			var pos = Vector2i(x, y)
			var blocked = not _grid.is_walkable(pos, ignore_unit)
			_astar.set_point_solid(pos, blocked)
			_astar.set_point_weight_scale(pos, float(_grid.get_movement_cost(pos)))

# ============================================================
# CALCUL DE CHEMIN  (renommé find_path pour éviter la collision)
# ============================================================

func find_path(
	from: Vector2i,
	to: Vector2i,
	ignore_unit = null,
	synchronize_grid := true
	) -> Array:
	# Le comportement historique reste le defaut. Les outils qui viennent de
	# synchroniser explicitement le graphe peuvent eviter une seconde passe et
	# recalculer le chemin sur l'etat courant de l'AStar.
	if synchronize_grid:
		sync(ignore_unit)
	if not _grid.is_valid(from) or not _grid.is_valid(to):
		return []
	if not _grid.vortex_links().is_empty():
		return _find_path_with_vortex(from, to, ignore_unit)
	var path = _astar.get_id_path(from, to)
	return Array(path)

# ============================================================
# ZONE ACCESSIBLE (BFS)
# ============================================================

func get_reachable(from: Vector2i, max_steps: int, ignore_unit = null) -> Array:
	sync(ignore_unit)
	if not _grid.vortex_links().is_empty():
		return _reachable_with_vortex(from, max_steps, ignore_unit)

	var reachable: Array = []
	var visited: Dictionary = { from: 0 }
	var frontier: Array = [from]
	var directions = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]

	while not frontier.is_empty():
		var current = frontier.pop_front()
		var cost = visited[current]
		if cost >= max_steps:
			continue
		for dir in directions:
			var neighbor = current + dir
			if not _grid.is_valid(neighbor):
				continue
			if visited.has(neighbor):
				continue
			var blocked = not _grid.is_walkable(neighbor, ignore_unit)
			if blocked:
				continue
			visited[neighbor] = cost + 1
			reachable.append(neighbor)
			frontier.append(neighbor)

	return reachable


func is_vortex_edge(from: Vector2i, to: Vector2i) -> bool:
	return _grid.get_vortex_destination(from) == to


func path_movement_cost(path: Array) -> int:
	var cost := 0
	for index in range(1, path.size()):
		var previous := path[index - 1] as Vector2i
		var current := path[index] as Vector2i
		if is_vortex_edge(previous, current):
			continue
		cost += _grid.get_movement_cost(current)
	return cost


func _find_path_with_vortex(
		from: Vector2i,
		to: Vector2i,
		ignore_unit
	) -> Array:
	var search := _vortex_search(from, -1, ignore_unit, to)
	if not (search.get("costs", {}) as Dictionary).has(to):
		return []
	return _reconstruct_vortex_path(from, to, search.get("previous", {}) as Dictionary)


func _reachable_with_vortex(
		from: Vector2i,
		max_cost: int,
		ignore_unit
	) -> Array:
	var search := _vortex_search(from, max_cost, ignore_unit)
	var result: Array = []
	for cell_value in (search.get("costs", {}) as Dictionary):
		var cell := cell_value as Vector2i
		if cell != from:
			result.append(cell)
	result.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y or (a.y == b.y and a.x < b.x)
	)
	return result


func _vortex_search(
		from: Vector2i,
		max_cost: int,
		ignore_unit,
		target := Vector2i(-1, -1)
	) -> Dictionary:
	var costs := {from: 0}
	var previous := {}
	var frontier: Array[Vector2i] = [from]
	var terminal_vortex_destinations := {}
	var directions: Array[Vector2i] = [
		Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT,
	]
	while not frontier.is_empty():
		frontier.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			var cost_a := int(costs.get(a, 2147483647))
			var cost_b := int(costs.get(b, 2147483647))
			return cost_a < cost_b or (cost_a == cost_b and (
				a.y < b.y or (a.y == b.y and a.x < b.x)
			))
		)
		var current: Vector2i = frontier.pop_front()
		if current == target:
			break
		if terminal_vortex_destinations.has(current):
			continue
		for direction in directions:
			var entered: Vector2i = current + direction
			if not _grid.is_walkable(entered, ignore_unit):
				continue
			var destination: Vector2i = entered
			var segment: Array[Vector2i] = [entered]
			var traversed_vortex := false
			if _grid.has_vortex(entered):
				if not _grid.can_traverse_vortex(entered, ignore_unit):
					continue
				destination = _grid.get_vortex_destination(entered)
				segment.append(destination)
				traversed_vortex = true
			var next_cost := int(costs[current]) + _grid.get_movement_cost(entered)
			if max_cost >= 0 and next_cost > max_cost:
				continue
			if costs.has(destination) and int(costs[destination]) <= next_cost:
				continue
			costs[destination] = next_cost
			previous[destination] = {"cell": current, "segment": segment}
			if traversed_vortex:
				terminal_vortex_destinations[destination] = true
			else:
				frontier.append(destination)
	return {"costs": costs, "previous": previous}


func _reconstruct_vortex_path(
		from: Vector2i,
		to: Vector2i,
		previous: Dictionary
	) -> Array:
	var segments: Array = []
	var cursor := to
	while cursor != from:
		if not previous.has(cursor):
			return []
		var record := previous[cursor] as Dictionary
		segments.push_front((record.get("segment", []) as Array).duplicate())
		cursor = record.get("cell", from) as Vector2i
	var path: Array = [from]
	for segment_value in segments:
		for cell_value in segment_value as Array:
			path.append(cell_value as Vector2i)
	return path

# ============================================================
# LIGNE DE VUE (Bresenham)
# ============================================================

func has_line_of_sight(from: Vector2i, to: Vector2i) -> bool:
	var line = trace_line(from, to)
	for i in range(1, line.size() - 1):
		if not _grid.is_transparent(line[i]):
			return false
	return true


func has_projectile_path(from: Vector2i, to: Vector2i) -> bool:
	if not _grid.is_valid(from) or not _grid.is_valid(to):
		return false
	var line = trace_line(from, to)
	for i in range(1, line.size() - 1):
		if not _grid.is_projectile_passable(line[i]):
			return false
	return true


## Expose la meme trace Bresenham au runtime, a Arena Studio et aux tests.
func trace_line(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell in _bresenham(from, to):
		result.append(cell)
	return result


func first_line_blocker(
		from: Vector2i,
		to: Vector2i,
		for_projectile := false
	) -> Vector2i:
	var line := trace_line(from, to)
	for index in range(1, line.size() - 1):
		var cell := line[index]
		var passable := _grid.is_projectile_passable(cell) \
			if for_projectile else _grid.is_transparent(cell)
		if not passable:
			return cell
	return Vector2i(-1, -1)

func _bresenham(from: Vector2i, to: Vector2i) -> Array:
	var result: Array = []
	var x0 = from.x; var y0 = from.y
	var x1 = to.x;   var y1 = to.y
	var dx = abs(x1 - x0); var dy = abs(y1 - y0)
	var sx = 1 if x0 < x1 else -1
	var sy = 1 if y0 < y1 else -1
	var err = dx - dy
	while true:
		result.append(Vector2i(x0, y0))
		if x0 == x1 and y0 == y1:
			break
		var e2 = 2 * err
		if e2 > -dy:
			err -= dy
			x0 += sx
		if e2 < dx:
			err += dx
			y0 += sy
	return result
