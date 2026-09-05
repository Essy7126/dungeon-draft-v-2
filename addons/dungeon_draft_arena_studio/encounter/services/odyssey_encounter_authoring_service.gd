@tool
class_name OdysseyEncounterAuthoringService
extends RefCounted


## Projection des rencontres de la partie courante, sans créer une autre séquence.
static func encounter_sheet(
		encounter: EncounterDefinition,
		progression: ChampionProgressionProfile = null,
		seed: int = 0
	) -> Dictionary:
	if encounter == null:
		return {}
	var roster: Array[Dictionary] = []
	for index in range(encounter.roster_units.size()):
		var unit := encounter.roster_units[index]
		if unit != null:
			roster.append({
				"unit_id": unit.get_effective_unit_id(),
				"name": unit.unit_name,
				"count": encounter.roster_counts[index] if index < encounter.roster_counts.size() else 0,
			})
	return {
		"encounter_id": encounter.encounter_id,
		"base_xp": encounter.base_xp,
		"optional_xp_budget": encounter.optional_xp_budget,
		"glory_challenge_id": encounter.glory_challenge.challenge_id if encounter.glory_challenge != null else &"",
		"glory_multiplier": encounter.glory_challenge.xp_multiplier if encounter.glory_challenge != null else 1.0,
		"xp_projection": ChampionProgressionAuthoringService.wisdom_glory_projection(
			progression, encounter.base_xp
		) if progression != null else [],
		"roster_count": encounter.get_initial_enemy_count(),
		"roster": roster,
		"seed": seed,
	}


static func run_sheet(run: RunData, progression: ChampionProgressionProfile = null) -> Dictionary:
	if run == null:
		return {}
	var rows: Array[Dictionary] = []
	var total_xp := 0
	for room_index in range(run.rooms.size()):
		var room := run.rooms[room_index]
		if room == null:
			continue
		for wave_index in range(room.get_wave_count()):
			var encounter := room.get_encounter_for_wave(wave_index)
			if encounter == null:
				continue
			var row := encounter_sheet(encounter, progression, run.default_seed)
			row["room_index"] = room_index
			row["wave_index"] = wave_index
			rows.append(row)
			total_xp += encounter.base_xp
	return {
		"run_name": run.run_name,
		"authority": "current_rooms",
		"entries": rows,
		"room_count": run.rooms.size(),
		"total_base_xp": total_xp,
	}
