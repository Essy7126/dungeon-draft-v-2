extends GutTest

const RUN: RunData = preload("res://data/runs/odyssey.tres")
const REGISTERED_SCENE := "res://battle/painted/registered_terrain/RegisteredTerrainBattle.tscn"
const PACKAGES := ["greek_drawn_courtyard_v1", "ashen_hell_courtyard_v1", "silent_judgment_courtyard_v1", "lethe_crossing_v1", "black_oath_temple_v1"]
const DIRECTIONS := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]


func test_five_catabase_rooms_bind_their_registered_production_maps() -> void:
	assert_eq(RUN.rooms.size(), 5)
	for index in range(PACKAGES.size()):
		var room := RUN.rooms[index] as ArenaDefinition
		assert_not_null(room)
		if room == null:
			continue
		var package := "res://data/arenas/%s/" % PACKAGES[index]
		assert_eq(room.resource_path, "res://data/rooms/odyssey/room_%02d.tres" % (index + 1))
		assert_eq(room.arena_id, StringName(PACKAGES[index]))
		assert_eq(room.registered_terrain_plan_path, package + "terrain_plan.json")
		assert_true(FileAccess.file_exists(room.registered_terrain_plan_path))
		assert_not_null(room.battle_scene)
		if room.battle_scene != null:
			assert_eq(room.battle_scene.resource_path, REGISTERED_SCENE)
			assert_false(FileAccess.get_file_as_string(REGISTERED_SCENE).contains("res://tools/labs/"))
		assert_eq(room.visual_mode, ArenaDefinition.VisualMode.HYBRID)
		assert_eq(room.source_image_size, Vector2i(1920, 1200))
		var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(package + "geometry_manifest.json"))
		var grid_size: Array = manifest.grid_size
		assert_eq(room.grid_size, Vector2i(int(grid_size[0]), int(grid_size[1])))
		assert_eq(room.axis_x, Vector2(float(manifest.axis_x[0]), float(manifest.axis_x[1])))
		assert_eq(room.axis_y, Vector2(float(manifest.axis_y[0]), float(manifest.axis_y[1])))
		if index < 3:
			assert_eq(room.grid_size, Vector2i(19, 18))
			assert_eq(room.axis_x, Vector2(51.6, 25.8))
			assert_eq(room.axis_y, Vector2(-51.6, 25.8))
		assert_true(room.foreground_occluder_polygon.is_empty())
		assert_false(room.foreground_full_hide_rect.has_area())
		for decoration in room.decorations:
			assert_false(decoration.scene_path.contains("res://tools/labs/"), decoration.scene_path)
	assert_eq(RUN.rooms[2].resource_path, "res://data/rooms/odyssey/room_03.tres")
	assert_eq(RUN.rooms[2].room_name, "Catabase III — Le Jugement silencieux")


