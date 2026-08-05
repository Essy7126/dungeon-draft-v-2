@tool
class_name EncounterSeedAnalysisService
extends RefCounted

signal progress_changed(completed: int, total: int, generation: int)

var cancelled := false
var generation := 0


func cancel() -> void:
	cancelled = true
	generation += 1


func analyze(
		room: RoomData,
		encounter: EncounterDefinition,
		first_seed: int,
		count: int,
		room_index: int,
		wave_index: int,
		batch_size := 20
	) -> Dictionary:
	cancelled = false
	generation += 1
	var request_generation := generation
	var report := _new_report(first_seed, count)
	var grid := EncounterGridFactory.build_from_room(room)
	if grid == null or encounter == null or room == null:
		report["failure_reasons"] = {"grid_or_encounter_missing": count}
		report["failures"] = count
		return _finalize(report, encounter)
	var pathfinder := Pathfinder.new(grid)
	var planner := EncounterFormationPlanner.new(grid, pathfinder)
	for offset in range(maxi(0, count)):
		if cancelled or request_generation != generation:
			report["cancelled"] = true
			break
		var run_seed := first_seed + offset
		var effective_seed := EncounterSeedResolver.effective_seed(run_seed, wave_index)
		var plan := planner.build_plan(
			encounter, room.hero_spawn_zone, room.enemy_spawn_zone, effective_seed
		)
		report["completed"] = offset + 1
		if not plan.get("valid", false):
			report["failures"] += 1
			var reason := str(plan.get("reason", &"unknown"))
			_increment(report["failure_reasons"], reason)
			report["problem_seeds"].append({
				"run_seed": run_seed,
				"effective_seed": effective_seed,
				"reason": reason,
			})
		else:
			report["successes"] += 1
			var formation := str(plan.get("formation_id", &""))
			_increment(report["formations"], formation)
			report["attempt_total"] += int(plan.get("attempt", 0)) + 1
			for placement_value in plan.get("placements", []):
				var placement := placement_value as Dictionary
				var cell := placement.get("cell", Vector2i(-1, -1)) as Vector2i
				var unit := placement.get("unit_data") as UnitData
				var distance := EncounterPreviewService.minimum_path_distance(
					pathfinder, cell, room.hero_spawn_zone
				)
				if distance < 999_999:
					report["distances"].append(distance)
					var role := str(unit.tactical_role_id) if unit != null else "inconnu"
					if not report["distances_by_role"].has(role):
						report["distances_by_role"][role] = []
					(report["distances_by_role"][role] as Array).append(distance)
				var cell_key := "%d,%d" % [cell.x, cell.y]
				_increment(report["cell_frequency"], cell_key)
				if room.enemy_spawn_zone.has(cell):
					report["preferred_placements"] += 1
				else:
					report["outside_preferred_placements"] += 1
		if (offset + 1) % maxi(1, batch_size) == 0:
			progress_changed.emit(offset + 1, count, request_generation)
			var tree := Engine.get_main_loop() as SceneTree
			if tree != null:
				await tree.process_frame
	progress_changed.emit(int(report["completed"]), count, request_generation)
	return _finalize(report, encounter)


func _new_report(first_seed: int, count: int) -> Dictionary:
	return {
		"first_seed": first_seed,
		"requested": maxi(0, count),
		"completed": 0,
		"successes": 0,
		"failures": 0,
		"success_rate_percent": 0.0,
		"failure_reasons": {},
		"formations": {},
		"attempt_total": 0,
		"average_attempts": 0.0,
		"distances": [],
		"distance_minimum": null,
		"distance_average": null,
		"distance_maximum": null,
		"distances_by_role": {},
		"cell_frequency": {},
		"preferred_placements": 0,
		"outside_preferred_placements": 0,
		"preferred_percent": 0.0,
		"formations_never_selected": [],
		"problem_seeds": [],
		"cancelled": false,
	}


func _finalize(report: Dictionary, encounter: EncounterDefinition) -> Dictionary:
	var completed := int(report["completed"])
	var successes := int(report["successes"])
	report["success_rate_percent"] = 100.0 * float(successes) / float(completed) \
		if completed > 0 else 0.0
	report["average_attempts"] = float(report["attempt_total"]) / float(successes) \
		if successes > 0 else 0.0
	var distances := report["distances"] as Array
	if not distances.is_empty():
		distances.sort()
		report["distance_minimum"] = distances.front()
		report["distance_maximum"] = distances.back()
		var total := 0.0
		for value in distances:
			total += float(value)
		report["distance_average"] = total / distances.size()
	var placement_count := int(report["preferred_placements"]) \
		+ int(report["outside_preferred_placements"])
	report["preferred_percent"] = 100.0 * float(report["preferred_placements"]) \
		/ float(placement_count) if placement_count > 0 else 0.0
	if encounter != null:
		for formation in encounter.formation_profiles:
			if not report["formations"].has(str(formation)):
				report["formations_never_selected"].append(str(formation))
	report.erase("attempt_total")
	return report


func _increment(dictionary: Dictionary, key: String) -> void:
	dictionary[key] = int(dictionary.get(key, 0)) + 1
