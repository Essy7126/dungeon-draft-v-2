@tool
class_name ArenaEditingService
extends RefCounted

const DEFAULT_ENCOUNTER := "res://data/encounters/first_run_room_01_encounter.tres"
const HERO_IDS := [&"elf", &"mage", &"warrior"]


static func prepare_automatically(
		arena: ArenaDefinition,
		target_run: RunData = null
	) -> Dictionary:
	if arena == null:
		return {"ok": false, "message": "Aucune arène n'est ouverte."}
	var total_started: int = Time.get_ticks_usec()
	var phase_started: int = total_started
	if arena.cells.is_empty():
		for y in range(arena.grid_size.y):
			for x in range(arena.grid_size.x):
				arena.ensure_cell(Vector2i(x, y))
	var ensure_cells_ms := _elapsed_ms(phase_started)
	# La préparation est une seule transaction logique : ses sous-étapes ne
	# publient pas chacune une projection runtime intermédiaire.
	phase_started = Time.get_ticks_usec()
	apply_safety_border(arena, arena.border_thickness, false)
	var safety_border_ms := _elapsed_ms(phase_started)
	phase_started = Time.get_ticks_usec()
	if arena.encounter_definition == null and ResourceLoader.exists(DEFAULT_ENCOUNTER):
		arena.encounter_definition = load(DEFAULT_ENCOUNTER) as EncounterDefinition
	var encounter_resolution_ms := _elapsed_ms(phase_started)
	phase_started = Time.get_ticks_usec()
	propose_spawns(arena, false, target_run)
	var spawn_proposal_ms := _elapsed_ms(phase_started)
	phase_started = Time.get_ticks_usec()
	# Les Resources de production historiques conservent leur contrat synchronise.
	# Seule une working copy protegee doit passer par une projection separee.
	var runtime_projection: ArenaDefinition
	if arena.authoring_document:
		runtime_projection = ArenaRuntimeBridge.build_runtime_projection(arena)
	else:
		ArenaRuntimeBridge.sync_runtime_resources(arena)
		runtime_projection = arena
	var runtime_sync_ms := _elapsed_ms(phase_started)
	phase_started = Time.get_ticks_usec()
	var grid := ArenaRuntimeBridge.build_grid_from_synced_resources(runtime_projection)
	var grid_build_ms := _elapsed_ms(phase_started)
	phase_started = Time.get_ticks_usec()
	var playable := arena.playable_cells()
	var connected := 0
	if grid != null and not playable.is_empty():
		var pathfinder := Pathfinder.new(grid)
		connected = pathfinder.get_reachable(
			playable[0], arena.grid_size.x * arena.grid_size.y
		).size() + 1
	var connectivity_ms := _elapsed_ms(phase_started)
	return {
		"ok": true,
		"playable": playable.size(),
		"border": arena.border_cells().size(),
		"connected": connected,
		"hero_spawns": runtime_projection.hero_spawn_zone.size() \
			if runtime_projection != null else 0,
		"enemy_spawns": runtime_projection.enemy_spawn_zone.size() \
			if runtime_projection != null else 0,
		"runtime_sync_calls": 1,
		"grid_data_builds": 1,
		"runtime_projection_reused_for_grid": true,
		"breakdown_ms": {
			"ensure_cells": ensure_cells_ms,
			"safety_border": safety_border_ms,
			"encounter_resolution": encounter_resolution_ms,
			"spawn_proposal": spawn_proposal_ms,
			"runtime_sync": runtime_sync_ms,
			"grid_build": grid_build_ms,
			"connectivity": connectivity_ms,
			"total": _elapsed_ms(total_started),
		},
	}


static func apply_safety_border(
		arena: ArenaDefinition,
		thickness := 1,
		sync_runtime := true
	) -> int:
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
	remove_invalid_spawns(arena, false)
	if sync_runtime:
		ArenaRuntimeBridge.sync_runtime_resources(arena)
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
			if definition.terrain_id == &"":
				ArenaTerrainRegistry.configure_cell(definition, &"neutral")
		&"remove":
			return arena.erase_cell(cell)
		&"playable":
			var definition := arena.ensure_cell(cell)
			definition.playable = true
			definition.border = false
			if definition.terrain_id == &"":
				ArenaTerrainRegistry.configure_cell(definition, &"neutral")
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