func test_persisted_projection_matches_the_registered_floor_pits_and_obstacles() -> void:
	for index in range(PACKAGES.size()):
		var room := RUN.rooms[index] as ArenaDefinition
		assert_not_null(room)
		if room == null:
			continue
		assert_not_null(room.grid_layout, room.resource_path)
		assert_not_null(room.painted_map_visual_data, room.resource_path)
		if room.grid_layout == null or room.painted_map_visual_data == null:
			continue
		var manifest_path := room.registered_terrain_plan_path.get_base_dir().path_join("geometry_manifest.json")
		var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
		assert_true(value is Dictionary, manifest_path)
		if not value is Dictionary:
			continue
		var manifest: Dictionary = value
		var floor := _cells(manifest.get("floor_cells", []))
		var blocked := {}
		for group: Dictionary in manifest.get("obstacles", []):
			blocked.merge(_cells(group.get("cells", [])))
		var pits := {}
		for group: Dictionary in manifest.get("pits", []):
			pits.merge(_cells(group.get("cells", [])))
		if index < 3:
			assert_eq(floor.size(), 217)
			assert_eq(blocked.size(), 12)
			assert_eq(pits.size(), 16)
		elif index == 3:
			assert_eq(floor.size(), 114)
			assert_eq(blocked.size(), 8)
			assert_eq(pits.size(), 6)
		else:
			assert_eq(floor.size(), 152)
			assert_eq(blocked.size(), 8)
			assert_eq(pits.size(), 8)
		assert_gt(floor.size(), blocked.size())
		for cell: Vector2i in blocked:
			assert_true(floor.has(cell), "a tactical obstacle retains its authored floor")
		assert_eq(room.grid_layout.logical_size, room.grid_size)
		var visual := room.painted_map_visual_data
		assert_eq(visual.map_id, room.arena_id)
		assert_eq(visual.logical_grid_size, room.grid_size)
		assert_eq(visual.source_image_size, room.source_image_size)
		assert_eq(visual.grid_origin, room.grid_origin)
		assert_eq(visual.axis_x, room.axis_x)
		assert_eq(visual.axis_y, room.axis_y)
		assert_eq(visual.background_texture_path, room.background_path)
		assert_true(room.grid_layout.validation_errors().is_empty())
		assert_true(visual.validation_errors().is_empty())
		assert_lt(visual.calibration_rms(), 0.001)
		var grid := GridData.new(room.grid_size.x, room.grid_size.y)
		room.grid_layout.apply_to_grid(grid)
		var actual_floor := {}
		for definition in room.cells:
			if definition != null and definition.defined and definition.cell_type != GridData.CellType.HOLE:
				actual_floor[definition.coordinate] = true
		assert_eq(actual_floor.size(), floor.size())
		for y in range(grid.rows):
			for x in range(grid.cols):
				var cell := Vector2i(x, y)
				assert_eq(actual_floor.has(cell), floor.has(cell), str(cell))
				# The legacy grid bridge represents a solid obstacle which leaves
				# sight open as HOLE. Its real FLOOR membership remains canonical
				# ArenaDefinition data, independently checked immediately above.
				if not floor.has(cell):
					assert_eq(grid.get_type(cell), GridData.CellType.HOLE, str(cell))
				elif not blocked.has(cell):
					assert_ne(grid.get_type(cell), GridData.CellType.HOLE, str(cell))
				assert_eq(grid.is_walkable(cell), floor.has(cell) and not blocked.has(cell), str(cell))
				assert_eq(grid.is_terrain_interactable(cell), floor.has(cell) and not blocked.has(cell), str(cell))
				assert_ne(grid.get_type(cell), GridData.CellType.LAVA, "lava is visual only: %s" % cell)
		for cell: Vector2i in pits:
			assert_false(floor.has(cell), "a recess remains VOID: %s" % cell)
		assert_false(room.hero_spawn_zone.is_empty())
		assert_false(room.enemy_spawn_zone.is_empty())
		if room.hero_spawn_zone.is_empty():
			continue
		var reachable := _reachable(grid, room.hero_spawn_zone[0])
		assert_eq(reachable.size(), floor.size() - blocked.size(), "all walkable cells stay connected")
		for cell: Vector2i in room.hero_spawn_zone + room.enemy_spawn_zone:
			assert_true(grid.is_walkable(cell), "spawn on free FLOOR: %s" % cell)
			assert_true(reachable.has(cell), "spawn reachable: %s" % cell)


func test_registered_plan_survives_studio_snapshot_and_terrain_update() -> void:
	var source := RUN.rooms[0] as ArenaDefinition
	var target := RUN.rooms[1] as ArenaDefinition
	assert_not_null(source)
	assert_not_null(target)
	if source == null or target == null:
		return
	assert_eq(
		RoomIntegrationFieldPolicy.classification_for(&"registered_terrain_plan_path", source),
		RoomIntegrationFieldPolicy.ARENA_OWNED,
	)
	assert_eq(
		ArenaRuntimeFieldCoverageService.classification_for("ArenaDefinition", &"registered_terrain_plan_path"),
		ArenaRuntimeFieldCoverageService.Classification.RUNTIME_CONSUMED,
	)
	var restored := ArenaDefinition.new()
	assert_true(restored.restore_snapshot(source.to_snapshot()))
	assert_eq(restored.registered_terrain_plan_path, source.registered_terrain_plan_path)
	var before := RoomDataSnapshotService.to_room_snapshot(target)
	var merged := RoomIntegrationFieldPolicy.merge_arena_into_room(restored, target)
	assert_not_null(merged)
	if merged == null:
		return
	assert_eq(merged.registered_terrain_plan_path, source.registered_terrain_plan_path)
	assert_eq(merged.battle_scene.resource_path, REGISTERED_SCENE)
	assert_eq(merged.room_name, target.room_name)
	assert_eq(merged.encounter_definition, target.encounter_definition)
	assert_eq(merged.enemies, target.enemies)
	assert_eq(merged.get_ultimate_reward_base_chance(), target.get_ultimate_reward_base_chance())
	assert_eq(merged.get_ultimate_reward_gain_range(), target.get_ultimate_reward_gain_range())
	assert_eq(RoomDataSnapshotService.to_room_snapshot(target), before)


