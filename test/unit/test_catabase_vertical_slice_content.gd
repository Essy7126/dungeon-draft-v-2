extends GutTest

const CATABASE_RUN: RunData = preload("res://data/runs/odyssey.tres")
const EXPECTED_MIDDLE_ROSTER: Array[StringName] = [
	&"odyssey_skirmisher",
	&"odyssey_skirmisher",
	&"spectre_greatsword",
]
const EXPECTED_JUDGMENT_ROSTER: Array[StringName] = [
	&"odyssey_champion",
	&"catabase_shadow_paris",
]


func test_catabase_keeps_five_distinct_ordered_arenas() -> void:
	assert_eq(CATABASE_RUN.rooms.size(), 5)
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
	assert_eq(names.size(), 5, "chaque salle garde une identité propre")
	assert_eq(map_ids.size(), 5, "chaque salle garde une arène visuelle propre")


func test_middle_room_is_the_melee_formation_escalation() -> void:
	var room := CATABASE_RUN.rooms[1]
	assert_eq(room.visual_mode, ArenaDefinition.VisualMode.HYBRID)
	assert_eq(_roster_ids(room), EXPECTED_MIDDLE_ROSTER)
	assert_eq(room.encounter_definition.get_initial_enemy_count(), 3)
	assert_eq(room.encounter_definition.living_enemy_cap, 3)
	assert_true(room.encounter_definition.formation_profiles.has(&"double_line"))
	assert_true(room.encounter_definition.formation_profiles.has(&"split"))
	assert_eq(_room_enemy_ids(room), EXPECTED_MIDDLE_ROSTER)


func test_shadow_paris_stays_in_the_third_room_with_a_melee_anchor() -> void:
	var judgment := CATABASE_RUN.rooms[2]
	assert_eq(_roster_ids(judgment), EXPECTED_JUDGMENT_ROSTER)
	assert_eq(_room_enemy_ids(judgment), EXPECTED_JUDGMENT_ROSTER)
	assert_eq(judgment.encounter_definition.room_index, 3)
	assert_eq(judgment.encounter_definition.living_enemy_cap, 2)
	assert_true(judgment.encounter_definition.formation_profiles.has(&"split"))
	var paris := judgment.enemies[1]
	assert_eq(paris.unit_name, "L’Ombre de Paris")
	assert_eq(paris.ai_behavior, EnemyAI.BEHAVIOR_RANGED)
	assert_true(paris.keep_distance)
	assert_eq(paris.spells.size(), 1)
	assert_eq(paris.spells[0].spell_id, &"catabase_shadow_paris_arrow")
	assert_true(paris.spells[0].needs_line_of_sight)
	assert_eq(judgment.grid_layout.logical_size, Vector2i(19, 18))
	assert_eq(judgment.painted_map_visual_data.logical_grid_size, Vector2i(19, 18))
	assert_eq(
		judgment.painted_map_visual_data.background_texture_path,
		"res://data/arenas/silent_judgment_courtyard_v1/grid_reference.png",
	)
	assert_eq(
		judgment.painted_map_visual_data.load_background_texture().get_size(),
		Vector2(judgment.painted_map_visual_data.source_image_size),
	)
	assert_lt(judgment.painted_map_visual_data.calibration_rms(), 0.001)
	assert_true(judgment.grid_layout.validation_errors().is_empty())
	assert_true(judgment.painted_map_visual_data.validation_errors().is_empty())
	assert_true(judgment.painted_map_visual_data.foreground_occluder_polygon.is_empty())
	assert_false(judgment.painted_map_visual_data.foreground_full_hide_rect.has_area())
	var presentation := judgment.painted_map_visual_data.presentation_profile
	assert_not_null(presentation.profile_for_unit(&"catabase_shadow_paris"))
	assert_almost_eq(
		presentation.final_visual_scale(&"catabase_shadow_paris"),
		1.7064,
		0.001,
	)


func test_encounter_durability_rises_across_the_five_rooms() -> void:
	var durability: Array[int] = []
	for room in CATABASE_RUN.rooms:
		durability.append(_total_roster_hp(room))
	assert_lt(durability[0], durability[1], str(durability))
	assert_lt(durability[1], durability[2], str(durability))
	assert_eq(durability[2], 167)
	assert_lt(durability[2], durability[3], str(durability))
	assert_eq(durability[3], 173)
	assert_lt(durability[3], durability[4], str(durability))
	assert_eq(durability[4], 243)


func test_later_room_formations_are_valid_for_twenty_seeds() -> void:
	for room_index in range(1, CATABASE_RUN.rooms.size()):
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
			if room_index == 3:
				for placement: Dictionary in plan.get("placements", []):
					var cell: Vector2i = placement.cell
					assert_gte(cell.y, 10, "Lethe's enemies deploy beyond the passage in the second court")
			elif room_index == 4:
				for placement: Dictionary in plan.get("placements", []):
					var cell: Vector2i = placement.cell
					assert_lte(cell.y, 5, "The black temple's enemies deploy opposite the heroes in the north of the nave")


func test_lethe_and_black_temple_extend_the_run_after_the_judgment_of_paris() -> void:
	var cases := [
		[3, "Catabase IV — Le Gué du Léthé", &"catabase_room_04", 160,
			[&"spectre_greatsword", &"spectre_greatsword", &"odyssey_skirmisher"]],
		[4, "Catabase V — Le Temple du Serment Noir", &"catabase_room_05", 180,
			[&"odyssey_champion", &"spectre_greatsword", &"spectre_greatsword"]],
	]
	for expected: Array in cases:
		var index := int(expected[0])
		var room := CATABASE_RUN.rooms[index]
		assert_eq(room.room_name, expected[1])
		assert_eq(room.resource_path, "res://data/rooms/odyssey/room_%02d.tres" % (index + 1))
		assert_eq(room.encounter_definition.resource_path, "res://data/encounters/%s_encounter.tres" % expected[2])
		assert_eq(room.encounter_definition.room_index, index + 1)
		assert_eq(room.encounter_definition.encounter_id, expected[2])
		assert_eq(room.encounter_definition.base_xp, expected[3])
		assert_eq(room.encounter_definition.get_initial_enemy_count(), 3)
		assert_eq(room.encounter_definition.living_enemy_cap, 3)
		assert_eq(_roster_ids(room), expected[4])
		assert_eq(_room_enemy_ids(room), expected[4])
		assert_eq(room.get_wave_count(), 1)
		assert_true(room.waves.is_empty())
		assert_eq(room.get_ultimate_reward_base_chance(), 0)
		assert_eq(room.get_ultimate_reward_gain_range(), Vector2i.ZERO)
	assert_true(CATABASE_RUN.is_single_encounter_flow())
	assert_eq(CATABASE_RUN.maximum_waves_per_room, 1)


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
