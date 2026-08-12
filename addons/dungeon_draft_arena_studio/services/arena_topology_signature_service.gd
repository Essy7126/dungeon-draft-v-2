@tool
class_name ArenaTopologySignatureService
extends RefCounted

## Autorite semantique de la forme d'une arene. Une grid_size delimite
## l'espace de coordonnees ; elle ne declare jamais implicitement les cellules.

const SET_NAMES := [
	"all_grid_cells",
	"declared_cells",
	"defined_cells",
	"visible_floor_cells",
	"playable_cells",
	"border_cells",
	"void_cells",
	"removed_cells",
	"blocked_cells",
	"obstacle_cells",
	"hero_spawn_cells",
	"enemy_spawn_cells",
	"objective_cells",
	"decoration_cells",
	"vortex_entry_cells",
	"vortex_exit_cells",
]


static func build(arena: ArenaDefinition) -> Dictionary:
	var buckets := {}
	for set_name in SET_NAMES:
		buckets[set_name] = {}
	if arena == null:
		return _finalize(Vector2i.ZERO, buckets, ["arena_missing"])

	for y in range(arena.grid_size.y):
		for x in range(arena.grid_size.x):
			_add(buckets.all_grid_cells, Vector2i(x, y))

	for definition in arena.cells:
		if definition == null:
			continue
		var cell := definition.coordinate
		if not arena.is_in_bounds(cell):
			continue
		_add(buckets.declared_cells, cell)
		if definition.defined:
			_add(buckets.defined_cells, cell)
		if is_void_definition(definition):
			_add(buckets.void_cells, cell)
			continue
		_add(buckets.visible_floor_cells, cell)
		if definition.border:
			_add(buckets.border_cells, cell)
		var obstacle := arena.obstacle_at(cell)
		var mechanically_walkable := bool(
			GridData.PROPERTIES[definition.cell_type]["walkable"]
		)
		var blocked_by_obstacle := obstacle != null and obstacle.blocks_movement
		if definition.playable and not definition.border \
				and mechanically_walkable and not blocked_by_obstacle:
			_add(buckets.playable_cells, cell)
		else:
			_add(buckets.blocked_cells, cell)

	for key in buckets.all_grid_cells:
		if not buckets.declared_cells.has(key):
			buckets.removed_cells[key] = true
			buckets.void_cells[key] = true

	for obstacle in arena.obstacles:
		if obstacle != null:
			_add(buckets.obstacle_cells, obstacle.cell)
	for spawn in arena.spawns:
		if spawn == null:
			continue
		if spawn.is_hero():
			_add(buckets.hero_spawn_cells, spawn.cell)
		elif spawn.is_enemy():
			_add(buckets.enemy_spawn_cells, spawn.cell)
	for objective in arena.objectives:
		if objective != null:
			_add(buckets.objective_cells, objective.cell)
	for decoration in arena.decorations:
		if decoration != null:
			_add(buckets.decoration_cells, decoration.cell)
	for pair in arena.vortex_pairs:
		if pair != null:
			_add(buckets.vortex_entry_cells, pair.entry_cell)
			_add(buckets.vortex_exit_cells, pair.exit_cell)
	for network in arena.vortex_networks:
		if network == null:
			continue
		for cell in network.unique_cells():
			_add(buckets.vortex_entry_cells, cell)
			_add(buckets.vortex_exit_cells, cell)

	return _finalize(arena.grid_size, buckets, [])


static func from_snapshot(snapshot: Dictionary) -> Dictionary:
	var restored := ArenaDefinition.new()
	if not restored.restore_snapshot(snapshot):
		var empty := {}
		for set_name in SET_NAMES:
			empty[set_name] = {}
		return _finalize(Vector2i.ZERO, empty, ["snapshot_restore_failed"])
	return build(restored)


static func is_void_definition(definition: ArenaCellDefinition) -> bool:
	return definition == null \
		or not definition.defined \
		or definition.terrain_id == &"void" \
		or definition.cell_type == GridData.CellType.HOLE


static func coordinate_key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]


static func key_to_coordinate(key: String) -> Vector2i:
	var parts := key.split(",", false, 1)
	return Vector2i(int(parts[0]), int(parts[1])) \
		if parts.size() == 2 else GridTransformService.INVALID_CELL


static func normalized_keys(values: Variant) -> Array[String]:
	var unique := {}
	if values is Dictionary:
		for value in values.keys():
			_add_key(unique, value)
	elif values is Array or values is PackedStringArray:
		for value in values:
			_add_key(unique, value)
	var result: Array[String] = []
	result.assign(unique.keys())
	result.sort_custom(func(left: String, right: String):
		var a := key_to_coordinate(left)
		var b := key_to_coordinate(right)
		return a.y < b.y or (a.y == b.y and a.x < b.x)
	)
	return result


static func cells_from_keys(values: Variant) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for key in normalized_keys(values):
		result.append(key_to_coordinate(key))
	return result


static func hash_keys(values: Variant) -> String:
	return JSON.stringify(normalized_keys(values), "", true).sha256_text()


static func difference(left: Variant, right: Variant) -> Array[String]:
	var right_set := {}
	for key in normalized_keys(right):
		right_set[key] = true
	var result: Array[String] = []
	for key in normalized_keys(left):
		if not right_set.has(key):
			result.append(key)
	return result


static func intersection(left: Variant, right: Variant) -> Array[String]:
	var right_set := {}
	for key in normalized_keys(right):
		right_set[key] = true
	var result: Array[String] = []
	for key in normalized_keys(left):
		if right_set.has(key):
			result.append(key)
	return result


static func _finalize(
		grid_size: Vector2i,
		buckets: Dictionary,
		errors: Array
	) -> Dictionary:
	var result := {
		"grid_size": grid_size,
		"hashes": {},
		"counts": {},
		"errors": errors.duplicate(),
	}
	var global_payload := {
		"grid_size": [grid_size.x, grid_size.y],
		"sets": {},
	}
	for set_name in SET_NAMES:
		var values := normalized_keys(buckets.get(set_name, {}))
		result[set_name] = values
		result.hashes[set_name] = hash_keys(values)
		result.counts[set_name] = values.size()
		global_payload.sets[set_name] = values
	result["visible_floor_hash"] = str(result.hashes.visible_floor_cells)
	result["topology_hash"] = JSON.stringify(
		global_payload, "", true
	).sha256_text()
	result["ok"] = errors.is_empty()
	return result


static func _add(bucket: Dictionary, cell: Vector2i) -> void:
	bucket[coordinate_key(cell)] = true


static func _add_key(bucket: Dictionary, value: Variant) -> void:
	if value is Vector2i:
		bucket[coordinate_key(value)] = true
	else:
		var key := str(value)
		if key_to_coordinate(key) != GridTransformService.INVALID_CELL:
			bucket[key] = true
