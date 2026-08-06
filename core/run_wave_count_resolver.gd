@tool
class_name RunWaveCountResolver
extends RefCounted

## Reproduit exactement la sequence RNG historique de GameManager.
static func resolve_counts(run_data: RunData, run_seed: int) -> PackedInt32Array:
	var result := PackedInt32Array()
	if run_data == null:
		return result
	if run_data.is_single_encounter_flow():
		for room_value in run_data.rooms:
			var room := room_value as RoomData
			result.append(1 if room != null and room.get_wave_count() > 0 else 0)
		return result
	var rng := RandomNumberGenerator.new()
	rng.seed = run_seed
	var maximum_per_room := maxi(1, run_data.maximum_waves_per_room)
	for room_value in run_data.rooms:
		var room := room_value as RoomData
		if room == null:
			result.append(0)
			continue
		var available := mini(room.get_wave_count(), maximum_per_room)
		var minimum := clampi(room.get_minimum_wave_count(), 1, available)
		var maximum := clampi(room.get_maximum_wave_count(), minimum, available)
		result.append(rng.randi_range(minimum, maximum))
	return result


static func total_for_seed(run_data: RunData, run_seed: int) -> int:
	var total := 0
	for count in resolve_counts(run_data, run_seed):
		total += count
	return total
