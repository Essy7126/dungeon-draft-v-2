extends GutTest

const CATABASE_RUN: RunData = preload("res://data/runs/odyssey.tres")
const EXPECTED_MIDDLE_ROSTER: Array[StringName] = [
	&"odyssey_skirmisher",
	&"odyssey_skirmisher",
	&"odyssey_guard",
]
const EXPECTED_FINALE_ROSTER: Array[StringName] = [
	&"odyssey_champion",
	&"catabase_shadow_paris",
]


func test_catabase_keeps_three_distinct_ordered_arenas() -> void:
	assert_eq(CATABASE_RUN.rooms.size(), 3)
	assert_eq(
		CATABASE_RUN.rooms[1].room_name,
		"Catabase II — La Porte des Cendres",
	)
	assert_eq(
		CATABASE_RUN.rooms[2].room_name,
		"Catabase III — Le Jugement de Paris",
	)
	var names := {}
	var map_ids := {}
	for room in CATABASE_RUN.rooms:
		assert_not_null(room)
		assert_not_null(room.grid_layout, room.resource_path)
		assert_not_null(room.painted_map_visual_data, room.resource_path)
		names[room.room_name] = true
		map_ids[room.painted_map_visual_data.map_id] = true
	assert_eq(names.size(), 3, "chaque salle garde une identité propre")
	assert_eq(map_ids.size(), 3, "chaque salle garde une arène visuelle propre")


func test_middle_room_is_the_melee_formation_escalation() -> void:
	var room := CATABASE_RUN.rooms[1]
	assert_eq(room.visual_mode, ArenaDefinition.VisualMode.PAINTED)
	assert_eq(_roster_ids(room), EXPECTED_MIDDLE_ROSTER)
	assert_eq(room.encounter_definition.get_initial_enemy_count(), 3)
	assert_eq(room.encounter_definition.living_enemy_cap, 3)
	assert_true(room.encounter_definition.formation_profiles.has(&"double_line"))
	assert_true(room.encounter_definition.formation_profiles.has(&"split"))
	assert_eq(_room_enemy_ids(room), EXPECTED_MIDDLE_ROSTER)


func test_shadow_paris_is_in_the_final_room_with_a_melee_anchor() -> void:
	var finale := CATABASE_RUN.rooms[2]
	assert_eq(_roster_ids(finale), EXPECTED_FINALE_ROSTER)
	assert_eq(_room_enemy_ids(finale), EXPECTED_FINALE_ROSTER)
	assert_eq(finale.encounter_definition.room_index, 3)
	assert_eq(finale.encounter_definition.living_enemy_cap, 2)
	assert_true(finale.encounter_definition.formation_profiles.has(&"split"))
	var paris := finale.enemies[1]
	assert_eq(paris.unit_name, "L’Ombre de Paris")
	assert_eq(paris.ai_behavior, EnemyAI.BEHAVIOR_RANGED)
	assert_true(paris.keep_distance)
	assert_eq(paris.spells.size(), 1)
	assert_eq(paris.spells[0].spell_id, &"catabase_shadow_paris_arrow")
	assert_true(paris.spells[0].needs_line_of_sight)
	assert_eq(finale.grid_layout.logical_size, Vector2i(13, 13))
	assert_eq(finale.painted_map_visual_data.logical_grid_size, Vector2i(13, 13))
	assert_eq(
		finale.painted_map_visual_data.background_texture_path,
		"res://asset/map/painted/greece/maps_achille_dalle.png",
	)
	assert_eq(
		finale.painted_map_visual_data.load_background_texture().get_size(),
		Vector2(finale.painted_map_visual_data.source_image_size),
	)
	assert_eq(finale.painted_map_visual_data.calibration_rms(), 0.0)
	assert_true(finale.grid_layout.validation_errors().is_empty())
	assert_true(finale.painted_map_visual_data.validation_errors().is_empty())
	assert_true(finale.painted_map_visual_data.foreground_occluder_polygon.is_empty())
	assert_false(finale.painted_map_visual_data.foreground_full_hide_rect.has_area())
	var presentation := finale.painted_map_visual_data.presentation_profile
	assert_not_null(presentation.profile_for_unit(&"catabase_shadow_paris"))
	assert_almost_eq(
		presentation.final_visual_scale(&"catabase_shadow_paris"),
		1.7064,
		0.001,
	)


func test_encounter_durability_rises_across_the_three_rooms() -> void:
	var durability: Array[int] = []
	for room in CATABASE_RUN.rooms:
		durability.append(_total_roster_hp(room))
	assert_lt(durability[0], durability[1], str(durability))
	assert_lt(durability[1], durability[2], str(durability))
	assert_eq(durability[2], 167)


func test_middle_and_final_formations_are_valid_for_twenty_seeds() -> void:
	for room_index in [1, 2]:
		var room := CATABASE_RUN.rooms[room_index]
		assert_true(
			room.encounter_definition.is_valid(),
			str(room.encounter_definition.validation_errors()),
		)
		var grid := _grid_for_room(room)
		var planner := EncounterFormationPlanner.new(grid, Pathfinder.new(grid))
		for seed in range(20):
			var plan := planner.build_plan(
				room.encounter_definition,
				room.hero_spawn_zone,
				room.enemy_spawn_zone,
				seed,
			)
			assert_true(
				plan.get("valid", false),
				"salle %d, seed %d : %s" % [room_index + 1, seed, plan],
			)
			assert_eq(
				(plan.get("placements", []) as Array).size(),
				room.encounter_definition.get_initial_enemy_count(),
			)


func _grid_for_room(room: RoomData) -> GridData:
	var logical_size := room.grid_layout.logical_size
	var grid := GridData.new(logical_size.x, logical_size.y)
	room.grid_layout.apply_to_grid(grid)
	return grid


func _roster_ids(room: RoomData) -> Array[StringName]:
	var result: Array[StringName] = []
	for unit_data in room.encounter_definition.expanded_roster():
		result.append(unit_data.get_effective_unit_id())
	return result


func _room_enemy_ids(room: RoomData) -> Array[StringName]:
	var result: Array[StringName] = []
	for unit_data in room.enemies:
		result.append(unit_data.get_effective_unit_id())
	return result


func _total_roster_hp(room: RoomData) -> int:
	var result := 0
	for unit_data in room.encounter_definition.expanded_roster():
		result += unit_data.max_hp
	return result
