class_name ArenaRuntimeProjectionService
extends RefCounted

static func build(arena: ArenaDefinition, configs: Array[SurfaceConfig] = []) -> ArenaRuntimeState:
	if arena == null:
		return null
	var before := RoomDataSnapshotService.room_fingerprint(arena)
	var snapshot := RoomDataSnapshotService.capture(arena)
	var projection := ArenaDefinition.new()
	if not RoomDataSnapshotService.restore(projection, snapshot):
		return null
	if not ArenaRuntimeBridge.sync_runtime_resources(projection):
		return null
	var state := ArenaRuntimeState.new()
	state.source_fingerprint = before
	state.arena_projection = projection
	state.layout = projection.grid_layout
	state.visual_data = projection.painted_map_visual_data
	state.visual_profile = projection.arena_visual_profile
	state.hero_spawns.assign(projection.hero_spawn_zone)
	state.enemy_spawns.assign(projection.enemy_spawn_zone)
	state.grid = GridData.new(projection.grid_size.x, projection.grid_size.y)
	state.layout.apply_to_grid(state.grid)
	var resolved_configs: Array[SurfaceConfig] = []
	resolved_configs.assign(configs)
	if resolved_configs.is_empty():
		state.surface_resolution = ArenaThemeRegistry.resolve(arena)
		resolved_configs.assign(state.surface_resolution.get("surface_configs", []))
	else:
		state.surface_resolution = {
			"ok": true,
			"requested_theme_id": arena.theme_id,
			"resolved_theme_id": &"explicit_configs",
			"surface_configs": resolved_configs,
			"fallback_used": false,
			"warning": "",
		}
	state.configure_surfaces(resolved_configs)
	for definition in arena.cells:
		if definition == null or not state.surface_service.has_state(definition.coordinate):
			continue
		var cell_state := state.surface_service.get_state(definition.coordinate)
		cell_state.configure_base_terrain(
			definition.terrain_id,
			state.grid.get_type(definition.coordinate),
			arena.obstacle_at(definition.coordinate) != null
		)
	assert(
		RoomDataSnapshotService.room_fingerprint(arena) == before,
		"La projection runtime ne doit jamais muter ArenaDefinition."
	)
	return state


static func parity_report(arena: ArenaDefinition, state: ArenaRuntimeState) -> Dictionary:
	if arena == null or state == null or state.grid == null:
		return {"ok": false, "error": "Projection incomplete."}
	var mismatches: Array[Dictionary] = []
	for y in range(arena.grid_size.y):
		for x in range(arena.grid_size.x):
			var cell := Vector2i(x, y)
			var definition := arena.get_cell_definition(cell)
			if definition == null or not definition.defined or definition.border:
				continue
			var expected := definition.cell_type
			var obstacle := arena.obstacle_at(cell)
			if obstacle != null and obstacle.blocks_movement and obstacle.wall_id == &"":
				expected = GridData.CellType.WALL \
					if obstacle.blocks_line_of_sight else GridData.CellType.HOLE
			if state.grid.get_type(cell) != expected:
				mismatches.append({
					"cell": cell,
					"expected": expected,
					"actual": state.grid.get_type(cell),
				})
	return {
		"ok": mismatches.is_empty(),
		"mismatches": mismatches,
		"source_unchanged": RoomDataSnapshotService.room_fingerprint(arena) \
			== state.source_fingerprint,
	}
