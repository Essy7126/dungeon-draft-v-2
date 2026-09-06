extends RefCounted

const BASE := preload("res://tools/philosopher_sprite_validation/cases.gd")
const SCENARIOS := ["push_lava", "push_water", "push_ice", "portal_pair", "avoid_fire", "escape_fire", "push_electric", "portal_network"]
const TERRAINS := {"push_lava": &"lava", "push_water": &"water", "push_ice": &"ice", "push_electric": &"electrified_water", "avoid_fire": &"lava", "escape_fire": &"lava"}


static func configure(arena: ArenaDefinition, scenario: String, direction: String) -> Dictionary:
	var result := {"ok": false, "scenario": scenario, "direction": direction,
		"scope": "Declared initial fixture on a memory-only copy of the canonical map. Permanent tiles use the production editor service. No runtime HP, AP, MP, positions, spells or terrain are forced."}
	if scenario not in SCENARIOS or not BASE.DIRECTIONS.has(direction):
		result.error = "unknown_terrain_fixture"
		return result
	var grid := ArenaRuntimeBridge.build_grid_from_synced_resources(arena)
	var finder := Pathfinder.new(grid)
	var forward: Vector2i = BASE.DIRECTIONS[direction]
	var side := Vector2i(-forward.y, forward.x)
	var distance := 1 if scenario.begins_with("push_") else 7
	if scenario == "avoid_fire":
		distance = 6
	elif scenario == "escape_fire":
		distance = 4
	if scenario == "portal_network":
		distance = 8
	var mage_cell := Vector2i(-1, -1)
	var best := INF
	for y in grid.rows:
		for x in grid.cols:
			var candidate := Vector2i(x, y)
			var required: Array[Vector2i] = []
			for step in range(0, maxi(distance + 1, 3)):
				required.append(candidate + forward * step)
			for step in range(0, 3):
				required.append(candidate + forward * step + side)
				required.append(candidate + forward * step - side)
			if scenario == "portal_network":
				required.append(candidate + forward * 5 + side)
			var legal := true
			for cell in required:
				var definition := arena.get_cell_definition(cell)
				if not grid.is_walkable(cell) or grid.has_vortex(cell) or definition == null or definition.terrain_id != &"stone":
					legal = false
					break
			if not legal or not finder.has_line_of_sight(candidate, candidate + forward * distance):
				continue
			var score := (Vector2(candidate) + Vector2(forward) * distance * 0.5).distance_to(Vector2(grid.cols, grid.rows) * 0.5)
			if score < best:
				best = score
				mage_cell = candidate
	if mage_cell == Vector2i(-1, -1):
		result.error = "no_clear_terrain_fixture_on_canonical_map"
		return result
	var source := load(BASE.MAGE_PATH) as UnitData
	var mage := source.duplicate(false) as UnitData
	mage.facing_dir = forward
	arena.encounter_definition = null
	arena.waves.clear()
	arena.enemies.assign([mage])
	arena.spawns.clear()
	var hero_cell := mage_cell + forward * distance
	BASE._add_spawn(arena, &"terrain_fixture_hero", ArenaSpawnDefinition.Kind.HERO_1, hero_cell)
	BASE._add_spawn(arena, &"terrain_fixture_mage", ArenaSpawnDefinition.Kind.ENEMY, mage_cell)
	result.mage_cell = mage_cell
	result.hero_cell = hero_cell
	result.direction_vector = forward
	result.permanent_tiles = []
	result.portal_cells = []
	if TERRAINS.has(scenario):
		var cell := mage_cell + forward * 2
		if scenario == "avoid_fire":
			cell = mage_cell + forward
		elif scenario == "escape_fire":
			cell = mage_cell
		var terrain_id: StringName = TERRAINS[scenario]
		if not ArenaDynamicEditingService.paint_permanent_terrain(arena, cell, terrain_id):
			result.error = "canonical_permanent_terrain_paint_failed"
			return result
		var catalog := ArenaCatalogService.terrain(terrain_id)
		result.permanent_tiles.append({"cell": cell, "terrain_id": str(terrain_id), "texture_path": catalog.base_texture.resource_path})
		result.hazard_cell = cell
	else:
		var entry := mage_cell + forward
		var exit_cell := mage_cell + forward * 5
		if scenario == "portal_pair":
			if not ArenaDynamicEditingService.place_vortex_pair(arena, entry, exit_cell):
				result.error = "canonical_portal_pair_creation_failed"
				return result
			result.portal_cells = [entry, exit_cell]
		else:
			var network := ArenaVortexNetworkService.create_network(arena, "Declared safe multi-exit combat fixture")
			network.random_destination = true
			for cell: Vector2i in [entry, exit_cell, exit_cell + side]:
				if not ArenaVortexNetworkService.add_cell(arena, network.network_id, cell):
					result.error = "canonical_portal_network_creation_failed"
					return result
				result.portal_cells.append(cell)
		result.portal_entry = entry
		result.portal_exits = (result.portal_cells as Array).slice(1)
	if not ArenaRuntimeBridge.sync_runtime_resources(arena):
		result.error = "terrain_fixture_projection_failed"
		return result
	result.modified_initial_fields = ["spawn_cells", "mage.facing_dir", "declared_permanent_tiles_or_portal_network"]
	result.canonical_mage_data = BASE.MAGE_PATH
	result.ok = true
	return result
