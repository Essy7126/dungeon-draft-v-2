@tool
class_name EncounterCopyService
extends RefCounted


static func copy_encounter(source: EncounterDefinition) -> EncounterDefinition:
	if source == null:
		return null
	var copy := EncounterDefinition.new()
	copy.room_index = source.room_index
	copy.roster_units.assign(source.roster_units)
	copy.roster_counts = source.roster_counts.duplicate()
	copy.allowed_spawn_groups.assign(source.allowed_spawn_groups.duplicate())
	copy.formation_profiles.assign(source.formation_profiles.duplicate())
	copy.living_enemy_cap = source.living_enemy_cap
	copy.shared_normal_summon_budget = source.shared_normal_summon_budget
	copy.shared_chief_summon_budget = source.shared_chief_summon_budget
	copy.disabled_ability_ids.assign(source.disabled_ability_ids.duplicate())
	copy.maximum_formation_attempts = source.maximum_formation_attempts
	copy.minimum_path_distance_by_role = source.minimum_path_distance_by_role.duplicate(true)
	copy.maximum_path_distance_by_role = source.maximum_path_distance_by_role.duplicate(true)
	copy.summon_free_neighbor_requirement = source.summon_free_neighbor_requirement
	copy.forbidden_initial_spawn_cells.assign(
		source.forbidden_initial_spawn_cells.duplicate()
	)
	return copy


static func copy_run(source: RunData) -> Dictionary:
	if source == null:
		return {}
	var source_to_work := {}
	var work_to_source := {}
	var encounter_copies := {}
	var run := RunData.new()
	run.run_name = source.run_name
	run.default_seed = source.default_seed
	run.target_duration_minutes = source.target_duration_minutes
	run.extended_duration_minutes = source.extended_duration_minutes
	run.maximum_waves_per_room = source.maximum_waves_per_room
	for source_room in source.rooms:
		var room := copy_room(source_room, encounter_copies)
		run.rooms.append(room)
		source_to_work[source_room] = room
		work_to_source[room] = source_room
	for source_encounter in encounter_copies:
		var work_encounter: EncounterDefinition = encounter_copies[source_encounter]
		source_to_work[source_encounter] = work_encounter
		work_to_source[work_encounter] = source_encounter
	for room_index in range(source.rooms.size()):
		var source_room := source.rooms[room_index]
		var work_room := run.rooms[room_index]
		for wave_index in range(source_room.waves.size()):
			source_to_work[source_room.waves[wave_index]] = work_room.waves[wave_index]
			work_to_source[work_room.waves[wave_index]] = source_room.waves[wave_index]
	source_to_work[source] = run
	work_to_source[run] = source
	return {
		"run": run,
		"source_to_work": source_to_work,
		"work_to_source": work_to_source,
	}


static func copy_room(source: RoomData, encounter_copies := {}) -> RoomData:
	if source == null:
		return null
	var room := RoomData.new()
	room.room_name = source.room_name
	room.background_image = source.background_image
	room.particles_scene = source.particles_scene
	room.battle_scene = source.battle_scene
	room.arena_generation_profile = source.arena_generation_profile
	room.arena_visual_profile = source.arena_visual_profile
	room.grid_layout = source.grid_layout
	room.painted_map_visual_data = source.painted_map_visual_data
	room.minimum_wave_count = source.minimum_wave_count
	room.maximum_wave_count = source.maximum_wave_count
	room.ultimate_reward_base_chance = source.ultimate_reward_base_chance
	room.ultimate_reward_min_gain_per_wave = source.ultimate_reward_min_gain_per_wave
	room.ultimate_reward_max_gain_per_wave = source.ultimate_reward_max_gain_per_wave
	room.enemies.assign(source.enemies)
	room.hero_spawn_zone.assign(source.hero_spawn_zone.duplicate())
	room.enemy_spawn_zone.assign(source.enemy_spawn_zone.duplicate())
	room.encounter_definition = _copy_shared_encounter(
		source.encounter_definition, encounter_copies
	)
	for source_wave in source.waves:
		room.waves.append(copy_wave(source_wave, encounter_copies))
	return room


static func copy_wave(source: RoomWaveData, encounter_copies := {}) -> RoomWaveData:
	if source == null:
		return null
	var wave := RoomWaveData.new()
	wave.wave_name = source.wave_name
	wave.encounter_definition = _copy_shared_encounter(
		source.encounter_definition, encounter_copies
	)
	wave.enemy_health_multiplier = source.enemy_health_multiplier
	wave.enemy_attack_multiplier = source.enemy_attack_multiplier
	wave.reward_multiplier = source.reward_multiplier
	return wave


static func encounter_snapshot(encounter: EncounterDefinition) -> Dictionary:
	if encounter == null:
		return {}
	return {
		"room_index": encounter.room_index,
		"roster_paths": encounter.roster_units.map(
			func(unit: UnitData): return unit.resource_path if unit != null else ""
		),
		"roster_counts": Array(encounter.roster_counts),
		"allowed_spawn_groups": Array(encounter.allowed_spawn_groups).map(str),
		"formation_profiles": Array(encounter.formation_profiles).map(str),
		"living_enemy_cap": encounter.living_enemy_cap,
		"shared_normal_summon_budget": encounter.shared_normal_summon_budget,
		"shared_chief_summon_budget": encounter.shared_chief_summon_budget,
		"disabled_ability_ids": Array(encounter.disabled_ability_ids).map(str),
		"maximum_formation_attempts": encounter.maximum_formation_attempts,
		"minimum_path_distance_by_role": encounter.minimum_path_distance_by_role.duplicate(true),
		"maximum_path_distance_by_role": encounter.maximum_path_distance_by_role.duplicate(true),
		"summon_free_neighbor_requirement": encounter.summon_free_neighbor_requirement,
		"forbidden_initial_spawn_cells": encounter.forbidden_initial_spawn_cells.map(
			func(cell: Vector2i): return [cell.x, cell.y]
		),
	}


static func suggested_path(
		room: RoomData,
		wave_index: int,
		root := "res://data/encounters"
	) -> String:
	var slug := room.room_name.to_lower().strip_edges()
	for character in [" ", "-", "—", "'", "’", "/", "\\", ".", ":"]:
		slug = slug.replace(character, "_")
	while "__" in slug:
		slug = slug.replace("__", "_")
	slug = slug.trim_prefix("_").trim_suffix("_")
	if slug.is_empty():
		slug = "salle"
	var base := root.path_join("%s_affrontement_%02d.tres" % [slug, wave_index + 1])
	var candidate := base
	var copy_index := 2
	while ResourceLoader.exists(candidate) or FileAccess.file_exists(candidate):
		candidate = base.trim_suffix(".tres") + "_copie_%d.tres" % copy_index
		copy_index += 1
	return candidate


static func _copy_shared_encounter(
		source: EncounterDefinition,
		encounter_copies: Dictionary
	) -> EncounterDefinition:
	if source == null:
		return null
	if not encounter_copies.has(source):
		encounter_copies[source] = copy_encounter(source)
	return encounter_copies[source]
