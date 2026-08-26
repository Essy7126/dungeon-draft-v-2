@tool
class_name ArenaDynamicEditingService
extends RefCounted

## Opérations métier partagées par le mode intégré et le Lab standalone.
## ArenaDefinition reste l'autorité; les GridData et scènes sont dérivés.


static func paint_terrain(
		arena: ArenaDefinition,
		cell: Vector2i,
		terrain_id: StringName
	) -> bool:
	if arena == null or not arena.is_in_bounds(cell) or not ArenaTerrainRegistry.has(terrain_id):
		return false
	var before := arena.get_cell_definition(cell)
	var before_data := before.to_dict() if before != null else {}
	var definition := before if before != null else arena.ensure_cell(cell)
	if definition == null or not ArenaTerrainRegistry.configure_cell(definition, terrain_id):
		return false
	if terrain_id == &"void":
		arena.obstacles = arena.obstacles.filter(func(value):
			return value != null and value.cell != cell
		)
		arena.spawns = arena.spawns.filter(func(value):
			return value != null and value.cell != cell
		)
		arena.objectives = arena.objectives.filter(func(value):
			return value != null and value.cell != cell
		)
		arena.decorations = arena.decorations.filter(func(value):
			return value != null and value.cell != cell
		)
		arena.vortex_pairs = arena.vortex_pairs.filter(func(value):
			return value != null and not value.contains(cell)
		)
		for network in arena.vortex_networks:
			if network != null:
				network.cells.erase(cell)
	var changed := before_data != definition.to_dict()
	if changed:
		ArenaRuntimeBridge.sync_runtime_resources(arena)
	return changed


static func paint_terrain_local(
		arena: ArenaDefinition,
		cell: Vector2i,
		terrain_id: StringName
	) -> bool:
	## Mutation canonique sans reconstruction dérivée. Réservée aux transactions
	## qui garantissent une synchronisation unique à leur commit.
	if arena == null or not arena.is_in_bounds(cell) or not ArenaTerrainRegistry.has(terrain_id):
		return false
	var before := arena.get_cell_definition(cell)
	var before_data := before.to_dict() if before != null else {}
	var definition := before if before != null else arena.ensure_cell(cell)
	if definition == null or not ArenaTerrainRegistry.configure_cell(definition, terrain_id):
		return false
	if terrain_id == &"void":
		arena.obstacles = arena.obstacles.filter(func(value):
			return value != null and value.cell != cell
		)
		arena.spawns = arena.spawns.filter(func(value):
			return value != null and value.cell != cell
		)
		arena.objectives = arena.objectives.filter(func(value):
			return value != null and value.cell != cell
		)
		arena.decorations = arena.decorations.filter(func(value):
			return value != null and value.cell != cell
		)
		arena.vortex_pairs = arena.vortex_pairs.filter(func(value):
			return value != null and not value.contains(cell)
		)
		for network in arena.vortex_networks:
			if network != null:
				network.cells.erase(cell)
	return before_data != definition.to_dict()


static func paint_permanent_terrain(
		arena: ArenaDefinition,
		cell: Vector2i,
		terrain_id: StringName
	) -> bool:
	if not ArenaPermanentTerrainPaintService.can_paint(arena, terrain_id):
		return false
	return paint_terrain(arena, cell, terrain_id)


static func paint_permanent_terrain_local(
		arena: ArenaDefinition,
		cell: Vector2i,
		terrain_id: StringName
	) -> bool:
	if not ArenaPermanentTerrainPaintService.can_paint(arena, terrain_id):
		return false
	return paint_terrain_local(arena, cell, terrain_id)


static func place_wall(
		arena: ArenaDefinition,
		cell: Vector2i,
		wall_id: StringName,
		sync_runtime := true
	) -> bool:
	if arena == null or not arena.is_in_bounds(cell):
		return false
	if wall_id == &"remove" or wall_id == &"":
		return remove_wall(arena, cell, sync_runtime)
	if not ArenaWallRegistry.has(wall_id):
		return false
	var cell_definition := arena.get_cell_definition(cell)
	if cell_definition == null or not cell_definition.defined or cell_definition.border:
		return false
	var obstacle := arena.obstacle_at(cell)
	var before := obstacle.to_dict() if obstacle != null else {}
	if obstacle == null:
		obstacle = ArenaObstacleDefinition.new()
		obstacle.obstacle_id = StringName("wall_%d_%d" % [cell.x, cell.y])
		obstacle.cell = cell
		arena.obstacles.append(obstacle)
	var config := ArenaWallRegistry.config_for(wall_id)
	obstacle.wall_id = wall_id
	obstacle.wall_config = config
	obstacle.visual_variant = wall_id
	obstacle.preset = ArenaObstacleDefinition.Preset.FULL_WALL
	if config != null:
		obstacle.blocks_movement = config.blocks_movement
		obstacle.blocks_line_of_sight = config.blocks_line_of_sight
		obstacle.blocks_projectiles = config.blocks_projectiles
	else:
		obstacle.apply_preset(ArenaObstacleDefinition.Preset.FULL_WALL)
	obstacle.blocks_push = true
	if sync_runtime:
		ArenaRuntimeBridge.sync_runtime_resources(arena)
	return before != obstacle.to_dict()


