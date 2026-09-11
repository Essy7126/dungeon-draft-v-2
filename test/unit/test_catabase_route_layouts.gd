extends GutTest


func test_authored_destinations_are_distinct_connected_and_keep_their_content() -> void:
	var entries: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://data/rooms/catabase_routes/catalog.json")
	)
	var signatures := { }
	assert_eq(entries.size(), 36)
	for title in entries:
		var entry: Dictionary = entries[title]
		var arena := load(entry.room) as ArenaDefinition
		var source := load(entry.base_room) as ArenaDefinition
		assert_eq(arena.room_name, title)
		assert_eq(arena.background_path, source.background_path)
		assert_eq(
			arena.get_encounter_for_wave(0).expanded_roster(),
			source.get_encounter_for_wave(0).expanded_roster(),
		)
		var coordinates: Array = arena.cells.map(
			func(cell):
				return [cell.coordinate.x, cell.coordinate.y],
		)
		var signature := JSON.stringify(coordinates)
		assert_false(signatures.has(signature), title)
		signatures[signature] = title
		var plan: Dictionary = JSON.parse_string(
			FileAccess.get_file_as_string(arena.registered_terrain_plan_path)
		)
		var manifest: Dictionary = JSON.parse_string(
			FileAccess.get_file_as_string(
				arena.registered_terrain_plan_path.get_base_dir().path_join(
					plan.geometry_manifest_path
				)
			)
		)
		var manifest_cells: Array = manifest.floor_cells.map(
			func(cell):
				return [int(cell[0]), int(cell[1])],
		)
		assert_eq(JSON.stringify(manifest_cells), signature, title)
		var grid := EncounterGridFactory.build_from_room(arena)
		var cells := { }
		for cell in arena.cells:
			if grid.is_walkable(cell.coordinate):
				cells[cell.coordinate] = true
		var pending: Array = [arena.hero_spawn_zone[0]]
		var seen := { pending[0]: true }
		while not pending.is_empty():
			var cell: Vector2i = pending.pop_back()
			for step in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var next: Vector2i = cell + step
				if cells.has(next) and not seen.has(next):
					seen[next] = true
					pending.append(next)
		assert_eq(seen.size(), cells.size(), title)
		for spawn in arena.hero_spawn_zone + arena.enemy_spawn_zone:
			assert_true(seen.has(spawn), title)


func test_factory_and_explorer_resolve_the_same_destination_across_seeds() -> void:
	var explorer = preload("res://tools/run_explorer/route_explorer_catalog.gd")
	var by_title := { }
	for seed_value in [2401, 1, 2, 9]:
		for node in ExpeditionRouteCatalog.create_nodes(seed_value):
			if not ExpeditionRouteCatalog.is_combat(node.kind):
				continue
			var room := ExpeditionRunFactory.make_room(node, seed_value) as ArenaDefinition
			assert_eq(room.room_name, node.title)
			assert_eq(room.registered_terrain_plan_path, explorer.describe(node).plan)
			if by_title.has(node.title):
				assert_eq(room.registered_terrain_plan_path, by_title[node.title])
			by_title[node.title] = room.registered_terrain_plan_path
			var grid := EncounterGridFactory.build_from_room(room)
			for cell in room.enemy_spawn_zone:
				assert_true(grid.is_walkable(cell), str(node.title))


func test_enemy_formation_fits_each_new_destination() -> void:
	for node in ExpeditionRouteCatalog.create_nodes(2401):
		if not ExpeditionRouteCatalog.is_combat(node.kind) or int(node.depth) in [1, 7, 15, 20]:
			continue
		var room := ExpeditionRunFactory.make_room(node, 2401)
		var grid := EncounterGridFactory.build_from_room(room)
		var planner := EncounterFormationPlanner.new(grid, Pathfinder.new(grid))
		var encounter := room.get_encounter_for_wave(0)
		var heroes: Array[Vector2i] = [room.hero_spawn_zone[0]]
		var plan := planner.build_plan(encounter, heroes, room.enemy_spawn_zone, 2401)
		assert_true(plan.valid, str(node.title))
		assert_eq(plan.placements.size(), encounter.expanded_roster().size(), str(node.title))
