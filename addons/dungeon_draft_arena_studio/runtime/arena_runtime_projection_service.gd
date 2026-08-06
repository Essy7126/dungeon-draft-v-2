class_name ArenaRuntimeProjectionService
extends RefCounted

const DEFAULT_SURFACE_CONFIG_PATHS := [
	"res://battle/dynamic_terrain/surface_configs/forest_none.tres",
	"res://battle/dynamic_terrain/surface_configs/forest_fire.tres",
	"res://battle/dynamic_terrain/surface_configs/forest_water.tres",
	"res://battle/dynamic_terrain/surface_configs/forest_ice.tres",
]


static func build(arena: ArenaDefinition, configs: Array[SurfaceConfig] = []) -> ArenaRuntimeState:
	if arena == null:
		return null
	var before := ArenaEditSession.fingerprint(arena.to_snapshot())
	var projection := ArenaDefinition.new()
	if not projection.restore_snapshot(arena.to_snapshot()):
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
	var resolved_configs := configs
	if resolved_configs.is_empty():
		resolved_configs = _default_configs()
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
		ArenaEditSession.fingerprint(arena.to_snapshot()) == before,
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
		"source_unchanged": ArenaEditSession.fingerprint(arena.to_snapshot()) \
			== state.source_fingerprint,
	}


static func _default_configs() -> Array[SurfaceConfig]:
	var result: Array[SurfaceConfig] = []
	for path in DEFAULT_SURFACE_CONFIG_PATHS:
		if ResourceLoader.exists(path):
			var config := load(path) as SurfaceConfig
			if config != null:
				result.append(config)
	return result
