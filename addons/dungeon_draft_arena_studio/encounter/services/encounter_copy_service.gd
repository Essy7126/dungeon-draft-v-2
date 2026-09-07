@tool
class_name EncounterCopyService
extends RefCounted


static func copy_encounter(
		source: EncounterDefinition,
		source_to_work: Dictionary = {},
		work_to_source: Dictionary = {}
	) -> EncounterDefinition:
	if source == null:
		return null
	var existing := source_to_work.get(source) as EncounterDefinition
	if existing != null:
		return existing
	var copy := EncounterDefinition.new()
	_register(source, copy, source_to_work, work_to_source)
	copy.room_index = source.room_index
	copy.roster_units.assign(source.roster_units)
	copy.roster_counts = source.roster_counts.duplicate()
	copy.allowed_spawn_groups.assign(source.allowed_spawn_groups.duplicate())
	copy.formation_profiles.assign(source.formation_profiles.duplicate())
	copy.living_enemy_cap = source.living_enemy_cap
	copy.shared_normal_summon_budget = source.shared_normal_summon_budget
	copy.shared_chief_summon_budget = source.shared_chief_summon_budget
	copy.disabled_ability_ids.assign(source.disabled_ability_ids.duplicate())
	copy.encounter_id = source.encounter_id
	copy.base_xp = source.base_xp
	copy.optional_xp_budget = source.optional_xp_budget
	copy.glory_challenge = _copy_embedded_resource(
		source.glory_challenge, source_to_work, work_to_source
	) as GloryChallengeData if source.glory_challenge != null else null
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
	run.randomize_seed_each_run = source.randomize_seed_each_run
	run.target_duration_minutes = source.target_duration_minutes
	run.extended_duration_minutes = source.extended_duration_minutes
	run.room_flow_mode = source.room_flow_mode
	run.maximum_waves_per_room = source.maximum_waves_per_room
	# Ces profils ne sont pas edites par Encounter Studio, mais font partie du
	# document RunData et doivent survivre a son round-trip.
	run.content_profile = source.content_profile
	run.economy_profile = source.economy_profile
	for source_room in source.rooms:
		var room := copy_room(
			source_room, encounter_copies, source_to_work, work_to_source
		)
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


static func copy_room(
		source: RoomData,
		encounter_copies := {},
		source_to_work: Dictionary = {},
		work_to_source: Dictionary = {}
	) -> RoomData:
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
		source.encounter_definition, encounter_copies,
		source_to_work, work_to_source
	)
	for source_wave in source.waves:
		room.waves.append(copy_wave(
			source_wave, encounter_copies, source_to_work, work_to_source
		))
	return room


static func copy_wave(
		source: RoomWaveData,
		encounter_copies := {},
		source_to_work: Dictionary = {},
		work_to_source: Dictionary = {}
	) -> RoomWaveData:
	if source == null:
		return null
	var wave := RoomWaveData.new()
	wave.wave_name = source.wave_name
	wave.encounter_definition = _copy_shared_encounter(
		source.encounter_definition, encounter_copies,
		source_to_work, work_to_source
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
		"encounter_id": str(encounter.encounter_id),
		"base_xp": encounter.base_xp,
		"optional_xp_budget": encounter.optional_xp_budget,
		"glory_challenge": _resource_snapshot(encounter.glory_challenge),
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
		encounter_copies: Dictionary,
		source_to_work: Dictionary = {},
		work_to_source: Dictionary = {}
	) -> EncounterDefinition:
	if source == null:
		return null
	if not encounter_copies.has(source):
		encounter_copies[source] = copy_encounter(
			source, source_to_work, work_to_source
		)
	return encounter_copies[source]


static func _copy_embedded_resource(
		source: Resource,
		source_to_work: Dictionary,
		work_to_source: Dictionary
	) -> Resource:
	if source == null:
		return null
	var existing := source_to_work.get(source) as Resource
	if existing != null:
		return existing
	var work := source.duplicate(true)
	_register(source, work, source_to_work, work_to_source)
	return work


static func _register(
		source: Resource,
		work: Resource,
		source_to_work: Dictionary,
		work_to_source: Dictionary
	) -> void:
	if source == null or work == null:
		return
	source_to_work[source] = work
	work_to_source[work] = source
	if not source.resource_path.is_empty() and not source.is_built_in():
		work.set_path_cache(source.resource_path)


static func _resource_snapshot(resource: Resource) -> Variant:
	if resource == null:
		return null
	var result := {"class": resource.get_class(), "path": resource.resource_path}
	for property_value in resource.get_property_list():
		var property := property_value as Dictionary
		var name := StringName(property.get("name", &""))
		if name in [&"script", &"resource_path", &"resource_name", &"resource_local_to_scene"] \
				or int(property.get("usage", 0)) & PROPERTY_USAGE_STORAGE == 0:
			continue
		var value: Variant = resource.get(name)
		result[str(name)] = str(value) if value is StringName else value
	return result
