@tool
class_name ArenaVisualAssemblyReport
extends RefCounted

var visual_mode := ArenaDefinition.VisualMode.PAINTED
var floor_policy := ArenaModularVisualProfile.HybridFloorPolicy.NONE
var base_floor_intentionally_painted := false
var expected_terrain_cell_count := 0
var rendered_terrain_node_count := 0
var expected_by_terrain_id := {}
var rendered_by_terrain_id := {}
var expected_wall_count := 0
var rendered_wall_count := 0
var expected_decoration_count := 0
var rendered_decoration_count := 0
var duplicate_terrain_node_count := 0
var terrain_nodes := {}
var wall_nodes := {}
var decoration_nodes := {}
var missing_terrain_assets: Array[String] = []
var missing_wall_assets: Array[String] = []
var skipped_cells: Array = []
var skip_reasons := {}
var warnings: Array[String] = []
var errors: Array[String] = []
var valid := false


func finalize() -> void:
	if expected_terrain_cell_count != rendered_terrain_node_count:
		errors.append("terrain_count_mismatch:%d/%d" % [
			rendered_terrain_node_count, expected_terrain_cell_count,
		])
	if expected_wall_count != rendered_wall_count:
		errors.append("wall_count_mismatch:%d/%d" % [
			rendered_wall_count, expected_wall_count,
		])
	if expected_decoration_count != rendered_decoration_count:
		errors.append("decoration_count_mismatch:%d/%d" % [
			rendered_decoration_count, expected_decoration_count,
		])
	if duplicate_terrain_node_count > 0:
		errors.append("duplicate_terrain_nodes:%d" % duplicate_terrain_node_count)
	valid = errors.is_empty() and missing_terrain_assets.is_empty() \
		and missing_wall_assets.is_empty() \
		and (expected_terrain_cell_count > 0 or base_floor_intentionally_painted \
			or floor_policy == ArenaModularVisualProfile.HybridFloorPolicy.NONE)


func to_dict() -> Dictionary:
	return {
		"visual_mode": visual_mode,
		"floor_policy": floor_policy,
		"base_floor_intentionally_painted": base_floor_intentionally_painted,
		"expected_terrain_cell_count": expected_terrain_cell_count,
		"rendered_terrain_node_count": rendered_terrain_node_count,
		"expected_by_terrain_id": expected_by_terrain_id.duplicate(true),
		"rendered_by_terrain_id": rendered_by_terrain_id.duplicate(true),
		"expected_wall_count": expected_wall_count,
		"rendered_wall_count": rendered_wall_count,
		"expected_decoration_count": expected_decoration_count,
		"rendered_decoration_count": rendered_decoration_count,
		"duplicate_terrain_node_count": duplicate_terrain_node_count,
		"terrain_nodes": terrain_nodes.duplicate(true),
		"wall_nodes": wall_nodes.duplicate(true),
		"decoration_nodes": decoration_nodes.duplicate(true),
		"missing_terrain_assets": missing_terrain_assets.duplicate(),
		"missing_wall_assets": missing_wall_assets.duplicate(),
		"skipped_cells": skipped_cells.duplicate(true),
		"skip_reasons": skip_reasons.duplicate(true),
		"warnings": warnings.duplicate(),
		"errors": errors.duplicate(),
		"valid": valid,
	}