static func remove_wall(
		arena: ArenaDefinition,
		cell: Vector2i,
		sync_runtime := true
	) -> bool:
	if arena == null:
		return false
	var before := arena.obstacles.size()
	arena.obstacles = arena.obstacles.filter(func(value):
		return value != null and (value.cell != cell or value.wall_id == &"")
	)
	if arena.obstacles.size() == before:
		return false
	if sync_runtime:
		ArenaRuntimeBridge.sync_runtime_resources(arena)
	return true


static func place_spawn(
		arena: ArenaDefinition,
		cell: Vector2i,
		kind: int,
		sync_runtime := true
	) -> bool:
	return ArenaEditingService.place_spawn(arena, cell, kind, sync_runtime)


static func move_or_place_primary_spawn(
		arena: ArenaDefinition,
		hero: bool,
		cell: Vector2i
	) -> bool:
	if arena == null or not arena.is_in_bounds(cell):
		return false
	var matches := arena.spawns.filter(func(value):
		return value != null and (value.is_hero() if hero else value.is_enemy())
	)
	var spawn: ArenaSpawnDefinition = matches[0] if not matches.is_empty() else null
	var created := spawn == null
	if spawn == null:
		spawn = ArenaSpawnDefinition.new()
		spawn.kind = ArenaSpawnDefinition.Kind.HERO_1 if hero else ArenaSpawnDefinition.Kind.ENEMY
		spawn.spawn_id = &"lab_hero" if hero else &"lab_enemy"
		spawn.unit_id = &"elf" if hero else &"encounter_enemy"
		arena.spawns.append(spawn)
	if not created and spawn.cell == cell:
		return false
	spawn.cell = cell
	ArenaRuntimeBridge.sync_runtime_resources(arena)
	return true


static func place_objective(arena: ArenaDefinition, cell: Vector2i) -> bool:
	if arena == null or arena.get_cell_definition(cell) == null:
		return false
	for objective in arena.objectives:
		if objective != null and objective.cell == cell:
			return false
	var objective := ArenaObjectiveDefinition.new()
	objective.objective_id = StringName("objective_%d_%d" % [cell.x, cell.y])
	objective.cell = cell
	objective.description = "Objectif place depuis Construction dynamique"
	arena.objectives.append(objective)
	return true


static func place_decoration(arena: ArenaDefinition, cell: Vector2i) -> bool:
	if arena == null or arena.get_cell_definition(cell) == null:
		return false
	for decoration in arena.decorations:
		if decoration != null and decoration.cell == cell:
			return false
	var decoration := ArenaDecorationDefinition.new()
	decoration.decoration_id = StringName("decoration_%d_%d" % [cell.x, cell.y])
	decoration.visual_variant = &"marker"
	decoration.cell = cell
	arena.decorations.append(decoration)
	return true


## Entrée métier de la bibliothèque unifiée. Le descripteur choisit le contrat
## et le payload ; aucun composant visuel ne traduit lui-même les familles.
static func apply_placeable(
		arena: ArenaDefinition,
		definition: TerrainPlaceableDefinition,
		cell: Vector2i,
		erase := false,
		sync_runtime := true
	) -> bool:
	if arena == null or definition == null:
		return false
	match definition.placement_kind:
		TerrainPlaceableDefinition.PlacementKind.PERMANENT_TERRAIN:
			var terrain_id := StringName(definition.payload.get("terrain_id", &""))
			if erase:
				var base_id := arena.modular_visual_profile.base_terrain_id \
					if arena.modular_visual_profile != null else &"stone"
				return paint_terrain(arena, cell, base_id)
			if arena.visual_mode == ArenaDefinition.VisualMode.PAINTED:
				var paintability := ArenaPermanentTerrainPaintService.paintability(
					arena, terrain_id
				)
				if StringName(paintability.get("reason_code", &"")) \
						!= &"painted_auto_hybrid":
					return false
				var current := arena.get_cell_definition(cell)
				var inferred_base: StringName = &"stone"
				if current != null and current.terrain_id != &"":
					inferred_base = current.terrain_id
				arena.visual_mode = ArenaDefinition.VisualMode.HYBRID
				if arena.modular_visual_profile == null:
					arena.modular_visual_profile = ArenaModularVisualProfile.new()
				arena.modular_visual_profile.theme_id = arena.theme_id
				arena.modular_visual_profile.base_terrain_id = inferred_base
				arena.modular_visual_profile.hybrid_floor_policy = (
					ArenaModularVisualProfile.HybridFloorPolicy.NON_BASE_TERRAINS
				)
			return paint_permanent_terrain(arena, cell, terrain_id) \
				if sync_runtime else paint_permanent_terrain_local(arena, cell, terrain_id)
		TerrainPlaceableDefinition.PlacementKind.WALL:
			return place_wall(
				arena, cell,
				&"remove" if erase else StringName(definition.payload.get("wall_id", &"")),
				sync_runtime
			)
		TerrainPlaceableDefinition.PlacementKind.SPAWN_POINT:
			if erase:
				var before := arena.spawns.size()
				arena.spawns = arena.spawns.filter(func(value):
					return value != null and value.cell != cell
				)
				if before != arena.spawns.size():
					if sync_runtime:
						ArenaRuntimeBridge.sync_runtime_resources(arena)
					return true
				return false
			return place_spawn(
				arena, cell, int(definition.payload.get("spawn_kind", -1)), sync_runtime
			)
		TerrainPlaceableDefinition.PlacementKind.DECORATION_MARKER:
			if erase:
				var before := arena.decorations.size()
				arena.decorations = arena.decorations.filter(func(value):
					return value != null and value.cell != cell
				)
				return before != arena.decorations.size()
			return place_decoration(arena, cell)
	return false


