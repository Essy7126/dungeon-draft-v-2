@tool
class_name ItemSavePlan
extends RefCounted

var entries: Array[ItemSavePlanEntry] = []
var conflicts: Array[ItemSaveConflict] = []
var warnings: Array[String] = []
var references: Array[String] = []
var catalog_path := ""
var reward_tag_changed := false


func is_valid() -> bool:
	return not entries.is_empty() and conflicts.is_empty()


func to_snapshot() -> Dictionary:
	var entry_snapshots: Array[Dictionary] = []
	for entry in entries:
		entry_snapshots.append(entry.to_snapshot())
	var conflict_snapshots: Array[Dictionary] = []
	for conflict in conflicts:
		conflict_snapshots.append(conflict.to_snapshot())
	return {
		"valid": is_valid(),
		"entries": entry_snapshots,
		"conflicts": conflict_snapshots,
		"warnings": warnings.duplicate(),
		"references": references.duplicate(),
		"catalog_path": catalog_path,
		"reward_tag_changed": reward_tag_changed,
	}
