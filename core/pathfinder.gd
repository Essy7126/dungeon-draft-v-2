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
			var blocked = not GridData.PROPERTIES[_grid.get_type(pos)]["walkable"]
			if _grid.has_unit(pos) and _grid.get_unit(pos) != ignore_unit:
				blocked = true
			_astar.set_point_solid(pos, blocked)

# ============================================================
# CALCUL DE CHEMIN  (renommé find_path pour éviter la collision)
# ============================================================

func find_path(from: Vector2i, to: Vector2i, ignore_unit = null) -> Array:
	sync(ignore_unit)
	if not _grid.is_valid(from) or not _grid.is_valid(to):
		return []
	var path = _astar.get_id_path(from, to)
	return Array(path)

# ============================================================
# ZONE ACCESSIBLE (BFS)
# ============================================================

func get_reachable(from: Vector2i, max_steps: int, ignore_unit = null) -> Array:
	sync(ignore_unit)

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
			var blocked = not GridData.PROPERTIES[_grid.get_type(neighbor)]["walkable"]
			if _grid.has_unit(neighbor) and _grid.get_unit(neighbor) != ignore_unit:
				blocked = true
			if blocked:
				continue
			visited[neighbor] = cost + 1
			reachable.append(neighbor)
			frontier.append(neighbor)

	return reachable

# ============================================================
# LIGNE DE VUE (Bresenham)
# ============================================================

func has_line_of_sight(from: Vector2i, to: Vector2i) -> bool:
	var line = _bresenham(from, to)
	for i in range(1, line.size() - 1):
		if not _grid.is_transparent(line[i]):
			return false
	return true

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
