@tool
class_name ArenaTacticalMetricsService
extends RefCounted

const DIRECTIONS: Array[Vector2i] = [
	Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN,
]

static var _cache := {}


static func analyze(
		arena: ArenaDefinition,
		runtime_state: ArenaRuntimeState = null
	) -> Dictionary:
	if arena == null:
		return {"ok": false, "error": "arena_missing"}
	var cache_key := ""
	if runtime_state == null:
		cache_key = ArenaSnapshotService.arena_fingerprint(arena)
		if _cache.has(cache_key):
			var cached := (_cache[cache_key] as Dictionary).duplicate(true)
			cached["cache_hit"] = true
			return cached
	var state := runtime_state if runtime_state != null \
		else ArenaRuntimeProjectionService.build(arena)
	if state == null or state.grid == null:
		return {"ok": false, "error": "runtime_projection_failed"}
	var grid := _analysis_grid(arena, state.grid)
	var cells := _walkable_cells(grid)
	var adjacency := _adjacency(cells)
	var components := _components(cells, adjacency)
	var topology := _topology(arena, cells, adjacency, components)
	var camps := _camp_metrics(arena, grid, adjacency)
	var spawn_metrics := _spawn_metrics(arena)
	var collision_metrics := _collision_metrics(arena, adjacency, camps)
	var result := {
		"ok": true,
		"topology": topology,
		"camps": camps,
		"contact": {
			"turns_at_3_pm": _contact_turns(int(camps.get("minimum_distance", -1)), 3),
			"turns_at_5_pm": _contact_turns(int(camps.get("minimum_distance", -1)), 5),
			"turns_with_charge": null,
			"first_significant_action_by_hero": camps.get(
				"first_significant_action_by_hero", {}
			),
		},
		"ranges": {
			"status": "RUN_DATA_REQUIRED",
			"coverage_by_spell": {},
			"average_coverage": 0.0,
			"coverage_with_los": float(camps.get("los_ratio", 0.0)),
			"coverage_without_los": float(camps.get("connected_ratio", 0.0)),
			"unreachable_cells": topology.get("unreachable_cells", []),
			"near_global_ranges": [],
			"coverage_by_spawn": {},
		},
		"collisions_and_chokepoints": collision_metrics,
		"spawns": spawn_metrics,
		"encounter": _encounter_metrics(arena),
	}
	result["cache_hit"] = false
	if runtime_state == null:
		_cache[cache_key] = result.duplicate(true)
	return result


static func clear_cache() -> void:
	_cache.clear()


static func cache_size() -> int:
	return _cache.size()


static func _analysis_grid(arena: ArenaDefinition, source: GridData) -> GridData:
	var grid := GridData.new(source.cols, source.rows)
	for y in range(source.rows):
		for x in range(source.cols):
			var cell := Vector2i(x, y)
			grid.set_type(cell, source.get_type(cell))
	# Les murs sont des blockers dynamiques dans la vraie scene. L'analyse pure
	# les projette ici sans toucher a la Resource ni aux regles de gameplay.
	for obstacle in arena.obstacles:
		if obstacle == null or not obstacle.blocks_movement or not grid.is_valid(obstacle.cell):
			continue
		grid.set_type(
			obstacle.cell,
			GridData.CellType.WALL if obstacle.blocks_line_of_sight \
			else GridData.CellType.HOLE
		)
	return grid


static func _walkable_cells(grid: GridData) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y in range(grid.rows):
		for x in range(grid.cols):
			var cell := Vector2i(x, y)
			if bool(GridData.PROPERTIES[grid.get_type(cell)].walkable):
				result.append(cell)
	return result


static func _adjacency(cells: Array[Vector2i]) -> Dictionary:
	var cell_set := {}
	for cell in cells:
		cell_set[cell] = true
	var result := {}
	for cell in cells:
		var neighbors: Array[Vector2i] = []
		for direction in DIRECTIONS:
			var neighbor := cell + direction
			if cell_set.has(neighbor):
				neighbors.append(neighbor)
		result[cell] = neighbors
	return result


