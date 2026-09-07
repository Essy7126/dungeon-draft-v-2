extends RefCounted

const SOURCE := "res://data/arenas/lethe_crossing_v1/arena.tres"
const OUTPUT := "res://data/rooms/philosopher_trial.tres"
const ENCOUNTER = preload("res://data/encounters/philosopher_trial_encounter.tres")
const NETWORK_ID := &"philosopher_trial_portals"
const HERO_CELLS: Array[Vector2i] = [Vector2i(4, 3), Vector2i(5, 3), Vector2i(4, 4), Vector2i(5, 4)]
const MAGE_CELL := Vector2i(9, 7)
const SPECTRE_CELL := Vector2i(7, 7)
const PORTAL_CELLS: Array[Vector2i] = [Vector2i(9, 6), Vector2i(7, 4)]
const TERRAIN_CELLS := {
	&"water": [Vector2i(5, 5), Vector2i(6, 5), Vector2i(7, 5)],
	&"ice": [Vector2i(5, 7), Vector2i(6, 7)],
	&"lava": [Vector2i(8, 7), Vector2i(8, 8)],
	&"electrified_water": [Vector2i(9, 9)],
}


static func build(source: ArenaDefinition) -> ArenaDefinition:
	if source == null:
		push_error("Philosopher trial: missing source arena.")
		return null
	var before := RoomDataSnapshotService.room_fingerprint(source)
	var before_snapshot := RoomDataSnapshotService.to_room_snapshot(source)
	var arena := ArenaDefinition.new()
	if not RoomDataSnapshotService.restore(arena, RoomDataSnapshotService.capture(source)):
		push_error("Philosopher trial: source snapshot restore failed.")
		return null
	# Array.duplicate(true) copies containers, but Resource entries inside an
	# array stay shared in the snapshot service. Detach each cell before paint.
	var owned_cells: Array[ArenaCellDefinition] = []
	for definition in arena.cells:
		owned_cells.append(definition.duplicate(true) as ArenaCellDefinition)
	arena.cells = owned_cells
	arena.invalidate_cell_index()
	arena.set_identity("L’Épreuve du Dialecticien — Le Gué du Léthé", "philosopher_trial_lethe")
	arena.source_room_path = SOURCE
	# Formation zones are only preferences in the generic planner. Restrict
	# this local encounter to the two authored, safe starting cells instead.
	var encounter := ENCOUNTER.duplicate(false) as EncounterDefinition
	encounter.forbidden_initial_spawn_cells = []
	for definition in arena.cells:
		if definition.coordinate not in [MAGE_CELL, SPECTRE_CELL]:
			encounter.forbidden_initial_spawn_cells.append(definition.coordinate)
	encounter.minimum_path_distance_by_role = {&"philosopher_mage": 7}
	encounter.maximum_path_distance_by_role = {&"philosopher_mage": 9}
	arena.encounter_definition = encounter
	arena.enemies.assign(encounter.expanded_roster())
	arena.minimum_wave_count = 1
	arena.maximum_wave_count = 1
	arena.waves.clear()
	arena.spawns.clear()
	arena.vortex_pairs.clear()
	arena.vortex_networks.clear()
	for terrain_id in TERRAIN_CELLS:
		for cell in TERRAIN_CELLS[terrain_id]:
			# Never extend the topology or paint over one of the source props.
			if not _free_source_cell(source, cell):
				push_error("Philosopher trial: unavailable terrain cell %s" % cell)
				return null
			if not ArenaDynamicEditingService.paint_permanent_terrain_local(arena, cell, terrain_id):
				push_error("Philosopher trial: failed to author %s on %s" % [terrain_id, cell])
				return null
	for cell in HERO_CELLS:
		if not _place_spawn(arena, source, cell, ArenaSpawnDefinition.Kind.HERO_1, &"achilles"):
			return null
	if not _place_spawn(arena, source, MAGE_CELL, ArenaSpawnDefinition.Kind.ENEMY, &"philosopher_mage") \
			or not _place_spawn(arena, source, SPECTRE_CELL, ArenaSpawnDefinition.Kind.ENEMY, &"spectre_greatsword"):
		return null
	var network := ArenaVortexNetworkService.create_network(arena, "Les deux rives du raisonnement")
	network.network_id = NETWORK_ID
	network.random_destination = false
	for cell in PORTAL_CELLS:
		if not _free_source_cell(source, cell) or not ArenaVortexNetworkService.add_cell(arena, NETWORK_ID, cell):
			push_error("Philosopher trial: invalid portal cell %s" % cell)
			return null
	arena.production_notes = "Independent philosopher trial derived from Lethe: 8 authored elemental tiles, one bidirectional portal pair, one mage and one spectre. Source geometry and props are preserved. Regenerate with tools/philosopher_sprite_pipeline/build_trial_room.tscn."
	if not ArenaRuntimeBridge.sync_runtime_resources(arena):
		push_error("Philosopher trial: final runtime sync failed.")
		return null
	var after := RoomDataSnapshotService.room_fingerprint(source)
	if after != before:
		var after_snapshot := RoomDataSnapshotService.to_room_snapshot(source)
		var changed_fields: Array[String] = []
		for key in before_snapshot:
			if before_snapshot[key] != after_snapshot.get(key):
				changed_fields.append(str(key))
		push_error("Philosopher trial: source changed in memory: %s" % JSON.stringify(changed_fields))
	assert(after == before, "The source arena must remain immutable.")
	return arena


static func _free_source_cell(arena: ArenaDefinition, cell: Vector2i) -> bool:
	var definition := arena.get_cell_definition(cell)
	if definition == null or not ArenaTerrainRegistry.definition_for(definition.terrain_id).walkable:
		return false
	for obstacle in arena.obstacles:
		if obstacle != null and obstacle.cell == cell:
			return false
	return true


static func _place_spawn(arena: ArenaDefinition, source: ArenaDefinition, cell: Vector2i, kind: int, unit_id: StringName) -> bool:
	if not _free_source_cell(source, cell) or not ArenaDynamicEditingService.place_spawn(arena, cell, kind, false):
		push_error("Philosopher trial: invalid spawn %s for %s" % [cell, unit_id])
		return false
	for spawn in arena.spawns:
		if spawn.cell == cell:
			spawn.unit_id = unit_id
			return true
	push_error("Philosopher trial: missing spawned definition at %s" % cell)
	return false
