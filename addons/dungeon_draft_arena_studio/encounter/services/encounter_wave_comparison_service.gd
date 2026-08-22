@tool
class_name EncounterWaveComparisonService
extends RefCounted


static func metrics(
		room: RoomData,
		wave_index: int,
		walkable_cell_count: int = 0
	) -> Dictionary:
	if room == null:
		return {}
	var wave := room.get_wave(wave_index)
	var encounter := room.get_encounter_for_wave(wave_index)
	if encounter == null:
		return {}
	var hp_multiplier := wave.enemy_health_multiplier if wave != null else 1.0
	var attack_multiplier := wave.enemy_attack_multiplier if wave != null else 1.0
	var reward_multiplier := wave.reward_multiplier if wave != null else 1.0
	var result := {
		"enemy_count": encounter.get_initial_enemy_count(),
		"total_base_hp_after_multiplier": 0.0,
		"total_base_attack_after_multiplier": 0.0,
		"total_armor": 0.0,
		"total_magic_resistance": 0.0,
		"initiative_average": 0.0,
		"movement_average": 0.0,
		"roles": {},
		"living_enemy_cap": encounter.living_enemy_cap,
		"normal_summon_budget": encounter.shared_normal_summon_budget,
		"chief_summon_budget": encounter.shared_chief_summon_budget,
		"theoretical_total_appeared": encounter.get_initial_enemy_count() \
			+ encounter.shared_normal_summon_budget \
			+ encounter.shared_chief_summon_budget,
		"initial_density_percent": 100.0 * encounter.get_initial_enemy_count() \
			/ float(walkable_cell_count) if walkable_cell_count > 0 else null,
		"health_multiplier": hp_multiplier,
		"attack_multiplier": attack_multiplier,
		"reward_multiplier": reward_multiplier,
	}
	var initiative_total := 0.0
	var movement_total := 0.0
	for index in range(encounter.roster_units.size()):
		var unit := encounter.roster_units[index]
		var count := encounter.roster_counts[index] if index < encounter.roster_counts.size() else 0
		if unit == null or count <= 0:
			continue
		result["total_base_hp_after_multiplier"] += unit.max_hp * count * hp_multiplier
		result["total_base_attack_after_multiplier"] += unit.attack_power * count * attack_multiplier
		result["total_armor"] += unit.armure * count
		result["total_magic_resistance"] += unit.resist_magique * count
		initiative_total += unit.initiative * count
		movement_total += unit.max_mp * count
		var role := str(unit.tactical_role_id) if unit.tactical_role_id != &"" else "inconnu"
		result["roles"][role] = int(result["roles"].get(role, 0)) + count
	if result["enemy_count"] > 0:
		result["initiative_average"] = initiative_total / result["enemy_count"]
		result["movement_average"] = movement_total / result["enemy_count"]
	return result


static func compare(previous: Dictionary, current: Dictionary) -> Dictionary:
	if previous.is_empty() or current.is_empty():
		return {"changes": {}, "warnings": []}
	var changes := {}
	for key in [
		"enemy_count", "total_base_hp_after_multiplier",
		"total_base_attack_after_multiplier", "reward_multiplier",
		"theoretical_total_appeared",
	]:
		var before := float(previous.get(key, 0.0))
		var after := float(current.get(key, 0.0))
		changes[key] = 100.0 * (after - before) / absf(before) if not is_zero_approx(before) else null
	var warnings := PackedStringArray()
	if previous.get("roles", {}) == current.get("roles", {}) \
			and previous.get("enemy_count", 0) == current.get("enemy_count", 0):
		warnings.append("La composition est identique à l'affrontement précédent.")
	if float(current.get("reward_multiplier", 0.0)) < float(previous.get("reward_multiplier", 0.0)) \
			and float(current.get("total_base_hp_after_multiplier", 0.0)) \
			> float(previous.get("total_base_hp_after_multiplier", 0.0)):
		warnings.append("La récompense baisse alors que les PV bruts augmentent.")
	return {"changes": changes, "warnings": warnings}