static func place_spawn(
		arena: ArenaDefinition,
		cell: Vector2i,
		kind: int,
		sync_runtime := true
	) -> bool:
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
		if spawn.kind == ArenaSpawnDefinition.Kind.ENEMY_GROUP:
			spawn.group_id = StringName("group_%d_%d" % [cell.x, cell.y])
	spawn.cell = cell
	arena.spawns.append(spawn)
	if sync_runtime:
		ArenaRuntimeBridge.sync_runtime_resources(arena)
	return true


static func propose_spawns(
		arena: ArenaDefinition,
		sync_runtime := true,
		target_run: RunData = null
	) -> void:
	for index in range(arena.spawns.size() - 1, -1, -1):
		if str(arena.spawns[index].spawn_id).begins_with("auto_"):
			arena.spawns.remove_at(index)
	# Une map importee possede deja ses positions runtime. Les propositions ne
	# doivent pas leur superposer un second trio et un second groupe ennemi.
	var hero_count := arena.spawns.filter(func(spawn):
		return spawn != null and spawn.is_hero()
	).size()
	var has_enemies := arena.spawns.any(func(spawn):
		return spawn != null and spawn.is_enemy()
	)
	var capacity := ArenaHeroStartCapacityService.resolve(target_run)
	var required_heroes := int(capacity.get("minimum", 0)) \
		if bool(capacity.get("known", false)) else 3
	if hero_count >= required_heroes and has_enemies:
		if sync_runtime:
			ArenaRuntimeBridge.sync_runtime_resources(arena)
		return
	var playable := arena.playable_cells()
	if playable.size() < maxi(1, required_heroes):
		return
	playable.sort_custom(func(a: Vector2i, b: Vector2i):
		return _camp_score(a, arena) < _camp_score(b, arena)
	)
	var resolved_heroes: Array = capacity.get("heroes", [])
	for hero_index in range(hero_count, required_heroes):
		var kind := mini(hero_index, ArenaSpawnDefinition.Kind.HERO_3)
		var hero_data := resolved_heroes[hero_index] as UnitData \
			if hero_index < resolved_heroes.size() else null
		_add_auto_spawn(
			arena, playable[hero_index], kind,
			StringName(hero_data.resource_path) if hero_data != null \
				and not hero_data.resource_path.is_empty() \
				else HERO_IDS[hero_index] if hero_index < HERO_IDS.size() else &"run_hero",
			hero_index
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
	if sync_runtime:
		ArenaRuntimeBridge.sync_runtime_resources(arena)


static func remove_invalid_spawns(arena: ArenaDefinition, sync_runtime := true) -> void:
	for index in range(arena.spawns.size() - 1, -1, -1):
		var spawn := arena.spawns[index]
		var definition := arena.get_cell_definition(spawn.cell)
		if definition == null or not definition.playable or definition.border \
				or arena.obstacle_at(spawn.cell) != null:
			arena.spawns.remove_at(index)
	if sync_runtime:
		ArenaRuntimeBridge.sync_runtime_resources(arena)


static func _add_auto_spawn(
		arena: ArenaDefinition,
		cell: Vector2i,
		kind: int,
		unit_id: StringName,
		index: int
	) -> void:
	if not arena.spawns_at(cell).is_empty():
		return
	var spawn := ArenaSpawnDefinition.new()
	spawn.spawn_id = StringName("auto_%s_%d" % ["hero" if kind < 3 else "enemy", index])
	spawn.kind = kind
	spawn.unit_id = unit_id
	spawn.cell = cell
	if spawn.kind == ArenaSpawnDefinition.Kind.ENEMY_GROUP:
		spawn.group_id = StringName("auto_enemy_group_%d" % index)
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


static func _elapsed_ms(started_usec: int) -> float:
	return float(Time.get_ticks_usec() - started_usec) / 1000.0
