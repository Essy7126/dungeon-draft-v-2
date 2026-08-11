@tool
class_name ArenaTopologyParityReport
extends Resource

@export var canonical_topology_hash := ""
@export var temporary_topology_hash := ""
@export var runtime_topology_hash := ""
@export var expected_floor_hash := ""
@export var rendered_floor_hash := ""
@export var missing_cells: Array[String] = []
@export var unexpected_cells: Array[String] = []
@export var removed_cells_rendered: Array[String] = []
@export var duplicate_cells: Array[String] = []
@export var errors: Array[String] = []
@export var valid := false


static func compare_floor_sets(
		expected: Variant,
		rendered: Variant,
		removed: Variant = [],
		duplicates: Variant = []
	) -> ArenaTopologyParityReport:
	var report := ArenaTopologyParityReport.new()
	var expected_keys := ArenaTopologySignatureService.normalized_keys(expected)
	var rendered_keys := ArenaTopologySignatureService.normalized_keys(rendered)
	report.expected_floor_hash = ArenaTopologySignatureService.hash_keys(expected_keys)
	report.rendered_floor_hash = ArenaTopologySignatureService.hash_keys(rendered_keys)
	report.missing_cells.assign(
		ArenaTopologySignatureService.difference(expected_keys, rendered_keys)
	)
	report.unexpected_cells.assign(
		ArenaTopologySignatureService.difference(rendered_keys, expected_keys)
	)
	report.removed_cells_rendered.assign(
		ArenaTopologySignatureService.intersection(removed, rendered_keys)
	)
	report.duplicate_cells.assign(
		ArenaTopologySignatureService.normalized_keys(duplicates)
	)
	report.valid = report.expected_floor_hash == report.rendered_floor_hash \
		and report.missing_cells.is_empty() \
		and report.unexpected_cells.is_empty() \
		and report.removed_cells_rendered.is_empty() \
		and report.duplicate_cells.is_empty()
	return report


static func compare_stages(
		canonical: Dictionary,
		temporary: Dictionary,
		runtime: Dictionary,
		expected_floor: Variant,
		rendered_floor: Variant,
		duplicates: Variant = []
	) -> ArenaTopologyParityReport:
	var report := compare_floor_sets(
		expected_floor,
		rendered_floor,
		canonical.get("removed_cells", []),
		duplicates
	)
	report.canonical_topology_hash = str(canonical.get("topology_hash", ""))
	report.temporary_topology_hash = str(temporary.get("topology_hash", ""))
	report.runtime_topology_hash = str(runtime.get("topology_hash", ""))
	for set_name in ArenaTopologySignatureService.SET_NAMES:
		var wanted := canonical.get(set_name, [])
		if ArenaTopologySignatureService.normalized_keys(wanted) \
				!= ArenaTopologySignatureService.normalized_keys(temporary.get(set_name, [])):
			report.errors.append("temporary_set_mismatch:%s" % set_name)
		if ArenaTopologySignatureService.normalized_keys(wanted) \
				!= ArenaTopologySignatureService.normalized_keys(runtime.get(set_name, [])):
			report.errors.append("runtime_set_mismatch:%s" % set_name)
	report.valid = report.valid \
		and report.canonical_topology_hash == report.temporary_topology_hash \
		and report.canonical_topology_hash == report.runtime_topology_hash \
		and report.errors.is_empty()
	return report


func to_dict() -> Dictionary:
	return {
		"canonical_topology_hash": canonical_topology_hash,
		"temporary_topology_hash": temporary_topology_hash,
		"runtime_topology_hash": runtime_topology_hash,
		"expected_floor_hash": expected_floor_hash,
		"rendered_floor_hash": rendered_floor_hash,
		"missing_cells": missing_cells.duplicate(),
		"unexpected_cells": unexpected_cells.duplicate(),
		"removed_cells_rendered": removed_cells_rendered.duplicate(),
		"duplicate_cells": duplicate_cells.duplicate(),
		"errors": errors.duplicate(),
		"valid": valid,
	}
