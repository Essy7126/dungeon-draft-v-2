extends RefCounted

const PATHS := preload("res://tools/registered_terrain_validation/validation_paths.gd")

# Recalculate expectations from authored cell lists. Runtime geometry is measured
# separately; cached count fields and a renderer's own report are not the oracle.
static func read(arena: ArenaDefinition, battle: Node = null) -> Dictionary:
	var path: String = PATHS.manifest_path(arena, battle)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	if not parsed is Dictionary:
		return {"ok": false, "errors": ["manifest_expectations_missing_or_invalid"], "summary": {}, "floor": {}, "obstacles": {}, "pits": {}}
	var manifest: Dictionary = parsed
	var errors: Array[String] = []
	var size_value: Array = manifest.get("grid_size", [])
	var size := Vector2i(int(size_value[0]), int(size_value[1])) if size_value.size() == 2 else Vector2i.ZERO
	if size.x <= 0 or size.y <= 0 or size != arena.grid_size:
		errors.append("manifest_logical_grid_size_invalid_or_differs_from_arena")
	var floor: Dictionary = _cells(manifest.get("floor_cells", []), size, "floor", errors)
	var obstacles: Dictionary = _groups(manifest.get("obstacles", []), size, "obstacle", errors)
	var pits: Dictionary = _groups(manifest.get("pits", []), size, "pit", errors)
	var groups: Array = manifest.get("pits", [])
	if floor.is_empty():
		errors.append("manifest_floor_empty")
	for cell: Vector2i in obstacles:
		if not floor.has(cell):
			errors.append("manifest_obstacle_without_floor:%s" % cell)
	for cell: Vector2i in pits:
		if floor.has(cell):
			errors.append("manifest_pit_overlaps_floor:%s" % cell)
	var counts: Dictionary = {
		"expected_floor_count": floor.size(),
		"expected_blocked_count": obstacles.size(),
		"expected_void_count": size.x * size.y - floor.size(),
		"expected_pit_cells": pits.size(),
		"expected_pit_group_count": groups.size(),
	}
	for key: String in counts:
		if int(manifest.get(key, -1)) != int(counts[key]):
			errors.append("manifest_cached_count_differs_from_cell_lists:" + key)
	var summary: Dictionary = {
		"path": path, "grid_size": [size.x, size.y],
		"floor_count": floor.size(), "blocked_count": obstacles.size(),
		"void_count": size.x * size.y - floor.size(),
		"pit_cell_count": pits.size(), "pit_group_count": groups.size(),
		"floor_cell_signature": _signature(floor),
		"obstacle_cell_signature": _signature(obstacles),
		"pit_cell_signature": _signature(pits),
		"authority": "Unique cells recalculated from manifest lists, with cached counts checked for consistency; live geometry is tested separately.",
	}
	return {"ok": errors.is_empty(), "errors": errors, "summary": summary, "floor": floor, "obstacles": obstacles, "pits": pits}

static func _cells(values: Array, size: Vector2i, label: String, errors: Array[String]) -> Dictionary:
	var cells: Dictionary = {}
	for value: Variant in values:
		if not value is Array or value.size() != 2:
			errors.append("manifest_%s_coordinate_invalid" % label)
			continue
		var cell := Vector2i(int(value[0]), int(value[1]))
		if float(value[0]) != float(cell.x) or float(value[1]) != float(cell.y) or cell.x < 0 or cell.y < 0 or cell.x >= size.x or cell.y >= size.y:
			errors.append("manifest_%s_coordinate_outside_grid:%s" % [label, cell])
		if cells.has(cell):
			errors.append("manifest_%s_duplicate_cell:%s" % [label, cell])
		cells[cell] = true
	return cells

static func _groups(values: Array, size: Vector2i, label: String, errors: Array[String]) -> Dictionary:
	var cells: Dictionary = {}
	for value: Variant in values:
		if not value is Dictionary:
			errors.append("manifest_%s_group_invalid" % label)
			continue
		var group: Dictionary = _cells(value.get("cells", []), size, label, errors)
		if group.is_empty():
			errors.append("manifest_%s_empty_group" % label)
		for cell: Vector2i in group:
			if cells.has(cell):
				errors.append("manifest_%s_cell_in_multiple_groups:%s" % [label, cell])
			cells[cell] = true
	return cells

static func _signature(cells: Dictionary) -> String:
	var ordered: Array[String] = []
	for cell: Vector2i in cells:
		ordered.append("%d,%d" % [cell.x, cell.y])
	ordered.sort()
	return "|".join(ordered).sha256_text()
