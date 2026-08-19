# core/pathfinder.gd
# ============================================================
# PATHFINDER — Calcul pondéré de chemins et de zones accessibles.
# Logique pure. AStarGrid2D conserve l'instantané des cases bloquées ; la
# recherche de coût est un Dijkstra déterministe pour gérer les transitions.
#
# NOTE : on évite le nom "get_path" car il entre en collision avec
# une méthode native des Nodes. On utilise "find_path" à la place.
# ============================================================

class_name Pathfinder
extends RefCounted

enum MovementType {
	VOLUNTARY,
	FORCED,
	TELEPORT,
}

var _grid: GridData
var _astar: AStarGrid2D
var voluntary_cost_modifier: Callable


func set_voluntary_cost_modifier(modifier: Callable) -> void:
	voluntary_cost_modifier = modifier

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
	synchronize_grid := true,
	movement_type: MovementType = MovementType.VOLUNTARY
	) -> Array:
	if synchronize_grid:
		sync(ignore_unit)
	if not _grid.is_valid(from) or not _grid.is_valid(to):
		return []
	if from == to:
		return [from]
	var mover := ignore_unit as Unit
	var search := _movement_search(from, -1, mover, to, movement_type)
	if not (search.get("costs", {}) as Dictionary).has(to):
		return []
	return _reconstruct_path(from, to, search.get("previous", {}) as Dictionary)

# ============================================================
# ZONE ACCESSIBLE (COÛT PONDÉRÉ)
# ============================================================

func get_reachable(
	from: Vector2i,
	max_cost: int,
	ignore_unit = null,
	movement_type: MovementType = MovementType.VOLUNTARY,
	synchronize_grid := true
	) -> Array:
	if synchronize_grid:
		sync(ignore_unit)
	if not _grid.is_valid(from) or max_cost < 0:
		return []
	var search := _movement_search(
		from,
		max_cost,
		ignore_unit as Unit,
		Vector2i(-1, -1),
		movement_type,
	)
	return get_reachable_from_movement_map(from, search, max_cost)


## Capture l'arbre complet des meilleurs chemins depuis une origine. L'IA peut
## ensuite reconstruire plusieurs chemins ou portees sans recalculer Dijkstra.
func build_movement_map(
		from: Vector2i,
		max_cost: int = -1,
		ignore_unit = null,
		movement_type: MovementType = MovementType.VOLUNTARY,
		synchronize_grid := true
	) -> Dictionary:
	if synchronize_grid:
		sync(ignore_unit)
	if not _grid.is_valid(from) or max_cost < -1:
		return {}
	return _movement_search(
		from,
		max_cost,
		ignore_unit as Unit,
		Vector2i(-1, -1),
		movement_type,
	)


func path_from_movement_map(
		from: Vector2i,
		to: Vector2i,
		movement_map: Dictionary
	) -> Array:
	if from == to:
		return [from]
	var costs := movement_map.get("costs", {}) as Dictionary
	if not costs.has(to):
		return []
	return _reconstruct_path(
		from,
		to,
		movement_map.get("previous", {}) as Dictionary,
	)


func get_reachable_from_movement_map(
		from: Vector2i,
		movement_map: Dictionary,
		max_cost: int
	) -> Array:
	var reachable: Array = []
	var costs := movement_map.get("costs", {}) as Dictionary
	for cell_value in costs:
		var cell := cell_value as Vector2i
		if cell != from and int(costs.get(cell, 2147483647)) <= max_cost:
			reachable.append(cell)
	reachable.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y or (a.y == b.y and a.x < b.x)
	)
	return reachable


func is_vortex_edge(from: Vector2i, to: Vector2i) -> bool:
	return _grid.get_vortex_destination(from) == to


func get_movement_cost(
		unit: Unit,
		from_cell: Vector2i,
		to_cell: Vector2i,
		movement_type: MovementType = MovementType.VOLUNTARY
	) -> int:
	if is_vortex_edge(from_cell, to_cell):
		return 0
	var base_cost := _grid.get_movement_cost(to_cell)
	if movement_type != MovementType.VOLUNTARY:
		return base_cost
	return _apply_voluntary_cost_modifier(
		unit, from_cell, to_cell,
		base_cost + get_disengagement_cost(unit, from_cell, to_cell),
		movement_type,
	)


