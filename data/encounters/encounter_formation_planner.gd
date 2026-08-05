@tool
class_name EncounterFormationPlanner
extends RefCounted

const DIRECTIONS := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]

var _grid: GridData
var _pathfinder: Pathfinder
var _hero_distance_cache: Dictionary = {}
var _hero_distance_cache_key := ""


func _init(grid: GridData, pathfinder: Pathfinder) -> void:
	_grid = grid
	_pathfinder = pathfinder


func build_plan(
		definition: EncounterDefinition,
		hero_spawn_cells: Array,
		preferred_enemy_cells: Array,
		run_seed: int
	) -> Dictionary:
	if definition == null or not definition.is_valid():
		return _failure(&"definition_invalid")
	var heroes := _valid_walkable_cells(hero_spawn_cells)
	if heroes.is_empty():
		return _failure(&"hero_spawn_missing")
	_ensure_hero_distance_cache(heroes)
	var formations := definition.formation_profiles.duplicate()
	_rotate(formations, posmod(run_seed + definition.room_index, formations.size()))
	var attempts := mini(definition.maximum_formation_attempts, formations.size())
	var last_reason: StringName = &"formation_unavailable"
	for attempt in attempts:
		var formation_id := StringName(formations[attempt])
		var candidate := _build_candidate(
			definition,
			heroes,
			preferred_enemy_cells,
			run_seed,
			formation_id,
		)
		var validation := validate_plan(definition, candidate, heroes)
		if validation.get("valid", false):
			candidate["valid"] = true
			candidate["formation_id"] = formation_id
			candidate["attempt"] = attempt
			return candidate
		last_reason = StringName(validation.get("reason", &"formation_invalid"))
	return _failure(last_reason)


func validate_plan(
		definition: EncounterDefinition,
		plan: Dictionary,
		hero_spawn_cells: Array
	) -> Dictionary:
	_ensure_hero_distance_cache(hero_spawn_cells)
	var placements: Array = plan.get("placements", [])
	if placements.size() != definition.get_initial_enemy_count():
		return _failure(&"incomplete_roster")
	var occupied := {}
	for placement_value in placements:
		var placement := placement_value as Dictionary
		var cell: Vector2i = placement.get("cell", Vector2i(-1, -1))
		var data := placement.get("unit_data") as UnitData
		if data == null or not _grid.is_valid(cell) \
				or not _grid.is_walkable(cell) or occupied.has(cell) \
				or definition.forbidden_initial_spawn_cells.has(cell):
			return _failure(&"invalid_or_overlapping_cell")
		occupied[cell] = true
		var role := data.tactical_role_id
		var distance := _minimum_path_distance(cell, hero_spawn_cells)
		var minimum := int(definition.minimum_path_distance_by_role.get(role, 0))
		if distance < minimum:
			return _failure(&"role_too_close")
		if role == &"skeleton_normal" and _is_adjacent_to_any(cell, hero_spawn_cells):
			return _failure(&"normal_adjacent_to_hero")
	for placement_value in placements:
		var placement := placement_value as Dictionary
		var data := placement.get("unit_data") as UnitData
		if data == null or data.tactical_role_id != &"skeleton_centurion":
			continue
		var free_neighbors := 0
		var cell: Vector2i = placement["cell"]
		for direction in DIRECTIONS:
			var neighbor: Vector2i = cell + (direction as Vector2i)
			if _grid.is_valid(neighbor) and _grid.is_walkable(neighbor) \
					and not occupied.has(neighbor):
				free_neighbors += 1
		if free_neighbors < definition.summon_free_neighbor_requirement:
			return _failure(&"centurion_without_summon_cell")
	return {"valid": true, "reason": &""}


