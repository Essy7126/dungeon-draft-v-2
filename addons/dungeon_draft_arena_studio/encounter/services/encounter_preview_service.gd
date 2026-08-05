@tool
class_name EncounterPreviewService
extends RefCounted


static func generate(
		room: RoomData,
		encounter: EncounterDefinition,
		run_seed: int,
		room_index: int,
		wave_index: int
	) -> Dictionary:
	var grid := EncounterGridFactory.build_from_room(room)
	if grid == null:
		return _failure(&"grid_missing", run_seed, wave_index)
	var effective_seed := EncounterSeedResolver.effective_seed(run_seed, wave_index)
	var pathfinder := Pathfinder.new(grid)
	var planner := EncounterFormationPlanner.new(grid, pathfinder)
	var plan := planner.build_plan(
		encounter,
		room.hero_spawn_zone if room != null else [],
		room.enemy_spawn_zone if room != null else [],
		effective_seed,
	)
	var placements: Array[Dictionary] = []
	var preferred_count := 0
	for index in range((plan.get("placements", []) as Array).size()):
		var placement := (plan["placements"] as Array)[index] as Dictionary
		var cell := placement.get("cell", Vector2i(-1, -1)) as Vector2i
		var unit := placement.get("unit_data") as UnitData
		var distance := minimum_path_distance(
			pathfinder, cell, room.hero_spawn_zone
		)
		var preferred := room.enemy_spawn_zone.has(cell)
		preferred_count += 1 if preferred else 0
		placements.append({
			"order": index,
			"unit_data": unit,
			"unit_path": unit.resource_path if unit != null else "",
			"unit_name": unit.unit_name if unit != null else "Unite absente",
			"role": unit.tactical_role_id if unit != null else &"",
			"cell": cell,
			"distance_to_ally_deployment": distance,
			"in_preferred_enemy_zone": preferred,
		})
	return {
		"valid": bool(plan.get("valid", false)),
		"reason": StringName(plan.get("reason", &"")),
		"run_seed": run_seed,
		"effective_seed": effective_seed,
		"room_index": room_index,
		"wave_index": wave_index,
		"formation_id": StringName(plan.get("formation_id", &"")),
		"attempt": int(plan.get("attempt", -1)),
		"placements": placements,
		"preferred_count": preferred_count,
		"outside_preferred_count": placements.size() - preferred_count,
		"grid": grid,
		"grid_size": Vector2i(grid.cols, grid.rows),
	}


static func minimum_path_distance(
		pathfinder: Pathfinder,
		cell: Vector2i,
		targets: Array
	) -> int:
	var minimum := 999_999
	for target_value in targets:
		var path := pathfinder.find_path(cell, target_value as Vector2i)
		if not path.is_empty():
			minimum = mini(minimum, path.size() - 1)
	return minimum


static func serializable(result: Dictionary) -> Dictionary:
	var copy := result.duplicate(true)
	copy.erase("grid")
	copy["grid_size"] = _vector_to_array(result.get("grid_size", Vector2i.ZERO))
	var placements: Array = []
	for placement_value in result.get("placements", []):
		var placement := (placement_value as Dictionary).duplicate(true)
		placement.erase("unit_data")
		placement["role"] = str(placement.get("role", &""))
		placement["cell"] = _vector_to_array(placement.get("cell", Vector2i.ZERO))
		placements.append(placement)
	copy["placements"] = placements
	copy["reason"] = str(copy.get("reason", &""))
	copy["formation_id"] = str(copy.get("formation_id", &""))
	return copy


static func _failure(reason: StringName, run_seed: int, wave_index: int) -> Dictionary:
	return {
		"valid": false,
		"reason": reason,
		"run_seed": run_seed,
		"effective_seed": EncounterSeedResolver.effective_seed(run_seed, wave_index),
		"placements": [],
	}


static func _vector_to_array(value: Vector2i) -> Array[int]:
	return [value.x, value.y]