func get_disengagement_cost(
		unit: Unit,
		from_cell: Vector2i,
		to_cell: Vector2i
	) -> int:
	var result := 0
	if unit == null or from_cell == to_cell:
		return result
	for controller in _eligible_controllers(unit):
		if _grid.are_adjacent(controller.grid_pos, from_cell) \
				and not _grid.are_adjacent(controller.grid_pos, to_cell):
			result = maxi(result, controller.get_control_cost())
	return result


func get_engaging_controllers(
		unit: Unit,
		cell: Vector2i = Vector2i(-1, -1)
	) -> Array[Unit]:
	var result: Array[Unit] = []
	if unit == null:
		return result
	var inspected_cell := unit.grid_pos if cell == Vector2i(-1, -1) else cell
	for controller_value in _grid.get_units():
		var controller := controller_value as Unit
		if controller == null \
				or not controller.can_exert_control() \
				or not controller.is_hostile_to(unit):
			continue
		if _grid.are_adjacent(controller.grid_pos, inspected_cell):
			result.append(controller)
	result.sort_custom(func(a: Unit, b: Unit) -> bool:
		return a.get_runtime_stable_id() < b.get_runtime_stable_id()
	)
	return result


func get_controllers_left(
		unit: Unit,
		from_cell: Vector2i,
		to_cell: Vector2i
	) -> Array[Unit]:
	var result: Array[Unit] = []
	if unit == null or from_cell == to_cell:
		return result
	for controller in get_engaging_controllers(unit, from_cell):
		if not _grid.are_adjacent(controller.grid_pos, to_cell):
			result.append(controller)
	return result


func path_movement_cost(
		path: Array,
		unit: Unit = null,
		movement_type: MovementType = MovementType.VOLUNTARY
	) -> int:
	return int(path_cost_breakdown(path, unit, movement_type).get("total", 0))


func path_cost_breakdown(
		path: Array,
		unit: Unit = null,
		movement_type: MovementType = MovementType.VOLUNTARY
	) -> Dictionary:
	var mover := _resolve_path_unit(path, unit)
	var result := {
		"total": 0,
		"unmodified_total": 0,
		"base": 0,
		"disengagement": 0,
		"relic_discount": 0,
		"disengagement_cells": [] as Array[Vector2i],
		"steps": [],
	}
	for index in range(1, path.size()):
		var previous := path[index - 1] as Vector2i
		var current := path[index] as Vector2i
		var base_cost := 0 if is_vortex_edge(previous, current) \
			else _grid.get_movement_cost(current)
		var disengagement_cost := 0
		if movement_type == MovementType.VOLUNTARY \
				and not is_vortex_edge(previous, current):
			disengagement_cost = get_disengagement_cost(
				mover, previous, current
			)
		var unmodified_cost := base_cost + disengagement_cost
		var transition_cost := _apply_voluntary_cost_modifier(
			mover, previous, current, unmodified_cost, movement_type
		)
		result.total = int(result.total) + transition_cost
		result.unmodified_total = int(result.unmodified_total) + unmodified_cost
		result.base = int(result.base) + base_cost
		result.disengagement = int(result.disengagement) + disengagement_cost
		result.relic_discount = int(result.relic_discount) + unmodified_cost - transition_cost
		if disengagement_cost > 0:
			(result.disengagement_cells as Array[Vector2i]).append(previous)
		(result.steps as Array).append({
			"from": previous,
			"to": current,
			"base": base_cost,
			"disengagement": disengagement_cost,
			"relic_discount": unmodified_cost - transition_cost,
			"total": transition_cost,
		})
	return result