func _build_candidate(
		definition: EncounterDefinition,
		hero_cells: Array,
		preferred_cells: Array,
		run_seed: int,
		formation_id: StringName
	) -> Dictionary:
	var placements: Array = []
	var occupied := {}
	var roster := definition.expanded_roster()
	roster.sort_custom(func(a: UnitData, b: UnitData) -> bool:
		var priority := {
			&"skeleton_centurion": 0,
			&"skeleton_chief": 1,
			&"skeleton_normal": 2,
		}
		var pa := int(priority.get(a.tactical_role_id, 3))
		var pb := int(priority.get(b.tactical_role_id, 3))
		if pa != pb:
			return pa < pb
		return str(a.get_effective_unit_id()) < str(b.get_effective_unit_id())
	)
	var all_cells := _all_walkable_cells()
	for roster_index in range(roster.size()):
		var data := roster[roster_index] as UnitData
		var scored: Array = []
		for cell_value in all_cells:
			var cell := cell_value as Vector2i
			if occupied.has(cell) or definition.forbidden_initial_spawn_cells.has(cell):
				continue
			var distance := _minimum_path_distance(cell, hero_cells)
			var minimum := int(definition.minimum_path_distance_by_role.get(
				data.tactical_role_id,
				0,
			))
			if distance < minimum or distance >= 999999:
				continue
			var maximum := int(definition.maximum_path_distance_by_role.get(
				data.tactical_role_id,
				minimum + 6,
			))
			var ideal := float(minimum + maximum) * 0.5
			var score := absf(float(distance) - ideal) * 10.0
			if distance > maximum:
				score += float(distance - maximum) * 5.0
			if preferred_cells.has(cell):
				score -= 8.0
			score += _formation_penalty(
				formation_id,
				cell,
				distance,
				data.tactical_role_id,
				roster_index,
			)
			score += _stable_jitter(cell, run_seed, definition.room_index) * 0.01
			scored.append({"cell": cell, "score": score})
		scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			if not is_equal_approx(float(a.score), float(b.score)):
				return float(a.score) < float(b.score)
			var ca: Vector2i = a.cell
			var cb: Vector2i = b.cell
			return ca.y < cb.y or (ca.y == cb.y and ca.x < cb.x)
		)
		if scored.is_empty():
			return {"placements": placements}
		var selected: Vector2i = scored[0].cell
		occupied[selected] = true
		placements.append({"unit_data": data, "cell": selected})
	return {"placements": placements}


func _formation_penalty(
		formation_id: StringName,
		cell: Vector2i,
		distance: int,
		role_id: StringName,
		roster_index: int
	) -> float:
	var center_x := float(_grid.cols - 1) * 0.5
	var lateral := float(cell.x) - center_x
	var penalty := 0.0
	match formation_id:
		&"line": penalty += absf(float(distance % 2)) * 2.0
		&"double_line": penalty += absf(float((distance + roster_index) % 3))
		&"left_flank": penalty += maxf(0.0, lateral) * 2.0
		&"right_flank": penalty += maxf(0.0, -lateral) * 2.0
		&"chief_forward":
			penalty += float(distance) * 0.8 if role_id == &"skeleton_chief" else 0.0
		&"centurion_rear":
			penalty -= float(distance) * 0.8 if role_id == &"skeleton_centurion" else 0.0
		&"split": penalty -= absf(lateral) * 0.7
	return penalty


func _minimum_path_distance(cell: Vector2i, targets: Array) -> int:
	_ensure_hero_distance_cache(targets)
	if _hero_distance_cache.has(cell):
		return int(_hero_distance_cache[cell])
	return 999999


func _ensure_hero_distance_cache(targets: Array) -> void:
	var valid_targets := _valid_walkable_cells(targets)
	var target_keys: Array[String] = []
	for target_value in valid_targets:
		var target := target_value as Vector2i
		target_keys.append("%d,%d" % [target.x, target.y])
	target_keys.sort()
	var cache_key := "|".join(target_keys)
	if cache_key == _hero_distance_cache_key:
		return
	_hero_distance_cache_key = cache_key
	_hero_distance_cache.clear()
	var frontier: Array[Vector2i] = []
	for target_value in valid_targets:
		var target := target_value as Vector2i
		if _hero_distance_cache.has(target):
			continue
		_hero_distance_cache[target] = 0
		frontier.append(target)
	var cursor := 0
	while cursor < frontier.size():
		var current := frontier[cursor]
		cursor += 1
		var next_distance := int(_hero_distance_cache[current]) + 1
		for direction_value in DIRECTIONS:
			var neighbor := current + (direction_value as Vector2i)
			if not _grid.is_valid(neighbor) or not _grid.is_walkable(neighbor) \
					or _hero_distance_cache.has(neighbor):
				continue
			_hero_distance_cache[neighbor] = next_distance
			frontier.append(neighbor)


func _is_adjacent_to_any(cell: Vector2i, targets: Array) -> bool:
	for target_value in targets:
		if _grid.are_adjacent(cell, target_value as Vector2i):
			return true
	return false


func _valid_walkable_cells(values: Array) -> Array:
	var result: Array = []
	for value in values:
		var cell := value as Vector2i
		if _grid.is_valid(cell) and _grid.is_walkable(cell) and not result.has(cell):
			result.append(cell)
	return result


func _all_walkable_cells() -> Array:
	var result: Array = []
	for y in _grid.rows:
		for x in _grid.cols:
			var cell := Vector2i(x, y)
			if _grid.is_walkable(cell):
				result.append(cell)
	return result


func _stable_jitter(cell: Vector2i, run_seed: int, room_index: int) -> float:
	return float(posmod(
		run_seed * 1103515245 + room_index * 7919 + cell.x * 101 + cell.y * 313,
		997,
	))


func _rotate(values: Array, amount: int) -> void:
	if values.is_empty():
		return
	for _index in posmod(amount, values.size()):
		values.append(values.pop_front())


func _failure(reason: StringName) -> Dictionary:
	return {"valid": false, "reason": reason, "placements": []}