static func place_vortex_pair(
		arena: ArenaDefinition,
		entry_cell: Vector2i,
		exit_cell: Vector2i
	) -> bool:
	if not is_valid_vortex_cell(arena, entry_cell) \
			or not is_valid_vortex_cell(arena, exit_cell) \
			or entry_cell == exit_cell:
		return false
	if arena.vortex_pair_at(entry_cell) != null \
			or arena.vortex_pair_at(exit_cell) != null:
		return false
	var definition := ArenaCatalogService.interactive(&"vortex")
	if definition == null or not definition.editor_placeable:
		return false
	var pair := ArenaVortexPairDefinition.new()
	pair.pair_id = _next_vortex_pair_id(arena)
	pair.entry_cell = entry_cell
	pair.exit_cell = exit_cell
	pair.traversal_contract = definition.traversal_contract
	pair.bidirectional = true
	pair.runtime_enabled = true
	arena.vortex_pairs.append(pair)
	ArenaVortexNetworkService.migrate_legacy_pairs(arena)
	return true


static func remove_special(arena: ArenaDefinition, cell: Vector2i) -> bool:
	if arena == null:
		return false
	var before := arena.objectives.size() + arena.decorations.size() \
		+ arena.spawns.size() + arena.vortex_pairs.size()
	arena.objectives = arena.objectives.filter(func(value):
		return value != null and value.cell != cell
	)
	arena.decorations = arena.decorations.filter(func(value):
		return value != null and value.cell != cell
	)
	arena.spawns = arena.spawns.filter(func(value):
		return value != null and value.cell != cell
	)
	arena.vortex_pairs = arena.vortex_pairs.filter(func(value):
		return value != null and not value.contains(cell)
	)
	for network in arena.vortex_networks:
		if network != null:
			network.cells.erase(cell)
	return before != arena.objectives.size() + arena.decorations.size() \
		+ arena.spawns.size() + arena.vortex_pairs.size()


static func resize_document(arena: ArenaDefinition, requested_size: Vector2i) -> bool:
	if arena == null:
		return false
	var next_size := Vector2i(clampi(requested_size.x, 1, 64), clampi(requested_size.y, 1, 64))
	if next_size == arena.grid_size:
		return false
	arena.grid_size = next_size
	arena.cells = arena.cells.filter(func(value):
		return value != null and arena.is_in_bounds(value.coordinate)
	)
	arena.invalidate_cell_index()
	arena.obstacles = arena.obstacles.filter(func(value):
		return value != null and arena.is_in_bounds(value.cell)
	)
	arena.spawns = arena.spawns.filter(func(value):
		return value != null and arena.is_in_bounds(value.cell)
	)
	arena.objectives = arena.objectives.filter(func(value):
		return value != null and arena.is_in_bounds(value.cell)
	)
	arena.decorations = arena.decorations.filter(func(value):
		return value != null and arena.is_in_bounds(value.cell)
	)
	arena.vortex_pairs = arena.vortex_pairs.filter(func(value):
		return value != null and arena.is_in_bounds(value.entry_cell) \
			and arena.is_in_bounds(value.exit_cell)
	)
	for network in arena.vortex_networks:
		if network != null:
			network.cells = network.cells.filter(func(value): return arena.is_in_bounds(value))
	ArenaRuntimeBridge.sync_runtime_resources(arena)
	return true


static func is_valid_vortex_cell(arena: ArenaDefinition, cell: Vector2i) -> bool:
	if arena == null or not arena.is_in_bounds(cell):
		return false
	var definition := arena.get_cell_definition(cell)
	if definition == null or not definition.defined or not definition.playable \
			or definition.border:
		return false
	var obstacle := arena.obstacle_at(cell)
	return obstacle == null or not obstacle.blocks_movement


static func _next_vortex_pair_id(arena: ArenaDefinition) -> StringName:
	var used := {}
	for pair in arena.vortex_pairs:
		if pair != null:
			used[pair.pair_id] = true
	var index := 1
	while used.has(StringName("vortex_pair_%03d" % index)):
		index += 1
	return StringName("vortex_pair_%03d" % index)
