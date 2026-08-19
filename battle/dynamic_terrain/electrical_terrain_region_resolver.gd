class_name ElectricalTerrainRegionResolver
extends RefCounted

## Resolves connected electrical cells to deterministic region identities.
##
## Lineage policy: identities are retained for the whole round. When regions
## merge, their lineage tokens are unioned; when a region splits, both children
## retain the parent's tokens. A topology edit therefore cannot re-arm a unit
## merely because the connected-component hash changed. A new disjoint region
## receives a new deterministic token and may trigger once.

const NEIGHBORS: Array[Vector2i] = [
	Vector2i.UP,
	Vector2i.RIGHT,
	Vector2i.DOWN,
	Vector2i.LEFT,
]

var _round_index := -1
var _lineage_by_cell: Dictionary = {}


func begin_round(value: int) -> void:
	var normalized := maxi(1, value)
	if normalized == _round_index:
		return
	_round_index = normalized
	_lineage_by_cell.clear()


func reset() -> void:
	_round_index = -1
	_lineage_by_cell.clear()


func resolve_region(
	cell: Vector2i,
	electrified_cells: Array[Vector2i]
	) -> Dictionary:
	var available: Dictionary = {}
	for candidate in electrified_cells:
		available[candidate] = true
	if not available.has(cell):
		return {
			"ok": false,
			"error": "cell_not_electrified",
			"cell": cell,
			"round_index": _round_index,
			"region_id": &"",
			"lineage_tokens": PackedStringArray(),
			"component": [] as Array[Vector2i],
		}

	var component: Array[Vector2i] = []
	var visited: Dictionary = {cell: true}
	var queue: Array[Vector2i] = [cell]
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		component.append(current)
		for offset in NEIGHBORS:
			var neighbor := current + offset
			if available.has(neighbor) and not visited.has(neighbor):
				visited[neighbor] = true
				queue.append(neighbor)
	component.sort_custom(_cell_less)

	var token_set: Dictionary = {}
	for component_cell in component:
		var remembered := _lineage_by_cell.get(
			component_cell, PackedStringArray()
		) as PackedStringArray
		for remembered_token in remembered:
			token_set[remembered_token] = true
	if token_set.is_empty():
		token_set[_deterministic_token(component)] = true

	var lineage_tokens := PackedStringArray()
	for token_value in token_set.keys():
		lineage_tokens.append(str(token_value))
	lineage_tokens.sort()
	for component_cell in component:
		_lineage_by_cell[component_cell] = lineage_tokens.duplicate()

	return {
		"ok": true,
		"error": "",
		"cell": cell,
		"round_index": _round_index,
		"region_id": StringName(lineage_tokens[0]),
		"lineage_tokens": lineage_tokens,
		"component": component,
	}


func _deterministic_token(component: Array[Vector2i]) -> String:
	var coordinate_parts := PackedStringArray()
	for cell in component:
		coordinate_parts.append("%d,%d" % [cell.x, cell.y])
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update("|".join(coordinate_parts).to_utf8_buffer())
	return "electrical_region:%s" % hashing.finish().hex_encode().substr(0, 20)


func _cell_less(a: Vector2i, b: Vector2i) -> bool:
	return a.y < b.y or (a.y == b.y and a.x < b.x)
