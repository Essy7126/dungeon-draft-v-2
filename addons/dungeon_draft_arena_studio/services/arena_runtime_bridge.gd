@tool
class_name ArenaRuntimeBridge
extends RefCounted

enum SyncScope { FULL, GRID_TRANSFORM }

static var _instrumentation_enabled := false
static var _instrumentation := {}


static func begin_instrumentation() -> void:
	_instrumentation_enabled = true
	_instrumentation = {
		"sync_runtime_resources": 0,
		"grid_data_builds": 0,
		"pathfinder_builds": 0,
	}


static func end_instrumentation() -> Dictionary:
	var result := _instrumentation.duplicate(true)
	_instrumentation_enabled = false
	return result


static func instrumentation_snapshot() -> Dictionary:
	return _instrumentation.duplicate(true)


static func _count_instrumentation(key: StringName) -> void:
	if _instrumentation_enabled:
		_instrumentation[key] = int(_instrumentation.get(key, 0)) + 1


static func sync_runtime_resources(
		arena: ArenaDefinition,
		scope := SyncScope.FULL
	) -> bool:
	_count_instrumentation(&"sync_runtime_resources")
	if arena == null or arena.grid_size.x <= 0 or arena.grid_size.y <= 0:
		return false
	if scope == SyncScope.GRID_TRANSFORM and _sync_grid_transform_projection(arena):
		return true
	ArenaVortexNetworkService.migrate_legacy_pairs(arena)
	var layout := RoomGridLayout.new()
	layout.layout_id = arena.arena_id
	layout.debug_name = arena.display_name
	layout.logical_size = arena.grid_size
	layout.layout_rows = _build_layout_rows(arena)
	layout.cell_type_overrides = _build_type_overrides(arena)
	layout.terrain_property_overrides = _build_property_overrides(arena)
	layout.vortex_links = _build_vortex_links(arena)
	layout.vortex_networks = _build_vortex_networks(arena)
	layout.visual_only_cells = arena.border_cells()
	layout.objective_cells.assign(arena.objectives.map(func(value): return value.cell))
	arena.grid_layout = layout

	var visual := PaintedMapVisualData.new()
	visual.map_id = arena.arena_id
	visual.debug_name = arena.display_name
	visual.background_texture_path = arena.background_path
	visual.source_image_size = arena.source_image_size
	visual.logical_grid_size = arena.grid_size
	visual.grid_origin = arena.grid_origin
	visual.axis_x = arena.axis_x
	visual.axis_y = arena.axis_y
	visual.image_offset = arena.image_offset
	visual.image_scale = arena.image_scale
	visual.foreground_texture_path = arena.foreground_path
	visual.occlusion_mask_path = arena.occlusion_mask_path
	visual.foreground_offset = arena.foreground_offset
	visual.foreground_scale = arena.foreground_scale
	visual.foreground_occluder_polygon = arena.foreground_occluder_polygon.duplicate()
	visual.foreground_occluder_sort_y = arena.foreground_occluder_sort_y
	visual.foreground_full_hide_rect = arena.foreground_full_hide_rect
	visual.camera_offset = arena.camera_offset
	visual.camera_zoom = arena.camera_zoom
	visual.calibration_cells = arena.calibration_cells.duplicate()
	visual.calibration_pixels = arena.calibration_pixels.duplicate()
	if ResourceLoader.exists(arena.presentation_profile_path):
		visual.presentation_profile = load(arena.presentation_profile_path) \
			as BattlePresentationProfile
	arena.painted_map_visual_data = visual
	if arena.visual_mode != ArenaDefinition.VisualMode.PAINTED \
			and arena.modular_visual_profile != null:
		arena.arena_visual_profile = arena.modular_visual_profile.resolved_tile_visual_profile()
	else:
		arena.arena_visual_profile = null

	arena.room_name = arena.display_name
	arena.hero_spawn_zone = []
	arena.enemy_spawn_zone = []
	for spawn in arena.spawns:
		if spawn == null:
			continue
		if spawn.is_hero() and not arena.hero_spawn_zone.has(spawn.cell):
			arena.hero_spawn_zone.append(spawn.cell)
		elif spawn.is_enemy() and not arena.enemy_spawn_zone.has(spawn.cell):
			arena.enemy_spawn_zone.append(spawn.cell)
	# EncounterDefinition n'est volontairement pas @tool dans le projet. En
	# contexte editeur, Godot le charge donc comme placeholder : conserver le
	# roster importe et laisser painted_battle l'etendre au lancement reel.
	if arena.encounter_definition != null and not Engine.is_editor_hint():
		arena.enemies = arena.encounter_definition.expanded_roster()
	var current_scene_path := arena.battle_scene.resource_path \
		if arena.battle_scene != null else ""
	if arena.visual_mode == ArenaDefinition.VisualMode.MODULAR \
			and current_scene_path in ["", ArenaDefinition.DEFAULT_BATTLE_SCENE] \
			and ResourceLoader.exists(ArenaDefinition.MODULAR_BATTLE_SCENE):
		arena.battle_scene = load(ArenaDefinition.MODULAR_BATTLE_SCENE) as PackedScene
	elif arena.visual_mode != ArenaDefinition.VisualMode.MODULAR \
			and arena.battle_scene == null \
			and ResourceLoader.exists(ArenaDefinition.DEFAULT_BATTLE_SCENE):
		arena.battle_scene = load(ArenaDefinition.DEFAULT_BATTLE_SCENE) as PackedScene
	return true