func trim_path_to_cost(
		path: Array,
		max_cost: int,
		unit: Unit = null,
		movement_type: MovementType = MovementType.VOLUNTARY
	) -> Array:
	if path.is_empty():
		return []
	var mover := _resolve_path_unit(path, unit)
	var result: Array = [path[0]]
	var spent := 0
	for index in range(1, path.size()):
		var previous := path[index - 1] as Vector2i
		var current := path[index] as Vector2i
		var transition_cost := get_movement_cost(
			mover, previous, current, movement_type
		)
		if spent + transition_cost > max_cost:
			break
		spent += transition_cost
		result.append(current)
	return result


## Construit en une seule passe le cout minimal permettant d'atteindre l'une
## des cellules de destination depuis chaque case. Ce champ inverse evite a
## l'IA de relancer un chemin complet pour chaque destination envisagee.
##
## Les vortex forment des aretes dirigees avec une destination implicite. Leur
## graphe inverse demande de conserver les segments de teleportation ; dans ce
## cas rare, un dictionnaire vide demande explicitement au client d'utiliser
## find_path(), qui reste la reference fonctionnelle.
func build_cost_field_to(
		destination_cells: Array,
		unit: Unit = null,
		movement_type: MovementType = MovementType.VOLUNTARY,
		synchronize_grid := true
	) -> Dictionary:
	if synchronize_grid:
		sync(unit)
	if not _grid.vortex_links().is_empty():
		return {}
	var costs := {}
	var frontier: Array = []
	for destination_value in destination_cells:
		if not destination_value is Vector2i:
			continue
		var destination := destination_value as Vector2i
		if not _grid.is_valid(destination) or _astar.is_point_solid(destination) \
				or costs.has(destination):
			continue
		costs[destination] = 0
		_heap_push(frontier, destination, 0)
	var controllers: Array[Unit] = []
	if movement_type == MovementType.VOLUNTARY:
		controllers = _eligible_controllers(unit)
	var directions: Array[Vector2i] = [
		Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT,
	]
	while not frontier.is_empty():
		var entry := _heap_pop(frontier)
		var current := entry.cell as Vector2i
		var current_cost := int(entry.cost)
		if current_cost != int(costs.get(current, 2147483647)):
			continue
		for direction in directions:
			var predecessor := current + direction
			if not _grid.is_valid(predecessor) \
					or _astar.is_point_solid(predecessor):
				continue
			var next_cost := current_cost + _movement_cost_with_controllers(
				unit,
				predecessor,
				current,
				movement_type,
				controllers,
			)
			if costs.has(predecessor) and int(costs[predecessor]) <= next_cost:
				continue
			costs[predecessor] = next_cost
			_heap_push(frontier, predecessor, next_cost)
	return costs


func _resolve_path_unit(path: Array, explicit_unit: Unit) -> Unit:
	if explicit_unit != null:
		return explicit_unit
	if path.is_empty() or not path[0] is Vector2i:
		return null
	return _grid.get_unit(path[0] as Vector2i) as Unit


func _movement_search(
		from: Vector2i,
		max_cost: int,
		mover: Unit,
		target := Vector2i(-1, -1),
		movement_type: MovementType = MovementType.VOLUNTARY
	) -> Dictionary:
	var costs := {from: 0}
	var previous := {}
	var frontier: Array = []
	_heap_push(frontier, from, 0)
	var terminal_vortex_destinations := {}
	var controllers: Array[Unit] = []
	if movement_type == MovementType.VOLUNTARY:
		controllers = _eligible_controllers(mover)
	var directions: Array[Vector2i] = [
		Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT,
	]
	while not frontier.is_empty():
		var entry := _heap_pop(frontier)
		var current := entry.cell as Vector2i
		var current_cost := int(entry.cost)
		if current_cost != int(costs.get(current, 2147483647)):
			continue
		if current == target:
			break
		if terminal_vortex_destinations.has(current):
			continue
		for direction in directions:
			var entered: Vector2i = current + direction
			if not _grid.is_valid(entered) or _astar.is_point_solid(entered):
				continue
			var destination: Vector2i = entered
			var segment: Array[Vector2i] = [entered]
			var traversed_vortex := false
			if _grid.has_vortex(entered):
				var network_cells := _grid.get_vortex_network_cells(entered)
				var linked_destination := _grid.get_vortex_destination(entered)
				if linked_destination != Vector2i(-1, -1):
					if (not network_cells.is_empty() \
							and not _grid.can_unit_use_vortex_network(entered, mover)) \
							or not _grid.can_traverse_vortex(entered, mover):
						continue
					destination = linked_destination
					segment.append(destination)
					traversed_vortex = true
				elif network_cells.size() >= 2:
					traversed_vortex = true
			var next_cost := current_cost + _movement_cost_with_controllers(
				mover,
				current,
				entered,
				movement_type,
				controllers,
			)
			if max_cost >= 0 and next_cost > max_cost:
				continue
			if costs.has(destination) and int(costs[destination]) <= next_cost:
				continue
			costs[destination] = next_cost
			previous[destination] = {"cell": current, "segment": segment}
			if traversed_vortex:
				terminal_vortex_destinations[destination] = true
			else:
				_heap_push(frontier, destination, next_cost)
	return {"costs": costs, "previous": previous}


