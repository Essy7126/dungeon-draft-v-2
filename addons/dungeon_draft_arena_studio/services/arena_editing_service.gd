@tool
class_name ArenaEditingService
extends RefCounted

const DEFAULT_ENCOUNTER := "res://data/encounters/first_run_room_01_encounter.tres"
const HERO_IDS := [&"elf", &"mage", &"warrior"]


static func prepare_automatically(arena: ArenaDefinition) -> Dictionary:
	if arena == null:
		return {"ok": false, "message": "Aucune arene n'est ouverte."}
	if arena.cells.is_empty():
		for y in range(arena.grid_size.y):
			for x in range(arena.grid_size.x):
				arena.ensure_cell(Vector2i(x, y))
	apply_safety_border(arena, arena.border_thickness)
	if arena.encounter_definition == null and ResourceLoader.exists(DEFAULT_ENCOUNTER):
		arena.encounter_definition = load(DEFAULT_ENCOUNTER) as EncounterDefinition
	propose_spawns(arena)
	ArenaRuntimeBridge.sync_runtime_resources(arena)
	var grid := ArenaRuntimeBridge.build_grid(arena)
	var connected := 0
	if grid != null and not arena.playable_cells().is_empty():
		var pathfinder := Pathfinder.new(grid)
		connected = pathfinder.get_reachable(
			arena.playable_cells()[0], arena.grid_size.x * arena.grid_size.y
		).size() + 1
	return {
		"ok": true,
		"playable": arena.playable_cells().size(),
		"border": arena.border_cells().size(),
		"connected": connected,
		"hero_spawns": arena.hero_spawn_zone.size(),
		"enemy_spawns": arena.enemy_spawn_zone.size(),
	}


static func apply_safety_border(arena: ArenaDefinition, thickness := 1) -> int:
	if arena == null:
		return 0
	for definition in arena.cells:
		if definition != null:
			definition.border = false
	var border := ArenaBoundaryService.compute_outer_border(
		arena.defined_cells(), arena.grid_size, maxi(1, thickness)
	)
	for cell in border:
		var definition := arena.get_cell_definition(cell)
		if definition != null:
			definition.border = true
			definition.playable = false
	arena.border_thickness = maxi(1, thickness)
	remove_invalid_spawns(arena)
	return border.size()


static func set_cell_state(arena: ArenaDefinition, cell: Vector2i, state: StringName) -> bool:
	if arena == null or not arena.is_in_bounds(cell):
		return false
	match state:
		&"add":
			var definition := arena.ensure_cell(cell)
			definition.playable = true
			definition.border = false
			definition.cell_type = GridData.CellType.NORMAL
		&"remove":
			return arena.erase_cell(cell)
		&"playable":
			var definition := arena.ensure_cell(cell)
			definition.playable = true
			definition.border = false
		&"non_playable":
			var definition := arena.ensure_cell(cell)
			definition.playable = false
			definition.border = false
		&"border":
			var definition := arena.ensure_cell(cell)
			definition.playable = false
			definition.border = true
		_:
			return false
	return true


static func set_obstacle(arena: ArenaDefinition, cell: Vector2i, preset: int) -> bool:
	var definition := arena.get_cell_definition(cell) if arena != null else null
	if definition == null or definition.border:
		return false
	var obstacle := arena.obstacle_at(cell)
	if obstacle == null:
		obstacle = ArenaObstacleDefinition.new()
		obstacle.obstacle_id = StringName("obstacle_%d_%d" % [cell.x, cell.y])
		obstacle.cell = cell
		arena.obstacles.append(obstacle)
	obstacle.apply_preset(preset)
	return true


static func clear_obstacle(arena: ArenaDefinition, cell: Vector2i) -> bool:
	var obstacle := arena.obstacle_at(cell) if arena != null else null
	if obstacle == null:
		return false
	arena.obstacles.erase(obstacle)
	return true