static func _sync_grid_transform_projection(arena: ArenaDefinition) -> bool:
	# La topologie, les terrains, spawns et rencontres sont inchangÃ©s. Mettre Ã 
	# jour la projection spatiale existante suffit et Ã©vite de reconstruire le
	# RoomGridLayout complet au relÃ¢chement du gizmo.
	var visual := arena.painted_map_visual_data
	if visual == null:
		return false
	visual.grid_origin = arena.grid_origin
	visual.axis_x = arena.axis_x
	visual.axis_y = arena.axis_y
	visual.calibration_cells = arena.calibration_cells.duplicate()
	visual.calibration_pixels = arena.calibration_pixels.duplicate()
	return true


static func build_grid(arena: ArenaDefinition) -> GridData:
	_count_instrumentation(&"grid_data_builds")
	var projection := _runtime_projection_copy(arena)
	if projection == null or not sync_runtime_resources(projection):
		return null
	var grid := GridData.new(projection.grid_size.x, projection.grid_size.y)
	projection.grid_layout.apply_to_grid(grid)
	return grid


static func build_pathfinder(arena: ArenaDefinition) -> Pathfinder:
	_count_instrumentation(&"pathfinder_builds")
	var grid := build_grid(arena)
	return Pathfinder.new(grid) if grid != null else null


static func runtime_signature(arena: ArenaDefinition) -> Dictionary:
	var projection := _runtime_projection_copy(arena)
	if projection == null or not sync_runtime_resources(projection):
		return {}
	var grid := GridData.new(projection.grid_size.x, projection.grid_size.y)
	projection.grid_layout.apply_to_grid(grid)
	var centers := {}
	var display_centers := {}
	var types := {}
	var runtime_hole_cells: Array[String] = []
	var runtime_interactable_cells: Array[String] = []
	for y in range(projection.grid_size.y):
		for x in range(projection.grid_size.x):
			var cell := Vector2i(x, y)
			var key := ArenaTopologySignatureService.coordinate_key(cell)
			centers[key] = projection.painted_map_visual_data.cell_to_image(cell)
			display_centers[key] = projection.painted_map_visual_data.cell_to_display(cell)
			types[key] = grid.get_type(cell)
			if grid.get_type(cell) == GridData.CellType.HOLE:
				runtime_hole_cells.append(key)
			if grid.is_terrain_interactable(cell):
				runtime_interactable_cells.append(key)
	var topology := ArenaTopologySignatureService.build(projection)
	return {
		"size": projection.grid_size,
		"centers": centers,
		"display_centers": display_centers,
		"types": types,
		"hero_spawns": projection.hero_spawn_zone.duplicate(),
		"enemy_spawns": projection.enemy_spawn_zone.duplicate(),
		"battle_scene": projection.battle_scene.resource_path if projection.battle_scene != null else "",
		"defined_cells": topology.defined_cells.duplicate(),
		"visible_floor_cells": topology.visible_floor_cells.duplicate(),
		"void_cells": topology.void_cells.duplicate(),
		"runtime_hole_cells": runtime_hole_cells,
		"runtime_interactable_cells": runtime_interactable_cells,
		"topology_hash": topology.topology_hash,
		"topology": topology,
	}