static func _components(cells: Array[Vector2i], adjacency: Dictionary) -> Array:
	var remaining := {}
	for cell in cells:
		remaining[cell] = true
	var result: Array = []
	while not remaining.is_empty():
		var start: Vector2i = remaining.keys()[0]
		var component: Array[Vector2i] = []
		var queue: Array[Vector2i] = [start]
		remaining.erase(start)
		while not queue.is_empty():
			var current := queue.pop_front()
			component.append(current)
			for neighbor in adjacency.get(current, []):
				if remaining.has(neighbor):
					remaining.erase(neighbor)
					queue.append(neighbor)
		result.append(component)
	result.sort_custom(func(a: Array, b: Array) -> bool: return a.size() > b.size())
	return result


static func _topology(
		arena: ArenaDefinition,
		cells: Array[Vector2i],
		adjacency: Dictionary,
		components: Array
	) -> Dictionary:
	var distance_distribution := {}
	var eccentricities: Array[int] = []
	var diameter := 0
	for index in range(cells.size()):
		var distances := _distances_from(cells[index], adjacency)
		var eccentricity := 0
		for target_index in range(index + 1, cells.size()):
			var target := cells[target_index]
			if not distances.has(target):
				continue
			var distance := int(distances[target])
			diameter = maxi(diameter, distance)
			eccentricity = maxi(eccentricity, distance)
			var key := str(distance)
			distance_distribution[key] = int(distance_distribution.get(key, 0)) + 1
		if not distances.is_empty():
			for distance_value in distances.values():
				eccentricity = maxi(eccentricity, int(distance_value))
			eccentricities.append(eccentricity)
	var radius := 0
	if not eccentricities.is_empty():
		radius = eccentricities.min()
	var dead_ends: Array[Vector2i] = []
	var corridors: Array[Vector2i] = []
	for cell in cells:
		var neighbors: Array = adjacency.get(cell, [])
		if neighbors.size() == 1:
			dead_ends.append(cell)
		elif neighbors.size() == 2 \
				and (neighbors[0] as Vector2i) + (neighbors[1] as Vector2i) == cell * 2:
			corridors.append(cell)
	var tarjan := _tarjan(adjacency)
	var intentional: Array[Vector2i] = []
	var invalid_intentional: Array[Vector2i] = []
	for cell in arena.intentionally_isolated_cells:
		if cells.has(cell):
			intentional.append(cell)
		else:
			invalid_intentional.append(cell)
	var blocking_obstacles := arena.obstacles.filter(func(value):
		return value != null and value.blocks_movement
	).size()
	var denominator := cells.size() + blocking_obstacles
	var largest_component: Array = components[0] if not components.is_empty() else []
	var unreachable: Array[Vector2i] = []
	if not components.is_empty():
		for component_index in range(1, components.size()):
			unreachable.append_array(components[component_index])
	return {
		"accessible_cells": cells.size(),
		"components": components.size(),
		"component_sizes": components.map(func(value): return value.size()),
		"largest_component_size": largest_component.size(),
		"diameter": diameter,
		"radius": radius,
		"distance_distribution": distance_distribution,
		"dead_ends": dead_ends,
		"dead_end_count": dead_ends.size(),
		"bridges": tarjan.bridges,
		"bridge_count": tarjan.bridges.size(),
		"articulation_points": tarjan.articulation_points,
		"articulation_point_count": tarjan.articulation_points.size(),
		"width_one_corridors": corridors,
		"width_one_corridor_count": corridors.size(),
		"enclosable_zones": tarjan.articulation_points.size(),
		"intentional_isolated_cells": intentional,
		"invalid_intentional_isolated_cells": invalid_intentional,
		"obstacle_density": float(blocking_obstacles) / float(maxi(1, denominator)),
		"unreachable_cells": unreachable,
	}