static func set_terrain(arena: ArenaDefinition, cell: Vector2i, cell_type: int) -> bool:
	var definition := arena.get_cell_definition(cell) if arena != null else null
	if definition == null or definition.border:
		return false
	definition.cell_type = clampi(cell_type, GridData.CellType.NORMAL, GridData.CellType.RUNE)
	definition.terrain_id = StringName([
		"normal", "wall", "hole", "lava", "ice", "shadow", "rune",
	][definition.cell_type])
	return true


static func place_spawn(arena: ArenaDefinition, cell: Vector2i, kind: int) -> bool:
	if arena == null:
		return false
	var definition := arena.get_cell_definition(cell)
	if definition == null or not definition.playable or definition.border \
			or arena.obstacle_at(cell) != null:
		return false
	for existing in arena.spawns_at(cell):
		arena.spawns.erase(existing)
	var spawn := ArenaSpawnDefinition.new()
	spawn.kind = clampi(kind, ArenaSpawnDefinition.Kind.HERO_1, ArenaSpawnDefinition.Kind.SUMMON_ZONE)
	spawn.spawn_id = StringName("spawn_%d_%d_%d" % [spawn.kind, cell.x, cell.y])
	if spawn.kind in [
		ArenaSpawnDefinition.Kind.HERO_1,
		ArenaSpawnDefinition.Kind.HERO_2,
		ArenaSpawnDefinition.Kind.HERO_3,
	]:
		spawn.unit_id = HERO_IDS[spawn.kind]
	elif spawn.is_enemy():
		spawn.unit_id = &"encounter_enemy"
	spawn.cell = cell
	arena.spawns.append(spawn)
	ArenaRuntimeBridge.sync_runtime_resources(arena)
	return true


static func propose_spawns(arena: ArenaDefinition) -> void:
	for index in range(arena.spawns.size() - 1, -1, -1):
		if str(arena.spawns[index].spawn_id).begins_with("auto_"):
			arena.spawns.remove_at(index)
	var playable := arena.playable_cells()
	if playable.size() < 6:
		return
	playable.sort_custom(func(a: Vector2i, b: Vector2i):
		return _camp_score(a, arena) < _camp_score(b, arena)
	)
	for hero_index in range(3):
		_add_auto_spawn(
			arena, playable[hero_index], hero_index, HERO_IDS[hero_index], hero_index
		)
	var enemy_candidates := playable.duplicate()
	enemy_candidates.reverse()
	var enemy_count := mini(6, maxi(3, enemy_candidates.size() / 8))
	for enemy_index in range(enemy_count):
		_add_auto_spawn(
			arena,
			enemy_candidates[enemy_index],
			ArenaSpawnDefinition.Kind.ENEMY_GROUP,
			&"encounter_enemy",
			enemy_index
		)
	ArenaRuntimeBridge.sync_runtime_resources(arena)


static func remove_invalid_spawns(arena: ArenaDefinition) -> void:
	for index in range(arena.spawns.size() - 1, -1, -1):
		var spawn := arena.spawns[index]
		var definition := arena.get_cell_definition(spawn.cell)
		if definition == null or not definition.playable or definition.border \
				or arena.obstacle_at(spawn.cell) != null:
			arena.spawns.remove_at(index)
	ArenaRuntimeBridge.sync_runtime_resources(arena)


static func _add_auto_spawn(
		arena: ArenaDefinition,
		cell: Vector2i,
		kind: int,
		unit_id: StringName,
		index: int
	) -> void:
	var spawn := ArenaSpawnDefinition.new()
	spawn.spawn_id = StringName("auto_%s_%d" % ["hero" if kind < 3 else "enemy", index])
	spawn.kind = kind
	spawn.unit_id = unit_id
	spawn.cell = cell
	arena.spawns.append(spawn)


static func _camp_score(cell: Vector2i, arena: ArenaDefinition) -> int:
	match arena.camp_orientation:
		ArenaDefinition.CampOrientation.HERO_BOTTOM_LEFT:
			return cell.x - cell.y
		ArenaDefinition.CampOrientation.HERO_BOTTOM_RIGHT:
			return -cell.x - cell.y
		ArenaDefinition.CampOrientation.HERO_TOP_LEFT:
			return cell.x + cell.y
		_:
			return -cell.x + cell.y