func _eligible_controllers(unit: Unit) -> Array[Unit]:
	var result: Array[Unit] = []
	if unit == null:
		return result
	for controller_value in _grid.get_units():
		var controller := controller_value as Unit
		if controller == null \
				or not controller.can_exert_control() \
				or not controller.is_hostile_to(unit):
			continue
		result.append(controller)
	return result


func _movement_cost_with_controllers(
		unit: Unit,
		from_cell: Vector2i,
		to_cell: Vector2i,
		movement_type: MovementType,
		controllers: Array[Unit]
	) -> int:
	if is_vortex_edge(from_cell, to_cell):
		return 0
	var result := _grid.get_movement_cost(to_cell)
	if movement_type != MovementType.VOLUNTARY or unit == null:
		return result
	var disengagement_cost := 0
	for controller in controllers:
		if _grid.are_adjacent(controller.grid_pos, from_cell) \
				and not _grid.are_adjacent(controller.grid_pos, to_cell):
			disengagement_cost = maxi(
				disengagement_cost,
				controller.get_control_cost(),
			)
	return _apply_voluntary_cost_modifier(
		unit, from_cell, to_cell, result + disengagement_cost, movement_type
	)


func _apply_voluntary_cost_modifier(
		unit: Unit,
		from_cell: Vector2i,
		to_cell: Vector2i,
		cost: int,
		movement_type: MovementType
	) -> int:
	if movement_type != MovementType.VOLUNTARY \
			or unit == null or not voluntary_cost_modifier.is_valid():
		return maxi(0, cost)
	return maxi(0, int(voluntary_cost_modifier.call(unit, from_cell, to_cell, cost)))


func _heap_push(heap: Array, cell: Vector2i, cost: int) -> void:
	heap.append({"cell": cell, "cost": cost})
	var index := heap.size() - 1
	while index > 0:
		var parent := int((index - 1) / 2)
		if not _heap_entry_less(heap[index], heap[parent]):
			break
		var swap = heap[parent]
		heap[parent] = heap[index]
		heap[index] = swap
		index = parent


func _heap_pop(heap: Array) -> Dictionary:
	var result := heap[0] as Dictionary
	var tail = heap.pop_back()
	if heap.is_empty():
		return result
	heap[0] = tail
	var index := 0
	while true:
		var left := index * 2 + 1
		if left >= heap.size():
			break
		var right := left + 1
		var smallest := left
		if right < heap.size() and _heap_entry_less(heap[right], heap[left]):
			smallest = right
		if not _heap_entry_less(heap[smallest], heap[index]):
			break
		var swap = heap[index]
		heap[index] = heap[smallest]
		heap[smallest] = swap
		index = smallest
	return result


func _heap_entry_less(a: Dictionary, b: Dictionary) -> bool:
	var cost_a := int(a.cost)
	var cost_b := int(b.cost)
	if cost_a != cost_b:
		return cost_a < cost_b
	var cell_a := a.cell as Vector2i
	var cell_b := b.cell as Vector2i
	return cell_a.y < cell_b.y or (cell_a.y == cell_b.y and cell_a.x < cell_b.x)


func _reconstruct_path(
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