static func _tarjan(adjacency: Dictionary) -> Dictionary:
	var discovery := {}
	var low := {}
	var parent := {}
	var child_count := {}
	var articulation := {}
	var bridges: Array = []
	var clock := 0
	# Une pile explicite évite le dépassement de pile GDScript sur les fixtures
	# 64×64 tout en conservant exactement les invariants de Tarjan.
	for root in adjacency:
		if discovery.has(root):
			continue
		clock += 1
		discovery[root] = clock
		low[root] = clock
		child_count[root] = 0
		var stack: Array[Dictionary] = [{
			"node": root,
			"neighbors": (adjacency.get(root, []) as Array).duplicate(),
			"next_index": 0,
		}]
		while not stack.is_empty():
			var frame_index := stack.size() - 1
			var frame := stack[frame_index]
			var node: Vector2i = frame.node
			var neighbors := frame.neighbors as Array
			var next_index := int(frame.next_index)
			if next_index < neighbors.size():
				var neighbor: Vector2i = neighbors[next_index]
				frame.next_index = next_index + 1
				stack[frame_index] = frame
				if not discovery.has(neighbor):
					parent[neighbor] = node
					child_count[node] = int(child_count.get(node, 0)) + 1
					child_count[neighbor] = 0
					clock += 1
					discovery[neighbor] = clock
					low[neighbor] = clock
					stack.append({
						"node": neighbor,
						"neighbors": (adjacency.get(neighbor, []) as Array).duplicate(),
						"next_index": 0,
					})
				elif not parent.has(node) or neighbor != parent[node]:
					low[node] = mini(int(low[node]), int(discovery[neighbor]))
				continue
			stack.pop_back()
			if parent.has(node):
				var parent_node: Vector2i = parent[node]
				low[parent_node] = mini(int(low[parent_node]), int(low[node]))
				if int(low[node]) > int(discovery[parent_node]):
					bridges.append([parent_node, node])
				if parent.has(parent_node) \
						and int(low[node]) >= int(discovery[parent_node]):
					articulation[parent_node] = true
			elif int(child_count.get(node, 0)) > 1:
				articulation[node] = true
	var points: Array[Vector2i] = []
	for point in articulation:
		points.append(point)
	points.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y or (a.y == b.y and a.x < b.x)
	)
	return {"articulation_points": points, "bridges": bridges}


static func _distances_from(start: Vector2i, adjacency: Dictionary) -> Dictionary:
	if not adjacency.has(start):
		return {}
	var distances := {start: 0}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var current := queue.pop_front()
		for neighbor in adjacency.get(current, []):
			if distances.has(neighbor):
				continue
			distances[neighbor] = int(distances[current]) + 1
			queue.append(neighbor)
	return distances


static func _camp_metrics(
		arena: ArenaDefinition,
		grid: GridData,
		adjacency: Dictionary
	) -> Dictionary:
	var heroes: Array[Vector2i] = []
	var enemies: Array[Vector2i] = []
	for spawn in arena.spawns:
		if spawn == null:
			continue
		if spawn.is_hero():
			heroes.append(spawn.cell)
		elif spawn.is_enemy():
			enemies.append(spawn.cell)
	var pairs: Array[Dictionary] = []
	var distances: Array[int] = []
	var connected := 0
	var line_of_sight := 0
	var first_action := {}
	var pathfinder := Pathfinder.new(grid)
	for hero in heroes:
		var hero_distances := _distances_from(hero, adjacency)
		var hero_minimum := -1
		for enemy in enemies:
			var distance := int(hero_distances.get(enemy, -1))
			var los := pathfinder.has_line_of_sight(hero, enemy)
			pairs.append({
				"hero": hero,
				"enemy": enemy,
				"distance": distance,
				"line_of_sight": los,
			})
			if distance >= 0:
				distances.append(distance)
				connected += 1
				hero_minimum = distance if hero_minimum < 0 else mini(hero_minimum, distance)
			if los:
				line_of_sight += 1
		first_action[_cell_key(hero)] = hero_minimum
	distances.sort()
	var minimum_pair := _pair_for_distance(pairs, distances[0] if not distances.is_empty() else -1)
	var maximum_pair := _pair_for_distance(pairs, distances[-1] if not distances.is_empty() else -1)
	var total := 0.0
	for distance in distances:
		total += distance
	var pair_count := pairs.size()
	return {
		"hero_spawn_pool": heroes,
		"enemy_spawn_pool": enemies,
		"pair_count": pair_count,
		"connected_pair_count": connected,
		"unreachable_pair_count": pair_count - connected,
		"connected_ratio": float(connected) / float(maxi(1, pair_count)),
		"minimum_distance": distances[0] if not distances.is_empty() else -1,
		"median_distance": _median(distances),
		"average_distance": total / float(maxi(1, distances.size())),
		"p90_distance": _percentile(distances, 0.9),
		"maximum_distance": distances[-1] if not distances.is_empty() else -1,
		"minimum_positions": minimum_pair,
		"maximum_positions": maximum_pair,
		"pairs": pairs,
		"los_pair_count": line_of_sight,
		"los_ratio": float(line_of_sight) / float(maxi(1, pair_count)),
		"first_significant_action_by_hero": first_action,
	}