static func _runtime_projection_copy(arena: ArenaDefinition) -> ArenaDefinition:
	if arena == null:
		return null
	var projection := ArenaDefinition.new()
	if not projection.restore_snapshot(arena.to_snapshot()):
		return null
	return projection


static func _build_layout_rows(arena: ArenaDefinition) -> PackedStringArray:
	var rows := PackedStringArray()
	for y in range(arena.grid_size.y):
		var row := ""
		for x in range(arena.grid_size.x):
			var cell := Vector2i(x, y)
			var definition := arena.get_cell_definition(cell)
			var obstacle := arena.obstacle_at(cell)
			if ArenaTopologySignatureService.is_void_definition(definition) \
					or definition.border:
				row += RoomGridLayout.VOID
			elif obstacle != null and obstacle.blocks_movement and obstacle.wall_id == &"":
				row += RoomGridLayout.BLOCKED \
					if obstacle.blocks_line_of_sight else RoomGridLayout.VOID
			elif not definition.playable:
				row += RoomGridLayout.VOID
			else:
				row += RoomGridLayout.WALKABLE
		rows.append(row)
	return rows


static func _build_type_overrides(arena: ArenaDefinition) -> Dictionary:
	var overrides := {}
	for definition in arena.cells:
		if ArenaTopologySignatureService.is_void_definition(definition) \
				or definition.border:
			continue
		var obstacle := arena.obstacle_at(definition.coordinate)
		if obstacle != null and obstacle.blocks_movement and obstacle.wall_id == &"":
			overrides[definition.coordinate] = GridData.CellType.WALL \
				if obstacle.blocks_line_of_sight else GridData.CellType.HOLE
		elif not definition.playable:
			continue
		elif definition.cell_type != GridData.CellType.NORMAL:
			overrides[definition.coordinate] = definition.cell_type
	return overrides


static func _build_property_overrides(arena: ArenaDefinition) -> Dictionary:
	var overrides := {}
	for definition in arena.cells:
		if ArenaTopologySignatureService.is_void_definition(definition) \
				or definition.border or not definition.playable:
			continue
		var terrain := ArenaCatalogService.terrain(definition.terrain_id)
		if terrain == null:
			continue
		var properties := {
			"terrain_id": terrain.stable_id,
			"walkable": terrain.walkable,
			"transparent": terrain.transparent,
			"projectile_passable": terrain.projectile_passable,
			"movement_cost": terrain.movement_cost,
			"ai_danger_weight": terrain.ai_danger_weight,
		}
		var obstacle := arena.obstacle_at(definition.coordinate)
		if obstacle != null:
			if obstacle.blocks_movement:
				properties["walkable"] = false
			if obstacle.blocks_line_of_sight:
				properties["transparent"] = false
			if obstacle.blocks_projectiles:
				properties["projectile_passable"] = false
		overrides[definition.coordinate] = properties
	return overrides


static func _build_vortex_links(arena: ArenaDefinition) -> Dictionary:
	var links := {}
	for pair in arena.vortex_pairs:
		if pair == null or not pair.runtime_enabled:
			continue
		links[pair.entry_cell] = pair.exit_cell
		if pair.bidirectional:
			links[pair.exit_cell] = pair.entry_cell
	return links


static func _build_vortex_networks(arena: ArenaDefinition) -> Dictionary:
	var result := {}
	for network in arena.vortex_networks:
		if network == null or not network.enabled:
			continue
		var cells := network.unique_cells()
		var data := {
			"network_id": network.network_id,
			"cells": cells,
			"enabled": network.enabled,
			"allowed_teams": network.allowed_teams,
		}
		for cell in cells:
			result[cell] = data
	return result