func test_judgment_courtyard_keeps_tactical_obstacles_without_peripheral_props() -> void:
	var room := RUN.rooms[2] as ArenaDefinition
	assert_not_null(room)
	if room == null:
		return
	assert_eq(room.encounter_definition.resource_path, "res://data/encounters/odyssey_room_03_encounter.tres")
	assert_eq(room.enemies.size(), room.encounter_definition.get_initial_enemy_count())
	assert_eq(room.get_wave_count(), 1)
	assert_true(room.waves.is_empty())
	assert_eq(room.get_ultimate_reward_base_chance(), 0)
	assert_eq(room.get_ultimate_reward_gain_range(), Vector2i.ZERO)
	var root_path := room.registered_terrain_plan_path.get_base_dir()
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(root_path.path_join("geometry_manifest.json")))
	var plan: Variant = JSON.parse_string(FileAccess.get_file_as_string(room.registered_terrain_plan_path))
	assert_true(manifest is Dictionary)
	assert_true(plan is Dictionary)
	if not manifest is Dictionary or not plan is Dictionary:
		return
	assert_true(manifest.get("perimeter_props", []).is_empty())
	assert_eq(int(manifest.get("expected_perimeter_prop_count", -1)), 0)
	assert_true(plan.get("world_decor", []).is_empty())
	assert_eq(room.obstacles.size(), 12)
	assert_eq(room.decorations.size(), 12, "the twelve tactical props remain on their authored floor cells")


func test_later_maps_use_distinct_tactical_footprints_and_preserve_studio_bindings() -> void:
	var first := RUN.rooms[0] as ArenaDefinition
	assert_not_null(first)
	if first == null:
		return
	var seen_floors: Array[Dictionary] = [_authored_floor(first)]
	var cases := [
		[3, Vector2i(18, 19), Vector2(1000, 125), 114, &"lethe_crossing_v1", "Catabase IV — Le Gué du Léthé"],
		[4, Vector2i(18, 18), Vector2(960, 125), 152, &"black_oath_temple_v1", "Catabase V — Le Temple du Serment Noir"],
	]
	for expected: Array in cases:
		var room := RUN.rooms[int(expected[0])] as ArenaDefinition
		assert_not_null(room)
		if room == null:
			continue
		var floor := _authored_floor(room)
		for previous: Dictionary in seen_floors:
			assert_ne(floor, previous, "Later rooms change the tactical footprint")
		seen_floors.append(floor)
		assert_eq(room.grid_size, expected[1])
		assert_eq(room.grid_origin, expected[2])
		assert_eq(floor.size(), expected[3])
		assert_eq(room.obstacles.size(), 8)
		assert_eq(room.arena_id, expected[4])
		assert_eq(room.room_name, expected[5])
		assert_gte(room.enemy_spawn_zone.size(), room.enemies.size())
		var restored := ArenaDefinition.new()
		assert_true(restored.restore_snapshot(room.to_snapshot()))
		assert_eq(restored.registered_terrain_plan_path, room.registered_terrain_plan_path)
		assert_eq(restored.cells.size(), room.cells.size())
		var merged := RoomIntegrationFieldPolicy.merge_arena_into_room(restored, room)
		assert_not_null(merged)
		if merged != null:
			assert_eq(merged.registered_terrain_plan_path, room.registered_terrain_plan_path)
			assert_eq(merged.encounter_definition, room.encounter_definition)
			assert_eq(merged.enemies, room.enemies)
			assert_eq(merged.room_name, room.room_name)


func _authored_floor(room: ArenaDefinition) -> Dictionary:
	var result := {}
	for cell in room.cells:
		if cell != null and cell.defined and cell.cell_type != GridData.CellType.HOLE:
			result[cell.coordinate] = true
	return result


func _cells(values: Array) -> Dictionary:
	var result := {}
	for value: Array in values:
		result[Vector2i(int(value[0]), int(value[1]))] = true
	return result


func _reachable(grid: GridData, first: Vector2i) -> Dictionary:
	var seen := {first: true}
	var queue: Array[Vector2i] = [first]
	var cursor := 0
	while cursor < queue.size():
		var current := queue[cursor]
		cursor += 1
		for direction: Vector2i in DIRECTIONS:
			var neighbor := current + direction
			if not seen.has(neighbor) and grid.is_walkable(neighbor):
				seen[neighbor] = true
				queue.append(neighbor)
	return seen