static func _spawn_metrics(arena: ArenaDefinition) -> Dictionary:
	var required_heroes := 0
	var hero_pool := 0
	var enemies := 0
	var groups := 0
	var summon_zones := 0
	for spawn in arena.spawns:
		if spawn == null:
			continue
		match spawn.kind:
			ArenaSpawnDefinition.Kind.HERO_1, \
			ArenaSpawnDefinition.Kind.HERO_2, \
			ArenaSpawnDefinition.Kind.HERO_3:
				hero_pool += 1
				if spawn.required:
					required_heroes += 1
			ArenaSpawnDefinition.Kind.ENEMY:
				enemies += 1
			ArenaSpawnDefinition.Kind.ENEMY_GROUP:
				groups += 1
			ArenaSpawnDefinition.Kind.SUMMON_ZONE:
				summon_zones += 1
	return {
		"required_hero_spawns": required_heroes,
		"hero_pool": hero_pool,
		"enemy_spawns": enemies,
		"enemy_groups": groups,
		"summon_zones": summon_zones,
	}


static func _collision_metrics(
		arena: ArenaDefinition,
		adjacency: Dictionary,
		camps: Dictionary
	) -> Dictionary:
	var push_collision_positions: Array[Vector2i] = []
	for cell in adjacency:
		if (adjacency[cell] as Array).size() <= 2:
			push_collision_positions.append(cell)
	var articulations: Array = _tarjan(adjacency).articulation_points
	var minimum_routes := 0
	for pair in camps.get("pairs", []):
		if int(pair.distance) < 0:
			continue
		var hero_degree := (adjacency.get(pair.hero, []) as Array).size()
		var enemy_degree := (adjacency.get(pair.enemy, []) as Array).size()
		var estimate := mini(hero_degree, enemy_degree)
		minimum_routes = estimate if minimum_routes == 0 else mini(minimum_routes, estimate)
	var exploitable_obstacles: Array[Vector2i] = []
	for obstacle in arena.obstacles:
		if obstacle != null and obstacle.blocks_push:
			exploitable_obstacles.append(obstacle.cell)
	return {
		"push_collision_positions": push_collision_positions,
		"exploitable_obstacles": exploitable_obstacles,
		"chokepoints_with_alternative": [],
		"chokepoints_without_alternative": articulations,
		"dominant_cells": articulations,
		"route_count_between_camps": minimum_routes,
	}


static func _encounter_metrics(arena: ArenaDefinition) -> Dictionary:
	if arena.encounter_definition == null:
		return {"available": false}
	var count := 0
	if arena.encounter_definition.has_method("get_initial_enemy_count"):
		count = int(arena.encounter_definition.get_initial_enemy_count())
	elif arena.encounter_definition.has_method("expanded_roster"):
		count = (arena.encounter_definition.expanded_roster() as Array).size()
	var spawn_capacity := 0
	for spawn in arena.spawns:
		if spawn != null and spawn.is_enemy():
			spawn_capacity += 1
	return {
		"available": true,
		"placeable_enemy_count": count,
		"spawn_capacity": spawn_capacity,
		"pre_hero_activation_budget": "ENCOUNTER_SIMULATION_REQUIRED",
		"roster_collisions": [],
		"saturation_zones": [],
	}


static func _pair_for_distance(pairs: Array[Dictionary], distance: int) -> Dictionary:
	for pair in pairs:
		if int(pair.distance) == distance:
			return {"hero": pair.hero, "enemy": pair.enemy}
	return {}


static func _median(values: Array[int]) -> float:
	if values.is_empty():
		return -1.0
	var middle := values.size() / 2
	if values.size() % 2 == 1:
		return float(values[middle])
	return (float(values[middle - 1]) + float(values[middle])) / 2.0


static func _percentile(values: Array[int], ratio: float) -> int:
	if values.is_empty():
		return -1
	var index := clampi(ceili(ratio * values.size()) - 1, 0, values.size() - 1)
	return values[index]


static func _contact_turns(distance: int, movement_points: int) -> int:
	return ceili(float(distance) / float(movement_points)) \
		if distance >= 0 and movement_points > 0 else -1


static func _cell_key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]
