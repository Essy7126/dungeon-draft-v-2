@tool
class_name EncounterRunProjectionService
extends RefCounted


static func project(run: RunData, first_seed: int, seed_count: int) -> Dictionary:
	if run == null:
		return {}
	var totals: Array[int] = []
	var distribution := {}
	for offset in range(maxi(0, seed_count)):
		var total := RunWaveCountResolver.total_for_seed(run, first_seed + offset)
		totals.append(total)
		distribution[total] = int(distribution.get(total, 0)) + 1
	totals.sort()
	var minimum := 0
	var maximum := 0
	var average := 0.0
	var median := 0.0
	if not totals.is_empty():
		minimum = totals.front()
		maximum = totals.back()
		for value in totals:
			average += value
		average /= totals.size()
		median = _percentile(totals, 0.5)
	var theoretical_minimum := 0
	var theoretical_maximum := 0
	for room in run.rooms:
		if room != null:
			theoretical_minimum += room.get_minimum_wave_count()
			theoretical_maximum += mini(
				room.get_maximum_wave_count(), run.maximum_waves_per_room
			)
	return {
		"room_count": run.rooms.size(),
		"seed_count": totals.size(),
		"theoretical_minimum": theoretical_minimum,
		"theoretical_maximum": theoretical_maximum,
		"observed_minimum": minimum,
		"observed_maximum": maximum,
		"average": average,
		"median": median,
		"quartile_1": _percentile(totals, 0.25) if not totals.is_empty() else 0.0,
		"quartile_3": _percentile(totals, 0.75) if not totals.is_empty() else 0.0,
		"distribution": distribution,
		"duration_status": "DUREE NON ESTIMEE — DONNEES INSUFFISANTES",
	}


static func _percentile(values: Array[int], ratio: float) -> float:
	if values.is_empty():
		return 0.0
	var position := clampf(ratio, 0.0, 1.0) * float(values.size() - 1)
	var lower := floori(position)
	var upper := ceili(position)
	if lower == upper:
		return values[lower]
	return lerpf(float(values[lower]), float(values[upper]), position - lower)
