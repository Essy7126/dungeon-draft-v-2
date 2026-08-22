@tool
class_name EncounterMigrationService
extends RefCounted


static func preview(room: RoomData, actual_room_index: int) -> Dictionary:
	if room == null:
		return {"available": false, "reason": "Salle absente."}
	if not room.waves.is_empty():
		return {"available": false, "reason": "La salle utilise déjà des vagues."}
	if room.encounter_definition != null:
		return {
			"available": true,
			"mode": "encounter_definition",
			"enemy_count_before": room.encounter_definition.get_initial_enemy_count(),
			"enemy_count_after": room.encounter_definition.get_initial_enemy_count(),
			"battle_scene": room.battle_scene.resource_path if room.battle_scene != null else "",
		}
	if room.enemies.is_empty():
		return {"available": false, "reason": "Aucun ennemi historique."}
	return {
		"available": true,
		"mode": "enemies",
		"enemy_count_before": room.enemies.size(),
		"enemy_count_after": room.enemies.size(),
		"battle_scene": room.battle_scene.resource_path if room.battle_scene != null else "",
		"room_index": actual_room_index + 1,
	}


static func migrate_working_room(
		room: RoomData,
		actual_room_index: int
	) -> Dictionary:
	var report := preview(room, actual_room_index)
	if not report.get("available", false):
		return report
	var encounter := room.encounter_definition
	if encounter == null:
		encounter = EncounterDefinition.new()
		encounter.room_index = actual_room_index + 1
		var units: Array[UnitData] = []
		var counts := PackedInt32Array()
		for unit in room.enemies:
			var index := units.find(unit)
			if index < 0:
				units.append(unit)
				counts.append(1)
			else:
				counts[index] += 1
		encounter.roster_units = units
		encounter.roster_counts = counts
		encounter.living_enemy_cap = room.enemies.size()
	var wave := RoomWaveData.new()
	wave.wave_name = "Affrontement 1 — migration historique"
	wave.encounter_definition = encounter
	room.waves = [wave]
	room.minimum_wave_count = 1
	room.maximum_wave_count = 1
	report["success"] = true
	report["encounter"] = encounter
	report["wave"] = wave
	return report
