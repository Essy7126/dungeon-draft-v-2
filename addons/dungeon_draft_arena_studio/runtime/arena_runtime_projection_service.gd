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
	state.configure_surfaces(resolved_configs, projection)
	assert(
		RoomDataSnapshotService.room_fingerprint(arena) == before,
		"La projection runtime ne doit jamais muter ArenaDefinition."
	)
	return state


static func parity_report(arena: ArenaDefinition, state: ArenaRuntimeState) -> Dictionary:
	if arena == null or state == null or state.grid == null:
		return {"ok": false, "error": "Projection incomplete."}
	var mismatches: Array[Dictionary] = []
	var runtime_hole_cells: Array[String] = []
	var runtime_interactable_cells: Array[String] = []
	for y in range(arena.grid_size.y):
		for x in range(arena.grid_size.x):
			var cell := Vector2i(x, y)
			var expected := state.layout.resolved_cell_type(cell)
			if state.grid.get_type(cell) != expected:
				mismatches.append({
					"cell": cell,
					"expected": expected,
					"actual": state.grid.get_type(cell),
				})
			var key := ArenaTopologySignatureService.coordinate_key(cell)
			if state.grid.get_type(cell) == GridData.CellType.HOLE:
				runtime_hole_cells.append(key)
			if state.grid.is_terrain_interactable(cell):
				runtime_interactable_cells.append(key)
	var canonical := ArenaTopologySignatureService.build(arena)
	var projected := ArenaTopologySignatureService.build(state.arena_projection)
	var expected_surface_cells := runtime_interactable_cells
	var actual_surface_cells := ArenaTopologySignatureService.normalized_keys(
		state.surface_service.state_cells()
	)
	var missing_surface_cells := ArenaTopologySignatureService.difference(
		expected_surface_cells, actual_surface_cells
	)
	var unexpected_surface_cells := ArenaTopologySignatureService.difference(
		actual_surface_cells, expected_surface_cells
	)
	return {
		"ok": mismatches.is_empty() \
			and canonical.topology_hash == projected.topology_hash \
			and missing_surface_cells.is_empty() \
			and unexpected_surface_cells.is_empty(),
		"mismatches": mismatches,
		"canonical_topology_hash": canonical.topology_hash,
		"runtime_topology_hash": projected.topology_hash,
		"topology": projected,
		"runtime_hole_cells": runtime_hole_cells,
		"runtime_interactable_cells": runtime_interactable_cells,
		"surface_cells": actual_surface_cells,
		"missing_surface_cells": missing_surface_cells,
		"unexpected_surface_cells": unexpected_surface_cells,
		"source_unchanged": RoomDataSnapshotService.room_fingerprint(arena) \
			== state.source_fingerprint,
	}
