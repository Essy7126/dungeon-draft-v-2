@tool
class_name SkillTreeSavePlan
extends RefCounted

var entries: Array[SkillTreeSavePlanEntry] = []
var conflicts: Array[SkillTreeSaveConflict] = []
var change_set := SkillTreeChangeSet.new()
var recovery_path := ""
var source_character_path := ""
var opening_fingerprint := ""
var working_fingerprint := ""


func add_entry(entry: SkillTreeSavePlanEntry) -> void:
	if entry == null:
		return
	entries.append(entry)
	change_set.add_entry(entry)
	if entry.conflict != null:
		conflicts.append(entry.conflict)


func writable_entries() -> Array[SkillTreeSavePlanEntry]:
	var result: Array[SkillTreeSavePlanEntry] = []
	for entry in entries:
		if entry.is_writable() and entry.conflict == null:
			result.append(entry)
	return result


func has_blocking_conflicts() -> bool:
	return conflicts.any(func(conflict: SkillTreeSaveConflict) -> bool:
		return conflict.blocking
	)


func to_dictionary() -> Dictionary:
	var serialized_entries: Array[Dictionary] = []
	for entry in entries:
		serialized_entries.append(entry.to_dictionary())
	var serialized_conflicts: Array[Dictionary] = []
	for conflict in conflicts:
		serialized_conflicts.append(conflict.to_dictionary())
	return {
		"entries": serialized_entries,
		"conflicts": serialized_conflicts,
		"change_set": change_set.to_dictionary(),
		"recovery_path": recovery_path,
		"source_character_path": source_character_path,
		"opening_fingerprint": opening_fingerprint,
		"working_fingerprint": working_fingerprint,
		"can_apply": not has_blocking_conflicts(),
	}
