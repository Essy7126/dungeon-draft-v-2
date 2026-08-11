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
	ArenaRuntimeBridge.sync_runtime_resources(arena)
	return before_data != definition.to_dict()


static func paint_permanent_terrain(
		arena: ArenaDefinition,
		cell: Vector2i,
		terrain_id: StringName
	) -> bool:
	if not ArenaPermanentTerrainPaintService.can_paint(arena, terrain_id):
		return false
	return paint_terrain(arena, cell, terrain_id)


static func place_wall(
		arena: ArenaDefinition,
		cell: Vector2i,
		wall_id: StringName
	) -> bool:
	if arena == null or not arena.is_in_bounds(cell):
		return false
	if wall_id == &"remove" or wall_id == &"":
		return remove_wall(arena, cell)
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
	ArenaRuntimeBridge.sync_runtime_resources(arena)
	return before != obstacle.to_dict()


static func remove_wall(arena: ArenaDefinition, cell: Vector2i) -> bool:
	if arena == null:
		return false
	var before := arena.obstacles.size()
	arena.obstacles = arena.obstacles.filter(func(value):
		return value != null and (value.cell != cell or value.wall_id == &"")
	)
	if arena.obstacles.size() == before:
		return false
	ArenaRuntimeBridge.sync_runtime_resources(arena)
	return true


static func place_spawn(arena: ArenaDefinition, cell: Vector2i, kind: int) -> bool:
	return ArenaEditingService.place_spawn(arena, cell, kind)


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
	pair.runtime_enabled = false
	arena.vortex_pairs.append(pair)
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
