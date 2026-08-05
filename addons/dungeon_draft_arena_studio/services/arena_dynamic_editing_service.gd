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
	ArenaRuntimeBridge.sync_runtime_resources(arena)
	return before_data != definition.to_dict()


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


static func remove_special(arena: ArenaDefinition, cell: Vector2i) -> bool:
	if arena == null:
		return false
	var before := arena.objectives.size() + arena.decorations.size() + arena.spawns.size()
	arena.objectives = arena.objectives.filter(func(value):
		return value != null and value.cell != cell
	)
	arena.decorations = arena.decorations.filter(func(value):
		return value != null and value.cell != cell
	)
	arena.spawns = arena.spawns.filter(func(value):
		return value != null and value.cell != cell
	)
	return before != arena.objectives.size() + arena.decorations.size() + arena.spawns.size()


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
	ArenaRuntimeBridge.sync_runtime_resources(arena)
	return true
