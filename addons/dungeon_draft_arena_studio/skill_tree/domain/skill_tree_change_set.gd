@tool
class_name SkillTreeChangeSet
extends RefCounted

var property_changes: Array[Dictionary] = []
var created_paths := PackedStringArray()
var updated_paths := PackedStringArray()
var detached_paths := PackedStringArray()
var orphaned_paths := PackedStringArray()
var archived_paths := PackedStringArray()
var deleted_paths := PackedStringArray()


func add_entry(entry: SkillTreeSavePlanEntry) -> void:
	if entry == null:
		return
	property_changes.append_array(entry.changes)
	match entry.operation:
		SkillTreeSavePlanEntry.Operation.CREATE:
			created_paths.append(entry.target_path)
		SkillTreeSavePlanEntry.Operation.UPDATE:
			updated_paths.append(entry.target_path)
		SkillTreeSavePlanEntry.Operation.DETACH_REFERENCE:
			detached_paths.append(entry.source_path)
		SkillTreeSavePlanEntry.Operation.ORPHANED:
			orphaned_paths.append(entry.source_path)
		SkillTreeSavePlanEntry.Operation.ARCHIVE:
			archived_paths.append(entry.source_path)
		SkillTreeSavePlanEntry.Operation.DELETE:
			deleted_paths.append(entry.source_path)


func to_dictionary() -> Dictionary:
	return {
		"property_changes": property_changes.duplicate(true),
		"created_paths": created_paths.duplicate(),
		"updated_paths": updated_paths.duplicate(),
		"detached_paths": detached_paths.duplicate(),
		"orphaned_paths": orphaned_paths.duplicate(),
		"archived_paths": archived_paths.duplicate(),
		"deleted_paths": deleted_paths.duplicate(),
	}
