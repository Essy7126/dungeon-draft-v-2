@tool
class_name ArenaStrokeBatchService
extends RefCounted

const VISUAL_ONLY_IDS := [&"stone", &"neutral"]

var _arena: ArenaDefinition = null
var _before := {}
var _changed_cells := {}
var _received_cells := {}
var _logical_change := false
var _active := false
var _started_usec := 0


func begin_stroke(arena: ArenaDefinition) -> Dictionary:
	cancel()
	if arena == null:
		return {}
	_arena = arena
	_before = arena.to_snapshot()
	_active = true
	_started_usec = Time.get_ticks_usec()
	return _before.duplicate(true)


func apply_terrain_cells(cells: Array[Vector2i], terrain_id: StringName) -> Array[Vector2i]:
	var changed: Array[Vector2i] = []
	if not _active or _arena == null:
		return changed
	if terrain_id != &"void" \
			and not ArenaPermanentTerrainPaintService.can_paint(_arena, terrain_id):
		return changed
	for cell in cells:
		_received_cells[cell] = int(_received_cells.get(cell, 0)) + 1
		if _changed_cells.has(cell):
			continue
		var current := _arena.get_cell_definition(cell)
		var previous_id := current.terrain_id if current != null else &""
		if previous_id == terrain_id:
			continue
		if not ArenaDynamicEditingService.paint_terrain_local(
			_arena, cell, terrain_id
		):
			continue
		_changed_cells[cell] = true
		changed.append(cell)
		if not (previous_id in VISUAL_ONLY_IDS and terrain_id in VISUAL_ONLY_IDS):
			_logical_change = true
	return changed


func record_external_changes(cells: Array[Vector2i], require_runtime_sync := true) -> void:
	## Enregistre les mutations locales réalisées par les autres familles de la
	## bibliothèque. Le geste reste propriétaire de l'unique instantané et de
	## l'unique synchronisation runtime effectuée dans `finish()`.
	if not _active or _arena == null:
		return
	for cell in cells:
		_received_cells[cell] = int(_received_cells.get(cell, 0)) + 1
		_changed_cells[cell] = true
	_logical_change = _logical_change or require_runtime_sync


func finish() -> Dictionary:
	if not _active or _arena == null:
		return {"changed": false}
	var started := Time.get_ticks_usec()
	var synced := false
	if not _changed_cells.is_empty() and _logical_change:
		synced = ArenaRuntimeBridge.sync_runtime_resources(_arena)
	var result := {
		"changed": not _changed_cells.is_empty(),
		"before": _before.duplicate(true),
		"after": _arena.to_snapshot(),
		"changed_cells": changed_cells(),
		"changed_cell_count": _changed_cells.size(),
		"received_cell_count": _received_cells.values().reduce(
			func(total, value): return int(total) + int(value), 0
		),
		"duplicate_cell_count": _duplicate_count(),
		"logical_change": _logical_change,
		"runtime_sync_calls": 1 if synced else 0,
		"finalization_ms": float(Time.get_ticks_usec() - started) / 1000.0,
		"total_ms": float(Time.get_ticks_usec() - _started_usec) / 1000.0,
	}
	cancel()
	return result


func cancel() -> void:
	_arena = null
	_before = {}
	_changed_cells.clear()
	_received_cells.clear()
	_logical_change = false
	_active = false
	_started_usec = 0


func changed_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell in _changed_cells:
		result.append(cell)
	result.sort_custom(func(a, b): return a.y < b.y or (a.y == b.y and a.x < b.x))
	return result


func is_active() -> bool:
	return _active


static func rectangle_cells(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y in range(mini(from.y, to.y), maxi(from.y, to.y) + 1):
		for x in range(mini(from.x, to.x), maxi(from.x, to.x) + 1):
			result.append(Vector2i(x, y))
	return result


static func contiguous_cells(arena: ArenaDefinition, start: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if arena == null or not arena.is_in_bounds(start):
		return result
	var start_definition := arena.get_cell_definition(start)
	var terrain_id := start_definition.terrain_id if start_definition != null else &""
	var visited := {start: true}
	var frontier: Array[Vector2i] = [start]
	while not frontier.is_empty():
		var current: Vector2i = frontier.pop_front()
		result.append(current)
		for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var neighbor: Vector2i = current + direction
			if visited.has(neighbor) or not arena.is_in_bounds(neighbor):
				continue
			var definition := arena.get_cell_definition(neighbor)
			if (definition.terrain_id if definition != null else &"") != terrain_id:
				continue
			visited[neighbor] = true
			frontier.append(neighbor)
	return result


static func replacement_cells(
		arena: ArenaDefinition,
		from_id: StringName
	) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if arena == null:
		return result
	for definition in arena.cells:
		if definition != null and definition.defined and definition.terrain_id == from_id:
			result.append(definition.coordinate)
	return result


func _duplicate_count() -> int:
	var result := 0
	for value in _received_cells.values():
		result += maxi(0, int(value) - 1)
	return result
