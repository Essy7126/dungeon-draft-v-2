@tool
class_name ArenaAutomaticRuntimeSmokeService
extends RefCounted

## Smoke synchrone et sans interaction utilise par le gate d'integration.
## Il serialise une copie isolee sous user://, la recharge sans cache, construit
## la projection runtime et compare les ensembles exacts de dalles.

const ROOT := "user://dungeon_draft_studio/integration_gate/automatic_smoke"

static var _cache := {}


static func run(arena: ArenaDefinition) -> Dictionary:
	var result := {
		"ok": false,
		"errors": PackedStringArray(),
		"automatic": true,
		"interactive": false,
		"temporary_path": "",
		"working_fingerprint": "",
		"temporary_fingerprint": "",
		"fingerprints_identical": false,
		"working_topology_hash": "",
		"temporary_topology_hash": "",
		"runtime_topology_hash": "",
		"topology_hashes_identical": false,
		"expected_floor_cells": [],
		"rendered_floor_cells": [],
		"expected_floor_hash": "",
		"rendered_floor_hash": "",
		"missing_cells": [],
		"unexpected_cells": [],
		"removed_cells_rendered": [],
		"duplicate_cells": [],
		"grid_built": false,
		"pathfinder_built": false,
		"visual_assembly_valid": false,
		"required_spawn_errors": [],
		"required_objective_errors": [],
		"cache_hit": false,
	}
	if arena == null:
		result.errors.append("arena_missing")
		return result
	var fingerprint := ArenaSnapshotService.arena_fingerprint(arena)
	if _cache.has(fingerprint):
		var cached := (_cache[fingerprint] as Dictionary).duplicate(true)
		cached["cache_hit"] = true
		return cached
	result.working_fingerprint = fingerprint
	var working_topology := ArenaTopologySignatureService.build(arena)
	result.working_topology_hash = str(working_topology.topology_hash)
	var clone := ArenaDefinition.new()
	if not ArenaSnapshotService.restore(clone, ArenaSnapshotService.capture(arena)):
		result.errors.append("snapshot_restore_failed")
		return result
	var directory := ROOT.path_join(fingerprint.left(20))
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory)) != OK:
		result.errors.append("temporary_directory_failed")
		return result
	var temporary_path := directory.path_join("arena.tres")
	result.temporary_path = temporary_path
	var save_error := ResourceSaver.save(
		clone, temporary_path, ResourceSaver.FLAG_RELATIVE_PATHS
	)
	if save_error != OK:
		result.errors.append("temporary_save_failed:%s" % error_string(save_error))
		return result
	var temporary := ResourceLoader.load(
		temporary_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as ArenaDefinition
	if temporary == null:
		result.errors.append("temporary_reload_failed")
		return result
	result.temporary_fingerprint = ArenaSnapshotService.arena_fingerprint(temporary)
	result.fingerprints_identical = result.working_fingerprint \
		== result.temporary_fingerprint
	var temporary_topology := ArenaTopologySignatureService.build(temporary)
	result.temporary_topology_hash = str(temporary_topology.topology_hash)
	var runtime_state := ArenaRuntimeProjectionService.build(temporary)
	result.grid_built = runtime_state != null and runtime_state.grid != null
	result.pathfinder_built = result.grid_built \
		and Pathfinder.new(runtime_state.grid) != null
	var runtime_parity := ArenaRuntimeProjectionService.parity_report(
		temporary, runtime_state
	)
	result.runtime_topology_hash = str(runtime_parity.get(
		"runtime_topology_hash", ""
	))
	result.topology_hashes_identical = result.working_topology_hash \
		== result.temporary_topology_hash \
		and result.working_topology_hash == result.runtime_topology_hash
	var plan := ArenaTerrainRenderPlanService.build(temporary)
	var visual := ArenaVisualAssembler.inspect(temporary)
	result.visual_assembly_valid = visual.valid
	var duplicates: Array[String] = []
	for key in visual.terrain_nodes:
		if int((visual.terrain_nodes[key] as Dictionary).get(
			"duplication_count", 1
		)) > 1:
			duplicates.append(str(key))
	var floor_parity := ArenaTopologyParityReport.compare_floor_sets(
		plan.get("expected_floor_cells", []), visual.terrain_nodes.keys(),
		temporary_topology.removed_cells, duplicates
	)
	result.expected_floor_cells = ArenaTopologySignatureService.normalized_keys(
		plan.get("expected_floor_cells", [])
	)
	result.rendered_floor_cells = ArenaTopologySignatureService.normalized_keys(
		visual.terrain_nodes.keys()
	)
	result.expected_floor_hash = floor_parity.expected_floor_hash
	result.rendered_floor_hash = floor_parity.rendered_floor_hash
	result.missing_cells = floor_parity.missing_cells.duplicate()
	result.unexpected_cells = floor_parity.unexpected_cells.duplicate()
	result.removed_cells_rendered = floor_parity.removed_cells_rendered.duplicate()
	result.duplicate_cells = floor_parity.duplicate_cells.duplicate()
	result.required_spawn_errors = _required_spawn_errors(temporary)
	result.required_objective_errors = _required_objective_errors(temporary)
	if not result.fingerprints_identical:
		result.errors.append("temporary_fingerprint_mismatch")
	if not result.topology_hashes_identical:
		result.errors.append("topology_mismatch")
	if not result.grid_built:
		result.errors.append("grid_build_failed")
	if not result.pathfinder_built:
		result.errors.append("pathfinder_build_failed")
	if not result.visual_assembly_valid:
		result.errors.append("visual_assembly_failed")
	if not floor_parity.valid:
		result.errors.append("floor_parity_failed")
	if not result.required_spawn_errors.is_empty():
		result.errors.append("required_spawn_invalid")
	if not result.required_objective_errors.is_empty():
		result.errors.append("required_objective_invalid")
	result.ok = result.errors.is_empty() and bool(runtime_parity.get("ok", false))
	_cache[fingerprint] = result.duplicate(true)
	return result


static func clear_cache() -> void:
	_cache.clear()


static func cache_size() -> int:
	return _cache.size()


static func _required_spawn_errors(arena: ArenaDefinition) -> Array[String]:
	var errors: Array[String] = []
	for spawn in arena.spawns:
		if spawn == null or not spawn.required:
			continue
		var definition := arena.get_cell_definition(spawn.cell)
		var obstacle := arena.obstacle_at(spawn.cell)
		if definition == null or not definition.defined or not definition.playable \
				or definition.border or (obstacle != null and obstacle.blocks_movement):
			errors.append("%s@%d,%d" % [
				spawn.spawn_id, spawn.cell.x, spawn.cell.y,
			])
	return errors


static func _required_objective_errors(arena: ArenaDefinition) -> Array[String]:
	var errors: Array[String] = []
	for objective in arena.objectives:
		if objective == null or not objective.required:
			continue
		var definition := arena.get_cell_definition(objective.cell)
		var obstacle := arena.obstacle_at(objective.cell)
		if definition == null or not definition.defined \
				or (obstacle != null and obstacle.blocks_movement):
			errors.append("%s@%d,%d" % [
				objective.objective_id, objective.cell.x, objective.cell.y,
			])
	return errors
